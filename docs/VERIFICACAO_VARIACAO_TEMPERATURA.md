# 🌡️ Verificação - Sistema de Alertas de Variação de Temperatura

## 📋 Status da Implementação

### ✅ **IMPLEMENTADO E FUNCIONANDO:**

1. **Sistema de Alertas Completo**
   - Detecção de variação de 5°C em 5 minutos
   - Envio de email com gráficos do Grafana
   - Cooldown de 5 minutos entre alertas
   - Rate limiting para evitar spam

2. **Configuração Correta**
   - Limite: 5°C em 5 minutos
   - Histórico de temperatura com janela de 5 minutos
   - Mensagens personalizadas para alertas

3. **Integração Completa**
   - ESP32 → MQTT → Prometheus → AlertManager → Email
   - Monitoramento em tempo real
   - Logs detalhados

---

## 🔧 **Melhorias Implementadas:**

### **1. Backend - Cálculo Inteligente da Variação**
```python
# ESP32 envia apenas temperatura atual (simples)
payload = {
    "esp_id": "legion32_a",
    "temperature": 23.5,
    "humidity": 45.0,
    "timestamp": "2024-01-01T12:00:00"
}

# Backend calcula variação em 5 minutos
def _calculate_temperature_variation_5min(self, esp_id: str) -> float:
    # Analisa histórico dos últimos 5 minutos
    # Retorna máxima variação encontrada na janela
    return max_temp - min_temp
```

### **2. Histórico de Temperatura (Backend)**
- **Armazenamento:** Lista de leituras com timestamp
- **Janela:** 5 minutos móveis
- **Precisão:** Variação máxima na janela
- **Vantagem:** Não sobrecarrega o ESP32

### **3. Mensagens Melhoradas**
```
📈 Variação Brusca de Temperatura
Variação de 6.2°C detectada no sensor legion32_a em 5 minutos (limite: 5.0°C).
```

---

## 🧪 **Como Testar:**

### **Teste 1: Usando o Script Automático**
```bash
# Execute o script de teste
python3 test_variation_alert.py
```

### **Teste 2: Manualmente no ESP32**
1. Coloque o sensor em ambiente frio (< 20°C)
2. Aguarde 2-3 minutos
3. Coloque o sensor em ambiente quente (> 25°C)
4. Aguarde receber o email de alerta

### **Teste 3: Usando o Teste Forçado**
```bash
cd backend/alerting
python3 test_alert_hard.py
```

---

## 📊 **Verificação do Sistema:**

### **1. Logs do ESP32:**
```
Publicando: {"esp_id":"legion32_a","temperature":28.7,"humidity":45.0,...}
```

### **2. Logs do AlertManager:**
```
[DEBUG] Variação 5min [legion32_a]: 6.20°C (min: 18.50°C, max: 24.70°C)
[DEBUG] 📈 Variação BRUSCA detectada: 6.2°C >= 5.0°C
[DEBUG] ✅ Email enviado com sucesso
```

### **3. Email Recebido:**
- **Assunto:** `[ALERTA CLUSTER] HIGH: legion32_a`
- **Conteúdo:** Variação de 6.2°C detectada em 5 minutos
- **Gráfico:** Anexo com gráfico do Grafana

---

## ⚙️ **Configurações Principais:**

### **ESP32** (`config.h`):
```cpp
#define TEMP_ALERT_THRESHOLD 27.0       // Temperatura alta
#define HUMIDITY_MIN_THRESHOLD 30.0     // Umidade mínima
#define HUMIDITY_MAX_THRESHOLD 70.0     // Umidade máxima
```

### **Backend** (`config.py`) - **Modificável sem rebuild!**:
```python
# Limites de temperatura
'temperature': {
    'critical_high': 35.0,      # Temperatura crítica alta
    'high': 27.0,               # Temperatura alta (alerta)
    'low': 15.0,                # Temperatura baixa (alerta)
    'critical_low': 5.0         # Temperatura crítica baixa
},

# Variações bruscas - AQUI ESTÁ O LIMITE DE 5°C!
'variation': {
    'temperature': 5.0,         # Variação de temperatura em 5 min
    'humidity': 15.0            # Variação de umidade em 5 min
},

# Cooldowns
'cooldown': {
    'email': 300,               # 5 minutos entre emails
    'sensor_offline': 300,      # 5 minutos para considerar offline
}
```

