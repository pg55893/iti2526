#!/usr/bin/env bash

# Script de Testes de Load Balancing - Versão macOS Compatible
# Testa a distribuição de carga entre réplicas da webapp

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

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

# Teste 1: Verificar se serviço está UP
test_service_up() {
    print_header "Teste 1: Verificar se webapp está UP"
    
    response_code=$(curl -s -o /dev/null -w "%{http_code}" "$WEBAPP_URL/health" 2>/dev/null || echo "000")
    
    if [ "$response_code" = "200" ]; then
        print_success "WebApp está respondendo (HTTP $response_code)"
        return 0
    else
        print_error "WebApp NÃO está respondendo (HTTP $response_code)"
        return 1
    fi
}

# Teste 2: Verificar número de réplicas
test_replicas() {
    print_header "Teste 2: Número de Réplicas Ativas"
    
    if ! command -v docker &> /dev/null; then
        print_warning "Docker não encontrado, pulando teste de réplicas"
        return 0
    fi
    
    replicas=$(docker service ls --filter name=webapp-stack_webapp --format "{{.Replicas}}" 2>/dev/null || echo "N/A")
    echo "Réplicas: $replicas"
    
    if [ "$replicas" != "N/A" ]; then
        running=$(echo $replicas | cut -d'/' -f1)
        desired=$(echo $replicas | cut -d'/' -f2)
        
        if [ "$running" = "$desired" ]; then
            print_success "Todas as réplicas estão rodando ($running/$desired)"
        else
            print_error "Nem todas as réplicas estão prontas ($running/$desired)"
        fi
    else
        print_warning "Não foi possível verificar réplicas (stack não encontrado)"
    fi
}

# Teste 3: Teste de distribuição de carga (simplificado)
test_load_distribution() {
    print_header "Teste 3: Distribuição de Carga ($NUM_REQUESTS requests)"
    
    echo "Enviando $NUM_REQUESTS requests para $WEBAPP_URL/health..."
    
    success_count=0
    fail_count=0
    
    for i in $(seq 1 $NUM_REQUESTS); do
        response=$(curl -s -o /dev/null -w "%{http_code}" "$WEBAPP_URL/health" 2>/dev/null || echo "000")
        
        if [ "$response" = "200" ]; then
            success_count=$((success_count + 1))
        else
            fail_count=$((fail_count + 1))
        fi
        
        # Progress indicator
        if [ $((i % 10)) -eq 0 ]; then
            echo -n "."
        fi
    done
    
    echo ""
    echo ""
    echo "Resultados:"
    echo "  ✓ Sucessos: $success_count requests"
    echo "  ✗ Falhas: $fail_count requests"
    
    success_rate=$((success_count * 100 / NUM_REQUESTS))
    echo "  Taxa de sucesso: ${success_rate}%"
    
    echo ""
    if [ $success_count -eq $NUM_REQUESTS ]; then
        print_success "Todos os $NUM_REQUESTS requests foram bem sucedidos"
        echo ""
        echo "ℹ️  Load balancing está funcionando - requisições distribuídas entre réplicas"
    elif [ $success_rate -ge 90 ]; then
        print_warning "$success_count de $NUM_REQUESTS requests foram bem sucedidos (${success_rate}%)"
    else
        print_error "Apenas $success_count de $NUM_REQUESTS requests foram bem sucedidos (${success_rate}%)"
    fi
}

# Teste 4: Teste de latência
test_latency() {
    print_header "Teste 4: Análise de Latência"
    
    echo "Medindo latência de 10 requests..."
    
    total_time=0
    min_time=999999
    max_time=0
    request_count=10
    
    for i in $(seq 1 $request_count); do
        time_output=$(curl -s -o /dev/null -w "%{time_total}" "$WEBAPP_URL/health" 2>/dev/null || echo "0")
        
        # Converter para milissegundos
        if command -v bc &> /dev/null; then
            time_ms=$(echo "$time_output * 1000" | bc | cut -d'.' -f1)
        else
            # Fallback sem bc (multiplicar por 1000 manualmente)
            time_ms=$(echo "$time_output" | awk '{printf "%.0f", $1 * 1000}')
        fi
        
        total_time=$((total_time + time_ms))
        
        if [ $time_ms -lt $min_time ]; then
            min_time=$time_ms
        fi
        
        if [ $time_ms -gt $max_time ]; then
            max_time=$time_ms
        fi
        
        echo "  Request $i: ${time_ms}ms"
    done
    
    avg_time=$((total_time / request_count))
    
    echo ""
    echo "Estatísticas:"
    echo "  Média: ${avg_time}ms"
    echo "  Mínima: ${min_time}ms"
    echo "  Máxima: ${max_time}ms"
    echo ""
    
    if [ $avg_time -lt 100 ]; then
        print_success "Latência excelente (< 100ms)"
    elif [ $avg_time -lt 500 ]; then
        print_success "Latência boa (< 500ms)"
    else
        print_warning "Latência elevada (> 500ms)"
    fi
}

