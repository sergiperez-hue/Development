# Casos Prácticos: Configuración Paso a Paso

## Caso Práctico 1: Configuración Básica Red 192.168.1.0/24

### Escenario
- **Dominio**: empresa.local
- **Red LAN**: 192.168.1.0/24
- **Router (DNS)**: 192.168.1.1
- **Servidor Web**: 192.168.1.10
- **Servidor Mail**: 192.168.1.11
- **PC Oficina 1**: 192.168.1.30
- **PC Oficina 2**: 192.168.1.31

### Paso 1: Instalación
```bash
opkg update
opkg install bind-server bind-tools ca-bundle
```

### Paso 2: Crear Estructura
```bash
mkdir -p /etc/bind/zones
chown bind:bind /etc/bind -R
chmod 755 /etc/bind
```

### Paso 3: Archivo Principal

**Archivo: `/etc/bind/bind.conf`**
```named
// ACL para la red local
acl "lan" {
    192.168.1.0/24;
    127.0.0.1;
};

options {
    directory "/var/cache/bind";
    
    // Escuchar en puerto 53
    listen-on port 53 { any; };
    listen-on-v6 port 53 { any; };
    
    // Permitir queries solo desde LAN
    allow-query { lan; };
    
    // Forwarders
    forwarders {
        8.8.8.8;
        1.1.1.1;
    };
    
    // Seguridad
    recursion yes;
    allow-recursion { lan; };
    allow-transfer { 127.0.0.1; };
};

// Zona directa
zone "empresa.local" IN {
    type master;
    file "/etc/bind/zones/db.empresa.local";
    allow-update { none; };
};

// Zona inversa
zone "1.168.192.in-addr.arpa" IN {
    type master;
    file "/etc/bind/zones/db.empresa.local.inv";
    allow-update { none; };
};
```

### Paso 4: Zona Directa

**Archivo: `/etc/bind/zones/db.empresa.local`**
```named
$TTL 86400

@   IN  SOA ns1.empresa.local. admin.empresa.local. (
        2024040901
        3600
        1800
        604800
        86400 )

@           IN  NS      ns1.empresa.local.

; Servidor de nombres
ns1         IN  A       192.168.1.1
router      IN  A       192.168.1.1

; Dominio raíz
@           IN  A       192.168.1.1

; Servidores de aplicación
web         IN  A       192.168.1.10
mail        IN  A       192.168.1.11
servidor1   IN  A       192.168.1.30
servidor2   IN  A       192.168.1.31

; Alias
www         IN  CNAME   web.empresa.local.
ftp         IN  CNAME   web.empresa.local.
smtp        IN  CNAME   mail.empresa.local.

; Registros MX
@           IN  MX  10  mail.empresa.local.
```

### Paso 5: Zona Inversa

**Archivo: `/etc/bind/zones/db.empresa.local.inv`**
```named
$TTL 86400

@   IN  SOA ns1.empresa.local. admin.empresa.local. (
        2024040901
        3600
        1800
        604800
        86400 )

@           IN  NS      ns1.empresa.local.

1           IN  PTR     router.empresa.local.
1           IN  PTR     ns1.empresa.local.
10          IN  PTR     web.empresa.local.
11          IN  PTR     mail.empresa.local.
30          IN  PTR     servidor1.empresa.local.
31          IN  PTR     servidor2.empresa.local.
```

### Paso 6: Permisos y Validación
```bash
chown bind:bind /etc/bind/zones/db.*
chmod 644 /etc/bind/zones/db.*

named-checkconf /etc/bind/bind.conf
named-checkzone empresa.local /etc/bind/zones/db.empresa.local
named-checkzone 1.168.192.in-addr.arpa /etc/bind/zones/db.empresa.local.inv
```

### Paso 7: Configurar Firewall
```bash
uci add firewall rule
uci set firewall.@rule[-1].name='Allow DNS'
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
```

### Paso 8: Configurar DHCP
```bash
# Anunciar el nuevo servidor DNS
uci set dhcp.lan.dhcp_option='6,192.168.1.1'
uci commit dhcp
/etc/init.d/dnsmasq restart
```

### Paso 9: Desactivar DNS en dnsmasq
```bash
echo "port=0" >> /etc/dnsmasq.conf
/etc/init.d/dnsmasq restart
```

### Paso 10: Iniciar BIND9
```bash
/etc/init.d/named enable
/etc/init.d/named start
```

### Pruebas
```bash
# Desde el router
dig @127.0.0.1 empresa.local
dig @127.0.0.1 web.empresa.local
dig @127.0.0.1 -x 192.168.1.10
nslookup servidor1.empresa.local 127.0.0.1
host mail.empresa.local 127.0.0.1

# Desde un cliente (IP: 192.168.1.30)
# Configurar DNS en cliente: 192.168.1.1
dig @192.168.1.1 web.empresa.local
nslookup empresa.local 192.168.1.1
```

---

## Caso Práctico 2: Red Múltiple (192.168.1.0/24 + 10.0.0.0/24)

