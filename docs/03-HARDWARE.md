# 🔧 Módulo 3: Hardware e Sensores

## 📋 Visão Geral

Este módulo detalha as especificações, configuração e programação dos sensores ESP32 utilizados no sistema de monitoramento do IF-UFG.

## 🔌 Especificações do Hardware

### **ESP32-WROOM-32**

| **Especificação** | **Valor** |
|------------------|-----------|
| **Microcontrolador** | Xtensa dual-core 32-bit LX6 |
| **Frequência** | 240 MHz |
| **Flash** | 4MB |
| **SRAM** | 520KB |
| **Wi-Fi** | 802.11 b/g/n |
| **Bluetooth** | v4.2 BR/EDR e BLE |
| **GPIO** | 34 pinos programáveis |
| **ADC** | 12-bit SAR ADC |
| **Tensão** | 3.3V (alimentação 5V via USB) |

### **Sensor DHT22 (AM2302)**

| **Especificação** | **Valor** |
|------------------|-----------|
| **Tipo** | Temperatura e Umidade Digital |
| **Faixa Temperatura** | -40°C a +80°C |
| **Precisão Temperatura** | ±0.5°C |
| **Faixa Umidade** | 0% a 100% RH |
| **Precisão Umidade** | ±2% RH |
| **Protocolo** | 1-Wire |
| **Tensão** | 3.3V - 5V |
| **Corrente** | 1-1.5mA |

## 🔧 Esquema de Conexão

### **Pinout ESP32 + DHT22**

```
ESP32-WROOM-32          DHT22 (AM2302)
┌─────────────────┐     ┌─────────────┐
│                 │     │             │
│ GPIO 4 ─────────┼─────┤ DATA        │
│ 3.3V ───────────┼─────┤ VCC         │
│ GND ────────────┼─────┤ GND         │
│                 │     │             │
│ GPIO 2 (LED)    │     └─────────────┘
│                 │
│ WiFi Antenna    │
└─────────────────┘

Resistor Pull-up: 10kΩ entre DATA e VCC (opcional para DHT22)
```

### **Diagrama de Circuito**

```
                    3.3V
                      │
                      ├─── VCC (DHT22)
                      │
                 ┌────┴────┐ 10kΩ (opcional)
                 │         │
ESP32 GPIO 4 ────┴── DATA (DHT22)
                 
ESP32 GND ─────────── GND (DHT22)

LED Status (GPIO 2):
ESP32 GPIO 2 ──┬── 330Ω ──┬── LED ──┬── GND
               │          │         │
               └──────────┴─────────┘
```

## 💻 Configuração do Firmware

### **Estrutura do Projeto PlatformIO**

```
esp32-sensors/
├── platformio.ini          # Configuração do projeto
├── src/
│   ├── main.cpp            # Código principal
│   └── config.h            # Configurações
├── lib/                    # Bibliotecas locais
├── include/                # Headers
└── README.md
```

### **Configuração platformio.ini**

```ini
[env:esp32dev]
platform = espressif32
board = esp32dev
framework = arduino

; Configurações de build
monitor_speed = 115200
upload_speed = 921600

; Bibliotecas necessárias
lib_deps = 
    knolleary/PubSubClient@^2.8
    adafruit/DHT sensor library@^1.4.4
    adafruit/Adafruit Unified Sensor@^1.1.7
    bblanchon/ArduinoJson@^6.21.2

; Configurações de debug
build_flags = 
    -DCORE_DEBUG_LEVEL=3
    -DCONFIG_ARDUHAL_LOG_COLORS=1

; Configurações de partição
board_build.partitions = huge_app.csv
```

### **Arquivo config.h**

```cpp
#ifndef CONFIG_H
#define CONFIG_H

// ============================================================================
// CONFIGURAÇÕES WIFI
// ============================================================================
#define WIFI_SSID           "WiFi-IF-UFG"
#define WIFI_PASSWORD       "senha-wifi-ifufg"
#define WIFI_TIMEOUT        30000  // 30 segundos

// ============================================================================
// CONFIGURAÇÕES MQTT
// ============================================================================
#define MQTT_SERVER         "192.168.1.100"  // IP do servidor
#define MQTT_PORT           1883
#define MQTT_CLIENT_ID      "ESP32-"         // Será concatenado com o ID
#define MQTT_TOPIC_BASE     "legion32/"
#define MQTT_USERNAME       ""               // Se necessário
#define MQTT_PASSWORD       ""               // Se necessário

// ============================================================================
// CONFIGURAÇÕES DO SENSOR
// ============================================================================
#define DHT_PIN             4                // GPIO para DHT22
#define DHT_TYPE            DHT22
#define LED_PIN             2                // LED de status
#define READING_INTERVAL    60000            // 1 minuto entre leituras

// ============================================================================
// CONFIGURAÇÕES DE IDENTIFICAÇÃO
// ============================================================================
// Defina o ID do sensor (a, b, c, etc.)
#define SENSOR_ID           "a"             // ALTERE PARA CADA ESP32
#define LOCATION            "Sala-Servidores"

// ============================================================================
// CONFIGURAÇÕES DE DEBUG
// ============================================================================
#define DEBUG_SERIAL        true
#define SERIAL_BAUD         115200

// ============================================================================
// CONFIGURAÇÕES DE SISTEMA
// ============================================================================
#define WATCHDOG_TIMEOUT    30               // Watchdog em segundos
#define MAX_WIFI_RETRIES    5
#define MAX_MQTT_RETRIES    3
#define DEEP_SLEEP_TIME     0                // 0 = sem deep sleep

#endif
```

