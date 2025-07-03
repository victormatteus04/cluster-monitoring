#!/bin/bash

# ============================================================================
# SCRIPT DE CORREÇÃO DE PERMISSÕES
# Monitoramento Inteligente de Clusters - IF-UFG
# ============================================================================

set -e

# ============================================================================
# CONFIGURAÇÕES
# ============================================================================
PROJECT_NAME="cluster-monitoring"
CURRENT_USER=$(whoami)
CURRENT_GROUP=$(id -gn)

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
# FUNÇÕES DE CORREÇÃO DE PERMISSÕES
# ============================================================================
fix_prometheus_permissions() {
    log_info "Corrigindo permissões do Prometheus..."
    
    if [ -d "backend/prometheus/data" ]; then
        sudo chown -R $CURRENT_USER:$CURRENT_GROUP backend/prometheus/data/
        chmod -R 755 backend/prometheus/data/
        log_success "Permissões do Prometheus corrigidas"
    else
        log_warning "Diretório do Prometheus não encontrado"
    fi
}

fix_grafana_permissions() {
    log_info "Corrigindo permissões do Grafana..."
    
    if [ -d "backend/grafana/data" ]; then
        sudo chown -R $CURRENT_USER:$CURRENT_GROUP backend/grafana/data/
        chmod -R 755 backend/grafana/data/
        log_success "Permissões do Grafana corrigidas"
    else
        log_warning "Diretório do Grafana não encontrado"
    fi
}

fix_mosquitto_permissions() {
    log_info "Corrigindo permissões do Mosquitto..."
    
    if [ -d "backend/mosquitto" ]; then
        sudo chown -R $CURRENT_USER:$CURRENT_GROUP backend/mosquitto/
        chmod -R 755 backend/mosquitto/
        log_success "Permissões do Mosquitto corrigidas"
    else
        log_warning "Diretório do Mosquitto não encontrado"
    fi
}

fix_alerting_permissions() {
    log_info "Corrigindo permissões do sistema de alertas..."
    
    if [ -d "backend/alerting" ]; then
        sudo chown -R $CURRENT_USER:$CURRENT_GROUP backend/alerting/
        chmod -R 755 backend/alerting/
        log_success "Permissões do sistema de alertas corrigidas"
    else
        log_warning "Diretório do sistema de alertas não encontrado"
    fi
}

fix_exporter_permissions() {
    log_info "Corrigindo permissões do exportador..."
    
    if [ -d "backend/exporter" ]; then
        sudo chown -R $CURRENT_USER:$CURRENT_GROUP backend/exporter/
        chmod -R 755 backend/exporter/
        log_success "Permissões do exportador corrigidas"
    else
        log_warning "Diretório do exportador não encontrado"
    fi
}

fix_logs_permissions() {
    log_info "Corrigindo permissões dos logs..."
    
    if [ -d "logs" ]; then
        sudo chown -R $CURRENT_USER:$CURRENT_GROUP logs/
        chmod -R 755 logs/
        log_success "Permissões dos logs corrigidas"
    else
        log_warning "Diretório de logs não encontrado"
    fi
}

# ============================================================================
# FUNÇÃO PARA CONFIGURAR PERMISSÕES FUTURAS
# ============================================================================
setup_future_permissions() {
    log_info "Configurando permissões para arquivos futuros..."
    
    # Criar arquivo de configuração do Docker para manter permissões
    cat > backend/.dockerignore << EOF
# Arquivos temporários
*.tmp
*.log
*.pid

# Arquivos de cache
__pycache__/
*.pyc
*.pyo

# Arquivos de IDE
.vscode/
.idea/
*.swp
*.swo

# Arquivos de sistema
.DS_Store
Thumbs.db
EOF

    # Configurar permissões padrão para novos arquivos
    umask 022
    
    log_success "Configuração de permissões futuras concluída"
}

# ============================================================================
# FUNÇÃO PARA VERIFICAR PERMISSÕES
# ============================================================================
check_permissions() {
    log_info "Verificando permissões dos diretórios principais..."
    
    local dirs=(
        "backend/prometheus/data"
        "backend/grafana/data"
        "backend/mosquitto"
        "backend/alerting"
        "backend/exporter"
        "logs"
    )
    
    for dir in "${dirs[@]}"; do
        if [ -d "$dir" ]; then
            local owner=$(stat -c '%U:%G' "$dir")
            if [ "$owner" = "$CURRENT_USER:$CURRENT_GROUP" ]; then
                log_success "$dir: permissões corretas ($owner)"
            else
                log_warning "$dir: permissões incorretas ($owner)"
            fi
        fi
    done
}

# ============================================================================
# FUNÇÃO PRINCIPAL
# ============================================================================
main() {
    echo "============================================================================"
    echo "  CORREÇÃO DE PERMISSÕES - MONITORAMENTO DE CLUSTERS"
    echo "  Usuário atual: $CURRENT_USER:$CURRENT_GROUP"
    echo "============================================================================"
    echo ""
    
    # Verificar se está no diretório correto
    if [ ! -f "start.sh" ]; then
        log_error "Execute este script no diretório raiz do projeto"
        exit 1
    fi
    
    # Parar serviços se estiverem rodando
    if docker compose -f backend/docker-compose.yaml ps | grep -q "Up"; then
        log_warning "Serviços estão rodando. Parando para corrigir permissões..."
        cd backend
        docker compose down
        cd ..
    fi
    
    # Corrigir permissões
    fix_prometheus_permissions
    fix_grafana_permissions
    fix_mosquitto_permissions
    fix_alerting_permissions
    fix_exporter_permissions
    fix_logs_permissions
    
    # Configurar permissões futuras
    setup_future_permissions
    
    # Verificar permissões
    check_permissions
    
    echo ""
    log_success "Correção de permissões concluída!"
    echo ""
    echo "Para reiniciar o sistema, execute: ./start.sh"
    echo "Para verificar permissões novamente, execute: ./fix_permissions.sh --check"
}

# ============================================================================
# EXECUÇÃO
# ============================================================================
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [ "$1" = "--check" ]; then
        check_permissions
    else
        main "$@"
    fi
fi 