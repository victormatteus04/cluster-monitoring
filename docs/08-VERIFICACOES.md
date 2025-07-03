# ✅ Módulo 8: Verificações e Monitoramento

## 📋 Visão Geral

Este módulo apresenta scripts de verificação, health checks e procedimentos de monitoramento contínuo para garantir a operação confiável do sistema de monitoramento IF-UFG.

## 🔍 Scripts de Verificação

### **Script Principal de Verificação**

```bash
#!/bin/bash
# utils/verificar_sistema.sh

echo "🔍 VERIFICAÇÃO DO SISTEMA DE MONITORAMENTO IF-UFG"
echo "==============================================="
echo "Timestamp: $(date)"
echo "Hostname: $(hostname)"
echo

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Função para log colorido
log_status() {
    local status=$1
    local message=$2
    case $status in
        "OK")
            echo -e "${GREEN}✅ $message${NC}"
            ;;
        "WARNING")
            echo -e "${YELLOW}⚠️  $message${NC}"
            ;;
        "ERROR")
            echo -e "${RED}❌ $message${NC}"
            ;;
        "INFO")
            echo -e "${BLUE}ℹ️  $message${NC}"
            ;;
    esac
}

# Contadores de status
ok_count=0
warning_count=0
error_count=0

# 1. Verificar Docker e Containers
echo -e "${BLUE}🐳 VERIFICANDO CONTAINERS${NC}"
echo "-----------------------------"

if ! command -v docker &> /dev/null; then
    log_status "ERROR" "Docker não está instalado"
    ((error_count++))
else
    log_status "OK" "Docker instalado"
    
    # Verificar se Docker está rodando
    if ! docker info &> /dev/null; then
        log_status "ERROR" "Docker não está rodando"
        ((error_count++))
    else
        log_status "OK" "Docker rodando"
        ((ok_count++))
        
        # Verificar containers específicos
        containers=("grafana" "prometheus" "mosquitto" "alerting")
        for container in "${containers[@]}"; do
            if docker ps --format '{{.Names}}' | grep -q "^$container$"; then
                status=$(docker inspect --format='{{.State.Health.Status}}' $container 2>/dev/null || echo "running")
                if [ "$status" = "healthy" ] || [ "$status" = "running" ]; then
                    log_status "OK" "Container $container: $status"
                    ((ok_count++))
                else
                    log_status "WARNING" "Container $container: $status"
                    ((warning_count++))
                fi
            else
                log_status "ERROR" "Container $container não está rodando"
                ((error_count++))
            fi
        done
    fi
fi
echo

# 2. Verificar Conectividade de Rede
echo -e "${BLUE}🌐 VERIFICANDO CONECTIVIDADE${NC}"
echo "------------------------------"

endpoints=(
    "http://localhost:3000|Grafana"
    "http://localhost:9090|Prometheus"
    "http://localhost:8000/health|MQTT Exporter"
)

for endpoint_info in "${endpoints[@]}"; do
    IFS='|' read -r url name <<< "$endpoint_info"
    if curl -s -f --max-time 10 "$url" > /dev/null; then
        log_status "OK" "$name acessível"
        ((ok_count++))
    else
        log_status "ERROR" "$name não acessível ($url)"
        ((error_count++))
    fi
done

# Verificar MQTT
if mosquitto_pub -h localhost -p 1883 -t test -m "health_check" &> /dev/null; then
    log_status "OK" "MQTT Broker acessível"
    ((ok_count++))
else
    log_status "ERROR" "MQTT Broker não acessível"
    ((error_count++))
fi
echo

# 3. Verificar Recursos do Sistema
echo -e "${BLUE}💻 VERIFICANDO RECURSOS${NC}"
echo "------------------------"

# CPU
cpu_usage=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')
if (( $(echo "$cpu_usage > 80" | bc -l) )); then
    log_status "WARNING" "CPU alta: ${cpu_usage}%"
    ((warning_count++))
else
    log_status "OK" "CPU normal: ${cpu_usage}%"
    ((ok_count++))
fi

# Memória
mem_usage=$(free | grep Mem | awk '{printf "%.0f", ($3/$2) * 100.0}')
if [ "$mem_usage" -gt 80 ]; then
    log_status "WARNING" "Memória alta: ${mem_usage}%"
    ((warning_count++))
else
    log_status "OK" "Memória normal: ${mem_usage}%"
    ((ok_count++))
fi

# Disco
disk_usage=$(df /opt/cluster-monitoring | tail -1 | awk '{print $5}' | sed 's/%//')
if [ "$disk_usage" -gt 90 ]; then
    log_status "ERROR" "Disco cheio: ${disk_usage}%"
    ((error_count++))
elif [ "$disk_usage" -gt 80 ]; then
    log_status "WARNING" "Disco alto: ${disk_usage}%"
    ((warning_count++))
else
    log_status "OK" "Disco normal: ${disk_usage}%"
    ((ok_count++))
fi

# Load Average
load=$(uptime | awk -F'load average:' '{print $2}' | cut -d, -f1 | tr -d ' ')
cpu_cores=$(nproc)
if (( $(echo "$load > $cpu_cores * 2" | bc -l) )); then
    log_status "WARNING" "Load alto: $load (cores: $cpu_cores)"
    ((warning_count++))
else
    log_status "OK" "Load normal: $load"
    ((ok_count++))
fi
echo

# 4. Verificar Bancos de Dados
echo -e "${BLUE}🗄️ VERIFICANDO BANCOS${NC}"
echo "-----------------------"

# SQLite
db_path="/opt/cluster-monitoring/backend/alerting/data/alerts.db"
if [ -f "$db_path" ]; then
    log_status "OK" "Banco SQLite existe"
    ((ok_count++))
    
    # Verificar integridade
    if sqlite3 "$db_path" "PRAGMA integrity_check;" | grep -q "ok"; then
        log_status "OK" "Banco SQLite íntegro"
        ((ok_count++))
    else
        log_status "ERROR" "Banco SQLite corrompido"
        ((error_count++))
    fi
    
    # Verificar tamanho
    db_size=$(du -h "$db_path" | cut -f1)
    log_status "INFO" "Tamanho banco SQLite: $db_size"
    
    # Verificar registros
    alert_count=$(sqlite3 "$db_path" "SELECT COUNT(*) FROM alerts;" 2>/dev/null || echo "0")
    sensor_count=$(sqlite3 "$db_path" "SELECT COUNT(*) FROM sensor_data;" 2>/dev/null || echo "0")
    log_status "INFO" "Alertas: $alert_count | Dados sensores: $sensor_count"
else
    log_status "ERROR" "Banco SQLite não encontrado"
    ((error_count++))
fi

# Prometheus
prom_data="/opt/cluster-monitoring/backend/prometheus/data"
if [ -d "$prom_data" ]; then
    prom_size=$(du -sh "$prom_data" | cut -f1)
    log_status "OK" "Dados Prometheus: $prom_size"
    ((ok_count++))
else
    log_status "ERROR" "Dados Prometheus não encontrados"
    ((error_count++))
fi
echo

# 5. Verificar Sensores
echo -e "${BLUE}📡 VERIFICANDO SENSORES${NC}"
echo "------------------------"

if [ -f "$db_path" ]; then
    # Sensores ativos (últimos 5 minutos)
    active_sensors=$(sqlite3 "$db_path" "
        SELECT COUNT(DISTINCT sensor_id) 
        FROM sensor_data 
        WHERE timestamp > datetime('now', '-5 minutes')
    " 2>/dev/null || echo "0")
    
    if [ "$active_sensors" -eq 2 ]; then
        log_status "OK" "Todos os sensores ativos (2/2)"
        ((ok_count++))
    elif [ "$active_sensors" -eq 1 ]; then
        log_status "WARNING" "Apenas 1 sensor ativo (1/2)"
        ((warning_count++))
    else
        log_status "ERROR" "Nenhum sensor ativo (0/2)"
        ((error_count++))
    fi
    
    # Verificar cada sensor individualmente
    for sensor in "a" "b"; do
        last_data=$(sqlite3 "$db_path" "
            SELECT MAX(timestamp) 
            FROM sensor_data 
            WHERE sensor_id = '$sensor'
        " 2>/dev/null)
        
        if [ -n "$last_data" ]; then
            # Calcular diferença em minutos
            last_epoch=$(date -d "$last_data" +%s 2>/dev/null || echo "0")
            now_epoch=$(date +%s)
            diff_minutes=$(( (now_epoch - last_epoch) / 60 ))
            
            if [ "$diff_minutes" -le 5 ]; then
                log_status "OK" "Sensor $sensor: ativo (${diff_minutes}m atrás)"
                ((ok_count++))
            elif [ "$diff_minutes" -le 15 ]; then
                log_status "WARNING" "Sensor $sensor: atrasado (${diff_minutes}m atrás)"
                ((warning_count++))
            else
                log_status "ERROR" "Sensor $sensor: offline (${diff_minutes}m atrás)"
                ((error_count++))
            fi
        else
            log_status "ERROR" "Sensor $sensor: sem dados"
            ((error_count++))
        fi
    done
else
    log_status "ERROR" "Não foi possível verificar sensores"
    ((error_count++))
fi
echo

# 6. Verificar Alertas e Logs
echo -e "${BLUE}📝 VERIFICANDO ALERTAS E LOGS${NC}"
echo "-------------------------------"

# Logs recentes
log_dir="/opt/cluster-monitoring/logs"
if [ -d "$log_dir" ]; then
    log_status "OK" "Diretório de logs existe"
    ((ok_count++))
    
    # Verificar erros recentes
    recent_errors=$(find "$log_dir" -name "*.log" -mtime -1 -exec grep -i "error" {} \; 2>/dev/null | wc -l)
    if [ "$recent_errors" -eq 0 ]; then
        log_status "OK" "Nenhum erro recente nos logs"
        ((ok_count++))
    elif [ "$recent_errors" -le 5 ]; then
        log_status "WARNING" "$recent_errors erros recentes nos logs"
        ((warning_count++))
    else
        log_status "ERROR" "$recent_errors erros recentes nos logs"
        ((error_count++))
    fi
    
    # Alertas nas últimas 24h
    if [ -f "$db_path" ]; then
        recent_alerts=$(sqlite3 "$db_path" "
            SELECT COUNT(*) FROM alerts 
            WHERE timestamp > datetime('now', '-24 hours')
        " 2>/dev/null || echo "0")
        
        if [ "$recent_alerts" -eq 0 ]; then
            log_status "OK" "Nenhum alerta nas últimas 24h"
            ((ok_count++))
        elif [ "$recent_alerts" -le 10 ]; then
            log_status "WARNING" "$recent_alerts alertas nas últimas 24h"
            ((warning_count++))
        else
            log_status "ERROR" "$recent_alerts alertas nas últimas 24h (muitos)"
            ((error_count++))
        fi
    fi
else
    log_status "ERROR" "Diretório de logs não encontrado"
    ((error_count++))
fi
echo

# 7. Verificar Configurações
echo -e "${BLUE}⚙️ VERIFICANDO CONFIGURAÇÕES${NC}"
echo "-----------------------------"

configs=(
    "backend/alerting/config.py|Config Alertas"
    "backend/prometheus/prometheus.yml|Config Prometheus"
    "backend/docker-compose.yaml|Docker Compose"
    "start.sh|Script Start"
    "stop.sh|Script Stop"
)

for config_info in "${configs[@]}"; do
    IFS='|' read -r file name <<< "$config_info"
    if [ -f "$file" ]; then
        if [ -r "$file" ]; then
            log_status "OK" "$name legível"
            ((ok_count++))
        else
            log_status "WARNING" "$name sem permissão de leitura"
            ((warning_count++))
        fi
    else
        log_status "ERROR" "$name não encontrado"
        ((error_count++))
    fi
done
echo

# 8. Verificar Conectividade Externa
echo -e "${BLUE}🌍 VERIFICANDO CONECTIVIDADE EXTERNA${NC}"
echo "-------------------------------------"

# Internet
if ping -c 1 8.8.8.8 &> /dev/null; then
    log_status "OK" "Conectividade internet"
    ((ok_count++))
else
    log_status "WARNING" "Sem conectividade internet"
    ((warning_count++))
fi

# DNS
if nslookup google.com &> /dev/null; then
    log_status "OK" "Resolução DNS"
    ((ok_count++))
else
    log_status "WARNING" "Problemas DNS"
    ((warning_count++))
fi

# SMTP (se configurado)
if command -v telnet &> /dev/null; then
    if timeout 5 telnet smtp.gmail.com 587 &> /dev/null; then
        log_status "OK" "SMTP Gmail acessível"
        ((ok_count++))
    else
        log_status "WARNING" "SMTP Gmail não acessível"
        ((warning_count++))
    fi
fi
echo

# 9. Resumo Final
echo -e "${BLUE}📊 RESUMO DA VERIFICAÇÃO${NC}"
echo "-------------------------"

total_checks=$((ok_count + warning_count + error_count))
echo "Total de verificações: $total_checks"
echo -e "${GREEN}✅ OK: $ok_count${NC}"
echo -e "${YELLOW}⚠️  Avisos: $warning_count${NC}"
echo -e "${RED}❌ Erros: $error_count${NC}"
echo

# Status geral
if [ $error_count -eq 0 ] && [ $warning_count -eq 0 ]; then
    echo -e "${GREEN}🎯 SISTEMA FUNCIONANDO PERFEITAMENTE${NC}"
    exit 0
elif [ $error_count -eq 0 ]; then
    echo -e "${YELLOW}⚠️  SISTEMA FUNCIONANDO COM AVISOS${NC}"
    exit 1
else
    echo -e "${RED}🚨 SISTEMA COM PROBLEMAS CRÍTICOS${NC}"
    exit 2
fi
```