### **Código Principal (main.cpp)**

```cpp
#include <Arduino.h>
#include <WiFi.h>
#include <PubSubClient.h>
#include <DHT.h>
#include <ArduinoJson.h>
#include <esp_task_wdt.h>
#include "config.h"

// ============================================================================
// OBJETOS GLOBAIS
// ============================================================================
WiFiClient wifiClient;
PubSubClient mqttClient(wifiClient);
DHT dht(DHT_PIN, DHT_TYPE);

// Variáveis de controle
unsigned long lastReading = 0;
unsigned long bootTime = 0;
int wifiRetries = 0;
int mqttRetries = 0;

// ============================================================================
// SETUP INICIAL
// ============================================================================
void setup() {
    Serial.begin(SERIAL_BAUD);
    delay(1000);
    
    Serial.println("=== ESP32 Sensor IF-UFG ===");
    Serial.printf("Sensor ID: %s\n", SENSOR_ID);
    Serial.printf("Location: %s\n", LOCATION);
    
    // Configurar pinos
    pinMode(LED_PIN, OUTPUT);
    digitalWrite(LED_PIN, LOW);
    
    // Inicializar sensor DHT
    dht.begin();
    
    // Configurar watchdog
    esp_task_wdt_init(WATCHDOG_TIMEOUT, true);
    esp_task_wdt_add(NULL);
    
    // Conectar WiFi
    connectWiFi();
    
    // Configurar MQTT
    mqttClient.setServer(MQTT_SERVER, MQTT_PORT);
    mqttClient.setCallback(mqttCallback);
    
    // Conectar MQTT
    connectMQTT();
    
    // Marcar tempo de boot
    bootTime = millis();
    
    Serial.println("Setup completo!");
    digitalWrite(LED_PIN, HIGH);
}

// ============================================================================
// LOOP PRINCIPAL
// ============================================================================
void loop() {
    // Reset watchdog
    esp_task_wdt_reset();
    
    // Verificar conexões
    if (!WiFi.isConnected()) {
        Serial.println("WiFi desconectado, tentando reconectar...");
        connectWiFi();
    }
    
    if (!mqttClient.connected()) {
        Serial.println("MQTT desconectado, tentando reconectar...");
        connectMQTT();
    }
    
    // Manter MQTT
    mqttClient.loop();
    
    // Ler sensores no intervalo definido
    if (millis() - lastReading >= READING_INTERVAL) {
        readAndSendSensorData();
        lastReading = millis();
    }
    
    // Pequeno delay para não sobrecarregar
    delay(100);
}

// ============================================================================
// CONECTAR WIFI
// ============================================================================
void connectWiFi() {
    wifiRetries = 0;
    WiFi.mode(WIFI_STA);
    WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
    
    Serial.printf("Conectando ao WiFi %s", WIFI_SSID);
    
    while (WiFi.status() != WL_CONNECTED && wifiRetries < MAX_WIFI_RETRIES) {
        delay(1000);
        Serial.print(".");
        wifiRetries++;
        
        // Piscar LED durante conexão
        digitalWrite(LED_PIN, !digitalRead(LED_PIN));
    }
    
    if (WiFi.isConnected()) {
        Serial.println("\nWiFi conectado!");
        Serial.printf("IP: %s\n", WiFi.localIP().toString().c_str());
        Serial.printf("RSSI: %d dBm\n", WiFi.RSSI());
        digitalWrite(LED_PIN, HIGH);
    } else {
        Serial.println("\nFalha na conexão WiFi!");
        digitalWrite(LED_PIN, LOW);
        
        // Tentar novamente em 30 segundos
        delay(30000);
        ESP.restart();
    }
}

// ============================================================================
// CONECTAR MQTT
// ============================================================================
void connectMQTT() {
    mqttRetries = 0;
    
    String clientId = String(MQTT_CLIENT_ID) + SENSOR_ID;
    
    while (!mqttClient.connected() && mqttRetries < MAX_MQTT_RETRIES) {
        Serial.printf("Conectando ao MQTT %s:%d...", MQTT_SERVER, MQTT_PORT);
        
        if (mqttClient.connect(clientId.c_str(), MQTT_USERNAME, MQTT_PASSWORD)) {
            Serial.println(" Conectado!");
            
            // Subscribe em tópicos de comando (se necessário)
            String commandTopic = String(MQTT_TOPIC_BASE) + "command/" + SENSOR_ID;
            mqttClient.subscribe(commandTopic.c_str());
            
        } else {
            Serial.printf(" Falha, rc=%d. Tentando novamente em 5s...\n", mqttClient.state());
            delay(5000);
            mqttRetries++;
        }
    }
    
    if (!mqttClient.connected()) {
        Serial.println("Falha crítica no MQTT. Reiniciando...");
        delay(10000);
        ESP.restart();
    }
}

// ============================================================================
// CALLBACK MQTT
// ============================================================================
void mqttCallback(char* topic, byte* payload, unsigned int length) {
    String message;
    for (int i = 0; i < length; i++) {
        message += (char)payload[i];
    }
    
    Serial.printf("Mensagem recebida [%s]: %s\n", topic, message.c_str());
    
    // Processar comandos (restart, config, etc.)
    if (message == "restart") {
        Serial.println("Comando de restart recebido!");
        delay(1000);
        ESP.restart();
    }
}

// ============================================================================
// LER E ENVIAR DADOS DO SENSOR
// ============================================================================
void readAndSendSensorData() {
    Serial.println("Lendo sensores...");
    
    // Ler DHT22
    float temperature = dht.readTemperature();
    float humidity = dht.readHumidity();
    
    // Verificar se leituras são válidas
    if (isnan(temperature) || isnan(humidity)) {
        Serial.println("Erro na leitura do DHT22!");
        return;
    }
    
    // Obter informações do sistema
    unsigned long uptime = (millis() - bootTime) / 1000;
    int wifiRSSI = WiFi.RSSI();
    uint32_t freeHeap = ESP.getFreeHeap();
    
    // Criar JSON
    DynamicJsonDocument doc(1024);
    doc["esp_id"] = SENSOR_ID;
    doc["location"] = LOCATION;
    doc["temperature"] = round(temperature * 10.0) / 10.0;  // 1 casa decimal
    doc["humidity"] = round(humidity * 10.0) / 10.0;
    doc["uptime"] = uptime;
    doc["wifi_rssi"] = wifiRSSI;
    doc["free_heap"] = freeHeap;
    doc["timestamp"] = millis();
    
    // Serializar JSON
    String jsonString;
    serializeJson(doc, jsonString);
    
    // Publicar no MQTT
    String topic = String(MQTT_TOPIC_BASE) + SENSOR_ID;
    
    if (mqttClient.publish(topic.c_str(), jsonString.c_str())) {
        Serial.printf("Dados enviados: %s\n", jsonString.c_str());
        
        // Piscar LED para indicar envio
        digitalWrite(LED_PIN, LOW);
        delay(100);
        digitalWrite(LED_PIN, HIGH);
        
    } else {
        Serial.println("Falha ao enviar dados MQTT!");
    }
}
```

