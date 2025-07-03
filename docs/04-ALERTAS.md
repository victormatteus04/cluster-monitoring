# 📧 Módulo 4: Emails, Logs e Alertas

## 📋 Visão Geral

O sistema de alertas do IF-UFG monitora continuamente os sensores e envia notificações por email quando detecta anomalias. Este módulo detalha a configuração, tipos de alertas e gerenciamento de logs.

## 🚨 Tipos de Alertas

### **1. Alertas de Temperatura**
- **Alerta de Calor**: Temperatura > 30°C
- **Alerta de Frio**: Temperatura < 15°C
- **Variação Brusca**: Mudança > 5°C em 5 minutos
- **Temperatura Crítica**: > 30°C ou < 10°C

### **2. Alertas de Umidade**
- **Umidade Alta**: > 80%
- **Umidade Baixa**: < 30%
- **Umidade Crítica**: > 90% ou < 20%

### **3. Alertas de Sistema**
- **Sensor Offline**: Sem dados há mais de 5 minutos
- **Oscilação de Energia**: Sensor reiniciou
- **Falha de Comunicação**: Erro MQTT/WiFi
- **Falha de Hardware**: Leituras inválidas

### **4. Alertas de Rede**
- **Conectividade**: WiFi fraco (RSSI < -80dBm)
- **Latência**: Delays na comunicação
- **Perda de Dados**: Mensagens perdidas

## 📧 Configuração de Email

### **Credenciais para Gmail (IF-UFG)**

```bash
# Configurar variáveis de ambiente
export SMTP_SERVER="smtp.gmail.com"
export SMTP_PORT="587"
export EMAIL_USER="sistema@ifufg.ufg.br"
export EMAIL_PASS="senha-app-especifica"  # App Password do Gmail
export EMAIL_TO="admin@ifufg.ufg.br,tecnico@ifufg.ufg.br"
```

### **Template de Email HTML**

```html
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Alerta - Sistema de Monitoramento IF-UFG</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background-color: #d32f2f; color: white; padding: 20px; text-align: center; }
        .content { padding: 20px; border: 1px solid #ddd; }
        .sensor-info { background-color: #f5f5f5; padding: 15px; margin: 10px 0; }
        .chart { text-align: center; margin: 20px 0; }
        .footer { text-align: center; color: #666; font-size: 12px; margin-top: 20px; }
        .critical { color: #d32f2f; font-weight: bold; }
        .warning { color: #ff9800; font-weight: bold; }
    </style>
</head>
<body>
    <div class="header">
        <h1>🚨 Alerta do Sistema</h1>
        <p>Instituto de Física - UFG</p>
    </div>
    
    <div class="content">
        <h2>{{alert_type}}</h2>
        <p><strong>Sensor:</strong> {{sensor_id}} ({{location}})</p>
        <p><strong>Timestamp:</strong> {{timestamp}}</p>
        <p><strong>Descrição:</strong> {{description}}</p>
        
        <div class="sensor-info">
            <h3>Dados do Sensor</h3>
            <p><strong>Temperatura:</strong> {{temperature}}°C</p>
            <p><strong>Umidade:</strong> {{humidity}}%</p>
            <p><strong>Status:</strong> {{status}}</p>
            <p><strong>Uptime:</strong> {{uptime}}</p>
        </div>
        
        <div class="chart">
            <h3>Gráfico das Últimas Horas</h3>
            <img src="cid:chart_image" alt="Gráfico de Temperatura/Umidade" style="max-width: 100%;">
        </div>
        
        <div class="footer">
            <p>Sistema de Monitoramento IF-UFG | {{current_time}}</p>
            <p>Este é um email automático. Não responda.</p>
        </div>
    </div>
</body>
</html>
```

## 🔧 Configuração de Limites

### **Thresholds de Alertas**

```python
# Configurações de limites
ALERT_THRESHOLDS = {
    'TEMPERATURE_HIGH': {
        'value': 30.0,
        'level': 'WARNING',
        'description': 'Temperatura acima do limite normal'
    },
    'TEMPERATURE_LOW': {
        'value': 15.0,
        'level': 'WARNING',
        'description': 'Temperatura abaixo do limite normal'
    },
    'TEMPERATURE_CRITICAL': {
        'value': 35.0,
        'level': 'CRITICAL',
        'description': 'Temperatura em nível crítico'
    },
    'HUMIDITY_HIGH': {
        'value': 80.0,
        'level': 'WARNING',
        'description': 'Umidade acima do limite normal'
    },
    'HUMIDITY_LOW': {
        'value': 30.0,
        'level': 'WARNING',
        'description': 'Umidade abaixo do limite normal'
    },
    'SENSOR_OFFLINE': {
        'value': 300,  # 5 minutos
        'level': 'CRITICAL',
        'description': 'Sensor não está respondendo'
    }
}
```

## 📝 Sistema de Logs

### **Estrutura de Logs**

