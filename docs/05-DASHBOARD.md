# 📊 Módulo 5: Dashboard e Grafana

## 📋 Visão Geral

O Grafana é a interface principal de visualização do sistema de monitoramento IF-UFG. Este módulo detalha a configuração, uso e personalização dos dashboards para monitoramento em tempo real.

## 🌐 Acesso ao Dashboard

### **URLs de Acesso**

```
Grafana Dashboard: http://servidor-ifufg:3000
Prometheus Metrics: http://servidor-ifufg:9090
MQTT Exporter API: http://servidor-ifufg:8000
```

### **Credenciais Padrão**

```
Usuário: admin
Senha: admin (altere na primeira conexão)
```

## 🎨 Configuração Inicial do Grafana

### **Primeiro Acesso**

1. **Acessar o Grafana**
   - Navegue para `http://servidor-ifufg:3000`
   - Login: `admin` / `admin`
   - Altere a senha quando solicitado

2. **Configurar Data Source**
   - Vá em Configuration > Data Sources
   - Adicione Prometheus como fonte
   - URL: `http://prometheus:9090`
   - Salve e teste a conexão

### **Configuração de Data Source**

```json
{
  "name": "Prometheus",
  "type": "prometheus",
  "url": "http://prometheus:9090",
  "access": "proxy",
  "basicAuth": false,
  "isDefault": true,
  "jsonData": {
    "httpMethod": "POST",
    "queryTimeout": "60s",
    "timeInterval": "30s"
  }
}
```

## 📈 Dashboard Principal

### **Dashboard de Monitoramento IF-UFG**

```json
{
  "dashboard": {
    "id": null,
    "title": "Sistema de Monitoramento IF-UFG",
    "tags": ["monitoring", "ifufg", "sensors"],
    "timezone": "America/Sao_Paulo",
    "panels": [
      {
        "id": 1,
        "title": "Temperatura por Sensor",
        "type": "graph",
        "targets": [
          {
            "expr": "cluster_temperature",
            "legendFormat": "Sensor {{sensor}}",
            "refId": "A"
          }
        ],
        "yAxes": [
          {
            "min": 10,
            "max": 40,
            "unit": "celsius"
          }
        ],
        "alert": {
          "conditions": [
            {
              "query": {
                "params": ["A", "5m", "now"]
              },
              "reducer": {
                "params": [],
                "type": "last"
              },
              "evaluator": {
                "params": [30],
                "type": "gt"
              }
            }
          ],
          "executionErrorState": "alerting",
          "for": "5m",
          "frequency": "10s",
          "handler": 1,
          "name": "Temperatura Alta",
          "noDataState": "no_data",
          "notifications": []
        }
      },
      {
        "id": 2,
        "title": "Umidade por Sensor",
        "type": "graph",
        "targets": [
          {
            "expr": "cluster_humidity",
            "legendFormat": "Sensor {{sensor}}",
            "refId": "A"
          }
        ],
        "yAxes": [
          {
            "min": 0,
            "max": 100,
            "unit": "percent"
          }
        ]
      },
      {
        "id": 3,
        "title": "Status dos Sensores",
        "type": "stat",
        "targets": [
          {
            "expr": "up{job=\"cluster-monitoring\"}",
            "legendFormat": "Sensor {{sensor}}",
            "refId": "A"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "color": {
              "mode": "thresholds"
            },
            "thresholds": {
              "steps": [
                {
                  "color": "red",
                  "value": 0
                },
                {
                  "color": "green",
                  "value": 1
                }
              ]
            }
          }
        }
      }
    ],
    "time": {
      "from": "now-6h",
      "to": "now"
    },
    "refresh": "30s"
  }
}
```

## 🔧 Configuração Avançada

### **Grafana.ini Personalizado**

```ini
# backend/grafana/config/grafana.ini

[DEFAULT]
# Configurações gerais
instance_name = "IF-UFG Monitoring"
app_mode = production

[server]
# Configurações do servidor
protocol = http
http_port = 3000
domain = monitoring.ifufg.ufg.br
root_url = http://monitoring.ifufg.ufg.br:3000

[database]
# Usar SQLite para simplicidade
type = sqlite3
path = /var/lib/grafana/grafana.db

[security]
# Configurações de segurança
admin_user = admin
admin_password = $__env{GRAFANA_ADMIN_PASSWORD}
secret_key = $__env{GRAFANA_SECRET_KEY}
login_remember_days = 7
cookie_secure = false

[users]
# Configurações de usuários
allow_sign_up = false
allow_org_create = false
default_theme = dark

[auth]
# Configurações de autenticação
disable_login_form = false
disable_signout_menu = false

[auth.anonymous]
# Acesso anônimo (desabilitado)
enabled = false

[alerting]
# Configurações de alertas
enabled = true
execute_alerts = true

[smtp]
# Configurações SMTP para alertas
enabled = true
host = smtp.gmail.com:587
user = sistema@ifufg.ufg.br
password = $__env{SMTP_PASSWORD}
skip_verify = false
from_address = sistema@ifufg.ufg.br
from_name = Sistema IF-UFG

[log]
# Configurações de log
mode = file
level = info
filters = rendering:debug
```