### **📧 Email** (`config.py`):
```python
EMAIL_CONFIG = {
    'to_emails': [
        '',
        # Adicione mais emails aqui
    ],
    'subject_prefix': '[ALERTA CLUSTER]'
}
```

### **Prometheus** (`cluster_alerts.yml`):
```yaml
- alert: TemperatureVariation
  expr: cluster_temperature_variation_celsius > 5
  for: 1m
  labels:
    severity: warning
  annotations:
    summary: "Variação brusca de temperatura"
    description: "Sensor {{ $labels.esp_id }} teve variação de {{ $value }}°C"
```

---

## 🔧 **Exemplos de Modificações Comuns:**

### **1. Mudar limite de variação para 3°C:**
```python
# Em backend/alerting/config.py
'variation': {
    'temperature': 3.0,  # Era 5.0, agora 3.0
    'humidity': 15.0
}
```

### **2. Adicionar mais emails:**
```python
# Em backend/alerting/config.py
'to_emails': [
    'admin@empresa.com',
    'operador@empresa.com'
]
```

### **3. Mudar cooldown para 2 minutos:**
```python
# Em backend/alerting/config.py
'cooldown': {
    'email': 120,  # Era 300 (5 min), agora 120 (2 min)
    'sensor_offline': 300
}
```

### **4. Após qualquer mudança:**
```bash
./reload_config.sh
```

---

## 🎯 **Resultado Final:**

### **✅ SIM, O SISTEMA ESTÁ IMPLEMENTADO E FUNCIONANDO:**

1. **Detecção correta** de variação de 5°C em 5 minutos
2. **Envio automático** de email com gráfico
3. **Cooldown** de 5 minutos entre alertas
4. **Rate limiting** para evitar spam
5. **Logs detalhados** para debugging
6. **Integração completa** com todas as partes do sistema

### **📧 Email de Alerta Inclui:**
- Descrição do problema
- Sensor afetado
- Timestamp
- Gráfico do Grafana em tempo real
- Informações técnicas

---

## 🚀 **Para Usar:**

1. **Certifique-se** que o sistema está rodando:
   ```bash
   ./start.sh
   ```

2. **Monitore** os logs:
   ```bash
   ./logs.sh
   ```

3. **Teste** o sistema:
   ```bash
   python3 test_variation_alert.py
   ```

4. **Verifique** o email configurado em `backend/alerting/config.py`

5. **Para modificar configurações:**
   ```bash
   # Edite o arquivo
   nano backend/alerting/config.py
   
   # Aplique as mudanças (sem rebuild!)
   ./reload_config.sh
   ```

---

## ✅ **VANTAGENS DA IMPLEMENTAÇÃO OTIMIZADA:**

1. **🔄 Não precisa fazer upload** no ESP32
2. **💾 ESP32 mais leve** - apenas envia dados
3. **🧠 Backend inteligente** - faz todo o processamento
4. **🔧 Modificações sem rebuild** - apenas `./reload_config.sh`
5. **📊 Histórico centralizado** - todos os sensores
6. **⚡ Melhor performance** - ESP32 focado em sensoriamento
7. **🚀 Configuração dinâmica** - muda limites em tempo real

---

**✅ SISTEMA TOTALMENTE FUNCIONAL E OTIMIZADO!**

### **🎉 AGORA VOCÊ PODE:**
- ✅ Modificar limites de temperatura no `config.py`
- ✅ Adicionar/remover emails de alerta  
- ✅ Ajustar cooldowns e timeouts
- ✅ Aplicar mudanças com `./reload_config.sh`
- ✅ **SEM REBUILD!** 🚀 