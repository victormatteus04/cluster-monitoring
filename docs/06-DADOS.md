# 🗄️ Módulo 6: Gestão de Dados

## 📋 Visão Geral

Este módulo aborda o gerenciamento completo dos dados do sistema de monitoramento IF-UFG, incluindo bancos de dados, backup, restore, retenção e otimização de performance.

## 🗃️ Estrutura dos Dados

### **Bancos de Dados Utilizados**

| **Sistema** | **Tipo** | **Localização** | **Função** |
|-------------|----------|-----------------|------------|
| **SQLite** | Relacional | `/backend/alerting/data/alerts.db` | Alertas e sensores |
| **Prometheus** | Time Series | `/backend/prometheus/data/` | Métricas e histórico |
| **Grafana** | SQLite | `/backend/grafana/data/grafana.db` | Dashboards e usuários |

### **Esquema do Banco SQLite (Alertas)**

```sql
-- Tabela de alertas
CREATE TABLE alerts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    sensor_id TEXT NOT NULL,
    alert_type TEXT NOT NULL,
    alert_level TEXT NOT NULL,
    description TEXT,
    value REAL,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    email_sent BOOLEAN DEFAULT FALSE,
    resolved BOOLEAN DEFAULT FALSE,
    INDEX(sensor_id),
    INDEX(timestamp),
    INDEX(alert_level)
);

-- Tabela de dados dos sensores
CREATE TABLE sensor_data (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    sensor_id TEXT NOT NULL,
    temperature REAL,
    humidity REAL,
    wifi_rssi INTEGER,
    uptime INTEGER,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    INDEX(sensor_id),
    INDEX(timestamp)
);

-- Tabela de configurações do sistema
CREATE TABLE system_config (
    key TEXT PRIMARY KEY,
    value TEXT,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Tabela de estatísticas
CREATE TABLE statistics (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    metric_name TEXT NOT NULL,
    metric_value REAL,
    sensor_id TEXT,
    period TEXT, -- hourly, daily, weekly
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    INDEX(metric_name),
    INDEX(timestamp)
);
```

## 💾 Backup e Restore

### **Script de Backup Completo**

```bash
#!/bin/bash
# utils/backup_completo.sh

BACKUP_DIR="/opt/cluster-monitoring/backups"
DATE=$(date '+%Y%m%d_%H%M%S')
BACKUP_PATH="$BACKUP_DIR/backup_$DATE"

echo "🔄 Iniciando backup completo do sistema..."
echo "Timestamp: $(date)"
echo "Destino: $BACKUP_PATH"

# Criar diretório de backup
mkdir -p "$BACKUP_PATH"

# 1. Backup do banco SQLite (alertas)
echo "📊 Backup do banco de alertas..."
sqlite3 /opt/cluster-monitoring/backend/alerting/data/alerts.db ".backup '$BACKUP_PATH/alerts.db'"

# 2. Backup do Prometheus
echo "📈 Backup dos dados Prometheus..."
tar -czf "$BACKUP_PATH/prometheus_data.tar.gz" \
    -C /opt/cluster-monitoring/backend/prometheus/data .

# 3. Backup do Grafana
echo "📊 Backup do Grafana..."
tar -czf "$BACKUP_PATH/grafana_data.tar.gz" \
    -C /opt/cluster-monitoring/backend/grafana/data .

# 4. Backup das configurações
echo "⚙️ Backup das configurações..."
tar -czf "$BACKUP_PATH/configs.tar.gz" \
    backend/alerting/config.py \
    backend/prometheus/prometheus.yml \
    backend/grafana/config/grafana.ini \
    backend/docker-compose.yaml

# 5. Backup dos logs
echo "📝 Backup dos logs..."
tar -czf "$BACKUP_PATH/logs.tar.gz" \
    -C /opt/cluster-monitoring/logs .

# 6. Backup dos scripts
echo "🔧 Backup dos scripts..."
tar -czf "$BACKUP_PATH/scripts.tar.gz" \
    *.sh utils/*.sh

# 7. Criar manifesto do backup
cat > "$BACKUP_PATH/manifest.txt" << EOF
Backup do Sistema de Monitoramento IF-UFG
=========================================
Data: $(date)
Versão: 2.0.0
Hostname: $(hostname)
Usuario: $(whoami)

Conteúdo:
- alerts.db: Banco de alertas e dados dos sensores
- prometheus_data.tar.gz: Dados históricos Prometheus
- grafana_data.tar.gz: Dashboards e configurações Grafana
- configs.tar.gz: Arquivos de configuração
- logs.tar.gz: Logs do sistema
- scripts.tar.gz: Scripts e utilitários

Tamanhos:
$(du -sh "$BACKUP_PATH"/* | sed 's|'$BACKUP_PATH'/||')

Total: $(du -sh "$BACKUP_PATH" | cut -f1)
EOF

echo "✅ Backup completo criado em: $BACKUP_PATH"
echo "📊 Tamanho total: $(du -sh "$BACKUP_PATH" | cut -f1)"

# Limpeza de backups antigos (manter últimos 10)
echo "🧹 Limpando backups antigos..."
cd "$BACKUP_DIR"
ls -1d backup_* | head -n -10 | xargs -r rm -rf

echo "✅ Backup concluído com sucesso!"
```

