#!/usr/bin/env bash

# Create a temporary file to store results
tmp_file=$(mktemp)
output_file="results.tsv"

# Iterate over all directories containing 'kustomization-postbuild-variables/env.yaml'
for env_file in $(find . -type f -path "*/kustomization-postbuild-variables/env.yaml"); do
    # Extract the environment directory
    env_dir=$(dirname $(dirname "$env_file"))

    # Extract the ENV_NAME and ENV_DOMAIN from the env.yaml file
    ENV_NAME=$(grep '^  ENV_NAME:' "$env_file" | awk -F': ' '{gsub(/"/, "", $2); print $2}')
    ENV_DOMAIN=$(grep '^  ENV_DOMAIN:' "$env_file" | awk -F': ' '{gsub(/"/, "", $2); print $2}')

    # Validate the extracted ENV_DOMAIN
    if [[ -z "$ENV_DOMAIN" ]]; then
        echo "Error: ENV_DOMAIN not found or empty in $env_file"
        continue
    fi

    # Construct the Prometheus URL
    PROMETHEUS_URL="https://prometheus.${ENV_DOMAIN}"

    # Query the sum(kubelet_running_containers) metric
    response=$(curl -sk -w "%{http_code}" -o /tmp/curl_response.txt "${PROMETHEUS_URL}/api/v1/query?query=sum(kubelet_running_containers)")
    http_code=$(tail -n1 <<< "$response")
    raw_response=$(cat /tmp/curl_response.txt)

    # Check HTTP status code
    if [[ "$http_code" -ne 200 ]]; then
        continue
    fi

    # Validate if the response is a valid JSON
    if ! echo "$raw_response" | jq empty > /dev/null 2>&1; then
        continue
    fi

    # Extract the number of running containers
    container_count=$(echo "$raw_response" | jq -r '.data.result[0].value[1]' 2>/dev/null)

    if [[ -z "$container_count" || "$container_count" == "null" ]]; then
        continue
    fi

    # Append the environment name and container count to the temporary file
    echo -e "${ENV_NAME}\t${container_count}" >> "$tmp_file"
done

# Sort the results alphabetically and save to the output file
sort "$tmp_file" > "$output_file"

# Display the sorted results
cat "$output_file"

# Clean up the temporary file
rm "$tmp_file"

echo "Results saved to $output_file"
