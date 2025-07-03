# ============================================================================
# EXPORTADOR MQTT PARA PROMETHEUS
# Monitoramento Inteligente de Clusters - IF-UFG
# ============================================================================

import json
import logging
import os
import signal
import sys
import time
from datetime import datetime
from typing import Dict, Any

import paho.mqtt.client as mqtt
from prometheus_client import (
    start_http_server, Gauge, Counter, Histogram, 
    generate_latest, CONTENT_TYPE_LATEST
)
from flask import Flask, Response, request, jsonify

# ============================================================================
# CONFIGURAÇÃO DE LOGGING
# ============================================================================
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# ============================================================================
# CONFIGURAÇÕES
# ============================================================================
MQTT_BROKER = os.getenv('MQTT_BROKER', 'localhost')
MQTT_PORT = int(os.getenv('MQTT_PORT', 1883))
PROMETHEUS_PORT = int(os.getenv('PROMETHEUS_PORT', 8000))

# ============================================================================
# MÉTRICAS PROMETHEUS
# ============================================================================

# Métricas de temperatura
temperature_gauge = Gauge(
    'cluster_temperature_celsius',
    'Temperatura atual do cluster',
    ['esp_id', 'location']
)

humidity_gauge = Gauge(
    'cluster_humidity_percent',
    'Umidade atual do cluster',
    ['esp_id', 'location']
)

# Métricas de variação
temperature_variation_gauge = Gauge(
    'cluster_temperature_variation_celsius',
    'Variação de temperatura',
    ['esp_id', 'location']
)

# Métricas de status
sensor_status_gauge = Gauge(
    'cluster_sensor_status',
    'Status do sensor (1=online, 0=offline)',
    ['esp_id', 'location']
)

# Métricas de contadores
messages_received_counter = Counter(
    'cluster_messages_received_total',
    'Total de mensagens MQTT recebidas',
    ['esp_id', 'topic']
)

alerts_generated_counter = Counter(
    'cluster_alerts_generated_total',
    'Total de alertas gerados',
    ['esp_id', 'alert_type', 'severity']
)

# Métricas de latência
message_processing_duration = Histogram(
    'cluster_message_processing_seconds',
    'Tempo de processamento de mensagens',
    ['esp_id']
)

# Métricas de sistema
uptime_gauge = Gauge(
    'cluster_sensor_uptime_seconds',
    'Uptime do sensor em segundos',
    ['esp_id']
)

wifi_rssi_gauge = Gauge(
    'cluster_wifi_rssi_dbm',
    'Força do sinal Wi-Fi',
    ['esp_id']
)

free_heap_gauge = Gauge(
    'cluster_free_heap_bytes',
    'Memória heap livre',
    ['esp_id']
)

# ============================================================================
# CLASSE PRINCIPAL DO EXPORTADOR
# ============================================================================