### Escenario
- **Dominio**: empresa.com
- **Red Principal**: 192.168.1.0/24
- **Red Secundaria**: 10.0.0.0/24
- **Ambas redes** comparten el mismo servidor DNS

### Paso 1: Archivo Principal Modificado

```named
acl "redes" {
    192.168.1.0/24;
    10.0.0.0/24;
    127.0.0.1;
};

options {
    directory "/var/cache/bind";
    listen-on port 53 { any; };
    listen-on-v6 port 53 { any; };
    allow-query { redes; };
    forwarders {
        8.8.8.8;
        1.1.1.1;
    };
    recursion yes;
    allow-recursion { redes; };
};

// Zona directa
zone "empresa.com" IN {
    type master;
    file "/etc/bind/zones/db.empresa.com";
};

// Zona inversa Red 192.168.1
zone "1.168.192.in-addr.arpa" IN {
    type master;
    file "/etc/bind/zones/db.empresa.com.192";
};

// Zona inversa Red 10.0.0
zone "0.0.10.in-addr.arpa" IN {
    type master;
    file "/etc/bind/zones/db.empresa.com.10";
};
```

### Paso 2: Zona Directa Extendida

```named
$TTL 86400

@   IN  SOA ns1.empresa.com. admin.empresa.com. (
        2024040902
        3600
        1800
        604800
        86400 )

@           IN  NS      ns1.empresa.com.

; Red 192.168.1 - Oficina Principal
ns1         IN  A       192.168.1.1
router1     IN  A       192.168.1.1
web         IN  A       192.168.1.10
mail        IN  A       192.168.1.11
srv-db      IN  A       192.168.1.50

; Red 10.0.0 - Sucursal
router2     IN  A       10.0.0.1
ns2         IN  A       10.0.0.1
srv-apps    IN  A       10.0.0.10
srv-backup  IN  A       10.0.0.50

; Alias DNS comunes
www         IN  CNAME   web.empresa.com.
ftp         IN  CNAME   web.empresa.com.
smtp        IN  CNAME   mail.empresa.com.

; Registros MX
@           IN  MX  10  mail.empresa.com.
```

### Paso 3: Zona Inversa para Red 192.168.1

```named
$TTL 86400

@   IN  SOA ns1.empresa.com. admin.empresa.com. (
        2024040901
        3600
        1800
        604800
        86400 )

@           IN  NS      ns1.empresa.com.

1           IN  PTR     router1.empresa.com.
1           IN  PTR     ns1.empresa.com.
10          IN  PTR     web.empresa.com.
11          IN  PTR     mail.empresa.com.
50          IN  PTR     srv-db.empresa.com.
```

### Paso 4: Zona Inversa para Red 10.0.0

```named
$TTL 86400

@   IN  SOA ns1.empresa.com. admin.empresa.com. (
        2024040901
        3600
        1800
        604800
        86400 )

@           IN  NS      ns1.empresa.com.

1           IN  PTR     router2.empresa.com.
1           IN  PTR     ns2.empresa.com.
10          IN  PTR     srv-apps.empresa.com.
50          IN  PTR     srv-backup.empresa.com.
```

### Paso 5: Firewall para Ambas Redes

```bash
# Permitir DNS desde ambas redes y localhost
uci add firewall rule
uci set firewall.@rule[-1].name='Allow DNS from LAN'
uci set firewall.@rule[-1].src='lan'
uci set firewall.@rule[-1].dest_port='53'
uci set firewall.@rule[-1].proto='udp tcp'
uci set firewall.@rule[-1].target='ACCEPT'

uci add firewall rule
uci set firewall.@rule[-1].name='Allow DNS from Guest'
uci set firewall.@rule[-1].src='guest'
uci set firewall.@rule[-1].dest_port='53'
uci set firewall.@rule[-1].proto='udp tcp'
uci set firewall.@rule[-1].target='ACCEPT'

uci commit firewall
/etc/init.d/firewall restart
```

---

## Caso Práctico 3: Subdominios y Zona Delegada

### Escenario
- **Dominio Principal**: empresa.com
- **Subdominio**: oficina.empresa.com (delegado a otro servidor)
- **Otro Servidor**: 192.168.1.100

### Paso 1: Zona Principal Modificada

```named
$TTL 86400

@   IN  SOA ns1.empresa.com. admin.empresa.com. (
        2024040903
        3600
        1800
        604800
        86400 )

@           IN  NS      ns1.empresa.com.

; Registros principales
ns1         IN  A       192.168.1.1
@           IN  A       192.168.1.1
www         IN  A       192.168.1.10

; Delegación de subdominio
oficina     IN  NS      ns-oficina.empresa.com.
ns-oficina  IN  A       192.168.1.100

; Otro subdominio sin delegación
shop        IN  A       192.168.1.20
www.shop    IN  CNAME   shop.empresa.com.
```

### Paso 2: Consultas de Prueba

```bash
# Desde principal
dig @127.0.0.1 empresa.com

# Consulta al subdominio delegado
dig @127.0.0.1 oficina.empresa.com

# Debería responder el otro servidor (192.168.1.100)
```

