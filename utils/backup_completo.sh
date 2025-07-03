#!/bin/bash

# =============================================================================
# Sistema de Backup Completo - IF-UFG
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
BACKUP_DIR="$PROJECT_DIR/backups"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="backup_ifufg_$DATE"
BACKUP_PATH="$BACKUP_DIR/$BACKUP_NAME"

# Função para logging
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$BACKUP_PATH/backup.log"
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
    echo "  💾 BACKUP COMPLETO IF-UFG v2.0"
    echo "=========================================="
    echo -e "${NC}"
}

# Criar estrutura de backup
create_backup_structure() {
    echo -e "${CYAN}📁 Criando estrutura de backup...${NC}"
    
    mkdir -p "$BACKUP_PATH"/{database,config,logs,grafana,prometheus,docs,scripts}
    
    if [ $? -eq 0 ]; then
        status_ok "Estrutura de backup criada: $BACKUP_PATH"
        
        # Criar arquivo de informações
        cat > "$BACKUP_PATH/backup_info.txt" << EOF
===========================================
BACKUP SISTEMA IF-UFG
===========================================
Data: $(date '+%d/%m/%Y %H:%M:%S')
Servidor: $(hostname)
Usuário: $(whoami)
Versão: 2.0.0
Tipo: Backup Completo
===========================================
EOF
        
        status_ok "Arquivo de informações criado"
    else
        status_error "Erro ao criar estrutura de backup"
        exit 1
    fi
}

# Backup do Banco de Dados
backup_database() {
    echo -e "${CYAN}🗄️ Backup do Banco de Dados...${NC}"
    
    local db_file="$PROJECT_DIR/backend/database.db"
    
    if [ -f "$db_file" ]; then
        # Backup do SQLite
        cp "$db_file" "$BACKUP_PATH/database/"
        
        # Dump SQL
        sqlite3 "$db_file" .dump > "$BACKUP_PATH/database/database_dump.sql"
        
        # Estatísticas do banco
        sqlite3 "$db_file" "SELECT COUNT(*) FROM readings;" > "$BACKUP_PATH/database/stats.txt"
        
        local db_size=$(du -h "$db_file" | cut -f1)
        status_ok "Banco de dados backupeado: $db_size"
    else
        status_warning "Arquivo de banco de dados não encontrado"
    fi
    
    # Backup dados do Prometheus
    if [ -d "$PROJECT_DIR/prometheus_data" ]; then
        tar -czf "$BACKUP_PATH/database/prometheus_data.tar.gz" -C "$PROJECT_DIR" prometheus_data/
        status_ok "Dados do Prometheus backupeados"
    else
        status_warning "Dados do Prometheus não encontrados"
    fi
}

# Backup de Configurações
backup_config() {
    echo -e "${CYAN}⚙️ Backup de Configurações...${NC}"
    
    # Docker Compose
    if [ -f "$PROJECT_DIR/docker-compose.yml" ]; then
        cp "$PROJECT_DIR/docker-compose.yml" "$BACKUP_PATH/config/"
        status_ok "docker-compose.yml backupeado"
    fi
    
    # Configurações do Grafana
    if [ -d "$PROJECT_DIR/grafana" ]; then
        cp -r "$PROJECT_DIR/grafana" "$BACKUP_PATH/config/"
        status_ok "Configurações do Grafana backupeadas"
    fi
    
    # Configurações do Prometheus
    if [ -f "$PROJECT_DIR/prometheus.yml" ]; then
        cp "$PROJECT_DIR/prometheus.yml" "$BACKUP_PATH/config/"
        status_ok "prometheus.yml backupeado"
    fi
    
    # Configurações do Backend
    if [ -f "$PROJECT_DIR/backend/config.py" ]; then
        cp "$PROJECT_DIR/backend/config.py" "$BACKUP_PATH/config/"
        status_ok "config.py backupeado"
    fi
    
    # Arquivo de ambiente
    if [ -f "$PROJECT_DIR/.env" ]; then
        cp "$PROJECT_DIR/.env" "$BACKUP_PATH/config/"
        status_ok ".env backupeado"
    fi
}

# Backup de Logs
backup_logs() {
    echo -e "${CYAN}📋 Backup de Logs...${NC}"
    
    if [ -d "$PROJECT_DIR/logs" ]; then
        # Backup dos logs dos últimos 7 dias
        find "$PROJECT_DIR/logs" -name "*.log" -mtime -7 -exec cp {} "$BACKUP_PATH/logs/" \;
        
        local log_count=$(find "$BACKUP_PATH/logs" -name "*.log" | wc -l)
        status_ok "Logs backupeados: $log_count arquivos"
    else
        status_warning "Diretório de logs não encontrado"
    fi
}