```
/opt/cluster-monitoring/logs/
├── system.log          # Logs gerais do sistema
├── alerts.log          # Alertas gerados
├── sensors.log         # Dados dos sensores
├── emails.log          # Envio de emails
├── errors.log          # Erros do sistema
└── critical.log        # Alertas críticos
```

### **Configuração de Log Rotation**

```bash
# Configurar logrotate
sudo tee /etc/logrotate.d/cluster-monitoring << 'EOF'
/opt/cluster-monitoring/logs/*.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    create 644 $USER $USER
    postrotate
        # Reiniciar serviços se necessário
        systemctl reload rsyslog > /dev/null 2>&1 || true
    endscript
}
EOF
```

## 🔍 Monitoramento e Verificação

### **Script de Verificação do Sistema**

```bash
#!/bin/bash
# utils/verificar_sistema.sh

echo "=== Verificação do Sistema de Monitoramento IF-UFG ==="
echo "Timestamp: $(date)"
echo

# Verificar containers
echo "🐳 Status dos Containers:"
docker compose -f backend/docker-compose.yaml ps

echo
echo "📊 Endpoints:"
curl -s -f http://localhost:3000 > /dev/null && echo "✅ Grafana: OK" || echo "❌ Grafana: ERRO"
curl -s -f http://localhost:9090 > /dev/null && echo "✅ Prometheus: OK" || echo "❌ Prometheus: ERRO"
curl -s -f http://localhost:8000/health > /dev/null && echo "✅ Exporter: OK" || echo "❌ Exporter: ERRO"

echo
echo "🔍 Logs Recentes (últimas 10 linhas):"
tail -n 10 /opt/cluster-monitoring/logs/alerts.log

echo
echo "📈 Estatísticas de Alertas:"
sqlite3 /opt/cluster-monitoring/backend/alerting/data/alerts.db \
  "SELECT alert_type, COUNT(*) FROM alerts WHERE timestamp > datetime('now', '-24 hours') GROUP BY alert_type;"

echo
echo "🔌 Sensores Ativos:"
sqlite3 /opt/cluster-monitoring/backend/alerting/data/alerts.db \
  "SELECT sensor_id, MAX(timestamp) as last_seen FROM sensor_data GROUP BY sensor_id;"
```

### **Teste de Alertas**

```bash
#!/bin/bash
# utils/testar_alertas.sh

echo "=== Teste de Alertas ==="

# Teste 1: Sensor válido
echo "📡 Testando sensor válido (a)..."
curl -X POST -H "Content-Type: application/json" \
  -d '{"esp_id": "a", "temperature": 32.0, "humidity": 85.0}' \
  http://localhost:8000/webhook

# Teste 2: Sensor inválido (deve ser rejeitado)
echo "📡 Testando sensor inválido (test)..."
curl -X POST -H "Content-Type: application/json" \
  -d '{"esp_id": "test", "temperature": 25.0, "humidity": 60.0}' \
  http://localhost:8000/webhook

# Teste 3: Temperatura crítica
echo "📡 Testando temperatura crítica..."
curl -X POST -H "Content-Type: application/json" \
  -d '{"esp_id": "b", "temperature": 36.0, "humidity": 60.0}' \
  http://localhost:8000/webhook

echo "✅ Testes concluídos. Verifique logs e emails."
```

## 🎯 Alertas Específicos

### **Detecção de Oscilação de Energia**

```python
def detectar_oscilacao_energia(sensor_data):
    """Detectar possível oscilação de energia"""
    uptime = sensor_data.get('uptime', 0)
    sensor_id = sensor_data.get('esp_id')
    
    # Se uptime for muito baixo, pode indicar reinicialização
    if uptime < 300:  # 5 minutos
        criar_alerta(sensor_id, 'POWER_OUTAGE', uptime)
        log_critico(f"Possível oscilação de energia detectada - Sensor {sensor_id}")
```

### **Verificação de Variação de Temperatura**

```python
def verificar_variacao_temperatura(sensor_data):
    """Verificar variação brusca de temperatura"""
    sensor_id = sensor_data.get('esp_id')
    temp_atual = sensor_data.get('temperature')
    
    # Buscar temperatura anterior
    temp_anterior = obter_temperatura_anterior(sensor_id)
    
    if temp_anterior and temp_atual:
        variacao = abs(temp_atual - temp_anterior)
        
        if variacao > 2.0:  # Variação maior que 2°C
            criar_alerta(sensor_id, 'TEMPERATURE_VARIATION', variacao)
            log_warning(f"Variação brusca detectada - Sensor {sensor_id}: {variacao}°C")
```

## 📊 Dashboard de Alertas

### **Endpoints REST**

```python
# API para dashboard
@app.route('/api/alerts/recent', methods=['GET'])
def alertas_recentes():
    """Obter alertas das últimas 24 horas"""
    return jsonify(obter_alertas_recentes())

@app.route('/api/sensors/status', methods=['GET'])
def status_sensores():
    """Obter status atual dos sensores"""
    return jsonify(obter_status_sensores())

@app.route('/api/alerts/stats', methods=['GET'])
def estatisticas_alertas():
    """Obter estatísticas de alertas"""
    return jsonify(obter_estatisticas())
```

