#!/bin/bash

# =============================================================================
# Sistema de Diagnóstico Automático - IF-UFG
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
LOG_FILE="$PROJECT_DIR/logs/diagnostico_$(date +%Y%m%d_%H%M%S).log"

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
    echo "  🔍 DIAGNÓSTICO AUTOMÁTICO IF-UFG v2.0"
    echo "=========================================="
    echo -e "${NC}"
}

# Diagnóstico Docker
diagnose_docker() {
    echo -e "${CYAN}🐳 Diagnóstico Docker...${NC}"
    
    if ! command -v docker &> /dev/null; then
        status_error "Docker não instalado"
        echo -e "${YELLOW}💡 Solução: sudo apt update && sudo apt install docker.io${NC}"
        return 1
    fi
    
    if ! docker ps &> /dev/null; then
        status_error "Docker daemon não está rodando"
        echo -e "${YELLOW}💡 Solução: sudo systemctl start docker${NC}"
        return 1
    fi
    
    # Verificar espaço em disco para Docker
    local docker_space=$(df /var/lib/docker | tail -1 | awk '{print $5}' | sed 's/%//')
    if [ $docker_space -gt 80 ]; then
        status_warning "Espaço em disco Docker baixo: ${docker_space}%"
        echo -e "${YELLOW}💡 Solução: docker system prune -a${NC}"
    fi
    
    status_ok "Docker funcionando corretamente"
    return 0
}

