# 🔌 ESP32 Sensors - Monitoramento Inteligente de Clusters

Código para as ESP32 que coletam dados de temperatura e umidade e enviam via MQTT.

## 📋 Descrição

Este módulo contém o código para as ESP32 que funcionam como sensores distribuídos no sistema de monitoramento de clusters. Cada ESP32:

- Conecta-se à rede Wi-Fi local
- Lê dados do sensor DHT22 (temperatura e umidade)
- Publica dados via MQTT
- Monitora sua própria saúde
- Reconecta automaticamente em caso de falhas

## 🛠️ Hardware Necessário

### Para cada ESP32:
- **ESP32 DevKit** (qualquer modelo)
- **Sensor DHT22** (temperatura e umidade)
- **Cabo USB** para programação
- **Fonte de alimentação** (USB ou 5V)

### Conexões:
```
DHT22 -> ESP32
VCC   -> 3.3V
GND   -> GND
DATA  -> GPIO26 (configurável)
```

## 📁 Estrutura do Projeto

```
esp32-sensors/
├── src/
│   ├── main.cpp          # Código principal
│   └── config.h          # Configurações centralizadas
├── platformio.ini        # Configuração PlatformIO
├── lib/                  # Bibliotecas (auto-gerado)
├── include/              # Headers (auto-gerado)
└── README.md            # Este arquivo
```

## ⚙️ Configuração

### 1. Instalação do PlatformIO

```bash
# Via pip
pip install platformio

# Ou via VS Code extension
# Instale a extensão "PlatformIO IDE"
```

### 2. Configuração de Rede

Edite o arquivo `src/config.h`:

```cpp
// Configurações de rede
#define WIFI_SSID "SUA_REDE_WIFI"
#define WIFI_PASSWORD "SUA_SENHA_WIFI"
#define MQTT_SERVER "192.168.1.168"  // IP do broker MQTT
```

### 3. Configuração de Sensores

Para múltiplas ESP32, use o `platformio.ini`:

```ini
[env:esp32a]
build_flags =
    -DESP_ID=\"esp32_a\"
    -DPUB_TOPIC=\"legion32/a\"

[env:esp32b]
build_flags =
    -DESP_ID=\"esp32_b\"
    -DPUB_TOPIC=\"legion32/b\"
```

## 🚀 Compilação e Upload

### Para ESP32-A:
```bash
pio run -e esp32a -t upload
```

### Para ESP32-B:
```bash
pio run -e esp32b -t upload
```

### Monitor Serial:
```bash
pio run -e esp32a -t monitor
```

## 📊 Formato dos Dados

### Dados do Sensor:
```json
{
  "esp_id": "esp32_a",
  "temperature": 25.5,
  "humidity": 60.2,
  "timestamp": "1T12:30:45Z",
  "uptime": 3600000,
  "temperature_variation": 2.1,
  "alert": "high_temperature"
}
```

### Status do Sistema:
```json
{
  "esp_id": "esp32_a",
  "status": "online",
  "timestamp": "1T12:30:45Z",
  "uptime": 3600000,
  "wifi_rssi": -45,
  "free_heap": 123456
}
```

## 🔧 Configurações Avançadas

### Intervalo de Leitura
```cpp
#define SENSOR_READ_INTERVAL 2000  // 2 segundos
```

### Limites de Alerta
```cpp
#define TEMP_ALERT_THRESHOLD 27.0
#define HUMIDITY_MIN_THRESHOLD 30.0
#define HUMIDITY_MAX_THRESHOLD 70.0
```

### Timeouts de Conexão
```cpp
#define WIFI_TIMEOUT 10000      // 10 segundos
#define MQTT_RECONNECT_DELAY 5000  // 5 segundos
```

## 🐛 Debug e Logs

### Habilitar Debug:
```cpp
#define DEBUG_MODE true
```

### Logs Disponíveis:
- Conexão Wi-Fi
- Conexão MQTT
- Leituras do sensor
- Alertas gerados
- Erros de sistema