### **Comandos via SSH**

```bash
# Verificar alertas recentes
ssh usuario@servidor "tail -n 20 /opt/cluster-monitoring/logs/alerts.log"

# Obter estatísticas
ssh usuario@servidor "sqlite3 /opt/cluster-monitoring/backend/alerting/data/alerts.db \
  'SELECT COUNT(*) FROM alerts WHERE timestamp > datetime(\"now\", \"-24 hours\");'"

# Verificar status dos sensores
ssh usuario@servidor "./utils/verificar_sistema.sh"
```

## 🔧 Manutenção

### **Limpeza de Logs**

```bash
#!/bin/bash
# utils/limpar_logs.sh

echo "🧹 Limpando logs antigos..."

# Manter últimos 30 dias
find /opt/cluster-monitoring/logs -name "*.log" -mtime +30 -delete

# Limpar banco de dados (manter 30 dias)
sqlite3 /opt/cluster-monitoring/backend/alerting/data/alerts.db \
  "DELETE FROM alerts WHERE timestamp < datetime('now', '-30 days');"

sqlite3 /opt/cluster-monitoring/backend/alerting/data/alerts.db \
  "DELETE FROM sensor_data WHERE timestamp < datetime('now', '-30 days');"

# Compactar banco
sqlite3 /opt/cluster-monitoring/backend/alerting/data/alerts.db "VACUUM;"

echo "✅ Limpeza concluída"
```

### **Backup de Dados**

```bash
#!/bin/bash
# utils/backup_alertas.sh

BACKUP_DIR="/opt/cluster-monitoring/backups"
DATE=$(date '+%Y%m%d_%H%M%S')

echo "💾 Realizando backup dos alertas..."

# Criar diretório de backup
mkdir -p "$BACKUP_DIR"

# Backup do banco SQLite
cp /opt/cluster-monitoring/backend/alerting/data/alerts.db \
   "$BACKUP_DIR/alerts_$DATE.db"

# Backup dos logs
tar -czf "$BACKUP_DIR/logs_$DATE.tar.gz" \
   /opt/cluster-monitoring/logs/*.log

# Manter apenas últimos 10 backups
cd "$BACKUP_DIR"
ls -t alerts_*.db | tail -n +11 | xargs -r rm
ls -t logs_*.tar.gz | tail -n +11 | xargs -r rm

echo "✅ Backup concluído: $BACKUP_DIR/alerts_$DATE.db"
```

## 🚨 Troubleshooting

### **Problemas Comuns**

| **Problema** | **Sintoma** | **Solução** |
|--------------|-------------|-------------|
| **Emails não enviados** | Alertas sem notificação | Verificar credenciais SMTP |
| **Muitos alertas** | Spam de emails | Ajustar thresholds |
| **Sensores offline** | Não recebe dados | Verificar rede WiFi |
| **Banco corrupto** | Erro SQLite | Restore do backup |
| **Logs grandes** | Disco cheio | Executar limpeza |

### **Comandos de Diagnóstico**

```bash
# Verificar conexão SMTP
telnet smtp.gmail.com 587

# Testar envio de email
python -c "
import smtplib
from email.mime.text import MIMEText
msg = MIMEText('Teste')
msg['Subject'] = 'Teste IF-UFG'
msg['From'] = 'sistema@ifufg.ufg.br'
msg['To'] = 'admin@ifufg.ufg.br'

server = smtplib.SMTP('smtp.gmail.com', 587)
server.starttls()
server.login('sistema@ifufg.ufg.br', 'senha')
server.send_message(msg)
server.quit()
print('Email enviado com sucesso!')
"

# Verificar banco de dados
sqlite3 /opt/cluster-monitoring/backend/alerting/data/alerts.db "PRAGMA integrity_check;"

# Monitorar logs em tempo real
tail -f /opt/cluster-monitoring/logs/alerts.log
```

## 📋 Checklist de Configuração

### **Configuração Inicial**
- [ ] Credenciais SMTP configuradas
- [ ] Destinatários de email definidos
- [ ] Thresholds ajustados para ambiente
- [ ] Log rotation configurado
- [ ] Scripts de verificação testados

### **Testes**
- [ ] Envio de email funcionando
- [ ] Alertas sendo gerados
- [ ] Sensores válidos aceitos
- [ ] Sensores inválidos rejeitados
- [ ] Logs sendo gravados

### **Manutenção**
- [ ] Backup automático configurado
- [ ] Limpeza de logs agendada
- [ ] Monitoramento contínuo ativo
- [ ] Documentação atualizada

---

**📍 Próximo Módulo**: [5. Dashboard e Grafana](05-DASHBOARD.md)  
**🏠 Voltar**: [Manual Principal](README.md) 