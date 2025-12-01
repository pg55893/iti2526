# 🔄 Migração: Docker Compose → Docker Swarm + Traefik

## 📊 Comparação Visual

### **ANTES: Docker Compose (Desenvolvimento)**
```
┌─────────────────────────────────────────┐
│         Host Machine (Porta 8080)       │
│                                         │
│  ┌───────────┐  ┌────────────┐        │
│  │  WebApp   │  │  Prometheus│        │
│  │  (único)  │  │            │        │
│  └─────┬─────┘  └──────┬─────┘        │
│        │                │              │
│  ┌─────┴────────────────┴─────┐       │
│  │      NFS Storage            │       │
│  └─────────────────────────────┘       │
└─────────────────────────────────────────┘

✗ Sem redundância
✗ Sem load balancing
✗ Sem auto-scaling
✗ Sem rolling updates
```

### **DEPOIS: Docker Swarm + Traefik (Produção)**
```
┌──────────────────────────────────────────────────────────┐
│                   Traefik (Load Balancer)                │
│              Portas 80, 443, Dashboard 8080              │
└────────────────────┬─────────────────────────────────────┘
                     │
        ┌────────────┼────────────┐
        │            │            │
   ┌────▼───┐   ┌───▼────┐  ┌───▼────┐
   │WebApp-1│   │WebApp-2│  │WebApp-3│   (3 réplicas)
   │ :8080  │   │ :8080  │  │ :8080  │
   └────┬───┘   └───┬────┘  └───┬────┘
        │           │           │
        └───────────┴───────────┘
                    │
           ┌────────▼────────┐
           │   NFS Storage   │
           └─────────────────┘
                    
        [Prometheus + Grafana]
              (Monitoring)

✓ Alta disponibilidade
✓ Load balancing automático
✓ Auto-scaling fácil
✓ Rolling updates zero-downtime
✓ Health checks automáticos
✓ SSL/TLS terminação
```

---

## 🔑 Principais Diferenças

