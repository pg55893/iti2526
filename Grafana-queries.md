# 📊 Queries Prometheus para Dashboards Grafana

## 🎯 Queries Essenciais para Docker Containers

### 📈 CPU Metrics

#### 1. CPU Usage por Container (%)
```promql
sum by (id) (rate(container_cpu_usage_seconds_total{id=~"/docker/.*", id!~".*(buildkit|buildx|kubepods).*"}[5m])) * 100
```
**Panel**: Time series
**Unit**: percent (0-100)
**Legend**: `{{id}}`

#### 2. CPU Usage Total (soma de todos)
```promql
sum(rate(container_cpu_usage_seconds_total{id=~"/docker/.*"}[5m])) * 100
```
**Panel**: Gauge
**Thresholds**: Green < 50%, Yellow < 80%, Red > 80%

#### 3. Top 5 Containers por CPU
```promql
topk(5, sum by (id) (rate(container_cpu_usage_seconds_total{id=~"/docker/.*"}[5m])) * 100)
```
**Panel**: Bar gauge

#### 4. CPU Throttling
```promql
rate(container_cpu_cfs_throttled_seconds_total{id=~"/docker/.*"}[5m])
```
**Panel**: Time series
**Unit**: seconds

---

### 💾 Memory Metrics

#### 5. Memory Usage por Container
```promql
sum by (id) (container_memory_usage_bytes{id=~"/docker/.*", id!~".*(buildkit|buildx|kubepods).*"})
```
**Panel**: Time series
**Unit**: bytes
**Legend**: `{{id}}`

#### 6. Memory Working Set (mais preciso)
```promql
sum by (id) (container_memory_working_set_bytes{id=~"/docker/.*", id!~".*(buildkit|buildx|kubepods).*"})
```
**Panel**: Time series
**Unit**: bytes

#### 7. Memory Usage em Percentagem
```promql
(container_memory_usage_bytes{id=~"/docker/.*"} / container_spec_memory_limit_bytes{id=~"/docker/.*"}) * 100
```
**Panel**: Gauge
**Unit**: percent
**Thresholds**: Green < 70%, Yellow < 85%, Red > 85%

#### 8. Top 5 Containers por Memória
```promql
topk(5, container_memory_usage_bytes{id=~"/docker/.*"})
```
**Panel**: Bar gauge
**Unit**: bytes

#### 9. Memory Cache
```promql
sum by (id) (container_memory_cache{id=~"/docker/.*"})
```
**Panel**: Time series
**Unit**: bytes

#### 10. Memory RSS (Resident Set Size)
```promql
sum by (id) (container_memory_rss{id=~"/docker/.*"})
```
**Panel**: Time series
**Unit**: bytes

---

### 🌐 Network Metrics

#### 11. Network Received (RX) - Total
```promql
sum(rate(container_network_receive_bytes_total{id=~"/docker/.*"}[5m]))
```
**Panel**: Time series
**Unit**: Bps (bytes/sec)
**Legend**: RX

#### 12. Network Transmitted (TX) - Total
```promql
sum(rate(container_network_transmit_bytes_total{id=~"/docker/.*"}[5m]))
```
**Panel**: Time series (com negative-Y no TX)
**Unit**: Bps
**Legend**: TX

#### 13. Network I/O por Container
```promql
# Receive
sum by (id) (rate(container_network_receive_bytes_total{id=~"/docker/.*"}[5m]))

# Transmit
sum by (id) (rate(container_network_transmit_bytes_total{id=~"/docker/.*"}[5m]))
```
**Panel**: Time series
**Unit**: Bps

#### 14. Network Errors
```promql
# RX Errors
sum(rate(container_network_receive_errors_total{id=~"/docker/.*"}[5m]))

# TX Errors
sum(rate(container_network_transmit_errors_total{id=~"/docker/.*"}[5m]))
```
**Panel**: Time series
**Unit**: errors/sec

#### 15. Network Packets (RX)
```promql
sum(rate(container_network_receive_packets_total{id=~"/docker/.*"}[5m]))
```
**Panel**: Time series
**Unit**: packets/sec

#### 16. Network Packets (TX)
```promql
sum(rate(container_network_transmit_packets_total{id=~"/docker/.*"}[5m]))
```
**Panel**: Time series
**Unit**: packets/sec

#### 17. Network Dropped Packets
```promql
# RX Dropped
sum(rate(container_network_receive_packets_dropped_total{id=~"/docker/.*"}[5m]))

# TX Dropped
sum(rate(container_network_transmit_packets_dropped_total{id=~"/docker/.*"}[5m]))
```
**Panel**: Time series

---

### 💿 Disk I/O Metrics

#### 18. Disk Read Bytes
```promql
sum by (id) (rate(container_fs_reads_bytes_total{id=~"/docker/.*"}[5m]))
```
**Panel**: Time series
**Unit**: Bps
**Legend**: Read