# Backup de Dashboards do Grafana
backup_grafana_dashboards() {
    echo -e "${CYAN}📊 Backup de Dashboards Grafana...${NC}"
    
    # Verificar se Grafana está rodando
    if curl -s http://localhost:3000/api/health &> /dev/null; then
        # Backup via API
        curl -s -H "Content-Type: application/json" \
             http://admin:admin@localhost:3000/api/search?type=dash-db | \
             jq -r '.[].uri' | while read -r uri; do
            dashboard_json=$(curl -s -H "Content-Type: application/json" \
                           "http://admin:admin@localhost:3000/api/dashboards/$uri")
            
            dashboard_title=$(echo "$dashboard_json" | jq -r '.dashboard.title' | tr ' ' '_')
            echo "$dashboard_json" > "$BACKUP_PATH/grafana/dashboard_${dashboard_title}.json"
        done
        
        status_ok "Dashboards do Grafana backupeados"
    else
        status_warning "Grafana não está respondendo - backup via arquivo"
        
        # Backup via arquivos
        if [ -d "$PROJECT_DIR/grafana_data" ]; then
            cp -r "$PROJECT_DIR/grafana_data" "$BACKUP_PATH/grafana/"
            status_ok "Dados do Grafana backupeados via arquivo"
        fi
    fi
}

# Backup de Scripts
backup_scripts() {
    echo -e "${CYAN}📜 Backup de Scripts...${NC}"
    
    # Scripts principais
    for script in start.sh stop.sh logs.sh; do
        if [ -f "$PROJECT_DIR/$script" ]; then
            cp "$PROJECT_DIR/$script" "$BACKUP_PATH/scripts/"
            status_ok "Script $script backupeado"
        fi
    done
    
    # Scripts utilitários
    if [ -d "$PROJECT_DIR/utils" ]; then
        cp -r "$PROJECT_DIR/utils" "$BACKUP_PATH/scripts/"
        status_ok "Scripts utilitários backupeados"
    fi
}

# Backup de Documentação
backup_docs() {
    echo -e "${CYAN}📚 Backup de Documentação...${NC}"
    
    if [ -d "$PROJECT_DIR/docs" ]; then
        cp -r "$PROJECT_DIR/docs" "$BACKUP_PATH/"
        status_ok "Documentação backupeada"
    fi
    
    # README principal
    if [ -f "$PROJECT_DIR/README.md" ]; then
        cp "$PROJECT_DIR/README.md" "$BACKUP_PATH/"
        status_ok "README.md backupeado"
    fi
}

# Criar arquivo de restore
create_restore_script() {
    echo -e "${CYAN}🔄 Criando script de restore...${NC}"
    
    cat > "$BACKUP_PATH/restore.sh" << 'EOF'
#!/bin/bash

# Script de Restore Automático
# Gerado automaticamente pelo sistema de backup

BACKUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$BACKUP_DIR")"

echo "🔄 Iniciando restore do backup..."

# Parar sistema
echo "⏹️ Parando sistema..."
cd "$PROJECT_DIR" && ./stop.sh

# Restaurar banco de dados
echo "🗄️ Restaurando banco de dados..."
if [ -f "$BACKUP_DIR/database/database.db" ]; then
    cp "$BACKUP_DIR/database/database.db" "$PROJECT_DIR/backend/"
    echo "✅ Banco de dados restaurado"
fi

# Restaurar configurações
echo "⚙️ Restaurando configurações..."
if [ -f "$BACKUP_DIR/config/docker-compose.yml" ]; then
    cp "$BACKUP_DIR/config/docker-compose.yml" "$PROJECT_DIR/"
fi

if [ -f "$BACKUP_DIR/config/.env" ]; then
    cp "$BACKUP_DIR/config/.env" "$PROJECT_DIR/"
fi

# Restaurar Grafana
echo "📊 Restaurando Grafana..."
if [ -d "$BACKUP_DIR/config/grafana" ]; then
    cp -r "$BACKUP_DIR/config/grafana" "$PROJECT_DIR/"
fi

# Reiniciar sistema
echo "🚀 Reiniciando sistema..."
cd "$PROJECT_DIR" && ./start.sh

echo "✅ Restore concluído!"
EOF

    chmod +x "$BACKUP_PATH/restore.sh"
    status_ok "Script de restore criado"
}

