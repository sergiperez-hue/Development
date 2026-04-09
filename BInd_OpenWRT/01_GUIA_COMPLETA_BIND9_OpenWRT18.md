# Guía Completa: Instalación y Configuración de BIND9 en OpenWRT 18

## Tabla de Contenidos
1. [Requisitos Previos](#requisitos-previos)
2. [Instalación de BIND9](#instalación-de-bind9)
3. [Desactivación de dnsmasq como DNS](#desactivación-de-dnsmasq-como-dns)
4. [Configuración del Firewall](#configuración-del-firewall)
5. [Configuración de Zonas](#configuración-de-zonas)
6. [Verificación y Testing](#verificación-y-testing)
7. [Registro de Errores](#registro-de-errores)

---

## Requisitos Previos

Antes de comenzar necesitas:
- Acceso SSH a OpenWRT 18
- Permisos de root (sudo)
- Directorio de espacio disponible en `/etc/bind/` (~50MB mínimo recomendado)
- Conocimiento básico de conceptos DNS

---

## Instalación de BIND9

### Paso 1: Actualizar los repositorios
```bash
opkg update
```

### Paso 2: Instalar BIND9 y dependencias
```bash
opkg install bind-server bind-clients ca-bundle
```

Esto instala:
- **bind-server**: El servidor DNS BIND9
- **bind-clients**: Herramientas como dig, nslookup, host
- **ca-bundle**: Certificados SSL/TLS

### Paso 3: Verificar la instalación
```bash
named -v
# Salida esperada: BIND 9.x.x
```

---

## Desactivación de dnsmasq como DNS

### **Importante**: Mantener DHCP activo, desactivar solo DNS

### Paso 1: Acceder a la interfaz UCI
Si trabajas vía CLI:
```bash
uci show dhcp
```

### Paso 2: Desactivar DNS en dnsmasq pero mantener DHCP
```bash
# Editar la configuración
vi /etc/config/dhcp
```

**Configuración original (típica):**
```
config dnsmasq
    option domainneeded '1'
    option boguspriv '1'
    option filterwin2k '0'
    option enable '1'      # ← Mantener esto en 1 para DHCP
```

**Configuración modificada:**
```
config dnsmasq
    option domainneeded '1'
    option boguspriv '1'
    option filterwin2k '0'
    option enable '1'              # ← DHCP sigue activo
    option noresolv '1'            # Ignore /etc/resolv.conf
    option port '0'                # Puerto 0 = DNS desactivado
```

### Paso 3: Aplicar los cambios
```bash
/etc/init.d/dnsmasq restart
```

### Paso 4: Verificar el puerto DNS
```bash
netstat -tulnp | grep -E ':(53|68|67)'
```

**Salida esperada:**
```
tcp  0  0 127.0.0.1:53  0.0.0.0:*  LISTEN   1234/named
tcp  0  0 0.0.0.0:53    0.0.0.0:*  LISTEN   1234/named
udp  0  0 0.0.0.0:67    0.0.0.0:*           1234/dnsmasq
udp  0  0 0.0.0.0:68    0.0.0.0:*           1234/dnsmasq
```

Donde:
- Puerto **53 (BIND9)**: DNS servidor
- Puerto **67/68 (dnsmasq)**: DHCP servidor

---

## Configuración del Firewall

### Paso 1: Permitir tráfico DNS (puerto 53)

**Vía UCI (recomendado):**
```bash
# Crear una nueva regla de firewall
uci add firewall rule
uci set firewall.@rule[-1].name='Allow DNS'
uci set firewall.@rule[-1].proto='udp'
uci set firewall.@rule[-1].dest_port='53'
uci set firewall.@rule[-1].target='ACCEPT'
uci set firewall.@rule[-1].family='ipv4'

# TCP también (para consultas grandes)
uci add firewall rule
uci set firewall.@rule[-1].name='Allow DNS TCP'
uci set firewall.@rule[-1].proto='tcp'
uci set firewall.@rule[-1].dest_port='53'
uci set firewall.@rule[-1].target='ACCEPT'
uci set firewall.@rule[-1].family='ipv4'

# Guardar y aplicar
uci commit firewall
/etc/init.d/firewall restart
```

**Vía archivo manualmente:**
Editar `/etc/config/firewall`:
```
config rule
    option name 'Allow DNS'
    option proto 'udp'
    option dest_port '53'
    option target 'ACCEPT'
    option family 'ipv4'

config rule
    option name 'Allow DNS TCP'
    option proto 'tcp'
    option dest_port '53'
    option target 'ACCEPT'
    option family 'ipv4'
```

### Paso 2: Configurar BIND9 para escuchar en todas las interfaces

Editar `/etc/bind/named.conf.options`:
```bash
options {
    directory "/var/cache/bind";
    
    # Escuchar en todas las interfaces
    listen-on { any; };
    listen-on-v6 { any; };
    
    # Permitir consultas desde cualquier lugar (in tranet)
    allow-query { any; };
    
    # Recursión - importante para clientes
    recursion yes;
    allow-recursion { any; };
    
    # Seguridad
    dnssec-validation auto;
    
    # Forwarding a servidores upstream
    forwarders {
        8.8.8.8;
        8.8.4.4;
    };
};
```

### Paso 3: Verificar reglas activas
```bash
iptables -L -n | grep 53
```

---

## Configuración de Zonas

Ver documentos específicos:
- `02_CONFIGURACION_ZONAS_DIRECTA_INVERSA.md`
- `03_ARCHIVOS_ZONA_EJEMPLO.md`

---

## Verificación y Testing

Ver documento:
- `04_VERIFICACION_CON_HERRAMIENTAS.md`

---

## Registro de Errores

Ver documento:
- `05_LOGGING_Y_DIAGNOSTICO.md`

---

## Resumen de Archivos Configuración

| Archivo | Propósito | Permisos |
|---------|-----------|----------|
| `/etc/bind/named.conf` | Configuración principal | 644 |
| `/etc/bind/named.conf.options` | Opciones globales | 644 |
| `/etc/bind/named.conf.local` | Zonas locales | 644 |
| `/var/cache/bind/db.example.com` | Datos zona directa | 644 |
| `/var/cache/bind/db.0.168.192.in-addr.arpa` | Datos zona inversa | 644 |
| `/var/log/syslog` | Logs sistema (BIND9) | 644 |

---

## Comandos Útiles

```bash
# Iniciar/parar BIND9
/etc/init.d/named start
/etc/init.d/named stop
/etc/init.d/named restart
/etc/init.d/named status

# Validar configuración
named-checkconf
named-checkzone example.com /var/cache/bind/db.example.com

# Ver procesos
ps aux | grep named

# Logs en tiempo real
tail -f /var/log/syslog | grep named

# Estadísticas BIND9
rndc stats
```

---

## Notas Importantes

⚠️ **Firewall**: Asegúrate de permitir DNS (53/UDP y TCP) antes de iniciar BIND9

⚠️ **DHCP**: Configura los clientes DHCP para usar la IP del router como DNS (normalmente se hace automáticamente)

⚠️ **Recursión**: Cuidado con habilitar recursión sin restricciones (riesgo de amplificación DDoS)

⚠️ **Zonas**: Verifica sintaxis con `named-checkzone` antes de recargar

⚠️ **Permisos**: El usuario `named` debe tener permisos de lectura en los archivos de zona

---

**Siguientes pasos**:
1. Leer documento 02 para configuración de zonas
2. Leer documento 03 para ejemplos prácticos
3. Leer documento 04 para testing
4. Leer documento 05 para logging
