# 🏗️ Módulo 1: Arquitetura do Sistema

## 📋 Visão Geral

O Sistema de Monitoramento IF-UFG é uma solução completa de IoT para monitoramento de clusters, composta por **sensores ESP32**, **servidor de processamento** e **interface de visualização**.

## 🔧 Componentes Principais

### **1. Camada de Sensores (Edge Layer)**
- **ESP32** (sensores a, b)
- **DHT22** (temperatura e umidade)
- **Wi-Fi** para conectividade
- **Firmware personalizado**

### **2. Camada de Comunicação (Network Layer)**
- **MQTT Broker** (Eclipse Mosquitto)
- **HTTP Webhook** para integração
- **Wi-Fi infrastructure**
- **Protocolo JSON** para dados

### **3. Camada de Processamento (Processing Layer)**
- **MQTT Exporter** (Python)
- **AlertManager** (Python)
- **Prometheus** (métricas)
- **SQLite** (persistência)

### **4. Camada de Visualização (Presentation Layer)**
- **Grafana** (dashboards)
- **Email notifications** (SMTP)
- **REST APIs** (endpoints)
- **Web interface**

## 🌐 Arquitetura de Deploy

### **Opção 1: Servidor Dedicado (Recomendado)**
```
┌─────────────────────────────────────────────────────────────┐
│                    SERVIDOR IF-UFG                         │
│  ┌─────────────────────────────────────────────────────┐   │
│  │              Docker Containers                       │   │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌─────────┐ │   │
│  │  │ Grafana  │ │Prometheus│ │ MQTT     │ │ Alerting │ │   │
│  │  │   :3000  │ │   :9090  │ │ :1883    │ │  :8000  │ │   │
│  │  └──────────┘ └──────────┘ └──────────┘ └─────────┘ │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  📁 /opt/cluster-monitoring/                               │
│  📁 /opt/cluster-monitoring/data/                          │
│  📁 /opt/cluster-monitoring/logs/                          │
└─────────────────────────────────────────────────────────────┘
                              │
                    ┌─────────┴─────────┐
                    │    Wi-Fi Network   │
                    │   192.168.x.x/24   │
                    └─────────┬─────────┘
                              │
        ┌─────────────────────┼─────────────────────┐
        │                     │                     │
    ┌───▼───┐             ┌───▼───┐             ┌───▼───┐
    │ESP32-a│             │ESP32-b│             │ ... │
    │DHT22  │             │DHT22  │             │ ESP32-n│
    │Wi-Fi  │             │Wi-Fi  │             │ DHT22 │
    └───────┘             └───────┘             └───────┘
```

### **Opção 2: Raspberry Pi 3+**
```
┌─────────────────────────────────────────────────────────────┐
│                  RASPBERRY PI 3B+                          │
│  ┌─────────────────────────────────────────────────────┐   │
│  │              Docker Containers                       │   │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌─────────┐ │   │
│  │  │ Grafana  │ │Prometheus│ │ MQTT     │ │ Alerting │ │   │
│  │  │   :3000  │ │   :9090  │ │ :1883    │ │  :8000  │ │   │
│  │  └──────────┘ └──────────┘ └──────────┘ └─────────┘ │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  💾 MicroSD 32GB+ (Classe 10)                             │
│  🔌 Fonte 5V/3A                                           │
│  📶 Wi-Fi integrado                                        │
└─────────────────────────────────────────────────────────────┘
```

## 📊 Fluxo de Dados

### **1. Coleta de Dados**
```
ESP32 Sensor → DHT22 Reading → JSON Payload → Wi-Fi → MQTT Broker
```

### **2. Processamento**
```
MQTT → MQTT Exporter → Prometheus Metrics → AlertManager → Email/Logs
```

### **3. Visualização**
```
Prometheus → Grafana → Dashboard → Charts/Graphs → Web Interface
```

### **4. Alertas**
```
AlertManager → Email Template → SMTP → Notification → User
```

## 🔧 Tecnologias Utilizadas

### **Backend**
| Componente | Tecnologia | Versão | Porta |
|------------|------------|--------|--------|
| **MQTT Broker** | Eclipse Mosquitto | 2.0 | 1883 |
| **Métricas** | Prometheus | latest | 9090 |
| **Dashboards** | Grafana | latest | 3000 |
| **Alertas** | Python 3.11 | 3.11 | 8000 |
| **Exporter** | Python 3.11 | 3.11 | 8000 |
| **Banco** | SQLite | 3.x | - |

