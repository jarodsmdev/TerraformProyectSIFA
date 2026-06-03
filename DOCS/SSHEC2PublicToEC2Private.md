# Acceso SSH a Instancias Privadas mediante Bastion Host

Este documento describe cómo conectarse a las instancias EC2 en la subred privada (`sifa-auth`, `sifa-plate`, `sifa-core`) utilizando la instancia pública `sifa-gateway` como bastión.

## Requisitos

- Clave privada `SIFA-KEY.pem` en el directorio `PAIR_KEYS/`
- Agente SSH configurado y corriendo
- Terraform aplicado (para conocer las IPs actuales)

## Obtener las IPs

```bash
# IP pública del gateway (bastion)
terraform output -json public_ec2 | jq -r '.public_ip'

# IPs privadas de los servicios internos
terraform output -json private_ec2 | jq -r '.private_ip'
terraform output -json private_ec2_plate | jq -r '.private_ip'
terraform output -json private_ec2_core | jq -r '.private_ip'
```

## Método 1: SSH Agent Forwarding

### 1. Cargar la clave en el agente SSH

```bash
ssh-add ./PAIR_KEYS/SIFA-KEY.pem
```

### 2. Conectarse al bastión con forwarding

```bash
ssh -A ubuntu@<IP_PUBLICA_GATEWAY>
```

El flag `-A` habilita el forwarding del agente SSH, permitiendo que el bastión use la clave local sin copiarla.

### 3. Saltar a la instancia privada

Desde el bastión:

```bash
ssh ubuntu@<IP_PRIVADA_INSTANCIA>
```

## Método 2: ProxyJump (recomendado)

Requiere una sola conexión directa desde el equipo local:

```bash
ssh -J ubuntu@<IP_PUBLICA_GATEWAY> ubuntu@<IP_PRIVADA_INSTANCIA>
```

Para mayor comodidad, agregar al `~/.ssh/config`:

```
Host sifa-bastion
    HostName <IP_PUBLICA_GATEWAY>
    User ubuntu
    IdentityFile ~/ruta/a/PAIR_KEYS/SIFA-KEY.pem

Host sifa-auth
    HostName 10.0.2.10
    User ubuntu
    ProxyJump sifa-bastion
    IdentityFile ~/ruta/a/PAIR_KEYS/SIFA-KEY.pem

Host sifa-plate
    HostName 10.0.2.20
    User ubuntu
    ProxyJump sifa-bastion
    IdentityFile ~/ruta/a/PAIR_KEYS/SIFA-KEY.pem

Host sifa-core
    HostName 10.0.2.30
    User ubuntu
    ProxyJump sifa-bastion
    IdentityFile ~/ruta/a/PAIR_KEYS/SIFA-KEY.pem
```

Luego conectar directamente:

```bash
ssh sifa-auth
ssh sifa-plate
ssh sifa-core
```

## Consideraciones de Seguridad

- La clave privada `SIFA-KEY.pem` nunca debe copiarse a ningún servidor.
- El security group privado (`sifa-private-sg`) solo permite SSH desde el security group público (`sifa-public-sg`), no desde internet.
- El forwarding del agente SSH (`-A`) debe usarse con precaución en entornos que no sean de confianza.
- Preferir ProxyJump (`-J`) sobre Agent Forwarding cuando sea posible, ya que no expone el agente SSH en el bastión.
