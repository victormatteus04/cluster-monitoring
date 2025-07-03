# 🛠️ Scripts Utilitários - IF-UFG

Este diretório contém scripts utilitários para manutenção, diagnóstico e monitoramento do sistema de monitoramento IF-UFG.

## 📋 Lista de Scripts

### 🔍 **verificar_sistema.sh**
**Descrição**: Script principal de verificação completa do sistema  
**Uso**: `./verificar_sistema.sh`

**Funcionalidades**:
- ✅ Verifica Docker e Docker Compose
- ✅ Status de containers
- ✅ Disponibilidade de portas
- ✅ Status dos sensores
- ✅ Integridade do banco de dados
- ✅ Verificação de logs
- ✅ Monitoramento de recursos
- ✅ Conectividade dos serviços

**Saída**: Log detalhado com cores e relatório final

---

### 💾 **backup_completo.sh**
**Descrição**: Sistema completo de backup com restore automático  
**Uso**: `./backup_completo.sh`

**Funcionalidades**:
- 💾 Backup de banco de dados SQLite
- 💾 Backup de configurações
- 💾 Backup de dashboards do Grafana
- 💾 Backup de logs relevantes
- 💾 Backup de scripts e documentação
- 💾 Compactação automática
- 💾 Script de restore incluído
- 💾 Limpeza de backups antigos
- 💾 Notificação por email

**Saída**: Arquivo `.tar.gz` com backup completo

---

### 🔍 **diagnostico.sh**
**Descrição**: Diagnóstico automático com sugestões de correção  
**Uso**: `./diagnostico.sh`

**Funcionalidades**:
- 🐳 Diagnóstico do Docker
- 📦 Análise de containers
- 🔌 Verificação de portas
- 🗄️ Integridade do banco
- 🌡️ Status dos sensores
- 📊 Análise do Grafana
- 💻 Verificação de recursos
- 🌐 Teste de conectividade
- 📋 Análise de logs
- 📄 Relatório de diagnóstico

**Saída**: Relatório com problemas identificados e soluções sugeridas

---

### 📊 **monitorar_recursos.sh**
**Descrição**: Monitoramento contínuo de recursos do sistema  
**Uso**: `./monitorar_recursos.sh [opções]`

**Opções**:
- `-c, --continuo`: Monitoramento contínuo
- `-s, --single`: Coleta única
- `-r, --report`: Gerar relatório HTML
- `-h, --help`: Mostrar ajuda

**Funcionalidades**:
- 📊 Coleta de métricas (CPU, memória, disco)
- 📈 Geração de estatísticas
- 🚨 Alertas automáticos
- 📄 Relatórios HTML
- 💾 Armazenamento em CSV
- 🧹 Limpeza automática de dados antigos

**Saída**: Arquivos CSV com métricas e relatórios HTML

---

### 🧹 **limpar_logs.sh**
**Descrição**: Limpeza automática de logs com rotação  
**Uso**: `./limpar_logs.sh [opções]`

**Opções**:
- `--days N`: Manter logs dos últimos N dias (padrão: 30)
- `--size SIZE`: Tamanho máximo para rotação (padrão: 100M)
- `--docker`: Limpar apenas logs do Docker
- `--system`: Limpar logs do sistema (requer root)
- `--setup-cron`: Configurar limpeza automática
- `--quiet`: Modo silencioso

**Funcionalidades**:
- 🗑️ Remoção de logs antigos
- 🔄 Rotação de logs grandes
- 📦 Compressão automática
- 🐳 Limpeza de logs do Docker
- 🖥️ Limpeza de logs do sistema
- ⏰ Configuração de cron automático

**Saída**: Estatísticas de limpeza e espaço recuperado

---

### ❤️ **health_check.sh**
**Descrição**: Health check automático para uso em cron  
**Uso**: `./health_check.sh [opções]`

**Opções**:
- `--silent, -s`: Modo silencioso (padrão para cron)
- `--verbose, -v`: Modo verboso com output detalhado
- `--report, -r`: Gerar apenas relatório HTML

**Funcionalidades**:
- ✅ Verificação completa de componentes
- 📊 Status em JSON estruturado
- 🚨 Alertas críticos automáticos
- 📧 Notificação por email
- 📄 Relatórios HTML dinâmicos
- ⏰ Adequado para cron jobs

**Saída**: Status JSON, logs de alerta e relatórios HTML

---

### 📈 **analyze_performance.py**
**Descrição**: Análise avançada de performance com gráficos  
**Uso**: `./analyze_performance.py [opções]`

**Opções**:
- `--days N`: Número de dias para análise (padrão: 7)
- `--project-dir PATH`: Diretório do projeto

**Funcionalidades**:
- 📊 Análise de tendências de recursos
- 🌡️ Performance dos sensores
- 📈 Gráficos avançados com matplotlib
- 📄 Relatórios HTML interativos
- 🔍 Detecção de anomalias
- 📊 Correlação entre métricas