### **Provisioning de Dashboards**

```yaml
# backend/grafana/provisioning/dashboards/dashboard.yaml

apiVersion: 1

providers:
  - name: 'default'
    orgId: 1
    folder: ''
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    allowUiUpdates: true
    options:
      path: /etc/grafana/provisioning/dashboards
```

### **Provisioning de Data Sources**

```yaml
# backend/grafana/provisioning/datasources/datasource.yaml

apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: true
    jsonData:
      httpMethod: POST
      queryTimeout: 60s
      timeInterval: 30s
```

## 📊 Painéis Customizados

### **Painel de Temperatura**

```json
{
  "title": "Temperatura - Sensores IF-UFG",
  "type": "timeseries",
  "targets": [
    {
      "expr": "cluster_temperature",
      "legendFormat": "Sensor {{sensor}} - {{location}}",
      "refId": "A"
    }
  ],
  "fieldConfig": {
    "defaults": {
      "color": {
        "mode": "palette-classic"
      },
      "custom": {
        "axisPlacement": "auto",
        "barAlignment": 0,
        "drawStyle": "line",
        "fillOpacity": 10,
        "gradientMode": "none",
        "hideFrom": {
          "legend": false,
          "tooltip": false,
          "vis": false
        },
        "lineInterpolation": "smooth",
        "lineWidth": 2,
        "pointSize": 5,
        "scaleDistribution": {
          "type": "linear"
        },
        "showPoints": "never",
        "spanNulls": false,
        "stacking": {
          "group": "A",
          "mode": "none"
        },
        "thresholdsStyle": {
          "mode": "line"
        }
      },
      "mappings": [],
      "thresholds": {
        "mode": "absolute",
        "steps": [
          {
            "color": "green",
            "value": null
          },
          {
            "color": "yellow",
            "value": 25
          },
          {
            "color": "red",
            "value": 30
          }
        ]
      },
      "unit": "celsius",
      "min": 10,
      "max": 40
    }
  },
  "options": {
    "legend": {
      "calcs": [],
      "displayMode": "table",
      "placement": "bottom"
    },
    "tooltip": {
      "mode": "single",
      "sort": "none"
    }
  }
}
```

### **Painel de Status dos Sensores**

```json
{
  "title": "Status dos Sensores",
  "type": "stat",
  "targets": [
    {
      "expr": "up{job=\"cluster-monitoring\"}",
      "legendFormat": "{{sensor}}",
      "refId": "A"
    }
  ],
  "fieldConfig": {
    "defaults": {
      "color": {
        "mode": "thresholds"
      },
      "mappings": [
        {
          "options": {
            "0": {
              "color": "red",
              "index": 0,
              "text": "OFFLINE"
            },
            "1": {
              "color": "green",
              "index": 1,
              "text": "ONLINE"
            }
          },
          "type": "value"
        }
      ],
      "thresholds": {
        "mode": "absolute",
        "steps": [
          {
            "color": "red",
            "value": null
          },
          {
            "color": "green",
            "value": 1
          }
        ]
      }
    }
  },
  "options": {
    "colorMode": "background",
    "graphMode": "none",
    "justifyMode": "auto",
    "orientation": "horizontal",
    "reduceOptions": {
      "calcs": [
        "lastNotNull"
      ],
      "fields": "",
      "values": false
    },
    "textMode": "auto"
  }
}
```

### **Painel de Métricas do Sistema**

```json
{
  "title": "Métricas do Sistema",
  "type": "table",
  "targets": [
    {
      "expr": "cluster_temperature",
      "legendFormat": "{{sensor}}",
      "refId": "A"
    },
    {
      "expr": "cluster_humidity",
      "legendFormat": "{{sensor}}",
      "refId": "B"
    },
    {
      "expr": "cluster_wifi_rssi",
      "legendFormat": "{{sensor}}",
      "refId": "C"
    }
  ],
  "transformations": [
    {
      "id": "merge",
      "options": {}
    },
    {
      "id": "organize",
      "options": {
        "excludeByName": {},
        "indexByName": {},
        "renameByName": {
          "Value #A": "Temperatura (°C)",
          "Value #B": "Umidade (%)",
          "Value #C": "WiFi RSSI (dBm)"
        }
      }
    }
  ],
  "fieldConfig": {
    "defaults": {
      "custom": {
        "align": "auto",
        "displayMode": "auto"
      },
      "mappings": [],
      "thresholds": {
        "mode": "absolute",
        "steps": [
          {
            "color": "green",
            "value": null
          }
        ]
      }
    }
  }
}
```

