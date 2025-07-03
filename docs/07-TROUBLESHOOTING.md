# 🚨 Módulo 7: Troubleshooting

## 📋 Visão Geral

Este módulo fornece soluções para problemas comuns, guias de diagnóstico e procedimentos de recuperação do sistema de monitoramento IF-UFG.

## 🔍 Diagnóstico Rápido

### **Script de Diagnóstico Completo**

```bash
#!/bin/bash
# utils/diagnostico.sh

echo "🔍 DIAGNÓSTICO COMPLETO DO SISTEMA IF-UFG"
echo "========================================"
echo "Timestamp: $(date)"
echo "Hostname: $(hostname)"
echo "Usuário: $(whoami)"
echo

# 1. Verificar containers Docker
echo "🐳 STATUS DOS CONTAINERS"
echo "------------------------"
if command -v docker &> /dev/null; then
    docker compose -f backend/docker-compose.yaml ps
    echo
    echo "Containers em execução:"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
else
    echo "❌ Docker não encontrado!"
fi
echo

# 2. Verificar conectividade de rede
echo "🌐 CONECTIVIDADE DE REDE"
echo "------------------------"
echo "Testando endpoints..."

# Grafana
if curl -s -f http://localhost:3000 > /dev/null; then
    echo "✅ Grafana (3000): OK"
else
    echo "❌ Grafana (3000): FALHA"
fi

# Prometheus
if curl -s -f http://localhost:9090 > /dev/null; then
    echo "✅ Prometheus (9090): OK"
else
    echo "❌ Prometheus (9090): FALHA"
fi

# MQTT Exporter
if curl -s -f http://localhost:8000/health > /dev/null; then
    echo "✅ MQTT Exporter (8000): OK"
else
    echo "❌ MQTT Exporter (8000): FALHA"
fi

# MQTT Broker
if mosquitto_pub -h localhost -p 1883 -t test -m "hello" 2>/dev/null; then
    echo "✅ MQTT Broker (1883): OK"
else
    echo "❌ MQTT Broker (1883): FALHA"
fi
echo

# 3. Verificar recursos do sistema
echo "💻 RECURSOS DO SISTEMA"
echo "----------------------"
echo "CPU:"
top -bn1 | grep "Cpu(s)" | cut -d% -f1 | awk '{print "  Uso: " $2 "%"}'

echo "Memória:"
free -h | grep Mem | awk '{print "  Usado: " $3 "/" $2 " (" int($3/$2*100) "%)"}'

echo "Disco:"
df -h /opt/cluster-monitoring | tail -n 1 | awk '{print "  Usado: " $3 "/" $2 " (" $5 ")"}'

echo "Load Average:"
uptime | awk -F'load average:' '{print "  " $2}'
echo

# 4. Verificar bancos de dados
echo "🗄️ BANCOS DE DADOS"
echo "------------------"
DB_PATH="/opt/cluster-monitoring/backend/alerting/data/alerts.db"

if [ -f "$DB_PATH" ]; then
    echo "SQLite Alertas:"
    echo "  Tamanho: $(du -h "$DB_PATH" | cut -f1)"
    echo "  Alertas: $(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM alerts;" 2>/dev/null || echo "ERRO")"
    echo "  Sensores: $(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM sensor_data;" 2>/dev/null || echo "ERRO")"
    
    # Verificar integridade
    if sqlite3 "$DB_PATH" "PRAGMA integrity_check;" | grep -q "ok"; then
        echo "  Integridade: ✅ OK"
    else
        echo "  Integridade: ❌ ERRO"
    fi
else
    echo "❌ Banco SQLite não encontrado!"
fi

echo "Prometheus:"
PROM_DATA="/opt/cluster-monitoring/backend/prometheus/data"
if [ -d "$PROM_DATA" ]; then
    echo "  Tamanho: $(du -sh "$PROM_DATA" | cut -f1)"
else
    echo "  ❌ Diretório não encontrado"
fi
echo

# 5. Verificar logs recentes
echo "📝 LOGS RECENTES"
echo "----------------"
LOG_DIR="/opt/cluster-monitoring/logs"

if [ -d "$LOG_DIR" ]; then
    echo "Erros recentes (últimas 10 linhas):"
    tail -n 10 "$LOG_DIR"/*.log 2>/dev/null | grep -i error | tail -5 || echo "  Nenhum erro encontrado"
    
    echo
    echo "Últimas atividades:"
    tail -n 5 "$LOG_DIR"/alerts.log 2>/dev/null || echo "  Log de alertas não disponível"
else
    echo "❌ Diretório de logs não encontrado!"
fi
echo

# 6. Verificar sensores
echo "📡 STATUS DOS SENSORES"
echo "----------------------"
if [ -f "$DB_PATH" ]; then
    echo "Sensores ativos (últimos 5 minutos):"
    sqlite3 "$DB_PATH" "
        SELECT sensor_id, 
               MAX(timestamp) as ultimo_dado,
               COUNT(*) as leituras
        FROM sensor_data 
        WHERE timestamp > datetime('now', '-5 minutes')
        GROUP BY sensor_id;
    " 2>/dev/null || echo "  Erro ao consultar sensores"
    
    echo
    echo "Sensores offline (sem dados há mais de 5 min):"
    sqlite3 "$DB_PATH" "
        SELECT DISTINCT sensor_id
        FROM sensor_data s1
        WHERE NOT EXISTS (
            SELECT 1 FROM sensor_data s2 
            WHERE s2.sensor_id = s1.sensor_id 
            AND s2.timestamp > datetime('now', '-5 minutes')
        )
        AND s1.sensor_id IN ('a', 'b');
    " 2>/dev/null || echo "  Erro ao consultar sensores offline"
else
    echo "❌ Não foi possível verificar sensores"
fi
echo

# 7. Verificar processos
echo "⚙️ PROCESSOS RELACIONADOS"
echo "-------------------------"
echo "Processos Python:"
ps aux | grep python | grep -v grep | wc -l | awk '{print "  Quantidade: " $1}'

echo "Processos Docker:"
ps aux | grep docker | grep -v grep | wc -l | awk '{print "  Quantidade: " $1}'

echo "Uso de portas:"
ss -tulpn | grep -E ":(3000|9090|1883|8000)" | wc -l | awk '{print "  Portas ativas: " $1}'
echo

# 8. Verificar configurações
echo "⚙️ CONFIGURAÇÕES"
echo "----------------"
CONFIG_FILES=(
    "backend/alerting/config.py"
    "backend/prometheus/prometheus.yml"
    "backend/docker-compose.yaml"
)

for config in "${CONFIG_FILES[@]}"; do
    if [ -f "$config" ]; then
        echo "✅ $config"
    else
        echo "❌ $config (não encontrado)"
    fi
done
echo

# 9. Resumo e recomendações
echo "📊 RESUMO DO DIAGNÓSTICO"
echo "------------------------"

# Contar problemas
problems=0

# Verificar serviços críticos
for port in 3000 9090 8000 1883; do
    if ! curl -s -f http://localhost:$port > /dev/null 2>&1 && ! nc -z localhost $port 2>/dev/null; then
        ((problems++))
    fi
done

# Verificar banco
if [ ! -f "$DB_PATH" ] || ! sqlite3 "$DB_PATH" "SELECT 1;" > /dev/null 2>&1; then
    ((problems++))
fi

# Verificar espaço em disco
used_space=$(df /opt/cluster-monitoring | tail -1 | awk '{print $5}' | sed 's/%//')
if [ "$used_space" -gt 90 ]; then
    ((problems++))
fi

if [ $problems -eq 0 ]; then
    echo "✅ Sistema funcionando normalmente"
    echo "🎯 Nenhum problema crítico detectado"
else
    echo "⚠️  $problems problema(s) detectado(s)"
    echo "🔧 Verifique os itens marcados com ❌ acima"
    echo "📖 Consulte o manual de troubleshooting para soluções"
fi

echo
echo "🔍 Para diagnósticos mais detalhados:"
echo "  ./utils/verificar_sistema.sh"
echo "  ./utils/monitorar_recursos.sh"
echo "  docker logs <container_name>"
echo
echo "========================================"
echo "Diagnóstico concluído em $(date)"
```

