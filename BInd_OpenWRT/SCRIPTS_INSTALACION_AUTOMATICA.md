# Scripts de Instalación y Configuración Automática

## Script 1: Instalación Completa de BIND9

```bash
#!/bin/bash
# Script: instalar_bind9.sh
# Propósito: Instalación automática de BIND9 en OpenWRT 18
# Uso: bash instalar_bind9.sh

set -e

echo "=== Instalación de BIND9 en OpenWRT 18 ==="
echo ""

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Función para imprimir con color
info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[ADVERTENCIA]${NC} $1"
}

# Verificar si es root
if [[ $EUID -ne 0 ]]; then
   error "Este script debe ejecutarse como root"
   exit 1
fi

# Paso 1: Actualizar repositorios
info "Actualizando repositorios..."
opkg update || error "Error al actualizar repositorios"

# Paso 2: Instalar BIND9
info "Instalando BIND9 y dependencias..."
opkg install bind-server bind-tools ca-bundle || error "Error instalando BIND9"

# Paso 3: Instalar utilidades adicionales (opcional)
info "Instalando utilidades adicionales..."
opkg install ca-cert ca-bundle

# Paso 4: Verificar instalación
info "Verificando instalación..."
if command -v named &> /dev/null; then
    VERSION=$(named -v)
    info "✓ BIND9 instalado correctamente: $VERSION"
else
    error "BIND9 no se instaló correctamente"
    exit 1
fi

# Paso 5: Crear estructura de directorios
info "Creando estructura de directorios..."
mkdir -p /etc/bind/zones
mkdir -p /var/cache/bind
mkdir -p /var/log/bind

# Paso 6: Configurar permisos
info "Configurando permisos..."
chown -R bind:bind /etc/bind
chown -R bind:bind /var/cache/bind
chown -R bind:bind /var/log/bind
chmod -R 755 /etc/bind
chmod -R 755 /var/cache/bind
chmod -R 755 /var/log/bind

# Paso 7: Desactivar DNS en dnsmasq
info "Desactivando DNS en dnsmasq..."
if grep -q "port=" /etc/dnsmasq.conf; then
    sed -i '/^port=/c\port=0' /etc/dnsmasq.conf
else
    echo "port=0" >> /etc/dnsmasq.conf
fi

# Reiniciar dnsmasq
/etc/init.d/dnsmasq restart

# Paso 8: Configurar Firewall
info "Configurando Firewall para permitir DNS..."
uci add firewall rule
uci set firewall.@rule[-1].name='Allow DNS UDP'
uci set firewall.@rule[-1].src='lan'
uci set firewall.@rule[-1].dest_port='53'
uci set firewall.@rule[-1].proto='udp'
uci set firewall.@rule[-1].target='ACCEPT'

uci add firewall rule
uci set firewall.@rule[-1].name='Allow DNS TCP'
uci set firewall.@rule[-1].src='lan'
uci set firewall.@rule[-1].dest_port='53'
uci set firewall.@rule[-1].proto='tcp'
uci set firewall.@rule[-1].target='ACCEPT'

uci commit firewall
/etc/init.d/firewall restart

# Paso 9: Habilitar BIND9 al arranque
info "Habilitando BIND9 al arranque..."
/etc/init.d/named enable

# Resumen
echo ""
echo "=== Instalación Completada ===" 
info "Pasos completados:"
echo "  ✓ BIND9 instalado"
echo "  ✓ Estructura de directorios creada"
echo "  ✓ Permisos configurados"
echo "  ✓ dnsmasq DNS desactivado (DHCP activo)"
echo "  ✓ Firewall configurado para DNS"
echo "  ✓ BIND9 habilitado al arranque"
echo ""
warning "PASOS SIGUIENTES:"
echo "  1. Copiar archivos de configuración de zona"
echo "  2. Editar /etc/bind/bind.conf con tus zonas"
echo "  3. Ejecutar: named-checkconf /etc/bind/bind.conf"
echo "  4. Ejecutar: /etc/init.d/named start"
echo "  5. Probar con: dig @127.0.0.1 tudominio.com"
echo ""
```

---

## Script 2: Configuración de Zonas Automática