---

## Caso Práctico 4: Records SPF y DKIM para Correo

### Escenario
- Configurar servidor mail para empresa.com
- Implementar SPF y DKIM

### Zona Modificada

```named
$TTL 86400

@   IN  SOA ns1.empresa.com. admin.empresa.com. (
        2024040904
        3600
        1800
        604800
        86400 )

@           IN  NS      ns1.empresa.com.

; Servidor mail
mail        IN  A       192.168.1.11

; Registros MX
@           IN  MX  10  mail.empresa.com.
@           IN  MX  20  mail2.empresa.com.
mail2       IN  A       192.168.1.12

; SPF record (permite mail, forbid other)
@           IN  TXT     "v=spf1 mx -all"

; DKIM records
default._domainkey  IN  TXT  "v=DKIM1; k=rsa; p=MIGfMA0BGE..."

; DMARC policy
_dmarc              IN  TXT  "v=DMARC1; p=reject; rua=mailto:admin@empresa.com"

; CAA (Certificate Authority Authorization) - opcional
@           IN  CAA     0 issue "letsencrypt.org"
```

---

## Caso Práctico 5: Monitoreo y Logging Detallado

### Configuración de Logging

**Archivo: `/etc/bind/logging.conf`**
```named
logging {
    // Queries (consultas DNS)
    channel query_log {
        file "/var/log/bind/query.log" versions 5 size 50m;
        print-time iso8601;
        print-category yes;
        print-severity yes;
    };

    // General
    channel general_log {
        file "/var/log/bind/general.log" versions 5 size 50m;
        print-time iso8601;
        print-category yes;
        print-severity yes;
    };

    // Transferencias
    channel transfer_log {
        file "/var/log/bind/transfer.log" versions 3 size 30m;
        print-time iso8601;
    };

    // Seguridad
    channel security_log {
        file "/var/log/bind/security.log" versions 3 size 30m;
        print-time iso8601;
        print-severity yes;
    };

    // Aplicar
    category queries { query_log; };
    category default { general_log; };
    category xfer-in { transfer_log; };
    category xfer-out { transfer_log; };
    category security { security_log; };
};
```

### Script de Análisis de Logs

```bash
#!/bin/bash
# Script: analizar_logs.sh

echo "=== ANÁLISIS DE LOGS DNS ==="
echo ""

echo "Queries más frecuentes:"
grep "query:" /var/log/bind/query.log | grep -oP '(?<=query: )\S+' | sort | uniq -c | sort -rn | head -10

echo ""
echo "Dominios más consultados:"
grep "query:" /var/log/bind/query.log | grep -oP 'query: \K[^ ]+' | sort | uniq -c | sort -rn | head -10

echo ""
echo "Errores en últimas 24h:"
find /var/log/bind/ -name "*.log" -mtime -1 -exec grep -i "error" {} + | wc -l

echo ""
echo "IPs que hacen más queries:"
grep "query:" /var/log/bind/query.log | grep -oP '\[[\d.]+\]' | sort | uniq -c | sort -rn | head -5

echo ""
echo "Tipos de query:"
grep "query:" /var/log/bind/query.log | grep -oP 'IN \K\w+' | sort | uniq -c | sort -rn
```

---

## Checklist de Configuración Individual para cada Caso

### Checklist Caso 1 (Básico)
- [ ] Instalación completada
- [ ] Estructura de directorios creada
- [ ] bind.conf válido (named-checkconf OK)
- [ ] Zonas válidas (named-checkzone OK)
- [ ] Permisos configurados (bind:bind, 755)
- [ ] Firewall permite DNS (puerto 53)
- [ ] DHCP anuncia DNS router
- [ ] dnsmasq DNS desactivado
- [ ] BIND9 iniciado y habilitado
- [ ] Resolución desde localhost funciona
- [ ] Resolución desde cliente funciona

### Checklist Caso 2 (Múltiples Redes)
- [ ] Todos los puntos de Caso 1
- [ ] ACL incluye ambas redes
- [ ] Zona inversa para red secundaria existe
- [ ] Firewall permite desde ambas redes
- [ ] Resolución funciona desde ambas redes

### Checklist Caso 3 (Subdominios)
- [ ] Todos los puntos de Caso 1
- [ ] Recurso NS para subdominio existe
- [ ] Servidor delegado accesible
- [ ] Queries al subdominio se resuelven

### Checklist Caso 4 (Correo)
- [ ] Todos los puntos de Caso 1
- [ ] Registros MX válidos
- [ ] Registros SPF/DKIM/DMARC correctos
- [ ] `dig MX` devuelve registros esperados
- [ ] `nslookup -type=MX` funciona

### Checklist Caso 5 (Logging)
- [ ] Todos los puntos de Caso 1
- [ ] logging.conf creado
- [ ] Directorio /var/log/bind/ creado
- [ ] Permisos de log configurados
- [ ] Logs se generan
- [ ] Script de análisis funciona

