# Guia Técnico - Sistema de Monitoramento Inteligente de Clusters

## 🔧 Arquitetura Técnica Detalhada

### Stack Tecnológico

```yaml
Backend:
  - Python 3.11 (asyncio, threading)
  - Docker Compose (multi-container)
  - SQLite (embedded database)
  - MQTT Protocol (IoT communication)

Monitoring:
  - Prometheus (time-series database)
  - Grafana (visualization platform)
  - cAdvisor (container monitoring)
  - Node Exporter (system metrics)

IoT:
  - ESP32 (microcontroller)
  - DHT22 (temperature/humidity sensor)
  - WiFi (wireless connectivity)
  - JSON (data serialization)

Infrastructure:
  - Docker (containerization)
  - Nginx (reverse proxy)
  - SMTP (email delivery)
```

---

## 📊 Estrutura de Dados

### Formato MQTT (ESP32 → Broker)

```json
{
  "esp_id": "esp32_a",
  "temperature": 31.4,
  "humidity": 43.3,
  "timestamp": "2025-06-29T13:32:53Z",
  "uptime": 10688211,
  "temperature_variation": 0,
  "alert": "high_temperature"
}
```

### Métricas Prometheus

```promql
# Temperatura
temperature_celsius{sensor="esp32_a"} 31.4

# Umidade
humidity_percent{sensor="esp32_a"} 43.3

# Uptime do sensor
sensor_uptime_seconds{sensor="esp32_a"} 10688211

# Status do sistema
up{job="mqtt-exporter"} 1
```

### Schema do Banco de Dados (SQLite)

```sql
-- Tabela de alertas
CREATE TABLE alerts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    esp_id TEXT NOT NULL,
    alert_type TEXT NOT NULL,
    severity TEXT NOT NULL,
    message TEXT NOT NULL,
    timestamp TEXT NOT NULL,
    data TEXT,
    sent INTEGER DEFAULT 0,
    retry_count INTEGER DEFAULT 0
);

-- Tabela de estados dos sensores
CREATE TABLE sensor_states (
    esp_id TEXT PRIMARY KEY,
    last_seen TEXT NOT NULL,
    temperature REAL,
    humidity REAL,
    status TEXT NOT NULL,
    alert_count INTEGER DEFAULT 0
);
```

---

## 🐳 Configuração Docker

### docker-compose.yml (Principais Serviços)

```yaml
version: '3.8'

services:
  mosquitto:
    image: eclipse-mosquitto:2.0
    ports:
      - "1883:1883"
      - "9001:9001"
    volumes:
      - ./mosquitto/config:/mosquitto/config
      - ./mosquitto/data:/mosquitto/data
      - ./mosquitto/logs:/mosquitto/log
    restart: unless-stopped

  mqtt-exporter:
    build: ./exporter
    ports:
      - "8000:8000"
    depends_on:
      - mosquitto
    environment:
      - MQTT_BROKER=mosquitto
    restart: unless-stopped

  prometheus:
    image: prom/prometheus:latest
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus/prometheus.yml:/etc/prometheus/prometheus.yml
      - ./prometheus/data:/prometheus
    restart: unless-stopped

  grafana:
    image: grafana/grafana:latest
    ports:
      - "3000:3000"
    volumes:
      - ./grafana/data:/var/lib/grafana
    environment:
      - GF_SECURITY_ADMIN_USER=
      - GF_SECURITY_ADMIN_PASSWORD=
    restart: unless-stopped

  alerting:
    build: ./alerting
    depends_on:
      - mosquitto
      - grafana
    volumes:
      - ./alerting/data:/app/data
    restart: unless-stopped
```

---

## 🔌 Configuração ESP32

### Código Principal (main.cpp)

