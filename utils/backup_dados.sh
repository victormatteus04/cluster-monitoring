#!/bin/bash
# ============================================================================
# BACKUP DOS DADOS DE 30 DIAS
# Sistema de Monitoramento Inteligente de Clusters - IF-UFG
# ============================================================================

# Configurações
BACKUP_DIR="backups/$(date +%Y%m%d_%H%M%S)"
TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")

echo "📦 BACKUP DOS DADOS DE MONITORAMENTO"
echo "============================================"
echo "Timestamp: $TIMESTAMP"
echo "Diretório: $BACKUP_DIR"
echo ""

# Criar diretório de backup
mkdir -p "$BACKUP_DIR"

echo "1️⃣ Fazendo backup do Prometheus (dados históricos)..."
# Para dados históricos completos (30 dias)
sudo tar -czf "$BACKUP_DIR/prometheus_data.tar.gz" -C backend/prometheus data/
echo "   ✅ Backup Prometheus: $(du -h "$BACKUP_DIR/prometheus_data.tar.gz" | cut -f1)"

echo ""
echo "2️⃣ Fazendo backup do SQLite (alertas e estados)..."
# Copia banco de dados SQLite
cp backend/alerting/data/alerts.db "$BACKUP_DIR/alerts.db"
echo "   ✅ Backup SQLite: $(du -h "$BACKUP_DIR/alerts.db" | cut -f1)"

echo ""
echo "3️⃣ Fazendo backup do Grafana (dashboards)..."
# Para preservar dashboards personalizados
sudo tar -czf "$BACKUP_DIR/grafana_data.tar.gz" -C backend/grafana data/
echo "   ✅ Backup Grafana: $(du -h "$BACKUP_DIR/grafana_data.tar.gz" | cut -f1)"

echo ""
echo "4️⃣ Exportando dados em formato legível..."

# Exporta dados do SQLite para texto
echo "-- DADOS DOS SENSORES --" > "$BACKUP_DIR/dados_legivel.txt"
echo "Backup criado em: $TIMESTAMP" >> "$BACKUP_DIR/dados_legivel.txt"
echo "" >> "$BACKUP_DIR/dados_legivel.txt"

echo "ESTADOS ATUAIS DOS SENSORES:" >> "$BACKUP_DIR/dados_legivel.txt"
docker exec cluster-alerting sqlite3 /app/data/alerts.db \
    "SELECT 'Sensor: ' || esp_id || ' | Temp: ' || temperature || '°C | Umidade: ' || humidity || '% | Status: ' || status || ' | Última vez visto: ' || datetime(last_seen) FROM sensor_states;" >> "$BACKUP_DIR/dados_legivel.txt"

echo "" >> "$BACKUP_DIR/dados_legivel.txt"
echo "HISTÓRICO DE ALERTAS (últimos 50):" >> "$BACKUP_DIR/dados_legivel.txt"
docker exec cluster-alerting sqlite3 /app/data/alerts.db \
    "SELECT datetime(timestamp) || ' | ' || esp_id || ' | ' || alert_type || ' | ' || severity || ' | ' || message FROM alerts ORDER BY timestamp DESC LIMIT 50;" >> "$BACKUP_DIR/dados_legivel.txt"

echo "   ✅ Dados legíveis: $(du -h "$BACKUP_DIR/dados_legivel.txt" | cut -f1)"

echo ""
echo "5️⃣ Resumo do backup:"
echo "   📁 Localização: $BACKUP_DIR"
echo "   📊 Total: $(du -sh "$BACKUP_DIR" | cut -f1)"
echo "   📋 Arquivos:"
ls -lah "$BACKUP_DIR/"

echo ""
echo "✅ BACKUP CONCLUÍDO COM SUCESSO!"
echo ""
echo "📋 Para restaurar os dados:"
echo "   ./restaurar_dados.sh $BACKUP_DIR" 