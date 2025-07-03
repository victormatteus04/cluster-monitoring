#!/bin/bash

# =============================================================================
# Limpeza de Logs Automática - IF-UFG
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
LOG_DIR="$PROJECT_DIR/logs"
RETENTION_DAYS=30
LARGE_FILE_SIZE=100M

# Função para logging
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_DIR/limpeza.log"
}

# Banner
print_banner() {
    echo -e "${PURPLE}"
    echo "=========================================="
    echo "  🧹 LIMPEZA DE LOGS IF-UFG v2.0"
    echo "=========================================="
    echo -e "${NC}"
}

# Verificar tamanho antes da limpeza
check_initial_size() {
    echo -e "${CYAN}📊 Verificando tamanho atual...${NC}"
    
    if [ -d "$LOG_DIR" ]; then
        local total_size=$(du -sh "$LOG_DIR" | cut -f1)
        local file_count=$(find "$LOG_DIR" -type f -name "*.log" | wc -l)
        
        echo -e "${BLUE}📁 Diretório: $LOG_DIR${NC}"
        echo -e "${BLUE}📊 Tamanho total: $total_size${NC}"
        echo -e "${BLUE}📄 Arquivos .log: $file_count${NC}"
        
        log "INICIO: Tamanho total: $total_size, Arquivos: $file_count"
        
        # Verificar arquivos grandes
        echo -e "${CYAN}🔍 Verificando arquivos grandes (>$LARGE_FILE_SIZE)...${NC}"
        local large_files=$(find "$LOG_DIR" -type f -name "*.log" -size +$LARGE_FILE_SIZE)
        
        if [ -n "$large_files" ]; then
            echo -e "${YELLOW}⚠️ Arquivos grandes encontrados:${NC}"
            echo "$large_files" | while read -r file; do
                local size=$(du -sh "$file" | cut -f1)
                echo -e "${YELLOW}  📄 $(basename "$file"): $size${NC}"
            done
        else
            echo -e "${GREEN}✅ Nenhum arquivo grande encontrado${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️ Diretório de logs não encontrado${NC}"
        log "WARNING: Diretório de logs não encontrado"
    fi
}

# Limpar logs antigos
clean_old_logs() {
    echo -e "${CYAN}🧹 Limpando logs antigos (>${RETENTION_DAYS} dias)...${NC}"
    
    if [ ! -d "$LOG_DIR" ]; then
        echo -e "${YELLOW}⚠️ Diretório de logs não existe${NC}"
        return 0
    fi
    
    # Encontrar arquivos antigos
    local old_files=$(find "$LOG_DIR" -type f -name "*.log" -mtime +$RETENTION_DAYS)
    
    if [ -n "$old_files" ]; then
        local count=0
        local total_size=0
        
        # Contar arquivos e calcular tamanho
        echo "$old_files" | while read -r file; do
            if [ -f "$file" ]; then
                local size=$(stat -c%s "$file")
                total_size=$((total_size + size))
                count=$((count + 1))
                
                echo -e "${YELLOW}🗑️ Removendo: $(basename "$file")${NC}"
                rm "$file"
                log "REMOVED: $file"
            fi
        done
        
        local count_actual=$(echo "$old_files" | wc -l)
        local size_mb=$((total_size / 1024 / 1024))
        
        echo -e "${GREEN}✅ Removidos $count_actual arquivos antigos (${size_mb}MB)${NC}"
        log "CLEANED: $count_actual arquivos antigos removidos"
    else
        echo -e "${GREEN}✅ Nenhum arquivo antigo encontrado${NC}"
        log "INFO: Nenhum arquivo antigo para remover"
    fi
}

# Rodar logs grandes
rotate_large_logs() {
    echo -e "${CYAN}🔄 Rotacionando logs grandes...${NC}"
    
    find "$LOG_DIR" -type f -name "*.log" -size +$LARGE_FILE_SIZE | while read -r file; do
        if [ -f "$file" ]; then
            local basename=$(basename "$file" .log)
            local dirname=$(dirname "$file")
            local timestamp=$(date +%Y%m%d_%H%M%S)
            local rotated_file="${dirname}/${basename}_${timestamp}.log"
            
            # Renomear arquivo grande
            mv "$file" "$rotated_file"
            
            # Comprimir arquivo rotacionado
            gzip "$rotated_file"
            
            # Criar novo arquivo vazio
            touch "$file"
            
            echo -e "${GREEN}✅ Rotacionado: $(basename "$file")${NC}"
            log "ROTATED: $file -> $rotated_file.gz"
        fi
    done
}

