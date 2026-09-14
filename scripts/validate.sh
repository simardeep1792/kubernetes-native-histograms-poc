#!/usr/bin/env bash
set -euo pipefail

context=kind-native-histograms
namespace=native-histograms-demo
port=19090
pid_file=$(mktemp)

cleanup() {
  kill "$(cat "$pid_file")" 2>/dev/null || true
  rm -f "$pid_file"
}
trap cleanup EXIT

kubectl --context "$context" -n "$namespace" port-forward service/prometheus "$port":9090 > /tmp/native-histograms-prometheus-port-forward.log 2>&1 &
echo $! > "$pid_file"

for _ in {1..30}; do
  curl --silent --fail "http://127.0.0.1:$port/-/ready" >/dev/null && break
  sleep 1
done

query() {
  curl --silent --fail --get "http://127.0.0.1:$port/api/v1/query" --data-urlencode "query=$1"
}

query_range() {
  local end
  end=$(date +%s)
  curl --silent --fail --get "http://127.0.0.1:$port/api/v1/query_range" \
    --data-urlencode "query=$1" \
    --data-urlencode "start=$((end - 60))" \
    --data-urlencode "end=$end" \
    --data-urlencode 'step=15s'
}

native_count=$(query 'count(apiserver_request_duration_seconds)')
classic_count=$(query 'count(apiserver_request_duration_seconds_bucket)')
native_p99=$(query 'histogram_quantile(0.99, sum(rate(apiserver_request_duration_seconds[1m])))')
classic_p99=$(query 'histogram_quantile(0.99, sum by (le) (rate(apiserver_request_duration_seconds_bucket[1m])))')
native_samples=$(query_range 'rate(apiserver_request_duration_seconds[1m])')

printf '%s\n' "$native_count" | jq -e '.status == "success" and (.data.result | length > 0)' >/dev/null
printf '%s\n' "$classic_count" | jq -e '.status == "success" and (.data.result | length > 0)' >/dev/null
printf '%s\n' "$native_p99" | jq -e '.status == "success" and (.data.result | length > 0)' >/dev/null
printf '%s\n' "$classic_p99" | jq -e '.status == "success" and (.data.result | length > 0)' >/dev/null
printf '%s\n' "$native_samples" | jq -e '.status == "success" and ([.data.result[].histograms[]?] | length > 0)' >/dev/null

printf 'PASS: native histogram samples, classic buckets, and both P99 queries returned data.\n'