# Compactar backup
compress_backup() {
    echo -e "${CYAN}📦 Compactando backup...${NC}"
    
    cd "$BACKUP_DIR"
    tar -czf "${BACKUP_NAME}.tar.gz" "$BACKUP_NAME"
    
    if [ $? -eq 0 ]; then
        local backup_size=$(du -h "${BACKUP_NAME}.tar.gz" | cut -f1)
        status_ok "Backup compactado: ${backup_size}"
        
        # Remover diretório temporário
        rm -rf "$BACKUP_NAME"
        
        echo -e "${GREEN}📦 Backup disponível em: ${BACKUP_DIR}/${BACKUP_NAME}.tar.gz${NC}"
    else
        status_error "Erro ao compactar backup"
    fi
}

# Limpeza de backups antigos
cleanup_old_backups() {
    echo -e "${CYAN}🧹 Limpando backups antigos...${NC}"
    
    # Manter apenas os últimos 7 backups
    cd "$BACKUP_DIR"
    ls -t backup_ifufg_*.tar.gz | tail -n +8 | xargs -r rm
    
    local remaining_backups=$(ls -1 backup_ifufg_*.tar.gz 2>/dev/null | wc -l)
    status_ok "Backups mantidos: $remaining_backups"
}

# Verificar integridade do backup
verify_backup() {
    echo -e "${CYAN}🔍 Verificando integridade do backup...${NC}"
    
    if [ -f "$BACKUP_DIR/${BACKUP_NAME}.tar.gz" ]; then
        if tar -tzf "$BACKUP_DIR/${BACKUP_NAME}.tar.gz" > /dev/null 2>&1; then
            status_ok "Integridade do backup verificada"
        else
            status_error "Backup corrompido"
        fi
    fi
}

# Enviar backup por email (opcional)
send_backup_notification() {
    echo -e "${CYAN}📧 Enviando notificação de backup...${NC}"
    
    local email_config="$PROJECT_DIR/backend/config.py"
    
    if [ -f "$email_config" ] && grep -q "SMTP_" "$email_config"; then
        local backup_size=$(du -h "$BACKUP_DIR/${BACKUP_NAME}.tar.gz" | cut -f1)
        
        # Usar o sistema de email do projeto
        python3 - << EOF
import sys
sys.path.append('$PROJECT_DIR/backend')
from email_service import send_email

subject = "✅ Backup Concluído - IF-UFG"
body = f"""
Backup do sistema IF-UFG concluído com sucesso!

📅 Data: $(date '+%d/%m/%Y %H:%M:%S')
📦 Tamanho: $backup_size
📍 Servidor: $(hostname)
📁 Arquivo: ${BACKUP_NAME}.tar.gz

O backup foi armazenado localmente e está pronto para uso.
"""

send_email(subject, body)
EOF
        
        status_ok "Notificação de backup enviada"
    else
        status_info "Notificação por email não configurada"
    fi
}

# Relatório Final
print_summary() {
    echo -e "\n${PURPLE}================================${NC}"
    echo -e "${PURPLE}📋 RELATÓRIO DE BACKUP${NC}"
    echo -e "${PURPLE}================================${NC}"
    
    echo -e "${BLUE}📅 Data: $(date '+%d/%m/%Y %H:%M:%S')${NC}"
    echo -e "${BLUE}🏢 Sistema: IF-UFG Cluster Monitoring${NC}"
    echo -e "${BLUE}📍 Servidor: $(hostname)${NC}"
    echo -e "${BLUE}📦 Backup: ${BACKUP_NAME}.tar.gz${NC}"
    
    if [ -f "$BACKUP_DIR/${BACKUP_NAME}.tar.gz" ]; then
        local backup_size=$(du -h "$BACKUP_DIR/${BACKUP_NAME}.tar.gz" | cut -f1)
        echo -e "${BLUE}📊 Tamanho: $backup_size${NC}"
    fi
    
    echo -e "\n${CYAN}🔧 Comandos para restore:${NC}"
    echo -e "${YELLOW}  • Extrair: tar -xzf ${BACKUP_NAME}.tar.gz${NC}"
    echo -e "${YELLOW}  • Restore: ./${BACKUP_NAME}/restore.sh${NC}"
    
    echo -e "\n${GREEN}✅ Backup concluído com sucesso!${NC}"
}

# Função principal
main() {
    print_banner
    
    # Criar diretório de backups se não existir
    mkdir -p "$BACKUP_DIR"
    
    # Executar backup
    create_backup_structure
    backup_database
    backup_config
    backup_logs
    backup_grafana_dashboards
    backup_scripts
    backup_docs
    create_restore_script
    compress_backup
    cleanup_old_backups
    verify_backup
    send_backup_notification
    
    print_summary
}

# Executar apenas se chamado diretamente
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    main "$@"
fi 