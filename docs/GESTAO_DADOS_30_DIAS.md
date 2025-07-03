# 📊 Gestão de Dados - 30 Dias de Monitoramento

## Sistema de Monitoramento Inteligente de Clusters - IF-UFG

---

## 📂 **1. ONDE os dados ficam armazenados**

### 🎯 **Localização dos Arquivos:**

```
cluster-monitoring/
├── backend/
│   ├── prometheus/data/          # 📈 Dados históricos (30 dias)
│   ├── alerting/data/alerts.db   # 🚨 Alertas e estados atuais  
│   └── grafana/data/             # 📊 Dashboards e configurações
```

### 📍 **Caminhos Completos:**
- **Prometheus**: `backend/prometheus/data/` (~133MB após algumas horas)
- **SQLite**: `backend/alerting/data/alerts.db` (~40KB)
- **Grafana**: `backend/grafana/data/` (~1.4MB)

---

## 📊 **2. QUE TIPO de dados são armazenados**

### 📈 **Prometheus (Dados Históricos - 30 dias):**
```
Métricas dos Sensores:
- cluster_temperature_celsius{esp_id="a/b"}     # Temperatura
- cluster_humidity_percent{esp_id="a/b"}        # Umidade  
- cluster_sensor_status{esp_id="a/b"}           # Status online/offline
- cluster_sensor_uptime_seconds{esp_id="a/b"}   # Tempo de funcionamento
- cluster_temperature_variation_celsius         # Variações
```

**Retenção:** 30 dias (configurado com `--storage.tsdb.retention.time=30d`)

### 🗃️ **SQLite (Estados e Alertas):**
```sql
-- Tabela: sensor_states (estado atual)
esp_id | temperature | humidity | status | last_seen | updated_at

-- Tabela: alerts (histórico de alertas)  
id | esp_id | alert_type | severity | message | timestamp | data
```

**Conteúdo:**
- Estado atual de cada sensor
- Histórico completo de alertas enviados
- Dados de recuperação após reinicialização

### 🎨 **Grafana (Visualização):**
- Dashboards personalizados
- Configurações de painéis
- Histórico de consultas

---

## 🔍 **3. COMO acessar os dados**

### 📊 **Acesso via SQLite (dados atuais):**
```bash
# Estado atual dos sensores
docker exec cluster-alerting sqlite3 /app/data/alerts.db \
  "SELECT esp_id, temperature, humidity, status, datetime(last_seen) FROM sensor_states;"

# Últimos alertas
docker exec cluster-alerting sqlite3 /app/data/alerts.db \
  "SELECT datetime(timestamp), esp_id, alert_type FROM alerts ORDER BY timestamp DESC LIMIT 10;"
```

### 📈 **Acesso via Prometheus (dados históricos):**
```bash
# Temperatura atual
curl -s "http://localhost:9090/api/v1/query?query=cluster_temperature_celsius" | jq '.'

# Histórico (últimas 24h)
curl -s "http://localhost:9090/api/v1/query_range?query=cluster_temperature_celsius&start=$(date -d '24 hours ago' +%s)&end=$(date +%s)&step=3600"
```

### 🎨 **Acesso via Grafana (interface visual):**
- URL: http://localhost:3000
- Login: `` / ``
- Dashboards pré-configurados com gráficos históricos

---

## 🗂️ **4. BACKUP e RESTAURAÇÃO**

### 📦 **Fazer Backup Completo:**
```bash
./backup_dados.sh
```
**O que é salvo:**
- ✅ Todos os dados históricos do Prometheus (30 dias)
- ✅ Banco SQLite com alertas e estados
- ✅ Dashboards do Grafana  
- ✅ Arquivo texto legível com resumo dos dados

**Saída:**
```
backups/20250703_140530/
├── prometheus_data.tar.gz    # Dados históricos
├── alerts.db                 # Estados e alertas
├── grafana_data.tar.gz      # Dashboards
└── dados_legivel.txt        # Resumo em texto
```

### 🔄 **Restaurar Backup:**
```bash
./restaurar_dados.sh backups/20250703_140530
```

### 🗑️ **Limpar e Reiniciar:**
```bash
./limpar_reiniciar.sh
```
**O que é removido:**
- 🗑️ Todos os dados históricos do Prometheus
- 🗑️ Banco SQLite (alertas e estados zerados)
- 🗑️ Cache Docker
- ⚠️ Dashboards Grafana (opcional)

---

## 📊 **5. ESTIMATIVAS de Armazenamento**

| **Período** | **Espaço Estimado** | **Observações** |
|---|---|---|
| **1 dia** | ~20-30 MB | Coleta a cada 10-15s |
| **1 semana** | ~150-200 MB | 7 dias de dados |
| **30 dias** | **2-3 GB** | **Configuração atual** |
| **90 dias** | ~6-9 GB | Requer alteração de config |
| **1 ano** | ~24-36 GB | Para análises anuais |

**Dados atuais:** 133MB após algumas horas = muito eficiente! 📈

---

## ⚙️ **6. CONFIGURAÇÃO de Retenção**

### 📝 **Atual (30 dias):**
```yaml
# docker-compose.yaml - linha 69
command:
  - '--storage.tsdb.retention.time=30d'
```

### 🔧 **Para alterar retenção:**
1. Editar `backend/docker-compose.yaml`
2. Alterar `30d` para `90d` (3 meses) ou `365d` (1 ano)
3. Reiniciar: `./stop.sh && ./start.sh`

---

## 🎯 **7. CICLO RECOMENDADO (30 dias)**

### 📅 **Rotina Sugerida:**
```bash
# A cada 30 dias:
1. ./backup_dados.sh              # Backup dos dados
2. ./limpar_reiniciar.sh           # Limpar e reiniciar
3. # Sistema pronto para próximos 30 dias
```

### 🗂️ **Organização de Backups:**
```
backups/
├── 2025-01-03_140530/   # Janeiro
├── 2025-02-03_140530/   # Fevereiro  
├── 2025-03-03_140530/   # Março
└── ...
```

---

## 💡 **8. VANTAGENS do Sistema Atual**

✅ **Dados completos por 30 dias**
✅ **Backup automático e fácil**  
✅ **Limpeza segura com confirmação**
✅ **Restauração completa de qualquer backup**
✅ **Formato legível para análises**
✅ **Ocupação de espaço eficiente**
✅ **Acesso via SQL, API e interface visual**

---

## 🚀 **Scripts Disponíveis**

| **Script** | **Função** | **Uso** |
|---|---|---|
| `backup_dados.sh` | Backup completo | `./backup_dados.sh` |
| `limpar_reiniciar.sh` | Limpeza e restart | `./limpar_reiniciar.sh` |
| `restaurar_dados.sh` | Restauração | `./restaurar_dados.sh <backup>` |

---

**Versão:** 1.0  
**Data:** 2025-01-03  
**Autor:** Sistema de Monitoramento IF-UFG 