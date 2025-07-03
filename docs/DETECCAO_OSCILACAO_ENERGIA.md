# 🔌 Detecção de Oscilação de Energia/Internet

## Sistema de Monitoramento Inteligente de Clusters - IF-UFG

### 📋 **Funcionalidade Implementada**

O sistema agora detecta automaticamente quando há oscilação de energia ou internet e envia um email informativo quando o sistema volta a funcionar.

### 🔄 **Como Funciona**

1. **Detecção de Sensor Offline**: 
   - Sistema marca sensor como offline após 5 minutos sem dados
   - Não envia email neste momento (evita spam)

2. **Detecção de Retorno**:
   - Quando sensor volta a enviar dados, sistema detecta mudança de status
   - Gera email informativo sobre o restabelecimento

3. **Email Informativo**:
   - Inclui temperatura atual do sensor que voltou
   - Mostra status completo de **todos os sensores** do cluster
   - Título personalizado indicando oscilação

### 📧 **Exemplo de Email Recebido**

```
Assunto: [ALERTA CLUSTER] Sistema restabelecido após oscilação - Sensor legion32_a

Mensagem: 
INFORMATIVO: O sensor legion32_a voltou a funcionar após período offline 
(provável oscilação de energia/internet). 

Temperatura atual: 26.5°C. 

Status completo do cluster: 
🟢 Sensor legion32_a: 26.5°C, 55.0% (online) | 
🟢 Sensor legion32_b: 24.2°C, 48.5% (online)
```

### 📊 **Informações Incluídas**

- **Sensor que voltou**: Nome do sensor que estava offline
- **Temperatura atual**: Temperatura no momento do retorno
- **Status do cluster**: Situação de todos os sensores:
  - 🟢 Online: Sensor funcionando normalmente
  - 🔴 Offline: Sensor sem comunicação
  - Temperatura e umidade atuais de cada sensor

### 🛠️ **Configuração**

A funcionalidade está **automaticamente ativada** e não requer configuração adicional.

**Parâmetros relevantes em `config.py`**:
```python
ALERT_CONFIG = {
    'cooldown': {
        'sensor_offline': 300,  # 5 minutos para considerar offline
    }
}
```

### 🧪 **Teste da Funcionalidade**

Para testar a detecção de oscilação:

```bash
# Teste completo (10 minutos)
python3 test_power_outage.py

# Teste rápido (2 minutos)
python3 test_power_outage.py quick
```

### 🔧 **Personalização da Mensagem**

Para personalizar a mensagem, edite em `backend/alerting/config.py`:

```python
ALERT_MESSAGES = {
    'sensor_back_online': {
        'title': 'Sistema restabelecido após oscilação - Sensor {esp_id}',
        'template': 'INFORMATIVO: O sensor {esp_id} voltou a funcionar após período offline (provável oscilação de energia/internet). Temperatura atual: {temperature}°C. Status completo do cluster: {sensors_status}'
    }
}
```

### 🚀 **Aplicar Mudanças**

Após modificar a configuração:

```bash
./reload_config.sh
```

### 📈 **Benefícios**

1. **Monitoramento Proativo**: Detecta problemas de infraestrutura
2. **Visibilidade Completa**: Mostra status de todo o cluster
3. **Não Invasivo**: Apenas um email informativo (não spam)
4. **Diagnóstico Rápido**: Identifica possíveis problemas de energia/rede
5. **Temperatura Atual**: Verifica se equipamento voltou em condições normais

### 💡 **Casos de Uso**

- **Queda de energia**: UPS esgotou, energia voltou
- **Instabilidade de rede**: Wi-Fi oscilou, reconectou
- **Reinicialização**: Equipamento reiniciou por algum motivo
- **Manutenção**: Sensor foi desconectado e reconectado

### 🔍 **Logs do Sistema**

Para acompanhar a detecção:

```bash
# Ver logs em tempo real
./logs.sh

# Procurar por eventos de retorno
docker logs cluster-alerting 2>&1 | grep "voltou online"
```

### 🎯 **Severidade do Alerta**

- **Tipo**: `sensor_back_online`
- **Severidade**: `LOW` (informativo)
- **Frequência**: Apenas quando sensor volta online
- **Cooldown**: Sem cooldown (evento raro)

---

**Versão**: 1.0  
**Data**: 2025-01-03  
**Autor**: Sistema de Monitoramento IF-UFG 