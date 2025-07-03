#include <Arduino.h>
#include <WiFi.h>
#include <PubSubClient.h>
#include <DHT.h>
#include <ArduinoJson.h>
#include "config.h"

// ============================================================================
// OBJETOS GLOBAIS
// ============================================================================
DHT dht(DHTPIN, DHTTYPE);
WiFiClient espClient;
PubSubClient mqttClient(espClient);



// ============================================================================
// VARIÁVEIS GLOBAIS
// ============================================================================
SystemStatus systemStatus = {false, false, 0, 0, 0};
SensorData lastSensorData = {0, 0, 0, false};
unsigned long lastPublishTime = 0;
unsigned long lastWifiCheck = 0;
unsigned long lastMqttCheck = 0;

// ============================================================================
// CONFIGURAÇÕES ESPECÍFICAS DA ESP32 (definidas via build flags)
// ============================================================================
#ifndef ESP_ID
    #define ESP_ID "esp32_unknown"
#endif

#ifndef PUB_TOPIC
    #define PUB_TOPIC "legion32/unknown"
#endif

#ifndef STATUS_TOPIC
    #define STATUS_TOPIC "legion32/status"
#endif

// ============================================================================
// FUNÇÕES DE UTILIDADE
// ============================================================================

/**
 * @brief Converte timestamp para string ISO 8601
 */
String getISOTimestamp() {
    unsigned long now = millis();
    unsigned long seconds = now / 1000;
    unsigned long minutes = seconds / 60;
    unsigned long hours = minutes / 60;
    unsigned long days = hours / 24;
    
    char timestamp[25];
    snprintf(timestamp, sizeof(timestamp), "%luT%02lu:%02lu:%02luZ", 
             days, hours % 24, minutes % 60, seconds % 60);
    return String(timestamp);
}

/**
 * @brief Verifica se o valor é válido (não NaN)
 */
bool isValidValue(float value) {
    return !isnan(value) && value > -100 && value < 200;
}

/**
 * @brief Calcula a variação de temperatura (deprecated - usar calculateTemperatureVariation5Min)
 */
float calculateTemperatureVariation(float currentTemp) {
    if (!lastSensorData.is_valid) return 0.0;
    return abs(currentTemp - lastSensorData.temperature);
}



// ============================================================================
// FUNÇÕES DE CONECTIVIDADE
// ============================================================================

/**
 * @brief Conecta ao Wi-Fi com timeout e retry
 */
bool connectWiFi() {
    if (WiFi.status() == WL_CONNECTED) {
        return true;
    }
    
    CLUSTER_DEBUG_PRINTLN("Conectando ao Wi-Fi...");
    WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
    
    unsigned long startTime = millis();
    while (WiFi.status() != WL_CONNECTED && (millis() - startTime) < WIFI_TIMEOUT) {
        delay(500);
        CLUSTER_DEBUG_PRINT(".");
    }
    
    if (WiFi.status() == WL_CONNECTED) {
        CLUSTER_DEBUG_PRINTLN("\nWi-Fi conectado!");
        CLUSTER_DEBUG_PRINTF("IP: %s\n", WiFi.localIP().toString().c_str());
        systemStatus.wifi_connected = true;
        systemStatus.reconnect_attempts = 0;
        return true;
    } else {
        CLUSTER_DEBUG_PRINTLN("\nFalha na conexão Wi-Fi!");
        systemStatus.wifi_connected = false;
        systemStatus.reconnect_attempts++;
        return false;
    }
}

/**
 * @brief Callback para reconexão MQTT
 */
void mqttCallback(char* topic, byte* payload, unsigned int length) {
    CLUSTER_DEBUG_PRINTF("Mensagem recebida no tópico: %s\n", topic);
    CLUSTER_DEBUG_PRINT("Payload: ");
    for (int i = 0; i < length; i++) {
        CLUSTER_DEBUG_PRINT((char)payload[i]);
    }
    CLUSTER_DEBUG_PRINTLN();
}

/**
 * @brief Publica status do sistema
 */
bool publishStatus(const char* status) {
    StaticJsonDocument<200> doc;
    doc["esp_id"] = ESP_ID;
    doc["status"] = status;
    doc["timestamp"] = getISOTimestamp();
    doc["uptime"] = millis();
    doc["wifi_rssi"] = WiFi.RSSI();
    doc["free_heap"] = ESP.getFreeHeap();
    
    String payload;
    serializeJson(doc, payload);
    
    return mqttClient.publish(STATUS_TOPIC, payload.c_str());
}

/**
 * @brief Conecta ao MQTT com retry
 */
bool connectMQTT() {
    if (mqttClient.connected()) {
        return true;
    }
    
    CLUSTER_DEBUG_PRINTLN("Conectando ao MQTT...");
    
    if (mqttClient.connect(ESP_ID)) {
        CLUSTER_DEBUG_PRINTLN("MQTT conectado!");
        systemStatus.mqtt_connected = true;
        systemStatus.reconnect_attempts = 0;
        
        // Publica status online
        publishStatus("online");
        return true;
    } else {
        CLUSTER_DEBUG_PRINTF("Falha MQTT, rc=%d\n", mqttClient.state());
        systemStatus.mqtt_connected = false;
        return false;
    }
}

// ============================================================================
// FUNÇÕES DE SENSOR
// ============================================================================

/**
 * @brief Lê dados do sensor com retry
 */