#### 19. Disk Write Bytes
```promql
sum by (id) (rate(container_fs_writes_bytes_total{id=~"/docker/.*"}[5m]))
```
**Panel**: Time series (negative-Y)
**Unit**: Bps
**Legend**: Write

#### 20. Disk Operations (IOPS) - Read
```promql
sum by (id) (rate(container_fs_reads_total{id=~"/docker/.*"}[5m]))
```
**Panel**: Time series
**Unit**: ops/sec

#### 21. Disk Operations (IOPS) - Write
```promql
sum by (id) (rate(container_fs_writes_total{id=~"/docker/.*"}[5m]))
```
**Panel**: Time series
**Unit**: ops/sec

#### 22. Disk Usage (espaço usado)
```promql
sum by (id) (container_fs_usage_bytes{id=~"/docker/.*"})
```
**Panel**: Time series
**Unit**: bytes

#### 23. Disk Limit (espaço total)
```promql
sum by (id) (container_fs_limit_bytes{id=~"/docker/.*"})
```
**Panel**: Stat
**Unit**: bytes

---

### 🔢 Container Status & Count

#### 24. Número de Containers Ativos
```promql
count(container_last_seen{id=~"/docker/.*", id!~".*(buildkit|buildx|kubepods).*"})
```
**Panel**: Stat
**Unit**: short

#### 25. Container Uptime
```promql
time() - container_start_time_seconds{id=~"/docker/.*"}
```
**Panel**: Table
**Unit**: seconds (ou usar `duration` format)

#### 26. Containers por Status
```promql
count by (id) (container_last_seen{id=~"/docker/.*"})
```
**Panel**: Pie chart

#### 27. Container Restarts
```promql
container_spec_restart_count{id=~"/docker/.*"}
```
**Panel**: Table

---

### ⚡ Process & Thread Metrics

#### 28. Processos por Container
```promql
sum by (id) (container_processes{id=~"/docker/.*"})
```
**Panel**: Time series
**Unit**: short

#### 29. Threads por Container
```promql
sum by (id) (container_threads{id=~"/docker/.*"})
```
**Panel**: Time series
**Unit**: short

#### 30. File Descriptors Abertos
```promql
sum by (id) (container_file_descriptors{id=~"/docker/.*"})
```
**Panel**: Time series
**Unit**: short

---

## 🎨 Queries Compostas (Métricas Calculadas)

### 31. Taxa de Crescimento de Memória
```promql
deriv(container_memory_usage_bytes{id=~"/docker/.*"}[5m])
```
**Panel**: Time series
**Unit**: bytes/sec

### 32. Eficiência de CPU (CPU usage / CPU limit)
```promql
(rate(container_cpu_usage_seconds_total{id=~"/docker/.*"}[5m]) / container_spec_cpu_quota{id=~"/docker/.*"} * 100000) * 100
```
**Panel**: Gauge
**Unit**: percent

### 33. Memória Disponível
```promql
container_spec_memory_limit_bytes{id=~"/docker/.*"} - container_memory_usage_bytes{id=~"/docker/.*"}
```
**Panel**: Stat
**Unit**: bytes

### 34. Network Throughput Total (RX + TX)
```promql
sum(rate(container_network_receive_bytes_total{id=~"/docker/.*"}[5m])) + 
sum(rate(container_network_transmit_bytes_total{id=~"/docker/.*"}[5m]))
```
**Panel**: Gauge
**Unit**: Bps

### 35. Disk I/O Total (Read + Write)
```promql
sum(rate(container_fs_reads_bytes_total{id=~"/docker/.*"}[5m])) + 
sum(rate(container_fs_writes_bytes_total{id=~"/docker/.*"}[5m]))
```
**Panel**: Gauge
**Unit**: Bps

### 36. Percentagem de Uso de Disco
```promql
(container_fs_usage_bytes{id=~"/docker/.*"} / container_fs_limit_bytes{id=~"/docker/.*"}) * 100
```
**Panel**: Gauge
**Unit**: percent
**Thresholds**: Green < 70%, Yellow < 85%, Red > 85%

---

## 🚨 Queries para Alertas

### 37. CPU Alto (> 80%)
```promql
sum by (id) (rate(container_cpu_usage_seconds_total{id=~"/docker/.*"}[5m])) * 100 > 80
```
**Alert**: Warning quando CPU > 80% por 5 minutos

### 38. Memória Alta (> 85%)
```promql
(container_memory_usage_bytes{id=~"/docker/.*"} / container_spec_memory_limit_bytes{id=~"/docker/.*"}) * 100 > 85
```
**Alert**: Critical quando Memória > 85%

### 39. Container Parou
```promql
absent(container_last_seen{id="/docker/<ID_WEBAPP>"}) == 1
```
**Alert**: Container não está a responder

