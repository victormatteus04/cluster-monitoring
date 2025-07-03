#!/bin/bash

# =============================================================================
# Coleta de Informações para Suporte - IF-UFG
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
SUPPORT_DIR="$PROJECT_DIR/logs/support"
DATE=$(date +%Y%m%d_%H%M%S)
SUPPORT_PACKAGE="support_package_$DATE"
SUPPORT_PATH="$SUPPORT_DIR/$SUPPORT_PACKAGE"

# Banner
print_banner() {
    echo -e "${PURPLE}"
    echo "=========================================="
    echo "  📋 COLETA SUPORTE IF-UFG v2.0"
    echo "=========================================="
    echo -e "${NC}"
}

# Função para status
status() {
    echo -e "${GREEN}✅ $1${NC}"
}

# Criar estrutura do pacote
create_package_structure() {
    echo -e "${CYAN}📁 Criando estrutura do pacote...${NC}"
    
    mkdir -p "$SUPPORT_PATH"/{system,docker,logs,config,database,network,sensors}
    
    # Criar arquivo de informações
    cat > "$SUPPORT_PATH/package_info.txt" << EOF
===========================================
PACOTE DE SUPORTE - IF-UFG
===========================================
Data de Criação: $(date '+%d/%m/%Y %H:%M:%S')
Servidor: $(hostname)
Usuário: $(whoami)
Versão do Sistema: 2.0.0
Tipo: Suporte Técnico Completo
===========================================

Este pacote contém informações completas do sistema
para análise de suporte técnico.

Diretórios:
- system/     : Informações do sistema operacional
- docker/     : Informações dos containers Docker
- logs/       : Logs relevantes para diagnóstico
- config/     : Arquivos de configuração
- database/   : Informações do banco de dados
- network/    : Informações de rede
- sensors/    : Status dos sensores
EOF
    
    status "Estrutura do pacote criada"
}

# Coletar informações do sistema
collect_system_info() {
    echo -e "${CYAN}🖥️ Coletando informações do sistema...${NC}"
    
    local sys_dir="$SUPPORT_PATH/system"
    
    # Informações básicas
    uname -a > "$sys_dir/uname.txt"
    lsb_release -a > "$sys_dir/os_release.txt" 2>/dev/null
    cat /proc/cpuinfo > "$sys_dir/cpuinfo.txt"
    cat /proc/meminfo > "$sys_dir/meminfo.txt"
    
    # Processos
    ps aux > "$sys_dir/processes.txt"
    top -bn1 > "$sys_dir/top_snapshot.txt"
    
    # Recursos
    free -h > "$sys_dir/memory_usage.txt"
    df -h > "$sys_dir/disk_usage.txt"
    lsof > "$sys_dir/open_files.txt" 2>/dev/null
    
    # Rede
    netstat -tuln > "$sys_dir/network_ports.txt"
    ss -tuln > "$sys_dir/socket_stats.txt"
    ip addr show > "$sys_dir/ip_config.txt"
    
    # Serviços
    systemctl list-units --failed > "$sys_dir/failed_services.txt"
    systemctl status > "$sys_dir/systemd_status.txt"
    
    # Logs do sistema
    journalctl --since "24 hours ago" > "$sys_dir/journalctl_24h.txt" 2>/dev/null
    
    # Cron jobs
    crontab -l > "$sys_dir/crontab.txt" 2>/dev/null
    
    status "Informações do sistema coletadas"
}