class MQTTExporter:
    """Exportador MQTT para Prometheus"""
    
    def __init__(self):
        self.mqtt_client = None
        self.running = True
        self.sensor_data = {}
        
        # Configuração de sinais
        signal.signal(signal.SIGINT, self._signal_handler)
        signal.signal(signal.SIGTERM, self._signal_handler)
    
    def _signal_handler(self, signum, frame):
        """Handler para sinais de shutdown"""
        logger.info(f"Recebido sinal {signum}, iniciando shutdown...")
        self.running = False
    
    def setup_mqtt(self):
        """Configura cliente MQTT"""
        try:
            self.mqtt_client = mqtt.Client()
            self.mqtt_client.on_connect = self._on_mqtt_connect
            self.mqtt_client.on_message = self._on_mqtt_message
            self.mqtt_client.on_disconnect = self._on_mqtt_disconnect
            
            # Configurações de reconexão
            self.mqtt_client.reconnect_delay_set(min_delay=1, max_delay=120)
            
            logger.info("Cliente MQTT configurado")
            
        except Exception as e:
            logger.error(f"Erro ao configurar MQTT: {e}")
            raise
    
    def _on_mqtt_connect(self, client, userdata, flags, rc):
        """Callback de conexão MQTT"""
        if rc == 0:
            logger.info("Conectado ao broker MQTT")
            
            # Inscreve nos tópicos
            topics = [
                ('legion32/+', 0),  # Dados dos sensores (legion32/a, legion32/b)
                ('legion32/status', 0),  # Status dos sensores
                ('legion32/system/stats', 0)  # Estatísticas do sistema
            ]
            
            for topic, qos in topics:
                client.subscribe(topic, qos)
                logger.info(f"Inscrito no tópico: {topic}")
        else:
            logger.error(f"Falha na conexão MQTT, código: {rc}")
    
    def _on_mqtt_disconnect(self, client, userdata, rc):
        """Callback de desconexão MQTT"""
        if rc != 0:
            logger.warning(f"Desconectado inesperadamente do MQTT, código: {rc}")
        else:
            logger.info("Desconectado do MQTT")
    
    def _on_mqtt_message(self, client, userdata, msg):
        """Callback de mensagem MQTT"""
        start_time = time.time()
        
        try:
            # Log da mensagem recebida
            logger.debug(f"Mensagem recebida: {msg.topic} - {msg.payload.decode()}")
            
            # Processa diferentes tipos de mensagem
            if msg.topic.startswith('legion32/') and len(msg.topic.split('/')) == 2:
                self._process_sensor_data(msg.topic, msg.payload.decode())
            elif msg.topic == 'legion32/status':
                self._process_status_message(msg.payload.decode())
            elif msg.topic == 'legion32/system/stats':
                self._process_system_stats(msg.payload.decode())
            else:
                logger.warning(f"Tópico não reconhecido: {msg.topic}")
            
            # Registra tempo de processamento
            duration = time.time() - start_time
            esp_id = msg.topic.split('/')[-1] if len(msg.topic.split('/')) >= 2 else 'unknown'
            message_processing_duration.labels(esp_id=esp_id).observe(duration)
            
        except Exception as e:
            logger.error(f"Erro ao processar mensagem MQTT: {e}")
    
    def _process_sensor_data(self, topic: str, payload: str):
        """Processa dados de sensores"""
        try:
            # Extrai ESP ID do tópico (legion32/a, legion32/b, etc.)
            esp_id = topic.split('/')[-1]
            
            # APENAS sensores 'a' e 'b' são aceitos
            sensores_validos = {'a', 'b'}
            if esp_id not in sensores_validos:
                logger.warning(f"🚫 MQTT: Sensor '{esp_id}' REJEITADO - Apenas sensores 'a' e 'b' são aceitos")
                return
            
            # Parse do JSON
            data = json.loads(payload)
            
            # Incrementa contador de mensagens
            messages_received_counter.labels(esp_id=esp_id, topic=topic).inc()
            
            # Atualiza métricas de temperatura e umidade
            if 'temperature' in data:
                temperature_gauge.labels(
                    esp_id=esp_id,
                    location=data.get('location', 'unknown')
                ).set(data['temperature'])
            
            if 'humidity' in data:
                humidity_gauge.labels(
                    esp_id=esp_id,
                    location=data.get('location', 'unknown')
                ).set(data['humidity'])
            
            # Métrica de variação de temperatura é calculada no AlertManager
            # Não precisa mais processar aqui
            
            # Atualiza métricas de sistema
            if 'uptime' in data:
                uptime_gauge.labels(esp_id=esp_id).set(data['uptime'])
            
            if 'wifi_rssi' in data:
                wifi_rssi_gauge.labels(esp_id=esp_id).set(data['wifi_rssi'])
            
            if 'free_heap' in data:
                free_heap_gauge.labels(esp_id=esp_id).set(data['free_heap'])
            
            # Processa alertas
            if 'alert' in data:
                alert_type = data['alert']
                severity = self._get_alert_severity(data)
                alerts_generated_counter.labels(
                    esp_id=esp_id,
                    alert_type=alert_type,
                    severity=severity
                ).inc()
            
            # Atualiza status do sensor
            sensor_status_gauge.labels(
                esp_id=esp_id,
                location=data.get('location', 'unknown')
            ).set(1)  # Online
            
            # Armazena dados para referência
            self.sensor_data[esp_id] = {
                'last_update': datetime.now(),
                'data': data
            }
            
            logger.debug(f"Dados processados para {esp_id}: Temp={data.get('temperature')}°C, "
                        f"Umidade={data.get('humidity')}%")
            
        except json.JSONDecodeError as e:
            logger.error(f"Erro ao decodificar JSON: {e}")
        except Exception as e:
            logger.error(f"Erro ao processar dados do sensor: {e}")
    
    def _process_status_message(self, payload: str):
        """Processa mensagens de status"""
        try:
            data = json.loads(payload)
            esp_id = data.get('esp_id', 'unknown')
            status = data.get('status', 'unknown')
            
            # Atualiza status do sensor
            sensor_status_gauge.labels(
                esp_id=esp_id,
                location=data.get('location', 'unknown')
            ).set(1 if status == 'online' else 0)
            
            logger.info(f"Status atualizado: {esp_id} - {status}")
            
        except Exception as e:
            logger.error(f"Erro ao processar mensagem de status: {e}")
    
    def _process_system_stats(self, payload: str):
        """Processa estatísticas do sistema"""
        try:
            data = json.loads(payload)
            logger.debug(f"Estatísticas do sistema recebidas: {data}")
            
        except Exception as e:
            logger.error(f"Erro ao processar estatísticas do sistema: {e}")
    
    def _get_alert_severity(self, data: Dict) -> str:
        """Determina severidade do alerta baseado nos dados"""
        temperature = data.get('temperature', 0)
        
        if temperature >= 35:
            return 'CRITICAL'
        elif temperature >= 27:
            return 'HIGH'
        elif temperature <= 5:
            return 'CRITICAL'
        elif temperature <= 15:
            return 'HIGH'
        else:
            return 'MEDIUM'
    
    def connect_mqtt(self):
        """Conecta ao broker MQTT"""
        try:
            logger.info(f"Conectando ao broker MQTT: {MQTT_BROKER}:{MQTT_PORT}")
            
            self.mqtt_client.connect(MQTT_BROKER, MQTT_PORT, 60)
            self.mqtt_client.loop_start()
            
        except Exception as e:
            logger.error(f"Erro ao conectar ao MQTT: {e}")
            raise
    
    def start_prometheus_server(self):
        """Inicia servidor HTTP para métricas Prometheus"""
        try:
            start_http_server(PROMETHEUS_PORT)
            logger.info(f"Servidor Prometheus iniciado na porta {PROMETHEUS_PORT}")
            
        except Exception as e:
            logger.error(f"Erro ao iniciar servidor Prometheus: {e}")
            raise
    
    def run(self):
        """Executa o exportador"""
        try:
            logger.info("=== Iniciando Exportador MQTT para Prometheus ===")
            logger.info(f"Versão: 1.0")
            logger.info(f"Broker MQTT: {MQTT_BROKER}:{MQTT_PORT}")
            logger.info(f"Porta HTTP: 8000")
            
            # Configura MQTT
            self.setup_mqtt()
            
            # Conecta ao MQTT
            self.connect_mqtt()
            
            logger.info("Exportador iniciado com sucesso!")
            
            # Loop principal
            while self.running:
                time.sleep(1)
                
        except KeyboardInterrupt:
            logger.info("Interrupção do teclado recebida")
        except Exception as e:
            logger.error(f"Erro no exportador: {e}")
        finally:
            self.shutdown()
    
    def shutdown(self):
        """Desliga o exportador de forma limpa"""
        logger.info("Iniciando shutdown do exportador...")
        
        self.running = False
        
        # Desliga MQTT
        if self.mqtt_client:
            try:
                self.mqtt_client.loop_stop()
                self.mqtt_client.disconnect()
                logger.info("Cliente MQTT desconectado")
            except Exception as e:
                logger.error(f"Erro ao desconectar MQTT: {e}")
        
        logger.info("Exportador desligado com sucesso")
        sys.exit(0)