**Dependências**: `pandas`, `matplotlib`, `seaborn`  
**Saída**: Gráficos PNG e relatórios HTML

---

### 📋 **coletar_suporte.sh**
**Descrição**: Coleta completa de informações para suporte técnico  
**Uso**: `./coletar_suporte.sh`

**Funcionalidades**:
- 🖥️ Informações completas do sistema
- 🐳 Status detalhado do Docker
- 📋 Logs relevantes para diagnóstico
- ⚙️ Configurações (dados sensíveis removidos)
- 🗄️ Informações do banco de dados
- 🌐 Status de conectividade
- 🌡️ Status dos sensores
- 🔍 Execução de diagnósticos
- 📦 Pacote compactado para envio

**Saída**: Pacote `.tar.gz` com todas as informações para suporte

---

## 🚀 Uso Recomendado

### 📅 **Verificação Diária**
```bash
# Executar verificação completa
./utils/verificar_sistema.sh

# Health check silencioso (para cron)
./utils/health_check.sh --silent
```

### 📊 **Monitoramento Contínuo**
```bash
# Monitoramento em tempo real
./utils/monitorar_recursos.sh --continuo

# Coleta única de métricas
./utils/monitorar_recursos.sh --single
```

### 💾 **Backup e Manutenção**
```bash
# Backup completo
./utils/backup_completo.sh

# Limpeza de logs
./utils/limpar_logs.sh

# Configurar limpeza automática
./utils/limpar_logs.sh --setup-cron
```

### 🔍 **Diagnóstico e Suporte**
```bash
# Diagnóstico completo
./utils/diagnostico.sh

# Análise de performance
./utils/analyze_performance.py --days 30

# Coletar informações para suporte
./utils/coletar_suporte.sh
```

---

## ⏰ Automação com Cron

### **Configuração Recomendada**

```bash
# Editar crontab
crontab -e

# Adicionar as seguintes linhas:

# Health check a cada 5 minutos
*/5 * * * * /path/to/project/utils/health_check.sh --silent

# Monitoramento de recursos a cada hora
0 * * * * /path/to/project/utils/monitorar_recursos.sh --single

# Backup diário às 02:00
0 2 * * * /path/to/project/utils/backup_completo.sh

# Limpeza de logs diária às 03:00
0 3 * * * /path/to/project/utils/limpar_logs.sh --quiet

# Verificação completa diária às 06:00
0 6 * * * /path/to/project/utils/verificar_sistema.sh

# Análise de performance semanal (domingo às 04:00)
0 4 * * 0 /path/to/project/utils/analyze_performance.py --days 7
```

---

## 📧 Configuração de Alertas

Os scripts utilizam o sistema de email configurado no backend para envio de alertas. Certifique-se de que as configurações SMTP estão corretas em `backend/config.py`.

### **Tipos de Alertas**:
- 🚨 **Críticos**: Falhas de sistema, containers parados
- ⚠️ **Avisos**: Recursos altos, sensores offline
- ℹ️ **Informativos**: Backup concluído, limpeza realizada

---

## 📊 Logs e Relatórios

### **Localização dos Arquivos**:
- **Logs**: `logs/`
- **Métricas**: `logs/metrics/`
- **Análises**: `logs/analysis/`
- **Backups**: `backups/`
- **Suporte**: `logs/support/`

### **Formato dos Arquivos**:
- **Logs**: `.log` (texto com timestamp)
- **Métricas**: `.csv` (dados estruturados)
- **Relatórios**: `.html` (visualização web)
- **Status**: `.json` (dados estruturados)

---

## 🛠️ Dependências

### **Sistema**:
- `bash` 4.0+
- `docker` e `docker-compose`
- `sqlite3`
- `curl`, `jq`
- `netstat`, `ss`

### **Python** (para `analyze_performance.py`):
```bash
pip install pandas matplotlib seaborn
```

### **Opcionais**:
- `bc` (cálculos decimais)
- `lsof` (arquivos abertos)
- `nc` (teste de portas)

---

## 🔒 Segurança

- ✅ Dados sensíveis são automaticamente removidos nos pacotes de suporte
- ✅ Senhas e tokens são mascarados como "REDACTED"
- ✅ Logs de aplicação não contêm informações confidenciais
- ✅ Permissões adequadas são mantidas nos arquivos

---

## 📞 Suporte

Para problemas com os scripts utilitários:

1. **Verificação**: Execute `./utils/verificar_sistema.sh`
2. **Diagnóstico**: Execute `./utils/diagnostico.sh`
3. **Coleta**: Execute `./utils/coletar_suporte.sh`
4. **Documentação**: Consulte `docs/07-TROUBLESHOOTING.md`

---

**🏢 Instituto de Física - Universidade Federal de Goiás**  
**📅 Atualizado**: Julho 2024  
**👥 Suporte Técnico**: Equipe IF-UFG 