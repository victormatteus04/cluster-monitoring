#!/usr/bin/env python3
# ============================================================================
# TESTE DE ENVIO DE EMAIL
# Monitoramento Inteligente de Clusters - IF-UFG
# ============================================================================

import smtplib
import ssl
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from config import EMAIL_CONFIG

def test_email():
    """Testa o envio de email"""
    try:
        print("=== Teste de Envio de Email ===")
        print(f"Servidor SMTP: {EMAIL_CONFIG['smtp_server']}:{EMAIL_CONFIG['smtp_port']}")
        print(f"Usuário: {EMAIL_CONFIG['username']}")
        print(f"Para: {EMAIL_CONFIG['to_emails']}")
        
        # Cria mensagem
        msg = MIMEMultipart()
        msg['From'] = EMAIL_CONFIG['from_email']
        msg['To'] = ', '.join(EMAIL_CONFIG['to_emails'])
        msg['Subject'] = f"{EMAIL_CONFIG['subject_prefix']} TESTE - Sistema de Alertas"
        
        # Corpo do email
        body = """
        <html>
        <body>
            <h2>🧪 Teste de Email - Sistema de Alertas</h2>
            <p>Este é um email de teste para verificar se o sistema de alertas está funcionando corretamente.</p>
            <p><strong>Status:</strong> ✅ Sistema operacional</p>
            <p><strong>Timestamp:</strong> Teste realizado</p>
            <hr>
            <p><em>Sistema de Monitoramento Inteligente de Clusters - IF-UFG</em></p>
        </body>
        </html>
        """
        
        msg.attach(MIMEText(body, 'html'))
        
        # Envia email
        print("Conectando ao servidor SMTP...")
        context = ssl.create_default_context()
        
        with smtplib.SMTP_SSL(EMAIL_CONFIG['smtp_server'], EMAIL_CONFIG['smtp_port'], context=context) as server:
            print("Fazendo login...")
            server.login(EMAIL_CONFIG['username'], EMAIL_CONFIG['password'])
            
            print("Enviando email...")
            server.send_message(msg)
            
        print("✅ Email enviado com sucesso!")
        return True
        
    except Exception as e:
        print(f"❌ Erro ao enviar email: {e}")
        return False

if __name__ == "__main__":
    test_email() 