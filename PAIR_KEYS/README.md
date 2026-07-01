# Claves SSH — SIFA

Este directorio contiene las claves SSH utilizadas para acceder a las instancias EC2 del proyecto SIFA.

## ⚠️ Importante

- **Nunca versiones** tus claves privadas en Git. Este directorio está excluido en `.gitignore`.
- La clave debe llamarse **`SIFA-KEY.pem`** según la configuración en `main.tf`.
- El permiso debe ser `400` (solo lectura para el propietario).

## Crear una clave nueva

### Opción 1: Desde AWS (recomendado)

```bash
aws ec2 create-key-pair --key-name SIFA-KEY --query 'KeyMaterial' --output text > PAIR_KEYS/SIFA-KEY.pem
chmod 400 PAIR_KEYS/SIFA-KEY.pem
```

### Opción 2: Importar una clave pública existente

```bash
aws ec2 import-key-pair --key-name SIFA-KEY --public-key-material fileb://~/.ssh/id_rsa.pub
```

Luego copia tu clave privada a este directorio:

```bash
cp ~/.ssh/id_rsa PAIR_KEYS/SIFA-KEY.pem
chmod 400 PAIR_KEYS/SIFA-KEY.pem
```

## Archivos en este directorio

| Archivo | Propósito |
|---|---|
| `SIFA-KEY.pem` | Clave privada (crear localmente, no versionada) |
| `exampleKey.pem` | Placeholder indicativo — reemplazar con la clave real |

## Uso

```bash
# Cargar clave en el agente SSH
ssh-add PAIR_KEYS/SIFA-KEY.pem

# Conectar al gateway (reemplazar con IP real)
ssh -A ubuntu@<IP_PUBLICA_GATEWAY>
```

## Documentación relacionada

- [Conexión SSH a instancias privadas](../DOCS/SSHEC2PublicToEC2Private.md)