# Diagnóstico Containers
diagnose_containers() {
    echo -e "${CYAN}📦 Diagnóstico Containers...${NC}"
    
    local containers=("grafana" "prometheus" "backend" "mqtt")
    local problems=()
    
    for container in "${containers[@]}"; do
        if ! docker ps --format "table {{.Names}}" | grep -q "$container"; then
            problems+=("$container não está rodando")
            
            # Verificar se container existe mas está parado
            if docker ps -a --format "table {{.Names}}" | grep -q "$container"; then
                status_error "Container $container está parado"
                echo -e "${YELLOW}💡 Solução: docker start $container${NC}"
            else
                status_error "Container $container não existe"
                echo -e "${YELLOW}💡 Solução: docker-compose up -d $container${NC}"
            fi
        else
            # Verificar saúde do container
            local container_id=$(docker ps -q --filter "name=$container")
            local container_status=$(docker inspect --format='{{.State.Health.Status}}' "$container_id" 2>/dev/null)
            
            if [ "$container_status" = "unhealthy" ]; then
                status_warning "Container $container não está saudável"
                echo -e "${YELLOW}💡 Solução: docker restart $container${NC}"
            else
                status_ok "Container $container OK"
            fi
        fi
    done
    
    if [ ${#problems[@]} -gt 0 ]; then
        echo -e "${RED}🚨 Problemas encontrados:${NC}"
        for problem in "${problems[@]}"; do
            echo -e "${RED}  • $problem${NC}"
        done
        return 1
    fi
    
    return 0
}

# Diagnóstico Portas
diagnose_ports() {
    echo -e "${CYAN}🔌 Diagnóstico Portas...${NC}"
    
    local ports=(3000 9090 1883 8080)
    local services=("Grafana" "Prometheus" "MQTT" "Backend")
    
    for i in "${!ports[@]}"; do
        local port="${ports[$i]}"
        local service="${services[$i]}"
        
        if ! netstat -tuln | grep -q ":$port "; then
            status_error "Porta $port ($service) não está aberta"
            
            # Verificar se processo está tentando usar a porta
            local process=$(lsof -ti:$port 2>/dev/null)
            if [ -n "$process" ]; then
                echo -e "${YELLOW}💡 Processo usando porta: $(ps -p $process -o comm=)${NC}"
                echo -e "${YELLOW}💡 Solução: kill $process && docker-compose restart${NC}"
            else
                echo -e "${YELLOW}💡 Solução: docker-compose up -d${NC}"
            fi
        else
            status_ok "Porta $port ($service) OK"
        fi
    done
    
    return 0
}

# Diagnóstico Banco de Dados
diagnose_database() {
    echo -e "${CYAN}🗄️ Diagnóstico Banco de Dados...${NC}"
    
    local db_file="$PROJECT_DIR/backend/database.db"
    
    if [ ! -f "$db_file" ]; then
        status_error "Banco de dados não encontrado"
        echo -e "${YELLOW}💡 Solução: Aguarde alguns minutos para criação automática${NC}"
        return 1
    fi
    
    # Verificar integridade do banco
    if ! sqlite3 "$db_file" "PRAGMA integrity_check;" | grep -q "ok"; then
        status_error "Banco de dados corrompido"
        echo -e "${YELLOW}💡 Solução: Restaurar backup ou recriar banco${NC}"
        return 1
    fi
    
    # Verificar se há dados recentes
    local recent_count=$(sqlite3 "$db_file" "SELECT COUNT(*) FROM readings WHERE timestamp > datetime('now', '-1 hour');" 2>/dev/null)
    if [ -z "$recent_count" ] || [ "$recent_count" -eq 0 ]; then
        status_warning "Não há dados recentes no banco"
        echo -e "${YELLOW}💡 Verifique se sensores estão enviando dados${NC}"
    else
        status_ok "Banco de dados OK ($recent_count leituras na última hora)"
    fi
    
    return 0
}

# Diagnóstico Sensores
diagnose_sensors() {
    echo -e "${CYAN}🌡️ Diagnóstico Sensores...${NC}"
    
    local backend_url="http://localhost:8080"
    
    if ! curl -s "$backend_url/health" &> /dev/null; then
        status_error "Backend não está respondendo"
        echo -e "${YELLOW}💡 Solução: docker-compose restart backend${NC}"
        return 1
    fi
    
    local sensors_data=$(curl -s "$backend_url/sensors/status" 2>/dev/null)
    
    if [ -z "$sensors_data" ]; then
        status_error "Não foi possível obter status dos sensores"
        echo -e "${YELLOW}💡 Verifique logs do backend${NC}"
        return 1
    fi
    
    # Verificar sensores individuais
    local sensors=("a" "b")
    for sensor in "${sensors[@]}"; do
        local last_seen=$(echo "$sensors_data" | jq -r ".sensor_$sensor.last_seen" 2>/dev/null)
        
        if [ "$last_seen" = "null" ] || [ -z "$last_seen" ]; then
            status_warning "Sensor $sensor não está enviando dados"
            echo -e "${YELLOW}💡 Verifique conexão WiFi do sensor $sensor${NC}"
        else
            local minutes_ago=$(( ($(date +%s) - $(date -d "$last_seen" +%s)) / 60 ))
            
            if [ $minutes_ago -gt 10 ]; then
                status_warning "Sensor $sensor offline há $minutes_ago minutos"
                echo -e "${YELLOW}💡 Verifique alimentação e WiFi do sensor $sensor${NC}"
            else
                status_ok "Sensor $sensor OK (último envio: $minutes_ago min atrás)"
            fi
        fi
    done
    
    return 0
}

# Diagnóstico Grafana
diagnose_grafana() {
    echo -e "${CYAN}📊 Diagnóstico Grafana...${NC}"
    
    if ! curl -s http://localhost:3000/api/health &> /dev/null; then
        status_error "Grafana não está respondendo"
        echo -e "${YELLOW}💡 Solução: docker-compose restart grafana${NC}"
        return 1
    fi
    
    # Verificar datasources
    local datasources=$(curl -s http://admin:admin@localhost:3000/api/datasources 2>/dev/null)
    
    if [ -z "$datasources" ]; then
        status_error "Não foi possível verificar datasources"
        echo -e "${YELLOW}💡 Verifique configuração do Grafana${NC}"
        return 1
    fi
    
    local prometheus_ds=$(echo "$datasources" | jq -r '.[].type' | grep -c "prometheus")
    
    if [ "$prometheus_ds" -eq 0 ]; then
        status_error "Datasource Prometheus não configurado"
        echo -e "${YELLOW}💡 Solução: Configurar datasource manualmente${NC}"
    else
        status_ok "Grafana OK (datasources configurados)"
    fi
    
    return 0
}

# Diagnóstico Recursos
diagnose_resources() {
    echo -e "${CYAN}💻 Diagnóstico Recursos...${NC}"
    
    # CPU
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')
    if (( $(echo "$cpu_usage > 90" | bc -l) )); then
        status_warning "CPU muito alta: ${cpu_usage}%"
        echo -e "${YELLOW}💡 Solução: Verificar processos com 'top'${NC}"
    fi
    
    # Memória
    local mem_percent=$(free | grep "Mem:" | awk '{printf "%.1f", $3/$2 * 100.0}')
    if (( $(echo "$mem_percent > 90" | bc -l) )); then
        status_warning "Memória muito alta: ${mem_percent}%"
        echo -e "${YELLOW}💡 Solução: Reiniciar containers ou sistema${NC}"
    fi
    
    # Disco
    local disk_usage=$(df -h / | tail -1 | awk '{print $5}' | sed 's/%//')
    if [ $disk_usage -gt 90 ]; then
        status_warning "Disco muito cheio: ${disk_usage}%"
        echo -e "${YELLOW}💡 Solução: Limpar logs e dados antigos${NC}"
    fi
    
    # Inodes
    local inode_usage=$(df -i / | tail -1 | awk '{print $5}' | sed 's/%//')
    if [ $inode_usage -gt 90 ]; then
        status_warning "Inodes esgotados: ${inode_usage}%"
        echo -e "${YELLOW}💡 Solução: Remover arquivos pequenos desnecessários${NC}"
    fi
    
    return 0
}

# Diagnóstico Rede
diagnose_network() {
    echo -e "${CYAN}🌐 Diagnóstico Rede...${NC}"
    
    # Conectividade externa
    if ! ping -c 1 8.8.8.8 &> /dev/null; then
        status_error "Sem conectividade externa"
        echo -e "${YELLOW}💡 Solução: Verificar configuração de rede${NC}"
        return 1
    fi
    
    # DNS
    if ! nslookup google.com &> /dev/null; then
        status_error "Problema com DNS"
        echo -e "${YELLOW}💡 Solução: Verificar /etc/resolv.conf${NC}"
        return 1
    fi
    
    # Conectividade interna
    local internal_services=("localhost:3000" "localhost:9090" "localhost:8080")
    for service in "${internal_services[@]}"; do
        if ! timeout 5 bash -c "cat < /dev/null > /dev/tcp/${service/:/ }"; then
            status_warning "Serviço $service não acessível"
            echo -e "${YELLOW}💡 Verifique se container está rodando${NC}"
        fi
    done
    
    status_ok "Rede OK"
    return 0
}

# Diagnóstico Logs
diagnose_logs() {
    echo -e "${CYAN}📋 Diagnóstico Logs...${NC}"
    
    # Verificar logs de erro recentes
    local log_dir="$PROJECT_DIR/logs"
    
    if [ ! -d "$log_dir" ]; then
        status_warning "Diretório de logs não encontrado"
        echo -e "${YELLOW}💡 Solução: mkdir -p $log_dir${NC}"
        return 1
    fi
    
    # Procurar erros recentes
    local recent_errors=$(find "$log_dir" -name "*.log" -mtime -1 -exec grep -l "ERROR\|CRITICAL\|FATAL" {} \; | wc -l)
    
    if [ $recent_errors -gt 0 ]; then
        status_warning "Erros encontrados em $recent_errors arquivos de log"
        echo -e "${YELLOW}💡 Verifique logs com: tail -f $log_dir/*.log${NC}"
    else
        status_ok "Nenhum erro crítico nos logs recentes"
    fi
    
    # Verificar tamanho dos logs
    local log_size=$(du -sh "$log_dir" 2>/dev/null | cut -f1)
    if [ -n "$log_size" ]; then
        status_info "Tamanho dos logs: $log_size"
    fi
    
    return 0
}

# Gerar relatório de diagnóstico
generate_report() {
    echo -e "${CYAN}📄 Gerando relatório de diagnóstico...${NC}"
    
    local report_file="$PROJECT_DIR/logs/diagnostic_report_$(date +%Y%m%d_%H%M%S).txt"
    
    cat > "$report_file" << EOF
===========================================
RELATÓRIO DE DIAGNÓSTICO - IF-UFG
===========================================
Data: $(date '+%d/%m/%Y %H:%M:%S')
Servidor: $(hostname)
Usuário: $(whoami)
Versão: 2.0.0
===========================================

INFORMAÇÕES DO SISTEMA:
$(uname -a)

DOCKER:
$(docker --version 2>/dev/null || echo "Docker não encontrado")

CONTAINERS:
$(docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || echo "Erro ao listar containers")

RECURSOS:
CPU: $(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')%
Memória: $(free -h | grep "Mem:" | awk '{print $3 "/" $2}')
Disco: $(df -h / | tail -1 | awk '{print $5}')

PORTAS:
$(netstat -tuln | grep -E ":(3000|9090|1883|8080)" | awk '{print $4}' | sort)

LOGS RECENTES:
$(find "$PROJECT_DIR/logs" -name "*.log" -mtime -1 -exec basename {} \; 2>/dev/null | sort)

===========================================
EOF
    
    status_ok "Relatório salvo em: $report_file"
    echo -e "${BLUE}📄 Relatório: $report_file${NC}"
}

# Sugestões de correção
suggest_fixes() {
    echo -e "\n${PURPLE}💡 SUGESTÕES DE CORREÇÃO${NC}"
    echo -e "${PURPLE}================================${NC}"
    
    echo -e "${CYAN}🔧 Comandos úteis:${NC}"
    echo -e "${YELLOW}  • Reiniciar sistema: ./start.sh${NC}"
    echo -e "${YELLOW}  • Verificar logs: ./logs.sh${NC}"
    echo -e "${YELLOW}  • Limpar sistema: docker system prune -a${NC}"
    echo -e "${YELLOW}  • Backup: ./utils/backup_completo.sh${NC}"
    echo -e "${YELLOW}  • Monitorar recursos: ./utils/monitorar_recursos.sh${NC}"
    
    echo -e "\n${CYAN}📞 Suporte:${NC}"
    echo -e "${YELLOW}  • Documentação: ./docs/README.md${NC}"
    echo -e "${YELLOW}  • Troubleshooting: ./docs/07-TROUBLESHOOTING.md${NC}"
    echo -e "${YELLOW}  • Verificação: ./utils/verificar_sistema.sh${NC}"
}

# Função principal
main() {
    print_banner
    
    # Criar diretório de logs se não existir
    mkdir -p "$PROJECT_DIR/logs"
    
    log "Iniciando diagnóstico do sistema"
    
    # Executar diagnósticos
    diagnose_docker
    diagnose_containers
    diagnose_ports
    diagnose_database
    diagnose_sensors
    diagnose_grafana
    diagnose_resources
    diagnose_network
    diagnose_logs
    
    # Gerar relatório
    generate_report
    
    # Sugestões
    suggest_fixes
    
    log "Diagnóstico concluído"
    echo -e "\n${GREEN}✅ Diagnóstico concluído! Verifique o relatório gerado.${NC}"
}

# Executar apenas se chamado diretamente
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    main "$@"
fi 