### **Script de Restore**

```bash
#!/bin/bash
# utils/restaurar_backup.sh

if [ $# -ne 1 ]; then
    echo "Uso: $0 <diretorio_backup>"
    echo "Exemplo: $0 /opt/cluster-monitoring/backups/backup_20240703_143000"
    exit 1
fi

BACKUP_PATH="$1"

if [ ! -d "$BACKUP_PATH" ]; then
    echo "❌ Diretório de backup não encontrado: $BACKUP_PATH"
    exit 1
fi

echo "🔄 Iniciando restore do sistema..."
echo "Origem: $BACKUP_PATH"
echo "⚠️  AVISO: Este processo irá substituir os dados atuais!"
read -p "Continuar? (s/N): " confirm

if [[ $confirm != [sS] ]]; then
    echo "❌ Restore cancelado pelo usuário"
    exit 1
fi

# Parar sistema
echo "⏸️ Parando sistema..."
cd /opt/cluster-monitoring
./stop.sh

# 1. Restore do banco SQLite
if [ -f "$BACKUP_PATH/alerts.db" ]; then
    echo "📊 Restaurando banco de alertas..."
    cp "$BACKUP_PATH/alerts.db" backend/alerting/data/alerts.db
fi

# 2. Restore do Prometheus
if [ -f "$BACKUP_PATH/prometheus_data.tar.gz" ]; then
    echo "📈 Restaurando dados Prometheus..."
    rm -rf backend/prometheus/data/*
    tar -xzf "$BACKUP_PATH/prometheus_data.tar.gz" \
        -C backend/prometheus/data/
fi

# 3. Restore do Grafana
if [ -f "$BACKUP_PATH/grafana_data.tar.gz" ]; then
    echo "📊 Restaurando dados Grafana..."
    rm -rf backend/grafana/data/*
    tar -xzf "$BACKUP_PATH/grafana_data.tar.gz" \
        -C backend/grafana/data/
fi

# 4. Restore das configurações
if [ -f "$BACKUP_PATH/configs.tar.gz" ]; then
    echo "⚙️ Restaurando configurações..."
    tar -xzf "$BACKUP_PATH/configs.tar.gz"
fi

# 5. Restore dos logs
if [ -f "$BACKUP_PATH/logs.tar.gz" ]; then
    echo "📝 Restaurando logs..."
    rm -rf logs/*
    tar -xzf "$BACKUP_PATH/logs.tar.gz" -C logs/
fi

# Corrigir permissões
echo "🔧 Corrigindo permissões..."
sudo chown -R $USER:$USER /opt/cluster-monitoring
chmod +x *.sh utils/*.sh

# Reiniciar sistema
echo "▶️ Reiniciando sistema..."
./start.sh

echo "✅ Restore concluído com sucesso!"
echo "🔍 Verificando sistema..."
sleep 10
./utils/verificar_sistema.sh
```

## 📈 Gestão de Retenção

### **Configuração de Retenção Prometheus**

