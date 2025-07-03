# ============================================================================
# SISTEMA DE GERENCIAMENTO DE ALERTAS
# Monitoramento Inteligente de Clusters - IF-UFG
# ============================================================================

import json
import logging
import sqlite3
import smtplib
import ssl
from datetime import datetime, timedelta
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from typing import Dict, List, Optional, Tuple
from dataclasses import dataclass
from collections import defaultdict
import threading
import time
import requests
from email.mime.image import MIMEImage
import matplotlib
matplotlib.use('Agg')  # Use non-interactive backend
import matplotlib.pyplot as plt
import matplotlib.dates as mdates
import numpy as np
from io import BytesIO

from config import (
    MQTT_CONFIG, EMAIL_CONFIG, ALERT_CONFIG, 
    LOGGING_CONFIG, ALERT_MESSAGES, SECURITY_CONFIG
)

# ============================================================================
# ESTRUTURAS DE DADOS
# ============================================================================

@dataclass
class AlertEvent:
    """Estrutura para eventos de alerta"""
    esp_id: str
    alert_type: str
    severity: str
    message: str
    timestamp: datetime
    data: Dict
    sent: bool = False
    retry_count: int = 0

@dataclass
class TemperatureReading:
    """Leitura de temperatura com timestamp"""
    temperature: float
    timestamp: datetime

@dataclass
class SensorState:
    """Estado atual de um sensor"""
    esp_id: str
    last_seen: datetime
    temperature: float
    humidity: float
    status: str
    alert_count: int = 0
    temperature_history: List[TemperatureReading] = None
    
    def __post_init__(self):
        if self.temperature_history is None:
            self.temperature_history = []

# ============================================================================
# CONFIGURAÇÃO DE LOGGING
# ============================================================================

def setup_logging():
    """Configura o sistema de logging"""
    handlers = []
    
    if LOGGING_CONFIG['console']['enabled']:
        handlers.append(logging.StreamHandler())
    
    if LOGGING_CONFIG['file']['enabled']:
        handlers.append(logging.FileHandler(LOGGING_CONFIG['file']['path']))
    
    logging.basicConfig(
        level=getattr(logging, LOGGING_CONFIG['level']),
        format=LOGGING_CONFIG['format'],
        handlers=handlers
    )
    return logging.getLogger(__name__)

logger = setup_logging()

# ============================================================================
# CLASSE PRINCIPAL DE GERENCIAMENTO DE ALERTAS
# ============================================================================

