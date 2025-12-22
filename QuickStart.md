## 📝 Quick Start

```bash
# Inicializar containers
docker-compose up -d

#Inicializae e configurar o Container Orchestrator (Docker Swarm) e fazer o deployment completo da aplicação nele
./deploy-swarm.sh start

# Efetuar testes
./test-loadbalancing-mac.sh all
```