### **Health Check Automatizado**

```bash
#!/bin/bash
# utils/health_check.sh

# Health check simplificado para uso em cron
LOGFILE="/opt/cluster-monitoring/logs/health.log"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# Função para log
log() {
    echo "[$TIMESTAMP] $1" >> "$LOGFILE"
}

# Verificações críticas
errors=0

# 1. Containers
if ! docker ps --format '{{.Names}}' | grep -q "grafana\|prometheus\|mosquitto\|alerting"; then
    log "ERROR: Containers críticos não estão rodando"
    ((errors++))
fi

# 2. Endpoints
for port in 3000 9090 8000 1883; do
    if ! nc -z localhost $port; then
        log "ERROR: Porta $port não acessível"
        ((errors++))
    fi
done

# 3. Banco de dados
db_path="/opt/cluster-monitoring/backend/alerting/data/alerts.db"
if [ -f "$db_path" ]; then
    if ! sqlite3 "$db_path" "SELECT 1;" &> /dev/null; then
        log "ERROR: Banco SQLite com problemas"
        ((errors++))
    fi
else
    log "ERROR: Banco SQLite não encontrado"
    ((errors++))
fi

# 4. Sensores ativos
if [ -f "$db_path" ]; then
    active_sensors=$(sqlite3 "$db_path" "
        SELECT COUNT(DISTINCT sensor_id) 
        FROM sensor_data 
        WHERE timestamp > datetime('now', '-10 minutes')
    " 2>/dev/null || echo "0")
    
    if [ "$active_sensors" -lt 1 ]; then
        log "WARNING: Nenhum sensor ativo nos últimos 10 minutos"
    elif [ "$active_sensors" -lt 2 ]; then
        log "WARNING: Apenas $active_sensors sensor ativo"
    fi
fi

# 5. Espaço em disco
disk_usage=$(df /opt/cluster-monitoring | tail -1 | awk '{print $5}' | sed 's/%//')
if [ "$disk_usage" -gt 90 ]; then
    log "ERROR: Disco cheio: ${disk_usage}%"
    ((errors++))
elif [ "$disk_usage" -gt 80 ]; then
    log "WARNING: Disco alto: ${disk_usage}%"
fi

# Resultado
if [ $errors -eq 0 ]; then
    log "OK: Sistema funcionando normalmente"
    exit 0
else
    log "ERROR: $errors problemas críticos detectados"
    exit 1
fi
```