# Coletar informações do Docker
collect_docker_info() {
    echo -e "${CYAN}🐳 Coletando informações do Docker...${NC}"
    
    local docker_dir="$SUPPORT_PATH/docker"
    
    if command -v docker &> /dev/null; then
        # Informações básicas
        docker --version > "$docker_dir/docker_version.txt"
        docker info > "$docker_dir/docker_info.txt" 2>&1
        
        # Containers
        docker ps -a > "$docker_dir/containers_all.txt"
        docker ps > "$docker_dir/containers_running.txt"
        
        # Imagens
        docker images > "$docker_dir/images.txt"
        
        # Volumes
        docker volume ls > "$docker_dir/volumes.txt"
        
        # Networks
        docker network ls > "$docker_dir/networks.txt"
        
        # Stats dos containers
        timeout 10s docker stats --no-stream > "$docker_dir/container_stats.txt" 2>/dev/null
        
        # Logs dos containers principais
        local containers=("grafana" "prometheus" "backend" "mqtt")
        for container in "${containers[@]}"; do
            if docker ps --format "table {{.Names}}" | grep -q "$container"; then
                docker logs --tail 100 "$container" > "$docker_dir/logs_${container}.txt" 2>&1
                docker inspect "$container" > "$docker_dir/inspect_${container}.json" 2>/dev/null
            fi
        done
        
        # Docker Compose
        if [ -f "$PROJECT_DIR/docker-compose.yml" ]; then
            cp "$PROJECT_DIR/docker-compose.yml" "$docker_dir/"
        fi
        
        # Sistema Docker
        docker system df > "$docker_dir/system_usage.txt"
        docker system events --since 24h --until now > "$docker_dir/events_24h.txt" 2>/dev/null &
        local events_pid=$!
        sleep 2
        kill $events_pid 2>/dev/null
        
    else
        echo "Docker não encontrado" > "$docker_dir/docker_not_found.txt"
    fi
    
    status "Informações do Docker coletadas"
}

# Coletar logs relevantes
collect_logs() {
    echo -e "${CYAN}📋 Coletando logs relevantes...${NC}"
    
    local logs_dir="$SUPPORT_PATH/logs"
    local project_logs="$PROJECT_DIR/logs"
    
    if [ -d "$project_logs" ]; then
        # Logs principais dos últimos 2 dias
        find "$project_logs" -name "*.log" -mtime -2 -exec cp {} "$logs_dir/" \; 2>/dev/null
        
        # Status files
        if [ -f "$project_logs/health_status.json" ]; then
            cp "$project_logs/health_status.json" "$logs_dir/"
        fi
        
        # Últimos alertas
        if [ -f "$project_logs/health_alerts.log" ]; then
            tail -100 "$project_logs/health_alerts.log" > "$logs_dir/recent_alerts.log"
        fi
        
        # Métricas recentes
        if [ -d "$project_logs/metrics" ]; then
            # Últimos 3 arquivos de métricas
            find "$project_logs/metrics" -name "recursos_*.csv" | sort -r | head -3 | \
            while read -r file; do
                cp "$file" "$logs_dir/"
            done
        fi
        
        # Análises recentes
        if [ -d "$project_logs/analysis" ]; then
            find "$project_logs/analysis" -name "*.html" -mtime -7 -exec cp {} "$logs_dir/" \; 2>/dev/null
        fi
    fi
    
    status "Logs relevantes coletados"
}

# Coletar configurações
collect_configs() {
    echo -e "${CYAN}⚙️ Coletando configurações...${NC}"
    
    local config_dir="$SUPPORT_PATH/config"
    
    # Configurações principais do projeto
    local configs=(
        "docker-compose.yml"
        "prometheus.yml" 
        ".env"
        "grafana.ini"
    )
    
    for config in "${configs[@]}"; do
        if [ -f "$PROJECT_DIR/$config" ]; then
            # Copiar removendo informações sensíveis
            sed 's/password=.*/password=REDACTED/g; s/secret=.*/secret=REDACTED/g' \
                "$PROJECT_DIR/$config" > "$config_dir/$config"
        fi
    done
    
    # Configurações do backend
    if [ -f "$PROJECT_DIR/backend/config.py" ]; then
        # Remover senhas e tokens
        sed 's/password.*=.*/password = "REDACTED"/g; s/token.*=.*/token = "REDACTED"/g; s/secret.*=.*/secret = "REDACTED"/g' \
            "$PROJECT_DIR/backend/config.py" > "$config_dir/backend_config.py"
    fi
    
    # Configurações do Grafana
    if [ -d "$PROJECT_DIR/grafana" ]; then
        cp -r "$PROJECT_DIR/grafana" "$config_dir/" 2>/dev/null
        # Remover dados sensíveis
        find "$config_dir/grafana" -name "*.json" -exec sed -i 's/"password":"[^"]*"/"password":"REDACTED"/g' {} \;
    fi
    
    status "Configurações coletadas (dados sensíveis removidos)"
}

