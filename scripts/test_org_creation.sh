#!/bin/bash

# Simple test script to debug organization creation

set -e

# Configuration
FOREMAN_URL="${FOREMAN_URL:-${SATELLITE_URL:-}}"
FOREMAN_USERNAME="${FOREMAN_USERNAME:-${SATELLITE_USERNAME:-}}"
FOREMAN_PASSWORD="${FOREMAN_PASSWORD:-${SATELLITE_PASSWORD:-}}"

KATELLO_URL="${FOREMAN_URL}/katello/api/v2"

# Get credentials
if [[ -z "$FOREMAN_USERNAME" ]]; then
    read -p "Enter Foreman username: " FOREMAN_USERNAME
fi

if [[ -z "$FOREMAN_PASSWORD" ]]; then
    read -s -p "Enter Foreman password: " FOREMAN_PASSWORD
    echo
fi

echo "Testing organization creation..."

# First, let's test if the organization already exists
echo "Checking if organization 'foo' already exists..."

search_param=$(printf 'name="%s"' "foo")
existing_org_response=$(curl -k -s -u "${FOREMAN_USERNAME}:${FOREMAN_PASSWORD}" \
    "${KATELLO_URL}/organizations" --data-urlencode "search=${search_param}" -G 2>/dev/null)

echo "Search response:"
echo "$existing_org_response" | python3 -m json.tool

existing_org=$(echo "$existing_org_response" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    if data.get('total', 0) > 0:
        print(data['results'][0]['id'])
    else:
        print('')
except Exception as e:
    print(f'Error: {e}', file=sys.stderr)
    print('')
")

if [[ -n "$existing_org" ]]; then
    echo "Organization 'foo' already exists with ID: $existing_org"
    ORG_ID="$existing_org"
else
    echo "Creating new organization 'foo'..."

    create_response=$(curl -k -s -u "${FOREMAN_USERNAME}:${FOREMAN_PASSWORD}" \
        -H "Content-Type: application/json" \
        -X POST "${KATELLO_URL}/organizations" \
        -d '{"name": "foo", "description": "Test organization"}' 2>/dev/null)

    echo "Create response:"
    echo "$create_response" | python3 -m json.tool

    # Parse the ID
    ORG_ID=$(echo "$create_response" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    org_id = data.get('id')
    if org_id:
        print(org_id)
    else:
        print('NO_ID_FOUND')
        print(f'Available keys: {list(data.keys())}', file=sys.stderr)
except Exception as e:
    print('JSON_PARSE_ERROR')
    print(f'Error: {e}', file=sys.stderr)
")

    echo "Extracted ORG_ID: '$ORG_ID'"

    if [[ -z "$ORG_ID" || "$ORG_ID" == "NO_ID_FOUND" || "$ORG_ID" == "JSON_PARSE_ERROR" ]]; then
        echo "ERROR: Failed to extract organization ID"
        exit 1
    fi

    echo "Successfully created organization 'foo' with ID: $ORG_ID"
fi

echo "Final ORG_ID: $ORG_ID"