## 📊 Monitoramento de Performance

### **Script de Monitoramento de Recursos**

```bash
#!/bin/bash
# utils/monitorar_recursos.sh

METRICS_FILE="/opt/cluster-monitoring/logs/metrics.log"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# Coleta de métricas
CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')
MEM_USAGE=$(free | grep Mem | awk '{printf "%.1f", ($3/$2) * 100.0}')
DISK_USAGE=$(df /opt/cluster-monitoring | tail -1 | awk '{print $5}' | sed 's/%//')
LOAD_AVG=$(uptime | awk -F'load average:' '{print $2}' | cut -d, -f1 | tr -d ' ')

# Métricas Docker
DOCKER_CONTAINERS=$(docker ps --format '{{.Names}}' | wc -l)

# Métricas do banco
DB_PATH="/opt/cluster-monitoring/backend/alerting/data/alerts.db"
if [ -f "$DB_PATH" ]; then
    DB_SIZE=$(du -m "$DB_PATH" | cut -f1)
    ALERT_COUNT=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM alerts;" 2>/dev/null || echo "0")
    SENSOR_COUNT=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM sensor_data;" 2>/dev/null || echo "0")
else
    DB_SIZE=0
    ALERT_COUNT=0
    SENSOR_COUNT=0
fi

# Métricas de rede
ACTIVE_CONNECTIONS=$(ss -tuln | grep -E ":(3000|9090|1883|8000)" | wc -l)

# Log em formato CSV
echo "$TIMESTAMP,$CPU_USAGE,$MEM_USAGE,$DISK_USAGE,$LOAD_AVG,$DOCKER_CONTAINERS,$DB_SIZE,$ALERT_COUNT,$SENSOR_COUNT,$ACTIVE_CONNECTIONS" >> "$METRICS_FILE"

# Criar header se arquivo for novo
if [ ! -s "$METRICS_FILE" ] || [ $(wc -l < "$METRICS_FILE") -eq 1 ]; then
    sed -i '1i timestamp,cpu_usage,memory_usage,disk_usage,load_avg,docker_containers,db_size_mb,alerts,sensor_data,active_connections' "$METRICS_FILE"
fi

# Alertas de threshold
if (( $(echo "$CPU_USAGE > 90" | bc -l) )); then
    echo "[$TIMESTAMP] ALERT: CPU muito alta: $CPU_USAGE%" >> /opt/cluster-monitoring/logs/alerts.log
fi

if [ "$MEM_USAGE" -gt 90 ]; then
    echo "[$TIMESTAMP] ALERT: Memória muito alta: $MEM_USAGE%" >> /opt/cluster-monitoring/logs/alerts.log
fi

if [ "$DISK_USAGE" -gt 90 ]; then
    echo "[$TIMESTAMP] ALERT: Disco muito cheio: $DISK_USAGE%" >> /opt/cluster-monitoring/logs/alerts.log
fi
```