```yaml
# backend/prometheus/prometheus.yml

global:
  scrape_interval: 30s
  evaluation_interval: 30s
  external_labels:
    cluster: 'ifufg-monitoring'

# Configuração de retenção
storage:
  tsdb:
    retention.time: 30d      # Manter 30 dias
    retention.size: 10GB     # Máximo 10GB
    wal-compression: true    # Compressão WAL

rule_files:
  - "rules/*.yml"

scrape_configs:
  - job_name: 'cluster-monitoring'
    static_configs:
      - targets: ['exporter:8000']
    scrape_interval: 30s
    metrics_path: /metrics
```

### **Script de Limpeza de Dados**

```bash
#!/bin/bash
# utils/limpar_dados_antigos.sh

echo "🧹 Iniciando limpeza de dados antigos..."

# Configurações
RETENTION_DAYS=30
DB_PATH="/opt/cluster-monitoring/backend/alerting/data/alerts.db"

# 1. Limpar alertas antigos
echo "🗑️ Removendo alertas antigos (>$RETENTION_DAYS dias)..."
sqlite3 "$DB_PATH" "
DELETE FROM alerts 
WHERE timestamp < datetime('now', '-$RETENTION_DAYS days');
"

# 2. Limpar dados de sensores antigos
echo "🗑️ Removendo dados de sensores antigos (>$RETENTION_DAYS dias)..."
sqlite3 "$DB_PATH" "
DELETE FROM sensor_data 
WHERE timestamp < datetime('now', '-$RETENTION_DAYS days');
"

# 3. Limpar estatísticas antigas
echo "🗑️ Removendo estatísticas antigas (>$RETENTION_DAYS dias)..."
sqlite3 "$DB_PATH" "
DELETE FROM statistics 
WHERE timestamp < datetime('now', '-$RETENTION_DAYS days');
"

# 4. Otimizar banco
echo "⚡ Otimizando banco de dados..."
sqlite3 "$DB_PATH" "VACUUM;"
sqlite3 "$DB_PATH" "ANALYZE;"

# 5. Limpar logs antigos
echo "🗑️ Removendo logs antigos..."
find /opt/cluster-monitoring/logs -name "*.log" -mtime +$RETENTION_DAYS -delete
find /opt/cluster-monitoring/logs -name "*.log.*" -mtime +$RETENTION_DAYS -delete

# 6. Limpar backups antigos
echo "🗑️ Removendo backups antigos..."
find /opt/cluster-monitoring/backups -name "backup_*" -mtime +60 -exec rm -rf {} \;

# Estatísticas finais
echo "📊 Estatísticas pós-limpeza:"
echo "- Alertas: $(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM alerts;")"
echo "- Dados sensores: $(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM sensor_data;")"
echo "- Tamanho banco: $(du -h "$DB_PATH" | cut -f1)"
echo "- Espaço em disco: $(df -h /opt/cluster-monitoring | tail -n 1 | awk '{print $4}') livres"

echo "✅ Limpeza concluída!"
```

### **Agendamento Automático (Cron)**

```bash
# Configurar limpeza automática
crontab -e

# Adicionar linhas:
# Backup diário às 2h
0 2 * * * /opt/cluster-monitoring/utils/backup_completo.sh >> /opt/cluster-monitoring/logs/backup.log 2>&1

# Limpeza semanal aos domingos às 3h
0 3 * * 0 /opt/cluster-monitoring/utils/limpar_dados_antigos.sh >> /opt/cluster-monitoring/logs/cleanup.log 2>&1

# Verificação do sistema a cada 6 horas
0 */6 * * * /opt/cluster-monitoring/utils/verificar_sistema.sh >> /opt/cluster-monitoring/logs/health.log 2>&1
```

## 📊 Análise e Relatórios

### **Script de Estatísticas**