class AlertManager:
    """Gerencia alertas e notificações do sistema de monitoramento"""
    
    def __init__(self):
        self.sensors = {}
        self.last_alert_time = {}
        self.rate_limiter = RateLimiter()
        self.db_manager = DatabaseManager()
        self.email_sender = EmailSender(self)
        
        # Threading
        self.cleanup_thread = None
        self.health_check_thread = None
        self.running = True
        
        # Blacklist de sensores de teste
        self.test_sensor_blacklist = set()
        
        # Setup inicial
        self._setup_database()
        self._restore_sensor_states()
        self._start_cleanup_thread()
        
        # APENAS sensores 'a' e 'b' são aceitos
        self.sensores_validos = {'a', 'b'}
        
        logger.info("AlertManager inicializado - Apenas sensores 'a' e 'b' serão processados")
    
    def _setup_database(self):
        """Configura o banco de dados"""
        try:
            self.db_manager.init_database()
            logger.info("Banco de dados inicializado com sucesso")
            
            # Restaura estados dos sensores após reinicialização
            self._restore_sensor_states()
        except Exception as e:
            logger.error(f"Erro ao inicializar banco de dados: {e}")
    
    def _start_cleanup_thread(self):
        """Inicia thread de limpeza de dados antigos"""
        def cleanup_worker():
            while self.running:
                try:
                    time.sleep(3600)  # 1 hora
                    self._cleanup_old_data()
                except Exception as e:
                    logger.error(f"Erro na thread de limpeza: {e}")
        
        cleanup_thread = threading.Thread(target=cleanup_worker, daemon=True)
        cleanup_thread.start()
    
    def _is_sensor_valido(self, esp_id: str) -> bool:
        """Verifica se o sensor é válido (apenas 'a' e 'b')"""
        return esp_id in self.sensores_validos

    def process_sensor_data(self, esp_id: str, temperature: float, humidity: float):
        """Processa dados do sensor"""
        try:
            # REJEITA qualquer sensor que não seja 'a' ou 'b'
            if not self._is_sensor_valido(esp_id):
                logger.warning(f"🚫 Sensor '{esp_id}' REJEITADO - Apenas sensores 'a' e 'b' são aceitos")
                return None
            
            logger.info(f"[DEBUG] Processando dados do sensor {esp_id}: Temp={temperature}°C, Umidade={humidity}%")
            
            # Atualiza estado do sensor
            self._update_sensor_state(esp_id, temperature, humidity)
            
            # Prepara dados para verificação de alertas
            data = {
                'temperature': temperature,
                'humidity': humidity,
                'esp_id': esp_id
            }
            
            # Detecta alertas
            alert = self._check_alerts(esp_id, data)
            
            # Processa alerta se detectado
            if alert:
                self._handle_alert(alert)
                logger.info(f"[DEBUG] ✅ Alerta gerado: {alert.alert_type} para {esp_id} - Severidade: {alert.severity}")
            else:
                logger.info(f"[DEBUG] ❌ Nenhum alerta gerado para {esp_id}")
                
            logger.info(f"[DEBUG] Dados processados para {esp_id}: Temp={temperature}°C, Umidade={humidity}%")
            
            return alert
            
        except Exception as e:
            logger.error(f"Erro ao processar dados do sensor {esp_id}: {e}")
            import traceback
            logger.error(f"Traceback: {traceback.format_exc()}")
            return None
    
    def _update_sensor_state(self, esp_id: str, temperature: float, humidity: float):
        """Atualiza o estado de um sensor"""
        now = datetime.now()
        
        if esp_id not in self.sensors:
            self.sensors[esp_id] = SensorState(
                esp_id=esp_id,
                last_seen=now,
                temperature=temperature,
                humidity=humidity,
                status='online'
            )
        else:
            sensor = self.sensors[esp_id]
            
            # Verifica se o sensor estava offline e agora voltou online
            was_offline = sensor.status == 'offline'
            
            sensor.last_seen = now
            sensor.temperature = temperature
            sensor.humidity = humidity
            sensor.status = 'online'
            
            # Se o sensor estava offline e agora voltou, envia alerta de retorno
            if was_offline:
                self._handle_sensor_back_online(esp_id, temperature)
        
        # Adiciona temperatura ao histórico
        self._add_temperature_to_history(esp_id, temperature, now)
        
        # Salva estado atualizado no banco
        self._save_sensor_state(esp_id)
    
    def _handle_sensor_back_online(self, esp_id: str, temperature: float):
        """Lida com sensor voltando online após estar offline"""
        logger.info(f"[DEBUG] Sensor {esp_id} voltou online após estar offline")
        
        # Gera status completo do cluster
        sensors_status = self._get_cluster_status()
        
        # Cria alerta informativo
        back_online_alert = AlertEvent(
            esp_id=esp_id,
            alert_type='sensor_back_online',
            severity='LOW',
            message=ALERT_MESSAGES['sensor_back_online']['template'].format(
                esp_id=esp_id,
                temperature=temperature,
                sensors_status=sensors_status
            ),
            timestamp=datetime.now(),
            data={
                'temperature': temperature,
                'sensors_status': sensors_status,
                'custom_title': ALERT_MESSAGES['sensor_back_online']['title'].format(esp_id=esp_id)
            }
        )
        
        # Envia alerta
        self._handle_alert(back_online_alert)
    
    def _get_cluster_status(self) -> str:
        """Retorna status formatado de todos os sensores do cluster"""
        status_lines = []
        
        for esp_id, sensor in self.sensors.items():
            status_emoji = "🟢" if sensor.status == 'online' else "🔴"
            status_lines.append(
                f"{status_emoji} Sensor {esp_id}: {sensor.temperature:.1f}°C, "
                f"{sensor.humidity:.1f}% ({sensor.status})"
            )
        
        if not status_lines:
            return "Nenhum sensor registrado no sistema"
        
        return " | ".join(status_lines)
    
    def _restore_sensor_states(self):
        """Restaura estados dos sensores do banco de dados após reinicialização"""
        try:
            restored_sensors = self.db_manager.load_sensor_states()
            now = datetime.now()
            
            for sensor_data in restored_sensors:
                esp_id = sensor_data['esp_id']
                last_seen = datetime.fromisoformat(sensor_data['last_seen'])
                
                # Verifica se sensor deveria estar offline (mais de 5 min sem dados)
                time_since_last_seen = (now - last_seen).total_seconds()
                offline_threshold = ALERT_CONFIG['cooldown']['sensor_offline']
                
                # Cria estado do sensor
                sensor_state = SensorState(
                    esp_id=esp_id,
                    last_seen=last_seen,
                    temperature=sensor_data['temperature'],
                    humidity=sensor_data['humidity'],
                    status='offline' if time_since_last_seen > offline_threshold else 'online',
                    alert_count=sensor_data.get('alert_count', 0)
                )
                
                self.sensors[esp_id] = sensor_state
                logger.info(f"[DEBUG] Sensor {esp_id} restaurado: {sensor_state.status} (última vez visto: {last_seen})")
            
            logger.info(f"[DEBUG] Restaurados {len(restored_sensors)} sensores do banco de dados")
            
        except Exception as e:
            logger.error(f"Erro ao restaurar estados dos sensores: {e}")
    
    def _save_sensor_state(self, esp_id: str):
        """Salva estado atual do sensor no banco de dados"""
        try:
            if esp_id in self.sensors:
                sensor = self.sensors[esp_id]
                self.db_manager.save_sensor_state(sensor)
        except Exception as e:
            logger.error(f"Erro ao salvar estado do sensor {esp_id}: {e}")
    
    def _add_temperature_to_history(self, esp_id: str, temperature: float, timestamp: datetime):
        """Adiciona leitura de temperatura ao histórico do sensor"""
        sensor = self.sensors[esp_id]
        
        # Adiciona nova leitura
        sensor.temperature_history.append(TemperatureReading(temperature, timestamp))
        
        # Mantém apenas últimos 5 minutos + margem de segurança
        cutoff_time = timestamp - timedelta(minutes=6)
        sensor.temperature_history = [
            reading for reading in sensor.temperature_history 
            if reading.timestamp > cutoff_time
        ]
        
        logger.debug(f"Histórico de {esp_id}: {len(sensor.temperature_history)} leituras")
    
    def _calculate_temperature_variation_5min(self, esp_id: str) -> float:
        """Calcula a variação de temperatura nos últimos 5 minutos"""
        logger.info(f"[DEBUG] _calculate_temperature_variation_5min iniciado para {esp_id}")
        
        if esp_id not in self.sensors:
            logger.info(f"[DEBUG] Sensor {esp_id} não encontrado nos sensores")
            return 0.0
        
        sensor = self.sensors[esp_id]
        history = sensor.temperature_history
        
        logger.info(f"[DEBUG] Histórico do sensor {esp_id}: {len(history)} leituras")
        
        if len(history) < 2:
            logger.info(f"[DEBUG] Histórico insuficiente para {esp_id}: apenas {len(history)} leituras")
            return 0.0
        
        # Janela de 5 minutos
        now = datetime.now()
        five_minutes_ago = now - timedelta(minutes=5)
        
        # Filtra leituras dos últimos 5 minutos
        recent_readings = [
            reading for reading in history 
            if reading.timestamp >= five_minutes_ago
        ]
        
        logger.info(f"[DEBUG] Leituras dos últimos 5min para {esp_id}: {len(recent_readings)} de {len(history)} total")
        
        if len(recent_readings) < 2:
            logger.info(f"[DEBUG] Leituras recentes insuficientes para {esp_id}: apenas {len(recent_readings)}")
            # Debug: mostrar timestamps das leituras
            for i, reading in enumerate(history):
                logger.info(f"[DEBUG] Leitura {i}: {reading.temperature}°C em {reading.timestamp}")
            return 0.0
        
        # Encontra temperaturas mínima e máxima na janela
        temperatures = [reading.temperature for reading in recent_readings]
        min_temp = min(temperatures)
        max_temp = max(temperatures)
        
        variation = max_temp - min_temp
        
        logger.info(f"[DEBUG] Variação calculada para {esp_id}: {variation:.2f}°C (min: {min_temp:.2f}°C, max: {max_temp:.2f}°C)")
        
        # Debug: mostrar todas as leituras recentes
        for i, reading in enumerate(recent_readings):
            logger.info(f"[DEBUG] Leitura recente {i}: {reading.temperature}°C em {reading.timestamp}")
        
        return variation
    
    def _check_alerts(self, esp_id: str, data: Dict) -> Optional[AlertEvent]:
        """Verifica se há condições de alerta"""
        logger.info(f"[DEBUG] _check_alerts iniciado para {esp_id}")
        
        temperature = data.get('temperature')
        humidity = data.get('humidity')
        
        logger.info(f"[DEBUG] Temperatura: {temperature}°C, Umidade: {humidity}%")
        logger.info(f"[DEBUG] Limites configurados - Temp HIGH: {ALERT_CONFIG['temperature']['high']}°C, CRITICAL: {ALERT_CONFIG['temperature']['critical_high']}°C")
        
        if temperature is None or humidity is None:
            logger.warning(f"[DEBUG] Dados inválidos - temperatura ou umidade ausente")
            return None
        
        alerts = []
        
        # Verifica temperatura
        logger.info(f"[DEBUG] Verificando limites de temperatura...")
        if temperature >= ALERT_CONFIG['temperature']['critical_high']:
            logger.info(f"[DEBUG] 🔥 Temperatura CRÍTICA detectada: {temperature}°C >= {ALERT_CONFIG['temperature']['critical_high']}°C")
            alerts.append(self._create_alert(esp_id, 'temperature_critical', 'CRITICAL', data))
        elif temperature >= ALERT_CONFIG['temperature']['high']:
            logger.info(f"[DEBUG] 🌡️ Temperatura ALTA detectada: {temperature}°C >= {ALERT_CONFIG['temperature']['high']}°C")
            alerts.append(self._create_alert(esp_id, 'temperature_high', 'HIGH', data))
        elif temperature <= ALERT_CONFIG['temperature']['critical_low']:
            logger.info(f"[DEBUG] 🧊 Temperatura CRÍTICA BAIXA detectada: {temperature}°C <= {ALERT_CONFIG['temperature']['critical_low']}°C")
            alerts.append(self._create_alert(esp_id, 'temperature_critical', 'CRITICAL', data))
        elif temperature <= ALERT_CONFIG['temperature']['low']:
            logger.info(f"[DEBUG] ❄️ Temperatura BAIXA detectada: {temperature}°C <= {ALERT_CONFIG['temperature']['low']}°C")
            alerts.append(self._create_alert(esp_id, 'temperature_low', 'HIGH', data))
        else:
            logger.info(f"[DEBUG] ✅ Temperatura dentro dos limites normais: {temperature}°C")
        
        # Verifica umidade
        logger.info(f"[DEBUG] Verificando limites de umidade...")
        if humidity >= ALERT_CONFIG['humidity']['high']:
            logger.info(f"[DEBUG] 💧 Umidade ALTA detectada: {humidity}% >= {ALERT_CONFIG['humidity']['high']}%")
            alerts.append(self._create_alert(esp_id, 'humidity_high', 'MEDIUM', data))
        elif humidity <= ALERT_CONFIG['humidity']['low']:
            logger.info(f"[DEBUG] 🏜️ Umidade BAIXA detectada: {humidity}% <= {ALERT_CONFIG['humidity']['low']}%")
            alerts.append(self._create_alert(esp_id, 'humidity_low', 'MEDIUM', data))
        else:
            logger.info(f"[DEBUG] ✅ Umidade dentro dos limites normais: {humidity}%")
        
        # Verifica variações bruscas (calcula no backend)
        variation = self._calculate_temperature_variation_5min(esp_id)
        logger.info(f"[DEBUG] Verificando variação de temperatura: {variation}°C")
        if variation >= ALERT_CONFIG['variation']['temperature']:
            logger.info(f"[DEBUG] 📈 Variação BRUSCA detectada: {variation}°C >= {ALERT_CONFIG['variation']['temperature']}°C")
            # Adiciona variação aos dados para usar na mensagem
            data_with_variation = data.copy()
            data_with_variation['temperature_variation'] = variation
            alerts.append(self._create_alert(esp_id, 'temperature_variation', 'HIGH', data_with_variation))
        
        logger.info(f"[DEBUG] Total de alertas detectados: {len(alerts)}")
        
        # Retorna o alerta mais crítico
        if alerts:
            critical_alert = max(alerts, key=lambda x: self._get_severity_level(x.severity))
            logger.info(f"[DEBUG] Alerta mais crítico selecionado: {critical_alert.alert_type} - {critical_alert.severity}")
            return critical_alert
        
        return None
    
    def _create_alert(self, esp_id: str, alert_type: str, severity: str, data: Dict) -> AlertEvent:
        """Cria um evento de alerta"""
        message_template = ALERT_MESSAGES.get(alert_type, {})
        title = message_template.get('title', 'Alerta')
        template = message_template.get('template', 'Alerta no sensor {esp_id}')
        
        # Determina o threshold baseado no tipo de alerta
        if 'temperature' in alert_type and 'variation' not in alert_type:
            threshold = ALERT_CONFIG['temperature']['high']
        elif 'humidity' in alert_type:
            threshold = ALERT_CONFIG['humidity']['high'] if 'high' in alert_type else ALERT_CONFIG['humidity']['low']
        else:
            threshold = ALERT_CONFIG['variation']['temperature']
        
        # Formata a mensagem e título
        format_data = {
            'esp_id': esp_id,
            'temperature': data.get('temperature', 0),
            'humidity': data.get('humidity', 0),
            'threshold': threshold,
            'variation': data.get('temperature_variation', 0)
        }
        
        message = template.format(**format_data)
        formatted_title = title.format(**format_data)
        
        alert = AlertEvent(
            esp_id=esp_id,
            alert_type=alert_type,
            severity=severity,
            message=message,
            timestamp=datetime.now(),
            data=data
        )
        
        # Adiciona título personalizado ao data para usar no email
        alert.data['custom_title'] = formatted_title
        
        return alert
    
    def _get_severity_level(self, severity: str) -> int:
        """Retorna nível numérico da severidade"""
        levels = {'LOW': 1, 'MEDIUM': 2, 'HIGH': 3, 'CRITICAL': 4}
        return levels.get(severity, 0)
    
    def _handle_alert(self, alert: AlertEvent):
        """Processa um alerta"""
        try:
            logger.info(f"[DEBUG] _handle_alert iniciado para {alert.esp_id} - {alert.alert_type} - {alert.severity}")
            
            # Verifica rate limiting
            logger.info(f"[DEBUG] Verificando rate limiting...")
            if not self.rate_limiter.can_send_alert(alert.esp_id, alert.alert_type):
                logger.warning(f"[DEBUG] ⚠️ Rate limit atingido para {alert.esp_id}")
                return
            logger.info(f"[DEBUG] ✅ Rate limiting OK")
            
            # Verifica cooldown de email
            logger.info(f"[DEBUG] Verificando cooldown de email...")
            if not self._can_send_email(alert.esp_id, alert.alert_type):
                logger.info(f"[DEBUG] ⚠️ Cooldown ativo para {alert.esp_id}")
                return
            logger.info(f"[DEBUG] ✅ Cooldown OK")
            
            # Salva no banco de dados
            logger.info(f"[DEBUG] Salvando alerta no banco de dados...")
            self.db_manager.save_alert(alert)
            logger.info(f"[DEBUG] ✅ Alerta salvo no banco")
            
            # Envia notificações
            logger.info(f"[DEBUG] Enviando notificações...")
            self._send_notifications(alert)
            
            # Atualiza histórico
            self.last_alert_time[alert.esp_id] = datetime.now()
            
            logger.info(f"[DEBUG] ✅ Alerta processado com sucesso: {alert.alert_type} para {alert.esp_id}")
            
        except Exception as e:
            logger.error(f"[DEBUG] ❌ Erro ao processar alerta: {e}")
            import traceback
            logger.error(f"Traceback: {traceback.format_exc()}")
    
    def _can_send_email(self, esp_id: str, alert_type: str) -> bool:
        """Verifica se pode enviar email (cooldown)"""
        key = f"{esp_id}_{alert_type}"
        last_sent = self.last_alert_time.get(esp_id)
        
        if last_sent is None:
            return True
        
        cooldown_time = ALERT_CONFIG['cooldown']['email']
        return (datetime.now() - last_sent).total_seconds() >= cooldown_time
    
    def _is_test_sensor(self, esp_id: str) -> bool:
        """Verifica se é um sensor de teste que não deve enviar email"""
        return esp_id in self.test_sensor_blacklist or esp_id.startswith('test_')
    
    def _send_notifications(self, alert: AlertEvent):
        """Envia notificações de alerta"""
        try:
            logger.info(f"[DEBUG] _send_notifications iniciado para {alert.esp_id} - {alert.alert_type}")
            
            # Dupla verificação - só sensores válidos chegam aqui
            if not self._is_sensor_valido(alert.esp_id):
                logger.error(f"🚫 ERRO: Sensor inválido '{alert.esp_id}' chegou ao envio de notificação")
                return
            
            # Verifica cooldown
            if not self._can_send_email(alert.esp_id, alert.alert_type):
                logger.info(f"[DEBUG] ⏳ Cooldown ativo para {alert.esp_id} - {alert.alert_type}")
                return
            
            # Envia email
            self.email_sender.send_alert_email(alert)
            alert.sent = True
            
            # Atualiza cooldown
            self._update_email_cooldown(alert.esp_id, alert.alert_type)
            
            logger.info(f"[DEBUG] ✅ Email enviado com sucesso para sensor {alert.esp_id}")
            
        except Exception as e:
            logger.error(f"Erro ao enviar notificações: {e}")
            alert.retry_count += 1
    
    def _update_email_cooldown(self, esp_id: str, alert_type: str):
        """Atualiza cooldown de email"""
        self.last_alert_time[esp_id] = datetime.now()
    
    def check_sensor_health(self):
        """Verifica saúde dos sensores (offline)"""
        now = datetime.now()
        offline_threshold = ALERT_CONFIG['cooldown']['sensor_offline']
        
        for esp_id, sensor in self.sensors.items():
            if sensor.status == 'online':
                time_since_last_seen = (now - sensor.last_seen).total_seconds()
                
                if time_since_last_seen > offline_threshold:
                    sensor.status = 'offline'
                    offline_alert = AlertEvent(
                        esp_id=esp_id,
                        alert_type='sensor_offline',
                        severity='HIGH',
                        message=ALERT_MESSAGES['sensor_offline']['template'].format(esp_id=esp_id),
                        timestamp=now,
                        data={
                            'last_seen': sensor.last_seen.isoformat(),
                            'custom_title': ALERT_MESSAGES['sensor_offline']['title'].format(esp_id=esp_id)
                        }
                    )
                    self._handle_alert(offline_alert)
    
    def _cleanup_old_data(self):
        """Remove dados antigos"""
        try:
            # Remove alertas antigos (mais de 30 dias)
            cutoff_date = datetime.now() - timedelta(days=30)
            self.last_alert_time = {k: v for k, v in self.last_alert_time.items() if v > cutoff_date}
            
            # Limpa cooldowns antigos
            now = datetime.now()
            self.last_alert_time = {k: v for k, v in self.last_alert_time.items() if (now - v).total_seconds() < 3600}  # 1 hora
            
            logger.info("Limpeza de dados antigos concluída")
            
        except Exception as e:
            logger.error(f"Erro na limpeza de dados: {e}")
    
    def get_statistics(self) -> Dict:
        """Retorna estatísticas do sistema"""
        return {
            'total_sensors': len(self.sensors),
            'online_sensors': len([s for s in self.sensors.values() if s.status == 'online']),
            'total_alerts': len(self.last_alert_time),
            'alerts_today': len([a for a in self.last_alert_time if a.date() == datetime.now().date()]),
            'rate_limiter_stats': self.rate_limiter.get_stats()
        }
    
    def shutdown(self):
        """Desliga o sistema de alertas"""
        self.running = False
        logger.info("Sistema de alertas desligado")

