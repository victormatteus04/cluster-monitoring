#!/usr/bin/env python3
# ============================================================================
# TESTE FORÇADO DE ALERTA - HARD EXECUTE
# Monitoramento Inteligente de Clusters - IF-UFG
# ============================================================================

import sys
from datetime import datetime
from alert_manager import AlertManager, AlertEvent

def test_hard_alert():
    """Força o envio de um alerta crítico diretamente"""
    try:
        print("=== TESTE FORÇADO DE ALERTA ===")
        
        # Cria instância do AlertManager
        alert_manager = AlertManager()
        print("✅ AlertManager inicializado")
        
        # Cria um alerta de teste crítico
        test_alert = AlertEvent(
            esp_id="test_sensor",
            alert_type="temperature_critical",
            severity="CRITICAL",
            message="🔥 TESTE: Temperatura crítica de 45°C detectada no sensor test_sensor!",
            timestamp=datetime.now(),
            data={
                "temperature": 45.0,
                "humidity": 55.0,
                "esp_id": "test_sensor",
                "test": True
            }
        )
        print(f"✅ Alerta criado: {test_alert.alert_type} - {test_alert.severity}")
        
        # Força o envio direto do e-mail (bypassa rate limiting e cooldown)
        print("📧 Enviando e-mail de alerta...")
        alert_manager.email_sender.send_alert_email(test_alert)
        print("✅ E-mail enviado com sucesso!")
        
        # Salva no banco (opcional)
        try:
            alert_manager.db_manager.save_alert(test_alert)
            print("✅ Alerta salvo no banco de dados")
        except Exception as e:
            print(f"⚠️ Erro ao salvar no banco: {e}")
        
        print("\n🎉 TESTE CONCLUÍDO COM SUCESSO!")
        print("📬 Verifique sua caixa de e-mail!")
        
        return True
        
    except Exception as e:
        print(f"❌ ERRO no teste de alerta: {e}")
        import traceback
        traceback.print_exc()
        return False

if __name__ == "__main__":
    success = test_hard_alert()
    sys.exit(0 if success else 1) 