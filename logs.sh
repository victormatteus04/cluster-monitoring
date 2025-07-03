#!/bin/bash

# ============================================================================
# SCRIPT DE LOGS
# Monitoramento Inteligente de Clusters - IF-UFG
# ============================================================================

set -e

# ============================================================================
# CONFIGURAÇÕES
# ============================================================================
COMPOSE_FILE="backend/docker-compose.yaml"

# ============================================================================
# CORES PARA OUTPUT
# ============================================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ============================================================================
# FUNÇÕES DE LOG
# ============================================================================
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# ============================================================================
# FUNÇÕES DE LOGS
# ============================================================================
show_service_logs() {
    local service=$1
    local lines=${2:-50}
    
    echo ""
    log_info "Logs do serviço: $service (últimas $lines linhas)"
    echo "============================================================================"
    
    cd backend
    docker compose logs --tail="$lines" "$service"
    cd ..
}

show_all_logs() {
    local lines=${1:-20}
    
    echo ""
    log_info "Logs de todos os serviços (últimas $lines linhas)"
    echo "============================================================================"
    
    cd backend
    docker compose logs --tail="$lines"
    cd ..
}

show_follow_logs() {
    local service=$1
    
    echo ""
    log_info "Seguindo logs do serviço: $service (Ctrl+C para sair)"
    echo "============================================================================"
    
    cd backend
    docker compose logs -f "$service"
    cd ..
}

show_file_logs() {
    local log_file=$1
    local lines=${2:-50}
    
    if [ -f "$log_file" ]; then
        echo ""
        log_info "Logs do arquivo: $log_file (últimas $lines linhas)"
        echo "============================================================================"
        tail -n "$lines" "$log_file"
    else
        log_error "Arquivo de log não encontrado: $log_file"
    fi
}

# ============================================================================
# MENU PRINCIPAL
# ============================================================================
show_menu() {
    echo "============================================================================"
    echo "  MONITORAMENTO INTELIGENTE DE CLUSTERS - IF-UFG"
    echo "  Visualizador de Logs"
    echo "============================================================================"
    echo ""
    echo "Escolha uma opção:"
    echo ""
    echo "  1) Logs de todos os serviços (últimas 20 linhas)"
    echo "  2) Logs do Mosquitto (MQTT)"
    echo "  3) Logs do Prometheus"
    echo "  4) Logs do Grafana"
    echo "  5) Logs do Sistema de Alertas"
    echo "  6) Logs do MQTT Exporter"
    echo "  7) Logs do Node Exporter"
    echo "  8) Logs do cAdvisor"
    echo "  9) Logs do Nginx"
    echo ""
    echo "  10) Seguir logs do Mosquitto (tempo real)"
    echo "  11) Seguir logs do Sistema de Alertas (tempo real)"
    echo "  12) Seguir logs do MQTT Exporter (tempo real)"
    echo ""
    echo "  13) Logs de inicialização do sistema"
    echo "  14) Logs de parada do sistema"
    echo ""
    echo "  0) Sair"
    echo ""
}

# ============================================================================
# FUNÇÃO PRINCIPAL
# ============================================================================
main() {
    while true; do
        show_menu
        read -p "Digite sua opção: " choice
        
        case $choice in
            1)
                show_all_logs 20
                ;;
            2)
                show_service_logs mosquitto 50
                ;;
            3)
                show_service_logs prometheus 30
                ;;
            4)
                show_service_logs grafana 30
                ;;
            5)
                show_service_logs alerting 50
                ;;
            6)
                show_service_logs mqtt-exporter 30
                ;;
            7)
                show_service_logs node-exporter 20
                ;;
            8)
                show_service_logs cadvisor 30
                ;;
            9)
                show_service_logs nginx 20
                ;;
            10)
                show_follow_logs mosquitto
                ;;
            11)
                show_follow_logs alerting
                ;;
            12)
                show_follow_logs mqtt-exporter
                ;;
            13)
                show_file_logs "logs/startup.log" 50
                ;;
            14)
                show_file_logs "logs/shutdown.log" 30
                ;;
            0)
                log_success "Saindo..."
                exit 0
                ;;
            *)
                log_error "Opção inválida: $choice"
                ;;
        esac
        
        echo ""
        read -p "Pressione Enter para continuar..."
        clear
    done
}

# ============================================================================
# EXECUÇÃO
# ============================================================================
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Verifica se o Docker Compose está rodando
    if ! docker compose -f "$COMPOSE_FILE" ps | grep -q "Up"; then
        log_warning "Nenhum serviço está rodando. Execute ./start.sh primeiro."
        exit 1
    fi
    
    main "$@"
fi 