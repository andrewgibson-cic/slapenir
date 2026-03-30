# SLAPENIR Monitoring Stack

**Phase 6: Monitoring & Observability**

This directory contains the configuration for the SLAPENIR monitoring stack, including Prometheus for metrics collection and Grafana for visualization.

## Overview

The monitoring stack provides:
- **Metrics Collection**: Prometheus scrapes metrics from all SLAPENIR services
- **Visualization**: Grafana dashboards for system overview and detailed analysis
- **Alerting**: Framework for alert rules (to be implemented)
- **Time-series Storage**: 30-day retention for metrics data

## Architecture

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   Proxy     │────▶│  Prometheus │────▶│   Grafana   │
│  :3000      │     │   :9090     │     │    :3001    │
└─────────────┘     └─────────────┘     └─────────────┘
       │                    │
       │                    │
┌─────────────┐            │
│   Agent     │────────────┘
│  :8000      │
└─────────────┘
```

## Components

### Prometheus
- **URL**: http://localhost:9090
- **Purpose**: Metrics collection and storage
- **Scrape Interval**: 15 seconds
- **Retention**: 30 days
- **Configuration**: `prometheus.yml`

### Grafana
- **URL**: http://localhost:3001
- **Username**: `admin`
- **Password**: `slapenir-dev-password`
- **Purpose**: Metrics visualization
- **Datasources**: Automatically provisions Prometheus
- **Dashboards**: Auto-loaded from `grafana/dashboards/`

## Directory Structure

```
monitoring/
├── README.md                           # This file
├── prometheus.yml                      # Prometheus configuration
└── grafana/
    ├── datasources/
    │   └── prometheus.yml             # Grafana datasource config
    └── dashboards/
        ├── dashboards.yml             # Dashboard provisioning
        ├── slapenir-overview.json     # System overview dashboard
        └── network-isolation.json     # Network isolation dashboard
```

## Quick Start

### 1. Start Monitoring Stack

```bash
# Start all services including monitoring
docker-compose up -d

# Or start only monitoring services
docker-compose up -d prometheus grafana
```

### 2. Access Dashboards

**Prometheus**: http://localhost:9090
- View metrics
- Test PromQL queries
- Check scrape targets: http://localhost:9090/targets

**Grafana**: http://localhost:3001
- Login: admin / slapenir-dev-password
- Navigate to "SLAPENIR" folder
- Open "SLAPENIR System Overview" dashboard

### 3. Verify Metrics Collection

```bash
# Check Prometheus targets
curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | {job:.labels.job, health:.health}'

# Query a metric
curl -s 'http://localhost:9090/api/v1/query?query=up' | jq '.data.result'
```

## Metrics Endpoints

### Proxy
- **Endpoint**: http://proxy:3000/metrics
- **Metrics**:
  - `slapenir_requests_total` - Total proxy requests
  - `slapenir_secrets_sanitized_total` - Number of secrets sanitized
  - `slapenir_mtls_connections_total` - mTLS connection count
  - `slapenir_bypass_attempts_total` - Bypass attempt count

### Agent
- **Endpoint**: http://agent:8000/metrics
- **Metrics**:
  - `agent_network_isolation_status` - Network isolation status (1=isolated, 0=bypassed)
  - `agent_bypass_attempts_total` - Total network bypass attempts detected

## Dashboard Features

### SLAPENIR System Overview
- **System Health**: Service up/down status
- **Request Rate**: HTTP requests per second
- **Response Time**: p95 latency
- **Error Rate**: 5xx errors per second
- **Secrets Sanitized**: Total secret replacements
- **mTLS Connections**: Active mTLS connections
- **Certificate Expiry**: Days until certificate expiration
- **Active Agents**: Count of healthy agent instances

### Network Isolation Dashboard
- **Firewall Status**: iptables rule enforcement status
- **Bypass Attempts**: Blocked network connection attempts over time
- **Traffic by Rule**: Breakdown of ACCEPT vs DROP traffic
- **DNS Queries**: DNS request patterns and filtering
- **Agent Connectivity**: Connection health to proxy and local LLM

## Adding Custom Dashboards

1. Create dashboard in Grafana UI
2. Export as JSON
3. Save to `grafana/dashboards/`
4. Dashboard will auto-load on restart

## Prometheus Configuration

### Adding New Scrape Targets

Edit `prometheus.yml`:

```yaml
scrape_configs:
  - job_name: 'my-service'
    static_configs:
      - targets: ['my-service:8080']
    metrics_path: '/metrics'
    scrape_interval: 15s
```

Reload configuration:

```bash
# Send HUP signal to reload
docker exec slapenir-prometheus kill -HUP 1

# Or use HTTP API
curl -X POST http://localhost:9090/-/reload
```

## Troubleshooting

### Prometheus Not Scraping Targets

```bash
# Check Prometheus logs
docker logs slapenir-prometheus

# Verify target is reachable
docker exec slapenir-prometheus wget -O- http://proxy:3000/metrics

# Check Prometheus targets page
open http://localhost:9090/targets
```

### Grafana Dashboard Not Loading

```bash
# Check Grafana logs
docker logs slapenir-grafana

# Verify provisioning
docker exec slapenir-grafana ls -la /etc/grafana/provisioning/dashboards/

# Check datasource
curl -u admin:slapenir-dev-password http://localhost:3001/api/datasources
```

## Security Considerations

1. **Grafana Password**: Change default password in production
2. **Network Isolation**: Monitoring stack is on internal network
3. **Data Retention**: Adjust based on compliance requirements
4. **Access Control**: Configure Grafana authentication for production

## Next Steps

1. **Enhanced Dashboards**:
   - Performance dashboard with latency percentiles
   - Certificate management dashboard with expiry alerts
   - Autonomous development session dashboard

2. **Set Up Alerting**:
   - Define alert rules in Prometheus
   - Configure Alertmanager
   - Set up notification channels (PagerDuty, Slack, etc.)

3. **SIEM Integration**:
   - Forward security events to external SIEM
   - Webhook-based integration for real-time alerts
   - Correlation with infrastructure logs

## References

- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [PromQL Basics](https://prometheus.io/docs/prometheus/latest/querying/basics/)