## 🐳 Problemas com Docker

### **Container não inicia**

```bash
# Verificar logs do container
docker logs cluster-grafana
docker logs cluster-prometheus
docker logs cluster-mosquitto
docker logs cluster-alerting

# Verificar status
docker compose -f backend/docker-compose.yaml ps

# Forçar recriação
docker compose -f backend/docker-compose.yaml down
docker compose -f backend/docker-compose.yaml up -d --force-recreate

# Verificar recursos
docker system df
docker system prune  # Limpar recursos não utilizados
```

### **Problemas de Rede Docker**

```bash
# Verificar redes Docker
docker network ls
docker network inspect cluster-monitoring_default

# Recriar rede
docker compose -f backend/docker-compose.yaml down
docker network prune
docker compose -f backend/docker-compose.yaml up -d

# Testar conectividade entre containers
docker exec grafana ping prometheus
docker exec alerting ping mosquitto
```

### **Problemas de Volume**

```bash
# Verificar volumes
docker volume ls
docker volume inspect cluster-monitoring_prometheus_data

# Verificar permissões
sudo chown -R $USER:$USER /opt/cluster-monitoring/backend/*/data

# Recriar volumes se necessário
docker compose -f backend/docker-compose.yaml down -v
docker compose -f backend/docker-compose.yaml up -d
```