### 40. Disco Quase Cheio (> 90%)
```promql
(container_fs_usage_bytes{id=~"/docker/.*"} / container_fs_limit_bytes{id=~"/docker/.*"}) * 100 > 90
```
**Alert**: Critical quando disco > 90%

### 41. Muitos Erros de Rede
```promql
sum(rate(container_network_receive_errors_total{id=~"/docker/.*"}[5m])) > 10
```
**Alert**: Warning quando > 10 erros/sec

---

## 📊 Queries para Tabelas

### 42. Tabela Resumo de Containers
```promql
# Nome (usar id por enquanto)
# CPU
sum by (id) (rate(container_cpu_usage_seconds_total{id=~"/docker/.*"}[5m])) * 100

# Memória
sum by (id) (container_memory_usage_bytes{id=~"/docker/.*"})

# Network RX
sum by (id) (rate(container_network_receive_bytes_total{id=~"/docker/.*"}[5m]))

# Network TX
sum by (id) (rate(container_network_transmit_bytes_total{id=~"/docker/.*"}[5m]))
```
**Panel**: Table
**Usar "Instant" query mode**

---

## 🎯 Queries Específicas para WebApp (depois de descobrir o ID)

Substitui `<WEBAPP_ID>` pelo ID completo do container webapp.

### 43. CPU do WebApp
```promql
rate(container_cpu_usage_seconds_total{id="/docker/<WEBAPP_ID>"}[5m]) * 100
```

### 44. Memória do WebApp
```promql
container_memory_usage_bytes{id="/docker/<WEBAPP_ID>"}
```

### 45. Network RX do WebApp
```promql
sum(rate(container_network_receive_bytes_total{id="/docker/<WEBAPP_ID>"}[5m]))
```

### 46. Network TX do WebApp
```promql
sum(rate(container_network_transmit_bytes_total{id="/docker/<WEBAPP_ID>"}[5m]))
```

### 47. Disk Read do WebApp
```promql
sum(rate(container_fs_reads_bytes_total{id="/docker/<WEBAPP_ID>"}[5m]))
```

### 48. Disk Write do WebApp
```promql
sum(rate(container_fs_writes_bytes_total{id="/docker/<WEBAPP_ID>"}[5m]))
```

---

## 🎨 Dicas de Visualização

### Para Time Series:
- **Fill opacity**: 10
- **Line width**: 1-2
- **Legend**: Show, Bottom, Table mode
- **Tooltip**: All series
- **Refresh**: 5s ou 10s

### Para Gauges:
- **Show thresholds**: Yes
- **Show threshold markers**: Yes
- **Min**: 0
- **Max**: 100 (para percentagens)

### Para Stats:
- **Color mode**: Background
- **Graph mode**: None ou Area
- **Text mode**: Value and name

### Para Tables:
- **Use instant queries** (não time series)
- **Format**: Adicionar units corretas
- **Sorting**: Por valor descendente

---

## 🚀 Como Usar

1. **Criar novo Dashboard** no Grafana
2. **Add Panel** → escolher tipo de visualização
3. **Copiar query** deste ficheiro
4. **Ajustar Legend** format: `{{id}}` ou `{{instance}}`
5. **Configurar Units** conforme indicado
6. **Adicionar Thresholds** para alertas visuais
7. **Save Dashboard**

---

## 💡 Queries Prontas por Dashboard

### Dashboard 1: Overview Geral
- Query 2: CPU Total
- Query 6: Memory Total
- Query 24: Containers Ativos
- Query 11 + 12: Network I/O
- Query 18 + 19: Disk I/O

### Dashboard 2: Per-Container Metrics
- Query 1: CPU por container
- Query 5: Memory por container
- Query 13: Network por container
- Query 28: Processos

### Dashboard 3: Alertas e Performance
- Query 3: Top 5 CPU
- Query 8: Top 5 Memory
- Query 37-41: Alertas

### Dashboard 4: WebApp Específico
- Queries 43-48: Todas as métricas do webapp

---

## 🔧 Troubleshooting

Se queries não retornarem dados:

1. **Verificar targets** em http://localhost:9090/targets
2. **Testar query** sem filtros: `container_memory_usage_bytes`
3. **Ver labels disponíveis** e ajustar filtro `id=~"..."`
4. **Aumentar time range** no Grafana para "Last 1 hour"
5. **Verificar se cAdvisor está UP**

---

## 📚 Referências Rápidas

| Métrica | Query Base | Unit |
|---------|-----------|------|
| CPU % | `rate(container_cpu_usage_seconds_total[5m]) * 100` | percent |
| Memory | `container_memory_usage_bytes` | bytes |
| Network RX | `rate(container_network_receive_bytes_total[5m])` | Bps |
| Network TX | `rate(container_network_transmit_bytes_total[5m])` | Bps |
| Disk Read | `rate(container_fs_reads_bytes_total[5m])` | Bps |
| Disk Write | `rate(container_fs_writes_bytes_total[5m])` | Bps |
| Containers | `count(container_last_seen)` | short |