| Aspecto | Docker Compose | Docker Swarm + Traefik |
|---------|---------------|------------------------|
| **Réplicas** | 1 container fixo | 3+ réplicas distribuídas |
| **Load Balancing** | Não | Sim (Traefik) |
| **Alta Disponibilidade** | Não | Sim |
| **Rolling Updates** | Manual | Automático zero-downtime |
| **Health Checks** | Básico | Avançado (Traefik) |
| **SSL/TLS** | Manual | Automático (Let's Encrypt) |
| **Scaling** | Restart necessário | `docker service scale` |
| **Acesso** | IP:Porta | Domínios (webapp.localhost) |
| **Monitoring** | Básico | Métricas Traefik + Prometheus |
| **Failover** | Não | Automático |

---

## 📋 Checklist de Migração

### **Pré-Migração**
- [ ] Backup dos volumes atuais (Grafana, Prometheus)
- [ ] Build da imagem webapp: `docker build -t webapp:latest .`
- [ ] Verificar NFS está acessível
- [ ] Parar docker-compose: `docker-compose down`

### **Inicialização Swarm**
- [ ] Inicializar Swarm: `docker swarm init`
- [ ] Criar rede overlay: `docker network create --driver overlay traefik-public`
- [ ] Verificar node: `docker node ls`

### **Deployment**
- [ ] Substituir `prometheus.yml` pelo `prometheus-swarm.yml`
- [ ] Deploy stack: `docker stack deploy -c docker-stack.yml webapp-stack`
- [ ] Verificar serviços: `docker stack services webapp-stack`
- [ ] Aguardar todos ficarem `3/3` ou `1/1`

### **Validação**
- [ ] Testar webapp: http://webapp.localhost
- [ ] Testar Traefik: http://traefik.localhost
- [ ] Testar Prometheus: http://prometheus.localhost
- [ ] Testar Grafana: http://grafana.localhost
- [ ] Executar testes: `./test-loadbalancing.sh all`

### **Pós-Migração**
- [ ] Importar dashboard Traefik no Grafana
- [ ] Configurar alertas
- [ ] Documentar URLs de acesso
- [ ] Configurar backups automáticos

---

## 🚀 Comandos Quick Reference

### **Deploy e Gestão**
```bash
# Deploy inicial
./deploy-swarm.sh start

# Ver status
docker stack services webapp-stack
docker stack ps webapp-stack

# Escalar webapp
docker service scale webapp-stack_webapp=5

# Update zero-downtime
./deploy-swarm.sh update webapp

# Ver logs
docker service logs -f webapp-stack_webapp

# Parar tudo
docker stack rm webapp-stack
```

### **Monitoring**
```bash
# Ver métricas Traefik
curl http://traefik.localhost:8080/metrics

# Query Prometheus
curl 'http://prometheus.localhost/api/v1/query?query=up'

# Testar load balancing
./test-loadbalancing.sh all
```

### **Troubleshooting**
```bash
# Ver eventos
docker service ps webapp-stack_webapp --no-trunc

# Inspecionar serviço
docker service inspect webapp-stack_webapp --pretty

# Verificar networks
docker network inspect webapp-stack_monitoring
```

---

## 🎯 Benefícios Imediatos

### **1. Alta Disponibilidade**
- 3 réplicas da webapp rodando simultaneamente
- Se 1 falhar, as outras 2 continuam servindo
- Traefik redireciona automaticamente

### **2. Performance**
- Load balancing distribui carga uniformemente
- Melhor utilização de recursos
- Response time mais consistente

### **3. Zero-Downtime Updates**
```bash
# Atualizar sem parar o serviço
docker service update --image webapp:v2 webapp-stack_webapp

# Rollback se necessário
docker service rollback webapp-stack_webapp
```

### **4. Monitoring Avançado**
- Traefik expõe métricas (RPS, latência, erros)
- Prometheus coleta tudo
- Grafana visualiza em dashboards

### **5. Facilidade Operacional**
```bash
# Escalar é simples
docker service scale webapp-stack_webapp=10

# Logs centralizados
docker service logs webapp-stack_webapp
```

---

## ⚙️ Configurações Importantes

### **Sticky Sessions**
Configurado no `docker-stack.yml`:
```yaml
labels:
  - "traefik.http.services.webapp.loadbalancer.sticky.cookie=true"
  - "traefik.http.services.webapp.loadbalancer.sticky.cookie.name=webapp_sticky"
```
**Por quê?** Mantém usuários autenticados na mesma réplica.

### **Health Checks**
```yaml
labels:
  - "traefik.http.services.webapp.loadbalancer.healthcheck.path=/health"
  - "traefik.http.services.webapp.loadbalancer.healthcheck.interval=10s"
```
**Por quê?** Traefik remove réplicas não-saudáveis automaticamente.

### **Resource Limits**
```yaml
resources:
  limits:
    cpus: '0.50'
    memory: 512M
  reservations:
    cpus: '0.25'
    memory: 256M
```
**Por quê?** Previne que uma réplica consuma todos os recursos.

### **Rolling Update Strategy**
```yaml
update_config:
  parallelism: 1        # 1 de cada vez
  delay: 10s            # Aguardar 10s entre updates
  failure_action: rollback
  order: start-first    # Zero-downtime
```

---

## 📈 Métricas a Monitorizar

### **No Traefik Dashboard**
- Request rate per second
- Average response time
- HTTP status codes distribution
- Active backends

### **No Prometheus**
```promql
# Requests por segundo
rate(traefik_service_requests_total[1m])

# Latência média
rate(traefik_service_request_duration_seconds_sum[5m]) / 
rate(traefik_service_request_duration_seconds_count[5m])

# Taxa de erros
rate(traefik_service_requests_total{code=~"5.."}[5m])
```

### **No Grafana**
- Dashboard "Docker Containers Monitoring" (já existente)
- Dashboard "Traefik Load Balancer Metrics" (novo)

---

## 🔐 Segurança em Produção

### **Obrigatório Mudar:**
```yaml
# Grafana
- GF_SECURITY_ADMIN_PASSWORD=SENHA_FORTE_AQUI

# WebApp
PASSWORD_HASH = bcrypt.generate_password_hash("SENHA_FORTE_AQUI")
```

### **Adicionar HTTPS:**
```yaml
traefik:
  command:
    - "--certificatesresolvers.letsencrypt.acme.email=teu@email.com"
    - "--certificatesresolvers.letsencrypt.acme.storage=/certificates/acme.json"
  
  labels:
    - "traefik.http.routers.webapp.tls.certresolver=letsencrypt"
```

### **Rate Limiting:**
```yaml
labels:
  - "traefik.http.middlewares.rate-limit.ratelimit.average=100"
  - "traefik.http.routers.webapp.middlewares=rate-limit"
```

---

## 🎓 Próximos Passos Recomendados

1. **Multi-Node Cluster**
   - Adicionar mais nodes ao Swarm
   - Distribuir réplicas geograficamente

2. **CI/CD Pipeline**
   - Automatizar build
   - Deploy automático em git push

3. **Logs Centralizados**
   - Adicionar ELK Stack ou Loki
   - Aggregar logs de todas réplicas

4. **Alerting**
   - Configurar Alertmanager
   - Notificações Slack/Email

5. **Backup Automático**
   - Cronjob para backup volumes
   - Replicação geográfica

---

## 💡 Dicas Finais

- **Desenvolvimento:** Continue usando `docker-compose.yml`
- **Produção:** Use `docker-stack.yml` com Swarm
- **Teste sempre:** `./test-loadbalancing.sh all` após mudanças
- **Monitor:** Grafana deve estar sempre visível
- **Documente:** URLs, passwords, procedimentos

---

## 📞 Comandos de Emergência

```bash
# Sistema travou? Reiniciar stack
docker stack rm webapp-stack
sleep 10
docker stack deploy -c docker-stack.yml webapp-stack

# Rollback urgente
docker service rollback webapp-stack_webapp

# Escalar para suportar mais carga
docker service scale webapp-stack_webapp=10

# Ver o que está consumindo recursos
docker stats

# Limpar recursos órfãos
docker system prune -a
```