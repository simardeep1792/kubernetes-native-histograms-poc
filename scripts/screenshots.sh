#!/usr/bin/env bash
set -euo pipefail

root_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
context=kind-native-histograms
namespace=native-histograms-demo

mkdir -p "$root_dir/screenshots"
kubectl --context "$context" -n "$namespace" get pods -o wide > "$root_dir/screenshots/pods.txt"

kubectl --context "$context" -n "$namespace" port-forward service/grafana 13000:3000 > /tmp/native-histograms-grafana-port-forward.log 2>&1 &
grafana_pid=$!
kubectl --context "$context" -n "$namespace" port-forward service/prometheus 19090:9090 > /tmp/native-histograms-prometheus-port-forward.log 2>&1 &
prometheus_pid=$!
trap 'kill "$grafana_pid" "$prometheus_pid" 2>/dev/null || true' EXIT

for _ in {1..30}; do
  curl --silent --fail http://127.0.0.1:13000/api/health >/dev/null && break
  sleep 1
done

chrome="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
if [[ ! -x "$chrome" ]]; then
  echo "Google Chrome is required for automated screenshots." >&2
  exit 1
fi

"$chrome" --headless --disable-gpu --no-first-run --no-default-browser-check --window-size=1440,1000 \
  --screenshot="$root_dir/screenshots/grafana-dashboard.png" \
  "http://127.0.0.1:13000/d/native-histograms-poc" >/dev/null 2>&1
"$chrome" --headless --disable-gpu --no-first-run --no-default-browser-check --window-size=1440,1000 \
  --screenshot="$root_dir/screenshots/prometheus-native-query.png" \
  "http://127.0.0.1:19090/graph?g0.expr=histogram_quantile(0.99%2C%20sum(rate(apiserver_request_duration_seconds%5B1m%5D)))&g0.tab=0" >/dev/null 2>&1
