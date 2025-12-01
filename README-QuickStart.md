# Tornar scripts executáveis
chmod +x deploy-swarm.sh test-loadbalancing.sh

# Deploy completo
./deploy-swarm.sh start

# Testar
./test-loadbalancing.sh all
```

### **2. Aceder aos Serviços:**
- **WebApp:** http://webapp.localhost
- **Traefik Dashboard:** http://traefik.localhost
- **Prometheus:** http://prometheus.localhost
- **Grafana:** http://grafana.localhost
- **cAdvisor:** http://cadvisor.localhost

---

## 🎯 **Principais Benefícios que Vais Obter:**

✅ **Alta Disponibilidade** - 3 réplicas da webapp rodando simultaneamente  
✅ **Load Balancing Automático** - Traefik distribui carga uniformemente  
✅ **Zero-Downtime Updates** - Atualizar sem parar o serviço  
✅ **Auto-Recovery** - Se uma réplica cai, outra sobe automaticamente  
✅ **Scaling Simples** - `docker service scale webapp=10`  
✅ **Monitoring Avançado** - Métricas Traefik + Prometheus + Grafana  
✅ **Health Checks** - Réplicas não-saudáveis removidas automaticamente  
✅ **Sticky Sessions** - Sessões autenticadas mantidas  

---

## 📋 **Próximos Passos Recomendados:**

1. **Lê primeiro:** `MIGRACAO-COMPOSE-SWARM.md` - entender as diferenças
2. **Depois:** `README-SWARM.md` - guia completo de deployment
3. **Deployment:** Usar `deploy-swarm.sh start`
4. **Testar:** `test-loadbalancing.sh all`
5. **Explorar:** `EXEMPLOS-PRATICOS.md` - cenários reais

---

## 💡 **Dicas Importantes:**

- **Desenvolvimento:** Continue usando `docker-compose.yml` 
- **Produção:** Use `docker-stack.yml` com Swarm
- **Substitui** `prometheus.yml` pelo `prometheus-swarm.yml` antes do deploy
- **Passwords:** Muda as passwords default antes de produção!
- **HTTPS:** Consulta o cenário 5 em `EXEMPLOS-PRATICOS.md`

---

## 🛠️ **Estrutura Final do Projeto:**
```
projeto/
├── app.py                          (já tens)
├── Dockerfile                      (já tens)
├── requirements.txt                (já tens)
├── docker-compose.yml              (já tens - dev)
├── docker-stack.yml                (NOVO - produção)
├── prometheus.yml                  (substituir por prometheus-swarm.yml)
├── deploy-swarm.sh                 (NOVO - automação)
├── test-loadbalancing.sh           (NOVO - testes)
├── traefik-dashboard.json          (NOVO - importar no Grafana)
├── README-SWARM.md                 (NOVO - documentação)
├── MIGRACAO-COMPOSE-SWARM.md       (NOVO - guia migração)
├── EXEMPLOS-PRATICOS.md            (NOVO - casos de uso)
└── grafana/
    └── provisioning/               (já tens)