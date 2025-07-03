# ⚙️ Módulo 2: Instalação e Deploy

## 📋 Pré-requisitos

### **Sistema Operacional**
- **Ubuntu 20.04+ LTS** (Recomendado)
- **Debian 11+** (Compatível)
- **CentOS 8+** / **RHEL 8+** (Compatível)
- **Raspberry Pi OS** (Para RPi)

### **Hardware Mínimo**
- **CPU**: 2 cores, 1.5GHz
- **RAM**: 2GB
- **Storage**: 20GB livres
- **Network**: Conectividade Wi-Fi/Ethernet

### **Software Base**
- **Docker** 20.10+
- **Docker Compose** 2.0+
- **Git** 2.25+
- **SSH** (para acesso remoto)

## 🚀 Instalação via SSH

### **Passo 1: Conexão SSH no Servidor IF-UFG**

```bash
# Conectar ao servidor do cluster
ssh usuario@servidor-ifufg.ufg.br

# Ou via IP direto
ssh usuario@192.168.x.x
```

### **Passo 2: Atualização do Sistema**

```bash
# Ubuntu/Debian
sudo apt update && sudo apt upgrade -y

# CentOS/RHEL
sudo yum update -y
# ou
sudo dnf update -y
```

### **Passo 3: Instalação do Docker**

```bash
# Ubuntu/Debian
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
sudo usermod -aG docker $USER

# Logout e login novamente para aplicar mudanças
exit
ssh usuario@servidor-ifufg.ufg.br

# Verificar instalação
docker --version
docker compose version
```

### **Passo 4: Preparação do Ambiente**

```bash
# Criar diretório do projeto
sudo mkdir -p /opt/cluster-monitoring
sudo chown $USER:$USER /opt/cluster-monitoring
cd /opt/cluster-monitoring

# Clone do repositório
git clone <url-do-repositorio> .

# Ou upload via SCP se não tiver Git
# scp -r cluster-monitoring/ usuario@servidor:/opt/
```

### **Passo 5: Configuração de Permissões**

```bash
# Dar permissões aos scripts
chmod +x *.sh
chmod +x utils/*.sh
chmod +x scripts/*.sh

# Criar diretórios necessários
mkdir -p {data,logs,backups}

# Verificar estrutura
tree -L 2
```

## 🔧 Configuração Inicial

### **1. Configuração de Rede**

```bash
# Verificar IP do servidor
ip addr show

# Verificar conectividade
ping google.com

# Testar portas (opcional)
sudo netstat -tulpn | grep -E ":(3000|9090|1883|8000)"
```

### **2. Configuração de Firewall**

```bash
# Ubuntu/Debian (UFW)
sudo ufw allow 3000/tcp    # Grafana
sudo ufw allow 9090/tcp    # Prometheus  
sudo ufw allow 1883/tcp    # MQTT
sudo ufw allow 8000/tcp    # Alertas/Exporter
sudo ufw allow 22/tcp      # SSH
sudo ufw enable

# CentOS/RHEL (firewalld)
sudo firewall-cmd --permanent --add-port=3000/tcp
sudo firewall-cmd --permanent --add-port=9090/tcp
sudo firewall-cmd --permanent --add-port=1883/tcp
sudo firewall-cmd --permanent --add-port=8000/tcp
sudo firewall-cmd --reload
```

### **3. Configuração de Email (SMTP)**

```bash
# Editar configuração de email
nano backend/alerting/config.py

# Configurar credenciais SMTP
SMTP_SERVER = "smtp.gmail.com"      # Para Gmail
SMTP_PORT = 587
EMAIL_USER = "sistema@ifufg.ufg.br"
EMAIL_PASS = "senha-app-especifica"
EMAIL_FROM = "sistema@ifufg.ufg.br"
EMAIL_TO = ["admin@ifufg.ufg.br"]
```

### **4. Configuração de Sensores**

```bash
# Editar lista de sensores válidos
nano backend/alerting/alert_manager.py

# Adicionar/remover sensores
self.sensores_validos = {'a', 'b', 'c', 'd'}  # Conforme necessário
```

## 🐳 Deploy com Docker

### **Instalação Padrão**

```bash
# Executar script de instalação
./scripts/install.sh

# Ou manualmente:
cd /opt/cluster-monitoring

# Build e start dos containers
docker compose -f backend/docker-compose.yaml up -d

# Verificar status
docker compose -f backend/docker-compose.yaml ps
```

### **Instalação para Raspberry Pi**

```bash
# Para RPi, use imagens ARM
export DOCKER_DEFAULT_PLATFORM=linux/arm64

# Modificar docker-compose.yaml se necessário
sed -i 's/amd64/arm64/g' backend/docker-compose.yaml

# Deploy normal
./start.sh
```

## 📁 Estrutura de Diretórios

```
/opt/cluster-monitoring/
├── backend/
│   ├── alerting/           # Sistema de alertas
│   ├── exporter/           # MQTT exporter
│   ├── grafana/           # Configurações Grafana
│   ├── prometheus/        # Configurações Prometheus
│   ├── mosquitto/         # Configurações MQTT
│   └── docker-compose.yaml
├── esp32-sensors/         # Firmware ESP32
├── docs/                  # Documentação
├── utils/                 # Scripts utilitários
├── scripts/               # Scripts de instalação
├── data/                  # Dados persistentes
├── logs/                  # Logs do sistema
├── backups/               # Backups automáticos
├── start.sh              # Iniciar sistema
├── stop.sh               # Parar sistema
└── README.md
```