# Limpar logs do Docker
clean_docker_logs() {
    echo -e "${CYAN}🐳 Limpando logs do Docker...${NC}"
    
    if command -v docker &> /dev/null; then
        # Limpar logs de containers
        docker ps -a --format "table {{.Names}}" | grep -v "NAMES" | while read -r container; do
            if [ -n "$container" ]; then
                # Truncar logs do container
                local log_file=$(docker inspect --format='{{.LogPath}}' "$container" 2>/dev/null)
                
                if [ -f "$log_file" ]; then
                    local size_before=$(du -sh "$log_file" | cut -f1)
                    
                    # Truncar arquivo de log
                    truncate -s 0 "$log_file"
                    
                    echo -e "${GREEN}✅ Logs do container $container limpos (era: $size_before)${NC}"
                    log "DOCKER: Logs do container $container limpos"
                fi
            fi
        done
        
        # Limpar logs do sistema Docker
        docker system prune -f --volumes > /dev/null 2>&1
        echo -e "${GREEN}✅ Limpeza do sistema Docker concluída${NC}"
        log "DOCKER: Sistema Docker limpo"
    else
        echo -e "${YELLOW}⚠️ Docker não encontrado${NC}"
    fi
}

# Limpar logs do sistema
clean_system_logs() {
    echo -e "${CYAN}🖥️ Limpando logs do sistema...${NC}"
    
    # Limpar journald
    if command -v journalctl &> /dev/null; then
        # Manter apenas últimos 30 dias
        sudo journalctl --vacuum-time=${RETENTION_DAYS}d > /dev/null 2>&1
        
        # Limitar tamanho máximo
        sudo journalctl --vacuum-size=100M > /dev/null 2>&1
        
        echo -e "${GREEN}✅ Logs do journald limpos${NC}"
        log "SYSTEM: Logs do journald limpos"
    fi
    
    # Limpar /var/log (apenas se executado como root)
    if [ "$EUID" -eq 0 ]; then
        # Limpar logs antigos do sistema
        find /var/log -type f -name "*.log" -mtime +$RETENTION_DAYS -exec rm {} \; 2>/dev/null
        
        # Limpar logs rotacionados antigos
        find /var/log -type f -name "*.log.*" -mtime +$RETENTION_DAYS -exec rm {} \; 2>/dev/null
        
        echo -e "${GREEN}✅ Logs do sistema limpos${NC}"
        log "SYSTEM: Logs do /var/log limpos"
    else
        echo -e "${YELLOW}⚠️ Sem permissão para limpar logs do sistema${NC}"
    fi
}

# Comprimir logs antigos
compress_old_logs() {
    echo -e "${CYAN}📦 Comprimindo logs antigos...${NC}"
    
    # Comprimir logs de 7-30 dias
    find "$LOG_DIR" -type f -name "*.log" -mtime +7 -mtime -$RETENTION_DAYS | while read -r file; do
        if [ -f "$file" ] && [[ "$file" != *.gz ]]; then
            local original_size=$(du -sh "$file" | cut -f1)
            
            gzip "$file"
            
            if [ -f "${file}.gz" ]; then
                local compressed_size=$(du -sh "${file}.gz" | cut -f1)
                echo -e "${GREEN}✅ Comprimido: $(basename "$file") ($original_size -> $compressed_size)${NC}"
                log "COMPRESSED: $file ($original_size -> $compressed_size)"
            fi
        fi
    done
}

# Estatísticas de limpeza
show_cleanup_stats() {
    echo -e "${CYAN}📊 Estatísticas após limpeza...${NC}"
    
    if [ -d "$LOG_DIR" ]; then
        local total_size=$(du -sh "$LOG_DIR" | cut -f1)
        local file_count=$(find "$LOG_DIR" -type f -name "*.log" | wc -l)
        local compressed_count=$(find "$LOG_DIR" -type f -name "*.log.gz" | wc -l)
        
        echo -e "${BLUE}📊 Tamanho total: $total_size${NC}"
        echo -e "${BLUE}📄 Arquivos .log: $file_count${NC}"
        echo -e "${BLUE}📦 Arquivos comprimidos: $compressed_count${NC}"
        
        log "FINAL: Tamanho total: $total_size, Arquivos: $file_count, Comprimidos: $compressed_count"
        
        # Top 10 maiores arquivos
        echo -e "${CYAN}🔝 Top 10 maiores arquivos:${NC}"
        find "$LOG_DIR" -type f \( -name "*.log" -o -name "*.log.gz" \) -exec du -h {} \; | sort -rh | head -10 | while read -r size file; do
            echo -e "${YELLOW}  📄 $(basename "$file"): $size${NC}"
        done
    fi
}