# ============================================================================
# CLASSES AUXILIARES
# ============================================================================

class RateLimiter:
    """Controla rate limiting de alertas"""
    
    def __init__(self):
        self.alert_counts = defaultdict(list)
        self.lock = threading.Lock()
    
    def can_send_alert(self, esp_id: str, alert_type: str) -> bool:
        """Verifica se pode enviar alerta"""
        with self.lock:
            now = datetime.now()
            key = f"{esp_id}_{alert_type}"
            
            # Remove alertas antigos (última hora)
            cutoff = now - timedelta(hours=1)
            self.alert_counts[key] = [t for t in self.alert_counts[key] if t > cutoff]
            
            # Verifica limite
            max_alerts = SECURITY_CONFIG['rate_limiting']['max_emails_per_hour']
            if len(self.alert_counts[key]) >= max_alerts:
                return False
            
            # Adiciona novo alerta
            self.alert_counts[key].append(now)
            return True
    
    def get_stats(self) -> Dict:
        """Retorna estatísticas do rate limiter"""
        with self.lock:
            return {
                'active_limits': len(self.alert_counts),
                'total_limited_keys': sum(1 for v in self.alert_counts.values() if len(v) > 0)
            }

class DatabaseManager:
    """Gerencia operações de banco de dados"""
    
    def __init__(self):
        self.db_path = '/app/data/alerts.db'
    
    def init_database(self):
        """Inicializa o banco de dados"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS alerts (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                esp_id TEXT NOT NULL,
                alert_type TEXT NOT NULL,
                severity TEXT NOT NULL,
                message TEXT NOT NULL,
                timestamp TEXT NOT NULL,
                data TEXT,
                sent INTEGER DEFAULT 0,
                retry_count INTEGER DEFAULT 0
            )
        ''')
        
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS sensor_states (
                esp_id TEXT PRIMARY KEY,
                last_seen TEXT NOT NULL,
                temperature REAL,
                humidity REAL,
                status TEXT NOT NULL,
                alert_count INTEGER DEFAULT 0,
                updated_at TEXT NOT NULL
            )
        ''')
        
        conn.commit()
        conn.close()
    
    def save_alert(self, alert: AlertEvent):
        """Salva alerta no banco de dados"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute('''
            INSERT INTO alerts (esp_id, alert_type, severity, message, timestamp, data, sent)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        ''', (
            alert.esp_id,
            alert.alert_type,
            alert.severity,
            alert.message,
            alert.timestamp.isoformat(),
            json.dumps(alert.data),
            1 if alert.sent else 0
        ))
        
        conn.commit()
        conn.close()
    
    def save_sensor_state(self, sensor: SensorState):
        """Salva estado do sensor no banco de dados"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute('''
            INSERT OR REPLACE INTO sensor_states 
            (esp_id, last_seen, temperature, humidity, status, alert_count, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        ''', (
            sensor.esp_id,
            sensor.last_seen.isoformat(),
            sensor.temperature,
            sensor.humidity,
            sensor.status,
            sensor.alert_count,
            datetime.now().isoformat()
        ))
        
        conn.commit()
        conn.close()
    
    def load_sensor_states(self) -> List[Dict]:
        """Carrega todos os estados dos sensores do banco de dados"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute('''
            SELECT esp_id, last_seen, temperature, humidity, status, alert_count, updated_at
            FROM sensor_states
            ORDER BY updated_at DESC
        ''')
        
        rows = cursor.fetchall()
        conn.close()
        
        sensors = []
        for row in rows:
            sensors.append({
                'esp_id': row[0],
                'last_seen': row[1],
                'temperature': row[2],
                'humidity': row[3],
                'status': row[4],
                'alert_count': row[5],
                'updated_at': row[6]
            })
        
        return sensors

def gerar_grafico_temperatura(sensor_data: Dict[str, SensorState], periodo_minutos=10):
    """
    Gera gráfico de temperatura dos últimos minutos usando matplotlib
    
    Args:
        sensor_data: Dicionário com dados dos sensores
        periodo_minutos: Período em minutos para mostrar no gráfico
    
    Returns:
        bytes: Imagem PNG do gráfico
    """
    try:
        logger.info(f"Gerando gráfico de temperatura (últimos {periodo_minutos} minutos)")
        
        # Configura o gráfico
        plt.style.use('default')
        fig, ax = plt.subplots(figsize=(12, 6))
        
        # Cor de fundo
        fig.patch.set_facecolor('white')
        ax.set_facecolor('#f8f9fa')
        
        # Timestamp de corte
        agora = datetime.now()
        tempo_corte = agora - timedelta(minutes=periodo_minutos)
        
        # Plota dados de cada sensor
        cores = {'a': '#ff6b6b', 'b': '#4ecdc4', 'test_dashboard': '#45b7d1', 'test_dashboard_var': '#96ceb4'}
        
        sensores_plotados = 0
        
        for esp_id, sensor in sensor_data.items():
            if not sensor.temperature_history:
                continue
                
            # Filtra dados do período
            temperaturas = []
            timestamps = []
            
            for reading in sensor.temperature_history:
                if reading.timestamp >= tempo_corte:
                    temperaturas.append(reading.temperature)
                    timestamps.append(reading.timestamp)
            
            if len(temperaturas) < 2:
                continue
                
            # Plota linha do sensor
            cor = cores.get(esp_id, '#555555')
            ax.plot(timestamps, temperaturas, 
                   marker='o', markersize=4, linewidth=2, 
                   color=cor, label=f'Sensor {esp_id.upper()}', alpha=0.8)
            
            sensores_plotados += 1
        
        # Se não há dados, criar gráfico vazio com mensagem
        if sensores_plotados == 0:
            ax.text(0.5, 0.5, f'📊 Aguardando dados de temperatura\n(últimos {periodo_minutos} minutos)', 
                   transform=ax.transAxes, fontsize=14, ha='center', va='center',
                   bbox=dict(boxstyle="round,pad=0.3", facecolor='lightgray', alpha=0.5))
            
            # Configura eixos vazios
            ax.set_xlim(tempo_corte, agora)
            ax.set_ylim(15, 35)
        else:
            # Formata eixo X (tempo)
            ax.xaxis.set_major_formatter(mdates.DateFormatter('%H:%M'))
            ax.xaxis.set_major_locator(mdates.MinuteLocator(interval=2))
            plt.setp(ax.xaxis.get_majorticklabels(), rotation=45)
            
            # Adiciona grade
            ax.grid(True, alpha=0.3, linestyle='--')
            
            # Adiciona legenda
            if sensores_plotados > 1:
                ax.legend(loc='upper left', frameon=True, fancybox=True, shadow=True)
        
        # Configurações do gráfico
        ax.set_xlabel('Horário', fontsize=12, fontweight='bold')
        ax.set_ylabel('Temperatura (°C)', fontsize=12, fontweight='bold')
        ax.set_title(f'📈 Temperatura dos Sensores - Últimos {periodo_minutos} minutos', 
                    fontsize=14, fontweight='bold', pad=20)
        
        # Adiciona timestamp
        timestamp_str = agora.strftime('%d/%m/%Y %H:%M:%S')
        ax.text(0.99, 0.01, f'Gerado em {timestamp_str}', 
               transform=ax.transAxes, fontsize=8, ha='right', va='bottom',
               bbox=dict(boxstyle="round,pad=0.2", facecolor='white', alpha=0.8))
        
        # Ajusta layout
        plt.tight_layout()
        
        # Salva em buffer
        buffer = BytesIO()
        plt.savefig(buffer, format='png', dpi=150, bbox_inches='tight', 
                   facecolor='white', edgecolor='none')
        buffer.seek(0)
        
        # Pega os bytes
        imagem_bytes = buffer.getvalue()
        
        # Limpa recursos
        plt.close(fig)
        buffer.close()
        
        logger.info(f"Gráfico gerado com sucesso! Tamanho: {len(imagem_bytes)} bytes")
        return imagem_bytes
        
    except Exception as e:
        logger.error(f"Erro ao gerar gráfico de temperatura: {e}")
        return None

class EmailSender:
    """Gerencia envio de emails"""
    
    def __init__(self, alert_manager=None):
        self.config = EMAIL_CONFIG
        self.alert_manager = alert_manager
    
    def _get_graph_period(self, alert_type: str) -> int:
        """Retorna o período em minutos do gráfico baseado no tipo de alerta"""
        periods = {
            'temperature': 10,     # 10 minutos para alertas de temperatura
            'humidity': 10,        # 10 minutos para alertas de umidade 
            'variation': 15,       # 15 minutos para alertas de variação
            'offline': 30,         # 30 minutos para alertas de offline
            'back_online': 10      # 10 minutos para alertas de volta online
        }
        return periods.get(alert_type, 10)  # Padrão: 10 minutos
    
    def send_alert_email(self, alert: AlertEvent):
        """Envia email de alerta"""
        try:
            msg = MIMEMultipart()
            msg['From'] = self.config['from_email']
            msg['To'] = ', '.join(self.config['to_emails'])
            
            # Usa título personalizado se disponível
            custom_title = alert.data.get('custom_title', f"{alert.severity}: {alert.esp_id}")
            msg['Subject'] = f"{self.config['subject_prefix']} {custom_title}"
            
            # Determina período do gráfico
            graph_period = self._get_graph_period(alert.alert_type)
            
            # Corpo do email
            body = f"""
            <html>
            <body style="font-family: Arial, sans-serif; max-width: 800px; margin: 0 auto;">
                <div style="background-color: #f8f9fa; padding: 20px; border-radius: 8px; border-left: 4px solid #dc3545;">
                    <h2 style="color: #dc3545; margin-top: 0;">🚨 {alert.message}</h2>
                    
                    <div style="background-color: white; padding: 15px; border-radius: 5px; margin: 15px 0;">
                        <table style="width: 100%; border-collapse: collapse;">
                            <tr>
                                <td style="padding: 8px; border-bottom: 1px solid #eee; font-weight: bold;">Sensor:</td>
                                <td style="padding: 8px; border-bottom: 1px solid #eee;">{alert.esp_id}</td>
                            </tr>
                            <tr>
                                <td style="padding: 8px; border-bottom: 1px solid #eee; font-weight: bold;">Tipo:</td>
                                <td style="padding: 8px; border-bottom: 1px solid #eee;">{alert.alert_type}</td>
                            </tr>
                            <tr>
                                <td style="padding: 8px; border-bottom: 1px solid #eee; font-weight: bold;">Severidade:</td>
                                <td style="padding: 8px; border-bottom: 1px solid #eee;"><span style="color: #dc3545; font-weight: bold;">{alert.severity}</span></td>
                            </tr>
                            <tr>
                                <td style="padding: 8px; font-weight: bold;">Timestamp:</td>
                                <td style="padding: 8px;">{alert.timestamp.strftime('%Y-%m-%d %H:%M:%S')}</td>
                            </tr>
                        </table>
                    </div>
                    
                    <div style="background-color: white; padding: 15px; border-radius: 5px; margin: 15px 0;">
                        <h3 style="color: #495057; margin-top: 0;">📊 Gráfico de Temperatura (últimos {graph_period} minutos)</h3>
                        <div style="text-align: center; margin: 20px 0;">
                            <img src="cid:grafico_temperatura" alt="Gráfico de Temperatura" style="max-width: 100%; height: auto; border: 1px solid #ddd; border-radius: 5px;"/>
                        </div>
                        <p style="color: #6c757d; font-size: 0.9em; text-align: center;">
                            <em>Gráfico mostra os últimos {graph_period} minutos de temperatura de todos os sensores</em>
                        </p>
                    </div>
                    
                    <div style="background-color: #e9ecef; padding: 10px; border-radius: 5px; margin-top: 20px;">
                        <p style="margin: 0; font-size: 0.9em; color: #495057;">
                            <strong>Sistema de Monitoramento Inteligente de Clusters - IF-UFG</strong><br>
                            <em>Email enviado automaticamente em {alert.timestamp.strftime('%d/%m/%Y às %H:%M:%S')}</em>
                        </p>
                    </div>
                </div>
            </body>
            </html>
            """
            
            msg.attach(MIMEText(body, 'html'))
            
            # Gerar e anexar gráfico
            logger.info(f"Preparando gráfico para email (período: {graph_period} minutos)")
            
            if self.alert_manager:
                grafico = gerar_grafico_temperatura(self.alert_manager.sensors, graph_period)
                if grafico:
                    mime_img = MIMEImage(grafico)
                    mime_img.add_header('Content-ID', '<grafico_temperatura>')
                    mime_img.add_header('Content-Disposition', 'inline', filename='temperatura.png')
                    msg.attach(mime_img)
                    logger.info("Gráfico anexado ao email com sucesso")
                else:
                    logger.warning("Não foi possível gerar o gráfico de temperatura")
                    # Adiciona mensagem no corpo informando que não foi possível gerar o gráfico
                    body = body.replace(
                        '<img src="cid:grafico_temperatura"',
                        '<p style="color: #dc3545; text-align: center; font-weight: bold;">⚠️ Não foi possível carregar o gráfico de temperatura</p><img src="cid:grafico_temperatura" style="display: none;"'
                    )
                    msg.set_payload([MIMEText(body, 'html')])
            else:
                logger.warning("Alert manager não disponível para gerar gráfico")
            
            # Envia email
            context = ssl.create_default_context()
            with smtplib.SMTP_SSL(self.config['smtp_server'], self.config['smtp_port'], context=context) as server:
                server.login(self.config['username'], self.config['password'])
                server.send_message(msg)
            
            logger.info(f"Email de alerta enviado para {alert.esp_id} com gráfico de {graph_period} minutos")
            
        except Exception as e:
            logger.error(f"Erro ao enviar email: {e}")
            raise 

 