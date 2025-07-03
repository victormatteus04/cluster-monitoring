# 📊 Dashboard de Temperatura no Email

## 📋 Resumo

O sistema de monitoramento foi aprimorado para incluir **gráficos de temperatura** nos emails de alerta, proporcionando contexto visual completo sobre as condições do cluster no momento do alerta.

## 🎯 Funcionalidades

### ✅ **Gráficos Automáticos**
- Gráfico de linha da temperatura de todos os sensores
- Anexado automaticamente a todos os emails de alerta
- Qualidade alta (1200x600px) otimizada para visualização

### ✅ **Períodos Inteligentes**
Diferentes períodos de histórico baseados no tipo de alerta:

| Tipo de Alerta | Período do Gráfico | Justificativa |
|---|---|---|
| **Temperatura Alta/Baixa** | 2 horas | Mostra tendência da temperatura |
| **Variação de Temperatura** | 1 hora | Foca no período da variação |
| **Sensor Offline** | 6 horas | Contexto amplo antes da queda |
| **Sensor Volta Online** | 2 horas | Mostra recuperação do sensor |

### ✅ **Layout Profissional**
- Design responsivo e moderno
- Cores e tipografia otimizadas
- Tabela organizada com informações do alerta
- Tratamento de erro se gráfico não carregar

## 🔧 Implementação Técnica

### **Backend: Integração com Grafana**

```python
def baixar_grafico_temperatura(periodo_horas=2):
    """Baixa gráfico de temperatura do Grafana"""
    headers = {"Authorization": f"Bearer {GRAFANA_API_KEY}"}
    params = {
        "panelId": 3,                    # Painel de timeseries
        "from": f"now-{periodo_horas}h", # Período dinâmico
        "to": "now",
        "width": 1200,                   # Alta qualidade
        "height": 600,
        "theme": "light"                 # Tema claro para email
    }
    
    response = requests.get(
        f"{GRAFANA_URL}/render/d-solo/{GRAFANA_DASH_UID}",
        headers=headers,
        params=params,
        timeout=30
    )
    
    return response.content if response.status_code == 200 else None
```

### **Email: Layout HTML Responsivo**

```html
<div style="background-color: white; padding: 15px; border-radius: 5px;">
    <h3>📊 Gráfico de Temperatura (últimas 2h)</h3>
    <div style="text-align: center; margin: 20px 0;">
        <img src="cid:grafico_temperatura" 
             alt="Gráfico de Temperatura" 
             style="max-width: 100%; height: auto; border: 1px solid #ddd;"/>
    </div>
    <p style="color: #6c757d; font-size: 0.9em; text-align: center;">
        <em>Gráfico mostra as últimas 2 horas de temperatura de todos os sensores</em>
    </p>
</div>
```

## 🧪 Como Testar

### **1. Aplicar as Melhorias**
```bash
chmod +x apply_dashboard_email.sh
./apply_dashboard_email.sh
```

### **2. Executar Testes**
```bash
python3 test_dashboard_email.py
```

### **3. Verificar Resultados**
- ✅ Gráfico baixado diretamente do Grafana
- ✅ Email com alerta de temperatura alta (2h de histórico)
- ✅ Email com alerta de variação (1h de histórico)
- ✅ Arquivo `temp_graph_test.png` salvo localmente

## 📧 Exemplo de Email

```
🚨 O sensor test_dashboard registrou temperatura alta de 33.5°C

┌─────────────────────────────────────────────────┐
│ Sensor:      test_dashboard                     │
│ Tipo:        temperature                        │
│ Severidade:  HIGH                               │
│ Timestamp:   2024-01-15 14:30:25                │
└─────────────────────────────────────────────────┘

📊 Gráfico de Temperatura (últimas 2h)
[GRÁFICO ANEXADO COMO IMAGEM]

Gráfico mostra as últimas 2 horas de temperatura de todos os sensores

Sistema de Monitoramento Inteligente de Clusters - IF-UFG
Email enviado automaticamente em 15/01/2024 às 14:30:25
```

