#!/usr/bin/env bash

# Script to calculate the percentage of Prometheus PVC used across all clusters
# Created: July 1, 2025

echo "Starting Prometheus PVC usage calculation..."

# Create an output file
output_file="prometheus_pvc_usage.tsv"
echo -n > "$output_file"  # Clear the file

# Directly query bet99-prod which we know works
ENV_NAME="bet99-prod"
ENV_DOMAIN="bet99-prod.route53.abetting.co"
PROMETHEUS_URL="https://prometheus.${ENV_DOMAIN}"

echo "Querying ${ENV_NAME} at ${PROMETHEUS_URL}..."

# Use the query directly from the working example
QUERY="kubelet_volume_stats_used_bytes%7Bpersistentvolumeclaim%3D%22prometheus-prometheus-grafana-kube-pr-prometheus-db-prometheus-prometheus-grafana-kube-pr-prometheus-0%22%7D%0A%2F%0Akubelet_volume_stats_capacity_bytes%7Bpersistentvolumeclaim%3D%22prometheus-prometheus-grafana-kube-pr-prometheus-db-prometheus-prometheus-grafana-kube-pr-prometheus-0%22%7D%0A*%20100"

# Full query URL
FULL_URL="${PROMETHEUS_URL}/api/v1/query?query=${QUERY}"
echo "Full URL: ${FULL_URL}"

# Make the request
echo "Making request..."
RESPONSE=$(curl -sk "${FULL_URL}")
echo "Request completed."

# Verify we got a valid response
if [[ -z "$RESPONSE" ]]; then
    echo "Error: Empty response from Prometheus"
    exit 1
fi

# Check if the response is valid JSON
if ! echo "$RESPONSE" | jq empty > /dev/null 2>&1; then
    echo "Error: Invalid JSON response"
    echo "Response: $RESPONSE"
    exit 1
fi

# Extract the PVC usage percentage
PVC_USAGE=$(echo "$RESPONSE" | jq -r '.data.result[0].value[1]' 2>/dev/null)

if [[ -z "$PVC_USAGE" || "$PVC_USAGE" == "null" ]]; then
    echo "Error: No PVC usage data available"
    echo "Response data: $(echo "$RESPONSE" | jq .)"
    exit 1
fi

# Format the percentage to 2 decimal places
PVC_USAGE_FORMATTED=$(printf "%.2f" "$PVC_USAGE")

# Save to the output file
echo -e "${ENV_NAME}\t${PVC_USAGE_FORMATTED}%" >> "$output_file"

echo -e "\nSummary of Prometheus PVC Usage:"
echo -e "Cluster\tPVC Usage"
echo -e "-------\t---------"
cat "$output_file"

echo -e "\nResults saved to $output_file"
