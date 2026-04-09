# Troubleshooting, Optimización y Mejores Prácticas

## Parte 1: Troubleshooting Completo

### Problema 1: BIND9 No Inicia

#### Síntoma
```
# /etc/init.d/named start
[FAILED]
```

#### Diagnóstico
```bash
# Ver error específico
/etc/init.d/named start 2>&1

# Ver si el proceso quedó activo
ps aux | grep named

# Revisar logs
tail /var/log/messages | grep named
```

#### Soluciones

**1. Validar Configuración**
```bash
named-checkconf /etc/bind/bind.conf -z

# Si hay errores, se muestran línea por línea
```

**2. Verificar Permisos**
```bash
# Permisos de archivos
ls -la /etc/bind/bind.conf
ls -la /etc/bind/zones/

# Deben ser:
# -rw-r--r-- bind:bind

# Corregir permisos
chown bind:bind /etc/bind -R
chmod 755 /etc/bind
chmod 644 /etc/bind/bind.conf
chmod 644 /etc/bind/zones/db.*
```

**3. Puerto 53 Ocupado**
```bash
# Ver qué usa puerto 53
lsof -i :53 2>/dev/null || netstat -ln | grep 53

# Si dnsmasq está usando:
/etc/init.d/dnsmasq stop
echo "port=0" >> /etc/dnsmasq.conf
/etc/init.d/dnsmasq restart

# Reintentar iniciar BIND9
/etc/init.d/named start
```

**4. Sintaxis de Configuración**
```bash
# Errores comunes:
# - Falta punto y coma al final de líneas
# - Comillas incorrectas
# - Llaves no cerradas
# - Path relativos en lugar de absolutos

# Buscar errores específicos
cat /etc/bind/bind.conf | grep -n "^}"

# Usar named-checkconf con verbosidad
named-checkconf -x /etc/bind/bind.conf
```

---

### Problema 2: BIND9 Inicia pero No Responde

#### Síntoma
```bash
dig @127.0.0.1 midominio.com
# Timeout o sin respuesta
```

#### Diagnóstico
```bash
# 1. Verificar que el proceso está corriendo
ps aux | grep named

# 2. Verificar que escucha en puerto 53
netstat -ln | grep 53

# 3. Revisar logs
tail -f /var/log/messages | grep named

# 4. Probar con verbose
dig @127.0.0.1 midominio.com +v

# 5. Verificar conectividad
telnet 127.0.0.1 53
```

#### Soluciones

**1. BIND9 No Escucha**
```bash
# En bind.conf, asegurar que listen-on está configurado

options {
    listen-on port 53 { any; };
    listen-on-v6 port 53 { any; };
};

# Recargar
rndc reload
```

**2. ACL Restringida**
```bash
# Si las queries vienen de la LAN pero se niega:
acl "lan" {
    192.168.1.0/24;
    127.0.0.1;
};

options {
    allow-query { lan; };
};

# Recargar
rndc reload
```

**3. Sistema de Archivos Lleno**
```bash
# Verificar espacio disco
df -h

# Si /var está lleno, limpiar logs antiguos
find /var/log -name "*.log" -mtime +30 -delete
```

**4. Memoria Insuficiente**
```bash
# Ver carga y memoria
free -m
top -b -n 1 | head -20

# Si hay poco RAM, reducir cache en BIND9
options {
    max-cache-size 32m;
};

rndc reload
```

---

### Problema 3: Zona No Carga

#### Síntoma
```bash
named-checkzone midominio.com /etc/bind/zones/db.midominio.com

# Salida:
zone midominio.com/IN: loading from master file /etc/bind/zones/db.midominio.com failed: file not found
```

#### Diagnóstico
```bash
# 1. Verificar que el archivo existe
ls -la /etc/bind/zones/db.midominio.com

# 2. Verificar permisos
# Debe ser legible por bind:bind

# 3. Verificar sintaxis del archivo
# Usar editor para buscar errores
```

#### Soluciones

**1. Archivo no Existe**
```bash
# Crear archivo desde la plantilla
cat > /etc/bind/zones/db.midominio.com << 'EOF'
$TTL 86400
@   IN  SOA ns1.midominio.com. admin.midominio.com. (
        2024040901
        3600
        1800
        604800
        86400 )
@           IN  NS      ns1.midominio.com.
EOF

chown bind:bind /etc/bind/zones/db.midominio.com
chmod 644 /etc/bind/zones/db.midominio.com
```

