#!/bin/bash

# =============================================================================
# Sistema de Verificação Completa - IF-UFG
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
LOG_FILE="$PROJECT_DIR/logs/verificacao_$(date +%Y%m%d_%H%M%S).log"

# Função para logging
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Função para status OK
status_ok() {
    echo -e "${GREEN}✅ $1${NC}"
    log "OK: $1"
}

# Função para status WARNING
status_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
    log "WARNING: $1"
}

# Função para status ERROR
status_error() {
    echo -e "${RED}❌ $1${NC}"
    log "ERROR: $1"
}

# Função para status INFO
status_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
    log "INFO: $1"
}

# Banner
print_banner() {
    echo -e "${PURPLE}"
    echo "=========================================="
    echo "  🔍 VERIFICAÇÃO SISTEMA IF-UFG v2.0"
    echo "=========================================="
    echo -e "${NC}"
}

# Verificação Docker
check_docker() {
    echo -e "${CYAN}🐳 Verificando Docker...${NC}"
    
    if ! command -v docker &> /dev/null; then
        status_error "Docker não está instalado"
        return 1
    fi
    
    if ! docker --version &> /dev/null; then
        status_error "Docker não está funcionando"
        return 1
    fi
    
    status_ok "Docker instalado: $(docker --version | cut -d' ' -f3 | cut -d',' -f1)"
    
    # Verificar se Docker está rodando
    if ! docker ps &> /dev/null; then
        status_error "Docker daemon não está rodando"
        return 1
    fi
    
    status_ok "Docker daemon rodando"
    return 0
}

# Verificação Docker Compose
check_docker_compose() {
    echo -e "${CYAN}🐳 Verificando Docker Compose...${NC}"
    
    if ! command -v docker-compose &> /dev/null; then
        status_error "Docker Compose não está instalado"
        return 1
    fi
    
    status_ok "Docker Compose instalado: $(docker-compose --version | cut -d' ' -f3 | cut -d',' -f1)"
    return 0
}

# Verificação Containers
check_containers() {
    echo -e "${CYAN}📦 Verificando Containers...${NC}"
    
    local containers_running=0
    local containers_total=0
    
    # Lista de containers esperados
    local expected_containers=("grafana" "prometheus" "backend" "mqtt")
    
    for container in "${expected_containers[@]}"; do
        ((containers_total++))
        if docker ps --format "table {{.Names}}" | grep -q "$container"; then
            status_ok "Container $container está rodando"
            ((containers_running++))
        else
            status_error "Container $container não está rodando"
        fi
    done
    
    echo -e "${BLUE}📊 Containers: $containers_running/$containers_total rodando${NC}"
    
    if [ $containers_running -eq $containers_total ]; then
        return 0
    else
        return 1
    fi
}

# Verificação Portas
check_ports() {
    echo -e "${CYAN}🔌 Verificando Portas...${NC}"
    
    local ports=(3000 9090 1883 8080)
    local ports_ok=0
    
    for port in "${ports[@]}"; do
        if netstat -tuln | grep -q ":$port "; then
            status_ok "Porta $port está aberta"
            ((ports_ok++))
        else
            status_error "Porta $port não está disponível"
        fi
    done
    
    echo -e "${BLUE}📊 Portas: $ports_ok/${#ports[@]} disponíveis${NC}"
    return 0
}

# Verificação Sensores
check_sensors() {
    echo -e "${CYAN}🌡️ Verificando Sensores...${NC}"
    
    local backend_url="http://localhost:8080"
    local sensors_data=$(curl -s "$backend_url/sensors" 2>/dev/null)
    
    if [ -z "$sensors_data" ]; then
        status_error "Não foi possível conectar ao backend"
        return 1
    fi
    
    # Verificar sensores ativos
    local sensor_a=$(echo "$sensors_data" | grep -c "sensor_a")
    local sensor_b=$(echo "$sensors_data" | grep -c "sensor_b")
    
    if [ $sensor_a -gt 0 ]; then
        status_ok "Sensor A está enviando dados"
    else
        status_warning "Sensor A não está enviando dados"
    fi
    
    if [ $sensor_b -gt 0 ]; then
        status_ok "Sensor B está enviando dados"
    else
        status_warning "Sensor B não está enviando dados"
    fi
    
    return 0
}

# Verificação Banco de Dados
check_database() {
    echo -e "${CYAN}🗄️ Verificando Banco de Dados...${NC}"
    
    local db_file="$PROJECT_DIR/backend/database.db"
    
    if [ -f "$db_file" ]; then
        local db_size=$(du -h "$db_file" | cut -f1)
        status_ok "Banco de dados existe: $db_size"
        
        # Verificar se o banco está acessível
        if sqlite3 "$db_file" "SELECT COUNT(*) FROM readings;" &> /dev/null; then
            local count=$(sqlite3 "$db_file" "SELECT COUNT(*) FROM readings;")
            status_ok "Banco de dados acessível: $count registros"
        else
            status_error "Banco de dados não está acessível"
        fi
    else
        status_error "Arquivo de banco de dados não encontrado"
    fi
    
    return 0
}