## 📊 Problemas com Grafana

### **Dashboard não carrega**

```bash
# 1. Verificar logs
docker logs grafana

# 2. Verificar data source
curl http://localhost:3000/api/datasources

# 3. Testar conexão Prometheus
curl http://localhost:9090/api/v1/query?query=up

# 4. Resetar configuração se necessário
docker exec grafana rm -f /var/lib/grafana/grafana.db
docker restart grafana
```

### **Alertas não funcionam**

```bash
# Verificar configuração SMTP
docker exec grafana cat /etc/grafana/grafana.ini | grep -A 10 "\[smtp\]"

# Testar envio de email
docker exec grafana grafana-cli admin reset-admin-password admin

# Verificar logs de alertas
docker logs grafana | grep alert
```

### **Performance lenta**

```bash
# Verificar uso de recursos
docker stats grafana

# Otimizar configuração
echo "
[database]
max_open_conns = 0
max_idle_conns = 2
conn_max_lifetime = 14400

[server]
enable_gzip = true
" >> backend/grafana/config/grafana.ini

docker restart grafana
```

## 📈 Problemas com Prometheus

### **Métricas não aparecem**

```bash
# 1. Verificar targets
curl http://localhost:9090/api/v1/targets

# 2. Verificar configuração
docker exec prometheus cat /etc/prometheus/prometheus.yml

# 3. Verificar exporter
curl http://localhost:8000/metrics

# 4. Recarregar configuração
curl -X POST http://localhost:9090/-/reload
```

### **Espaço em disco cheio**

```bash
# Verificar tamanho dos dados
du -sh backend/prometheus/data

# Reduzir retenção
echo "
global:
  external_labels:
    cluster: 'ifufg-monitoring'
storage:
  tsdb:
    retention.time: 15d
    retention.size: 5GB
" > backend/prometheus/prometheus.yml

docker restart prometheus
```

### **Queries lentas**

```bash
# Verificar queries ativas
curl http://localhost:9090/api/v1/query?query=prometheus_engine_queries

# Otimizar queries no Grafana
# - Usar intervalos maiores
# - Limitar time range
# - Usar funções agregadas
```

## 📧 Problemas com Alertas/Email

### **Emails não são enviados**

```bash
# 1. Verificar logs do AlertManager
docker logs alerting

# 2. Testar configuração SMTP
python3 -c "
import smtplib
from email.mime.text import MIMEText

msg = MIMEText('Teste')
msg['Subject'] = 'Teste IF-UFG'
msg['From'] = 'sistema@ifufg.ufg.br'
msg['To'] = 'admin@ifufg.ufg.br'

try:
    server = smtplib.SMTP('smtp.gmail.com', 587)
    server.starttls()
    server.login('sistema@ifufg.ufg.br', 'senha')
    server.send_message(msg)
    server.quit()
    print('✅ Email enviado com sucesso')
except Exception as e:
    print(f'❌ Erro: {e}')
"

# 3. Verificar firewall
sudo ufw status | grep 587
telnet smtp.gmail.com 587
```

### **Muitos alertas falsos**

```bash
# Ajustar thresholds no código
nano backend/alerting/config.py

# Aumentar cooldown
ALERT_COOLDOWN = 600  # 10 minutos

# Verificar dados dos sensores
sqlite3 backend/alerting/data/alerts.db "
SELECT sensor_id, AVG(temperature), COUNT(*)
FROM sensor_data 
WHERE timestamp > datetime('now', '-24 hours')
GROUP BY sensor_id;
"
```

### **AlertManager não processa dados**

```bash
# Verificar webhook
curl -X POST -H "Content-Type: application/json" \
  -d '{"esp_id": "a", "temperature": 25.0, "humidity": 60.0}' \
  http://localhost:8000/webhook

# Verificar logs
tail -f logs/alerts.log

# Reiniciar serviço
docker restart alerting
```

## 📡 Problemas com Sensores ESP32

### **Sensor não conecta WiFi**

