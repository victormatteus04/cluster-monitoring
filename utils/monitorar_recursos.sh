#!/bin/bash

# =============================================================================
# Monitoramento de Recursos do Sistema - IF-UFG
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
METRICS_DIR="$PROJECT_DIR/logs/metrics"
CSV_FILE="$METRICS_DIR/recursos_$(date +%Y%m%d).csv"
ALERT_THRESHOLD_CPU=80
ALERT_THRESHOLD_MEM=80
ALERT_THRESHOLD_DISK=85

# Função para logging
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$PROJECT_DIR/logs/monitoramento.log"
}

# Banner
print_banner() {
    echo -e "${PURPLE}"
    echo "=========================================="
    echo "  📊 MONITORAMENTO RECURSOS IF-UFG v2.0"
    echo "=========================================="
    echo -e "${NC}"
}

# Criar cabeçalho CSV
create_csv_header() {
    if [ ! -f "$CSV_FILE" ]; then
        echo "timestamp,cpu_percent,mem_percent,mem_used_gb,mem_total_gb,disk_percent,disk_used_gb,disk_total_gb,load_avg,docker_containers,processes" > "$CSV_FILE"
    fi
}

# Coletar métricas
collect_metrics() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # CPU
    local cpu_percent=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')
    
    # Memória
    local mem_info=$(free -g | grep "Mem:")
    local mem_total=$(echo $mem_info | awk '{print $2}')
    local mem_used=$(echo $mem_info | awk '{print $3}')
    local mem_percent=$(free | grep "Mem:" | awk '{printf "%.1f", $3/$2 * 100.0}')
    
    # Disco
    local disk_info=$(df -h / | tail -1)
    local disk_total=$(echo $disk_info | awk '{print $2}' | sed 's/G//')
    local disk_used=$(echo $disk_info | awk '{print $3}' | sed 's/G//')
    local disk_percent=$(echo $disk_info | awk '{print $5}' | sed 's/%//')
    
    # Load Average
    local load_avg=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')
    
    # Docker
    local docker_containers=$(docker ps --format "table {{.Names}}" 2>/dev/null | wc -l)
    docker_containers=$((docker_containers - 1)) # Remove header
    
    # Processos
    local processes=$(ps aux | wc -l)
    
    # Salvar no CSV
    echo "$timestamp,$cpu_percent,$mem_percent,$mem_used,$mem_total,$disk_percent,$disk_used,$disk_total,$load_avg,$docker_containers,$processes" >> "$CSV_FILE"
    
    # Mostrar métricas
    echo -e "${BLUE}📊 Métricas coletadas:${NC}"
    echo -e "${CYAN}  🔥 CPU: ${cpu_percent}%${NC}"
    echo -e "${CYAN}  🧠 Memória: ${mem_used}GB/${mem_total}GB (${mem_percent}%)${NC}"
    echo -e "${CYAN}  💾 Disco: ${disk_used}GB/${disk_total}GB (${disk_percent}%)${NC}"
    echo -e "${CYAN}  ⚡ Load: ${load_avg}${NC}"
    echo -e "${CYAN}  🐳 Containers: ${docker_containers}${NC}"
    echo -e "${CYAN}  🔧 Processos: ${processes}${NC}"
    
    # Verificar alertas
    check_alerts "$cpu_percent" "$mem_percent" "$disk_percent"
    
    return 0
}

# Verificar alertas
check_alerts() {
    local cpu=$1
    local mem=$2
    local disk=$3
    
    # CPU
    if (( $(echo "$cpu > $ALERT_THRESHOLD_CPU" | bc -l) )); then
        echo -e "${RED}🚨 ALERTA: CPU alta ${cpu}%${NC}"
        log "ALERT: CPU alta ${cpu}%"
        send_alert "CPU Alta" "CPU em ${cpu}% (limite: ${ALERT_THRESHOLD_CPU}%)"
    fi
    
    # Memória
    if (( $(echo "$mem > $ALERT_THRESHOLD_MEM" | bc -l) )); then
        echo -e "${RED}🚨 ALERTA: Memória alta ${mem}%${NC}"
        log "ALERT: Memória alta ${mem}%"
        send_alert "Memória Alta" "Memória em ${mem}% (limite: ${ALERT_THRESHOLD_MEM}%)"
    fi
    
    # Disco
    if [ $disk -gt $ALERT_THRESHOLD_DISK ]; then
        echo -e "${RED}🚨 ALERTA: Disco cheio ${disk}%${NC}"
        log "ALERT: Disco cheio ${disk}%"
        send_alert "Disco Cheio" "Disco em ${disk}% (limite: ${ALERT_THRESHOLD_DISK}%)"
    fi
}

