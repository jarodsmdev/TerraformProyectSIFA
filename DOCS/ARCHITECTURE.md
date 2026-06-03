# Arquitectura de SIFA en AWS

## Diagrama de Red

```
                                     Internet
                                         |
                                    Internet Gateway
                                         |
                     +-------------------+-------------------+
                     |                                       |
               Public Subnet                            Private Subnet
                (10.0.1.0/24)                            (10.0.2.0/24)
                     |                                       |
               +-----------+                         +---------------+
               |  sifa-    |                         |    sifa-      |
               |  gateway  |                         |    auth       |
               | 10.0.1.10 |                         |    10.0.2.10  |
               +-----------+                         +---------------+
               |  EIP       |                         |    sifa-      |
               | 44.x.x.x   |                         |    plate      |
               +-----------+                         |    10.0.2.20  |
                                                      +---------------+
                                                      |    sifa-      |
                                                      |    core       |
                                                      |    10.0.2.30  |
                                                      +---------------+
```

## Componentes de Red

| Componente | Recurso AWS | Detalle |
|------------|-------------|---------|
| VPC | `aws_vpc` | 10.0.0.0/16 |
| Subnet Pública | `aws_subnet.public` | 10.0.1.0/24, us-east-1a |
| Subnet Privada | `aws_subnet.private` | 10.0.2.0/24, us-east-1a |
| Internet Gateway | `aws_internet_gateway` | Conecta la VPC a internet |
| NAT Gateway | `aws_nat_gateway` | Salida a internet desde subred privada |
| EIP NAT | `aws_eip.nat` | IP elástica asociada al NAT Gateway |
| Route Table Pública | `aws_route_table.public` | 0.0.0.0/0 → Internet Gateway |
| Route Table Privada | `aws_route_table.private` | 0.0.0.0/0 → NAT Gateway |

## Instancias EC2

| Nombre | Módulo | Tipo | Subnet | IP Privada | IP Pública | IAM |
|--------|--------|------|--------|------------|------------|-----|
| sifa-gateway | `public_ec2` | t3.micro | Pública | 10.0.1.10 | EIP (pre-asignada) | - |
| sifa-auth | `private_ec2` | t3.micro | Privada | 10.0.2.10 | - | - |
| sifa-plate | `private_ec2_plate` | t3.large | Privada | 10.0.2.20 | - | - |
| sifa-core | `private_ec2_core` | t3.micro | Privada | 10.0.2.30 | - | `EMR_EC2_DefaultRole` |

Todas las instancias usan:
- AMI: Ubuntu 22.04 (`ami-05cf1e9f73fbad2e2`)
- Key Pair: `SIFA-KEY`
- User Data: Instalación de Docker (`modules/scripts/docker-install.sh`)

## Security Groups

### sifa-public-sg
Reglas de entrada:

| Puerto | Protocolo | Origen | Descripción |
|--------|-----------|--------|-------------|
| 22 | TCP | 0.0.0.0/0 | SSH desde internet |
| 80 | TCP | 0.0.0.0/0 | HTTP desde internet |
| -1 | ICMP | 10.0.0.0/16 | Diagnóstico desde la VPC |

Reglas de salida: todo el tráfico (0.0.0.0/0).

### sifa-private-sg
Reglas de entrada:

| Puerto | Protocolo | Origen | Descripción |
|--------|-----------|--------|-------------|
| 22 | TCP | sifa-public-sg | SSH desde el gateway |
| 80 | TCP | sifa-public-sg | HTTP desde el gateway |

Reglas de salida: todo el tráfico (0.0.0.0/0).

## Almacenamiento

| Componente | Recurso | Detalle |
|------------|---------|---------|
| S3 Images | `aws_s3_bucket` | `sifa-core-images-quisco`, acceso público de lectura, versionado habilitado |

## Backend de Terraform

| Recurso | Nombre | Propósito |
|---------|--------|-----------|
| Bucket S3 | `sifa-terraform-state` | Almacenamiento del state file |
| DynamoDB | `terraform-locks` | Locking para operaciones concurrentes |

## Flujo de Tráfico

1. **Internet → API Gateway**: El tráfico HTTP llega al Internet Gateway, enruta a la subred pública y llega a `sifa-gateway` (puerto 80).
2. **Gateway → Servicios Privados**: `sifa-gateway` reenvía peticiones a `sifa-auth`, `sifa-plate` o `sifa-core` en la subred privada (puerto 80).
3. **Salida a internet desde privada**: Las instancias privadas salen a internet a través del NAT Gateway ubicado en la subred pública.
4. **SIFA Core → S3**: `sifa-core` tiene un perfil IAM (`EMR_EC2_DefaultRole`) que le permite acceder al bucket S3 de imágenes.
