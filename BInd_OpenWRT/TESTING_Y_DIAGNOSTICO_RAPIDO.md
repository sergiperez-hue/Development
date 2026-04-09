# Referencia Rápida: Testing y Diagnóstico

## Tabla Rápida de Comandos

| Tarea | Comando | Salida Esperada |
|-------|---------|-----------------|
| Verificar instalación | `which named` | `/usr/sbin/named` |
| Ver versión | `named -v` | `BIND 9.xx.xx` |
| Validar config | `named-checkconf /etc/bind/bind.conf` | (sin salida = OK) |
| Validar zona | `named-checkzone midominio.com /etc/bind/zones/db.midominio.com` | `zone loaded serial XXXXX` |
| Ver logs | `tail -f /var/log/messages` | Eventos de named |
| Ver puerto 53 | `netstat -ln \| grep 53` | `tcp/udp 0.0.0.0:53 LISTEN` |
| Iniciar BIND9 | `/etc/init.d/named start` | `[OK]` |
| Parar BIND9 | `/etc/init.d/named stop` | `[OK]` |
| Estado BIND9 | `/etc/init.d/named status` | `running` / `stopped` |
| Recargar config | `rndc reload` | Sin salida = OK |
| Probar DNS local | `dig @127.0.0.1 midominio.com` | `ANSWER: 1, A record` |

---

## Pruebas con `dig` (Domain Information Groper)

### Instalación
```bash
opkg install bind-tools
```

### Pruebas Básicas

#### 1. Consulta Simple (Zona Directa)
```bash
dig @127.0.0.1 midominio.com

# Salida esperada:
# ;; ANSWER SECTION:
# midominio.com.          86400   IN      A       192.168.1.1
```

#### 2. Consulta de Host Específico
```bash
dig @127.0.0.1 web.midominio.com

# Salida esperada:
# web.midominio.com.      86400   IN      A       192.168.1.20
```

#### 3. Búsqueda Inversa (Zona Inversa)
```bash
dig @127.0.0.1 -x 192.168.1.20

# Salida esperada:
# ;; ANSWER SECTION:
# 20.1.168.192.in-addr.arpa. 86400 IN    PTR     web.midominio.com.
```

#### 4. Consultar Registros MX
```bash
dig @127.0.0.1 MX midominio.com

# Salida esperada:
# midominio.com.          86400   IN      MX      10 mail.midominio.com.
```

#### 5. Consultar Registros NS
```bash
dig @127.0.0.1 NS midominio.com

# Salida esperada:
# midominio.com.          86400   IN      NS      ns1.midominio.com.
```

#### 6. Transferencia de Zona (AXFR) - Solo si está permitida
```bash
dig @127.0.0.1 midominio.com AXFR

# Salida esperada (lista completa de registros de la zona)
# midominio.com.  IN  SOA  ...
# midominio.com.  IN  NS   ...
# ...
```

#### 7. Consulta con Todos los Detalles
```bash
dig @127.0.0.1 midominio.com +nocmd +multiline +noall +answer

# Salida esperada:
# midominio.com.          86400   IN      A       192.168.1.1
```

#### 8. Consulta Short (sin comentarios)
```bash
dig +short @127.0.0.1 midominio.com

# Salida esperada:
# 192.168.1.1
```

#### 9. Traceo de Resolución Recursiva
```bash
dig @127.0.0.1 +trace google.com

# Muestra el proceso de resolución paso a paso
```

#### 10. Información de Timing
```bash
dig @127.0.0.1 midominio.com +stats

# Muestra: Query time, Server, etc.
```

---

## Pruebas con `nslookup`

### Modo Interactivo

```bash
nslookup

> server 127.0.0.1         # Definir servidor
> midominio.com            # Consultar dominio
> set type=A               # Tipo A (ipv4)
> set type=AAAA            # Tipo AAAA (ipv6)
> set type=MX              # Registros MX
> set type=NS              # Registros NS
> set type=PTR             # Búsqueda inversa
> -x 192.168.1.20          # Búsqueda inversa directa
> exit
```