### **Script de Análise de Performance**

```python
#!/usr/bin/env python3
# utils/analisar_performance.py

import pandas as pd
import matplotlib.pyplot as plt
import sys
from datetime import datetime, timedelta

def analisar_metricas(arquivo_metricas):
    """Analisar métricas de performance"""
    
    try:
        # Ler dados
        df = pd.read_csv(arquivo_metricas)
        df['timestamp'] = pd.to_datetime(df['timestamp'])
        
        # Últimas 24 horas
        df_24h = df[df['timestamp'] > datetime.now() - timedelta(hours=24)]
        
        if df_24h.empty:
            print("❌ Sem dados das últimas 24 horas")
            return
        
        print("📊 ANÁLISE DE PERFORMANCE - ÚLTIMAS 24H")
        print("=" * 40)
        
        # Estatísticas básicas
        print(f"📈 CPU:")
        print(f"  Média: {df_24h['cpu_usage'].mean():.1f}%")
        print(f"  Máximo: {df_24h['cpu_usage'].max():.1f}%")
        print(f"  Mínimo: {df_24h['cpu_usage'].min():.1f}%")
        
        print(f"\n💾 Memória:")
        print(f"  Média: {df_24h['memory_usage'].mean():.1f}%")
        print(f"  Máximo: {df_24h['memory_usage'].max():.1f}%")
        print(f"  Mínimo: {df_24h['memory_usage'].min():.1f}%")
        
        print(f"\n💿 Disco:")
        print(f"  Atual: {df_24h['disk_usage'].iloc[-1]}%")
        print(f"  Tendência: {'+' if df_24h['disk_usage'].iloc[-1] > df_24h['disk_usage'].iloc[0] else '-'}")
        
        print(f"\n🗄️ Banco de Dados:")
        print(f"  Tamanho: {df_24h['db_size_mb'].iloc[-1]} MB")
        print(f"  Alertas: {df_24h['alerts'].iloc[-1]}")
        print(f"  Dados sensores: {df_24h['sensor_data'].iloc[-1]}")
        
        # Alertas de threshold
        cpu_high = len(df_24h[df_24h['cpu_usage'] > 80])
        mem_high = len(df_24h[df_24h['memory_usage'] > 80])
        
        print(f"\n⚠️ Alertas de Threshold:")
        print(f"  CPU > 80%: {cpu_high} ocorrências")
        print(f"  Memória > 80%: {mem_high} ocorrências")
        
        # Gerar gráfico
        fig, axes = plt.subplots(2, 2, figsize=(15, 10))
        fig.suptitle('Performance Sistema IF-UFG - Últimas 24h', fontsize=16)
        
        # CPU
        axes[0,0].plot(df_24h['timestamp'], df_24h['cpu_usage'])
        axes[0,0].set_title('CPU Usage (%)')
        axes[0,0].set_ylabel('Percentage')
        axes[0,0].axhline(y=80, color='r', linestyle='--', alpha=0.7)
        axes[0,0].grid(True, alpha=0.3)
        
        # Memória
        axes[0,1].plot(df_24h['timestamp'], df_24h['memory_usage'], color='orange')
        axes[0,1].set_title('Memory Usage (%)')
        axes[0,1].set_ylabel('Percentage')
        axes[0,1].axhline(y=80, color='r', linestyle='--', alpha=0.7)
        axes[0,1].grid(True, alpha=0.3)
        
        # Disco
        axes[1,0].plot(df_24h['timestamp'], df_24h['disk_usage'], color='green')
        axes[1,0].set_title('Disk Usage (%)')
        axes[1,0].set_ylabel('Percentage')
        axes[1,0].axhline(y=90, color='r', linestyle='--', alpha=0.7)
        axes[1,0].grid(True, alpha=0.3)
        
        # Banco de dados
        axes[1,1].plot(df_24h['timestamp'], df_24h['db_size_mb'], color='purple')
        axes[1,1].set_title('Database Size (MB)')
        axes[1,1].set_ylabel('Size (MB)')
        axes[1,1].grid(True, alpha=0.3)
        
        # Ajustar layout
        plt.tight_layout()
        
        # Salvar gráfico
        output_file = f"performance_report_{datetime.now().strftime('%Y%m%d_%H%M%S')}.png"
        plt.savefig(output_file, dpi=150, bbox_inches='tight')
        plt.close()
        
        print(f"\n📊 Gráfico salvo em: {output_file}")
        
    except Exception as e:
        print(f"❌ Erro na análise: {e}")

if __name__ == "__main__":
    arquivo = "/opt/cluster-monitoring/logs/metrics.log"
    if len(sys.argv) > 1:
        arquivo = sys.argv[1]
    
    analisar_metricas(arquivo)
```

