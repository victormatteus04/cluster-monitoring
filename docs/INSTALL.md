# 🚀 Guia de Instalação Rápida

## 📋 Pré-requisitos

### Sistema Operacional
- **Linux** (Ubuntu 20.04+ recomendado)
- **macOS** (10.15+)
- **Windows** (10/11 com WSL2)

### Software Necessário
- **Docker** (versão 20.10+)
- **Docker Compose** (versão 2.0+)
- **Git** (para clonar o repositório)

### Hardware
- **Raspberry Pi 4** (recomendado) ou PC
- **2x ESP32** + **2x DHT22**
- **Rede Wi-Fi** local

## ⚡ Instalação Rápida (5 minutos)

### 1. Clone o Repositório
```bash
git clone <repository-url>
cd cluster-monitoring
```

### 2. Configure as ESP32
```bash
# Edite as configurações de rede
nano esp32-sensors/src/config.h

# Configure:
# - WIFI_SSID: sua rede Wi-Fi
# - WIFI_PASSWORD: sua senha Wi-Fi
# - MQTT_SERVER: IP do seu servidor
```

### 3. Compile e Faça Upload das ESP32
```bash
cd esp32-sensors

# Para ESP32-A
pio run -e esp32a -t upload

# Para ESP32-B
pio run -e esp32b -t upload

cd ..
```

### 4. Inicie o Sistema
```bash
# Torne o script executável
chmod +x start.sh

# Execute o script de inicialização
./start.sh
```

### 5. Acesse os Dashboards
- **Grafana**: http://localhost:3000 (admin/senha)
- **Prometheus**: http://localhost:9090
- **MQTT Exporter**: http://localhost:8000

## 🔧 Configuração Detalhada

### Configuração de Rede

#### 1. IP Fixo (Recomendado)
Configure um IP fixo para o servidor:

```bash
# Ubuntu/Debian
sudo nano /etc/netplan/01-netcfg.yaml

# Adicione:
network:
  version: 2
  ethernets:
    eth0:
      dhcp4: false
      addresses: [IP/24]
      gateway4: 192.168.1.1
      nameservers:
        addresses: [8.8.8.8, 8.8.4.4]

# Aplique as mudanças
sudo netplan apply
```

#### 2. Configuração das ESP32
Edite `esp32-sensors/src/config.h`:

```cpp
// Configurações de rede
#define WIFI_SSID "SUA_REDE_WIFI"
#define WIFI_PASSWORD "SUA_SENHA_WIFI"
#define MQTT_SERVER "IP"  // IP do servidor
```

### Configuração de Email

Edite `backend/alerting/config.py`:

```python
EMAIL_CONFIG = {
    'smtp_server': 'smtp.gmail.com',  # ou outro servidor
    'smtp_port': 587,
    'use_ssl': False,
    'username': 'seu-email@gmail.com',
    'password': 'sua-senha-de-app',
    'from_email': 'seu-email@gmail.com',
    'to_emails': ['destinatario@email.com']
}
```

### Configuração de Alertas

Edite `backend/alerting/config.py`:

```python
ALERT_CONFIG = {
    'temperature': {
        'critical_high': 35.0,  # Temperatura crítica
        'high': 27.0,           # Temperatura alta
        'low': 15.0,            # Temperatura baixa
        'critical_low': 5.0     # Temperatura crítica baixa
    },
    'humidity': {
        'high': 70.0,           # Umidade alta
        'low': 30.0             # Umidade baixa
    }
}
```

## 🔌 Conexões das ESP32

### Hardware Necessário
- **ESP32 DevKit** (2x)
- **Sensor DHT22** (2x)
- **Cabo USB** (2x)
- **Fonte de alimentação** (5V/2A)

### Conexões
```
DHT22 -> ESP32
VCC   -> 3.3V
GND   -> GND
DATA  -> GPIO26
```

### Pinout ESP32
```
ESP32 DevKit:
┌─────────────┐
│ 3.3V  GND   │
│ GPIO26      │
│ USB         │
└─────────────┘
```

## 🚀 Comandos Úteis

### Iniciar Sistema
```bash
./start.sh
```

### Parar Sistema
```bash
./stop.sh
```

### Ver Logs
```bash
./logs.sh
```

### Status dos Serviços
```bash
cd backend
docker-compose ps
```

### Reiniciar Serviço
```bash
cd backend
docker-compose restart [servico]
```

### Ver Logs de um Serviço
```bash
cd backend
docker-compose logs -f [servico]
```

## 📊 Dashboards Disponíveis

### Grafana (http://localhost:3000)
- **Dashboard Principal**: Visão geral dos sensores
- **Dashboard de Temperatura**: Gráficos de temperatura
- **Dashboard de Umidade**: Gráficos de umidade
- **Dashboard de Alertas**: Histórico de alertas

### Prometheus (http://localhost:9090)
- **Métricas**: Todas as métricas coletadas
- **Alertas**: Status dos alertas
- **Targets**: Status dos serviços

### MQTT Exporter (http://localhost:8000)
- **Métricas**: Métricas em formato Prometheus
- **Health Check**: Status do exportador

## 🔧 Troubleshooting

### Problema: Docker não inicia
```bash
# Verifique se o Docker está rodando
sudo systemctl status docker

# Inicie o Docker se necessário
sudo systemctl start docker
```

### Problema: Portas em uso
```bash
# Verifique portas em uso
sudo netstat -tuln | grep -E ':(1883|3000|9090|8000)'

# Mate processos se necessário
sudo kill -9 [PID]
```

### Problema: ESP32 não conecta
```bash
# Verifique:
1. SSID e senha corretos
2. IP do servidor correto
3. Rede Wi-Fi acessível
4. Broker MQTT rodando
```

### Problema: Dados não aparecem
```bash
# Verifique logs
./logs.sh

# Verifique conectividade MQTT
mosquitto_sub -h localhost -t "legion32/#" -v
```

### Problema: Alertas não funcionam
```bash
# Verifique configuração de email
cat backend/alerting/config.py

# Teste envio de email
cd backend/alerting
python -c "from alert_manager import EmailSender; EmailSender().send_test_email()"
```

## 📈 Monitoramento

### Métricas Importantes
- **Temperatura**: Deve estar entre 15-35°C
- **Umidade**: Deve estar entre 30-70%
- **Uptime**: Deve ser > 99%
- **Latência MQTT**: Deve ser < 100ms

### Alertas Configurados
- **Temperatura Alta**: > 27°C
- **Temperatura Crítica**: > 35°C
- **Sensor Offline**: > 5min
- **Variação Brusca**: > 5°C/5min

## 🔒 Segurança

### Recomendações
1. **Mude as senhas padrão**
2. **Configure firewall**
3. **Use HTTPS** (opcional)
4. **Monitore logs**
5. **Faça backups regulares**

### Configuração de Firewall
```bash
# Ubuntu/Debian
sudo ufw allow 22/tcp    # SSH
sudo ufw allow 80/tcp    # HTTP
sudo ufw allow 443/tcp   # HTTPS
sudo ufw allow 1883/tcp  # MQTT
sudo ufw enable
```

## 📞 Suporte
z
### Logs de Erro
```bash
# Logs do sistema
./logs.sh

# Logs específicos
tail -f logs/startup.log
tail -f logs/shutdown.log
```

### Contato
- **Email**: victor.matt2003@gmail.com
- **Laboratório**: Laboratório de Computação Científica - IF-UFG

---

**Instituto de Física - UFG**  
*Monitoramento Inteligente de Clusters*  
*Versão 1.0 - 2024* 