**2. Permisos Incorrectos**
```bash
# Corregir propietario
chown bind:bind /etc/bind/zones/db.midominio.com

# Corregir permisos
chmod 644 /etc/bind/zones/db.midominio.com

# Verificar
ls -la /etc/bind/zones/db.midominio.com
```

**3. Errores en Sintaxis de Zona**
```bash
# Buscar líneas problemáticas
cat -n /etc/bind/zones/db.midominio.com | grep -v "^.*IN"

# Errores típicos:
# - Faltan puntos finales en FQDN
# - Caracteres ilícitos
# - TTL inválido
# - Tipos de registro incorrectos

# Ejemplo de error:
# web    IN  A    192.168.1.10    <- Correcto
# web    IN  A    192.168.1.10 x  <- Error (carácter extra)
# web    IN  CNAME web            <- Error (falta punto)
```

---

### Problema 4: Query Denied (Consulta Rechazada)

#### Síntoma
```bash
dig @127.0.0.1 midominio.com

# Salida:
;; Query denied by BIND
```

#### Diagnóstico
```bash
# Ver logs específicos
grep "query:" /var/log/messages | grep "denied"

# Ver ACL configurada
grep -A5 "allow-query" /etc/bind/bind.conf

# Verificar IP del cliente
hostname -I

# Probar desde localhost
dig @127.0.0.1 midominio.com +v
```

#### Soluciones

**1. ACL Incompleta**
```bash
# En bind.conf, agregar IP cliente a ACL
acl "lan" {
    192.168.1.0/24;     # Esta red debe incluir al cliente
    127.0.0.1;
};

options {
    allow-query { lan; };
};

rndc reload
```

**2. ACL Muy Restringida**
```bash
# Si solo permite localhost:
acl "local" { 127.0.0.1; };

# Cambiar a:
acl "local" { any; };  # O especificar redes

rndc reload
```

**3. Firewall Bloqueando**
```bash
# Verificar reglas en iptables
iptables -L INPUT -n | grep 53

# Si no hay reglas, agregar
uci add firewall rule
uci set firewall.@rule[-1].src='lan'
uci set firewall.@rule[-1].dest_port='53'
uci set firewall.@rule[-1].proto='udp'
uci set firewall.@rule[-1].target='ACCEPT'

uci commit firewall
/etc/init.d/firewall restart
```

---

### Problema 5: NXDOMAIN (Dominio No Existe)

#### Síntoma
```bash
dig midominio.com

# Salida:
;; ->>HEADER<<- opcode: QUERY, status: NXDOMAIN, id: 12345
```

#### Diagnóstico
```bash
# El registro no existe en la zona

# 1. Verificar que la zona existe
named-checkzone midominio.com /etc/bind/zones/db.midominio.com

# 2. Buscar el registro en la zona
grep "^web" /etc/bind/zones/db.midominio.com

# 3. Verificar configuración recursiva
grep -i "recursion" /etc/bind/bind.conf
```

#### Soluciones

**1. Registro No Existe**
```bash
# Agregar el registro a la zona
echo "web    IN  A    192.168.1.20" >> /etc/bind/zones/db.midominio.com

# Incrementar serial
# Cambiar: 2024040901 a 2024040902

# Validar y recargar
named-checkzone midominio.com /etc/bind/zones/db.midominio.com
rndc reload midominio.com
```

**2. Zona No Cargada**
```bash
# Verificar que la zona está en bind.conf
grep "zone \"midominio.com\"" /etc/bind/bind.conf

# Revisar logs
grep "midominio.com" /var/log/messages
```

**3. Recursión Desactivada (para internet)**
```bash
# Si necesitas resolver dominios de internet:
options {
    recursion yes;
    forwarders {
        8.8.8.8;
        1.1.1.1;
    };
};

rndc reload
```

---

### Problema 6: Zona Inversa No Funciona

#### Síntoma
```bash
dig -x 192.168.1.10
# Status: NXDOMAIN
```

#### Diagnóstico
```bash
# 1. Verificar zona inversa configurada
grep "in-addr.arpa" /etc/bind/bind.conf

# 2. Verificar archivo existe
ls -la /etc/bind/zones/db.*.inv

# 3. Verificar sintaxis
named-checkzone 1.168.192.in-addr.arpa /etc/bind/zones/db.midominio.com.inv

# 4. Buscar el registro
grep "^10" /etc/bind/zones/db.midominio.com.inv
```

#### Soluciones

**1. Zona Inversa No Configurada**
```bash
# En bind.conf agregar:
zone "1.168.192.in-addr.arpa" {
    type master;
    file "/etc/bind/zones/db.midominio.com.inv";
};

rndc reload
```