## 🔔 Alertas de Sistema

### **Script de Alertas Críticos**

```bash
#!/bin/bash
# utils/alertas_criticos.sh

ALERT_LOG="/opt/cluster-monitoring/logs/critical_alerts.log"
EMAIL_TO="admin@ifufg.ufg.br"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# Função para enviar alerta crítico
send_critical_alert() {
    local subject="$1"
    local message="$2"
    
    echo "[$TIMESTAMP] CRITICAL: $subject - $message" >> "$ALERT_LOG"
    
    # Enviar email se configurado
    if command -v mail &> /dev/null; then
        echo "$message" | mail -s "[IF-UFG CRÍTICO] $subject" "$EMAIL_TO"
    fi
    
    # Log no sistema
    logger -t cluster-monitoring "CRITICAL: $subject - $message"
}

# Verificações críticas

# 1. Sistema fora do ar
if ! curl -s -f http://localhost:3000 > /dev/null; then
    if ! curl -s -f http://localhost:9090 > /dev/null; then
        send_critical_alert "Sistema Fora do Ar" "Grafana e Prometheus não acessíveis"
    fi
fi

# 2. Todos os sensores offline
DB_PATH="/opt/cluster-monitoring/backend/alerting/data/alerts.db"
if [ -f "$DB_PATH" ]; then
    active_sensors=$(sqlite3 "$DB_PATH" "
        SELECT COUNT(DISTINCT sensor_id) 
        FROM sensor_data 
        WHERE timestamp > datetime('now', '-15 minutes')
    " 2>/dev/null || echo "0")
    
    if [ "$active_sensors" -eq 0 ]; then
        send_critical_alert "Todos Sensores Offline" "Nenhum sensor enviando dados há mais de 15 minutos"
    fi
fi

# 3. Disco cheio
disk_usage=$(df /opt/cluster-monitoring | tail -1 | awk '{print $5}' | sed 's/%//')
if [ "$disk_usage" -gt 95 ]; then
    send_critical_alert "Disco Crítico" "Uso de disco: ${disk_usage}% - Sistema pode parar"
fi

# 4. Containers parados
running_containers=$(docker ps --format '{{.Names}}' | grep -E "(grafana|prometheus|mosquitto|alerting)" | wc -l)
if [ "$running_containers" -lt 4 ]; then
    stopped=$(docker ps -a --format '{{.Names}} {{.Status}}' | grep -E "(grafana|prometheus|mosquitto|alerting)" | grep -v "Up")
    send_critical_alert "Containers Parados" "Containers não rodando: $stopped"
fi

# 5. Banco corrompido
if [ -f "$DB_PATH" ]; then
    if ! sqlite3 "$DB_PATH" "PRAGMA integrity_check;" | grep -q "ok"; then
        send_critical_alert "Banco Corrompido" "Banco SQLite falhou na verificação de integridade"
    fi
fi
```