```python
#!/usr/bin/env python3
# utils/gerar_relatorio.py

import sqlite3
import json
import matplotlib.pyplot as plt
import pandas as pd
from datetime import datetime, timedelta
import sys

class RelatorioSistema:
    def __init__(self, db_path):
        self.db_path = db_path
        self.conn = sqlite3.connect(db_path)
    
    def obter_estatisticas_gerais(self):
        """Obter estatísticas gerais do sistema"""
        cursor = self.conn.cursor()
        
        # Total de alertas
        cursor.execute("SELECT COUNT(*) FROM alerts")
        total_alertas = cursor.fetchone()[0]
        
        # Alertas por nível
        cursor.execute("""
            SELECT alert_level, COUNT(*) 
            FROM alerts 
            GROUP BY alert_level
        """)
        alertas_por_nivel = dict(cursor.fetchall())
        
        # Alertas nas últimas 24h
        cursor.execute("""
            SELECT COUNT(*) FROM alerts 
            WHERE timestamp > datetime('now', '-24 hours')
        """)
        alertas_24h = cursor.fetchone()[0]
        
        # Sensores ativos
        cursor.execute("""
            SELECT COUNT(DISTINCT sensor_id) FROM sensor_data 
            WHERE timestamp > datetime('now', '-5 minutes')
        """)
        sensores_ativos = cursor.fetchone()[0]
        
        return {
            'total_alertas': total_alertas,
            'alertas_por_nivel': alertas_por_nivel,
            'alertas_24h': alertas_24h,
            'sensores_ativos': sensores_ativos,
            'timestamp': datetime.now().isoformat()
        }
    
    def obter_dados_sensores(self, horas=24):
        """Obter dados dos sensores das últimas N horas"""
        query = """
            SELECT sensor_id, temperature, humidity, wifi_rssi, timestamp
            FROM sensor_data
            WHERE timestamp > datetime('now', '-{} hours')
            ORDER BY timestamp DESC
        """.format(horas)
        
        df = pd.read_sql_query(query, self.conn)
        df['timestamp'] = pd.to_datetime(df['timestamp'])
        
        return df
    
    def gerar_grafico_temperatura(self, output_path='temperatura_relatorio.png'):
        """Gerar gráfico de temperatura"""
        df = self.obter_dados_sensores(24)
        
        if df.empty:
            print("Sem dados para gerar gráfico")
            return
        
        plt.figure(figsize=(12, 6))
        
        for sensor in df['sensor_id'].unique():
            sensor_data = df[df['sensor_id'] == sensor]
            plt.plot(sensor_data['timestamp'], sensor_data['temperature'], 
                    label=f'Sensor {sensor}', linewidth=2)
        
        plt.title('Temperatura por Sensor - Últimas 24 Horas')
        plt.xlabel('Horário')
        plt.ylabel('Temperatura (°C)')
        plt.legend()
        plt.grid(True, alpha=0.3)
        plt.xticks(rotation=45)
        plt.tight_layout()
        plt.savefig(output_path, dpi=150, bbox_inches='tight')
        plt.close()
        
        print(f"Gráfico salvo em: {output_path}")
    
    def gerar_relatorio_html(self, output_path='relatorio.html'):
        """Gerar relatório HTML completo"""
        stats = self.obter_estatisticas_gerais()
        df = self.obter_dados_sensores(24)
        
        html = f"""
        <!DOCTYPE html>
        <html>
        <head>
            <title>Relatório - Sistema IF-UFG</title>
            <style>
                body {{ font-family: Arial, sans-serif; margin: 20px; }}
                .header {{ background-color: #2e7d32; color: white; padding: 20px; text-align: center; }}
                .stats {{ display: flex; justify-content: space-around; margin: 20px 0; }}
                .stat-box {{ background-color: #f5f5f5; padding: 15px; text-align: center; border-radius: 5px; }}
                table {{ width: 100%; border-collapse: collapse; margin: 20px 0; }}
                th, td {{ border: 1px solid #ddd; padding: 8px; text-align: left; }}
                th {{ background-color: #f2f2f2; }}
            </style>
        </head>
        <body>
            <div class="header">
                <h1>Relatório do Sistema de Monitoramento</h1>
                <p>Instituto de Física - UFG</p>
                <p>Gerado em: {stats['timestamp']}</p>
            </div>
            
            <div class="stats">
                <div class="stat-box">
                    <h3>{stats['total_alertas']}</h3>
                    <p>Total de Alertas</p>
                </div>
                <div class="stat-box">
                    <h3>{stats['alertas_24h']}</h3>
                    <p>Alertas (24h)</p>
                </div>
                <div class="stat-box">
                    <h3>{stats['sensores_ativos']}</h3>
                    <p>Sensores Ativos</p>
                </div>
            </div>
            
            <h2>Alertas por Nível</h2>
            <table>
                <tr><th>Nível</th><th>Quantidade</th></tr>
        """
        
        for nivel, count in stats['alertas_por_nivel'].items():
            html += f"<tr><td>{nivel}</td><td>{count}</td></tr>"
        
        html += """
            </table>
            
            <h2>Dados Recentes dos Sensores</h2>
            <table>
                <tr><th>Sensor</th><th>Temperatura</th><th>Umidade</th><th>WiFi RSSI</th><th>Timestamp</th></tr>
        """
        
        for _, row in df.head(20).iterrows():
            html += f"""
                <tr>
                    <td>{row['sensor_id']}</td>
                    <td>{row['temperature']:.1f}°C</td>
                    <td>{row['humidity']:.1f}%</td>
                    <td>{row['wifi_rssi']} dBm</td>
                    <td>{row['timestamp']}</td>
                </tr>
            """
        
        html += """
            </table>
        </body>
        </html>
        """
        
        with open(output_path, 'w', encoding='utf-8') as f:
            f.write(html)
        
        print(f"Relatório HTML salvo em: {output_path}")
    
    def __del__(self):
        if hasattr(self, 'conn'):
            self.conn.close()

def main():
    db_path = "/opt/cluster-monitoring/backend/alerting/data/alerts.db"
    
    if len(sys.argv) > 1:
        db_path = sys.argv[1]
    
    relatorio = RelatorioSistema(db_path)
    
    print("📊 Gerando relatório do sistema...")
    
    # Estatísticas gerais
    stats = relatorio.obter_estatisticas_gerais()
    print(f"📈 Total de alertas: {stats['total_alertas']}")
    print(f"🔔 Alertas 24h: {stats['alertas_24h']}")
    print(f"📡 Sensores ativos: {stats['sensores_ativos']}")
    
    # Gerar gráficos
    relatorio.gerar_grafico_temperatura()
    
    # Gerar relatório HTML
    relatorio.gerar_relatorio_html()
    
    print("✅ Relatório concluído!")

if __name__ == "__main__":
    main()
```