# Verificação Logs
check_logs() {
    echo -e "${CYAN}📋 Verificando Logs...${NC}"
    
    local log_dir="$PROJECT_DIR/logs"
    
    if [ -d "$log_dir" ]; then
        local log_count=$(find "$log_dir" -name "*.log" | wc -l)
        local log_size=$(du -sh "$log_dir" | cut -f1)
        
        status_ok "Diretório de logs existe: $log_count arquivos, $log_size"
        
        # Verificar logs recentes
        local recent_logs=$(find "$log_dir" -name "*.log" -mtime -1 | wc -l)
        if [ $recent_logs -gt 0 ]; then
            status_ok "Logs recentes encontrados: $recent_logs arquivos"
        else
            status_warning "Nenhum log recente encontrado"
        fi
    else
        status_error "Diretório de logs não encontrado"
    fi
    
    return 0
}

# Verificação Recursos do Sistema
check_system_resources() {
    echo -e "${CYAN}💻 Verificando Recursos do Sistema...${NC}"
    
    # CPU
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')
    echo -e "${BLUE}🔥 CPU: ${cpu_usage}%${NC}"
    
    # Memória
    local mem_info=$(free -h | grep "Mem:")
    local mem_total=$(echo $mem_info | awk '{print $2}')
    local mem_used=$(echo $mem_info | awk '{print $3}')
    local mem_percent=$(free | grep "Mem:" | awk '{printf "%.1f", $3/$2 * 100.0}')
    
    echo -e "${BLUE}🧠 Memória: ${mem_used}/${mem_total} (${mem_percent}%)${NC}"
    
    # Disco
    local disk_usage=$(df -h / | tail -1 | awk '{print $5}' | sed 's/%//')
    local disk_available=$(df -h / | tail -1 | awk '{print $4}')
    
    echo -e "${BLUE}💾 Disco: ${disk_usage}% usado, ${disk_available} disponível${NC}"
    
    # Alertas de recursos
    if (( $(echo "$cpu_usage > 80" | bc -l) )); then
        status_warning "CPU alta: ${cpu_usage}%"
    fi
    
    if (( $(echo "$mem_percent > 80" | bc -l) )); then
        status_warning "Memória alta: ${mem_percent}%"
    fi
    
    if [ $disk_usage -gt 80 ]; then
        status_warning "Disco cheio: ${disk_usage}%"
    fi
    
    return 0
}

# Verificação Conectividade
check_connectivity() {
    echo -e "${CYAN}🌐 Verificando Conectividade...${NC}"
    
    # Ping para Google
    if ping -c 1 8.8.8.8 &> /dev/null; then
        status_ok "Conectividade externa OK"
    else
        status_error "Sem conectividade externa"
    fi
    
    # Verificar se Grafana está respondendo
    if curl -s http://localhost:3000/api/health &> /dev/null; then
        status_ok "Grafana respondendo"
    else
        status_error "Grafana não está respondendo"
    fi
    
    # Verificar se Prometheus está respondendo
    if curl -s http://localhost:9090/-/healthy &> /dev/null; then
        status_ok "Prometheus respondendo"
    else
        status_error "Prometheus não está respondendo"
    fi
    
    return 0
}

# Relatório Final
print_summary() {
    echo -e "\n${PURPLE}================================${NC}"
    echo -e "${PURPLE}📋 RELATÓRIO FINAL${NC}"
    echo -e "${PURPLE}================================${NC}"
    
    echo -e "${BLUE}📅 Data: $(date '+%d/%m/%Y %H:%M:%S')${NC}"
    echo -e "${BLUE}🏢 Sistema: IF-UFG Cluster Monitoring${NC}"
    echo -e "${BLUE}📍 Servidor: $(hostname)${NC}"
    echo -e "${BLUE}📊 Log: $LOG_FILE${NC}"
    
    echo -e "\n${CYAN}🔧 Comandos úteis:${NC}"
    echo -e "${YELLOW}  • Reiniciar: ./start.sh${NC}"
    echo -e "${YELLOW}  • Parar: ./stop.sh${NC}"
    echo -e "${YELLOW}  • Logs: ./logs.sh${NC}"
    echo -e "${YELLOW}  • Backup: ./utils/backup_completo.sh${NC}"
    echo -e "${YELLOW}  • Diagnóstico: ./utils/diagnostico.sh${NC}"
    
    echo -e "\n${GREEN}✅ Verificação concluída!${NC}"
}

# Função principal
main() {
    print_banner
    
    # Criar diretório de logs se não existir
    mkdir -p "$PROJECT_DIR/logs"
    
    log "Iniciando verificação do sistema"
    
    # Executar verificações
    check_docker
    check_docker_compose
    check_containers
    check_ports
    check_sensors
    check_database
    check_logs
    check_system_resources
    check_connectivity
    
    print_summary
    
    log "Verificação concluída"
}

# Executar apenas se chamado diretamente
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    main "$@"
fi 