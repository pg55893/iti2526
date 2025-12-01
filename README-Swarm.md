# 🚀 Deployment com Docker Swarm e Traefik

Este guia explica como fazer deploy da aplicação usando Docker Swarm para orquestração e Traefik para load balancing.

## 📋 Pré-requisitos

- Docker Engine 20.10+
- Docker Compose V2
- Servidor NFS configurado (192.168.64.5)
- Imagem da webapp buildada

## 🎯 Arquitetura

```
                    Internet
                       |
                   [Traefik] :80, :443
                       |
         +-------------+-------------+
         |             |             |
    [WebApp-1]    [WebApp-2]    [WebApp-3]  (3 réplicas)
         |             |             |
         +-------------+-------------+
                       |
                  [NFS Storage]
                       
    [Prometheus] ← [cAdvisor] (métricas)
         |
    [Grafana] (visualização)
```

## 🔧 Passo a Passo

### 1. **Build da Imagem da WebApp**

```bash
# Build da imagem localmente
docker build -t webapp:latest .

# Verificar que a imagem foi criada
docker images | grep webapp
```

### 2. **Inicializar Docker Swarm**

```bash
# Inicializar o swarm
docker swarm init

# Verificar nodes (deves ver 1 manager)
docker node ls
```

**Output esperado:**
```
ID                HOSTNAME   STATUS    AVAILABILITY   MANAGER STATUS
abc123def456 *    node1      Ready     Active         Leader
```

### 3. **Criar Rede Overlay**

```bash
# Criar rede pública do Traefik
docker network create --driver overlay --attachable traefik-public

# Verificar redes
docker network ls | grep traefik
```

### 4. **Preparar Ficheiros de Configuração**

```bash
# Copiar prometheus.yml atualizado
cp prometheus-swarm.yml prometheus.yml

# Estrutura final:
.
├── docker-stack.yml
├── prometheus.yml
├── Dockerfile
├── app.py
├── requirements.txt
└── grafana/
    └── provisioning/
```

### 5. **Deploy da Stack**

```bash
# Deploy completo
docker stack deploy -c docker-stack.yml webapp-stack

# Verificar serviços
docker stack services webapp-stack
```

**Output esperado:**
```
ID             NAME                      MODE         REPLICAS   IMAGE
abc123         webapp-stack_traefik      replicated   1/1        traefik:v2.10
def456         webapp-stack_webapp       replicated   3/3        webapp:latest
ghi789         webapp-stack_cadvisor     global       1/1        gcr.io/cadvisor/cadvisor:latest
jkl012         webapp-stack_prometheus   replicated   1/1        prom/prometheus:latest
mno345         webapp-stack_grafana      replicated   1/1        grafana/grafana:latest
pqr678         webapp-stack_node-exporter global      1/1        prom/node-exporter:latest
```

### 6. **Verificar Status**

```bash
# Ver todos os containers
docker stack ps webapp-stack

# Ver logs de um serviço específico
docker service logs -f webapp-stack_webapp

# Ver réplicas da webapp
docker service ls | grep webapp
```

## 🌐 Acesso aos Serviços

### Via Traefik (Load Balanced)

| Serviço | URL | Descrição |
|---------|-----|-----------|
| WebApp | http://webapp.localhost | Aplicação principal (3 réplicas) |
| Traefik Dashboard | http://traefik.localhost | Dashboard do Traefik |
| Prometheus | http://prometheus.localhost | Interface do Prometheus |
| Grafana | http://grafana.localhost | Dashboards de monitorização |
| cAdvisor | http://cadvisor.localhost | Métricas de containers |

**Nota:** Para produção, substitui `.localhost` pelo teu domínio real.

### Credenciais

- **WebApp:** admin / 1234
- **Grafana:** admin / admin123
- **Traefik Dashboard:** Sem autenticação (configurável)

## 🔍 Verificação de Load Balancing

### Teste 1: Ver distribuição de pedidos

```bash
# Fazer múltiplos requests
for i in {1..10}; do
  curl -s http://webapp.localhost/health
  echo "Request $i completed"
done

# Ver logs de cada réplica
docker service logs webapp-stack_webapp | grep "GET /health"
```

### Teste 2: Verificar sticky sessions

```bash
# Login e verificar cookie
curl -c cookies.txt -d "username=admin&password=1234" \
  http://webapp.localhost/login

# Requests subsequentes devem ir para a mesma réplica
for i in {1..5}; do
  curl -b cookies.txt http://webapp.localhost/
done
```

### Teste 3: Health checks automáticos

```bash
# Traefik verifica /health a cada 10s
# Simular falha parando 1 réplica
docker service scale webapp-stack_webapp=2

# Traefik remove automaticamente da pool
# Verificar no dashboard: http://traefik.localhost
```

## 📊 Monitoring com Prometheus/Grafana

### Métricas Disponíveis

1. **Traefik Metrics:**
   - Request rate per service
   - Response times
   - HTTP status codes
   - Backend health

2. **Container Metrics (via cAdvisor):**
   - CPU, Memory, Network I/O
   - Por réplica individual

3. **System Metrics (via Node Exporter):**
   - Host CPU, Memory, Disk

### Queries Úteis para Swarm

```promql
# Requests por segundo no webapp
sum(rate(traefik_service_requests_total{service="webapp@docker"}[5m]))

# Latência média
histogram_quantile(0.95, 
  rate(traefik_service_request_duration_seconds_bucket[5m])
)

# CPU por réplica
sum by (container_label_com_docker_swarm_task_name) (
  rate(container_cpu_usage_seconds_total{
    container_label_com_docker_swarm_service_name="webapp-stack_webapp"
  }[5m])
) * 100
```

## 🔄 Operações Comuns

### Escalar Serviços