## 📈 Relatórios Automatizados

### **Relatório Diário**

```bash
#!/bin/bash
# utils/relatorio_diario.sh

REPORT_DIR="/opt/cluster-monitoring/reports"
DATE=$(date '+%Y-%m-%d')
REPORT_FILE="$REPORT_DIR/relatorio_$DATE.html"

mkdir -p "$REPORT_DIR"

# Gerar relatório HTML
cat > "$REPORT_FILE" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Relatório Diário IF-UFG - $DATE</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background-color: #2e7d32; color: white; padding: 20px; text-align: center; }
        .section { margin: 20px 0; padding: 15px; border: 1px solid #ddd; border-radius: 5px; }
        .ok { color: green; }
        .warning { color: orange; }
        .error { color: red; }
        table { width: 100%; border-collapse: collapse; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
    </style>
</head>
<body>
    <div class="header">
        <h1>Relatório Diário - Sistema de Monitoramento</h1>
        <p>Instituto de Física - UFG</p>
        <p>Data: $DATE</p>
    </div>
    
    <div class="section">
        <h2>Resumo Executivo</h2>
        <p>Status geral do sistema nas últimas 24 horas.</p>
        
        <h3>Indicadores Principais</h3>
        <table>
            <tr><th>Métrica</th><th>Status</th><th>Valor</th></tr>
EOF

# Coletar métricas
DB_PATH="/opt/cluster-monitoring/backend/alerting/data/alerts.db"

# Uptime do sistema
if systemctl is-active docker &> /dev/null; then
    echo "            <tr><td>Docker</td><td class='ok'>✅ Ativo</td><td>Rodando</td></tr>" >> "$REPORT_FILE"
else
    echo "            <tr><td>Docker</td><td class='error'>❌ Inativo</td><td>Parado</td></tr>" >> "$REPORT_FILE"
fi

# Containers
running_containers=$(docker ps --format '{{.Names}}' | wc -l)
echo "            <tr><td>Containers</td><td class='ok'>✅ OK</td><td>$running_containers rodando</td></tr>" >> "$REPORT_FILE"

# Sensores
if [ -f "$DB_PATH" ]; then
    active_sensors=$(sqlite3 "$DB_PATH" "
        SELECT COUNT(DISTINCT sensor_id) 
        FROM sensor_data 
        WHERE timestamp > datetime('now', '-24 hours')
    " 2>/dev/null || echo "0")
    
    total_readings=$(sqlite3 "$DB_PATH" "
        SELECT COUNT(*) 
        FROM sensor_data 
        WHERE timestamp > datetime('now', '-24 hours')
    " 2>/dev/null || echo "0")
    
    alerts_24h=$(sqlite3 "$DB_PATH" "
        SELECT COUNT(*) 
        FROM alerts 
        WHERE timestamp > datetime('now', '-24 hours')
    " 2>/dev/null || echo "0")
    
    echo "            <tr><td>Sensores Ativos</td><td class='ok'>✅ OK</td><td>$active_sensors sensores</td></tr>" >> "$REPORT_FILE"
    echo "            <tr><td>Leituras (24h)</td><td class='ok'>✅ OK</td><td>$total_readings leituras</td></tr>" >> "$REPORT_FILE"
    echo "            <tr><td>Alertas (24h)</td><td class='warning'>⚠️ Monitorar</td><td>$alerts_24h alertas</td></tr>" >> "$REPORT_FILE"
fi

# Recursos
cpu_avg=$(awk -F, '{sum+=$2; count++} END {if(count>0) print sum/count; else print 0}' /opt/cluster-monitoring/logs/metrics.log 2>/dev/null | tail -1)
mem_avg=$(awk -F, '{sum+=$3; count++} END {if(count>0) print sum/count; else print 0}' /opt/cluster-monitoring/logs/metrics.log 2>/dev/null | tail -1)
disk_current=$(df /opt/cluster-monitoring | tail -1 | awk '{print $5}' | sed 's/%//')

echo "            <tr><td>CPU Média (24h)</td><td class='ok'>✅ OK</td><td>${cpu_avg:-N/A}%</td></tr>" >> "$REPORT_FILE"
echo "            <tr><td>Memória Média (24h)</td><td class='ok'>✅ OK</td><td>${mem_avg:-N/A}%</td></tr>" >> "$REPORT_FILE"
echo "            <tr><td>Uso de Disco</td><td class='ok'>✅ OK</td><td>${disk_current}%</td></tr>" >> "$REPORT_FILE"

cat >> "$REPORT_FILE" << EOF
        </table>
    </div>
    
    <div class="section">
        <h2>Detalhes dos Sensores</h2>
EOF

# Detalhes por sensor
if [ -f "$DB_PATH" ]; then
    echo "        <table>" >> "$REPORT_FILE"
    echo "            <tr><th>Sensor</th><th>Última Leitura</th><th>Temp. Atual</th><th>Umidade Atual</th><th>WiFi RSSI</th></tr>" >> "$REPORT_FILE"
    
    for sensor in "a" "b"; do
        sensor_data=$(sqlite3 "$DB_PATH" "
            SELECT temperature, humidity, wifi_rssi, timestamp
            FROM sensor_data 
            WHERE sensor_id = '$sensor'
            ORDER BY timestamp DESC 
            LIMIT 1
        " 2>/dev/null)
        
        if [ -n "$sensor_data" ]; then
            IFS='|' read -r temp humidity rssi timestamp <<< "$sensor_data"
            echo "            <tr><td>Sensor $sensor</td><td>$timestamp</td><td>${temp}°C</td><td>${humidity}%</td><td>${rssi} dBm</td></tr>" >> "$REPORT_FILE"
        else
            echo "            <tr><td>Sensor $sensor</td><td colspan='4' class='error'>❌ Sem dados</td></tr>" >> "$REPORT_FILE"
        fi
    done
    
    echo "        </table>" >> "$REPORT_FILE"
fi

cat >> "$REPORT_FILE" << EOF
    </div>
    
    <div class="section">
        <h2>Alertas Recentes</h2>
EOF

# Alertas das últimas 24h
if [ -f "$DB_PATH" ]; then
    echo "        <table>" >> "$REPORT_FILE"
    echo "            <tr><th>Timestamp</th><th>Sensor</th><th>Tipo</th><th>Nível</th><th>Descrição</th></tr>" >> "$REPORT_FILE"
    
    sqlite3 "$DB_PATH" "
        SELECT timestamp, sensor_id, alert_type, alert_level, description
        FROM alerts 
        WHERE timestamp > datetime('now', '-24 hours')
        ORDER BY timestamp DESC 
        LIMIT 10
    " 2>/dev/null | while IFS='|' read -r timestamp sensor_id alert_type alert_level description; do
        case $alert_level in
            "CRITICAL") class="error" ;;
            "WARNING") class="warning" ;;
            *) class="ok" ;;
        esac
        echo "            <tr><td>$timestamp</td><td>$sensor_id</td><td>$alert_type</td><td class='$class'>$alert_level</td><td>$description</td></tr>" >> "$REPORT_FILE"
    done
    
    echo "        </table>" >> "$REPORT_FILE"
fi

cat >> "$REPORT_FILE" << EOF
    </div>
    
    <div class="section">
        <h2>Recomendações</h2>
        <ul>
            <li>Verificar logs diariamente</li>
            <li>Monitorar uso de disco</li>
            <li>Validar funcionamento dos sensores</li>
            <li>Realizar backup semanal</li>
        </ul>
    </div>
    
    <div class="section">
        <h2>Contatos</h2>
        <p><strong>Suporte Técnico:</strong> suporte-ti@ifufg.ufg.br</p>
        <p><strong>Emergência:</strong> (62) 9999-9999</p>
    </div>
    
    <footer style="text-align: center; margin-top: 30px; color: #666; font-size: 12px;">
        <p>Relatório gerado automaticamente pelo Sistema de Monitoramento IF-UFG</p>
        <p>Gerado em: $(date)</p>
    </footer>
</body>
</html>
EOF

echo "📊 Relatório diário gerado: $REPORT_FILE"

# Enviar por email se configurado
if command -v mail &> /dev/null; then
    {
        echo "Segue em anexo o relatório diário do sistema de monitoramento IF-UFG."
        echo
        echo "Data: $DATE"
        echo "Arquivo: $REPORT_FILE"
        echo
        echo "Atenciosamente,"
        echo "Sistema de Monitoramento IF-UFG"
    } | mail -s "[IF-UFG] Relatório Diário - $DATE" -A "$REPORT_FILE" admin@ifufg.ufg.br
fi
```