## 🚨 Configuração de Alertas

### **Regras de Alerta no Grafana**

```json
{
  "alert": {
    "name": "Temperatura Alta IF-UFG",
    "message": "Temperatura acima de 30°C detectada no sensor {{sensor}}",
    "frequency": "30s",
    "conditions": [
      {
        "query": {
          "queryType": "",
          "refId": "A"
        },
        "reducer": {
          "type": "last",
          "params": []
        },
        "evaluator": {
          "params": [30],
          "type": "gt"
        }
      }
    ],
    "executionErrorState": "alerting",
    "noDataState": "no_data",
    "for": "5m"
  }
}
```

### **Notification Channels**

```json
{
  "name": "email-ifufg",
  "type": "email",
  "settings": {
    "addresses": "admin@ifufg.ufg.br;tecnico@ifufg.ufg.br",
    "subject": "[IF-UFG] Alerta: {{range .Alerts}}{{.AlertName}}{{end}}",
    "body": "{{range .Alerts}}{{.AlertName}}: {{.Message}}{{end}}"
  }
}
```

## 🔍 Queries Úteis

### **Consultas Prometheus**

```promql
# Temperatura atual de todos os sensores
cluster_temperature

# Temperatura média nas últimas 24 horas
rate(cluster_temperature[24h])

# Sensores offline (sem dados há mais de 5 minutos)
up{job="cluster-monitoring"} == 0

# Variação de temperatura
delta(cluster_temperature[5m])

# Umidade máxima por sensor
max_over_time(cluster_humidity[1h])

# Status da rede WiFi
cluster_wifi_rssi < -80

# Uptime dos sensores
cluster_uptime / 3600

# Dados por localização
cluster_temperature{location="Rack-Principal"}
```

### **Queries para Dashboards**

```json
{
  "queries": [
    {
      "name": "Temperatura Atual",
      "expr": "cluster_temperature",
      "legend": "Sensor {{sensor}} ({{location}})"
    },
    {
      "name": "Umidade Atual",
      "expr": "cluster_humidity",
      "legend": "Sensor {{sensor}} ({{location}})"
    },
    {
      "name": "Status Online",
      "expr": "up{job=\"cluster-monitoring\"}",
      "legend": "{{sensor}}"
    },
    {
      "name": "Força WiFi",
      "expr": "cluster_wifi_rssi",
      "legend": "{{sensor}} RSSI"
    }
  ]
}
```

## 📱 Mobile Dashboard

### **Configuração Mobile**

```json
{
  "dashboard": {
    "title": "IF-UFG Mobile",
    "tags": ["mobile", "ifufg"],
    "panels": [
      {
        "title": "Temperatura",
        "type": "singlestat",
        "targets": [
          {
            "expr": "cluster_temperature",
            "legendFormat": "{{sensor}}"
          }
        ],
        "gridPos": {
          "h": 8,
          "w": 12,
          "x": 0,
          "y": 0
        }
      },
      {
        "title": "Umidade",
        "type": "singlestat",
        "targets": [
          {
            "expr": "cluster_humidity",
            "legendFormat": "{{sensor}}"
          }
        ],
        "gridPos": {
          "h": 8,
          "w": 12,
          "x": 12,
          "y": 0
        }
      }
    ]
  }
}
```

## 🔧 Personalização

### **Temas Personalizados**

```css
/* Custom CSS para IF-UFG */
.navbar-brand-text {
    color: #1f77b4 !important;
}

.panel-title {
    color: #2e7d32 !important;
}

.graph-legend .legend-value {
    font-weight: bold;
}

/* Logo IF-UFG */
.sidemenu__logo {
    background-image: url('/public/img/ifufg-logo.png');
    background-size: contain;
    background-repeat: no-repeat;
}
```

### **Variáveis de Dashboard**

```json
{
  "templating": {
    "list": [
      {
        "name": "sensor",
        "type": "query",
        "query": "label_values(cluster_temperature, sensor)",
        "current": {
          "text": "All",
          "value": "$__all"
        },
        "options": [
          {
            "text": "All",
            "value": "$__all",
            "selected": true
          }
        ],
        "includeAll": true,
        "multi": true
      },
      {
        "name": "location",
        "type": "query",
        "query": "label_values(cluster_temperature, location)",
        "current": {
          "text": "All",
          "value": "$__all"
        }
      }
    ]
  }
}
```

## 📊 Exportação de Dados

### **Export de Dashboard**