## 🔍 Configuração do Grafana

### **Dashboard Utilizado**
- **UID**: ``
- **Painel**: `3` (Timeseries de temperatura)
- **URL**: `http://localhost:3000`

### **API Key**
```
GRAFANA_API_KEY = ""
```

### **Fonte de Dados**
- **Prometheus**: `feq6bma82bksge`
- **Métricas**: `cluster_temperature_celsius{esp_id="a"}` e `cluster_temperature_celsius{esp_id="b"}`

## 🛠️ Tratamento de Erros

### **Gráfico Não Disponível**
Se o Grafana estiver inacessível ou houver erro:
- Email é enviado normalmente
- Mensagem de erro no lugar do gráfico
- Log detalhado do problema

### **Timeouts**
- Timeout de 30 segundos para download
- Fallback gracioso sem interromper o alerta

## 🎨 Customização

### **Alterar Período do Gráfico**
```python
# Em alert_manager.py
def _get_graph_period(self, alert_type: str) -> int:
    periods = {
        'temperature': 4,      # 4 horas ao invés de 2
        'variation': 2,        # 2 horas ao invés de 1
        # ...
    }
    return periods.get(alert_type, 2)
```

### **Alterar Qualidade da Imagem**
```python
params = {
    "width": 1600,    # Maior largura
    "height": 800,    # Maior altura
    "theme": "dark"   # Tema escuro
}
```

## 🔄 Integração com Alertas Existentes

### **Alertas Contemplados**
- ✅ Temperatura alta/baixa
- ✅ Variação de temperatura
- ✅ Sensor offline
- ✅ Sensor volta online
- ✅ Umidade alta/baixa

### **Compatibilidade**
- ✅ Títulos personalizados mantidos
- ✅ Cooldown de emails respeitado
- ✅ Rate limiting funcional
- ✅ Persistência de estado preservada

## 🌟 Benefícios

### **Para Administradores**
- 📊 **Contexto Visual**: Vê exatamente o que aconteceu antes do alerta
- 📈 **Tendências**: Identifica padrões de temperatura
- 🔍 **Diagnóstico**: Facilita investigação de problemas
- 📧 **Profissionalismo**: Emails mais informativos e organizados

### **Para Operação**
- ⚡ **Resposta Rápida**: Decisões baseadas em dados visuais
- 🎯 **Priorização**: Distingue alertas críticos dos normais
- 📱 **Mobilidade**: Gráficos legíveis em dispositivos móveis
- 🔄 **Histórico**: Registra condições no momento do alerta

## 📈 Métricas de Sucesso

### **Indicadores de Funcionamento**
- Emails enviados com gráfico anexado
- Tempo de resposta do Grafana < 30s
- Taxa de sucesso de download > 95%
- Nenhum email perdido por falha de gráfico

### **Logs de Monitoramento**
```
[INFO] Baixando gráfico de temperatura (período: 2h)
[INFO] Gráfico de temperatura baixado com sucesso
[INFO] Gráfico anexado ao email com sucesso
[INFO] Email de alerta enviado para sensor_a com gráfico de 2h
```

## 🚀 Próximos Passos

### **Melhorias Futuras**
- 📊 Gráficos de umidade
- 🔥 Heatmaps de temperatura
- 📱 Gráficos otimizados para mobile
- 🌐 Dashboard público para stakeholders

### **Expansão**
- 📧 Relatórios semanais com gráficos
- 📈 Análise de tendências
- 🔔 Alertas preditivos com contexto visual
- 📊 Dashboards personalizados por usuário

---

**📍 Status**: ✅ **Implementado e Testado**  
**🗓️ Atualizado**: Janeiro 2024  
**👥 Responsável**: Sistema de Monitoramento IF-UFG 