## ⏰ Agendamento Automático

### **Configuração Cron**

```bash
# Editar crontab
crontab -e

# Adicionar tarefas:

# Health check a cada 5 minutos
*/5 * * * * /opt/cluster-monitoring/utils/health_check.sh >> /opt/cluster-monitoring/logs/health.log 2>&1

# Verificação completa a cada hora
0 * * * * /opt/cluster-monitoring/utils/verificar_sistema.sh >> /opt/cluster-monitoring/logs/verification.log 2>&1

# Monitoramento de recursos a cada 15 minutos
*/15 * * * * /opt/cluster-monitoring/utils/monitorar_recursos.sh

# Alertas críticos a cada 10 minutos
*/10 * * * * /opt/cluster-monitoring/utils/alertas_criticos.sh

# Backup diário às 2h
0 2 * * * /opt/cluster-monitoring/utils/backup_completo.sh >> /opt/cluster-monitoring/logs/backup.log 2>&1

# Relatório diário às 8h
0 8 * * * /opt/cluster-monitoring/utils/relatorio_diario.sh >> /opt/cluster-monitoring/logs/reports.log 2>&1

# Limpeza semanal aos domingos às 3h
0 3 * * 0 /opt/cluster-monitoring/utils/limpar_dados_antigos.sh >> /opt/cluster-monitoring/logs/cleanup.log 2>&1

# Análise de performance semanal às segundas às 9h
0 9 * * 1 /opt/cluster-monitoring/utils/analisar_performance.py >> /opt/cluster-monitoring/logs/performance.log 2>&1

# Verificar e rotar logs diariamente à meia-noite
0 0 * * * /usr/sbin/logrotate /etc/logrotate.d/cluster-monitoring
```

