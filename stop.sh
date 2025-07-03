#!/bin/bash

# ============================================================================
# SCRIPT DE PARADA
# Monitoramento Inteligente de Clusters - IF-UFG
# ============================================================================

set -e

# ============================================================================
# CONFIGURAÇÕES
# ============================================================================
COMPOSE_FILE="backend/docker-compose.yaml"
LOG_FILE="logs/shutdown.log"

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
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

# ============================================================================
# FUNÇÃO PRINCIPAL
# ============================================================================
main() {
    echo "============================================================================"
    echo "  MONITORAMENTO INTELIGENTE DE CLUSTERS - IF-UFG"
    echo "  Script de Parada"
    echo "============================================================================"
    echo ""
    
    # Verifica se o Docker Compose está rodando
    if ! docker compose -f "$COMPOSE_FILE" ps | grep -q "Up"; then
        log_warning "Nenhum serviço está rodando"
        exit 0
    fi
    
    # Mostra status atual
    log_info "Status atual dos serviços:"
    docker compose -f "$COMPOSE_FILE" ps
    
    echo ""
    log_info "Parando serviços..."
    
    # Para os serviços
    cd backend
    docker compose down
    cd ..
    
    log_success "Serviços parados com sucesso!"
    
    echo ""
    log_info "Para iniciar novamente, execute: ./start.sh"
}

# ============================================================================
# EXECUÇÃO
# ============================================================================
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 