# Enviar alerta
send_alert() {
    local subject="$1"
    local message="$2"
    
    # Verificar se sistema de email está configurado
    if [ -f "$PROJECT_DIR/backend/config.py" ] && grep -q "SMTP_" "$PROJECT_DIR/backend/config.py"; then
        python3 - << EOF
import sys
sys.path.append('$PROJECT_DIR/backend')
try:
    from email_service import send_email
    send_email("🚨 $subject - IF-UFG", "$message\n\nServidor: $(hostname)\nData: $(date)")
except Exception as e:
    print(f"Erro ao enviar email: {e}")
EOF
    fi
}

# Mostrar estatísticas
show_statistics() {
    echo -e "${CYAN}📈 Estatísticas do dia:${NC}"
    
    if [ -f "$CSV_FILE" ]; then
        local avg_cpu=$(tail -n +2 "$CSV_FILE" | awk -F',' '{sum+=$2} END {print sum/NR}')
        local avg_mem=$(tail -n +2 "$CSV_FILE" | awk -F',' '{sum+=$3} END {print sum/NR}')
        local avg_disk=$(tail -n +2 "$CSV_FILE" | awk -F',' '{sum+=$6} END {print sum/NR}')
        local max_cpu=$(tail -n +2 "$CSV_FILE" | awk -F',' '{if($2>max) max=$2} END {print max}')
        local max_mem=$(tail -n +2 "$CSV_FILE" | awk -F',' '{if($3>max) max=$3} END {print max}')
        local max_disk=$(tail -n +2 "$CSV_FILE" | awk -F',' '{if($6>max) max=$6} END {print max}')
        
        echo -e "${YELLOW}  CPU - Média: ${avg_cpu}% | Máximo: ${max_cpu}%${NC}"
        echo -e "${YELLOW}  Memória - Média: ${avg_mem}% | Máximo: ${max_mem}%${NC}"
        echo -e "${YELLOW}  Disco - Média: ${avg_disk}% | Máximo: ${max_disk}%${NC}"
    else
        echo -e "${YELLOW}  Sem dados disponíveis${NC}"
    fi
}

# Limpar dados antigos
cleanup_old_data() {
    echo -e "${CYAN}🧹 Limpando dados antigos...${NC}"
    
    # Manter apenas últimos 30 dias
    find "$METRICS_DIR" -name "recursos_*.csv" -mtime +30 -delete
    
    local files_count=$(find "$METRICS_DIR" -name "recursos_*.csv" | wc -l)
    echo -e "${GREEN}✅ Arquivos mantidos: $files_count${NC}"
}

# Modo contínuo
continuous_monitoring() {
    echo -e "${CYAN}🔄 Iniciando monitoramento contínuo...${NC}"
    echo -e "${YELLOW}Pressione Ctrl+C para parar${NC}"
    
    while true; do
        clear
        print_banner
        collect_metrics
        show_statistics
        echo -e "\n${BLUE}⏰ Próxima coleta em 60 segundos...${NC}"
        sleep 60
    done
}

