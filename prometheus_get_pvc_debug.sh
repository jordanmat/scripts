#!/usr/bin/env bash

# Script to calculate the percentage of Prometheus PVC used across all clusters
# Created: July 1, 2025

# Enable debug output
set -x

# Create a temporary file to store results
tmp_file=$(mktemp)
output_file="prometheus_pvc_usage.tsv"

echo "Gathering Prometheus PVC usage across clusters..."

# Define just bet99-prod for testing
declare -A clusters
clusters["bet99-prod"]="bet99-prod.route53.abetting.co"

# Function to query Prometheus PVC usage for a specific cluster
query_prometheus_pvc() {
    local env_name=$1
    local env_domain=$2
    
    # Build the Prometheus URL
    local prometheus_url="https://prometheus.${env_domain}"
    
    # The Prometheus query (URL encoded version that we know works)
    local query="kubelet_volume_stats_used_bytes%7Bpersistentvolumeclaim%3D%22prometheus-prometheus-grafana-kube-pr-prometheus-db-prometheus-prometheus-grafana-kube-pr-prometheus-0%22%7D%0A%2F%0Akubelet_volume_stats_capacity_bytes%7Bpersistentvolumeclaim%3D%22prometheus-prometheus-grafana-kube-pr-prometheus-db-prometheus-prometheus-grafana-kube-pr-prometheus-0%22%7D%0A*%20100"
    
    # Full URL
    local url="${prometheus_url}/api/v1/query?query=${query}"
    
    echo "Querying ${env_name}..."
    
    # Make the API call and store the response with a timeout
    local response=$(curl -sk --connect-timeout 5 --max-time 10 "$url")
    echo "Raw response: $response"
    
    # Check if the response is valid JSON
    if ! echo "$response" | jq empty > /dev/null 2>&1; then
        echo "Warning: Invalid JSON response from ${env_name}"
        return 1
    fi
    
    # Extract the PVC usage percentage
    local pvc_usage=$(echo "$response" | jq -r '.data.result[0].value[1]' 2>/dev/null)
    echo "PVC usage extracted: $pvc_usage"
    
    if [[ -z "$pvc_usage" || "$pvc_usage" == "null" ]]; then
        echo "Warning: No PVC usage data available for ${env_name}"
        echo "Full response structure: $(echo "$response" | jq .)"
        return 1
    fi
    
    # Format the percentage to 2 decimal places
    local pvc_usage_formatted=$(printf "%.2f" "$pvc_usage")
    
    # Append to results file
    echo -e "${env_name}\t${pvc_usage_formatted}%" >> "$tmp_file"
    echo "Processed ${env_name}: ${pvc_usage_formatted}% PVC usage"
    
    return 0
}

# Process each cluster
for env_name in "${!clusters[@]}"; do
    env_domain="${clusters[$env_name]}"
    query_prometheus_pvc "$env_name" "$env_domain"
done

# Sort the results alphabetically and save to the output file
sort "$tmp_file" > "$output_file"

echo -e "\nSummary of Prometheus PVC Usage:"
echo -e "Cluster\tPVC Usage"
echo -e "-------\t---------"
cat "$output_file"

# Find clusters with high PVC usage (>80%)
echo -e "\nClusters with high PVC usage (>80%):"
grep -E $'\t8[0-9]\.[0-9]{2}%|\t9[0-9]\.[0-9]{2}%' "$output_file" || echo "None found"

# Clean up the temporary file
rm "$tmp_file"

echo -e "\nResults saved to $output_file"