## 🔍 Consultas Úteis

### **Queries SQLite para Análise**

```sql
-- 1. Alertas por sensor nas últimas 24 horas
SELECT sensor_id, alert_type, COUNT(*) as count
FROM alerts 
WHERE timestamp > datetime('now', '-24 hours')
GROUP BY sensor_id, alert_type
ORDER BY count DESC;

-- 2. Média de temperatura por sensor (últimos 7 dias)
SELECT sensor_id, 
       AVG(temperature) as temp_media,
       MIN(temperature) as temp_minima,
       MAX(temperature) as temp_maxima
FROM sensor_data 
WHERE timestamp > datetime('now', '-7 days')
GROUP BY sensor_id;

-- 3. Sensores com maior número de alertas
SELECT sensor_id, COUNT(*) as total_alertas
FROM alerts 
GROUP BY sensor_id 
ORDER BY total_alertas DESC;

-- 4. Histórico de uptime dos sensores
SELECT sensor_id, 
       MAX(uptime) as max_uptime,
       COUNT(*) as readings
FROM sensor_data 
WHERE timestamp > datetime('now', '-24 hours')
GROUP BY sensor_id;

-- 5. Alertas por hora do dia (padrões)
SELECT strftime('%H', timestamp) as hora,
       COUNT(*) as alertas
FROM alerts 
WHERE timestamp > datetime('now', '-7 days')
GROUP BY hora 
ORDER BY hora;

-- 6. Qualidade da rede WiFi por sensor
SELECT sensor_id,
       AVG(wifi_rssi) as rssi_medio,
       MIN(wifi_rssi) as rssi_minimo,
       COUNT(*) as leituras
FROM sensor_data 
WHERE timestamp > datetime('now', '-24 hours')
GROUP BY sensor_id;
```

### **Scripts de Monitoramento**

