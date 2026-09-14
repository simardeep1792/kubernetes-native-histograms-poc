# Kubernetes Native Histograms POC

This small, local POC demonstrates Kubernetes v1.37 API server native histograms collected by Prometheus 3.x alongside classic histogram buckets.

It creates an isolated `kind-native-histograms` cluster. It does not use the current `kubectl` context or any cloud cluster.

## What it proves

- Kubernetes API server metrics are scraped in Prometheus Protobuf format with native histograms enabled.
- Classic `_bucket` series remain available during migration.
- Native and classic `histogram_quantile()` queries produce P99 API server latency results.
- Grafana displays both P99 calculations side by side.

## Run

Prerequisites: Docker Desktop, `kubectl`, `jq`, Google Chrome for screenshots, and `kind` v0.33.0 or later. Kubernetes v1.37 requires a current `kind` release because older releases generate an obsolete kubeadm configuration.

```bash
./scripts/deploy.sh
sleep 30
./scripts/validate.sh
./scripts/screenshots.sh
```

The first run downloads Kubernetes, Prometheus, Grafana, and curl container images. Expect 10 to 20 minutes depending on network speed.

## Prometheus configuration

`manifests/prometheus.yaml` uses the safe migration configuration:

```yaml
scrape_native_histograms: true
always_scrape_classic_histograms: true
```

The first option negotiates Protobuf scraping and ingests native spans. The second retains `_bucket`, `_sum`, and `_count` series so existing dashboards and alerts continue to work.

## Queries

Native P99:

```promql
histogram_quantile(0.99, sum(rate(apiserver_request_duration_seconds[1m])))
```

Classic P99:

```promql
histogram_quantile(0.99, sum by (le) (rate(apiserver_request_duration_seconds_bucket[1m])))
```

## Access locally

```bash
kubectl --context kind-native-histograms -n native-histograms-demo port-forward service/grafana 3000:3000
kubectl --context kind-native-histograms -n native-histograms-demo port-forward service/prometheus 9090:9090
```

Open Grafana at `http://localhost:3000/d/native-histograms-poc` and Prometheus at `http://localhost:9090`.

## Evidence

- `screenshots/grafana-dashboard.png` shows native and classic P99 latency together, plus the retained series counts.
- `screenshots/prometheus-native-query.png` shows the native PromQL query without the classic `_bucket` suffix.
- `screenshots/pods.txt` records the healthy POC workloads.

## Clean up

```bash
kind delete cluster --name native-histograms
```
