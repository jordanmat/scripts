#!/usr/bin/env bash

# Simple script to test prometheus query
URL="https://prometheus.bet99-prod.route53.abetting.co/api/v1/query?query=kubelet_volume_stats_used_bytes%7Bpersistentvolumeclaim%3D%22prometheus-prometheus-grafana-kube-pr-prometheus-db-prometheus-prometheus-grafana-kube-pr-prometheus-0%22%7D%0A%2F%0Akubelet_volume_stats_capacity_bytes%7Bpersistentvolumeclaim%3D%22prometheus-prometheus-grafana-kube-pr-prometheus-db-prometheus-prometheus-grafana-kube-pr-prometheus-0%22%7D%0A*%20100"

echo "Querying: $URL"
curl -sk "$URL" | jq .
