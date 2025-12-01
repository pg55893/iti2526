#!/bin/bash

echo "╔════════════════════════════════════════╗"
echo "║  Diagnóstico Dashboard Traefik        ║"
echo "╚════════════════════════════════════════╝"
echo ""

echo "1️⃣  Verificar se Traefik está a expor métricas:"
echo "─────────────────────────────────────────────"
curl -s http://traefik.localhost:8080/metrics 2>/dev/null | head -20
if [ $? -eq 0 ]; then
    echo ""
    echo "✓ Traefik está a expor métricas"
else
    echo "✗ Não foi possível aceder às métricas do Traefik"
    exit 1
fi
echo ""

echo "2️⃣  Service names disponíveis no Traefik:"
echo "─────────────────────────────────────────────"
curl -s http://traefik.localhost:8080/metrics 2>/dev/null | grep 'traefik_service_requests_total{' | head -5
echo ""

echo "3️⃣  Extrair service names únicos:"
echo "─────────────────────────────────────────────"
curl -s http://traefik.localhost:8080/metrics 2>/dev/null | \
    grep 'traefik_service_requests_total{' | \
    grep -oP 'service="[^"]*"' | \
    sort -u
echo ""

echo "4️⃣  Verificar se Prometheus está a coletar:"
echo "─────────────────────────────────────────────"
curl -s 'http://prometheus.localhost/api/v1/query?query=traefik_service_requests_total' 2>/dev/null | \
    python3 -c "import sys, json; data=json.load(sys.stdin); print('Status:', data['status']); print('Results:', len(data.get('data',{}).get('result',[])), 'series')" 2>/dev/null || \
    echo "⚠️  Precisa de python3 para parsing"
echo ""

echo "5️⃣  Query de teste no Prometheus:"
echo "─────────────────────────────────────────────"
echo "Abre este URL no browser:"
echo "http://prometheus.localhost/graph?g0.expr=traefik_service_requests_total&g0.tab=1"
echo ""

echo "6️⃣  Verificar target Traefik no Prometheus:"
echo "─────────────────────────────────────────────"
curl -s http://prometheus.localhost/api/v1/targets 2>/dev/null | \
    python3 -c "
import sys, json
data = json.load(sys.stdin)
for target in data.get('data', {}).get('activeTargets', []):
    if 'traefik' in target.get('labels', {}).get('job', ''):
        print(f\"Job: {target['labels']['job']}\")
        print(f\"Health: {target['health']}\")
        print(f\"URL: {target['scrapeUrl']}\")
        print(f\"Last Scrape: {target.get('lastScrape', 'N/A')}\")
        print(f\"Last Error: {target.get('lastError', 'None')}\")
" 2>/dev/null || echo "⚠️  Precisa de python3"
echo ""

echo "═════════════════════════════════════════════"
echo "📋 AÇÕES NECESSÁRIAS:"
echo ""
echo "1. Anota os service names que aparecem acima"
echo "2. No Grafana dashboard, edita os painéis"
echo "3. Substitui 'service=\"webapp@docker\"' pelo nome correto"
echo ""
echo "Exemplo de service names possíveis:"
echo "  - webapp-stack_webapp@docker"
echo "  - webapp@docker"
echo "  - webapp-stack-webapp@docker"