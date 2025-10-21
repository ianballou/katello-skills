#!/bin/bash

# Script to wait for a specific task to complete

FOREMAN_URL="${FOREMAN_URL:-${SATELLITE_URL:-}}"
FOREMAN_USERNAME="${FOREMAN_USERNAME:-${SATELLITE_USERNAME:-}}"
FOREMAN_PASSWORD="${FOREMAN_PASSWORD:-${SATELLITE_PASSWORD:-}}"

# Task ID from the error message
TASK_ID="${1:-d68d9b65-567a-423f-8f5c-0da31dda861a}"

BASE_URL="${FOREMAN_URL}/api/v2"

# Get credentials
if [[ -z "$FOREMAN_USERNAME" ]]; then
    read -p "Enter Foreman username: " FOREMAN_USERNAME
fi

if [[ -z "$FOREMAN_PASSWORD" ]]; then
    read -s -p "Enter Foreman password: " FOREMAN_PASSWORD
    echo
fi

echo "Waiting for task $TASK_ID to complete..."

while true; do
    response=$(curl -k -s -u "${FOREMAN_USERNAME}:${FOREMAN_PASSWORD}" \
        "${BASE_URL}/tasks/${TASK_ID}" 2>/dev/null)

    status=$(echo "$response" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    print(data.get('state', 'unknown'))
except:
    print('unknown')
" 2>/dev/null || echo "unknown")

    echo "Task status: $status"

    case "$status" in
        "stopped"|"succeeded")
            echo "✅ Task completed successfully!"
            break
            ;;
        "error"|"failed")
            echo "❌ Task failed!"
            echo "Response:"
            echo "$response" | python3 -m json.tool 2>/dev/null || echo "$response"
            exit 1
            ;;
        "unknown")
            echo "⚠️  Unable to check task status"
            echo "Response:"
            echo "$response"
            break
            ;;
        *)
            echo "Task still running..."
            sleep 5
            ;;
    esac
done

echo "You can now try running the workflow script again."