# ============================================================================
# APLICAÇÃO FLASK PARA ENDPOINTS ADICIONAIS
# ============================================================================

app = Flask(__name__)

# Cliente MQTT global para uso no webhook
mqtt_client_global = None

@app.route('/metrics')
def metrics():
    """Endpoint para métricas Prometheus"""
    return Response(generate_latest(), mimetype=CONTENT_TYPE_LATEST)

@app.route('/health')
def health():
    """Endpoint de health check"""
    return {'status': 'healthy', 'timestamp': datetime.now().isoformat()}

@app.route('/')
def index():
    """Página inicial"""
    return '''
    <html>
    <head><title>MQTT Exporter</title></head>
    <body>
        <h1>MQTT Exporter - Monitoramento Inteligente de Clusters</h1>
        <p><a href="/metrics">Métricas Prometheus</a></p>
        <p><a href="/health">Health Check</a></p>
    </body>
    </html>
    '''

@app.route('/webhook', methods=['POST'])
def webhook():
    """Webhook para receber dados de sensores via HTTP"""
    try:
        data = request.get_json()
        
        if not data:
            return jsonify({'error': 'No data received'}), 400
        
        esp_id = data.get('esp_id')
        if not esp_id:
            return jsonify({'error': 'esp_id is required'}), 400
        
        # APENAS sensores 'a' e 'b' são aceitos
        sensores_validos = {'a', 'b'}
        if esp_id not in sensores_validos:
            logger.warning(f"🚫 Webhook: Sensor '{esp_id}' REJEITADO - Apenas sensores 'a' e 'b' são aceitos")
            return jsonify({'error': f'Sensor {esp_id} não é válido. Apenas sensores "a" e "b" são aceitos.'}), 400
        
        temperature = data.get('temperature')
        humidity = data.get('humidity')
        
        if temperature is None or humidity is None:
            return jsonify({'error': 'temperature and humidity are required'}), 400
        
        # Cria tópico MQTT
        topic = f"legion32/{esp_id}"
        
        # Payload para MQTT
        mqtt_payload = {
            'esp_id': esp_id,
            'temperature': temperature,
            'humidity': humidity,
            'timestamp': datetime.now().isoformat()
        }
        
        # Publica no MQTT usando cliente global
        if mqtt_client_global:
            mqtt_client_global.publish(topic, json.dumps(mqtt_payload))
            logger.info(f"✅ Webhook: Dados do sensor {esp_id} publicados no MQTT")
        else:
            logger.warning("Cliente MQTT não disponível para webhook")
        
        return jsonify({
            'status': 'success',
            'message': f'Dados do sensor {esp_id} recebidos e publicados no MQTT'
        }), 200
        
    except Exception as e:
        logger.error(f"Erro no webhook: {e}")
        return jsonify({'error': 'Internal server error'}), 500

# ============================================================================
# FUNÇÃO PRINCIPAL
# ============================================================================

def main():
    """Função principal"""
    global mqtt_client_global
    
    try:
        # Cria exporter global para uso no webhook
        exporter = MQTTExporter()
        
        # Configuração MQTT
        exporter.setup_mqtt()
        
        # Conecta ao MQTT
        exporter.connect_mqtt()
        
        # Armazena cliente MQTT globalmente para uso no webhook
        mqtt_client_global = exporter.mqtt_client
        
        # Inicia Flask app em thread separada
        import threading
        flask_thread = threading.Thread(
            target=lambda: app.run(host='0.0.0.0', port=8000, debug=False)
        )
        flask_thread.daemon = True
        flask_thread.start()
        
        # Executa exportador MQTT
        exporter.run()
        
    except Exception as e:
        logger.error(f"Erro fatal no exportador: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main() 