```cpp
#include <WiFi.h>
#include <PubSubClient.h>
#include <DHT.h>
#include <ArduinoJson.h>

// Configurações WiFi
const char* ssid = "SUA_REDE_WIFI";
const char* password = "SUA_SENHA_WIFI";

// Configurações MQTT
const char* mqtt_server = "192.168.1.100";
const int mqtt_port = 1883;
const char* mqtt_topic = "legion32/a";

// Configurações DHT
#define DHT_PIN 4
#define DHT_TYPE DHT22
DHT dht(DHT_PIN, DHT_TYPE);

WiFiClient espClient;
PubSubClient client(espClient);

void setup() {
  Serial.begin(115200);
  dht.begin();
  
  // Conectar WiFi
  WiFi.begin(ssid, password);
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  
  // Configurar MQTT
  client.setServer(mqtt_server, mqtt_port);
}

void loop() {
  if (!client.connected()) {
    reconnect();
  }
  client.loop();
  
  // Ler sensores
  float temperature = dht.readTemperature();
  float humidity = dht.readHumidity();
  
  if (!isnan(temperature) && !isnan(humidity)) {
    // Criar JSON
    StaticJsonDocument<200> doc;
    doc["esp_id"] = "esp32_a";
    doc["temperature"] = temperature;
    doc["humidity"] = humidity;
    doc["timestamp"] = WiFi.getTime();
    doc["uptime"] = millis();
    
    // Determinar alerta
    if (temperature >= 35.0) {
      doc["alert"] = "critical_temperature";
    } else if (temperature >= 27.0) {
      doc["alert"] = "high_temperature";
    } else {
      doc["alert"] = "normal";
    }
    
    // Enviar via MQTT
    String output;
    serializeJson(doc, output);
    client.publish(mqtt_topic, output.c_str());
  }
  
  delay(10000); // 10 segundos
}

void reconnect() {
  while (!client.connected()) {
    if (client.connect("ESP32_A")) {
      Serial.println("MQTT Connected");
    } else {
      delay(5000);
    }
  }
}
```

---

## 🚨 Sistema de Alertas (Python)

### Classe Principal AlertManager

```python
class AlertManager:
    def __init__(self):
        self.sensors = {}
        self.alert_history = []
        self.email_cooldowns = {}
        self.rate_limiter = RateLimiter()
        self.db_manager = DatabaseManager()
        self.email_sender = EmailSender()
        
    def process_sensor_data(self, esp_id: str, data: Dict) -> Optional[AlertEvent]:
        """Processa dados do sensor e gera alertas se necessário"""
        
        # Atualizar estado do sensor
        self._update_sensor_state(esp_id, data)
        
        # Verificar alertas
        alert = self._check_alerts(esp_id, data)
        
        if alert:
            self._handle_alert(alert)
            
        return alert
    
    def _check_alerts(self, esp_id: str, data: Dict) -> Optional[AlertEvent]:
        """Verifica se os dados geram algum alerta"""
        alerts = []
        temperature = data.get('temperature', 0)
        humidity = data.get('humidity', 0)
        
        # Verificar limites de temperatura
        if temperature >= ALERT_CONFIG['temperature']['critical_high']:
            alerts.append(('temperature_critical', 'CRITICAL'))
        elif temperature >= ALERT_CONFIG['temperature']['high']:
            alerts.append(('temperature_high', 'HIGH'))
        elif temperature <= ALERT_CONFIG['temperature']['critical_low']:
            alerts.append(('temperature_critical_low', 'CRITICAL'))
        elif temperature <= ALERT_CONFIG['temperature']['low']:
            alerts.append(('temperature_low', 'HIGH'))
            
        # Verificar limites de umidade
        if humidity >= ALERT_CONFIG['humidity']['high']:
            alerts.append(('humidity_high', 'MEDIUM'))
        elif humidity <= ALERT_CONFIG['humidity']['low']:
            alerts.append(('humidity_low', 'MEDIUM'))
            
        # Retornar alerta mais crítico
        if alerts:
            alert_type, severity = max(alerts, key=lambda x: self._get_severity_level(x[1]))
            return self._create_alert(esp_id, alert_type, severity, data)
            
        return None
```

### Sistema de Email com Gráficos