SensorData readSensor() {
    SensorData data = {0, 0, 0, false};
    
    for (int i = 0; i < SENSOR_RETRY_COUNT; i++) {
        float humidity = dht.readHumidity();
        float temperature = dht.readTemperature();
        
        if (isValidValue(humidity) && isValidValue(temperature)) {
            data.temperature = temperature;
            data.humidity = humidity;
            data.timestamp = millis();
            data.is_valid = true;
            CLUSTER_DEBUG_PRINTF("Sensor OK - Temp: %.2f°C, Umidade: %.2f%%\n", 
                        temperature, humidity);
            break;
        } else {
            CLUSTER_DEBUG_PRINTF("Tentativa %d: Erro na leitura do sensor\n", i + 1);
            delay(1000);
        }
    }
    
    if (!data.is_valid) {
        CLUSTER_DEBUG_PRINTLN("Falha na leitura do sensor após todas as tentativas");
    }
    
    return data;
}

// ============================================================================
// FUNÇÕES DE PUBLICAÇÃO
// ============================================================================

/**
 * @brief Publica dados do sensor
 */
bool publishSensorData(const SensorData& data) {
    if (!data.is_valid) {
        return false;
    }
    
    StaticJsonDocument<JSON_BUFFER_SIZE> doc;
    doc["esp_id"] = ESP_ID;
    doc["temperature"] = round(data.temperature * 100) / 100.0;
    doc["humidity"] = round(data.humidity * 100) / 100.0;
    doc["timestamp"] = getISOTimestamp();
    doc["uptime"] = millis();
    
    // Adiciona alertas básicos se necessário
    if (data.temperature > TEMP_ALERT_THRESHOLD) {
        doc["alert"] = "high_temperature";
    } else if (data.humidity < HUMIDITY_MIN_THRESHOLD || 
               data.humidity > HUMIDITY_MAX_THRESHOLD) {
        doc["alert"] = "humidity_out_of_range";
    }
    
    String payload;
    serializeJson(doc, payload);
    
    CLUSTER_DEBUG_PRINTF("Publicando: %s\n", payload.c_str());
    
    if (mqttClient.publish(PUB_TOPIC, payload.c_str())) {
        lastPublishTime = millis();
        return true;
    } else {
        CLUSTER_DEBUG_PRINTLN("Falha na publicação MQTT");
        return false;
    }
}

// ============================================================================
// FUNÇÕES DE MONITORAMENTO
// ============================================================================

/**
 * @brief Verifica e mantém conectividade
 */
void maintainConnectivity() {
    unsigned long now = millis();
    
    // Verifica Wi-Fi a cada 30 segundos
    if (now - lastWifiCheck > 30000) {
        if (WiFi.status() != WL_CONNECTED) {
            CLUSTER_DEBUG_PRINTLN("Wi-Fi desconectado, reconectando...");
            systemStatus.wifi_connected = false;
            connectWiFi();
        }
        lastWifiCheck = now;
    }
    
    // Verifica MQTT a cada 10 segundos
    if (now - lastMqttCheck > 10000) {
        if (!mqttClient.connected()) {
            CLUSTER_DEBUG_PRINTLN("MQTT desconectado, reconectando...");
            systemStatus.mqtt_connected = false;
            connectMQTT();
        }
        lastMqttCheck = now;
    }
}

/**
 * @brief Atualiza status do sistema
 */
void updateSystemStatus() {
    systemStatus.uptime = millis();
    systemStatus.wifi_connected = (WiFi.status() == WL_CONNECTED);
    systemStatus.mqtt_connected = mqttClient.connected();
}

// ============================================================================
// SETUP E LOOP PRINCIPAIS
// ============================================================================

void setup() {
    // Inicialização do Serial
    Serial.begin(SERIAL_BAUD_RATE);
    delay(1000);
    
    CLUSTER_DEBUG_PRINTLN("=== Monitoramento Inteligente de Clusters - IF-UFG ===");
    CLUSTER_DEBUG_PRINTF("ESP ID: %s\n", ESP_ID);
    CLUSTER_DEBUG_PRINTF("Tópico: %s\n", PUB_TOPIC);
    CLUSTER_DEBUG_PRINTF("Versão: 1.0\n");
    
    // Inicialização do sensor
    dht.begin();
    CLUSTER_DEBUG_PRINTLN("Sensor DHT22 inicializado");
    
    // Configuração MQTT
    mqttClient.setServer(MQTT_SERVER, MQTT_PORT);
    mqttClient.setCallback(mqttCallback);
    mqttClient.setKeepAlive(MQTT_KEEPALIVE_CUSTOM);
    
    // Conecta ao Wi-Fi
    if (connectWiFi()) {
        // Conecta ao MQTT
        connectMQTT();
    }
    
    CLUSTER_DEBUG_PRINTLN("Setup concluído!");
}

void loop() {
    // Mantém conectividade
    maintainConnectivity();
    
    // Atualiza status do sistema
    updateSystemStatus();
    
    // Processa mensagens MQTT
    mqttClient.loop();
    
    // Lê e publica dados do sensor
    unsigned long now = millis();
    if (now - lastPublishTime >= SENSOR_READ_INTERVAL) {
        SensorData currentData = readSensor();
        
        if (currentData.is_valid) {
            // Publica dados
            if (publishSensorData(currentData)) {
                // Atualiza último dado válido
                lastSensorData = currentData;
                systemStatus.last_sensor_read = now;
            }
        } else {
            // Publica erro de sensor
            CLUSTER_DEBUG_PRINTLN("Publicando erro de sensor");
            publishStatus("sensor_error");
        }
        
        lastPublishTime = now;
    }
    
    // Pequeno delay para estabilidade
    delay(100);
} 