### Modo No-Interactivo

```bash
# Consulta simple
nslookup midominio.com 127.0.0.1

# Búsqueda inversa
nslookup 192.168.1.20 127.0.0.1

# Consulta específica
nslookup -type=MX midominio.com 127.0.0.1
nslookup -type=NS midominio.com 127.0.0.1

# Debug mode (detallado)
nslookup -debug midominio.com 127.0.0.1
```

### Salidas Esperadas

```
# Consulta exitosa:
Server:         127.0.0.1
Address:        127.0.0.1#53

Name:   midominio.com
Address: 192.168.1.1

# Error - Servidor no responde:
;; connection timed out; trying next origin
** server can't find midominio.com: SERVFAIL

# Error - CNAME no existe:
Name:   web.midominio.com
Address: 192.168.1.20
```

---

## Pruebas con `host`

### Sintaxis
```bash
host [-t tipo] dominio [servidor]
```

### Ejemplos

#### 1. Consulta Simple
```bash
host midominio.com 127.0.0.1

# Salida esperada:
# midominio.com has address 192.168.1.1
```

#### 2. Búsqueda Inversa
```bash
host 192.168.1.20 127.0.0.1

# Salida esperada:
# 20.1.168.192.in-addr.arpa domain name pointer web.midominio.com.
```

#### 3. Consultar Tipo Específico
```bash
host -t MX midominio.com 127.0.0.1

# Salida esperada:
# midominio.com mail is handled by 10 mail.midominio.com.

host -t NS midominio.com 127.0.0.1

# Salida esperada:
# midominio.com nameserver ns1.midominio.com.
```

#### 4. Información Completa
```bash
host -a midominio.com 127.0.0.1

# Muestra toda la información de la zona
```

#### 5. Información de Autoridad
```bash
host -C midominio.com 127.0.0.1

# Muestra registros SOA y NS
```

#### 6. Verbose (Verboso)
```bash
host -v midominio.com 127.0.0.1

# Salida detallada con estadísticas
```

---

## Matriz de Pruebas Completa

| Herramienta | Comando | Propósito | Salida Exitosa |
|-------------|---------|----------|----------------|
| dig | `dig @127.0.0.1 midominio.com` | Verificar A record | `status: NOERROR` |
| dig | `dig @127.0.0.1 -x 192.168.1.20` | Verificar PTR (inversa) | `status: NOERROR` |
| dig | `dig @127.0.0.1 midominio.com MX` | Verificar MX | `status: NOERROR` |
| nslookup | `nslookup midominio.com 127.0.0.1` | Verificar A record | `Address: 192.168.1.1` |
| nslookup | `nslookup 192.168.1.20 127.0.0.1` | Verificar PTR | `name = web.midominio.com` |
| host | `host midominio.com 127.0.0.1` | Verificar A record | `has address 192.168.1.1` |
| host | `host -t MX midominio.com 127.0.0.1` | Verificar MX | `mail is handled by` |

---

## Diagnóstico Paso a Paso

### Paso 1: ¿Está BIND9 Corriendo?
```bash
/etc/init.d/named status
ps aux | grep 'named'
netstat -ln | grep ':53'
```

**Si NO está corriendo:**
```bash
/etc/init.d/named start
/etc/init.d/named enable
```

### Paso 2: ¿Escucha en Puerto 53?
```bash
netstat -ln | grep 53
```

**Salida esperada:**
```
tcp   0  0 0.0.0.0:53    0.0.0.0:*    LISTEN
udp   0  0 0.0.0.0:53    0.0.0.0:*
```

**Si no aparece: Verificar Firewall**
```bash
uci show firewall | grep 53
```

### Paso 3: ¿Es Válida la Configuración?
```bash
named-checkconf /etc/bind/bind.conf
```

