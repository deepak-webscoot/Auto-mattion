#!/bin/bash

# Usage: ./ip_lookup <input_file>
# Input file format: <hits> <ip> <user_agent...>

API_KEY="YOUR_API_KEY_HERE"   # ← Replace this with your AbuseIPDB key

# Check if input file is provided
if [ -z "$1" ]; then
    echo "Usage: $0 <input_file>"
    exit 1
fi

input_file="$1"

# Check if jq is installed
if ! command -v jq &>/dev/null; then
    echo "Error: jq is required but not installed. Install it using: sudo apt install jq"
    exit 1
fi

# Extract IP list
ip_list=()
while read -r line; do
    ip=$(echo "$line" | awk '{print $2}')
    ip_list+=("$ip")
done < "$input_file"

# Generate quick log inspection command
echo -e "\n# Quick log inspection command:"
echo -n "for ip in"
for ip in "${ip_list[@]}"; do
    echo -n " $ip"
done
echo "; do echo \"== \$ip ==\"; grep \"\$ip\" restofair.ae_access_log | tail -5; echo; done"
echo

# Print header
printf "%-8s %-15s %-15s %-30s %-12s %-50s\n" "Hits" "IP" "Country" "Datacenter" "AbuseScore" "User Agent"
echo "------------------------------------------------------------------------------------------------------------------------------------------"

# Process each IP
while read -r line; do
    hits=$(echo "$line" | awk '{print $1}')
    ip=$(echo "$line" | awk '{print $2}')
    user_agent=$(echo "$line" | cut -d' ' -f3-)

    # === IP-API lookup ===
    api_data=$(curl -s "http://ip-api.com/json/$ip?fields=status,country,org")
    status=$(echo "$api_data" | jq -r '.status')
    country=$(echo "$api_data" | jq -r '.country')
    org=$(echo "$api_data" | jq -r '.org')

    if [[ "$status" == "fail" ]]; then
        country="Unknown"
        org="Unknown"
    fi

    # === AbuseIPDB lookup ===
    abuse_data=$(curl -sG "https://api.abuseipdb.com/api/v2/check" \
      --data-urlencode "ipAddress=$ip" \
      -d maxAgeInDays=90 \
      -H "Key: $API_KEY" \
      -H "Accept: application/json")

    abuse_score=$(echo "$abuse_data" | jq -r '.data.abuseConfidenceScore // 0')

    # Print final line
    printf "%-8s %-15s %-15s %-30s %-12s %-50s\n" "$hits" "$ip" "$country" "$org" "$abuse_score" "$user_agent"

    # Sleep to avoid API rate limits
    sleep 1
done < "$input_file"