# Gerar relatório
generate_report() {
    echo -e "${CYAN}📄 Gerando relatório...${NC}"
    
    local report_file="$PROJECT_DIR/logs/relatorio_recursos_$(date +%Y%m%d_%H%M%S).html"
    
    cat > "$report_file" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Relatório de Recursos - IF-UFG</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background: #f0f0f0; padding: 20px; border-radius: 5px; }
        .metric { background: #e8f4f8; padding: 15px; margin: 10px 0; border-radius: 5px; }
        .alert { background: #ffebee; color: #c62828; padding: 10px; border-radius: 5px; }
        .ok { background: #e8f5e8; color: #2e7d32; padding: 10px; border-radius: 5px; }
        table { border-collapse: collapse; width: 100%; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
    </style>
</head>
<body>
    <div class="header">
        <h1>📊 Relatório de Recursos - IF-UFG</h1>
        <p><strong>Data:</strong> $(date '+%d/%m/%Y %H:%M:%S')</p>
        <p><strong>Servidor:</strong> $(hostname)</p>
    </div>
    
    <div class="metric">
        <h2>📈 Métricas Atuais</h2>
EOF

    # Coletar métricas atuais
    local cpu_current=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')
    local mem_current=$(free | grep "Mem:" | awk '{printf "%.1f", $3/$2 * 100.0}')
    local disk_current=$(df -h / | tail -1 | awk '{print $5}' | sed 's/%//')
    
    # Determinar status
    local cpu_status="ok"
    local mem_status="ok"
    local disk_status="ok"
    
    if (( $(echo "$cpu_current > $ALERT_THRESHOLD_CPU" | bc -l) )); then
        cpu_status="alert"
    fi
    
    if (( $(echo "$mem_current > $ALERT_THRESHOLD_MEM" | bc -l) )); then
        mem_status="alert"
    fi
    
    if [ $disk_current -gt $ALERT_THRESHOLD_DISK ]; then
        disk_status="alert"
    fi
    
    cat >> "$report_file" << EOF
        <div class="$cpu_status">CPU: ${cpu_current}%</div>
        <div class="$mem_status">Memória: ${mem_current}%</div>
        <div class="$disk_status">Disco: ${disk_current}%</div>
    </div>
    
    <div class="metric">
        <h2>📊 Histórico (Últimas 24h)</h2>
        <table>
            <tr>
                <th>Hora</th>
                <th>CPU %</th>
                <th>Memória %</th>
                <th>Disco %</th>
                <th>Load</th>
                <th>Containers</th>
            </tr>
EOF

    # Adicionar dados das últimas 24h
    if [ -f "$CSV_FILE" ]; then
        tail -n 24 "$CSV_FILE" | while IFS=',' read timestamp cpu mem mem_used mem_total disk disk_used disk_total load containers processes; do
            echo "            <tr>" >> "$report_file"
            echo "                <td>$(date -d "$timestamp" '+%H:%M')</td>" >> "$report_file"
            echo "                <td>$cpu</td>" >> "$report_file"
            echo "                <td>$mem</td>" >> "$report_file"
            echo "                <td>$disk</td>" >> "$report_file"
            echo "                <td>$load</td>" >> "$report_file"
            echo "                <td>$containers</td>" >> "$report_file"
            echo "            </tr>" >> "$report_file"
        done
    fi
    
    cat >> "$report_file" << EOF
        </table>
    </div>
    
    <div class="metric">
        <h2>💡 Recomendações</h2>
        <ul>
            <li>Monitore regularmente os recursos do sistema</li>
            <li>Configure alertas para valores críticos</li>
            <li>Faça backup dos dados periodicamente</li>
            <li>Mantenha os containers atualizados</li>
        </ul>
    </div>
    
    <p><em>Relatório gerado automaticamente pelo Sistema de Monitoramento IF-UFG</em></p>
</body>
</html>
EOF
    
    echo -e "${GREEN}✅ Relatório gerado: $report_file${NC}"
}

# Ajuda
show_help() {
    echo -e "${CYAN}📖 Uso:${NC}"
    echo -e "${YELLOW}  ./monitorar_recursos.sh [opção]${NC}"
    echo -e ""
    echo -e "${CYAN}Opções:${NC}"
    echo -e "${YELLOW}  -c, --continuo     Monitoramento contínuo${NC}"
    echo -e "${YELLOW}  -s, --single       Coleta única${NC}"
    echo -e "${YELLOW}  -r, --report       Gerar relatório HTML${NC}"
    echo -e "${YELLOW}  -h, --help         Mostrar ajuda${NC}"
    echo -e ""
    echo -e "${CYAN}Exemplos:${NC}"
    echo -e "${YELLOW}  ./monitorar_recursos.sh -c${NC}"
    echo -e "${YELLOW}  ./monitorar_recursos.sh -s${NC}"
    echo -e "${YELLOW}  ./monitorar_recursos.sh -r${NC}"
}

# Função principal
main() {
    # Criar diretórios necessários
    mkdir -p "$METRICS_DIR"
    mkdir -p "$PROJECT_DIR/logs"
    
    # Criar cabeçalho CSV
    create_csv_header
    
    # Processar argumentos
    case "${1:-}" in
        -c|--continuo)
            continuous_monitoring
            ;;
        -s|--single)
            print_banner
            collect_metrics
            show_statistics
            ;;
        -r|--report)
            generate_report
            ;;
        -h|--help)
            show_help
            ;;
        *)
            print_banner
            collect_metrics
            show_statistics
            cleanup_old_data
            ;;
    esac
}

# Executar apenas se chamado diretamente
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    main "$@"
fi 