### Monitor Serial:
```bash
# ESP32-A
pio run -e esp32a -t monitor

# ESP32-B
pio run -e esp32b -t monitor
```

## 🔄 Recursos de Robustez

### Reconexão Automática
- Wi-Fi: reconecta automaticamente se desconectado
- MQTT: reconecta com retry exponencial
- Sensor: retry em caso de falha de leitura

### Validação de Dados
- Verifica se valores são válidos (não NaN)
- Range de temperatura: -100°C a 200°C
- Range de umidade: 0% a 100%

### Monitoramento de Saúde
- Uptime do sistema
- Força do sinal Wi-Fi
- Memória heap livre
- Status de conectividade

## 📈 Métricas Coletadas

| Métrica | Descrição | Unidade |
|---------|-----------|---------|
| `temperature` | Temperatura atual | °C |
| `humidity` | Umidade atual | % |
| `temperature_variation` | Variação de temperatura | °C |
| `uptime` | Tempo de funcionamento | ms |
| `wifi_rssi` | Força do sinal Wi-Fi | dBm |
| `free_heap` | Memória heap livre | bytes |

## 🚨 Sistema de Alertas

### Alertas Automáticos:
- **Temperatura Alta**: > 27°C
- **Temperatura Crítica**: > 35°C
- **Variação Brusca**: > 5°C em 5min
- **Umidade Fora do Range**: < 30% ou > 70%
- **Sensor Offline**: > 5min sem dados

### Prevenção de Spam:
- Cooldown de 5 minutos entre alertas
- Rate limiting por sensor
- Alertas inteligentes (não repetitivos)

## 🔧 Troubleshooting

### Problema: Não conecta ao Wi-Fi
```bash
# Verifique:
1. SSID e senha corretos
2. Rede Wi-Fi disponível
3. Sinal Wi-Fi forte o suficiente
```

### Problema: Não conecta ao MQTT
```bash
# Verifique:
1. IP do broker correto
2. Broker MQTT rodando
3. Rede acessível
4. Porta 1883 aberta
```

### Problema: Erro de leitura do sensor
```bash
# Verifique:
1. Conexões do DHT22
2. Alimentação 3.3V
3. GPIO26 conectado
4. Sensor funcionando
```

### Problema: Dados inconsistentes
```bash
# Verifique:
1. Fonte de alimentação estável
2. Conexões firmes
3. Interferência elétrica
4. Temperatura ambiente
```

## 📝 Logs de Exemplo

### Inicialização:
```
=== Monitoramento Inteligente de Clusters - IF-UFG ===
ESP ID: esp32_a
Tópico: legion32/a
Versão: 1.0
Sensor DHT22 inicializado
Conectando ao Wi-Fi...
Wi-Fi conectado!
IP local: 192.168.1.100
Conectando ao MQTT...
MQTT conectado!
Setup concluído!
```

### Operação Normal:
```
Sensor OK - Temp: 25.5°C, Umidade: 60.2%
Publicando: {"esp_id":"esp32_a","temperature":25.5,"humidity":60.2,"timestamp":"1T12:30:45Z","uptime":3600000}
```

### Alerta:
```
[ALERTA] Temperatura alta: 28.5°C
Publicando: {"esp_id":"esp32_a","temperature":28.5,"humidity":55.1,"timestamp":"1T12:35:20Z","uptime":3605000,"alert":"high_temperature"}
```

## 🔄 Atualizações

### Para atualizar o código:
```bash
# 1. Pare o monitor serial (Ctrl+C)
# 2. Compile e faça upload
pio run -e esp32a -t upload

# 3. Reinicie o monitor
pio run -e esp32a -t monitor
```

### Para atualizar configurações:
```bash
# 1. Edite config.h
# 2. Recompile
pio run -e esp32a -t upload
```

## 📞 Suporte

Para problemas ou dúvidas:
- **Email**: victor.matt2003@gmail.com
- **Laboratório**: Laboratório de Computação Científica - IF-UFG

---

**Instituto de Física - UFG**  
*Monitoramento Inteligente de Clusters*  
*Versão 1.0 - 2024* 