## 📡 Configuração de Rede

### **Configurações WiFi IF-UFG**

```cpp
// Para rede corporativa
#define WIFI_SSID           "IF-UFG-IoT"
#define WIFI_PASSWORD       "senha-iot-2024"

// Para rede de desenvolvimento
#define WIFI_SSID           "IF-UFG-DEV"
#define WIFI_PASSWORD       "senha-dev-2024"

// Para hotspot móvel (backup)
#define WIFI_SSID           "Hotspot-Admin"
#define WIFI_PASSWORD       "backup-2024"
```

### **Configuração de IP Estático (Opcional)**

```cpp
// Configurar IP estático no setup()
IPAddress local_IP(192, 168, 1, 200);  // IP fixo para sensor A
IPAddress gateway(192, 168, 1, 1);
IPAddress subnet(255, 255, 255, 0);
IPAddress primaryDNS(8, 8, 8, 8);
IPAddress secondaryDNS(8, 8, 4, 4);

if (!WiFi.config(local_IP, gateway, subnet, primaryDNS, secondaryDNS)) {
    Serial.println("Falha na configuração de IP estático");
}
```

## 🏭 Produção e Deploy dos Sensores

### **Configuração por Sensor**

| **Sensor** | **ID** | **GPIO DHT** | **Localização** | **IP Sugerido** |
|------------|--------|--------------|-----------------|-----------------|
| **ESP32-A** | "a" | 4 | Rack Principal | 192.168.1.201 |
| **ESP32-B** | "b" | 4 | Sala Servidores | 192.168.1.202 |
| **ESP32-C** | "c" | 4 | UPS Room | 192.168.1.203 |
| **ESP32-D** | "d" | 4 | Network Closet | 192.168.1.204 |

