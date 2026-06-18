# SIFA - Infrastructure as Code with Terraform

Este repositorio contiene la definición de infraestructura como código (IaC) para el proyecto SIFA, desplegado en AWS utilizando Terraform. La arquitectura implementa un sistema distribuido con componentes expuestos a internet y servicios privados en subnets internas.

## Tabla de Contenidos

- [Descripción General](#descripción-general)
- [Arquitectura](#arquitectura)
- [Estructura del Proyecto](#estructura-del-proyecto)
- [Requisitos Previos](#requisitos-previos)
- [Configuración](#configuración)
- [Uso](#uso)
- [Variables](#variables)
- [Outputs](#outputs)
- [Seguridad](#seguridad)
- [Limpieza de Recursos](#limpieza-de-recursos)

## Descripción General

El proyecto SIFA (Sistema de Inteligencia para Fiscalización Automática) es una aplicación distribuida compuesta por múltiples microservicios desplegados en instancias EC2 de AWS. La infraestructura se gestiona completamente con Terraform, utilizando un backend remoto en S3 para el almacenamiento del estado con lock file.

### Componentes de la Infraestructura

| Componente | Tipo | Descripción |
|------------|------|--------------|
| API Gateway | EC2 Pública | Punto de entrada exposición a internet con IP elástica |
| Auth Service | EC2 Privada | Servicio de autenticación |
| Plate Service | EC2 Privada | Servicio de gestión de platos/comidas |
| SIFA Core | EC2 Privada | Servicio principal con acceso a S3 |
| MySQL | EC2 Pública | Base de datos MySQL con EIP opcional |
| S3 Images | Bucket S3 | Almacenamiento público para imágenes |

## Arquitectura

La infraestructura sigue un patrón de arquitectura de red con subnets públicas y privadas, utilizando un NAT Gateway para permitir que las instancias privadas puedan acceder a internet sin exposición directa.

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
               |  sifa-    |                         +---------------+
               |  mysql    |                         |    sifa-      |
               | 10.0.1.40 |                         |    core       |
               +-----------+                         |    10.0.2.30  |
               |  EIP       |                         +---------------+
               | (opcional) |
               +-----------+
```

### Componentes de Red

- **VPC**: 10.0.0.0/16 - Red virtual privada
- **Public Subnet**: 10.0.1.0/24 - Subnet con acceso a internet directo
- **Private Subnet**: 10.0.2.0/24 - Subnet con acceso a internet mediante NAT Gateway
- **Internet Gateway**: Proporciona conectividad directa desde la VPC a internet
- **NAT Gateway**: Permite a las instancias privadas salir a internet de forma segura

## Estructura del Proyecto

```
├── main.tf                 # Configuración principal del proyecto
├── variables.tf            # Definición de variables (definidas en módulos)
├── outputs.tf              # Outputs de la infraestructura
├── .terraform.lock.hcl     # Lock file de proveedores (versionar)
├── .gitignore              # Archivos ignorados por Git
├── modules/                # Módulos reutilizables
│   ├── vpc/                # Módulo de red virtual
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── ec2/                # Módulo de instancias EC2
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── mysql/              # Módulo de MySQL
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── sg/                 # Módulo de Security Groups
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── s3/                 # Módulo de bucket S3
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── scripts/            # Scripts de inicialización
│       └── docker-install.sh
├── bootstrap/              # Backend remoto (crear bucket S3)
│   └── backend-bootstrap.tf
├── DOCS/                   # Documentación adicional
│   ├── ARCHITECTURE.md
│   └── SSHEC2PublicToEC2Private.md
└── PAIR_KEYS/              # Claves SSH (no versionadas)
    └── README.md
```

## Requisitos Previos

Para utilizar este repositorio necesitas:

1. **Terraform** versión 1.0 o superior
2. **AWS CLI** configurado con credenciales válidas
3. **Key pair** llamado `SIFA-KEY` creado en AWS
4. **Elastic IP** pre-asignada para el API Gateway
5. **Elastic IP** (opcional) pre-asignada para MySQL si se requiere acceso público

### Instalación de Terraform

En Ubuntu/Debian:
```bash
sudo apt-get update
sudo apt-get install -y wget unzip
wget https://releases.hashicorp.com/terraform/1.7.5/terraform_1.7.5_linux_amd64.zip
sudo unzip terraform_1.7.5_linux_amd64.zip -d /usr/local/bin/
rm terraform_1.7.5_linux_amd64.zip
```

## Configuración

### 1. Configurar el Backend

El proyecto usa **S3 como backend remoto** con lock file (`use_lockfile`). El bucket `sifa-terraform-state` debe existir antes de inicializar.

**Opción A — Bootstrap con Terraform:**

```bash
cd bootstrap/
terraform init
terraform apply -auto-approve
cd ..
```

**Opción B — Manual (AWS CLI):**

```bash
aws s3 mb s3://sifa-terraform-state --region us-east-1
aws s3api put-bucket-versioning --bucket sifa-terraform-state --versioning-configuration Status=Enabled
```

Luego inicializar el proyecto:

```bash
terraform init
```

### 2. Variables de Entorno de AWS

Configura tus credenciales de AWS:
```bash
export AWS_ACCESS_KEY_ID="tu_access_key"
export AWS_SECRET_ACCESS_KEY="tu_secret_key"
export AWS_DEFAULT_REGION="us-east-1"
```

O configura AWS CLI:
```bash
aws configure
```

### 3. Clave SSH

Asegúrate de que la clave SSH `SIFA-KEY` exista en AWS EC2. Si no existe:
```bash
aws ec2 create-key-pair --key-name SIFA-KEY --query 'KeyMaterial' --output text > SIFA-KEY.pem
chmod 400 SIFA-KEY.pem
```

## Uso

### Inicialización

Inicializa el backend y descarga los proveedores:
```bash
terraform init
```

### Planificación

Revisa los cambios que se aplicarán:
```bash
terraform plan
```

### Aplicación

Despliega la infraestructura:
```bash
terraform apply
```

Para aplicar con auto-aprobación:
```bash
terraform apply -auto-approve
```

### Validación del Estado

Para verificar el estado actual de la infraestructura:
```bash
terraform show
```

### Outputs

Después de aplicar, los outputs mostrarán información importante:
```bash
terraform output
```

## Variables

El proyecto define las siguientes variables en los módulos:

### Módulo VPC

| Variable | Tipo | Valor por Defecto | Descripción |
|----------|------|-------------------|--------------|
| `project_name` | string | - | Nombre del proyecto para etiquetado |
| `vpc_cidr` | string | "10.0.0.0/16" | Bloque CIDR de la VPC |
| `public_subnet_cidr` | string | "10.0.1.0/24" | CIDR de la subnet pública |
| `private_subnet_cidr` | string | "10.0.2.0/24" | CIDR de la subnet privada |
| `az` | string | "us-east-1a" | Zona de disponibilidad |

### Módulo EC2

| Variable | Tipo | Valor por Defecto | Descripción |
|----------|------|-------------------|--------------|
| `name` | string | - | Nombre de la instancia |
| `ami` | string | ami-05cf1e9f73fbad2e2 | ID de la AMI (Ubuntu 22.04) |
| `instance_type` | string | t3.micro | Tipo de instancia |
| `subnet_id` | string | - | ID de la subnet |
| `security_group_ids` | list(string) | - | IDs de security groups |
| `key_name` | string | - | Nombre del key pair |
| `associate_eip` | bool | false | Asociar IP elástica |
| `allocation_id` | string | null | ID de asignación de EIP |
| `private_ip` | string | null | IP privada estática |
| `iam_instance_profile` | string | null | Perfil de IAM |
| `user_data` | string | null | Script de inicialización |
| `root_volume_size` | number | 8 | Tamaño del disco raíz en GB |

### Módulo S3

| Variable | Tipo | Valor por Defecto | Descripción |
|----------|------|-------------------|--------------|
| `bucket_name` | string | - | Nombre único del bucket |
| `project_name` | string | - | Nombre del proyecto |
| `versioning` | bool | true | Habilitar versionado |

### Módulo Security Group

| Variable | Tipo | Descripción |
|----------|------|--------------|
| `name` | string | Nombre del security group |
| `description` | string | Descripción |
| `vpc_id` | string | ID de la VPC |
| `ingress_rules` | list(object) | Reglas de entrada |
| `egress_rules` | list(object) | Reglas de salida |

### Módulo MySQL

| Variable | Tipo | Valor por Defecto | Descripción |
|----------|------|-------------------|--------------|
| `name` | string | - | Nombre de la instancia |
| `ami` | string | ami-05cf1e9f73fbad2e2 | ID de la AMI (Ubuntu 22.04) |
| `instance_type` | string | t3.micro | Tipo de instancia |
| `subnet_id` | string | - | ID de la subnet |
| `security_group_ids` | list(string) | - | IDs de security groups |
| `key_name` | string | - | Nombre del key pair |
| `private_ip` | string | null | IP privada estática |
| `mysql_user` | string | - | Usuario de MySQL |
| `mysql_password` | string | - | Contraseña de MySQL |
| `associate_eip` | bool | false | Asociar IP elástica |
| `allocation_id` | string | null | ID de asignación de EIP |

### Configuración desde `locals` (en `main.tf`)

Además de las variables de módulo, los siguientes valores se configuran directamente en el bloque `locals` del archivo `main.tf`:

| Variable | Valor por Defecto | Descripción |
|----------|-------------------|--------------|
| `region` | us-east-1 | Región de AWS |
| `project_name` | SIFA | Nombre del proyecto |
| `bucket_name` | sifa-core-images-quisco | Nombre del bucket S3 |
| `key_name` | SIFA-KEY | Key pair de EC2 |
| `gateway_eip_allocation_id` | eipalloc-... | EIP del API Gateway |
| `ubuntu_ami` | ami-05cf1e9f73fbad2e2 | AMI base para todas las EC2 |
| `gateway_private_ip` | 10.0.1.10 | IP privada del Gateway |
| `auth_private_ip` | 10.0.2.10 | IP privada del Auth Service |
| `plate_private_ip` | 10.0.2.20 | IP privada del Plate Service |
| `core_private_ip` | 10.0.2.30 | IP privada del SIFA Core |
| `mysql_private_ip` | 10.0.1.40 | IP privada de MySQL |
| `mysql_user` | adminroot | Usuario de MySQL |
| `mysql_password` | adminroot123 | Contraseña de MySQL |
| `mysql_allocation_id` | null | EIP para MySQL (null = sin EIP) |

## Outputs

Después de aplicar Terraform, dispondrás de los siguientes outputs:

```hcl
vpc_id              # ID de la VPC creada
public_ec2          # Información de la EC2 pública (Gateway)
  - name            # Nombre de la instancia
  - public_ip       # IP pública asignada
  - instance_id     # ID de la instancia
private_ec2         # Información de la EC2 Auth
  - name
  - private_ip
  - instance_id
private_ec2_core    # Información de la EC2 Core
  - name
  - private_ip
private_ec2_plate   # Información de la EC2 Plate
  - name
  - private_ip
mysql               # Información de la EC2 MySQL
  - name
  - private_ip
  - public_ip       # null si no se asoció EIP
  - instance_id
```

## Seguridad

### Consideraciones Importantes

1. **Credenciales AWS**: Nunca expongas tus credenciales en el repositorio. Utiliza variables de entorno o perfiles de AWS CLI.

2. **Estado de Terraform**: El estado contiene información sensible. Se utiliza backend S3 con lock file para evitar conflictos.

3. **Security Groups**: Los security groups configurados permiten acceso desde internet en puertos específicos. Revisa y ajusta según tus necesidades.

4. **Claves SSH**: La clave privada `SIFA-KEY.pem` debe mantenerse segura y nunca versionarse en Git.

5. **Acceso a S3**: El bucket está configurado con acceso público de lectura. Ajusta las políticas según los requisitos de seguridad de tu proyecto.

### Puertos Expuestos

- **22**: SSH (desde cualquier IP: 0.0.0.0/0) - API Gateway
- **80**: HTTP (desde cualquier IP: 0.0.0.0/0) - API Gateway
- **3306**: MySQL (desde cualquier IP: 0.0.0.0/0 y desde subnet privada 10.0.2.0/24) - MySQL
- **ICMP**: Desde la VPC (10.0.0.0/16) - Diagnóstico

## Limpieza de Recursos

Para destruir toda la infraestructura creada:

```bash
terraform destroy
```

Para destruir con auto-aprobación:
```bash
terraform destroy -auto-approve
```

**Advertencia**: Esta acción eliminará todos los recursos creados incluyendo:
- Instancias EC2
- Bucket S3
- NAT Gateway y Elastic IP
- Security Groups
- Subnets y VPC

## Documentación Adicional

- [Arquitectura Detallada](./DOCS/ARCHITECTURE.md)
- [Configuración SSH](./DOCS/SSHEC2PublicToEC2Private.md)

## Contribuir

Para modificar la infraestructura:

1. Crea una rama para tus cambios
2. Modifica los archivos necesarios
3. Ejecuta `terraform plan` para revisar cambios
4. Ejecuta `terraform apply` para aplicar
5. Commit y push de los cambios

## Licencia

Este proyecto es para fines educativos y de desarrollo.