```bash
# Exportar dashboard via API
curl -H "Authorization: Bearer API_KEY" \
  http://localhost:3000/api/dashboards/db/sistema-monitoramento-ifufg \
  > dashboard_ifufg.json

# Importar dashboard
curl -X POST -H "Content-Type: application/json" \
  -H "Authorization: Bearer API_KEY" \
  -d @dashboard_ifufg.json \
  http://localhost:3000/api/dashboards/db
```

### **Export de Dados (CSV)**

```bash
# Script para exportar dados
#!/bin/bash
# utils/export_data.sh

PROMETHEUS_URL="http://localhost:9090"
START_TIME=$(date -d "7 days ago" +%s)
END_TIME=$(date +%s)

# Exportar temperatura
curl -G "$PROMETHEUS_URL/api/v1/query_range" \
  --data-urlencode "query=cluster_temperature" \
  --data-urlencode "start=$START_TIME" \
  --data-urlencode "end=$END_TIME" \
  --data-urlencode "step=300" \
  > temperature_data.json

# Converter para CSV
python3 -c "
import json
import csv
import sys

with open('temperature_data.json') as f:
    data = json.load(f)

with open('temperature_data.csv', 'w', newline='') as f:
    writer = csv.writer(f)
    writer.writerow(['timestamp', 'sensor', 'temperature'])
    
    for result in data['data']['result']:
        sensor = result['metric']['sensor']
        for value in result['values']:
            writer.writerow([value[0], sensor, value[1]])

print('Dados exportados para temperature_data.csv')
"
```

## 🔍 Monitoramento via API

### **APIs Grafana**

```bash
# Obter informações do dashboard
curl -H "Authorization: Bearer API_KEY" \
  http://localhost:3000/api/dashboards/db/sistema-monitoramento-ifufg

# Listar alertas
curl -H "Authorization: Bearer API_KEY" \
  http://localhost:3000/api/alerts

# Obter métricas
curl -H "Authorization: Bearer API_KEY" \
  http://localhost:3000/api/admin/stats
```

### **Scripts de Automação**

```python
# utils/grafana_api.py

import requests
import json

class GrafanaAPI:
    def __init__(self, url, api_key):
        self.url = url
        self.headers = {'Authorization': f'Bearer {api_key}'}
    
    def get_dashboard(self, dashboard_id):
        response = requests.get(f'{self.url}/api/dashboards/db/{dashboard_id}', 
                               headers=self.headers)
        return response.json()
    
    def get_alerts(self):
        response = requests.get(f'{self.url}/api/alerts', headers=self.headers)
        return response.json()
    
    def create_snapshot(self, dashboard_id):
        data = {
            'dashboard': self.get_dashboard(dashboard_id),
            'expires': 3600
        }
        response = requests.post(f'{self.url}/api/snapshots', 
                                json=data, headers=self.headers)
        return response.json()

# Uso
api = GrafanaAPI('http://localhost:3000', 'API_KEY')
alerts = api.get_alerts()
print(f"Alertas ativos: {len(alerts)}")
```

## 🛠️ Troubleshooting

### **Problemas Comuns**

| **Problema** | **Sintoma** | **Solução** |
|--------------|-------------|-------------|
| **Dashboard não carrega** | Página em branco | Verificar data source |
| **Gráficos sem dados** | Painéis vazios | Verificar queries Prometheus |
| **Alertas não funcionam** | Sem notificações | Verificar SMTP config |
| **Performance lenta** | Dashboard lento | Otimizar queries |
| **Erro de conexão** | Timeout | Verificar rede/firewall |

### **Comandos de Diagnóstico**

```bash
# Verificar logs Grafana
docker logs grafana

# Testar conexão Prometheus
curl http://localhost:9090/api/v1/query?query=up

# Verificar configuração
curl http://localhost:3000/api/admin/settings

# Testar queries
curl -G http://localhost:9090/api/v1/query \
  --data-urlencode "query=cluster_temperature"
```

## 📋 Checklist de Configuração

### **Configuração Inicial**
- [ ] Grafana acessível via browser
- [ ] Data source Prometheus configurado
- [ ] Dashboard principal criado
- [ ] Variáveis de ambiente configuradas
- [ ] Alertas configurados

### **Dashboards**
- [ ] Painéis de temperatura funcionando
- [ ] Painéis de umidade funcionando
- [ ] Status dos sensores visível
- [ ] Métricas do sistema exibidas
- [ ] Queries otimizadas

### **Personalização**
- [ ] Tema IF-UFG aplicado
- [ ] Variáveis de dashboard configuradas
- [ ] Alertas personalizados
- [ ] Exportação de dados funcionando

---

**📍 Próximo Módulo**: [6. Gestão de Dados](06-DADOS.md)  
**🏠 Voltar**: [Manual Principal](README.md) 