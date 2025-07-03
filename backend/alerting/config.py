# ============================================================================
# CONFIGURAÇÃO DO SISTEMA DE ALERTAS
# Monitoramento Inteligente de Clusters - IF-UFG
# ============================================================================

import os
from datetime import timedelta

# ============================================================================
# CONFIGURAÇÕES MQTT
# ============================================================================
MQTT_CONFIG = {
    'broker': os.getenv('MQTT_BROKER', 'localhost'),
    'port': int(os.getenv('MQTT_PORT', 1883)),
    'keepalive': 60,
    'topics': {
        'sensor_data': 'legion32/+',  # legion32/a, legion32/b, etc.
        'status': 'legion32/status',
        'alerts': 'legion32/alerts'
    }
}

# ============================================================================
# CONFIGURAÇÕES DE EMAIL
# ============================================================================
EMAIL_CONFIG = {
    'smtp_server': '',
    'smtp_port': 465,
    'use_ssl': True,
    'username': '',
    'password': '',
    'from_email': '',
    'to_emails': [
        '',
        # Adicione mais emails conforme necessário
    ],
    'subject_prefix': '[ALERTA CLUSTER]'
}

# ============================================================================
# CONFIGURAÇÕES DE ALERTAS
# ============================================================================
ALERT_CONFIG = {
    # Limites de temperatura
    'temperature': {
        'critical_high': 30.0,      # Temperatura crítica alta
        'high': 27.0,               # Temperatura alta (alerta)
        'low': 15.0,                # Temperatura baixa (alerta)
        'critical_low': 5.0         # Temperatura crítica baixa
    },
    
    # Limites de umidade
    'humidity': {
        'high': 70.0,               # Umidade alta
        'low': 30.0                 # Umidade baixa
    },
    
    # Variações bruscas
    'variation': {
        'temperature': 5.0,         # Variação de temperatura em 5 min
        'humidity': 15.0            # Variação de umidade em 5 min
    },
    
    # Timeouts e cooldowns
    'cooldown': {
        'email': 300,               # 5 minutos entre emails
        'sensor_offline': 300,      # 5 minutos para considerar offline
        'variation_check': 300      # 5 minutos para verificar variações
    },
    
    # Configurações de notificação
    'notification': {
        'enable_email': True,
        'enable_mqtt': True,
        'enable_log': True,
        'retry_attempts': 3,
        'retry_delay': 60           # 1 minuto entre tentativas
    }
}

# ============================================================================
# CONFIGURAÇÕES DE LOGGING
# ============================================================================
LOGGING_CONFIG = {
    'level': 'INFO',
    'format': '%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    'file': {
        'enabled': False,
        'path': '/app/logs/cluster-alerts.log',
        'max_size': 10 * 1024 * 1024,  # 10MB
        'backup_count': 5
    },
    'console': {
        'enabled': True
    }
}

# ============================================================================
# CONFIGURAÇÕES DE BANCO DE DADOS
# ============================================================================
DATABASE_CONFIG = {
    'sqlite': {
        'path': '/app/data/alerts.db',
        'backup_enabled': True,
        'backup_interval': timedelta(hours=24)
    },
    'prometheus': {
        'enabled': True,
        'metrics_prefix': 'cluster_alert_'
    }
}

# ============================================================================
# CONFIGURAÇÕES DE MONITORAMENTO
# ============================================================================
MONITORING_CONFIG = {
    'health_check_interval': 60,    # 1 minuto
    'metrics_collection': True,
    'performance_monitoring': True,
    'memory_limit': 512 * 1024 * 1024,  # 512MB
    'cpu_limit': 50.0               # 50% CPU
}

# ============================================================================
# MENSAGENS DE ALERTA
# ============================================================================
ALERT_MESSAGES = {
    'temperature_high': {
        'title': 'Alta temperatura detectada pelo Sensor {esp_id}',
        'template': 'ALERTA: O sensor {esp_id} atingiu {temperature}°C, ultrapassando o limite de {threshold}°C estabelecido para operação segura. Verificar ventilação e refrigeração do ambiente.'
    },
    'temperature_critical': {
        'title': 'Temperatura CRÍTICA detectada pelo Sensor {esp_id}',
        'template': 'ATENÇÃO URGENTE: O sensor {esp_id} registrou temperatura crítica de {temperature}°C (limite crítico: 30°C)! Intervenção imediata necessária para evitar danos ao cluster.'
    },
    'temperature_variation': {
        'title': 'Variação brusca de temperatura pelo Sensor {esp_id}',
        'template': 'O sensor {esp_id} registrou variação de {variation}°C em 5 minutos (temperatura atual: {temperature}°C), acima do limite de {threshold}°C configurado. Verificar ventilação e refrigeração do ambiente.'
    },
    'humidity_high': {
        'title': 'Umidade alta detectada pelo Sensor {esp_id}',
        'template': 'ALERTA: O sensor {esp_id} registrou umidade de {humidity}%, acima do limite máximo de {threshold}% estabelecido. Verificar ventilação e controle de umidade no ambiente.'
    },
    'humidity_low': {
        'title': 'Umidade baixa detectada pelo Sensor {esp_id}',
        'template': 'ALERTA: O sensor {esp_id} registrou umidade de {humidity}%, abaixo do limite mínimo de {threshold}% estabelecido. Verificar sistemas de umidificação.'
    },
    'sensor_offline': {
        'title': 'Sensor {esp_id} desconectado',
        'template': 'O sensor {esp_id} não transmite dados há mais de 5 minutos. Verificar conexão de rede e alimentação.'
    },
    'sensor_online': {
        'title': 'Sensor {esp_id} reconectado',
        'template': 'O sensor {esp_id} voltou a transmitir dados normalmente.'
    },
    'sensor_back_online': {
        'title': 'Sistema restabelecido após oscilação - Sensor {esp_id}',
        'template': 'INFORMATIVO: O sensor {esp_id} voltou a funcionar após período offline (provável oscilação de energia/internet). Temperatura atual: {temperature}°C. Status completo do cluster: {sensors_status}'
    },
    'system_error': {
        'title': '⚠️ Erro no Sistema',
        'template': 'Erro detectado no sistema de monitoramento: {error}'
    }
}

# ============================================================================
# CONFIGURAÇÕES DE SEGURANÇA
# ============================================================================
SECURITY_CONFIG = {
    'rate_limiting': {
        'enabled': True,
        'max_emails_per_hour': 10,
        'max_alerts_per_minute': 5
    },
    'authentication': {
        'mqtt_username': os.getenv('MQTT_USERNAME', None),
        'mqtt_password': os.getenv('MQTT_PASSWORD', None)
    },
    'encryption': {
        'email_ssl': True,
        'mqtt_ssl': False
    }
}

# ============================================================================
# CONFIGURAÇÕES DE DESENVOLVIMENTO
# ============================================================================
# DEV_CONFIG = {
#     'debug_mode': os.getenv('DEBUG_MODE', 'false').lower() == 'true',
#     'test_mode': os.getenv('TEST_MODE', 'false').lower() == 'true',
#     'mock_sensors': os.getenv('MOCK_SENSORS', 'false').lower() == 'true',
#     'log_level': 'DEBUG' if os.getenv('DEBUG_MODE', 'false').lower() == 'true' else 'INFO'
# } 