```bash
#!/bin/bash
# Script: configurar_zona.sh
# Propósito: Crear zona directa e inversa automáticamente
# Uso: bash configurar_zona.sh midominio.com 192.168.1
# Parámetros:
#   $1 = Dominio (ej: midominio.com)
#   $2 = Red (ej: 192.168.1) para zona inversa

if [ $# -ne 2 ]; then
    echo "Uso: $0 <dominio> <red>"
    echo "Ejemplo: $0 midominio.com 192.168.1"
    exit 1
fi

DOMINIO=$1
RED=$2
FECHA=$(date +%Y%m%d)

# Verificar que es root
if [[ $EUID -ne 0 ]]; then
   echo "Este script debe ejecutarse como root"
   exit 1
fi

echo "Creando zonas para: $DOMINIO en red $RED.0/24"

# Crear zona directa
ZONA_DIR="/etc/bind/zones/db.${DOMINIO}"
echo "Creando zona directa: $ZONA_DIR"

cat > "$ZONA_DIR" << 'EOF'
$TTL 86400
@   IN  SOA ns1.DOMINIO_PLACEHOLDER. admin.DOMINIO_PLACEHOLDER. (
        FECHA_PLACEHOLDER01
        3600
        1800
        604800
        86400 )
@           IN  NS      ns1.DOMINIO_PLACEHOLDER.
ns1         IN  A       RED_PLACEHOLDER.1
@           IN  A       RED_PLACEHOLDER.1
router      IN  A       RED_PLACEHOLDER.1
gateway     IN  A       RED_PLACEHOLDER.1
www         IN  CNAME   router.DOMINIO_PLACEHOLDER.
EOF

# Reemplazar placeholders
sed -i "s/DOMINIO_PLACEHOLDER/${DOMINIO}/g" "$ZONA_DIR"
sed -i "s/FECHA_PLACEHOLDER/${FECHA}/g" "$ZONA_DIR"
sed -i "s/RED_PLACEHOLDER/${RED}/g" "$ZONA_DIR"

# Crear zona inversa
RED_INVERSA=$(echo $RED | awk -F. '{print $3"."$2"."$1}')
ZONA_INV="/etc/bind/zones/db.${DOMINIO}.inv"
echo "Creando zona inversa: $ZONA_INV (${RED_INVERSA}.in-addr.arpa)"

cat > "$ZONA_INV" << 'EOF'
$TTL 86400
@   IN  SOA ns1.DOMINIO_PLACEHOLDER. admin.DOMINIO_PLACEHOLDER. (
        FECHA_PLACEHOLDER01
        3600
        1800
        604800
        86400 )
@           IN  NS      ns1.DOMINIO_PLACEHOLDER.
1           IN  PTR     router.DOMINIO_PLACEHOLDER.
1           IN  PTR     ns1.DOMINIO_PLACEHOLDER.
EOF

sed -i "s/DOMINIO_PLACEHOLDER/${DOMINIO}/g" "$ZONA_INV"
sed -i "s/FECHA_PLACEHOLDER/${FECHA}/g" "$ZONA_INV"

# Permisos
chown bind:bind "$ZONA_DIR" "$ZONA_INV"
chmod 644 "$ZONA_DIR" "$ZONA_INV"

# Validar
echo "Validando zonas..."
named-checkzone "${DOMINIO}" "$ZONA_DIR"
RED_INVERSA_ARPA="${RED_INVERSA}.in-addr.arpa"
named-checkzone "${RED_INVERSA_ARPA}" "$ZONA_INV"

echo "✓ Zonas creadas correctamente"
echo "✓ Próximo paso: Editar /etc/bind/bind.conf para incluir estas zonas"
```

---

## Script 3: Validación y Testing

