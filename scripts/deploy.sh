#!/usr/bin/env bash
set -euo pipefail

root_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
context=kind-native-histograms
kind_bin=${KIND_BIN:-kind}

if [[ -x "$root_dir/tools/kind-darwin-arm64" ]]; then
  kind_bin="$root_dir/tools/kind-darwin-arm64"
fi

if ! "$kind_bin" get clusters | grep -qx native-histograms; then
  "$kind_bin" create cluster --config "$root_dir/kind-config.yaml" --image kindest/node:v1.37.0
fi

kubectl --context "$context" apply -f "$root_dir/manifests/namespace.yaml"
kubectl --context "$context" apply -f "$root_dir/manifests/prometheus.yaml"
kubectl --context "$context" apply -f "$root_dir/manifests/load-generator.yaml"
kubectl --context "$context" apply -f "$root_dir/manifests/grafana.yaml"
kubectl --context "$context" -n native-histograms-demo rollout status deployment/prometheus --timeout=180s
kubectl --context "$context" -n native-histograms-demo rollout status deployment/grafana --timeout=180s
kubectl --context "$context" -n native-histograms-demo rollout status deployment/api-load-generator --timeout=180s

printf '\nPOC is ready. Run ./scripts/validate.sh, then ./scripts/screenshots.sh.\n'
