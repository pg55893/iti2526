# WebApp com Monitorização Completa

Este projeto inclui uma aplicação Flask de gestão de ficheiros com stack completa de monitorização usando cAdvisor, Prometheus e Grafana.

## 🚀 Componentes

### Aplicação Principal
- **WebApp** (porta 8080): Aplicação Flask de upload/download de ficheiros
  - Login: `admin` / `1234`

### Stack de Monitorização
- **cAdvisor** (porta 8081): Métricas de containers Docker
- **Prometheus** (porta 9090): Recolha e armazenamento de métricas
- **Node Exporter** (porta 9100): Métricas do sistema host
- **Grafana** (porta 3000): Visualização de dashboards
  - Login: `admin` / `admin123`

## 📊 Métricas Monitorizadas

### Container Metrics (via cAdvisor)
- **CPU Usage**: Utilização de CPU por container
- **Memory Usage**: Consumo de memória
- **Network I/O**: Tráfego de rede (RX/TX)
- **Disk I/O**: Operações de leitura/escrita em disco
- **Container Status**: Estado dos containers

### System Metrics (via Node Exporter)
- CPU, memória e disco do host
- Estatísticas de rede
- Filesystem usage

## 🛠️ Instalação e Configuração

### Pré-requisitos
- Docker e Docker Compose instalados
- Servidor NFS configurado em `192.168.64.5` (ou ajustar no docker-compose.yml)

### Passos

1. **Clone/prepare os ficheiros do projeto:**
```bash
# Estrutura necessária:
.
├── app.py
├── Dockerfile
├── requirements.txt
├── docker-compose.yml
├── prometheus.yml
└── grafana/
    └── provisioning/
        ├── datasources/
        │   └── prometheus.yml
        └── dashboards/
            ├── dashboard.yml
            └── docker-monitoring.json
```

2. **Iniciar todos os serviços:**
```bash
docker-compose up -d
```

3. **Verificar estado dos containers:**
```bash
docker-compose ps
```

## 🌐 Acesso às Interfaces

| Serviço | URL | Credenciais |
|---------|-----|-------------|
| WebApp | http://webapp.localhost | admin / 1234 |
| cAdvisor | http://cadvisor.localhost | - |
| Prometheus | http://prometheus.localhost | - |
| Node Exporter | http://localhost:9100/metrics | - |
| Grafana | http://grafaba.localhost | admin / admin123 |

## 📈 Dashboards do Grafana

### Dashboard Pré-configurado: "Docker Containers Monitoring"

O dashboard inclui:

1. **CPU Usage por Container** - Gráfico temporal de uso de CPU
2. **Memory Usage por Container** - Consumo de memória ao longo do tempo
3. **Network I/O - WebApp** - Tráfego de rede (RX/TX)
4. **Disk I/O - WebApp** - Operações de disco (Read/Write)
5. **Gauges** - Indicadores visuais de CPU e memória
6. **Containers Ativos** - Gráfico de pizza com containers em execução
7. **WebApp Status** - Indicador UP/DOWN

### Aceder ao Dashboard

1. Abrir http://localhost:3000
2. Login com `admin` / `admin123`
3. O dashboard "Docker Containers Monitoring" é carregado automaticamente

## 🔍 Queries Prometheus Úteis

Aceder a http://localhost:9090 e experimentar:

```promql
# CPU usage de um container específico
rate(container_cpu_usage_seconds_total{name="webapp"}[5m]) * 100

# Memória usada pelo webapp
container_memory_usage_bytes{name="webapp"}

# Network received bytes
rate(container_network_receive_bytes_total{name="webapp"}[5m])

# Todos os containers ativos
count(container_last_seen) by (name)
```

## 🔧 Configuração Avançada

### Ajustar Retenção de Dados do Prometheus
No `docker-compose.yml`, alterar:
```yaml
--storage.tsdb.retention.time=30d  # Mudar para 7d, 60d, etc.
```

### Adicionar Novos Dashboards
1. Criar JSON do dashboard no Grafana UI
2. Exportar e colocar em `grafana/provisioning/dashboards/`
3. Reiniciar Grafana: `docker-compose restart grafana`

### Configurar Alertas
Editar `prometheus.yml` e adicionar:
```yaml
alerting:
  alertmanagers:
    - static_configs:
        - targets: ['alertmanager:9093']
```

## 📦 Volumes Persistentes

Os seguintes volumes são criados para persistência de dados:
- `dados_nfs`: Dados da aplicação (via NFS)
- `prometheus_data`: Métricas do Prometheus
- `grafana_data`: Configuração e dashboards do Grafana

## 🛡️ Notas de Segurança

⚠️ **IMPORTANTE para Produção:**
1. Mudar passwords default (webapp, Grafana)
2. Configurar HTTPS/TLS
3. Restringir acesso às portas de monitorização
4. Implementar autenticação no Prometheus
5. Configurar firewall adequado

## 🐛 Troubleshooting

### cAdvisor não está a recolher métricas
```bash
# Verificar se o cAdvisor tem acesso ao Docker socket
docker logs cadvisor
```

### Grafana não mostra dados
```bash
# Verificar se o Prometheus está a scrape corretamente
curl http://localhost:9090/api/v1/targets

# Verificar logs do Grafana
docker logs grafana
```

### Erros de permissões NFS
```bash
# Verificar montagem NFS
docker exec webapp df -h | grep nfs
```

## 📝 Comandos Úteis

```bash
# Ver logs de um serviço específico
docker-compose logs -f webapp

# Reiniciar apenas um serviço
docker-compose restart prometheus

# Parar tudo
docker-compose down

# Parar e remover volumes (cuidado!)
docker-compose down -v

# Ver uso de recursos em tempo real
docker stats
```

## 🔄 Manutenção

### Backup de Dados
```bash
# Backup do Prometheus
docker run --rm -v prometheus_data:/data -v $(pwd):/backup \
  alpine tar czf /backup/prometheus-backup.tar.gz /data

# Backup do Grafana
docker run --rm -v grafana_data:/data -v $(pwd):/backup \
  alpine tar czf /backup/grafana-backup.tar.gz /data
```

## 📚 Recursos Adicionais

- [Documentação cAdvisor](https://github.com/google/cadvisor)
- [Documentação Prometheus](https://prometheus.io/docs/)
- [Documentação Grafana](https://grafana.com/docs/)
- [PromQL Query Examples](https://prometheus.io/docs/prometheus/latest/querying/examples/)
- [Grafana Dashboards Community](https://grafana.com/grafana/dashboards/)