```bash
# Aumentar réplicas da webapp para 5
docker service scale webapp-stack_webapp=5

# Reduzir para 2
docker service scale webapp-stack_webapp=2

# Verificar
docker service ps webapp-stack_webapp
```

### Atualizar Aplicação (Zero-Downtime)

```bash
# 1. Build nova versão
docker build -t webapp:v2 .

# 2. Update do serviço
docker service update \
  --image webapp:v2 \
  --update-parallelism 1 \
  --update-delay 10s \
  webapp-stack_webapp

# 3. Acompanhar rollout
docker service ps webapp-stack_webapp
```

### Rollback

```bash
# Voltar à versão anterior
docker service rollback webapp-stack_webapp

# Verificar histórico
docker service inspect webapp-stack_webapp --pretty
```

### Ver Logs

```bash
# Logs de todas as réplicas
docker service logs -f webapp-stack_webapp

# Logs de uma réplica específica
docker service logs webapp-stack_webapp | grep "task_id"

# Logs do Traefik
docker service logs -f webapp-stack_traefik
```

## 🛡️ Configurações de Segurança

### 1. Adicionar Autenticação ao Traefik Dashboard

Editar `docker-stack.yml`:

```yaml
traefik:
  command:
    - "--api.dashboard=true"
    # Remover insecure mode para produção
    # - "--api.insecure=true"
  deploy:
    labels:
      # Adicionar autenticação básica
      - "traefik.http.middlewares.auth.basicauth.users=admin:$$apr1$$..."
      - "traefik.http.routers.traefik.middlewares=auth"
```

Gerar password hash:
```bash
htpasswd -nb admin password123
```

### 2. Configurar HTTPS com Let's Encrypt

Adicionar ao Traefik:

```yaml
command:
  - "--certificatesresolvers.letsencrypt.acme.email=teu@email.com"
  - "--certificatesresolvers.letsencrypt.acme.storage=/certificates/acme.json"
  - "--certificatesresolvers.letsencrypt.acme.tlschallenge=true"

labels:
  - "traefik.http.routers.webapp.tls=true"
  - "traefik.http.routers.webapp.tls.certresolver=letsencrypt"
```

### 3. Rate Limiting

```yaml
labels:
  - "traefik.http.middlewares.rate-limit.ratelimit.average=100"
  - "traefik.http.middlewares.rate-limit.ratelimit.burst=50"
  - "traefik.http.routers.webapp.middlewares=rate-limit"
```

## 🐛 Troubleshooting

### Serviços não iniciam

```bash
# Ver eventos do serviço
docker service ps webapp-stack_webapp --no-trunc

# Ver logs detalhados
docker service logs webapp-stack_webapp

# Inspecionar configuração
docker service inspect webapp-stack_webapp --pretty
```

### Traefik não roteia corretamente

```bash
# Verificar configuração do Traefik
curl http://localhost:8080/api/rawdata | jq

# Ver routers ativos
curl http://localhost:8080/api/http/routers | jq

# Verificar backend health
curl http://localhost:8080/api/http/services | jq
```

### Problemas de DNS no Swarm

```bash
# Testar DNS resolution
docker run --rm --network webapp-stack_monitoring alpine \
  nslookup tasks.webapp

# Verificar overlay network
docker network inspect webapp-stack_monitoring
```

### Volume NFS não monta

```bash
# Verificar montagem em cada node
docker service ps webapp-stack_webapp

# Testar NFS manualmente
mount -t nfs4 192.168.64.5:/dados_webapp /mnt/test
```

## 🔄 Manutenção

### Backup

```bash
# Backup volumes
docker run --rm \
  -v webapp-stack_grafana_data:/data \
  -v $(pwd):/backup \
  alpine tar czf /backup/grafana-backup-$(date +%Y%m%d).tar.gz /data

# Backup configs
tar czf configs-backup-$(date +%Y%m%d).tar.gz \
  docker-stack.yml prometheus.yml grafana/
```

### Remover Stack

```bash
# Remover todos os serviços
docker stack rm webapp-stack

# Aguardar limpeza completa
watch docker stack ps webapp-stack

# Remover volumes (CUIDADO!)
docker volume rm webapp-stack_grafana_data
docker volume rm webapp-stack_prometheus_data

# Leave swarm (se necessário)
docker swarm leave --force
```

## 📈 Scaling Recommendations

### Ambiente de Desenvolvimento
- WebApp: 1-2 réplicas
- Monitoring: 1 réplica cada

### Ambiente de Produção (Single Node)
- WebApp: 3-5 réplicas
- Traefik: 1 réplica
- Prometheus/Grafana: 1 réplica cada

### Ambiente de Produção (Multi-Node)
- WebApp: 5-10 réplicas (distribuído)
- Traefik: 2+ réplicas (com constraints)
- Prometheus: 1 réplica (manager node)
- Grafana: 1 réplica (manager node)
- cAdvisor/Node-Exporter: global (todos os nodes)

## 🎯 Próximos Passos

1. **CI/CD Pipeline:**
   - Automatizar build e deploy
   - Testes automáticos antes de deploy

2. **Multi-Node Cluster:**
   - Adicionar worker nodes
   - Distribuir carga

3. **Service Mesh:**
   - Implementar Istio/Linkerd
   - Traffic management avançado

4. **Observability:**
   - Adicionar tracing (Jaeger)
   - Logs centralizados (ELK/Loki)

## 📚 Recursos

- [Docker Swarm Docs](https://docs.docker.com/engine/swarm/)
- [Traefik Docs](https://doc.traefik.io/traefik/)
- [Prometheus Service Discovery](https://prometheus.io/docs/prometheus/latest/configuration/configuration/#docker_sd_config)
- [Grafana Provisioning](https://grafana.com/docs/grafana/latest/administration/provisioning/)