# Guía Completa: Instalación y Configuración de BIND9 en OpenWRT 18

## Tabla de Contenidos
1. [Requisitos Previos](#requisitos-previos)
2. [Instalación de BIND9](#instalación-de-bind9)
3. [Desactivación de dnsmasq para DNS](#desactivación-de-dnsmasq-para-dns)
4. [Configuración del Firewall](#configuración-del-firewall)
5. [Configuración de Zonas](#configuración-de-zonas)
6. [Verificación de la Configuración](#verificación-de-la-configuración)
7. [Monitoreo y Resolución de Problemas](#monitoreo-y-resolución-de-problemas)

---

## Requisitos Previos

- Dispositivo con OpenWRT 18 instalado
- Acceso SSH al router (usuario: root)
- Una conexión a internet funcional
- Conocimientos básicos de redes y DNS
- IP local conocida del router (ejemplo: 192.168.1.1)

---

## 1. Instalación de BIND9

### Paso 1.1: Actualizar el Sistema

```bash
# Conectarse al router
ssh root@192.168.1.1

# Actualizar la lista de paquetes
opkg update
```

### Paso 1.2: Instalar BIND9

```bash
# Instalar bind9 (servidor DNS)
opkg install bind-server

# Instalar utilidades de administración (opcional pero recomendado)
opkg install bind-tools
```

### Paso 1.3: Verificar la Instalación

```bash
# Verificar que bind está instalado
which named

# Comprobar la versión
named -v

# Salida esperada:
# BIND 9.xx.xx ...
```

### Paso 1.4: Estructura de Directorios

Los archivos principales de BIND9 en OpenWRT están en:

```
/etc/bind/               # Directorio de configuración
├── bind.conf            # Archivo de configuración principal
├── named.conf           # Enlace simbólico a bind.conf
├── zones/               # Directorio para los archivos de zona
│   ├── db.midominio.com
│   └── db.midominio.com.inv
└── bind.keys            # Claves DNSSEC
```

---

## 2. Desactivación de dnsmasq para DNS

### Paso 2.1: Preservar DHCP, Desactivar DNS

dnsmasq proporciona dos servicios:
- **DHCP**: Asignación de direcciones IP (MANTENER)
- **DNS**: Resolución de nombres (DESACTIVAR)

```bash
# Editar la configuración de dnsmasq
vi /etc/dnsmasq.conf

# Comentar o eliminar las líneas:
# port=53                 # Desactivar DNS
# DNS escucha en puerto 53 por defecto
```

### Paso 2.2: Configurar dnsmasq para No Usar DNS

```bash
# Agregar estas líneas al dnsmasq.conf
port=0                    # Desactiva DNS en dnsmasq, deja DHCP activo

# También se puede usar:
# no-resolv               # No usar /etc/resolv.conf
```

### Paso 2.3: Actualizar Resolución de Nombres Local

```bash
# Editar resolv.conf para apuntar a BIND9 localmente
vi /etc/resolv.conf

# Agregar:
nameserver 127.0.0.1      # El servidor BIND9 local
nameserver 8.8.8.8        # Google DNS como fallback
```

### Paso 2.4: Reiniciar Servicios

```bash
# Reiniciar dnsmasq (solo DHCP)
/etc/init.d/dnsmasq restart

# Verificar que dnsmasq sigue activo (DHCP)
ps aux | grep dnsmasq
```

---

## 3. Configuración del Firewall

OpenWRT usa nftables o iptables. Necesitamos permitir que los clientes usen DNS en BIND9.

### Paso 3.1: Configurar Firewall para DNS (OpenWRT 18)

```bash
# Editar la configuración del firewall
vi /etc/config/firewall

# Agregar esta regla en la sección de INPUT (permitir DNS desde LAN):
uci add firewall rule
uci set firewall.@rule[-1].name='Allow DNS TCP'
uci set firewall.@rule[-1].src='lan'
uci set firewall.@rule[-1].dest='*'
uci set firewall.@rule[-1].dest_port='53'
uci set firewall.@rule[-1].proto='tcp'
uci set firewall.@rule[-1].target='ACCEPT'

uci add firewall rule
uci set firewall.@rule[-1].name='Allow DNS UDP'
uci set firewall.@rule[-1].src='lan'
uci set firewall.@rule[-1].dest='*'
uci set firewall.@rule[-1].dest_port='53'
uci set firewall.@rule[-1].proto='udp'
uci set firewall.@rule[-1].target='ACCEPT'

# Guardar cambios
uci commit firewall

# Reiniciar firewall
/etc/init.d/firewall restart
```

### Paso 3.2: Método Alternativo (Editar directamente)

```bash
vi /etc/config/firewall

# Agregar al final:
config rule
	option name 'Allow DNS TCP'
	option src 'lan'
	option dest_port '53'
	option proto 'tcp'
	option target 'ACCEPT'

config rule
	option name 'Allow DNS UDP'
	option src 'lan'
	option dest_port '53'
	option proto 'udp'
	option target 'ACCEPT'
```

### Paso 3.3: Configurar DHCP para Avisar del Nuevo Servidor DNS

```bash
# Editar configuración de red
vi /etc/config/dhcp

# En la sección lan, agregar:
list dhcp_option '6,192.168.1.1'  # IP del router como servidor DNS

# O usar el comando:
uci set dhcp.lan.dhcp_option='6,192.168.1.1'
uci commit dhcp
/etc/init.d/dnsmasq restart
```

---

## 4. Configuración de Zonas (Directa e Inversa)

### Paso 4.1: Crear Archivo de Configuración Principal de BIND9

```bash
# Crear o editar el archivo principal
vi /etc/bind/bind.conf

# Contenido:
```

#### Archivo: `/etc/bind/bind.conf`

```named
// Configuración principal de BIND9 en OpenWRT
acl "lan" {
    192.168.1.0/24;     // Rango de la LAN
    127.0.0.1;          // Localhost
};

options {
    directory "/var/cache/bind";
    
    // Solo permitir consultas desde la LAN
    allow-query { lan; };
    
    // Forwarders para consultas recursivas a internet
    forwarders {
        8.8.8.8;        // Google DNS
        1.1.1.1;        // Cloudflare DNS
    };
    
    // Permitir transferencias solo desde localhost
    allow-transfer { 127.0.0.1; };
    
    // Logging
    querylog yes;
    
    // Performance
    recursion yes;
    allow-recursion { lan; };
    
    // Seguridad
    version "BIND";
};

// Zona ROOT (puede omitirse en configuraciones locales simples)
zone "." {
    type hint;
    file "/etc/bind/db.root";
};

// Zona Directa - Ejemplo: midominio.com
zone "midominio.com" {
    type master;
    file "/etc/bind/zones/db.midominio.com";
    allow-update { none; };
    allow-transfer { 127.0.0.1; };
};

// Zona Inversa - Ejemplo: 192.168.1.0/24
zone "1.168.192.in-addr.arpa" {
    type master;
    file "/etc/bind/zones/db.midominio.com.inv";
    allow-update { none; };
    allow-transfer { 127.0.0.1; };
};

// Logging
logging {
    channel "default_syslog" {
        syslog local2;
        severity debug;
        print-time yes;
        print-severity yes;
        print-category yes;
    };
    
    category default {
        "default_syslog";
    };
    
    category queries {
        "default_syslog";
    };
};
```

### Paso 4.2: Crear Directorio de Zonas

```bash
# Crear directorio si no existe
mkdir -p /etc/bind/zones

# Establecer permisos
chmod 755 /etc/bind/zones
chown bind:bind /etc/bind/zones
```

### Paso 4.3: Crear Zona Directa

#### Archivo: `/etc/bind/zones/db.midominio.com`

```bash
vi /etc/bind/zones/db.midominio.com
```

Contenido del archivo:

```named
$TTL 86400              ; TTL por defecto (1 día)

; Zona: midominio.com
; Servidor autoritativo: router (192.168.1.1)

@   IN  SOA ns1.midominio.com. admin.midominio.com. (
        2024040901  ; Serial (YYYYMMDDNN)
        3600        ; Refresh (1 hora)
        1800        ; Retry (30 minutos)
        604800      ; Expire (7 días)
        86400 )     ; Minimum TTL (1 día)

; Servidores de Nombres
@           IN  NS      ns1.midominio.com.

; Direcciones IP de los servidores de nombres
ns1         IN  A       192.168.1.1

; Dirección de correo (A)
mail        IN  A       192.168.1.10

; Host local
@           IN  A       192.168.1.1
router      IN  A       192.168.1.1
gateway     IN  A       192.168.1.1

; Servidores de aplicación
web         IN  A       192.168.1.20
servidor1   IN  A       192.168.1.30
servidor2   IN  A       192.168.1.31

; Alias (CNAME)
www         IN  CNAME   web.midominio.com.
ftp         IN  CNAME   web.midominio.com.

; Registro MX (Intercambiador de correo)
@           IN  MX  10  mail.midominio.com.

; SRV records (opcional)
_ldap._tcp  IN  SRV     0 0 389 servidor1.midominio.com.

; TXT records (SPF, etc.)
@           IN  TXT     "v=spf1 mx -all"
```

### Paso 4.4: Crear Zona Inversa

La zona inversa mapea direcciones IP a nombres (búsqueda inversa o reverse lookup).

#### Archivo: `/etc/bind/zones/db.midominio.com.inv`

```bash
vi /etc/bind/zones/db.midominio.com.inv
```

Contenido del archivo:

```named
$TTL 86400

; Zona inversa para 192.168.1.0/24
; Los octetos se invierten: 192.168.1 → 1.168.192.in-addr.arpa

@   IN  SOA ns1.midominio.com. admin.midominio.com. (
        2024040901  ; Serial
        3600        ; Refresh
        1800        ; Retry
        604800      ; Expire
        86400 )     ; Minimum TTL

; Servidores de nombres
@           IN  NS      ns1.midominio.com.

; Registros PTR (mapeo IP → FQDN)
1           IN  PTR     router.midominio.com.
1           IN  PTR     ns1.midominio.com.

10          IN  PTR     mail.midominio.com.

20          IN  PTR     web.midominio.com.

30          IN  PTR     servidor1.midominio.com.
31          IN  PTR     servidor2.midominio.com.

; Host genérico
0           IN  PTR     gateway.midominio.com.
```

### Paso 4.5: Configurar Permisos

```bash
# Establecer propietario
chown bind:bind /etc/bind/zones/db.midominio.com
chown bind:bind /etc/bind/zones/db.midominio.com.inv

# Establecer permisos (bind puede leer)
chmod 644 /etc/bind/zones/db.midominio.com
chmod 644 /etc/bind/zones/db.midominio.com.inv
```

---

## 5. Verificación de la Configuración

### Paso 5.1: Validar Sintaxis de Configuración

```bash
# Validar el archivo de configuración principal
named-checkconf /etc/bind/bind.conf

# Salida esperada: (ningún error)

# Validar zona directa
named-checkzone midominio.com /etc/bind/zones/db.midominio.com

# Salida esperada:
# zone midominio.com/IN: loaded serial 2024040901
# OK

# Validar zona inversa
named-checkzone 1.168.192.in-addr.arpa /etc/bind/zones/db.midominio.com.inv

# Salida esperada:
# zone 1.168.192.in-addr.arpa/IN: loaded serial 2024040901
# OK
```

### Paso 5.2: Iniciar Servicio BIND9

```bash
# Habilitar BIND9 para que inicie al arrancar
/etc/init.d/named enable

# Iniciar el servicio
/etc/init.d/named start

# Verificar que está corriendo
ps aux | grep named

# Ver estado
/etc/init.d/named status
```

### Paso 5.3: Comprobar que Escucha en Puerto 53

```bash
# Ver puertos en escucha
netstat -ln | grep 53

# Salida esperada:
# tcp  0  0 0.0.0.0:53    0.0.0.0:*    LISTEN
# udp  0  0 0.0.0.0:53    0.0.0.0:*
```

---

## 6. Pruebas de Resolución

### Prueba 6.1: Usando `dig` (Domain Information Groper)

```bash
# Consulta simple
dig @127.0.0.1 midominio.com

# Salida esperada:
# ; <<>> DiG 9.xx <<>> @127.0.0.1 midominio.com
# ; (1 server found)
# ;; global options: +cmd
# ;; Got answer:
# ;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: xxxxx
# ;; flags: qr aa rd ra; QUERY: 1, ANSWER: 1, AUTHORITY: 2, ADDITIONAL: 1
# 
# ;; QUESTION SECTION:
# ;midominio.com.			IN	A
# 
# ;; ANSWER SECTION:
# midominio.com.		86400	IN	A	192.168.1.1


# Consulta específica
dig @127.0.0.1 web.midominio.com

# Búsqueda inversa
dig @127.0.0.1 -x 192.168.1.20

# Salida esperada:
# ; <<>> DiG 9.xx <<>> -x 192.168.1.20
# ...
# ;; ANSWER SECTION:
# 20.1.168.192.in-addr.arpa. 86400 IN	PTR	web.midominio.com.

# Consulta TODO
dig @127.0.0.1 midominio.com ANY

# Ver respuesta sin comprimir (para debugging)
dig +noall +answer @127.0.0.1 midominio.com

# Ver información de transferencia de zona (si está permitida)
dig @127.0.0.1 midominio.com axfr
```

### Prueba 6.2: Usando `nslookup`

```bash
# Consulta interactiva
nslookup

# Luego en el prompt:
> server 127.0.0.1
Default server: 127.0.0.1
Default servers are now 127.0.0.1

> midominio.com
Server:         127.0.0.1
Address:        127.0.0.1#53

Name:   midominio.com
Address: 192.168.1.1

# Búsqueda inversa interactiva
> set type=PTR
> 192.168.1.20

# O de forma directa (no interactiva):
nslookup midominio.com 127.0.0.1

# Búsqueda inversa directa
nslookup 192.168.1.20 127.0.0.1

# Salida esperada:
# Server:         127.0.0.1
# Address:        127.0.0.1#53
#
# 20.1.168.192.in-addr.arpa     name = web.midominio.com.

# Buscar registro MX
nslookup -type=MX midominio.com 127.0.0.1

# Buscar registro NS
nslookup -type=NS midominio.com 127.0.0.1
```

### Prueba 6.3: Usando `host`

```bash
# Consulta simple
host midominio.com 127.0.0.1

# Salida esperada:
# midominio.com has address 192.168.1.1

# Búsqueda inversa
host 192.168.1.20 127.0.0.1

# Salida esperada:
# 20.1.168.192.in-addr.arpa domain name pointer web.midominio.com.

# Con registros adicionales
host -a midominio.com 127.0.0.1

# Buscar registro específico (MX)
host -t MX midominio.com 127.0.0.1

# Salida esperada:
# midominio.com mail is handled by 10 mail.midominio.com.

# Buscar registros NS
host -t NS midominio.com 127.0.0.1
```

### Prueba 6.4: Desde un Cliente de la LAN

```bash
# Desde una máquina cliente (NO el router):
# Editar el cliente para usar el servidor DNS del router

# En Linux/Mac:
echo "nameserver 192.168.1.1" | sudo tee /etc/resolv.conf

# Luego probar:
dig @192.168.1.1 midominio.com
nslookup midominio.com 192.168.1.1
host midominio.com 192.168.1.1

# En Windows:
# Configurar DNS en las propiedades de red:
#   - Preferido: 192.168.1.1
#   - Alternativo: 8.8.8.8

# Luego:
nslookup midominio.com 192.168.1.1
```

---

## 7. Monitoreo y Resolución de Problemas

### 7.1: Ver Logs de BIND9

```bash
# Los logs de BIND9 se escriben en syslog
# En OpenWRT, típicamente van a /var/log/messages

# Ver logs en tiempo real
tail -f /var/log/messages | grep named

# Ver todos los logs de named
grep named /var/log/messages

# Ver con timestamp
grep "$(date +%b\ %d)" /var/log/messages | grep named

# Ver logs detallados de queries
# (Requiere querylog configurado en bind.conf)
tail -n 100 /var/log/messages | grep "query:"
```

### 7.2: Configurar Logging Más Detallado

Editar `/etc/bind/bind.conf` y agregar:

```named
logging {
    // Canal para queries
    channel queries_log {
        file "/var/log/bind/queries.log" versions 3 size 10m;
        severity info;
        print-category yes;
        print-severity yes;
        print-time yes;
    };
    
    // Canal para errores generales
    channel general_log {
        file "/var/log/bind/general.log" versions 3 size 10m;
        severity info;
        print-category yes;
        print-severity yes;
        print-time yes;
    };
    
    // Aplicar canales
    category queries {
        queries_log;
    };
    
    category default {
        general_log;
    };
};
```

Luego:

```bash
# Crear directorio de logs
mkdir -p /var/log/bind
chown bind:bind /var/log/bind
chmod 755 /var/log/bind

# Reiniciar BIND9
/etc/init.d/named restart
```

### 7.3: Comandos de Diagnóstico

```bash
# Ver estado del servicio
/etc/init.d/named status

# Recargar configuración sin reiniciar
rndc reload

# Recargar una zona específica
rndc reload midominio.com

# Ver estadísticas
rndc stats

# Ver la solución de problemas de conexión
rndc dumpdb -all

# Asegurar que BIND9 tiene permisos suficientes
ls -la /etc/bind/
ls -la /etc/bind/zones/
ls -la /var/cache/bind/
```

### 7.4: Errores Comunes y Soluciones

#### Error: "Permission denied" al iniciar BIND9

```bash
# Solución: Asegurar permisos correctos
chown -R bind:bind /etc/bind
chmod -R 755 /etc/bind
chmod 644 /etc/bind/zones/db.*

ls -l /var/cache/bind/
chown bind:bind /var/cache/bind
```

#### Error: "Zone not loaded - file not found"

```bash
# Solución: Verificar rutas en bind.conf
# Asegurarse que los archivos de zona existen:
ls -la /etc/bind/zones/

# Verificar que los permisos permiten que bind pueda leerlos:
ls -la /etc/bind/zones/db.midominio.com
# Debe mostrar: -rw-r--r-- bind bind
```

#### Error: "named[xxx]: client @0x... (midominio.com): query denied"

```bash
# Solución: Verificar ACLs en bind.conf
# Asegurar que la LAN está permitida:
cat /etc/bind/bind.conf | grep -A5 "acl"

# La ACL debe incluir la red del cliente
acl "lan" {
    192.168.1.0/24;
};
```

#### Error: "Address already in use" en puerto 53

```bash
# Solución: Verificar si otro servicio usa puerto 53
netstat -ln | grep 53

# Si dnsmasq está usando 53, desactivar DNS en dnsmasq
vi /etc/dnsmasq.conf
# Agregar/cambiar:
port=0

# Reiniciar dnsmasq
/etc/init.d/dnsmasq restart
```

#### BIND9 no resuelve nombres recursivos (internet)

```bash
# Solución: Configurar forwarders en bind.conf
options {
    forwarders {
        8.8.8.8;
        1.1.1.1;
    };
    recursion yes;
};

# Reiniciar
/etc/init.d/named restart

# Probar:
dig @127.0.0.1 google.com
```

### 7.5: Archivo de Registro de Errores Completo

Crear archivo `/etc/bind/logging-full.conf`:

```named
logging {
    // Channel para queries detalladas
    channel queries_log {
        file "/var/log/bind/queries.log" versions 5 size 20m;
        severity info;
        print-category yes;
        print-severity yes;
        print-time iso8601;
    };
    
    // Channel para eventos críticos
    channel critical_log {
        file "/var/log/bind/critical.log";
        severity critical;
        print-category yes;
        print-severity yes;
        print-time iso8601;
    };
    
    // Channel para eventos de configuración
    channel config_log {
        file "/var/log/bind/config.log";
        severity info;
        print-category yes;
        print-severity yes;
        print-time iso8601;
    };
    
    // Channel para errores de transferencia
    channel transfer_log {
        file "/var/log/bind/transfer.log";
        severity info;
        print-category yes;
        print-severity yes;
        print-time iso8601;
    };
    
    // Channel para errores de seguridad
    channel security_log {
        file "/var/log/bind/security.log";
        severity info;
        print-category yes;
        print-severity yes;
        print-time iso8601;
    };
    
    // Aplicar categorías
    category queries { queries_log; };
    category general { config_log; };
    category zone { config_log; };
    category xfer-in { transfer_log; };
    category xfer-out { transfer_log; };
    category security { security_log; };
    category default { critical_log; };
};
```

Luego incluir en bind.conf:

```named
include "/etc/bind/logging-full.conf";
```

---

## Checklist de Implementación

- [ ] BIND9 instalado correctamente
- [ ] dnsmasq configurado solo para DHCP
- [ ] Firewall permite DNS (puerto 53 TCP/UDP)
- [ ] Zona directa creada y validada
- [ ] Zona inversa creada y validada
- [ ] Permisos configurados correctamente
- [ ] BIND9 iniciado y habilitado al boot
- [ ] Resolución desde localhost funciona (dig, nslookup, host)
- [ ] Resolución desde cliente LAN funciona
- [ ] Logging configurado
- [ ] Monitoreo implementado
- [ ] Plan de backup y recuperación establecido

---

## Comandos Rápidos de Referencia

```bash
# Instalación
opkg install bind-server bind-tools

# Iniciar/Detener
/etc/init.d/named start
/etc/init.d/named stop
/etc/init.d/named restart
/etc/init.d/named status

# Validar configuración
named-checkconf /etc/bind/bind.conf
named-checkzone midominio.com /etc/bind/zones/db.midominio.com

# Probar resolución
dig @127.0.0.1 midominio.com
nslookup midominio.com 127.0.0.1
host midominio.com 127.0.0.1

# Monitoreo
tail -f /var/log/messages | grep named
rndc reload
rndc dumpdb -all

# Firewall
uci show firewall
uci modify firewall
/etc/init.d/firewall restart
```

---

## Recursos Adicionales

- [BIND 9 Documentation](https://bind9.readthedocs.io/)
- [OpenWRT Wiki - DNS/DHCP](https://openwrt.org/docs/guide-user/services/dns/)
- [ISC BIND Homepage](https://www.isc.org/bind/)
- [RFC 1912 - Common DNS Data File Format](https://tools.ietf.org/html/rfc1912)
- [RFC 2317 - Classless IN-ADDR.ARPA delegation](https://tools.ietf.org/html/rfc2317)