### **Procedimento de Flash**

```bash
# 1. Conectar ESP32 via USB
# 2. Configurar config.h para cada sensor
# 3. Compilar e fazer upload

# Para sensor A
sed -i 's/#define SENSOR_ID.*/#define SENSOR_ID "a"/' src/config.h
platformio run --target upload --environment esp32dev

# Para sensor B  
sed -i 's/#define SENSOR_ID.*/#define SENSOR_ID "b"/' src/config.h
platformio run --target upload --environment esp32dev
```

### **Script de Deploy Automático**

```bash
#!/bin/bash
# deploy_sensors.sh

SENSORS=("a" "b" "c" "d")
LOCATIONS=("Rack-Principal" "Sala-Servidores" "UPS-Room" "Network-Closet")

for i in "${!SENSORS[@]}"; do
    SENSOR_ID=${SENSORS[$i]}
    LOCATION=${LOCATIONS[$i]}
    
    echo "Configurando sensor $SENSOR_ID..."
    
    # Atualizar config.h
    sed -i "s/#define SENSOR_ID.*/#define SENSOR_ID \"$SENSOR_ID\"/" src/config.h
    sed -i "s/#define LOCATION.*/#define LOCATION \"$LOCATION\"/" src/config.h
    
    # Compilar
    platformio run --environment esp32dev
    
    echo "Conecte o ESP32-$SENSOR_ID e pressione Enter..."
    read
    
    # Upload
    platformio run --target upload --environment esp32dev
    
    echo "Sensor $SENSOR_ID configurado! Desconecte e conecte o próximo."
done
```

## 🔧 Manutenção e Troubleshooting

### **Diagnóstico via Serial**

```bash
# Conectar ao monitor serial
platformio device monitor --environment esp32dev --baud 115200

# Ou com screen/minicom
screen /dev/ttyUSB0 115200
```

### **Comandos de Debug**

```cpp
// Adicionar ao código para debug
void printSystemInfo() {
    Serial.println("=== INFORMAÇÕES DO SISTEMA ===");
    Serial.printf("Chip ID: %s\n", String((uint32_t)ESP.getEfuseMac(), HEX).c_str());
    Serial.printf("Firmware: %s\n", __DATE__ " " __TIME__);
    Serial.printf("Free Heap: %d bytes\n", ESP.getFreeHeap());
    Serial.printf("WiFi RSSI: %d dBm\n", WiFi.RSSI());
    Serial.printf("Uptime: %lu segundos\n", millis() / 1000);
}
```

### **Problemas Comuns**

| **Problema** | **Sintoma** | **Solução** |
|--------------|-------------|-------------|
| **DHT22 não responde** | NaN nas leituras | Verificar conexões, delay entre leituras |
| **WiFi não conecta** | Timeout de WiFi | Verificar SSID/senha, sinal fraco |
| **MQTT falha** | rc=-2 ou similar | Verificar IP do servidor, firewall |
| **Watchdog reset** | ESP reinicia sozinho | Reduzir READING_INTERVAL |
| **Memória insuficiente** | Crash aleatório | Otimizar código, reduzir variáveis |

### **Atualização OTA (Over-The-Air)**

```cpp
#include <ArduinoOTA.h>

void setupOTA() {
    ArduinoOTA.setHostname(("ESP32-" + String(SENSOR_ID)).c_str());
    ArduinoOTA.setPassword("senha-ota-ifufg");
    
    ArduinoOTA.onStart([]() {
        Serial.println("OTA: Iniciando atualização");
    });
    
    ArduinoOTA.onEnd([]() {
        Serial.println("OTA: Atualização concluída");
    });
    
    ArduinoOTA.begin();
}

// No loop()
ArduinoOTA.handle();
```

## 🔒 Segurança e Boas Práticas

### **Segurança da Rede**
- Usar WPA2/WPA3 na rede WiFi
- Segmentar rede IoT (VLAN separada)
- Firewall para MQTT (apenas portas necessárias)
- Certificados SSL/TLS para MQTT (produção)

### **Segurança do Firmware**
- Senhas em arquivo separado (não no Git)
- OTA com autenticação
- Watchdog para recovery automático
- Logs de segurança

### **Manutenção Preventiva**
- Verificação semanal dos sensores
- Limpeza física mensal
- Atualização firmware trimestral
- Backup das configurações

---

**📍 Próximo Módulo**: [4. Emails, Logs e Alertas](04-ALERTAS.md)  
**🏠 Voltar**: [Manual Principal](README.md) 