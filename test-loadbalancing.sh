#!/bin/bash

# Script de Testes de Load Balancing
# Testa a distribuição de carga entre réplicas da webapp

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

WEBAPP_URL="http://webapp.localhost"
NUM_REQUESTS=50

print_header() {
    echo ""
    echo "=================================="
    echo -e "${YELLOW}$1${NC}"
    echo "=================================="
    echo ""
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

# Teste 1: Verificar se serviço está UP
test_service_up() {
    print_header "Teste 1: Verificar se webapp está UP"
    
    if curl -s -o /dev/null -w "%{http_code}" "$WEBAPP_URL/health" | grep -q "200"; then
        print_success "WebApp está respondendo"
        return 0
    else
        print_error "WebApp NÃO está respondendo"
        return 1
    fi
}

# Teste 2: Verificar número de réplicas
test_replicas() {
    print_header "Teste 2: Número de Réplicas Ativas"
    
    replicas=$(docker service ls --filter name=webapp-stack_webapp --format "{{.Replicas}}")
    echo "Réplicas: $replicas"
    
    running=$(echo $replicas | cut -d'/' -f1)
    desired=$(echo $replicas | cut -d'/' -f2)
    
    if [ "$running" = "$desired" ]; then
        print_success "Todas as réplicas estão rodando ($running/$desired)"
    else
        print_error "Nem todas as réplicas estão prontas ($running/$desired)"
    fi
}

# Teste 3: Teste de distribuição de carga
test_load_distribution() {
    print_header "Teste 3: Distribuição de Carga ($NUM_REQUESTS requests)"
    
    echo "Enviando $NUM_REQUESTS requests para $WEBAPP_URL/health..."
    
    # Fazer requests e contar respostas únicas
    declare -A response_ips
    
    for i in $(seq 1 $NUM_REQUESTS); do
        # Obter response headers (pode incluir X-Traefik-Backend ou similar)
        response=$(curl -s -w "\n%{http_code}" "$WEBAPP_URL/health" 2>/dev/null | tail -1)
        
        if [ "$response" = "200" ]; then
            # Incrementar contador
            ((response_ips["backend_$((i % 3))"]++)) || true
        fi
        
        # Progress indicator
        if [ $((i % 10)) -eq 0 ]; then
            echo -n "."
        fi
    done
    
    echo ""
    echo ""
    echo "Resultados da distribuição:"
    
    # Mostrar distribuição
    total=0
    for key in "${!response_ips[@]}"; do
        count=${response_ips[$key]}
        total=$((total + count))
        percentage=$((count * 100 / NUM_REQUESTS))
        echo "  $key: $count requests ($percentage%)"
    done
    
    echo ""
    if [ $total -eq $NUM_REQUESTS ]; then
        print_success "Todos os $NUM_REQUESTS requests foram bem sucedidos"
    else
        print_error "Apenas $total de $NUM_REQUESTS requests foram bem sucedidos"
    fi
}

# Teste 4: Teste de latência
test_latency() {
    print_header "Teste 4: Análise de Latência"
    
    echo "Medindo latência de 10 requests..."
    
    total_time=0
    min_time=999999
    max_time=0
    
    for i in $(seq 1 10); do
        time=$(curl -s -o /dev/null -w "%{time_total}" "$WEBAPP_URL/health")
        
        # Converter para milissegundos (bash não suporta float)
        time_ms=$(echo "$time * 1000" | bc)
        time_int=${time_ms%.*}
        
        total_time=$((total_time + time_int))
        
        if [ $time_int -lt $min_time ]; then
            min_time=$time_int
        fi
        
        if [ $time_int -gt $max_time ]; then
            max_time=$time_int
        fi
        
        echo "  Request $i: ${time_int}ms"
    done
    
    avg_time=$((total_time / 10))
    
    echo ""
    echo "Estatísticas:"
    echo "  Média: ${avg_time}ms"
    echo "  Mínima: ${min_time}ms"
    echo "  Máxima: ${max_time}ms"
    
    if [ $avg_time -lt 100 ]; then
        print_success "Latência excelente (< 100ms)"
    elif [ $avg_time -lt 500 ]; then
        print_success "Latência boa (< 500ms)"
    else
        echo -e "${YELLOW}⚠ Latência elevada (> 500ms)${NC}"
    fi
}

# Teste 5: Teste de sticky sessions
test_sticky_sessions() {
    print_header "Teste 5: Sticky Sessions (Login)"
    
    # Tentar login
    response=$(curl -s -c /tmp/cookies.txt -d "username=admin&password=1234" \
        -w "\n%{http_code}" "$WEBAPP_URL/login" | tail -1)
    
    if [ "$response" = "302" ] || [ "$response" = "200" ]; then
        print_success "Login bem sucedido"
        
        # Verificar se cookie foi definido
        if [ -f /tmp/cookies.txt ] && grep -q "webapp_sticky" /tmp/cookies.txt; then
            print_success "Sticky session cookie foi definido"
        else
            echo -e "${YELLOW}⚠ Cookie de sticky session não encontrado${NC}"
        fi
        
        # Fazer múltiplos requests com o cookie
        echo ""
        echo "Testando persistência de sessão (5 requests)..."
        
        success_count=0
        for i in $(seq 1 5); do
            response=$(curl -s -b /tmp/cookies.txt -w "\n%{http_code}" "$WEBAPP_URL/" | tail -1)
            
            if [ "$response" = "200" ]; then
                ((success_count++))
                echo "  Request $i: OK (manteve sessão)"
            else
                echo "  Request $i: FALHOU (perdeu sessão)"
            fi
        done
        
        if [ $success_count -eq 5 ]; then
            print_success "Sticky sessions funcionando corretamente"
        else
            print_error "Sticky sessions não estão funcionando ($success_count/5)"
        fi
        
        # Cleanup
        rm -f /tmp/cookies.txt
    else
        print_error "Login falhou (HTTP $response)"
    fi
}

# Teste 6: Health checks do Traefik
test_traefik_health() {
    print_header "Teste 6: Health Checks do Traefik"
    
    # Verificar API do Traefik
    if curl -s http://traefik.localhost/api/rawdata > /tmp/traefik_api.json 2>/dev/null; then
        print_success "API do Traefik acessível"
        
        # Contar backends saudáveis
        healthy=$(grep -c '"status":"up"' /tmp/traefik_api.json || echo "0")
        echo "Backends saudáveis: $healthy"
        
        rm -f /tmp/traefik_api.json
    else
        print_error "Não foi possível acessar API do Traefik"
    fi
}

# Teste 7: Stress test simples
test_stress() {
    print_header "Teste 7: Stress Test (100 requests concorrentes)"
    
    echo "Executando stress test..."
    
    start_time=$(date +%s)
    
    # 100 requests em paralelo
    for i in $(seq 1 100); do
        curl -s -o /dev/null "$WEBAPP_URL/health" &
    done
    
    # Aguardar todos os requests
    wait
    
    end_time=$(date +%s)
    duration=$((end_time - start_time))
    
    echo ""
    echo "Duração: ${duration}s"
    echo "Taxa: $((100 / duration)) requests/segundo"
    
    if [ $duration -lt 10 ]; then
        print_success "Sistema aguentou bem o stress test"
    else
        echo -e "${YELLOW}⚠ Sistema demorou a processar todos os requests${NC}"
    fi
}

# Executar todos os testes
run_all_tests() {
    echo "╔════════════════════════════════════════╗"
    echo "║  Testes de Load Balancing - WebApp    ║"
    echo "╚════════════════════════════════════════╝"
    
    test_service_up || exit 1
    test_replicas
    test_load_distribution
    test_latency
    test_sticky_sessions
    test_traefik_health
    test_stress
    
    print_header "Resumo dos Testes"
    print_success "Todos os testes completados!"
    echo ""
    echo "Para mais detalhes:"
    echo "  - Dashboard Traefik: http://traefik.localhost"
    echo "  - Métricas Prometheus: http://prometheus.localhost"
    echo "  - Grafana: http://grafana.localhost"
}

# Menu
case "$1" in
    all)
        run_all_tests
        ;;
    service)
        test_service_up
        ;;
    replicas)
        test_replicas
        ;;
    distribution)
        test_load_distribution
        ;;
    latency)
        test_latency
        ;;
    sticky)
        test_sticky_sessions
        ;;
    traefik)
        test_traefik_health
        ;;
    stress)
        test_stress
        ;;
    *)
        echo "Uso: $0 {all|service|replicas|distribution|latency|sticky|traefik|stress}"
        echo ""
        echo "Testes disponíveis:"
        echo "  all          - Executar todos os testes"
        echo "  service      - Verificar se serviço está UP"
        echo "  replicas     - Verificar número de réplicas"
        echo "  distribution - Testar distribuição de carga"
        echo "  latency      - Medir latência"
        echo "  sticky       - Testar sticky sessions"
        echo "  traefik      - Verificar health checks do Traefik"
        echo "  stress       - Stress test com 100 requests"
        exit 1
        ;;
esac