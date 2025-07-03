#!/bin/bash

# ============================================================================
# SCRIPT DE INICIALIZAÇÃO
# Monitoramento Inteligente de Clusters - IF-UFG
# ============================================================================

set -e

# ============================================================================
# CONFIGURAÇÕES
# ============================================================================
PROJECT_NAME="cluster-monitoring"
COMPOSE_FILE="backend/docker-compose.yaml"
LOG_FILE="logs/startup.log"

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
# FUNÇÕES DE VERIFICAÇÃO
# ============================================================================
check_docker() {
    if ! command -v docker &> /dev/null; then
        log_error "Docker não está instalado. Instale o Docker primeiro."
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        log_error "Docker não está rodando. Inicie o Docker primeiro."
        exit 1
    fi
    
    log_success "Docker verificado com sucesso"
}

check_docker_compose() {
    if ! docker compose version &> /dev/null; then
        log_error "Docker Compose não está disponível. Verifique se o Docker está atualizado."
        exit 1
    fi
    
    log_success "Docker Compose verificado com sucesso"
}

check_ports() {
    local ports=("1883" "3000" "9090" "8000" "9100" "8080" "80" "443")
    
    for port in "${ports[@]}"; do
        if netstat -tuln | grep -q ":$port "; then
            log_warning "Porta $port já está em uso. Verifique se não há outro serviço rodando."
        fi
    done
}

# ============================================================================
# FUNÇÕES DE PREPARAÇÃO
# ============================================================================
create_directories() {
    log_info "Criando diretórios necessários..."
    
    mkdir -p logs
    mkdir -p backend/mosquitto/{config,data,logs}
    mkdir -p backend/prometheus/{data,rules}
    mkdir -p backend/grafana/{data,provisioning,dashboards}
    mkdir -p backend/alerting/{data,logs}
    mkdir -p backend/exporter/data
    mkdir -p backend/nginx/ssl
    
    log_success "Diretórios criados com sucesso"
}

setup_mosquitto_config() {
    log_info "Configurando Mosquitto..."
    
    cat > backend/mosquitto/config/mosquitto.conf << EOF
# ============================================================================
# CONFIGURAÇÃO MOSQUITTO
# Monitoramento Inteligente de Clusters - IF-UFG
# ============================================================================

# Configurações básicas
listener 1883
allow_anonymous true
persistence true
persistence_location /mosquitto/data/
log_dest file /mosquitto/log/mosquitto.log
log_type all
log_timestamp true

# Configurações de performance
max_inflight_messages 20
max_queued_messages 100

# Configurações de segurança (opcional)
# password_file /mosquitto/config/password_file
# acl_file /mosquitto/config/acl_file

# Configurações de rede
max_connections -1
EOF

    log_success "Configuração do Mosquitto criada"
}

setup_prometheus_rules() {
    log_info "Configurando regras do Prometheus..."
    
    cat > backend/prometheus/rules/cluster_alerts.yml << EOF
# ============================================================================
# REGRAS DE ALERTA - PROMETHEUS
# Monitoramento Inteligente de Clusters - IF-UFG
# ============================================================================

groups:
  - name: cluster_alerts
    rules:
      # Alerta de temperatura alta
      - alert: HighTemperature
        expr: cluster_temperature_celsius > 27
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: "Temperatura alta detectada"
          description: "Sensor {{ \$labels.esp_id }} está com temperatura {{ \$value }}°C"

      # Alerta de temperatura crítica
      - alert: CriticalTemperature
        expr: cluster_temperature_celsius > 35
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Temperatura crítica detectada"
          description: "Sensor {{ \$labels.esp_id }} está com temperatura crítica {{ \$value }}°C"

      # Alerta de sensor offline
      - alert: SensorOffline
        expr: cluster_sensor_status == 0
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Sensor offline"
          description: "Sensor {{ \$labels.esp_id }} está offline há mais de 5 minutos"

      # Alerta de variação brusca de temperatura
      - alert: TemperatureVariation
        expr: cluster_temperature_variation_celsius > 5
        for: 1m
        labels:
          severity: warning
        annotations:
          summary: "Variação brusca de temperatura"
          description: "Sensor {{ \$labels.esp_id }} teve variação de {{ \$value }}°C"
EOF

    log_success "Regras do Prometheus criadas"
}

# ============================================================================
# FUNÇÕES DE CONTROLE
# ============================================================================
start_services() {
    log_info "Iniciando serviços..."
    
    cd backend
    
    # Para serviços existentes
    docker compose down 2>/dev/null || true
    
    # Inicia serviços
    docker compose up -d
    
    cd ..
    
    log_success "Serviços iniciados com sucesso"
}

wait_for_services() {
    log_info "Aguardando serviços ficarem prontos..."
    
    local services=("mosquitto" "prometheus" "grafana" "mqtt-exporter" "alerting")
    local max_attempts=30
    
    for service in "${services[@]}"; do
        log_info "Aguardando $service..."
        
        for i in $(seq 1 $max_attempts); do
            if docker compose -f backend/docker-compose.yaml ps $service | grep -q "Up"; then
                log_success "$service está pronto"
                break
            fi
            
            if [ $i -eq $max_attempts ]; then
                log_error "$service não ficou pronto em $max_attempts tentativas"
                return 1
            fi
            
            sleep 2
        done
    done
}

show_status() {
    log_info "Status dos serviços:"
    docker compose -f backend/docker-compose.yaml ps
    
    echo ""
    log_info "URLs de acesso:"
    echo "  - Grafana: http://localhost:3000 (admin/senha)"
    echo "  - Prometheus: http://localhost:9090"
    echo "  - MQTT Exporter: http://localhost:8000"
    echo "  - cAdvisor: http://localhost:8080"
    echo "  - Node Exporter: http://localhost:9100/metrics"
}

# ============================================================================
# FUNÇÃO PRINCIPAL
# ============================================================================
main() {
    echo "============================================================================"
    echo "  MONITORAMENTO INTELIGENTE DE CLUSTERS - IF-UFG"
    echo "  Script de Inicialização"
    echo "============================================================================"
    echo ""
    
    # Verificações
    check_docker
    check_docker_compose
    check_ports
    
    # Preparação
    create_directories
    setup_mosquitto_config
    setup_prometheus_rules
    
    # Inicialização
    start_services
    wait_for_services
    
    # Status final
    show_status
    
    echo ""
    log_success "Sistema iniciado com sucesso!"
    echo ""
    echo "Para parar o sistema, execute: ./stop.sh"
    echo "Para ver logs, execute: ./logs.sh"
}

# ============================================================================
# EXECUÇÃO
# ============================================================================
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 