```bash
# No monitor serial do ESP32:
# Verificar SSID e senha
# Verificar força do sinal
# Testar com hotspot móvel

# Comandos de debug no ESP32:
WiFi.scanNetworks()  # Verificar redes disponíveis
WiFi.RSSI()         # Verificar força do sinal
WiFi.status()       # Status da conexão
```

### **Dados não chegam ao servidor**

```bash
# 1. Verificar MQTT broker
mosquitto_sub -h localhost -p 1883 -t "legion32/#"

# 2. Verificar firewall
sudo ufw status
sudo ufw allow 1883/tcp

# 3. Testar manualmente
mosquitto_pub -h localhost -p 1883 -t "legion32/a" \
  -m '{"esp_id": "a", "temperature": 25.0, "humidity": 60.0}'

# 4. Verificar logs MQTT
docker logs mosquitto
```

### **Sensor reinicia constantemente**

```bash
# Possíveis causas:
# - Problema de alimentação
# - Watchdog timeout
# - Overflow de memória
# - Erro no código

# Soluções:
# 1. Verificar fonte de alimentação
# 2. Aumentar WATCHDOG_TIMEOUT
# 3. Reduzir READING_INTERVAL
# 4. Verificar logs serial
```

## 🗄️ Problemas com Banco de Dados

### **Banco SQLite corrompido**

```bash
# 1. Verificar integridade
sqlite3 backend/alerting/data/alerts.db "PRAGMA integrity_check;"

# 2. Tentar reparar
sqlite3 backend/alerting/data/alerts.db "VACUUM;"

# 3. Restore do backup
cp backups/backup_YYYYMMDD_HHMMSS/alerts.db backend/alerting/data/alerts.db

# 4. Recriar banco se necessário
mv backend/alerting/data/alerts.db backend/alerting/data/alerts.db.bak
docker restart alerting  # Recriará o banco
```

### **Performance lenta do banco**

```bash
# 1. Criar índices
sqlite3 backend/alerting/data/alerts.db "
CREATE INDEX IF NOT EXISTS idx_alerts_timestamp ON alerts(timestamp);
CREATE INDEX IF NOT EXISTS idx_sensor_data_timestamp ON sensor_data(timestamp);
ANALYZE;
"

# 2. Limpar dados antigos
./utils/limpar_dados_antigos.sh

# 3. Otimizar banco
sqlite3 backend/alerting/data/alerts.db "VACUUM;"
```

### **Banco muito grande**

```bash
# Verificar tamanho
du -h backend/alerting/data/alerts.db

# Limpar dados antigos
sqlite3 backend/alerting/data/alerts.db "
DELETE FROM sensor_data WHERE timestamp < datetime('now', '-7 days');
DELETE FROM alerts WHERE timestamp < datetime('now', '-30 days');
VACUUM;
"

# Configurar limpeza automática
crontab -e
# 0 2 * * * /opt/cluster-monitoring/utils/limpar_dados_antigos.sh
```

## 🌐 Problemas de Rede

### **Portas não acessíveis externamente**

```bash
# 1. Verificar firewall
sudo ufw status
sudo ufw allow 3000/tcp  # Grafana
sudo ufw allow 9090/tcp  # Prometheus

# 2. Verificar bind dos containers
docker port grafana
docker port prometheus

# 3. Verificar iptables
sudo iptables -L -n

# 4. Testar conectividade
telnet servidor-ifufg 3000
nmap -p 3000,9090,1883,8000 servidor-ifufg
```

### **DNS não resolve**

```bash
# Testar resolução
nslookup servidor-ifufg.ufg.br
ping servidor-ifufg.ufg.br

# Configurar hosts local se necessário
echo "192.168.1.100 servidor-ifufg.ufg.br" | sudo tee -a /etc/hosts
```

### **Latência alta**

```bash
# Verificar latência
ping -c 10 servidor-ifufg
traceroute servidor-ifufg

# Verificar rede interna
iftop  # Monitor de tráfego
netstat -i  # Estatísticas de interface
```

## 🔧 Scripts de Recuperação

### **Recuperação Completa do Sistema**