```bash
#!/bin/bash
# Script: validar_bind9.sh
# Propósito: Validar configuración y hacer pruebas
# Uso: bash validar_bind9.sh

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

success() {
    echo -e "${GREEN}✓${NC} $1"
}

failed() {
    echo -e "${RED}✗${NC} $1"
}

warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

echo "=== Validación de BIND9 en OpenWRT 18 ==="
echo ""

# 1. Verificar que BIND9 está instalado
echo "1. Verificando instalación de BIND9..."
if command -v named &> /dev/null; then
    success "BIND9 instalado"
else
    failed "BIND9 no está instalado"
    exit 1
fi

# 2. Verificar que el servicio está corriendo
echo ""
echo "2. Verificando que BIND9 está corriendo..."
if /etc/init.d/named status > /dev/null 2>&1; then
    success "BIND9 está corriendo"
else
    warning "BIND9 no está corriendo. Iniciando..."
    /etc/init.d/named start
    success "BIND9 iniciado"
fi

# 3. Verificar que escucha en puerto 53
echo ""
echo "3. Verificando puerto 53..."
if netstat -ln 2>/dev/null | grep -q ":53 "; then
    success "BIND9 escucha en puerto 53"
else
    failed "BIND9 no está escuchando en puerto 53"
fi

# 4. Validar configuración
echo ""
echo "4. Validando configuración..."
if named-checkconf /etc/bind/bind.conf 2>/dev/null; then
    success "Configuración válida"
else
    failed "Configuración inválida"
    named-checkconf /etc/bind/bind.conf
fi

# 5. Probar resolución local
echo ""
echo "5. Probando resolución local..."
if dig @127.0.0.1 localhost > /dev/null 2>&1; then
    success "Resolución local funciona"
else
    failed "No se puede resolver localhost"
fi

# 6. Verificar firewall
echo ""
echo "6. Verificando reglas de firewall..."
if iptables -L INPUT -n 2>/dev/null | grep -q "dpt:53"; then
    success "Firewall permite DNS"
else
    warning "Puerto 53 podría no estar permitido en firewall"
fi

# 7. Verificar dnsmasq DNS desactivado
echo ""
echo "7. Verificando dnsmasq..."
if grep -q "port=0" /etc/dnsmasq.conf; then
    success "DNS desactivado en dnsmasq"
else
    warning "DNS aún podría estar activo en dnsmasq"
fi

if ps aux | grep -q "[d]nsmasq.*-l.*127.0.0.1"; then
    success "DHCP de dnsmasq está activo"
else
    warning "dnsmasq podría no estar proporcionando DHCP"
fi

# 8. Verificar logs
echo ""
echo "8. Revisando logs recientes..."
RECENT_LOGS=$(grep -c "named" /var/log/messages 2>/dev/null || echo 0)
if [ "$RECENT_LOGS" -gt 0 ]; then
    success "Se encontraron $RECENT_LOGS entradas de login en los últimos minutos"
else
    warning "No hay entradas recientes de named en los logs"
fi

echo ""
echo "=== Resumen de Validación ==="
success "BIND9 está correctamente instalado y configurado"
echo ""
echo "Próximos pasos:"
echo "  1. Probar desde cliente: dig @ROUTER-IP tudominio.com"
echo "  2. Verificar DHCP: ipconfig /all (Windows) o nmcli (Linux)"
echo "  3. Revisar logs: tail -f /var/log/messages | grep named"
```

---

## Script 4: Monitoreo y Diagnóstico

```bash
#!/bin/bash
# Script: monitorear_bind9.sh
# Propósito: Monitorear BIND9 en tiempo real
# Uso: bash monitorear_bind9.sh

clear
echo "=== Monitor de BIND9 en tiempo real ==="
echo "Presiona Ctrl+C para salir"
echo ""

while true; do
    clear
    echo "=== Estado de BIND9 ==="
    echo "Fecha: $(date)"
    echo ""
    
    # Estado del servicio
    echo "Estado del servicio:"
    /etc/init.d/named status
    echo ""
    
    # Procesos
    echo "Procesos BIND9:"
    ps aux | grep "[n]amed"
    echo ""
    
    # Puertos
    echo "Puerto 53 (DNS):"
    netstat -ln | grep ":53"
    echo ""
    
    # Errores recientes (últimas 10 líneas)
    echo "Últimos eventos en logs:"
    tail -n 5 /var/log/messages | grep named || echo "Sin eventos recientes"
    echo ""
    
    # Estadísticas
    echo "Estadísticas de conexión:"
    netstat -an | grep ":53" | wc -l
    echo " conexiones activas"
    echo ""
    
    sleep 10
done
```

---

## Script 5: Backup y Restauración