```python
class EmailSender:
    def send_alert_email(self, alert: AlertEvent):
        """Envia email de alerta com gráfico anexado"""
        
        msg = MIMEMultipart()
        msg['From'] = self.config['from_email']
        msg['To'] = ', '.join(self.config['to_emails'])
        msg['Subject'] = f"{self.config['subject_prefix']} {alert.severity}: {alert.esp_id}"
        
        # Corpo HTML do email
        body = f"""
        <html>
        <body>
            <h2>🚨 {alert.message}</h2>
            <table border="1" style="border-collapse: collapse;">
                <tr><td><strong>Sensor:</strong></td><td>{alert.esp_id}</td></tr>
                <tr><td><strong>Tipo:</strong></td><td>{alert.alert_type}</td></tr>
                <tr><td><strong>Severidade:</strong></td><td>{alert.severity}</td></tr>
                <tr><td><strong>Timestamp:</strong></td><td>{alert.timestamp}</td></tr>
            </table>
            <br/>
            <img src="cid:grafico_temperatura" alt="Gráfico de Temperatura"/>
            <hr>
            <p><em>Sistema de Monitoramento Inteligente de Clusters - IF-UFG</em></p>
        </body>
        </html>
        """
        
        msg.attach(MIMEText(body, 'html'))
        
        # Baixar e anexar gráfico do Grafana
        grafico = self._baixar_grafico_grafana()
        if grafico:
            mime_img = MIMEImage(grafico)
            mime_img.add_header('Content-ID', '<grafico_temperatura>')
            msg.attach(mime_img)
        
        # Enviar via SMTP
        self._enviar_smtp(msg)
```

---

## 📈 Configuração Prometheus

### prometheus.yml

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  - "rules/*.yml"

scrape_configs:
  - job_name: 'mqtt-exporter'
    static_configs:
      - targets: ['mqtt-exporter:8000']
    scrape_interval: 15s
    
  - job_name: 'cadvisor'
    static_configs:
      - targets: ['cadvisor:8080']
    scrape_interval: 30s
    
  - job_name: 'node-exporter'
    static_configs:
      - targets: ['node-exporter:9100']
    scrape_interval: 30s

alerting:
  alertmanagers:
    - static_configs:
        - targets:
          - alertmanager:9093
```

### Regras de Alerta (cluster_alerts.yml)

```yaml
groups:
  - name: cluster_alerts
    rules:
      - alert: HighTemperature
        expr: temperature_celsius > 27
        for: 1m
        labels:
          severity: warning
        annotations:
          summary: "High temperature detected"
          description: "Temperature is {{ $value }}°C on sensor {{ $labels.sensor }}"
          
      - alert: CriticalTemperature
        expr: temperature_celsius > 35
        for: 30s
        labels:
          severity: critical
        annotations:
          summary: "Critical temperature detected"
          description: "Temperature is {{ $value }}°C on sensor {{ $labels.sensor }}"
          
      - alert: SensorOffline
        expr: up{job="mqtt-exporter"} == 0
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Sensor offline"
          description: "MQTT Exporter is down"
```

---

## 📊 Dashboards Grafana

### Query Examples

```sql
-- Temperatura atual
temperature_celsius

-- Temperatura média (1 hora)
avg_over_time(temperature_celsius[1h])

-- Máxima temperatura (24 horas)
max_over_time(temperature_celsius[24h])

-- Taxa de alertas
rate(alerts_generated_total[5m]) * 300

-- Uptime dos sensores
(time() - sensor_uptime_seconds/1000)
```

### Panel Configuration (JSON)

```json
{
  "title": "Temperature Monitoring",
  "type": "graph",
  "targets": [
    {
      "expr": "temperature_celsius",
      "legendFormat": "{{sensor}}",
      "refId": "A"
    }
  ],
  "yAxes": [
    {
      "label": "Temperature (°C)",
      "min": 0,
      "max": 50
    }
  ],
  "thresholds": [
    {
      "value": 27,
      "colorMode": "critical",
      "op": "gt"
    },
    {
      "value": 35,
      "colorMode": "critical",
      "op": "gt"
    }
  ]
}
```

---

## 🔧 Performance e Otimização

### Configurações de Performance

```python
# Rate Limiting
RATE_LIMITS = {
    'max_emails_per_hour': 10,
    'max_alerts_per_minute': 5,
    'cooldown_seconds': 300
}