**Si hay errores: Ver línea específica**
```bash
named-checkconf -z /etc/bind/bind.conf
```

### Paso 4: ¿Son Válidas las Zonas?
```bash
named-checkzone midominio.com /etc/bind/zones/db.midominio.com
```

**Salida esperada:**
```
zone midominio.com/IN: loaded serial 2024040901
OK
```

### Paso 5: ¿Responde Localmente?
```bash
dig @127.0.0.1 midominio.com
```

**Si falla: Revisar logs**
```bash
tail -f /var/log/messages | grep named
```

### Paso 6: ¿Responde desde Cliente Local?
```bash
# Desde otra máquina en la LAN:
dig @192.168.1.1 midominio.com
```

**Si falla: Verificar firewall**
```bash
iptables -L INPUT -n
```

---

## Tabla de Errores Comunes

| Error | Causa | Solución |
|-------|-------|----------|
| `named: can't load 'bind.conf'` | Archivo no existe | `locate bind.conf` / crear archivo |
| `named: error (SERVFAIL)` | Zona no encontrada | `named-checkzone` / verificar sintaxis |
| `Query denied` | ACL restringida | Agregar IP a ACL en bind.conf |
| `Address already in use` | Puerto 53 ocupado | `lsof -i :53` / detener otro servicio |
| `Permission denied` | Permisos insuficientes | `chown bind:bind /etc/bind -R` |
| `Connection refused` | BIND9 no escucha | `netstat -ln | grep 53` / reiniciar BIND9 |
| `Timeout` | BIND9 no responde | `tail -f /var/log/messages` / revisar logs |
| `NXDOMAIN` | Dominio no existe | Agregar registro a la zona |
| `FORMERR` | Formato inválido en query | Sintaxis incorrecta en comando |
| `REFUSED` | Transferencia denegada | `allow-transfer` en bind.conf |

---

## Archivos de Log Important

| Archivo | Contenido |
|---------|----------|
| `/var/log/messages` | Logs generales del sistema (incluye BIND9) |
| `/var/log/syslog` | Log del sistema (en algunos sistemas) |
| `/var/log/bind/` | Logs específicos de BIND9 (si se configuró) |
| `/var/run/named.pid` | PID del proceso BIND9 |

### Ver Logs
```bash
# En tiempo real
tail -f /var/log/messages | grep named

# Últimas líneas
tail -n 50 /var/log/messages | grep named

# Buscar errores
grep "named.*error" /var/log/messages

# Contar queries
grep "query:" /var/log/messages | wc -l

# Ver queries de un dominio
grep "midominio.com" /var/log/messages
```

---

## Script de Diagnóstico Completo

```bash
#!/bin/bash
# Script: diagnostico_completo.sh

echo "=== DIAGNÓSTICO COMPLETO DE BIND9 ==="
echo ""

echo "1. INSTALACIÓN"
which named && echo "✓ BIND9 instalado" || echo "✗ BIND9 no instalado"
echo ""

echo "2. SERVICIO"
/etc/init.d/named status
echo ""

echo "3. PUERTO"
netstat -ln | grep 53 || echo "Puerto 53 no en escucha"
echo ""

echo "4. CONFIGURACIÓN"
named-checkconf /etc/bind/bind.conf && echo "✓ Configuración válida" || echo "✗ Error en configuración"
echo ""

echo "5. ZONAS"
for zona in /etc/bind/zones/db.*; do
    [ -f "$zona" ] && named-checkzone "$(basename $zona)" "$zona" && echo "✓ $zona válida" || echo "✗ $zona inválida"
done
echo ""

echo "6. FIREWALL"
uci show firewall | grep -q 53 && echo "✓ Firewall OK" || echo "⚠ Verificar firewall"
echo ""

echo "7. PRUEBA LOCAL"
dig @127.0.0.1 midominio.com +short && echo "✓ Resolución OK" || echo "✗ Resolución falla"
```