## ✅ Verificação da Instalação

### **1. Verificar Containers**

```bash
# Status dos containers
docker compose -f backend/docker-compose.yaml ps

# Logs dos serviços
docker compose -f backend/docker-compose.yaml logs
```

### **2. Verificar Endpoints**

```bash
# Grafana (Dashboard)
curl -f http://localhost:3000 || echo "Grafana indisponível"

# Prometheus (Métricas)
curl -f http://localhost:9090 || echo "Prometheus indisponível"

# MQTT Exporter (API)
curl -f http://localhost:8000/health || echo "Exporter indisponível"

# MQTT Broker (teste de conexão)
mosquitto_pub -h localhost -p 1883 -t test -m "hello" || echo "MQTT indisponível"
```

### **3. Teste de Sensores**

```bash
# Simular dados de sensor
curl -X POST -H "Content-Type: application/json" \
  -d '{"esp_id": "a", "temperature": 25.0, "humidity": 60.0}' \
  http://localhost:8000/webhook

# Verificar se dados aparecem no Grafana
curl -s http://localhost:8000/metrics | grep cluster_temperature
```

## 🔄 Scripts de Gerenciamento

### **Scripts Principais**

```bash
# Iniciar sistema completo
./start.sh

# Parar sistema
./stop.sh

# Reiniciar sistema
./stop.sh && ./start.sh

# Status do sistema
./utils/verificar_sistema.sh
```

### **Scripts de Manutenção**

```bash
# Backup completo
./utils/backup_completo.sh

# Limpeza de logs
./utils/limpar_logs.sh

# Diagnóstico de problemas
./utils/diagnostico.sh

# Monitoramento de recursos
./utils/monitorar_recursos.sh
```

## 🚦 Deploy em Produção

### **1. Configuração de Produção**

```bash
# Configurar restart automático
sudo systemctl enable docker

# Configurar log rotation
sudo nano /etc/logrotate.d/cluster-monitoring
```

**Arquivo logrotate:**
```
/opt/cluster-monitoring/logs/*.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    create 644 $USER $USER
}
```

### **2. Monitoramento de Sistema**

```bash
# Adicionar ao crontab para verificações
crontab -e

# Adicionar linhas:
# Verificação a cada 5 minutos
*/5 * * * * /opt/cluster-monitoring/utils/verificar_sistema.sh >> /opt/cluster-monitoring/logs/health.log 2>&1

# Backup diário às 2h
0 2 * * * /opt/cluster-monitoring/utils/backup_completo.sh >> /opt/cluster-monitoring/logs/backup.log 2>&1

# Limpeza semanal de logs
0 3 * * 0 /opt/cluster-monitoring/utils/limpar_logs.sh >> /opt/cluster-monitoring/logs/cleanup.log 2>&1
```

### **3. Configuração de SSL (Opcional)**

```bash
# Para acesso HTTPS ao Grafana
sudo apt install nginx certbot python3-certbot-nginx

# Configurar proxy reverso
sudo nano /etc/nginx/sites-available/cluster-monitoring
```

**Configuração Nginx:**
```nginx
server {
    listen 80;
    server_name monitoring.ifufg.ufg.br;

    location / {
        proxy_pass http://localhost:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

## 📝 Deploy Checklist

### **Pré-Deploy**
- [ ] Servidor preparado com Docker
- [ ] Firewall configurado
- [ ] Credenciais de email configuradas
- [ ] Rede Wi-Fi disponível para ESP32
- [ ] Backup do sistema anterior (se aplicável)

### **Deploy**
- [ ] Código baixado/atualizado
- [ ] Permissões configuradas
- [ ] Containers iniciados
- [ ] Endpoints respondendo
- [ ] Logs sem erros críticos

### **Pós-Deploy**
- [ ] Teste de sensores funcionando
- [ ] Emails sendo enviados
- [ ] Dashboards acessíveis
- [ ] Monitoramento automático ativo
- [ ] Backup configurado
- [ ] Documentação atualizada

## 🚨 Problemas Comuns na Instalação

### **Docker não inicia**
```bash
# Verificar status
sudo systemctl status docker

# Reiniciar serviço
sudo systemctl restart docker

# Verificar logs
sudo journalctl -u docker.service
```

### **Portas em uso**
```bash
# Verificar portas ocupadas
sudo netstat -tulpn | grep -E ":(3000|9090|1883|8000)"

# Matar processos se necessário
sudo kill -9 $(sudo lsof -t -i:3000)
```

### **Permissões de arquivo**
```bash
# Corrigir permissões
sudo chown -R $USER:$USER /opt/cluster-monitoring
chmod +x *.sh utils/*.sh scripts/*.sh
```

### **Problemas de memória**
```bash
# Verificar uso de memória
free -h

# Limpar cache se necessário
sudo sync && sudo sysctl vm.drop_caches=3
```

## 🔄 Atualizações

### **Atualização do Sistema**

```bash
# Parar sistema
./stop.sh

# Backup antes da atualização
./utils/backup_completo.sh

# Atualizar código
git pull origin main

# Rebuild containers se necessário
docker compose -f backend/docker-compose.yaml build --no-cache

# Iniciar sistema atualizado
./start.sh

# Verificar funcionamento
./utils/verificar_sistema.sh
```

---

**📍 Próximo Módulo**: [3. Hardware e Sensores](03-HARDWARE.md)  
**🏠 Voltar**: [Manual Principal](README.md) 