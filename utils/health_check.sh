#!/bin/bash

# =============================================================================
# Health Check Automático - IF-UFG
# =============================================================================

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configurações
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
LOG_FILE="$PROJECT_DIR/logs/health_check.log"
STATUS_FILE="$PROJECT_DIR/logs/health_status.json"
ALERT_FILE="$PROJECT_DIR/logs/health_alerts.log"

# Thresholds
CPU_THRESHOLD=80
MEM_THRESHOLD=80
DISK_THRESHOLD=85
SENSOR_TIMEOUT=600  # 10 minutos

# Função para logging
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Função para alertas
alert() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ALERT: $1" | tee -a "$ALERT_FILE"
}

# Função para status JSON
update_status() {
    local component="$1"
    local status="$2"
    local message="$3"
    
    # Criar arquivo de status se não existir
    if [ ! -f "$STATUS_FILE" ]; then
        echo '{}' > "$STATUS_FILE"
    fi
    
    # Atualizar status usando jq
    jq --arg comp "$component" --arg stat "$status" --arg msg "$message" --arg ts "$(date -Iseconds)" \
       '.[$comp] = {status: $stat, message: $msg, timestamp: $ts}' \
       "$STATUS_FILE" > "${STATUS_FILE}.tmp" && mv "${STATUS_FILE}.tmp" "$STATUS_FILE"
}

# Verificar Docker
check_docker() {
    if ! command -v docker &> /dev/null; then
        update_status "docker" "ERROR" "Docker não instalado"
        return 1
    fi
    
    if ! docker ps &> /dev/null; then
        update_status "docker" "ERROR" "Docker daemon não está rodando"
        alert "Docker daemon não está rodando"
        return 1
    fi
    
    update_status "docker" "OK" "Docker funcionando"
    return 0
}