**2. Registros PTR Faltantes**
```bash
# En archivo de zona inversa:
# Para IP 192.168.1.10:
# El octeto final (10) se convierte en:
10    IN  PTR    web.midominio.com.

# Nota: SIEMPRE con punto final
```

**3. Octetos Invertidos Incorrectamente**
```bash
# Para red 192.168.1.0/24:
# Red "normal": 192.168.1
# Zona inversa: 1.168.192.in-addr.arpa

# Errores comunes:
# 192.168.1.in-addr.arpa    <- Error
# 1.168.192.in-addr.arpa    <- Correcto

# Para red 10.0.0.0/24:
# Red "normal": 10.0.0
# Zona inversa: 0.0.10.in-addr.arpa
```

---

## Parte 2: Optimización de Rendimiento

### 1. Cache Optimization

```named
options {
    // Tamaño máximo de cache
    max-cache-size 128m;
    
    // Tamaño máximo de cache por zona
    max-cache-ttl 604800;        // 7 días
    max-ncache-ttl 86400;         // 1 día para NXDOMAIN
    
    // Estadísticas de cache
    statistics-channels {
        inet 127.0.0.1 port 8053 allow { 127.0.0.1; };
    };
};

# Ver estadísticas
rndc stats
# Los datos se escriben en /var/cache/bind/named.stats
```

### 2. Query Optimization

```named
options {
    // Consultas recursivas más rápidas
    recursion yes;
    
    // Reducir latencia con forwarders cercanos
    forwarders {
        8.8.8.8;           // Google (bajo latency)
        1.1.1.1;           // Cloudflare (bajo latency)
    };
    
    // Timeout corto para forwarders
    forward-timeout 2;   // 2 segundos
};
```

### 3. Zone Transfers Optimization

```named
zone "midominio.com" {
    type master;
    file "/etc/bind/zones/db.midominio.com";
    
    // Permitir transferencias
    allow-transfer { 
        127.0.0.1;
        // Agregar IPs de servidores secundarios
    };
    
    // Notificar a servidores secundarios
    notify yes;
    also-notify {
        192.168.1.100;  // Servidor secundario
    };
};
```

### 4. Memory & CPU Optimization

```named
options {
    // Limitar número de conexiones
    listen-on-v6 port 53 { ::1; };
    
    // Reducir uso de CPU
    recursion yes;
    
    // Limitar tamaño de respuestas
    max-cache-size 64m;
    
    // Query rate limiting
    rate-limit {
        responses-per-second 100;
        window 15;
    };
};
```

---

## Parte 3: Mejores Prácticas

### 1. Seguridad

#### 1.1 DNSSEC
```bash
# Verificar que DNSSEC está habilitado
grep "dnssec" /etc/bind/bind.conf

# Debe estar:
options {
    dnssec-validation auto;
};

# Para zonas locales, desactivar para mejor rendimiento
zone "empresa.local" {
    type master;
    file "/etc/bind/zones/db.empresa.local";
    dnssec-validation no;
};
```

#### 1.2 ACL Estrictas
```named
# En lugar de:
allow-query { any; };

# Usar:
acl "trusted" {
    192.168.1.0/24;      // LAN
    127.0.0.1;           // Localhost
    // Agregar otros servidores si es necesario
};

options {
    allow-query { trusted; };
    allow-recursion { trusted; };
    allow-transfer { 127.0.0.1; };
};
```

#### 1.3 Deshabilitar Transferencias de Zona
```named
zone "midominio.com" {
    type master;
    file "/etc/bind/zones/db.midominio.com";
    
    // Prohibir transferencias
    allow-transfer { none; };
};
```

#### 1.4 Hide Server Information
```named
options {
    // Ocultar versión de BIND
    version "BIND";
    
    // Respuestas breves
    minimal-responses yes;
};
```

### 2. Mantenimiento

#### 2.1 Backup Automático
```bash
#!/bin/bash
# Script: backup_diario.sh

BACKUP_DIR="/root/backups/dns"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

mkdir -p "$BACKUP_DIR"

# Backup completo
tar -czf "$BACKUP_DIR/bind9_$TIMESTAMP.tar.gz" /etc/bind/

# Limpiar backups > 30 días
find "$BACKUP_DIR" -name "*.tar.gz" -mtime +30 -delete

# Cronear
# 0 2 * * * /root/scripts/backup_diario.sh
```