### **Script de Inicialização do Sistema**

```bash
#!/bin/bash
# /etc/systemd/system/cluster-monitoring.service

# Criar arquivo de serviço systemd
sudo tee /etc/systemd/system/cluster-monitoring.service << 'EOF'
[Unit]
Description=Cluster Monitoring IF-UFG
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/cluster-monitoring
ExecStart=/opt/cluster-monitoring/start.sh
ExecStop=/opt/cluster-monitoring/stop.sh
User=ubuntu
Group=ubuntu
TimeoutStartSec=300

[Install]
WantedBy=multi-user.target
EOF

# Habilitar serviço
sudo systemctl daemon-reload
sudo systemctl enable cluster-monitoring
sudo systemctl start cluster-monitoring

echo "✅ Serviço cluster-monitoring configurado"
```

## 📋 Checklist de Verificação

### **Verificação Diária**
- [ ] Todos os containers rodando
- [ ] Sensores enviando dados
- [ ] Dashboards acessíveis
- [ ] Alertas funcionando
- [ ] Espaço em disco suficiente
- [ ] Logs sem erros críticos

### **Verificação Semanal**
- [ ] Backup funcionando
- [ ] Performance adequada
- [ ] Limpeza de dados executada
- [ ] Relatórios gerados
- [ ] Configurações atualizadas

### **Verificação Mensal**
- [ ] Análise de tendências
- [ ] Otimização de queries
- [ ] Atualização de documentação
- [ ] Revisão de alertas
- [ ] Teste de recovery

### **Verificação Anual**
- [ ] Auditoria completa
- [ ] Atualização de software
- [ ] Revisão de segurança
- [ ] Planejamento de capacidade
- [ ] Treinamento de equipe

---

**🏠 Voltar**: [Manual Principal](README.md)  
**📚 Documentação Completa**: Todos os módulos criados! 