<div align="center">
  <h1>SIFA</h1>
  <p><strong>Sistema de Inteligencia para Fiscalización Automática</strong></p>
  <p>Infraestructura como Código en AWS con Terraform</p>
  <p>
    <img src="https://img.shields.io/badge/Terraform-1.x-844FBA?logo=terraform&logoColor=white" alt="Terraform">
    <img src="https://img.shields.io/badge/AWS-Infrastructure-FF9900?logo=amazonaws&logoColor=white" alt="AWS">
    <img src="https://img.shields.io/badge/IaC-Terraform-7B42BC?logo=terraform&logoColor=white" alt="IaC">
    <img src="https://img.shields.io/badge/Ubuntu-22.04-E95420?logo=ubuntu&logoColor=white" alt="Ubuntu">
    <img src="https://img.shields.io/badge/Docker-Compose-2496ED?logo=docker&logoColor=white" alt="Docker">
    <img src="https://img.shields.io/badge/License-Educational-2ea44f" alt="License">
  </p>
</div>

---

## Tabla de Contenidos

- [Descripción General](#descripción-general)
- [Arquitectura](#arquitectura)
- [Tecnologías](#tecnologías)
- [Estructura del Proyecto](#estructura-del-proyecto)
- [Requisitos Previos](#requisitos-previos)
- [Configuración Inicial](#configuración-inicial)
- [Despliegue](#despliegue)
- [Comandos Útiles](#comandos-útiles)
- [Variables](#variables)
- [Outputs](#outputs)
- [Seguridad](#seguridad)
- [Resolución de Problemas](#resolución-de-problemas)
- [Limpieza de Recursos](#limpieza-de-recursos)
- [Contribuir](#contribuir)
- [Licencia](#licencia)

---

## Descripción General

**SIFA** es una aplicación distribuida compuesta por múltiples microservicios desplegados en instancias EC2 de AWS. La infraestructura se gestiona completamente con **Terraform**, utilizando un backend remoto en S3 para el almacenamiento del estado con lock file.

### Componentes de la Infraestructura

| Componente | Tipo | Descripción |
|---|---|---|
| API Gateway | EC2 Pública con EIP | Punto de entrada con exposición a internet |
| Auth Service | EC2 Privada | Servicio de autenticación |
| Plate Service | EC2 Privada | Servicio de gestión de platos/comidas |
| SIFA Core | EC2 Privada (IAM S3) | Servicio principal con acceso a S3 |
| MySQL | EC2 Pública con EIP opcional | Base de datos MySQL |
| S3 Images | Bucket S3 | Almacenamiento público para imágenes |

---

## Arquitectura

La infraestructura sigue un patrón de **red con subnets públicas y privadas**, utilizando un **NAT Gateway** para que las instancias privadas accedan a internet sin exposición directa.

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
                |  EIP      |                         |    sifa-      |
                | 44.x.x.x  |                         |    plate      |
                +-----------+                         |    10.0.2.20  |
                |  sifa-    |                         +---------------+
                |  mysql    |                         |    sifa-      |
                | 10.0.1.40 |                         |    core       |
                +-----------+                         |    10.0.2.30  |
                |  EIP       |                        +---------------+
                | (opcional) |
                +-----------+
```

### Componentes de Red

| Componente | Recurso AWS | Detalle |
|---|---|---|
| **VPC** | `aws_vpc` | 10.0.0.0/16 |
| **Subnet Pública** | `aws_subnet` | 10.0.1.0/24 en us-east-1a |
| **Subnet Privada** | `aws_subnet` | 10.0.2.0/24 en us-east-1a |
| **Internet Gateway** | `aws_internet_gateway` | Conectividad directa a internet |
| **NAT Gateway** | `aws_nat_gateway` | Salida a internet desde subred privada |
| **EIP NAT** | `aws_eip` | IP elástica asociada al NAT Gateway |

### Flujo de Tráfico

1. **Internet → API Gateway**: El tráfico HTTP llega al Internet Gateway y se enruta a `sifa-gateway` (puerto 80).
2. **Gateway → Servicios Privados**: `sifa-gateway` reenvía peticiones a `sifa-auth`, `sifa-plate` o `sifa-core` en la subred privada (puerto 80).
3. **Salida a internet desde privada**: Las instancias privadas salen a internet a través del NAT Gateway.
4. **SIFA Core → S3**: `sifa-core` tiene un perfil IAM (`EMR_EC2_DefaultRole`) que permite acceder al bucket S3 de imágenes.

> **Nota**: Existe un `time_sleep` de 90s (`wait_for_nat`) que retrasa el lanzamiento de las instancias privadas hasta que el NAT Gateway esté operativo.

---

## Tecnologías

| Tecnología | Versión | Propósito |
|---|---|---|
| [Terraform](https://www.terraform.io/) | >= 1.0 | Infraestructura como Código |
| [AWS](https://aws.amazon.com/) | - | Proveedor cloud |
| [Ubuntu](https://ubuntu.com/) | 22.04 LTS | Sistema operativo (AMI) |
| [Docker](https://www.docker.com/) | latest | Contenedores en EC2 |
| [MySQL](https://www.mysql.com/) | 8.0+ | Base de datos relacional |
| [S3](https://aws.amazon.com/s3/) | - | Almacenamiento de imágenes |

---

## Estructura del Proyecto

```
.
├── main.tf                     # Configuración principal del proyecto
├── variables.tf                # Definición de variables raíz (actualmente vacío)
├── outputs.tf                  # Outputs de la infraestructura
├── .terraform.lock.hcl         # Lock file de proveedores (NO versionado — ver .gitignore)
├── .gitignore                  # Archivos ignorados por Git
├── modules/                    # Módulos reutilizables
│   ├── vpc/                    # Red virtual (VPC, subnets, NAT Gateway, routing)
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── ec2/                    # Instancias EC2 genéricas
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── mysql/                  # Instancia EC2 con MySQL
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── sg/                     # Security Groups
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── s3/                     # Bucket S3
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── scripts/                # Scripts de inicialización (user_data)
│       └── docker-install.sh   # Instalación de Docker en EC2
├── bootstrap/                  # Backend remoto (creación del bucket S3 para estado)
│   ├── backend-bootstrap.tf
│   └── terraform.tfstate       # Estado local del bootstrap
├── DOCS/                       # Documentación adicional
│   ├── ARCHITECTURE.md         # Arquitectura detallada
│   └── SSHEC2PublicToEC2Private.md  # Conexión SSH a instancias privadas
└── PAIR_KEYS/                  # Claves SSH (no versionadas)
    ├── README.md               # Instrucciones para las claves
    └── exampleKey.pem          # Placeholder — reemplazar con tu clave real
```

---

## Requisitos Previos

### Herramientas

| Herramienta | Versión Mínima | Instalación |
|---|---|---|
| **Terraform** | >= 1.0 | [Descargar](https://www.terraform.io/downloads) |
| **AWS CLI** | >= 2.x | `pip install awscli` o [descargar](https://aws.amazon.com/cli/) |

### Instalación Rápida de Terraform (Ubuntu/Debian)

```bash
sudo apt-get update && sudo apt-get install -y wget unzip
wget https://releases.hashicorp.com/terraform/1.7.5/terraform_1.7.5_linux_amd64.zip
sudo unzip terraform_1.7.5_linux_amd64.zip -d /usr/local/bin/
rm terraform_1.7.5_linux_amd64.zip
terraform --version
```

### Recursos AWS Necesarios

Antes de desplegar, asegúrate de contar con:

1. **Key Pair** `SIFA-KEY` en la región us-east-1 (ver [PAIR_KEYS/README.md](./PAIR_KEYS/README.md))
2. **Elastic IP** pre-asignada para el API Gateway
3. **Elastic IP** (opcional) pre-asignada para MySQL

---

## Configuración Inicial

### 1. Configurar credenciales AWS

```bash
aws configure
# AWS Access Key ID: tu_access_key
# AWS Secret Access Key: tu_secret_key
# Default region: us-east-1
# Default output: json
```

O mediante variables de entorno:

```bash
export AWS_ACCESS_KEY_ID="tu_access_key"
export AWS_SECRET_ACCESS_KEY="tu_secret_key"
export AWS_DEFAULT_REGION="us-east-1"
```

### 2. Configurar valores del proyecto en `locals { ... }`

El archivo `main.tf` contiene un bloque `locals { ... }` con todos los valores configurables del proyecto. **Es el punto central de configuración** — revisa y ajusta según tu entorno:

| Variable | Descripción |
|---|---|
| `region` | Región AWS (default: `us-east-1`) |
| `project_name` | Prefijo para nombres de recursos |
| `bucket_name` | Nombre del bucket S3 (debe ser único global) |
| `key_name` | Nombre del key pair EC2 |
| `gateway_eip_allocation_id` | EIP Allocation ID del API Gateway |
| `mysql_allocation_id` | EIP para MySQL o `null` |
| `mysql_user` / `mysql_password` | Credenciales de base de datos |
| `gateway_private_ip` / `auth_private_ip` / `plate_private_ip` / `core_private_ip` / `mysql_private_ip` | IPs privadas estáticas |

```hcl
locals {
  region                        = "us-east-1"
  project_name                  = "SIFA"
  bucket_name                   = "sifa-core-images-quisco"
  key_name                      = "SIFA-KEY"
  gateway_eip_allocation_id     = "eipalloc-XXXXXXXX"  # ← Reemplazar
  mysql_allocation_id           = null                   # o "eipalloc-YYYYYYYY"
  mysql_user                    = "adminroot"
  mysql_password                = "adminroot123"
}
```

> Consulta la [tabla completa de locals](#configuración-local-locals-en-maintf) para todos los valores disponibles.

### 3. Crear el Key Pair de EC2

```bash
aws ec2 create-key-pair --key-name SIFA-KEY --query 'KeyMaterial' --output text > PAIR_KEYS/SIFA-KEY.pem
chmod 400 PAIR_KEYS/SIFA-KEY.pem
```

> Alternativamente, puedes importar una clave existente: `aws ec2 import-key-pair --key-name SIFA-KEY --public-key-material fileb://~/.ssh/id_rsa.pub`

### 4. Configurar el Backend Remoto (S3)

El proyecto usa **S3 como backend remoto** con `use_lockfile`. El bucket `sifa-terraform-state` debe existir antes de inicializar.

**Opción A — Bootstrap con Terraform** (recomendado):

```bash
cd bootstrap/
terraform init
terraform apply -auto-approve
cd ..
```

**Opción B — Manual con AWS CLI**:

```bash
aws s3 mb s3://sifa-terraform-state --region us-east-1
aws s3api put-bucket-versioning --bucket sifa-terraform-state --versioning-configuration Status=Enabled
```

---

## Despliegue

### 1. Inicializar Terraform

```bash
terraform init
```

Descarga los proveedores y configura el backend remoto S3.

### 2. Validar la configuración

```bash
terraform validate     # Verifica sintaxis y estructura
terraform fmt -check   # Verifica formato del código
```

### 3. Revisar el plan

```bash
terraform plan
```

Muestra los recursos que se crearán, modificarán o destruirán.

### 4. Aplicar la infraestructura

```bash
terraform apply
```

Revisa el plan y confirma escribiendo `yes`. Para auto-aprobar:

```bash
terraform apply -auto-approve
```

### 5. Ver outputs

```bash
terraform output
```

Muestra las IPs públicas, privadas e IDs de los recursos creados.

---

## Comandos Útiles

| Comando | Descripción |
|---|---|
| `terraform plan -out=tfplan` | Guarda el plan en un archivo |
| `terraform apply tfplan` | Aplica un plan pre-generado |
| `terraform show` | Muestra el estado actual de la infraestructura |
| `terraform state list` | Lista todos los recursos gestionados |
| `terraform output -json` | Outputs en formato JSON |
| `terraform graph \| dot -Tsvg > graph.svg` | Genera un grafo de dependencias |
| `terraform fmt -recursive` | Formatea todos los archivos `.tf` |

---

## Variables

### Configuración local (`locals` en `main.tf`)

Estos valores se configuran directamente en el archivo `main.tf`:

| Variable | Valor por Defecto | Descripción |
|---|---|---|
| `region` | `us-east-1` | Región de AWS |
| `project_name` | `SIFA` | Nombre del proyecto |
| `bucket_name` | `sifa-core-images-quisco` | Bucket S3 para imágenes |
| `key_name` | `SIFA-KEY` | Key pair de EC2 |
| `ubuntu_ami` | `ami-05cf1e9f73fbad2e2` | AMI Ubuntu 22.04 |
| `gateway_eip_allocation_id` | — | EIP Allocation ID del API Gateway |
| `mysql_allocation_id` | — | EIP Allocation ID de MySQL (o `null`) |
| `gateway_private_ip` | `10.0.1.10` | IP privada del Gateway |
| `auth_private_ip` | `10.0.2.10` | IP privada del Auth Service |
| `plate_private_ip` | `10.0.2.20` | IP privada del Plate Service |
| `core_private_ip` | `10.0.2.30` | IP privada del SIFA Core |
| `mysql_private_ip` | `10.0.1.40` | IP privada de MySQL |
| `mysql_user` | `adminroot` | Usuario de MySQL |
| `mysql_password` | `adminroot123` | Contraseña de MySQL |

> ⚠️ **Seguridad**: Las credenciales de MySQL están hardcodeadas en `locals` para este laboratorio. En producción, usa **variables** o un **secret store** (AWS Secrets Manager / SSM Parameter Store).

### Módulo VPC

| Variable | Tipo | Default | Descripción |
|---|---|---|---|
| `project_name` | `string` | — | Nombre del proyecto para etiquetado |
| `vpc_cidr` | `string` | `10.0.0.0/16` | Bloque CIDR de la VPC |
| `public_subnet_cidr` | `string` | `10.0.1.0/24` | CIDR de la subnet pública |
| `private_subnet_cidr` | `string` | `10.0.2.0/24` | CIDR de la subnet privada |
| `az` | `string` | `us-east-1a` | Zona de disponibilidad |

### Módulo EC2

| Variable | Tipo | Default | Descripción |
|---|---|---|---|
| `name` | `string` | — | Nombre de la instancia |
| `ami` | `string` | `ami-05cf1e9f73fbad2e2` | AMI (Ubuntu 22.04) |
| `instance_type` | `string` | `t3.micro` | Tipo de instancia |
| `subnet_id` | `string` | — | ID de la subnet |
| `security_group_ids` | `list(string)` | — | IDs de security groups |
| `key_name` | `string` | — | Nombre del key pair |
| `associate_eip` | `bool` | `false` | Asociar IP elástica |
| `allocation_id` | `string` | `null` | ID de asignación de EIP |
| `private_ip` | `string` | `null` | IP privada estática |
| `iam_instance_profile` | `string` | `null` | Perfil de IAM |
| `user_data` | `string` | `null` | Script de inicialización |
| `root_volume_size` | `number` | `8` | Tamaño del disco raíz en GB |

### Módulo S3

| Variable | Tipo | Default | Descripción |
|---|---|---|---|
| `bucket_name` | `string` | — | Nombre único global del bucket |
| `project_name` | `string` | — | Nombre del proyecto |
| `versioning` | `bool` | `true` | Habilitar versionado |

### Módulo Security Group

| Variable | Tipo | Descripción |
|---|---|---|
| `name` | `string` | Nombre del security group |
| `description` | `string` | Descripción |
| `vpc_id` | `string` | ID de la VPC |
| `ingress_rules` | `list(object)` | Reglas de entrada |
| `egress_rules` | `list(object)` | Reglas de salida |

### Módulo MySQL

| Variable | Tipo | Default | Descripción |
|---|---|---|---|
| `name` | `string` | — | Nombre de la instancia |
| `ami` | `string` | `ami-05cf1e9f73fbad2e2` | AMI (Ubuntu 22.04) |
| `instance_type` | `string` | `t3.micro` | Tipo de instancia |
| `subnet_id` | `string` | — | ID de la subnet |
| `security_group_ids` | `list(string)` | — | IDs de security groups |
| `key_name` | `string` | — | Nombre del key pair |
| `private_ip` | `string` | `null` | IP privada estática |
| `mysql_user` | `string` | — | Usuario de MySQL |
| `mysql_password` | `string` | — | Contraseña de MySQL |
| `associate_eip` | `bool` | `false` | Asociar IP elástica |
| `allocation_id` | `string` | `null` | ID de asignación de EIP |

---

## Outputs

Después de aplicar Terraform, los siguientes outputs están disponibles:

| Output | Tipo | Descripción |
|---|---|---|
| `vpc_id` | `string` | ID de la VPC |
| `public_ec2` | `object` | `{ name, public_ip, instance_id }` del Gateway |
| `private_ec2` | `object` | `{ name, private_ip, instance_id }` del Auth Service |
| `private_ec2_core` | `object` | `{ name, private_ip }` del SIFA Core |
| `private_ec2_plate` | `object` | `{ name, private_ip }` del Plate Service |
| `mysql` | `object` | `{ name, private_ip, public_ip, instance_id }` de MySQL |

Para consultarlos:

```bash
terraform output                    # Todos los outputs
terraform output public_ec2         # Output específico
terraform output public_ec2
```

---

## Seguridad

### Consideraciones Importantes

| Práctica | Recomendación |
|---|---|
| **Credenciales AWS** | Usa variables de entorno o perfiles AWS CLI — nunca las versiones |
| **Estado de Terraform** | Se almacena en S3 con lock file; contiene información sensible |
| **Clave SSH** | `SIFA-KEY.pem` debe mantenerse segura y **nunca** versionarse (ver [PAIR_KEYS/README.md](./PAIR_KEYS/README.md)) |
| **Security Groups** | Revisa y ajusta las reglas según tus necesidades |
| **Bucket S3** | Actualmente configurado con acceso público de lectura — ajusta las políticas según requisitos |
| **MySQL expuesto** | Puerto 3306 abierto a `0.0.0.0/0` — considera restringirlo en entornos productivos (en este proyecto se deja expuesto para ser accedido desde cualquier IP a modo académico) |
| **IAM Role** | `EMR_EC2_DefaultRole` es un rol genérico; en producción crea un rol con permisos específicos (Se usa este rol en este laboratorio para acceder desde la máquina EC2 Core al bucket S3)|

### Puertos Expuestos

| Puerto | Protocolo | Destino | Origen | Descripción |
|---|---|---|---|---|
| **22** | TCP | API Gateway | `0.0.0.0/0` | SSH público |
| **80** | TCP | API Gateway | `0.0.0.0/0` | HTTP público |
| **22** | TCP | Instancias privadas | `sifa-public-sg` | SSH desde Gateway |
| **80** | TCP | Instancias privadas | `sifa-public-sg` + `10.0.2.0/24` | HTTP interno |
| **3306** | TCP | MySQL | `0.0.0.0/0` + `10.0.2.0/24` | MySQL público e interno |
| **ICMP** | - | API Gateway | `10.0.0.0/16` | Diagnóstico desde VPC |

---

## Resolución de Problemas

### Error: "Bucket sifa-terraform-state does not exist"

El bucket del backend remoto no se ha creado. Ejecuta primero el bootstrap:

```bash
cd bootstrap/
terraform init && terraform apply -auto-approve
cd ..
terraform init
```

### Error: "NoCredentialProviders"

Las credenciales de AWS no están configuradas:

```bash
aws configure
# o exporta las variables de entorno AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY
```

### Error: "InvalidAllocationID.NotFound"

El EIP Allocation ID no corresponde a una IP elástica existente en tu cuenta:

```bash
aws ec2 describe-addresses --query 'Addresses[*].[AllocationId,PublicIp]'
# Actualiza gateway_eip_allocation_id en main.tf con un ID válido
```

### Error: "InvalidKeyPair.NotFound"

El key pair `SIFA-KEY` no existe en la región us-east-1:

```bash
aws ec2 describe-key-pairs --key-names SIFA-KEY
aws ec2 create-key-pair --key-name SIFA-KEY --query 'KeyMaterial' --output text > PAIR_KEYS/SIFA-KEY.pem
```

### Las instancias privadas no tienen conectividad

El NAT Gateway tarda en estar operativo. Terraform espera 90s (`time_sleep.wait_for_nat`), pero si el problema persiste, verifica:

```bash
aws ec2 describe-nat-gateways --filter "Name=vpc-id,Values=$(terraform output -raw vpc_id)"
```

### El lock file de Terraform no se versiona

El archivo `.terraform.lock.hcl` está ignorado por `.gitignore` (patrón `*.hcl`). Para compartir el lock file entre el equipo, elimina `*.hcl` del `.gitignore` o añade `!.terraform.lock.hcl` como excepción.

---

## Limpieza de Recursos

Para destruir toda la infraestructura:

```bash
terraform destroy
```

Para destruir con auto-aprobación:

```bash
terraform destroy -auto-approve
```

> ⚠️ **Advertencia**: Esta acción eliminará **todos** los recursos: EC2, S3, NAT Gateway, EIPs, Security Groups, Subnets y VPC. Los datos en S3 y las bases de datos MySQL se perderán irreversiblemente.

---

## Herramientas Relacionadas

| Herramienta | Repositorio | Propósito |
|---|---|---|
| **MYSQL_TOOLS** | [github.com/jarodsmdev/MYSQL_TOOLS](https://github.com/jarodsmdev/MYSQL_TOOLS) | Backup y restore de la base de datos MySQL |
| **AWS_S3_TOOL** | [github.com/jarodsmdev/AWS_S3_TOOL](https://github.com/jarodsmdev/AWS_S3_TOOL) | Backup y restore del bucket S3 de imágenes |

## Documentación Adicional

- [Arquitectura Detallada](./DOCS/ARCHITECTURE.md)
- [Conexión SSH a Instancias Privadas](./DOCS/SSHEC2PublicToEC2Private.md)
- [Gestión de Claves SSH](./PAIR_KEYS/README.md)

---

## Contribuir

1. Crea una rama para tus cambios:
   ```bash
   git checkout -b feat/mi-mejora
   ```
2. Realiza las modificaciones necesarias (ver [Estructura del Proyecto](#estructura-del-proyecto))
3. Valida los cambios:
   ```bash
   terraform fmt -recursive   # Formatea el código
   terraform validate         # Verifica sintaxis
   terraform plan             # Revisa impacto
   ```
4. Commit y push:
   ```bash
   git add .
   git commit -m "feat: descripción del cambio"
   git push origin feat/mi-mejora
   ```
5. Abre un Pull Request describiendo los cambios y su impacto.

---

## Licencia

Este proyecto es **con fines educativos y de desarrollo**. No está diseñado para uso en producción sin las adaptaciones de seguridad correspondientes.