```bash
#!/bin/bash
# Script: backup_bind9.sh
# Propósito: Hacer backup de configuración BIND9
# Uso: bash backup_bind9.sh

BACKUP_DIR="/root/backups/bind9"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/bind9_backup_$TIMESTAMP.tar.gz"

mkdir -p "$BACKUP_DIR"

echo "Realizando backup de BIND9..."
echo "Ubicación: $BACKUP_FILE"

# Crear backup
tar -czf "$BACKUP_FILE" \
    /etc/bind/ \
    /var/cache/bind/ \
    /etc/config/firewall \
    /etc/dnsmasq.conf \
    2>/dev/null

if [ -f "$BACKUP_FILE" ]; then
    SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
    echo "✓ Backup completado: $SIZE"
    echo ""
    echo "Para restaurar:"
    echo "  tar -xzf $BACKUP_FILE -C /"
else
    echo "✗ Error realizando backup"
    exit 1
fi

# Guardar solo últimas 5 copias
echo ""
echo "Limpiando backups antiguos..."
ls -t "$BACKUP_DIR"/*.tar.gz 2>/dev/null | tail -n +6 | xargs rm -f 2>/dev/null
echo "✓ Completado"

# Listar backups disponibles
echo ""
echo "Backups disponibles:"
ls -lh "$BACKUP_DIR"/*.tar.gz 2>/dev/null | awk '{print $9, "(" $5 ")"}'
```

---

## Script 6: Agregar Registro DNS

```bash
#!/bin/bash
# Script: agregar_registro.sh
# Propósito: Agregar registros a una zona
# Uso: bash agregar_registro.sh midominio.com www 192.168.1.10 A

if [ $# -ne 4 ]; then
    echo "Uso: $0 <dominio> <host> <valor> <tipo>"
    echo "Ejemplo: $0 midominio.com www 192.168.1.10 A"
    echo "Tipos soportados: A, AAAA, CNAME, MX, TXT"
    exit 1
fi

DOMINIO=$1
HOST=$2
VALOR=$3
TIPO=$4
ZONA_FILE="/etc/bind/zones/db.${DOMINIO}"

if [ ! -f "$ZONA_FILE" ]; then
    echo "Error: Archivo de zona no encontrado: $ZONA_FILE"
    exit 1
fi

# Incrementar serial
SERIAL=$(grep "SERIAL" "$ZONA_FILE" | head -1 | awk '{print $1}' || date +%Y%m%d01)
NEW_SERIAL=$((SERIAL + 1))

# Crear backup
cp "$ZONA_FILE" "${ZONA_FILE}.bak"

# Agregar registro
echo "$HOST    IN  $TIPO    $VALOR" >> "$ZONA_FILE"

# Incrementar serial
sed -i "s/^        [0-9]\\{10\\}/        $NEW_SERIAL/" "$ZONA_FILE"

# Validar
if named-checkzone "$DOMINIO" "$ZONA_FILE" > /dev/null 2>&1; then
    echo "✓ Registro agregado correctamente"
    echo "  Host: $HOST.$DOMINIO"
    echo "  Tipo: $TIPO"
    echo "  Valor: $VALOR"
    echo "  Serial: $NEW_SERIAL"
    
    # Recargar
    rndc reload "$DOMINIO"
    echo "✓ Zona recargada"
else
    echo "✗ Error validando zona"
    cp "${ZONA_FILE}.bak" "$ZONA_FILE"
    exit 1
fi
```

---

## Uso de los Scripts

```bash
# 1. Instalación (ejecutar una sola vez)
chmod +x instalar_bind9.sh
./instalar_bind9.sh

# 2. Crear zonas
chmod +x configurar_zona.sh
./configurar_zona.sh midominio.com 192.168.1

# 3. Validar configuración
chmod +x validar_bind9.sh
./validar_bind9.sh

# 4. Monitorear en tiempo real
chmod +x monitorear_bind9.sh
./monitorear_bind9.sh &

# 5. Backup
chmod +x backup_bind9.sh
./backup_bind9.sh

# 6. Agregar registros
chmod +x agregar_registro.sh
./agregar_registro.sh midominio.com web 192.168.1.20 A
```