#### 2.2 Serial Increment
```bash
#!/bin/bash
# Script: increment_serial.sh

ZONE_FILE=$1

# Leer serial actual
SERIAL=$(grep "SOA" "$ZONE_FILE" -A1 | tail -1 | awk '{print $1}')

# Incrementar
NEW_SERIAL=$((SERIAL + 1))

# Reemplazar
sed -i "s/^        $SERIAL/        $NEW_SERIAL/" "$ZONE_FILE"

echo "Serial actualizado: $SERIAL -> $NEW_SERIAL"
```

#### 2.3 Verificación Diaria
```bash
#!/bin/bash
# Script: verificacion_diaria.sh

echo "=== Verificación Diaria DNS ===" >> /var/log/dns-check.log
date >> /var/log/dns-check.log

# Validar zonas
for zona in /etc/bind/zones/db.*; do
    named-checkzone "$(basename $zona)" "$zona" >> /var/log/dns-check.log
done

# Verificar servicio
/etc/init.d/named status >> /var/log/dns-check.log

# Test resolución
dig @127.0.0.1 midominio.com +short >> /var/log/dns-check.log

# Cronear
# 0 6 * * * /root/scripts/verificacion_diaria.sh
```

### 3. Documentation

#### Plantilla de Documento
```markdown
# Configuración DNS - Empresa XYZ

## Información General
- Dominio: empresa.com
- Servidor DNS: router.empresa.com (192.168.1.1)
- Red: 192.168.1.0/24
- Contacto: admin@empresa.com

## Zonas Configuradas
1. empresa.com (directa)
2. 1.168.192.in-addr.arpa (inversa)

## Registros Principales
- web: 192.168.1.10
- mail: 192.168.1.11
- srv-db: 192.168.1.50

## Procedimientos
### Agregar Registro
1. Editar /etc/bind/zones/db.empresa.com
2. Incrementar serial
3. named-checkzone empresa.com /etc/bind/zones/db.empresa.com
4. rndc reload empresa.com

### Backup
```bash
tar -czf "/root/backups/dns_$(date +%Y%m%d).tar.gz" /etc/bind/
```

### Monitoreo
```bash
tail -f /var/log/messages | grep named
```

## Contactos y Escalación
- Soporte: admin@empresa.com
- Emergencia: +34 xxx xxx xxx
```

### 4. Capacitación

#### Comandos Esenciales para Administrador
```bash
# Comandos de administración
/etc/init.d/named start          # Iniciar
/etc/init.d/named stop           # Detener
/etc/init.d/named restart        # Reiniciar
/etc/init.d/named enable         # Iniciar al boot
/etc/init.d/named disable        # No iniciar al boot

# Validación
named-checkconf /etc/bind/bind.conf  # Validar config
named-checkzone ZONA /etc/...        # Validar zona

# Monitoreo
rndc status                      # Estado
rndc reload                      # Recargar config
rndc reload ZONA                 # Recargar zona
tail -f /var/log/messages        # Ver logs

# Testing
dig @127.0.0.1 dominio.com
nslookup dominio.com 127.0.0.1
host dominio.com 127.0.0.1
```

---

## Parte 4: Checklist de Health Check

### Health Check Mensual

```bash
#!/bin/bash
# health_check.sh - Ejecutar mensualmente

echo "=== HEALTH CHECK DNS - $(date) ===" > /tmp/dns-health.txt

# 1. Servicio
echo "Estado del Servicio:"
/etc/init.d/named status >> /tmp/dns-health.txt

# 2. Configuración
echo "Validación de Configuración:"
named-checkconf /etc/bind/bind.conf >> /tmp/dns-health.txt

# 3. Zonas
echo "Validación de Zonas:"
for zona in /etc/bind/zones/db.*; do
    named-checkzone "$(basename $zona)" "$zona" >> /tmp/dns-health.txt
done

# 4. Puertos
echo "Puertos en Escucha:"
netstat -ln | grep 53 >> /tmp/dns-health.txt

# 5. Diskspace
echo "Espacio en Disco:"
df -h /etc/bind >> /tmp/dns-health.txt
df -h /var/log >> /tmp/dns-health.txt

# 6. Rendimiento
echo "Tamaño de Logs:"
du -sh /var/log/messages >> /tmp/dns-health.txt

# 7. Errores
echo "Errores en Logs (últimas 24h):"
find /var/log -name "*.log" -mtime -1 -exec grep -i "error" {} + | wc -l >> /tmp/dns-health.txt

# Enviar reporte
mail -s "DNS Health Check - $(hostname)" admin@empresa.com < /tmp/dns-health.txt
```

