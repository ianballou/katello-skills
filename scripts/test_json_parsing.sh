#!/bin/bash

# Test script to verify JSON parsing works correctly

# Test data (the actual response from your debug output)
test_json='{"sync_state_aggregated":null,"redhat":false,"id":354,"cp_id":"709626493140","name":"prod","label":"prod","description":"Product created by automation script","provider_id":3,"sync_plan_id":null,"sync_summary":{},"gpg_key_id":null,"ssl_ca_cert_id":null,"ssl_client_cert_id":null,"ssl_client_key_id":null,"sync_state":null,"last_sync":null,"last_sync_words":null,"organization_id":3,"organization":{"name":"foo","label":"foo","id":3},"sync_plan":null,"repository_count":0,"created_at":"2025-10-21 20:48:11 UTC","updated_at":"2025-10-21 20:48:11 UTC","product_content":[],"available_content":[],"repositories":[],"provider":{"name":"Anonymous"},"sync_status":{"id":null,"product_id":null,"progress":null,"sync_id":null,"state":null,"raw_state":null,"start_time":null,"finish_time":null,"duration":null,"display_size":null,"size":null,"is_running":null,"error_details":null},"permissions":{"view_products":true,"edit_products":true,"destroy_products":true,"sync_products":true},"published_content_view_ids":[],"has_last_affected_repo_in_filter":false,"active_task_count":0}'

echo "Testing JSON parsing..."

# Test the parsing logic
product_id=$(echo "$test_json" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    product_id = data.get('id', '')
    if product_id:
        print(product_id)
    else:
        print('NO_ID_FOUND')
except Exception as e:
    print('JSON_PARSE_ERROR')
    print(f'Error: {e}', file=sys.stderr)
")

echo "Extracted product_id: '$product_id'"

if [[ "$product_id" == "354" ]]; then
    echo "✅ JSON parsing works correctly!"
else
    echo "❌ JSON parsing failed. Got: '$product_id'"
    exit 1
fi

# Test with contaminated JSON (like what was happening before)
contaminated_json='[INFO] Creating product prod
  {"id":354,"name":"prod"}'

echo -e "\nTesting contaminated JSON..."
product_id_bad=$(echo "$contaminated_json" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    product_id = data.get('id', '')
    if product_id:
        print(product_id)
    else:
        print('NO_ID_FOUND')
except Exception as e:
    print('JSON_PARSE_ERROR')
")

echo "Contaminated result: '$product_id_bad'"

if [[ "$product_id_bad" == "JSON_PARSE_ERROR" ]]; then
    echo "✅ Correctly detected contaminated JSON!"
else
    echo "❌ Should have failed on contaminated JSON"
fi

echo -e "\nAll tests completed!"