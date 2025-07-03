# ============================================================================
# SISTEMA PRINCIPAL DE ALERTAS
# Monitoramento Inteligente de Clusters - IF-UFG
# ============================================================================

import json
import logging
import signal
import sys
import time
from datetime import datetime
from typing import Dict, Any

import paho.mqtt.client as mqtt

from config import MQTT_CONFIG, LOGGING_CONFIG
from alert_manager import AlertManager

# ============================================================================
# CONFIGURAÇÃO DE LOGGING
# ============================================================================

def setup_logging():
    """Configura o sistema de logging"""
    logging.basicConfig(
        level=getattr(logging, LOGGING_CONFIG['level']),
        format=LOGGING_CONFIG['format'],
        handlers=[
            logging.StreamHandler() if LOGGING_CONFIG['console']['enabled'] else None,
            logging.FileHandler(LOGGING_CONFIG['file']['path']) if LOGGING_CONFIG['file']['enabled'] else None
        ]
    )
    return logging.getLogger(__name__)

logger = setup_logging()

# ============================================================================
# CLASSE PRINCIPAL DO SISTEMA
# ============================================================================

class ClusterMonitoringSystem:
    """Sistema principal de monitoramento de clusters"""
    
    def __init__(self):
        self.alert_manager = AlertManager()
        self.mqtt_client = None
        self.running = True
        
        # Estatísticas
        self.stats = {
            'messages_received': 0,
            'alerts_generated': 0,
            'start_time': datetime.now(),
            'last_health_check': datetime.now()
        }
        
        # Configuração de sinais para graceful shutdown
        signal.signal(signal.SIGINT, self._signal_handler)
        signal.signal(signal.SIGTERM, self._signal_handler)
    
    def _signal_handler(self, signum, frame):
        """Handler para sinais de shutdown"""
        logger.info(f"Recebido sinal {signum}, iniciando shutdown...")
        self.shutdown()
    
    def setup_mqtt(self):
        """Configura cliente MQTT"""
        try:
            self.mqtt_client = mqtt.Client()
            self.mqtt_client.on_connect = self._on_mqtt_connect
            self.mqtt_client.on_message = self._on_mqtt_message
            self.mqtt_client.on_disconnect = self._on_mqtt_disconnect
            
            # Configurações de reconexão
            self.mqtt_client.reconnect_delay_set(min_delay=1, max_delay=120)
            
            # Autenticação (se configurada)
            if MQTT_CONFIG.get('username') and MQTT_CONFIG.get('password'):
                self.mqtt_client.username_pw_set(
                    MQTT_CONFIG['username'], 
                    MQTT_CONFIG['password']
                )
            
            logger.info("Cliente MQTT configurado")
            
        except Exception as e:
            logger.error(f"Erro ao configurar MQTT: {e}")
            raise
    
    def _on_mqtt_connect(self, client, userdata, flags, rc):
        """Callback de conexão MQTT"""
        if rc == 0:
            logger.info("Conectado ao broker MQTT")
            
            # Debug: mostra configuração carregada
            logger.info(f"[DEBUG] Configuração de tópicos: {MQTT_CONFIG['topics']}")
            
            # Inscreve nos tópicos
            topics = [
                (MQTT_CONFIG['topics']['sensor_data'], 0),
                (MQTT_CONFIG['topics']['status'], 0)
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
        try:
            self.stats['messages_received'] += 1
            
            # Log da mensagem recebida
            logger.info(f"[DEBUG] Mensagem MQTT recebida: {msg.topic} - {msg.payload.decode()}")
            
            # Processa diferentes tipos de mensagem
            if msg.topic.startswith('legion32/'):
                logger.info(f"[DEBUG] Processando dados do sensor: {msg.topic}")
                self._process_sensor_data(msg.topic, msg.payload.decode())
            elif msg.topic == MQTT_CONFIG['topics']['status']:
                logger.info(f"[DEBUG] Processando mensagem de status")
                self._process_status_message(msg.payload.decode())
            else:
                logger.warning(f"Tópico não reconhecido: {msg.topic}")
                
        except Exception as e:
            logger.error(f"Erro ao processar mensagem MQTT: {e}")
    
    def _process_sensor_data(self, topic: str, payload: str):
        """Processa dados de sensores"""
        try:
            logger.info(f"[DEBUG] Iniciando processamento de dados do sensor: {topic}")
            
            # Extrai ESP ID do tópico (legion32/a, legion32/b, etc.)
            esp_id = topic.split('/')[-1]
            logger.info(f"[DEBUG] ESP ID extraído: {esp_id}")
            
            # Parse do JSON
            data = json.loads(payload)
            logger.info(f"[DEBUG] Dados parseados: {data}")
            
            # Adiciona ESP ID aos dados
            data['esp_id'] = esp_id
            data['topic'] = topic
            data['received_at'] = datetime.now().isoformat()
            
            logger.info(f"[DEBUG] Chamando alert_manager.process_sensor_data para {esp_id}")
            # Processa alertas - extrai temperatura e umidade do dicionário
            temperature = data.get('temperature', 0.0)
            humidity = data.get('humidity', 0.0)
            alert = self.alert_manager.process_sensor_data(esp_id, temperature, humidity)
            
            if alert:
                self.stats['alerts_generated'] += 1
                logger.info(f"[DEBUG] ✅ Alerta gerado: {alert.alert_type} para {esp_id} - Severidade: {alert.severity}")
            else:
                logger.info(f"[DEBUG] ❌ Nenhum alerta gerado para {esp_id}")
            
            # Log dos dados processados
            logger.info(f"[DEBUG] Dados processados para {esp_id}: Temp={data.get('temperature')}°C, "
                        f"Umidade={data.get('humidity')}%")
            
        except json.JSONDecodeError as e:
            logger.error(f"Erro ao decodificar JSON: {e}")
        except Exception as e:
            logger.error(f"Erro ao processar dados do sensor: {e}")
            import traceback
            logger.error(f"Traceback: {traceback.format_exc()}")
    
    def _process_status_message(self, payload: str):
        """Processa mensagens de status"""
        try:
            data = json.loads(payload)
            esp_id = data.get('esp_id', 'unknown')
            status = data.get('status', 'unknown')
            
            logger.info(f"Status atualizado: {esp_id} - {status}")
            
            # Processa status offline/online
            if status == 'online':
                logger.info(f"Sensor {esp_id} voltou online")
            elif status == 'offline':
                logger.warning(f"Sensor {esp_id} está offline")
            
        except Exception as e:
            logger.error(f"Erro ao processar mensagem de status: {e}")
    
    def connect_mqtt(self):
        """Conecta ao broker MQTT"""
        try:
            logger.info(f"Conectando ao broker MQTT: {MQTT_CONFIG['broker']}:{MQTT_CONFIG['port']}")
            
            self.mqtt_client.connect(
                MQTT_CONFIG['broker'],
                MQTT_CONFIG['port'],
                MQTT_CONFIG['keepalive']
            )
            
            # Inicia loop em thread separada
            self.mqtt_client.loop_start()
            
        except Exception as e:
            logger.error(f"Erro ao conectar ao MQTT: {e}")
            raise
    
    def start_health_check_loop(self):
        """Inicia loop de verificação de saúde dos sensores"""
        def health_check_worker():
            while self.running:
                try:
                    time.sleep(60)  # Verifica a cada minuto
                    self.alert_manager.check_sensor_health()
                    self.stats['last_health_check'] = datetime.now()
                except Exception as e:
                    logger.error(f"Erro no health check: {e}")
        
        import threading
        health_thread = threading.Thread(target=health_check_worker, daemon=True)
        health_thread.start()
        logger.info("Thread de health check iniciada")
    
    def start_stats_reporting(self):
        """Inicia relatório de estatísticas"""
        def stats_worker():
            while self.running:
                try:
                    time.sleep(300)  # A cada 5 minutos
                    self._report_statistics()
                except Exception as e:
                    logger.error(f"Erro no relatório de estatísticas: {e}")
        
        import threading
        stats_thread = threading.Thread(target=stats_worker, daemon=True)
        stats_thread.start()
        logger.info("Thread de estatísticas iniciada")
    
    def _report_statistics(self):
        """Relata estatísticas do sistema"""
        try:
            alert_stats = self.alert_manager.get_statistics()
            
            stats_report = {
                'timestamp': datetime.now().isoformat(),
                'system_stats': self.stats,
                'alert_stats': alert_stats,
                'uptime': (datetime.now() - self.stats['start_time']).total_seconds()
            }
            
            logger.info(f"Estatísticas do sistema: {json.dumps(stats_report, indent=2)}")
            
            # Publica estatísticas no MQTT (opcional)
            if self.mqtt_client and self.mqtt_client.is_connected():
                self.mqtt_client.publish(
                    'legion32/system/stats',
                    json.dumps(stats_report)
                )
            
        except Exception as e:
            logger.error(f"Erro ao gerar relatório de estatísticas: {e}")
    
    def run(self):
        """Executa o sistema principal"""
        try:
            logger.info("=== Iniciando Sistema de Monitoramento Inteligente de Clusters ===")
            logger.info(f"Versão: 1.0")
            logger.info(f"Broker MQTT: {MQTT_CONFIG['broker']}:{MQTT_CONFIG['port']}")
            
            # Configura MQTT
            self.setup_mqtt()
            
            # Conecta ao MQTT
            self.connect_mqtt()
            
            # Inicia threads auxiliares
            self.start_health_check_loop()
            self.start_stats_reporting()
            
            logger.info("Sistema iniciado com sucesso!")
            
            # Loop principal
            while self.running:
                time.sleep(1)
                
        except KeyboardInterrupt:
            logger.info("Interrupção do teclado recebida")
        except Exception as e:
            logger.error(f"Erro no sistema principal: {e}")
        finally:
            self.shutdown()
    
    def shutdown(self):
        """Desliga o sistema de forma limpa"""
        logger.info("Iniciando shutdown do sistema...")
        
        self.running = False
        
        # Desliga MQTT
        if self.mqtt_client:
            try:
                self.mqtt_client.loop_stop()
                self.mqtt_client.disconnect()
                logger.info("Cliente MQTT desconectado")
            except Exception as e:
                logger.error(f"Erro ao desconectar MQTT: {e}")
        
        # Desliga alert manager
        try:
            self.alert_manager.shutdown()
            logger.info("Sistema de alertas desligado")
        except Exception as e:
            logger.error(f"Erro ao desligar sistema de alertas: {e}")
        
        # Relata estatísticas finais
        self._report_statistics()
        
        logger.info("Sistema desligado com sucesso")
        sys.exit(0)

# ============================================================================
# FUNÇÃO PRINCIPAL
# ============================================================================

def main():
    """Função principal"""
    try:
        # Cria e executa o sistema
        system = ClusterMonitoringSystem()
        system.run()
        
    except Exception as e:
        logger.error(f"Erro fatal no sistema: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main() 