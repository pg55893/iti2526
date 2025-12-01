#!/bin/bash

# Script de Deploy Automatizado - Docker Swarm + Traefik
# Uso: ./deploy-swarm.sh [start|stop|update|logs|scale]

set -e

STACK_NAME="webapp-stack"
IMAGE_NAME="webapp:latest"

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Funções auxiliares
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}ℹ $1${NC}"
}

# Verificar se Swarm está ativo
check_swarm() {
    if ! docker info 2>/dev/null | grep -q "Swarm: active"; then
        print_error "Docker Swarm não está ativo!"
        print_info "Inicializando Swarm..."
        docker swarm init
        print_success "Swarm inicializado"
    else
        print_success "Swarm já está ativo"
    fi
}

# Verificar/criar rede overlay
check_network() {
    if ! docker network ls | grep -q "traefik-public"; then
        print_info "Criando rede traefik-public..."
        docker network create --driver overlay --attachable traefik-public
        print_success "Rede criada"
    else
        print_success "Rede traefik-public já existe"
    fi
}

# Build da imagem
build_image() {
    print_info "Building imagem $IMAGE_NAME..."
    docker build -t $IMAGE_NAME . || {
        print_error "Falha no build da imagem"
        exit 1
    }
    print_success "Imagem buildada com sucesso"
}

# Deploy da stack
deploy_stack() {
    print_info "Fazendo deploy da stack $STACK_NAME..."
    docker stack deploy -c docker-stack.yml $STACK_NAME || {
        print_error "Falha no deploy da stack"
        exit 1
    }
    print_success "Stack deployada com sucesso"
    
    # Aguardar serviços ficarem prontos
    print_info "Aguardando serviços ficarem prontos..."
    sleep 5
    
    echo ""
    print_info "Status dos serviços:"
    docker stack services $STACK_NAME
}

# Remover stack
remove_stack() {
    print_info "Removendo stack $STACK_NAME..."
    docker stack rm $STACK_NAME || {
        print_error "Falha ao remover stack"
        exit 1
    }
    print_success "Stack removida"
    
    # Aguardar limpeza
    print_info "Aguardando limpeza completa..."
    while docker stack ps $STACK_NAME 2>/dev/null; do
        sleep 2
    done
    print_success "Limpeza concluída"
}

# Update de serviço
update_service() {
    local service=$1
    
    if [ -z "$service" ]; then
        print_error "Especifica o serviço a atualizar"
        echo "Uso: $0 update [webapp|prometheus|grafana]"
        exit 1
    fi
    
    print_info "Atualizando serviço ${STACK_NAME}_${service}..."
    
    if [ "$service" = "webapp" ]; then
        # Re-build imagem antes de update
        build_image
    fi
    
    docker service update \
        --image $IMAGE_NAME \
        --update-parallelism 1 \
        --update-delay 10s \
        ${STACK_NAME}_${service} || {
        print_error "Falha ao atualizar serviço"
        exit 1
    }
    
    print_success "Serviço atualizado"
}

# Ver logs
show_logs() {
    local service=$1
    
    if [ -z "$service" ]; then
        print_info "Logs disponíveis para:"
        docker stack services $STACK_NAME --format "{{.Name}}" | sed "s/${STACK_NAME}_/  - /"
        echo ""
        echo "Uso: $0 logs [nome_do_servico]"
        exit 0
    fi
    
    print_info "Logs do serviço ${STACK_NAME}_${service}:"
    docker service logs -f ${STACK_NAME}_${service}
}

# Escalar serviço
scale_service() {
    local service=$1
    local replicas=$2
    
    if [ -z "$service" ] || [ -z "$replicas" ]; then
        print_error "Uso: $0 scale [servico] [num_replicas]"
        echo "Exemplo: $0 scale webapp 5"
        exit 1
    fi
    
    print_info "Escalando ${STACK_NAME}_${service} para $replicas réplicas..."
    docker service scale ${STACK_NAME}_${service}=$replicas || {
        print_error "Falha ao escalar serviço"
        exit 1
    }
    
    print_success "Serviço escalado"
    docker service ps ${STACK_NAME}_${service}
}

# Status da stack
show_status() {
    echo ""
    print_info "=== Status da Stack $STACK_NAME ==="
    echo ""
    
    print_info "Serviços:"
    docker stack services $STACK_NAME
    echo ""
    
    print_info "Tasks:"
    docker stack ps $STACK_NAME --no-trunc
    echo ""
    
    print_info "URLs de Acesso:"
    echo "  WebApp:    http://webapp.localhost"
    echo "  Traefik:   http://traefik.localhost"
    echo "  Prometheus: http://prometheus.localhost"
    echo "  Grafana:   http://grafana.localhost"
    echo "  cAdvisor:  http://cadvisor.localhost"
    echo ""
}

# Teste de conectividade
test_services() {
    print_info "Testando conectividade dos serviços..."
    echo ""
    
    services=(
        "webapp.localhost:80"
        "traefik.localhost:80"
        "prometheus.localhost:80"
        "grafana.localhost:80"
        "cadvisor.localhost:80"
    )
    
    for service in "${services[@]}"; do
        if curl -s -o /dev/null -w "%{http_code}" "http://$service" | grep -q "200\|302"; then
            print_success "$service está acessível"
        else
            print_error "$service NÃO está acessível"
        fi
    done
    echo ""
}

# Menu principal
case "$1" in
    start)
        print_info "=== Iniciando Deploy Completo ==="
        check_swarm
        check_network
        build_image
        deploy_stack
        echo ""
        show_status
        echo ""
        print_success "Deploy completo!"
        print_info "Execute '$0 test' para testar conectividade"
        ;;
    
    stop)
        print_info "=== Parando Stack ==="
        remove_stack
        print_success "Stack parada"
        ;;
    
    update)
        update_service $2
        show_status
        ;;
    
    logs)
        show_logs $2
        ;;
    
    scale)
        scale_service $2 $3
        ;;
    
    status)
        show_status
        ;;
    
    test)
        test_services
        ;;
    
    restart)
        print_info "=== Reiniciando Stack ==="
        remove_stack
        sleep 3
        deploy_stack
        show_status
        print_success "Stack reiniciada"
        ;;
    
    *)
        echo "Uso: $0 {start|stop|restart|update|logs|scale|status|test}"
        echo ""
        echo "Comandos:"
        echo "  start              - Deploy completo da stack"
        echo "  stop               - Parar e remover stack"
        echo "  restart            - Reiniciar stack completa"
        echo "  update [servico]   - Atualizar serviço específico"
        echo "  logs [servico]     - Ver logs de um serviço"
        echo "  scale [servico] N  - Escalar serviço para N réplicas"
        echo "  status             - Ver status da stack"
        echo "  test               - Testar conectividade dos serviços"
        echo ""
        echo "Exemplos:"
        echo "  $0 start"
        echo "  $0 update webapp"
        echo "  $0 logs webapp"
        echo "  $0 scale webapp 5"
        echo "  $0 test"
        exit 1
        ;;
esac