### **Frontend**
| Componente | Tecnologia | Funcionalidade |
|------------|------------|----------------|
| **Grafana UI** | React/TypeScript | Dashboards interativos |
| **REST API** | Flask/Python | Endpoints HTTP |
| **MQTT Client** | Paho MQTT | Comunicação IoT |
| **Email** | SMTP/HTML | Notificações |

### **Hardware**
| Componente | Especificação | Função |
|------------|---------------|--------|
| **ESP32** | ESP32-WROOM-32 | Microcontrolador |
| **DHT22** | AM2302 | Sensor temperatura/umidade |
| **Wi-Fi** | 802.11 b/g/n | Conectividade |
| **Servidor** | x86_64 / ARM64 | Processamento |

## 🚦 Estados do Sistema

### **Estados dos Sensores**
- **🟢 Online**: Sensor enviando dados normalmente
- **🟡 Warning**: Sensor com atraso ou valores anômalos
- **🔴 Offline**: Sensor sem comunicação há mais de 5 minutos
- **⚫ Error**: Sensor com erro de hardware ou firmware

### **Estados dos Serviços**
- **🟢 Healthy**: Serviço funcionando normalmente
- **🟡 Degraded**: Serviço com performance reduzida
- **🔴 Down**: Serviço inoperante
- **🔄 Restarting**: Serviço reiniciando

## 📈 Métricas Monitoradas

### **Sensores**
- **Temperatura** (°C): -40 a +80
- **Umidade** (%): 0 a 100
- **Status**: Online/Offline
- **Uptime**: Tempo de funcionamento
- **Wi-Fi RSSI**: Força do sinal

### **Sistema**
- **CPU Usage**: Uso de processador
- **Memory**: Uso de memória
- **Disk I/O**: Operações de disco
- **Network**: Tráfego de rede
- **Container Health**: Estado dos containers

## 🔄 Redundância e Alta Disponibilidade

### **Estratégias de Backup**
- **Dados**: Backup automático SQLite
- **Configurações**: Versionamento Git
- **Métricas**: Retenção Prometheus
- **Dashboards**: Export Grafana

### **Recuperação de Falhas**
- **Auto-restart**: Containers Docker
- **Health checks**: Monitoramento contínuo
- **Alertas**: Notificação de falhas
- **Recovery**: Scripts automatizados

## 📡 Protocolos de Comunicação

### **MQTT Topics**
```
legion32/a          # Dados do sensor A
legion32/b          # Dados do sensor B  
legion32/status     # Status dos sensores
legion32/system     # Estatísticas do sistema
```

### **Formato de Mensagens**
```json
{
  "esp_id": "a",
  "temperature": 25.6,
  "humidity": 60.2,
  "uptime": 3600,
  "wifi_rssi": -45,
  "timestamp": "2024-07-03T10:30:00Z"
}
```

### **REST Endpoints**
```
GET  /metrics       # Prometheus metrics
GET  /health        # Health check
POST /webhook       # HTTP sensor data
GET  /             # Status page
```

## 🛡️ Segurança

### **Rede**
- **Firewall**: Apenas portas necessárias
- **Wi-Fi**: WPA2/WPA3 encryption
- **VPN**: Acesso remoto seguro (opcional)

### **Aplicação**
- **Autenticação**: Grafana login
- **Validação**: Input sanitization
- **Logs**: Auditoria de acesso
- **Backup**: Dados criptografados

## 📊 Performance

### **Capacidade**
- **Sensores**: Até 100 ESP32 simultâneos
- **Dados**: 1 leitura/sensor/minuto
- **Retenção**: 30 dias (configurável)
- **Throughput**: 1000 msg/min MQTT

### **Requisitos Mínimos**
- **CPU**: 2 cores, 1.5GHz
- **RAM**: 2GB
- **Storage**: 20GB SSD
- **Network**: 100Mbps

### **Requisitos Recomendados**
- **CPU**: 4 cores, 2.5GHz
- **RAM**: 4GB
- **Storage**: 50GB SSD
- **Network**: 1Gbps

---

**📍 Próximo Módulo**: [2. Instalação e Deploy](02-INSTALACAO.md)  
**🏠 Voltar**: [Manual Principal](README.md) 