# Configurações de Banco
DATABASE_CONFIG = {
    'connection_pool_size': 5,
    'timeout': 30,
    'wal_mode': True,
    'cache_size': 2000
}

# Configurações MQTT
MQTT_CONFIG = {
    'keepalive': 60,
    'max_inflight_messages': 20,
    'message_retry_set': 3,
    'reconnect_delay': 1
}
```

### Métricas de Performance

```promql
# CPU Usage
rate(container_cpu_usage_seconds_total[5m]) * 100

# Memory Usage
container_memory_usage_bytes / container_spec_memory_limit_bytes * 100

# MQTT Messages Rate
rate(mqtt_messages_received_total[5m])

# Alert Processing Time
histogram_quantile(0.95, rate(alert_processing_duration_seconds_bucket[5m]))
```

---

## 🧪 Testes e Debugging

### Testes Unitários

```python
import unittest
from alert_manager import AlertManager

class TestAlertManager(unittest.TestCase):
    def setUp(self):
        self.alert_manager = AlertManager()
    
    def test_high_temperature_alert(self):
        data = {
            'temperature': 30.0,
            'humidity': 45.0,
            'timestamp': '2025-06-29T13:00:00Z'
        }
        
        alert = self.alert_manager.process_sensor_data('test_sensor', data)
        
        self.assertIsNotNone(alert)
        self.assertEqual(alert.alert_type, 'temperature_high')
        self.assertEqual(alert.severity, 'HIGH')
    
    def test_normal_temperature(self):
        data = {
            'temperature': 25.0,
            'humidity': 45.0,
            'timestamp': '2025-06-29T13:00:00Z'
        }
        
        alert = self.alert_manager.process_sensor_data('test_sensor', data)
        self.assertIsNone(alert)
```

### Scripts de Debug

```bash
#!/bin/bash
# debug.sh - Script de debugging

echo "=== System Status ==="
docker compose ps

echo "=== MQTT Messages ==="
docker compose logs mqtt-exporter --tail=20

echo "=== Alert Logs ==="
docker compose logs alerting --tail=20 | grep -E "(ERROR|WARNING|ALERT)"

echo "=== Database Status ==="
docker compose exec alerting sqlite3 /app/data/alerts.db "SELECT COUNT(*) FROM alerts;"

echo "=== Prometheus Targets ==="
curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | {job: .labels.job, health: .health}'
```

---

## 🔒 Segurança

### Configurações de Segurança

```python
SECURITY_CONFIG = {
    'rate_limiting': {
        'enabled': True,
        'max_emails_per_hour': 10,
        'max_alerts_per_minute': 5
    },
    'authentication': {
        'mqtt_username': os.getenv('MQTT_USERNAME'),
        'mqtt_password': os.getenv('MQTT_PASSWORD')
    },
    'encryption': {
        'email_ssl': True,
        'mqtt_ssl': False  # Pode ser habilitado para produção
    }
}
```

### Variáveis de Ambiente

```bash
# .env file
MQTT_BROKER=mosquitto
MQTT_USERNAME=cluster_user
MQTT_PASSWORD=secure_password
GRAFANA_API_TOKEN=
EMAIL_PASSWORD=
DEBUG_MODE=false
```

---

## 📋 Checklist de Deploy

### Pré-Deploy

- [ ] Verificar configurações WiFi nos ESP32
- [ ] Configurar variáveis de ambiente
- [ ] Testar conectividade MQTT
- [ ] Verificar credenciais de email
- [ ] Configurar limites de alertas

### Deploy

- [ ] `./fix_permissions.sh`
- [ ] `./start.sh`
- [ ] Verificar containers: `docker compose ps`
- [ ] Verificar logs: `./logs.sh`
- [ ] Testar dashboards: http://localhost:3000
- [ ] Testar alertas: `python test_alert_hard.py`

### Pós-Deploy

- [ ] Monitorar logs por 24h
- [ ] Verificar recebimento de dados
- [ ] Testar alertas reais
- [ ] Configurar backups
- [ ] Documentar configurações específicas

---

*Este guia técnico complementa a documentação principal e fornece detalhes específicos para desenvolvedores e administradores do sistema.* 