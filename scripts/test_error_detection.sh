#!/bin/bash

# Test script to verify error detection logic

test_good_response='{"content_host_count":0,"composite":false,"rolling":false,"component_ids":[],"duplicate_repositories_to_publish":[],"default":false,"version_count":0,"latest_version":null,"latest_version_id":null,"auto_publish":false,"solve_dependencies":false,"import_only":false,"generated_for":"none","related_cv_count":0,"related_composite_cvs":[],"filtered":false,"needs_publish":true,"environment_ids":[],"repository_ids":[],"id":5,"name":"prod-cv","label":"prod-cv","description":"Content view created by automation script","organization_id":4,"organization":{"name":"foo","label":"foo","id":4},"created_at":"2025-10-21 20:54:31 UTC","updated_at":"2025-10-21 20:54:31 UTC","last_task":null,"latest_version_environments":[],"repositories":[],"versions":[],"components":[],"content_view_components":[],"activation_keys":[],"hosts":[],"next_version":"1.0","last_published":null,"environments":[],"errors":null}'

test_bad_response='{"errors":["Name has already been taken"],"displayMessage":"Error occurred"}'

test_pending_response='{"displayMessage":"Pending tasks detected in repositories of this content view. Please wait for the tasks: - http://example.com/tasks/123 before publishing.","errors":["Pending tasks detected"]}'

echo "Testing good response (errors:null)..."
result1=$(echo "$test_good_response" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)

    # Check for error field with actual content
    if 'error' in data and data['error'] is not None:
        if isinstance(data['error'], dict):
            print(data['error'].get('message', 'Unknown error'))
        else:
            print(str(data['error']))
        sys.exit(1)

    # Check for errors array with actual content
    elif 'errors' in data and data['errors'] is not None:
        if isinstance(data['errors'], list) and len(data['errors']) > 0:
            # Filter out null/empty errors
            actual_errors = [e for e in data['errors'] if e is not None and str(e).strip()]
            if actual_errors:
                print(actual_errors[0])
                sys.exit(1)

    # Check for displayMessage indicating error
    elif 'displayMessage' in data and 'error' in str(data['displayMessage']).lower():
        print(data['displayMessage'])
        sys.exit(1)

    # No actual errors found
    print('NO_ERROR')

except Exception as e:
    print('Failed to parse response')
    sys.exit(1)
")

echo "Result: '$result1'"
if [[ "$result1" == "NO_ERROR" ]]; then
    echo "✅ Good response correctly identified as success"
else
    echo "❌ Good response incorrectly flagged as error"
fi

echo -e "\nTesting bad response (actual errors)..."
result2=$(echo "$test_bad_response" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)

    # Check for error field with actual content
    if 'error' in data and data['error'] is not None:
        if isinstance(data['error'], dict):
            print(data['error'].get('message', 'Unknown error'))
        else:
            print(str(data['error']))
        sys.exit(1)

    # Check for errors array with actual content
    elif 'errors' in data and data['errors'] is not None:
        if isinstance(data['errors'], list) and len(data['errors']) > 0:
            # Filter out null/empty errors
            actual_errors = [e for e in data['errors'] if e is not None and str(e).strip()]
            if actual_errors:
                print(actual_errors[0])
                sys.exit(1)

    # Check for displayMessage indicating error
    elif 'displayMessage' in data and 'error' in str(data['displayMessage']).lower():
        print(data['displayMessage'])
        sys.exit(1)

    # No actual errors found
    print('NO_ERROR')

except Exception as e:
    print('Failed to parse response')
    sys.exit(1)
")

echo "Result: '$result2'"
if [[ "$result2" != "NO_ERROR" ]]; then
    echo "✅ Bad response correctly identified as error: $result2"
else
    echo "❌ Bad response incorrectly identified as success"
fi

echo -e "\nAll error detection tests completed!"