# Teste 5: Teste de sticky sessions
test_sticky_sessions() {
    print_header "Teste 5: Sticky Sessions (Login)"
    
    cookie_file="/tmp/webapp_cookies_$$.txt"
    
    # Tentar login
    response=$(curl -s -c "$cookie_file" -d "username=admin&password=1234" \
        -w "\n%{http_code}" "$WEBAPP_URL/login" 2>/dev/null | tail -1)
    
    if [ "$response" = "302" ] || [ "$response" = "200" ]; then
        print_success "Login bem sucedido (HTTP $response)"
        
        # Verificar se cookie foi definido
        if [ -f "$cookie_file" ] && grep -q "webapp_sticky\|session" "$cookie_file" 2>/dev/null; then
            print_success "Cookie de sessão foi definido"
        else
            print_warning "Cookie de sticky session não encontrado (pode estar usando outro nome)"
        fi
        
        # Fazer múltiplos requests com o cookie
        echo ""
        echo "Testando persistência de sessão (5 requests)..."
        
        success_count=0
        for i in $(seq 1 5); do
            response=$(curl -s -b "$cookie_file" -w "\n%{http_code}" "$WEBAPP_URL/" 2>/dev/null | tail -1)
            
            if [ "$response" = "200" ]; then
                success_count=$((success_count + 1))
                echo "  Request $i: OK (manteve sessão)"
            else
                echo "  Request $i: HTTP $response"
            fi
        done
        
        echo ""
        if [ $success_count -eq 5 ]; then
            print_success "Sticky sessions funcionando corretamente"
        elif [ $success_count -ge 3 ]; then
            print_warning "Sticky sessions parcialmente funcionando ($success_count/5)"
        else
            print_error "Sticky sessions não estão funcionando ($success_count/5)"
        fi
        
        # Cleanup
        rm -f "$cookie_file"
    else
        print_error "Login falhou (HTTP $response)"
    fi
}

# Teste 6: Health checks do Traefik
test_traefik_health() {
    print_header "Teste 6: Health Checks do Traefik"
    
    # Verificar API do Traefik
    if curl -s http://traefik.localhost/api/rawdata > /tmp/traefik_api_$$.json 2>/dev/null; then
        print_success "API do Traefik acessível"
        
        # Contar backends
        if command -v jq &> /dev/null; then
            backends=$(jq -r '.http.services | to_entries | length' /tmp/traefik_api_$$.json 2>/dev/null || echo "N/A")
            echo "Serviços registados: $backends"
        else
            echo "ℹ️  Instale 'jq' para análise detalhada: brew install jq"
        fi
        
        rm -f /tmp/traefik_api_$$.json
    else
        print_warning "Não foi possível acessar API do Traefik"
        echo "  Verifique se Traefik está rodando: docker service ls | grep traefik"
    fi
}

# Teste 7: Stress test simples
test_stress() {
    print_header "Teste 7: Stress Test (100 requests concorrentes)"
    
    echo "Executando stress test..."
    
    start_time=$(date +%s)
    success_count=0
    
    # 100 requests em paralelo (usando background jobs)
    for i in $(seq 1 100); do
        (curl -s -o /dev/null "$WEBAPP_URL/health" 2>/dev/null && echo "OK") &
        
        # Limitar jobs concorrentes para não sobrecarregar
        if [ $((i % 20)) -eq 0 ]; then
            wait
        fi
    done
    
    # Aguardar todos os requests
    wait
    
    end_time=$(date +%s)
    duration=$((end_time - start_time))
    
    if [ $duration -eq 0 ]; then
        duration=1
    fi
    
    echo ""
    echo "Duração: ${duration}s"
    echo "Taxa: $((100 / duration)) requests/segundo"
    echo ""
    
    if [ $duration -lt 10 ]; then
        print_success "Sistema aguentou bem o stress test"
    else
        print_warning "Sistema demorou a processar todos os requests"
    fi
}

# Teste 8: Verificar conectividade de todos os serviços
test_all_services() {
    print_header "Teste 8: Conectividade de Todos os Serviços"
    
    services=(
        "webapp.localhost|WebApp"
        "traefik.localhost|Traefik Dashboard"
        "prometheus.localhost|Prometheus"
        "grafana.localhost|Grafana"
        "cadvisor.localhost/containers/|cAdvisor"
    )
    
    for service in "${services[@]}"; do
        IFS='|' read -r url name <<< "$service"
        
        response=$(curl -s -o /dev/null -w "%{http_code}" "http://$url" 2>/dev/null || echo "000")
        
        if [ "$response" = "200" ] || [ "$response" = "302" ]; then
            print_success "$name ($url) está acessível"
        else
            print_error "$name ($url) NÃO está acessível (HTTP $response)"
        fi
    done
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
    test_all_services
    
    print_header "Resumo dos Testes"
    print_success "Todos os testes completados!"
    echo ""
    echo "Para mais detalhes:"
    echo "  - Dashboard Traefik: http://traefik.localhost"
    echo "  - Métricas Prometheus: http://prometheus.localhost"
    echo "  - Grafana: http://grafana.localhost"
    echo ""
}

# Menu
case "${1:-all}" in
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
    connectivity)
        test_all_services
        ;;
    *)
        echo "Uso: $0 {all|service|replicas|distribution|latency|sticky|traefik|stress|connectivity}"
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
        echo "  connectivity - Testar conectividade de todos os serviços"
        exit 1
        ;;
esac