# Coletar informações do banco
collect_database_info() {
    echo -e "${CYAN}🗄️ Coletando informações do banco...${NC}"
    
    local db_dir="$SUPPORT_PATH/database"
    local db_file="$PROJECT_DIR/backend/database.db"
    
    if [ -f "$db_file" ]; then
        # Informações básicas
        ls -lh "$db_file" > "$db_dir/database_info.txt"
        
        # Schema
        sqlite3 "$db_file" ".schema" > "$db_dir/database_schema.sql"
        
        # Estatísticas
        sqlite3 "$db_file" "SELECT name, COUNT(*) as count FROM sqlite_master WHERE type='table' GROUP BY name;" > "$db_dir/table_stats.txt"
        
        # Contagens por tabela
        for table in $(sqlite3 "$db_file" "SELECT name FROM sqlite_master WHERE type='table';"); do
            sqlite3 "$db_file" "SELECT COUNT(*) FROM $table;" > "$db_dir/count_$table.txt" 2>/dev/null
        done
        
        # Últimos registros (sem dados sensíveis)
        sqlite3 "$db_file" "SELECT COUNT(*), MIN(timestamp), MAX(timestamp) FROM readings;" > "$db_dir/readings_summary.txt" 2>/dev/null
        
        # Verificação de integridade
        sqlite3 "$db_file" "PRAGMA integrity_check;" > "$db_dir/integrity_check.txt"
        
    else
        echo "Banco de dados não encontrado" > "$db_dir/database_not_found.txt"
    fi
    
    status "Informações do banco coletadas"
}

# Coletar informações de rede
collect_network_info() {
    echo -e "${CYAN}🌐 Coletando informações de rede...${NC}"
    
    local net_dir="$SUPPORT_PATH/network"
    
    # Configuração de rede
    ip route show > "$net_dir/routes.txt"
    cat /etc/resolv.conf > "$net_dir/dns_config.txt"
    
    # Conectividade
    ping -c 3 8.8.8.8 > "$net_dir/ping_external.txt" 2>&1
    ping -c 3 localhost > "$net_dir/ping_localhost.txt" 2>&1
    
    # Portas dos serviços
    local ports=(3000 9090 1883 8080)
    for port in "${ports[@]}"; do
        nc -zv localhost $port > "$net_dir/port_${port}_test.txt" 2>&1
    done
    
    # Teste de conectividade dos serviços
    curl -s -o /dev/null -w "HTTP: %{http_code}, Time: %{time_total}s\n" \
         http://localhost:3000/api/health > "$net_dir/grafana_health.txt" 2>&1
    
    curl -s -o /dev/null -w "HTTP: %{http_code}, Time: %{time_total}s\n" \
         http://localhost:9090/-/healthy > "$net_dir/prometheus_health.txt" 2>&1
    
    curl -s -o /dev/null -w "HTTP: %{http_code}, Time: %{time_total}s\n" \
         http://localhost:8080/health > "$net_dir/backend_health.txt" 2>&1
    
    # Firewall
    if command -v ufw &> /dev/null; then
        ufw status verbose > "$net_dir/firewall_ufw.txt" 2>/dev/null
    fi
    
    if command -v iptables &> /dev/null; then
        iptables -L > "$net_dir/firewall_iptables.txt" 2>/dev/null
    fi
    
    status "Informações de rede coletadas"
}

# Coletar status dos sensores
collect_sensor_status() {
    echo -e "${CYAN}🌡️ Coletando status dos sensores...${NC}"
    
    local sensor_dir="$SUPPORT_PATH/sensors"
    
    # Status via API
    if curl -s http://localhost:8080/health &> /dev/null; then
        curl -s http://localhost:8080/sensors > "$sensor_dir/sensors_status.json" 2>/dev/null
        curl -s http://localhost:8080/sensors/a/last > "$sensor_dir/sensor_a_last.json" 2>/dev/null
        curl -s http://localhost:8080/sensors/b/last > "$sensor_dir/sensor_b_last.json" 2>/dev/null
        
        # Histórico recente
        curl -s "http://localhost:8080/sensors/readings?hours=24" > "$sensor_dir/readings_24h.json" 2>/dev/null
    else
        echo "Backend não acessível" > "$sensor_dir/backend_not_accessible.txt"
    fi
    
    # Logs MQTT se disponível
    if docker ps --format "table {{.Names}}" | grep -q "mqtt"; then
        docker logs --tail 50 mqtt > "$sensor_dir/mqtt_logs.txt" 2>&1
    fi
    
    status "Status dos sensores coletado"
}