# Verificar Containers
check_containers() {
    local containers=("grafana" "prometheus" "backend" "mqtt")
    local running=0
    local total=${#containers[@]}
    
    for container in "${containers[@]}"; do
        if docker ps --format "table {{.Names}}" | grep -q "$container"; then
            ((running++))
        else
            alert "Container $container não está rodando"
        fi
    done
    
    if [ $running -eq $total ]; then
        update_status "containers" "OK" "Todos os containers rodando ($running/$total)"
    elif [ $running -gt 0 ]; then
        update_status "containers" "WARNING" "Alguns containers não estão rodando ($running/$total)"
    else
        update_status "containers" "ERROR" "Nenhum container rodando"
    fi
    
    return $((total - running))
}

# Verificar Portas
check_ports() {
    local ports=(3000 9090 1883 8080)
    local services=("Grafana" "Prometheus" "MQTT" "Backend")
    local open_ports=0
    
    for i in "${!ports[@]}"; do
        local port="${ports[$i]}"
        local service="${services[$i]}"
        
        if netstat -tuln | grep -q ":$port "; then
            ((open_ports++))
        else
            alert "Porta $port ($service) não está aberta"
        fi
    done
    
    if [ $open_ports -eq ${#ports[@]} ]; then
        update_status "ports" "OK" "Todas as portas abertas ($open_ports/${#ports[@]})"
    else
        update_status "ports" "ERROR" "Algumas portas não estão abertas ($open_ports/${#ports[@]})"
    fi
    
    return $((${#ports[@]} - open_ports))
}

# Verificar Recursos
check_resources() {
    # CPU
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')
    
    # Memória
    local mem_usage=$(free | grep "Mem:" | awk '{printf "%.0f", $3/$2 * 100.0}')
    
    # Disco
    local disk_usage=$(df -h / | tail -1 | awk '{print $5}' | sed 's/%//')
    
    local resource_alerts=0
    
    # Verificar CPU
    if (( $(echo "$cpu_usage > $CPU_THRESHOLD" | bc -l) )); then
        alert "CPU alta: ${cpu_usage}%"
        ((resource_alerts++))
    fi
    
    # Verificar Memória
    if [ $mem_usage -gt $MEM_THRESHOLD ]; then
        alert "Memória alta: ${mem_usage}%"
        ((resource_alerts++))
    fi
    
    # Verificar Disco
    if [ $disk_usage -gt $DISK_THRESHOLD ]; then
        alert "Disco cheio: ${disk_usage}%"
        ((resource_alerts++))
    fi
    
    # Status
    if [ $resource_alerts -eq 0 ]; then
        update_status "resources" "OK" "CPU: ${cpu_usage}%, Mem: ${mem_usage}%, Disk: ${disk_usage}%"
    else
        update_status "resources" "WARNING" "Recursos altos - CPU: ${cpu_usage}%, Mem: ${mem_usage}%, Disk: ${disk_usage}%"
    fi
    
    return $resource_alerts
}

# Verificar Conectividade
check_connectivity() {
    local connectivity_issues=0
    
    # Internet
    if ! ping -c 1 8.8.8.8 &> /dev/null; then
        alert "Sem conectividade externa"
        ((connectivity_issues++))
    fi
    
    # Grafana
    if ! curl -s http://localhost:3000/api/health &> /dev/null; then
        alert "Grafana não está respondendo"
        ((connectivity_issues++))
    fi
    
    # Prometheus
    if ! curl -s http://localhost:9090/-/healthy &> /dev/null; then
        alert "Prometheus não está respondendo"
        ((connectivity_issues++))
    fi
    
    # Backend
    if ! curl -s http://localhost:8080/health &> /dev/null; then
        alert "Backend não está respondendo"
        ((connectivity_issues++))
    fi
    
    if [ $connectivity_issues -eq 0 ]; then
        update_status "connectivity" "OK" "Todos os serviços respondendo"
    else
        update_status "connectivity" "ERROR" "$connectivity_issues serviços não respondendo"
    fi
    
    return $connectivity_issues
}

# Verificar Sensores
check_sensors() {
    local backend_url="http://localhost:8080"
    local sensor_issues=0
    
    # Verificar se backend está respondendo
    if ! curl -s "$backend_url/health" &> /dev/null; then
        update_status "sensors" "ERROR" "Backend não acessível"
        return 1
    fi
    
    # Verificar sensores individuais
    local sensors=("a" "b")
    local active_sensors=0
    
    for sensor in "${sensors[@]}"; do
        # Verificar última leitura do sensor
        local last_reading=$(curl -s "$backend_url/sensors/$sensor/last" 2>/dev/null)
        
        if [ -n "$last_reading" ]; then
            local last_timestamp=$(echo "$last_reading" | jq -r '.timestamp' 2>/dev/null)
            
            if [ "$last_timestamp" != "null" ] && [ -n "$last_timestamp" ]; then
                local time_diff=$(( $(date +%s) - $(date -d "$last_timestamp" +%s) ))
                
                if [ $time_diff -lt $SENSOR_TIMEOUT ]; then
                    ((active_sensors++))
                else
                    alert "Sensor $sensor offline há $((time_diff / 60)) minutos"
                    ((sensor_issues++))
                fi
            else
                alert "Sensor $sensor sem dados"
                ((sensor_issues++))
            fi
        else
            alert "Sensor $sensor não encontrado"
            ((sensor_issues++))
        fi
    done
    
    if [ $sensor_issues -eq 0 ]; then
        update_status "sensors" "OK" "Todos os sensores ativos ($active_sensors/${#sensors[@]})"
    else
        update_status "sensors" "WARNING" "Problemas com sensores ($active_sensors/${#sensors[@]} ativos)"
    fi
    
    return $sensor_issues
}

# Verificar Banco de Dados
check_database() {
    local db_file="$PROJECT_DIR/backend/database.db"
    
    if [ ! -f "$db_file" ]; then
        update_status "database" "ERROR" "Banco de dados não encontrado"
        alert "Banco de dados não encontrado"
        return 1
    fi
    
    # Verificar integridade
    if ! sqlite3 "$db_file" "PRAGMA integrity_check;" | grep -q "ok"; then
        update_status "database" "ERROR" "Banco de dados corrompido"
        alert "Banco de dados corrompido"
        return 1
    fi
    
    # Verificar dados recentes
    local recent_count=$(sqlite3 "$db_file" "SELECT COUNT(*) FROM readings WHERE timestamp > datetime('now', '-1 hour');" 2>/dev/null)
    
    if [ -z "$recent_count" ] || [ "$recent_count" -eq 0 ]; then
        update_status "database" "WARNING" "Sem dados recentes no banco"
    else
        update_status "database" "OK" "$recent_count leituras na última hora"
    fi
    
    return 0
}

# Verificar Logs
check_logs() {
    local log_dir="$PROJECT_DIR/logs"
    local log_issues=0
    
    if [ ! -d "$log_dir" ]; then
        update_status "logs" "ERROR" "Diretório de logs não encontrado"
        return 1
    fi
    
    # Verificar erros recentes
    local recent_errors=$(find "$log_dir" -name "*.log" -mtime -1 -exec grep -l "ERROR\|CRITICAL\|FATAL" {} \; 2>/dev/null | wc -l)
    
    if [ $recent_errors -gt 0 ]; then
        update_status "logs" "WARNING" "Erros encontrados em $recent_errors arquivos"
        ((log_issues++))
    else
        update_status "logs" "OK" "Nenhum erro crítico recente"
    fi
    
    # Verificar tamanho dos logs
    local log_size=$(du -s "$log_dir" 2>/dev/null | cut -f1)
    if [ $log_size -gt 1000000 ]; then  # 1GB em KB
        alert "Logs muito grandes: $((log_size / 1024))MB"
        ((log_issues++))
    fi
    
    return $log_issues
}

# Enviar alertas críticos
send_critical_alerts() {
    local current_time=$(date +%s)
    local last_alert_file="$PROJECT_DIR/logs/last_alert.txt"
    local min_interval=3600  # 1 hora
    
    # Verificar se já foi enviado alerta recentemente
    if [ -f "$last_alert_file" ]; then
        local last_alert_time=$(cat "$last_alert_file")
        local time_diff=$((current_time - last_alert_time))
        
        if [ $time_diff -lt $min_interval ]; then
            return 0  # Não enviar alerta ainda
        fi
    fi
    
    # Verificar se há alertas críticos
    local critical_alerts=$(tail -20 "$ALERT_FILE" 2>/dev/null | grep "$(date '+%Y-%m-%d')" | wc -l)
    
    if [ $critical_alerts -gt 0 ]; then
        # Enviar email de alerta
        if [ -f "$PROJECT_DIR/backend/config.py" ] && grep -q "SMTP_" "$PROJECT_DIR/backend/config.py"; then
            local alert_content=$(tail -20 "$ALERT_FILE" | grep "$(date '+%Y-%m-%d')")
            
            python3 - << EOF
import sys
sys.path.append('$PROJECT_DIR/backend')
try:
    from email_service import send_email
    
    subject = "🚨 Alertas Críticos - IF-UFG"
    body = f"""
Sistema IF-UFG apresentando problemas:

$alert_content

Servidor: $(hostname)
Data: $(date '+%d/%m/%Y %H:%M:%S')

Verifique o sistema imediatamente.
"""
    
    send_email(subject, body)
    print("Alerta enviado por email")
except Exception as e:
    print(f"Erro ao enviar email: {e}")
EOF
            
            # Atualizar timestamp do último alerta
            echo "$current_time" > "$last_alert_file"
        fi
    fi
}

# Gerar relatório de status
generate_status_report() {
    local report_file="$PROJECT_DIR/logs/status_report.html"
    
    cat > "$report_file" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Status Report - IF-UFG</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .ok { color: green; }
        .warning { color: orange; }
        .error { color: red; }
        .component { margin: 10px 0; padding: 10px; border: 1px solid #ddd; }
        .timestamp { font-size: 0.8em; color: #666; }
    </style>
</head>
<body>
    <h1>🖥️ Status Report - IF-UFG</h1>
    <p><strong>Última atualização:</strong> $(date '+%d/%m/%Y %H:%M:%S')</p>
    <p><strong>Servidor:</strong> $(hostname)</p>
    
    <h2>📊 Status dos Componentes</h2>
EOF
    
    # Ler status de cada componente
    if [ -f "$STATUS_FILE" ]; then
        jq -r 'to_entries[] | "\(.key),\(.value.status),\(.value.message),\(.value.timestamp)"' "$STATUS_FILE" | \
        while IFS=',' read -r component status message timestamp; do
            local css_class=$(echo "$status" | tr '[:upper:]' '[:lower:]')
            cat >> "$report_file" << EOF
    <div class="component">
        <strong>$component:</strong> <span class="$css_class">$status</span><br>
        <em>$message</em><br>
        <span class="timestamp">$timestamp</span>
    </div>
EOF
        done
    fi
    
    cat >> "$report_file" << EOF
    
    <h2>🚨 Alertas Recentes</h2>
    <pre>
$(tail -20 "$ALERT_FILE" 2>/dev/null | grep "$(date '+%Y-%m-%d')" || echo "Nenhum alerta hoje")
    </pre>
    
    <p><em>Relatório gerado automaticamente</em></p>
</body>
</html>
EOF
    
    echo "$report_file"
}

# Modo silencioso (para cron)
silent_mode() {
    log "Iniciando health check silencioso"
    
    # Executar todas as verificações
    check_docker
    check_containers
    check_ports
    check_resources
    check_connectivity
    check_sensors
    check_database
    check_logs
    
    # Enviar alertas críticos se necessário
    send_critical_alerts
    
    log "Health check silencioso concluído"
}

# Modo verboso
verbose_mode() {
    echo -e "${PURPLE}🔍 HEALTH CHECK IF-UFG v2.0${NC}"
    echo -e "${PURPLE}================================${NC}"
    
    echo -e "${CYAN}📅 $(date '+%d/%m/%Y %H:%M:%S')${NC}"
    echo -e "${CYAN}🖥️ $(hostname)${NC}"
    echo ""
    
    local total_issues=0
    
    echo -e "${BLUE}🐳 Docker...${NC}"
    if check_docker; then
        echo -e "${GREEN}✅ Docker OK${NC}"
    else
        echo -e "${RED}❌ Docker com problemas${NC}"
        ((total_issues++))
    fi
    
    echo -e "\n${BLUE}📦 Containers...${NC}"
    local container_issues
    container_issues=$(check_containers; echo $?)
    if [ $container_issues -eq 0 ]; then
        echo -e "${GREEN}✅ Containers OK${NC}"
    else
        echo -e "${RED}❌ $container_issues containers com problemas${NC}"
        total_issues=$((total_issues + container_issues))
    fi
    
    echo -e "\n${BLUE}🔌 Portas...${NC}"
    local port_issues
    port_issues=$(check_ports; echo $?)
    if [ $port_issues -eq 0 ]; then
        echo -e "${GREEN}✅ Portas OK${NC}"
    else
        echo -e "${RED}❌ $port_issues portas com problemas${NC}"
        total_issues=$((total_issues + port_issues))
    fi
    
    echo -e "\n${BLUE}💻 Recursos...${NC}"
    local resource_issues
    resource_issues=$(check_resources; echo $?)
    if [ $resource_issues -eq 0 ]; then
        echo -e "${GREEN}✅ Recursos OK${NC}"
    else
        echo -e "${YELLOW}⚠️ $resource_issues recursos em alerta${NC}"
        total_issues=$((total_issues + resource_issues))
    fi
    
    echo -e "\n${BLUE}🌐 Conectividade...${NC}"
    local connectivity_issues
    connectivity_issues=$(check_connectivity; echo $?)
    if [ $connectivity_issues -eq 0 ]; then
        echo -e "${GREEN}✅ Conectividade OK${NC}"
    else
        echo -e "${RED}❌ $connectivity_issues problemas de conectividade${NC}"
        total_issues=$((total_issues + connectivity_issues))
    fi
    
    echo -e "\n${BLUE}🌡️ Sensores...${NC}"
    local sensor_issues
    sensor_issues=$(check_sensors; echo $?)
    if [ $sensor_issues -eq 0 ]; then
        echo -e "${GREEN}✅ Sensores OK${NC}"
    else
        echo -e "${YELLOW}⚠️ $sensor_issues sensores com problemas${NC}"
        total_issues=$((total_issues + sensor_issues))
    fi
    
    echo -e "\n${BLUE}🗄️ Banco de Dados...${NC}"
    if check_database; then
        echo -e "${GREEN}✅ Banco de Dados OK${NC}"
    else
        echo -e "${RED}❌ Banco de Dados com problemas${NC}"
        ((total_issues++))
    fi
    
    echo -e "\n${BLUE}📋 Logs...${NC}"
    local log_issues
    log_issues=$(check_logs; echo $?)
    if [ $log_issues -eq 0 ]; then
        echo -e "${GREEN}✅ Logs OK${NC}"
    else
        echo -e "${YELLOW}⚠️ $log_issues problemas nos logs${NC}"
        total_issues=$((total_issues + log_issues))
    fi
    
    echo -e "\n${PURPLE}================================${NC}"
    if [ $total_issues -eq 0 ]; then
        echo -e "${GREEN}✅ Sistema saudável (0 problemas)${NC}"
    else
        echo -e "${RED}🚨 Sistema com problemas ($total_issues issues)${NC}"
    fi
    
    # Gerar relatório
    local report_file
    report_file=$(generate_status_report)
    echo -e "\n${BLUE}📄 Relatório: $report_file${NC}"
    
    return $total_issues
}

# Função principal
main() {
    # Criar diretórios necessários
    mkdir -p "$PROJECT_DIR/logs"
    
    # Processar argumentos
    case "${1:-}" in
        --silent|-s)
            silent_mode
            ;;
        --verbose|-v)
            verbose_mode
            ;;
        --report|-r)
            generate_status_report
            ;;
        *)
            silent_mode
            ;;
    esac
}

# Executar apenas se chamado diretamente
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    main "$@"
fi 