```bash
#!/bin/bash
# utils/monitorar_performance.sh

echo "=== Monitoramento de Performance ==="
echo "Timestamp: $(date)"

# Tamanho dos bancos
echo "📊 Tamanho dos Bancos:"
echo "SQLite Alertas: $(du -h /opt/cluster-monitoring/backend/alerting/data/alerts.db | cut -f1)"
echo "Prometheus: $(du -sh /opt/cluster-monitoring/backend/prometheus/data | cut -f1)"
echo "Grafana: $(du -h /opt/cluster-monitoring/backend/grafana/data/grafana.db | cut -f1)"

# Número de registros
echo
echo "📈 Número de Registros:"
DB_PATH="/opt/cluster-monitoring/backend/alerting/data/alerts.db"
echo "Alertas: $(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM alerts;")"
echo "Dados Sensores: $(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM sensor_data;")"

# Performance das queries
echo
echo "⚡ Performance de Queries:"
time sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM sensor_data WHERE timestamp > datetime('now', '-24 hours');" > /dev/null

# Espaço em disco
echo
echo "💾 Espaço em Disco:"
df -h /opt/cluster-monitoring | tail -n 1

# Uso de memória dos containers
echo
echo "🐳 Uso de Memória dos Containers:"
docker stats --no-stream --format "table {{.Name}}\t{{.MemUsage}}\t{{.MemPerc}}"
```

## 🔧 Otimização

### **Índices de Performance**

```sql
-- Criar índices para melhorar performance
CREATE INDEX IF NOT EXISTS idx_alerts_sensor_timestamp 
ON alerts(sensor_id, timestamp);

CREATE INDEX IF NOT EXISTS idx_alerts_level 
ON alerts(alert_level);

CREATE INDEX IF NOT EXISTS idx_sensor_data_timestamp 
ON sensor_data(timestamp);

CREATE INDEX IF NOT EXISTS idx_sensor_data_sensor 
ON sensor_data(sensor_id);

-- Analisar estatísticas
ANALYZE;
```

### **Configuração de Memory para SQLite**

```python
# Configurações de performance SQLite
def configurar_sqlite_performance(conn):
    """Configurar SQLite para melhor performance"""
    cursor = conn.cursor()
    
    # Configurações de performance
    cursor.execute("PRAGMA cache_size = 10000")      # 10k páginas em cache
    cursor.execute("PRAGMA temp_store = MEMORY")     # Usar memória para temp
    cursor.execute("PRAGMA journal_mode = WAL")      # Write-Ahead Logging
    cursor.execute("PRAGMA synchronous = NORMAL")    # Sync normal
    cursor.execute("PRAGMA foreign_keys = ON")       # Chaves estrangeiras
    
    conn.commit()
```

## 🛠️ Troubleshooting

### **Problemas Comuns**

| **Problema** | **Sintoma** | **Solução** |
|--------------|-------------|-------------|
| **Banco corrupto** | Erro SQLite | Restore do backup |
| **Espaço insuficiente** | Disco cheio | Limpeza de dados antigos |
| **Performance lenta** | Queries demoradas | Criar índices, otimizar |
| **Backup falhou** | Erro no script | Verificar permissões |
| **Dados inconsistentes** | Valores anômalos | Validação e limpeza |

### **Comandos de Diagnóstico**

```bash
# Verificar integridade do banco
sqlite3 /opt/cluster-monitoring/backend/alerting/data/alerts.db "PRAGMA integrity_check;"

# Verificar estatísticas do banco
sqlite3 /opt/cluster-monitoring/backend/alerting/data/alerts.db "PRAGMA table_info(alerts);"

# Verificar espaço em disco
df -h /opt/cluster-monitoring

# Verificar processos que usam o banco
lsof /opt/cluster-monitoring/backend/alerting/data/alerts.db

# Testar performance de queries
time sqlite3 /opt/cluster-monitoring/backend/alerting/data/alerts.db "SELECT COUNT(*) FROM sensor_data;"
```

## 📋 Checklist de Manutenção

### **Diário**
- [ ] Verificar espaço em disco
- [ ] Verificar integridade dos serviços
- [ ] Monitorar logs de erro

### **Semanal**
- [ ] Executar limpeza de dados antigos
- [ ] Verificar performance das queries
- [ ] Validar backups

### **Mensal**
- [ ] Otimizar bancos (VACUUM/ANALYZE)
- [ ] Gerar relatório de estatísticas
- [ ] Revisar retenção de dados
- [ ] Atualizar documentação

---

**📍 Próximo Módulo**: [7. Troubleshooting](07-TROUBLESHOOTING.md)  
**🏠 Voltar**: [Manual Principal](README.md) 