# Executar diagnósticos
run_diagnostics() {
    echo -e "${CYAN}🔍 Executando diagnósticos...${NC}"
    
    local diag_dir="$SUPPORT_PATH/diagnostics"
    mkdir -p "$diag_dir"
    
    # Executar verificação do sistema
    if [ -f "$SCRIPT_DIR/verificar_sistema.sh" ]; then
        "$SCRIPT_DIR/verificar_sistema.sh" > "$diag_dir/system_check.txt" 2>&1
    fi
    
    # Executar diagnóstico
    if [ -f "$SCRIPT_DIR/diagnostico.sh" ]; then
        "$SCRIPT_DIR/diagnostico.sh" > "$diag_dir/diagnostic_report.txt" 2>&1
    fi
    
    # Health check
    if [ -f "$SCRIPT_DIR/health_check.sh" ]; then
        "$SCRIPT_DIR/health_check.sh" --verbose > "$diag_dir/health_check.txt" 2>&1
    fi
    
    status "Diagnósticos executados"
}

# Criar resumo
create_summary() {
    echo -e "${CYAN}📄 Criando resumo...${NC}"
    
    cat > "$SUPPORT_PATH/RESUMO.md" << EOF
# Resumo do Pacote de Suporte - IF-UFG

## Informações Básicas
- **Data**: $(date '+%d/%m/%Y %H:%M:%S')
- **Servidor**: $(hostname)
- **Sistema**: $(uname -s) $(uname -r)
- **Usuário**: $(whoami)

## Conteúdo do Pacote

### 📁 system/
Informações completas do sistema operacional:
- Configuração de hardware
- Processos em execução
- Uso de recursos
- Configuração de rede
- Logs do sistema

### 📁 docker/
Informações do ambiente Docker:
- Status dos containers
- Logs dos serviços principais
- Configuração do Docker Compose
- Uso de recursos dos containers

### 📁 logs/
Logs relevantes para diagnóstico:
- Logs da aplicação
- Alertas recentes
- Métricas de performance
- Relatórios de análise

### 📁 config/
Arquivos de configuração (dados sensíveis removidos):
- Configuração do sistema
- Configuração dos serviços
- Configuração do Grafana

### 📁 database/
Informações do banco de dados:
- Schema e estrutura
- Estatísticas das tabelas
- Verificação de integridade
- Resumo dos dados

### 📁 network/
Informações de conectividade:
- Configuração de rede
- Teste de portas
- Status dos serviços
- Configuração de firewall

### 📁 sensors/
Status dos sensores ESP32:
- Dados dos sensores
- Status de conectividade
- Histórico recente
- Logs MQTT

### 📁 diagnostics/
Relatórios de diagnóstico:
- Verificação completa do sistema
- Diagnóstico automático
- Health check detalhado

## Como Usar Este Pacote

1. **Análise Inicial**: Comece lendo este resumo e o arquivo package_info.txt
2. **Problemas Específicos**: Consulte a pasta correspondente ao componente
3. **Diagnóstico**: Verifique os relatórios na pasta diagnostics/
4. **Logs**: Analise os logs na pasta logs/ para identificar erros

## Informações de Contato

- **Sistema**: Sistema de Monitoramento IF-UFG v2.0
- **Documentação**: Consulte docs/README.md no projeto
- **Suporte**: Equipe técnica IF-UFG

---
*Pacote gerado automaticamente em $(date '+%d/%m/%Y %H:%M:%S')*
EOF
    
    status "Resumo criado"
}

