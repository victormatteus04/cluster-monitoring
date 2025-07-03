# 📚 Manual do Sistema de Monitoramento IF-UFG

## 🎯 Visão Geral

Sistema completo de monitoramento de cluster com sensores ESP32, alertas por email e dashboards em tempo real, desenvolvido para o **Instituto de Física da Universidade Federal de Goiás (IF-UFG)**.

## 📋 Índice da Documentação

### 🏗️ **[1. Arquitetura do Sistema](01-ARQUITETURA.md)**
- Visão geral da arquitetura
- Componentes e tecnologias
- Fluxo de dados
- Diagramas do sistema

### ⚙️ **[2. Instalação e Deploy](02-INSTALACAO.md)**
- Pré-requisitos do sistema
- Instalação via SSH
- Deploy no cluster IF-UFG
- Configuração inicial

### 🔧 **[3. Hardware e Sensores](03-HARDWARE.md)**
- Especificações dos ESP32
- Configuração dos sensores
- Conexão com Wi-Fi
- Pinout e circuitos

### 📧 **[4. Emails, Logs e Alertas](04-ALERTAS.md)**
- Sistema de alertas
- Configuração de email
- Tipos de notificações
- Logs do sistema

### 📊 **[5. Dashboard e Grafana](05-DASHBOARD.md)**
- Acesso ao Grafana
- Navegação nos dashboards
- Criação de painéis
- Exportação de dados

### 🗄️ **[6. Gestão de Dados](06-DADOS.md)**
- Banco de dados SQLite
- Prometheus e métricas
- Backup e restore
- Retenção de dados

### 🚨 **[7. Troubleshooting](07-TROUBLESHOOTING.md)**
- Problemas comuns
- Diagnóstico de falhas
- Recuperação do sistema
- Logs de erro

### ✅ **[8. Verificações e Monitoramento](08-VERIFICACOES.md)**
- Scripts de verificação
- Health checks
- Monitoramento contínuo
- Alertas de sistema

---

## 🛠️ Utilitários

### 📁 **[Scripts Helpers](utils/)**
- `verificar_sistema.sh` - Verificação completa do sistema
- `backup_completo.sh` - Backup de dados e configurações
- `diagnostico.sh` - Diagnóstico automático de problemas
- `monitorar_recursos.sh` - Monitoramento de recursos
- `limpar_logs.sh` - Limpeza de logs antigos

---

## 📖 Informações do Projeto

| **Propriedade** | **Valor** |
|-----------------|-----------|
| **Versão** | 2.0.0 |
| **Instituição** | Instituto de Física - UFG |
| **Ambiente** | Cluster de Produção |
| **Sensores** | ESP32 (a, b) |
| **Tecnologia** | Docker, Python, Grafana |

---

## 🚀 Início Rápido

```bash
# 1. Clone o repositório
git clone <repositorio>
cd cluster-monitoring

# 2. Execute a instalação
./scripts/install.sh

# 3. Inicie o sistema
./start.sh

# 4. Acesse o dashboard
http://servidor:3000
```

---

## 📞 Suporte

- **Manual Completo**: Consulte os módulos específicos
- **Logs**: `./utils/verificar_sistema.sh`
- **Backup**: `./utils/backup_completo.sh`
- **Diagnóstico**: `./utils/diagnostico.sh`

---

**🏢 Instituto de Física - Universidade Federal de Goiás**  
**📅 Atualizado**: Julho 2024  
**👥 Suporte Técnico**: Equipe IF-UFG 