```bash
#!/bin/bash
# utils/recuperacao_sistema.sh

echo "🚨 INICIANDO RECUPERAÇÃO DO SISTEMA"
echo "Timestamp: $(date)"

# 1. Parar todos os serviços
echo "⏹️ Parando serviços..."
./stop.sh

# 2. Backup de emergência
echo "💾 Criando backup de emergência..."
mkdir -p recovery_backup_$(date +%Y%m%d_%H%M%S)
cp -r backend/*/data recovery_backup_*/

# 3. Limpar containers e volumes
echo "🧹 Limpando containers..."
docker compose -f backend/docker-compose.yaml down -v
docker system prune -f

# 4. Verificar e corrigir permissões
echo "🔧 Corrigindo permissões..."
sudo chown -R $USER:$USER /opt/cluster-monitoring
chmod +x *.sh utils/*.sh

# 5. Recriar diretórios necessários
echo "📁 Recriando estrutura..."
mkdir -p backend/{alerting,grafana,prometheus,mosquitto}/data
mkdir -p logs backups

# 6. Restaurar configurações
echo "⚙️ Verificando configurações..."
if [ ! -f backend/alerting/config.py ]; then
    echo "❌ Config do AlertManager não encontrado!"
    exit 1
fi

# 7. Reiniciar sistema
echo "▶️ Reiniciando sistema..."
./start.sh

# 8. Aguardar inicialização
echo "⏳ Aguardando inicialização..."
sleep 30

# 9. Verificar sistema
echo "🔍 Verificando sistema..."
./utils/verificar_sistema.sh

echo "✅ Recuperação concluída!"
```

### **Reinicialização Limpa**

```bash
#!/bin/bash
# utils/reset_sistema.sh

echo "⚠️  REINICIALIZAÇÃO LIMPA DO SISTEMA"
echo "Isso irá apagar TODOS os dados!"
read -p "Continuar? (digite 'CONFIRMO'): " confirm

if [ "$confirm" != "CONFIRMO" ]; then
    echo "❌ Operação cancelada"
    exit 1
fi

# Parar sistema
./stop.sh

# Remover dados
rm -rf backend/*/data/*
rm -rf logs/*
rm -rf backups/*

# Recriar estrutura
mkdir -p backend/{alerting,grafana,prometheus,mosquitto}/data
mkdir -p logs backups

# Reiniciar
./start.sh

echo "✅ Sistema reinicializado"
```

## 📞 Suporte e Contato

### **Coleta de Informações para Suporte**

```bash
#!/bin/bash
# utils/coletar_info_suporte.sh

SUPPORT_DIR="support_info_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$SUPPORT_DIR"

echo "📋 Coletando informações para suporte..."

# Informações do sistema
uname -a > "$SUPPORT_DIR/system_info.txt"
df -h >> "$SUPPORT_DIR/system_info.txt"
free -h >> "$SUPPORT_DIR/system_info.txt"

# Logs
cp -r logs "$SUPPORT_DIR/"

# Configurações (sem senhas)
cp backend/docker-compose.yaml "$SUPPORT_DIR/"
grep -v "password\|PASSWORD" backend/alerting/config.py > "$SUPPORT_DIR/config_sanitized.py"

# Status dos containers
docker ps > "$SUPPORT_DIR/docker_status.txt"
docker logs grafana > "$SUPPORT_DIR/grafana_logs.txt" 2>&1
docker logs prometheus > "$SUPPORT_DIR/prometheus_logs.txt" 2>&1

# Diagnóstico
./utils/diagnostico.sh > "$SUPPORT_DIR/diagnostico.txt"

# Compactar
tar -czf "${SUPPORT_DIR}.tar.gz" "$SUPPORT_DIR"
rm -rf "$SUPPORT_DIR"

echo "✅ Informações coletadas em: ${SUPPORT_DIR}.tar.gz"
echo "📧 Envie este arquivo para o suporte técnico"
```

### **Contatos de Suporte**

```
📧 Email: suporte-ti@ifufg.ufg.br
📱 WhatsApp: (62) 9999-9999 (emergências)
🏢 Instituto de Física - UFG
🌐 https://fisica.ufg.br/suporte
```

## 📋 Checklist de Troubleshooting

### **Verificação Básica**
- [ ] Todos os containers estão rodando
- [ ] Portas estão acessíveis
- [ ] Banco de dados íntegro
- [ ] Espaço em disco suficiente
- [ ] Logs sem erros críticos

### **Verificação Avançada**
- [ ] Sensores enviando dados
- [ ] Alertas funcionando
- [ ] Emails sendo enviados
- [ ] Dashboards carregando
- [ ] Performance adequada

### **Recuperação**
- [ ] Backup recente disponível
- [ ] Procedimentos de recuperação testados
- [ ] Informações de suporte coletadas
- [ ] Contatos de emergência atualizados

---

**📍 Próximo Módulo**: [8. Verificações e Monitoramento](08-VERIFICACOES.md)  
**🏠 Voltar**: [Manual Principal](README.md) 