# Compactar pacote
compress_package() {
    echo -e "${CYAN}📦 Compactando pacote...${NC}"
    
    cd "$SUPPORT_DIR"
    tar -czf "${SUPPORT_PACKAGE}.tar.gz" "$SUPPORT_PACKAGE"
    
    if [ $? -eq 0 ]; then
        local package_size=$(du -sh "${SUPPORT_PACKAGE}.tar.gz" | cut -f1)
        rm -rf "$SUPPORT_PACKAGE"
        
        echo -e "${GREEN}📦 Pacote criado: ${SUPPORT_DIR}/${SUPPORT_PACKAGE}.tar.gz${NC}"
        echo -e "${GREEN}📊 Tamanho: $package_size${NC}"
        
        # Criar arquivo de instruções
        cat > "${SUPPORT_DIR}/INSTRUCOES_${DATE}.txt" << EOF
INSTRUÇÕES PARA USO DO PACOTE DE SUPORTE
========================================

Arquivo: ${SUPPORT_PACKAGE}.tar.gz
Tamanho: $package_size
Data: $(date '+%d/%m/%Y %H:%M:%S')

Para extrair:
tar -xzf ${SUPPORT_PACKAGE}.tar.gz

O pacote contém informações completas do sistema IF-UFG
para análise de suporte técnico.

Consulte o arquivo RESUMO.md dentro do pacote para
informações detalhadas sobre o conteúdo.

IMPORTANTE: Este pacote foi criado removendo dados
sensíveis como senhas e tokens, mas ainda pode conter
informações confidenciais. Compartilhe apenas com a
equipe de suporte autorizada.
EOF
        
        status "Pacote compactado com sucesso"
        return 0
    else
        echo -e "${RED}❌ Erro ao compactar pacote${NC}"
        return 1
    fi
}

# Limpeza de pacotes antigos
cleanup_old_packages() {
    echo -e "${CYAN}🧹 Limpando pacotes antigos...${NC}"
    
    # Manter apenas os últimos 5 pacotes
    cd "$SUPPORT_DIR"
    ls -t support_package_*.tar.gz 2>/dev/null | tail -n +6 | xargs -r rm
    ls -t INSTRUCOES_*.txt 2>/dev/null | tail -n +6 | xargs -r rm
    
    local remaining=$(ls -1 support_package_*.tar.gz 2>/dev/null | wc -l)
    status "Pacotes mantidos: $remaining"
}

# Função principal
main() {
    print_banner
    
    echo -e "${BLUE}📅 $(date '+%d/%m/%Y %H:%M:%S')${NC}"
    echo -e "${BLUE}🖥️ $(hostname)${NC}"
    echo ""
    
    # Criar diretório de suporte
    mkdir -p "$SUPPORT_DIR"
    
    # Executar coleta
    create_package_structure
    collect_system_info
    collect_docker_info
    collect_logs
    collect_configs
    collect_database_info
    collect_network_info
    collect_sensor_status
    run_diagnostics
    create_summary
    
    # Finalizar
    if compress_package; then
        cleanup_old_packages
        
        echo ""
        echo -e "${PURPLE}================================${NC}"
        echo -e "${PURPLE}📋 COLETA CONCLUÍDA${NC}"
        echo -e "${PURPLE}================================${NC}"
        echo ""
        echo -e "${GREEN}✅ Pacote de suporte criado com sucesso!${NC}"
        echo ""
        echo -e "${CYAN}📦 Arquivo: ${SUPPORT_DIR}/${SUPPORT_PACKAGE}.tar.gz${NC}"
        echo -e "${CYAN}📄 Instruções: ${SUPPORT_DIR}/INSTRUCOES_${DATE}.txt${NC}"
        echo ""
        echo -e "${YELLOW}💡 Próximos passos:${NC}"
        echo -e "${YELLOW}  1. Envie o arquivo .tar.gz para a equipe de suporte${NC}"
        echo -e "${YELLOW}  2. Inclua as instruções e uma descrição do problema${NC}"
        echo -e "${YELLOW}  3. Mantenha uma cópia local se necessário${NC}"
        echo ""
    else
        echo -e "${RED}❌ Erro ao criar pacote de suporte${NC}"
        exit 1
    fi
}

# Executar apenas se chamado diretamente
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    main "$@"
fi 