# Configurar limpeza automática
setup_automatic_cleanup() {
    echo -e "${CYAN}⚙️ Configurando limpeza automática...${NC}"
    
    local cron_job="0 2 * * * $SCRIPT_DIR/limpar_logs.sh --quiet"
    
    # Verificar se cron job já existe
    if crontab -l 2>/dev/null | grep -q "limpar_logs.sh"; then
        echo -e "${YELLOW}⚠️ Cron job já existe${NC}"
    else
        # Adicionar cron job
        (crontab -l 2>/dev/null; echo "$cron_job") | crontab -
        echo -e "${GREEN}✅ Cron job configurado (diário às 02:00)${NC}"
        log "SETUP: Cron job configurado"
    fi
}

# Modo silencioso
quiet_mode() {
    log "INICIO: Limpeza automática iniciada"
    
    # Limpar logs antigos
    find "$LOG_DIR" -type f -name "*.log" -mtime +$RETENTION_DAYS -delete 2>/dev/null
    
    # Rodar logs grandes
    find "$LOG_DIR" -type f -name "*.log" -size +$LARGE_FILE_SIZE | while read -r file; do
        if [ -f "$file" ]; then
            local basename=$(basename "$file" .log)
            local dirname=$(dirname "$file")
            local timestamp=$(date +%Y%m%d_%H%M%S)
            local rotated_file="${dirname}/${basename}_${timestamp}.log"
            
            mv "$file" "$rotated_file"
            gzip "$rotated_file"
            touch "$file"
            
            log "ROTATED: $file"
        fi
    done
    
    # Comprimir logs antigos
    find "$LOG_DIR" -type f -name "*.log" -mtime +7 -mtime -$RETENTION_DAYS -exec gzip {} \; 2>/dev/null
    
    log "FINAL: Limpeza automática concluída"
}

# Ajuda
show_help() {
    echo -e "${CYAN}📖 Uso:${NC}"
    echo -e "${YELLOW}  ./limpar_logs.sh [opções]${NC}"
    echo -e ""
    echo -e "${CYAN}Opções:${NC}"
    echo -e "${YELLOW}  --days N           Manter logs dos últimos N dias (padrão: 30)${NC}"
    echo -e "${YELLOW}  --size SIZE        Tamanho máximo para rotação (padrão: 100M)${NC}"
    echo -e "${YELLOW}  --docker           Limpar apenas logs do Docker${NC}"
    echo -e "${YELLOW}  --system           Limpar logs do sistema (requer root)${NC}"
    echo -e "${YELLOW}  --setup-cron       Configurar limpeza automática${NC}"
    echo -e "${YELLOW}  --quiet            Modo silencioso${NC}"
    echo -e "${YELLOW}  -h, --help         Mostrar ajuda${NC}"
    echo -e ""
    echo -e "${CYAN}Exemplos:${NC}"
    echo -e "${YELLOW}  ./limpar_logs.sh --days 15${NC}"
    echo -e "${YELLOW}  ./limpar_logs.sh --docker${NC}"
    echo -e "${YELLOW}  ./limpar_logs.sh --setup-cron${NC}"
}

# Função principal
main() {
    mkdir -p "$LOG_DIR"
    
    # Processar argumentos
    while [[ $# -gt 0 ]]; do
        case $1 in
            --days)
                RETENTION_DAYS="$2"
                shift 2
                ;;
            --size)
                LARGE_FILE_SIZE="$2"
                shift 2
                ;;
            --docker)
                print_banner
                clean_docker_logs
                exit 0
                ;;
            --system)
                print_banner
                clean_system_logs
                exit 0
                ;;
            --setup-cron)
                setup_automatic_cleanup
                exit 0
                ;;
            --quiet)
                quiet_mode
                exit 0
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                echo -e "${RED}❌ Opção inválida: $1${NC}"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Limpeza completa
    print_banner
    
    check_initial_size
    clean_old_logs
    rotate_large_logs
    compress_old_logs
    clean_docker_logs
    clean_system_logs
    show_cleanup_stats
    
    echo -e "\n${GREEN}✅ Limpeza concluída!${NC}"
    log "COMPLETED: Limpeza completa concluída"
}

# Executar apenas se chamado diretamente
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    main "$@"
fi 