# 🎯 Guia Prático: Cenários e Casos de Uso

## 📖 Índice de Cenários
1. [Deploy Inicial Completo](#cenário-1-deploy-inicial-completo)
2. [Update de Aplicação Zero-Downtime](#cenário-2-update-zero-downtime)
3. [Responder a Aumento de Tráfego](#cenário-3-responder-a-aumento-de-tráfego)
4. [Recovery de Falha](#cenário-4-recovery-de-falha)
5. [Adicionar HTTPS com Let's Encrypt](#cenário-5-adicionar-https)
6. [Debug de Problemas de Performance](#cenário-6-debug-performance)

---

## Cenário 1: Deploy Inicial Completo

### **Situação:**
Queres fazer o primeiro deploy do sistema completo em produção.

### **Passo a Passo:**

```bash
# 1. Preparar o ambiente
cd /caminho/do/projeto

# 2. Build da imagem
docker build -t webapp:latest .

# 3. Verificar que a imagem foi criada
docker images | grep webapp
# Esperado: webapp   latest   abc123def456   X minutes ago   XMB

# 4. Usar o script de deploy automatizado
chmod +x deploy-swarm.sh
./deploy-swarm.sh start
```

### **O que acontece:**
```
✓ Docker Swarm inicializado
✓ Rede traefik-public criada
✓ Imagem buildada
✓ Stack deployada com:
  - Traefik (1 réplica)
  - WebApp (3 réplicas)
  - Prometheus (1 réplica)
  - Grafana (1 réplica)
  - cAdvisor (global)
  - Node Exporter (global)
```

### **Verificar:**
```bash
# Ver status de todos os serviços
docker stack services webapp-stack

# Deve mostrar:
# webapp-stack_traefik      1/1
# webapp-stack_webapp       3/3  ← 3 réplicas rodando
# webapp-stack_prometheus   1/1
# webapp-stack_grafana      1/1
# webapp-stack_cadvisor     1/1
# webapp-stack_node-exporter 1/1
```

### **Testar:**
```bash
# Testar conectividade
./test-loadbalancing.sh all

# Acessar serviços
curl http://webapp.localhost/health
# Esperado: ok

# Browser:
open http://webapp.localhost        # Aplicação
open http://traefik.localhost       # Dashboard Traefik
open http://grafana.localhost       # Grafana
```

### **Tempo Estimado:** 5-10 minutos

---

## Cenário 2: Update Zero-Downtime

### **Situação:**
Fizeste mudanças no código e precisas fazer deploy da nova versão SEM parar o serviço.

### **Código de Exemplo (mudança no app.py):**
```python
# app.py - Adicionar versão ao health endpoint
@app.route("/health")
def health():
    return jsonify({"status": "ok", "version": "2.0"}), 200
```

### **Processo de Update:**

```bash
# 1. Build nova versão com tag
docker build -t webapp:v2.0 .

# 2. Opção A: Update automático com script
./deploy-swarm.sh update webapp

# OU

# 2. Opção B: Update manual com controle fino
docker service update \
  --image webapp:v2.0 \
  --update-parallelism 1 \
  --update-delay 10s \
  --update-failure-action rollback \
  webapp-stack_webapp
```

### **O que acontece internamente:**
```
Início: [v1] [v1] [v1]  ← 3 réplicas versão 1.0

Passo 1: [v2] [v1] [v1]  ← 1ª réplica atualizada
         ↑ aguarda 10s e verifica health

Passo 2: [v2] [v2] [v1]  ← 2ª réplica atualizada
         ↑ aguarda 10s e verifica health

Passo 3: [v2] [v2] [v2]  ← 3ª réplica atualizada
         ✓ Update completo!

Durante TODO o processo:
- Traefik mantém tráfego ativo
- Usuários não percebem downtime
- Health checks garantem estabilidade
```

### **Monitorizar Update:**
```bash
# Terminal 1: Ver progresso
watch -n 1 'docker service ps webapp-stack_webapp'

# Terminal 2: Ver logs
docker service logs -f webapp-stack_webapp

# Terminal 3: Fazer requests contínuos
while true; do 
  curl -s http://webapp.localhost/health | jq
  sleep 1
done
```

### **Rollback se necessário:**
```bash
# Se algo correr mal, rollback é instantâneo
docker service rollback webapp-stack_webapp

# Volta para: [v1] [v1] [v1]
```

### **Tempo Estimado:** 1-2 minutos (depende do número de réplicas)

---

## Cenário 3: Responder a Aumento de Tráfego

### **Situação:**
Estás a ver no Grafana que o CPU está alto e response time a aumentar. Precisas de mais réplicas.

### **Sintomas no Grafana:**
- CPU usage: 75-90%
- Request rate: 500+ req/s
- Response time: 800ms (era 200ms)

### **Solução Rápida:**

```bash
# Escalar de 3 para 8 réplicas
docker service scale webapp-stack_webapp=8

# Verificar
docker service ls | grep webapp
# webapp-stack_webapp   replicated   8/8
```

### **Monitorizar Impacto:**
```bash
# Ver distribuição de carga no Grafana
# Dashboard → CPU Usage per Container
# Agora tens 8 containers distribuindo a carga

# Ver no Prometheus
curl -s http://prometheus.localhost/api/v1/query \
  --data-urlencode 'query=sum(rate(container_cpu_usage_seconds_total{container_label_com_docker_swarm_service_name="webapp-stack_webapp"}[1m]))' | jq
```

### **Resultado Esperado:**
```
ANTES (3 réplicas):
- CPU per replica: 80%
- Response time: 800ms
- Requests per replica: 166 req/s

DEPOIS (8 réplicas):
- CPU per replica: 35%
- Response time: 250ms
- Requests per replica: 62 req/s
```

### **Quando Reduzir:**
```bash
# Quando tráfego normalizar (ex: fim do dia)
docker service scale webapp-stack_webapp=3

# Ou usar auto-scaling (requer configuração adicional)
```

### **Tempo de Resposta:** < 30 segundos para novas réplicas estarem UP

---

## Cenário 4: Recovery de Falha

### **Situação:**
Uma réplica crashou ou o node ficou indisponível.

### **Simular Falha para Teste:**
```bash
# Descobrir ID de uma réplica
docker service ps webapp-stack_webapp

# Matar uma réplica específica
docker kill <container_id>
```

### **O que acontece automaticamente:**

```
Estado Inicial:
[Replica-1: RUNNING] 
[Replica-2: RUNNING]
[Replica-3: RUNNING]

Falha detectada:
[Replica-1: FAILED]   ← Crashou!
[Replica-2: RUNNING]
[Replica-3: RUNNING]

Swarm reage (automático):
[Replica-1: STARTING] ← Nova instância
[Replica-2: RUNNING]
[Replica-3: RUNNING]

Traefik ajusta (automático):
- Remove Replica-1 falha do pool
- Direciona tráfego para Replica-2 e 3
- Adiciona nova Replica-1 quando estiver healthy

Resultado:
[Replica-1: RUNNING]  ← Recuperada
[Replica-2: RUNNING]
[Replica-3: RUNNING]
```

### **Verificar Recovery:**
```bash
# Ver histórico de eventos
docker service ps webapp-stack_webapp

# Output mostra:
# ID      NAME                    IMAGE    NODE   DESIRED  CURRENT STATE
# abc123  webapp-stack_webapp.1   webapp   node1  Running  Running 10s ago
# def456  \_ webapp-stack_webapp.1 webapp  node1  Shutdown Failed 15s ago
#         ↑ Réplica anterior que falhou

# Dashboard Traefik mostra:
# - Health check failed
# - Backend removed
# - Backend re-added (nova réplica)
```

### **Alertas no Prometheus:**
```promql
# Configurar alerta para falhas
ALERT ServiceDown
  IF absent(up{job="webapp"}) == 1
  FOR 1m
  ANNOTATIONS {
    summary = "WebApp service down",
    description = "WebApp has been down for more than 1 minute."
  }
```

### **Tempo de Recovery:** 10-30 segundos (automático)

---

## Cenário 5: Adicionar HTTPS

### **Situação:**
Sistema está rodando em HTTP, precisas adicionar HTTPS com certificado Let's Encrypt.

### **Pré-requisitos:**
- Domínio apontado para o teu servidor (ex: webapp.example.com)
- Portas 80 e 443 abertas

### **Modificar docker-stack.yml:**

```yaml
services:
  traefik:
    command:
      # ... comandos existentes ...
      
      # ADICIONAR:
      - "--certificatesresolvers.letsencrypt.acme.email=teu@email.com"
      - "--certificatesresolvers.letsencrypt.acme.storage=/certificates/acme.json"
      - "--certificatesresolvers.letsencrypt.acme.tlschallenge=true"
      
      # Redirect HTTP → HTTPS
      - "--entrypoints.web.http.redirections.entryPoint.to=websecure"
      - "--entrypoints.web.http.redirections.entryPoint.scheme=https"
    
    volumes:
      # ... volumes existentes ...
      - traefik-certificates:/certificates
    
    deploy:
      labels:
        # ... labels existentes ...
        
        # ADICIONAR HTTPS:
        - "traefik.http.routers.webapp-secure.rule=Host(`webapp.example.com`)"
        - "traefik.http.routers.webapp-secure.entrypoints=websecure"
        - "traefik.http.routers.webapp-secure.tls=true"
        - "traefik.http.routers.webapp-secure.tls.certresolver=letsencrypt"
```

### **Deploy HTTPS:**

```bash
# 1. Preparar certificados (primeira vez)
touch acme.json
chmod 600 acme.json

# 2. Update stack
docker stack deploy -c docker-stack.yml webapp-stack

# 3. Verificar certificado
curl -I https://webapp.example.com
# Esperado: HTTP/2 200
# ↑ Note HTTP/2 (indica HTTPS)
```

### **Verificar no Traefik Dashboard:**
```
http://traefik.localhost/dashboard

Routers:
  ✓ webapp-secure
    - Rule: Host(`webapp.example.com`)
    - TLS: ✓ Enabled
    - Certificate: Let's Encrypt
    - Valid until: 2025-03-01
```

### **Auto-Renewal:**
Let's Encrypt renova automaticamente certificados a cada 60 dias.

### **Tempo de Setup:** 5 minutos + tempo de propagação DNS

---

## Cenário 6: Debug de Performance

### **Situação:**
Sistema está lento, precisas identificar o bottleneck.

### **Metodologia de Debug:**

#### **1. Verificar Distribuição de Carga**

```bash
# Test load distribution
./test-loadbalancing.sh distribution

# Esperado (3 réplicas):
# backend_0: 17 requests (34%)
# backend_1: 16 requests (32%)
# backend_2: 17 requests (34%)

# ⚠️ Problema se vires:
# backend_0: 45 requests (90%)  ← Uma réplica recebendo tudo!
# backend_1: 3 requests (6%)
# backend_2: 2 requests (4%)
```

**Solução:** Verificar sticky sessions ou health checks.

#### **2. Identificar Réplicas Lentas**

```bash
# Query Prometheus - Response time por container
curl -s http://prometheus.localhost/api/v1/query \
  --data-urlencode 'query=rate(traefik_service_request_duration_seconds_sum[5m]) by (server)' | jq

# Se uma réplica está muito mais lenta:
# server1: 0.2s
# server2: 0.2s
# server3: 2.5s  ← PROBLEMA!
```

**Solução:** Investigar réplica específica:
```bash
# Ver logs da réplica lenta
docker service logs webapp-stack_webapp | grep server3

# Reiniciar réplica problemática
docker service update --force webapp-stack_webapp
```

#### **3. Verificar Recursos**

```bash
# CPU e Memory por container
docker stats --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}"

# Grafana query:
sum by (container_label_com_docker_swarm_task_name) (
  rate(container_cpu_usage_seconds_total[5m])
) * 100

# ⚠️ Se vires CPU > 80% sustentado:
```

**Solução:** Escalar ou otimizar código.

#### **4. Network Bottleneck?**

```bash
# Ver network I/O
docker stats --format "table {{.Name}}\t{{.NetIO}}"

# Prometheus query:
rate(container_network_receive_bytes_total[5m])
```

#### **5. Disk I/O Bottleneck?**

```bash
# Query disk operations
rate(container_fs_reads_total[5m])
rate(container_fs_writes_total[5m])
```

**Se NFS está lento:**
```bash
# Testar latência NFS
time dd if=/dev/zero of=/mnt/dados_webapp/test.txt bs=1M count=100
# Deveria ser < 2s
```

### **Checklist Completo:**

- [ ] Load balancing distribui uniformemente?
- [ ] Alguma réplica com response time alto?
- [ ] CPU/Memory dentro dos limites?
- [ ] Network I/O normal?
- [ ] Disk I/O do NFS aceitável?
- [ ] Database/serviços externos lentos?
- [ ] Logs mostram erros?

---

## 🎓 Comandos Úteis por Contexto

### **Desenvolvimento Local:**
```bash
# Usar docker-compose
docker-compose up -d
docker-compose logs -f
docker-compose down
```

### **Deploy em Produção:**
```bash
# Usar docker stack
./deploy-swarm.sh start
docker stack services webapp-stack
docker service logs -f webapp-stack_webapp
```

### **Monitoring:**
```bash
# Ver métricas
curl http://prometheus.localhost/api/v1/query --data-urlencode 'query=up'

# Testar load balancing
./test-loadbalancing.sh all

# Dashboard Grafana
open http://grafana.localhost
```

### **Troubleshooting:**
```bash
# Ver todos os eventos
docker service ps webapp-stack_webapp --no-trunc

# Inspecionar config
docker service inspect webapp-stack_webapp --pretty

# Verificar networks
docker network inspect webapp-stack_monitoring
```

### **Manutenção:**
```bash
# Backup volumes
docker run --rm -v webapp-stack_grafana_data:/data -v $(pwd):/backup \
  alpine tar czf /backup/grafana-backup.tar.gz /data

# Limpar recursos não usados
docker system prune -a

# Estatísticas em tempo real
docker stats
```

---

## 📚 Templates de Configuração

### **Template: Adicionar Rate Limiting**
```yaml
labels:
  - "traefik.http.middlewares.rate-limit.ratelimit.average=100"
  - "traefik.http.middlewares.rate-limit.ratelimit.burst=50"
  - "traefik.http.routers.webapp.middlewares=rate-limit"
```

### **Template: Adicionar Basic Auth**
```bash
# Gerar password hash
htpasswd -nb admin password123

# Adicionar labels:
labels:
  - "traefik.http.middlewares.auth.basicauth.users=admin:$$apr1$$..."
  - "traefik.http.routers.webapp.middlewares=auth"
```

### **Template: Headers de Segurança**
```yaml
labels:
  - "traefik.http.middlewares.security-headers.headers.stsSeconds=31536000"
  - "traefik.http.middlewares.security-headers.headers.stsIncludeSubdomains=true"
  - "traefik.http.routers.webapp.middlewares=security-headers"
```

---

## 🚨 Resolução Rápida de Problemas

### **Problema: Serviços não iniciam**
```bash
docker service ps webapp-stack_webapp --no-trunc
# Ver erro específico e corrigir configuração
```

### **Problema: Traefik não roteia**
```bash
curl http://traefik.localhost:8080/api/rawdata | jq
# Verificar se backend está registado
```

### **Problema: DNS não resolve**
```bash
# Adicionar ao /etc/hosts:
127.0.0.1 webapp.localhost traefik.localhost
```

### **Problema: Health check falha**
```bash
# Testar manualmente
docker exec <container_id> curl localhost:8080/health
```

---

Estes cenários cobrem os casos mais comuns que vais encontrar. Guarda este ficheiro como referência rápida!