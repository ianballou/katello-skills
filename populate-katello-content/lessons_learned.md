# Critical Katello Automation Skills & Lessons Learned

## 🚨 Key Issues Discovered & Solutions

### 1. **URL Parameter Escaping in Curl**

#### ❌ **Problem**: Broken search queries
```bash
# WRONG - Shell interprets quotes and spaces incorrectly
curl -k ${HEADERS} "${BASE_URL}/organizations?search=name=\"foo\""
```

#### ✅ **Solution**: Use `--data-urlencode` with `-G`
```bash
# CORRECT - Proper URL encoding
search_param=$(printf 'name="%s"' "$org_name")
curl -k ${HEADERS} "${BASE_URL}/organizations" --data-urlencode "search=${search_param}" -G
```

**Why This Matters**:
- Prevents injection attacks
- Handles special characters in entity names
- Works with organization names containing spaces

### 2. **Katello vs Foreman API Endpoints**

#### ❌ **Problem**: "Route overridden by Katello" error
```bash
# WRONG - Using Foreman API for content management
curl -k ${HEADERS} -X POST "${BASE_URL}/organizations" -d '{"name": "foo"}'
```

#### ✅ **Solution**: Use correct API endpoints
```bash
# CORRECT - Use Katello API for content entities
curl -k ${HEADERS} -X POST "${KATELLO_URL}/organizations" -d '{"name": "foo"}'
```

**API Endpoint Rules**:
- **Katello API** (`/katello/api/v2/`): organizations, products, repositories, content_views, subscriptions
- **Foreman API** (`/api/v2/`): hosts, users, smart_proxies, provisioning_templates

### 3. **Bash Script Output Contamination**

#### ❌ **Problem**: Log messages mixed with JSON responses
```bash
# WRONG - print functions writing to stdout
print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
response=$(api_call ...)  # Captures BOTH logs AND JSON
```

Result: Invalid JSON for parsing:
```
[INFO] Creating product 'prod'
{"id":354,"name":"prod",...}
```

#### ✅ **Solution**: Separate stdout and stderr
```bash
# CORRECT - Log messages to stderr, JSON to stdout
print_info() { echo -e "${BLUE}[INFO]${NC} $1" >&2; }
response=$(api_call ...)  # Only captures clean JSON
```

### 4. **Smart Error Detection**

#### ❌ **Problem**: False positives on null error fields
```bash
# WRONG - Any presence of "error" field = failure
if echo "$response" | grep -q '"error"'; then
```

This failed on successful responses like: `{"id":5,"errors":null}`

#### ✅ **Solution**: Check for actual error content
```python
# CORRECT - Only fail on real errors
if 'errors' in data and data['errors'] is not None:
    if isinstance(data['errors'], list) and len(data['errors']) > 0:
        actual_errors = [e for e in data['errors'] if e is not None and str(e).strip()]
        if actual_errors:
            # Only now it's a real error
```

### 5. **Handling Pending Tasks in Katello**

#### ❌ **Problem**: Content view publish fails with pending tasks
```json
{
  "displayMessage": "Pending tasks detected in repositories...",
  "errors": ["Pending tasks detected..."]
}
```

#### ✅ **Solution**: Task monitoring with retry logic
```bash
# Wait for pending tasks
wait_for_pending_tasks() {
    while [[ $wait_time -lt $max_wait ]]; do
        running_tasks=$(curl "${BASE_URL}/tasks?search=state=running" | ...)
        if [[ "$running_tasks" == "0" ]]; then
            break
        fi
        sleep 10
    done
}

# Retry publication with pending task detection
for attempt in 1 2 3; do
    if echo "$response" | grep -q "Pending tasks detected"; then
        sleep 30
        continue
    fi
    break
done
```

## 🛠 **Essential Helper Functions**

### URL Encoding Function
```bash
url_encode() {
    local string="${1}"
    local strlen=${#string}
    local encoded=""
    local pos c o

    for (( pos=0 ; pos<strlen ; pos++ )); do
        c=${string:$pos:1}
        case "$c" in
            [-_.~a-zA-Z0-9] ) o="${c}" ;;
            * ) printf -v o '%%%02x' "'$c"
        esac
        encoded+="${o}"
    done
    echo "${encoded}"
}
```

### Safe API Call Wrapper
```bash
api_call() {
    local method="$1" url="$2" data="$3" description="$4"

    print_info "$description" >&2  # Log to stderr

    local response
    if [[ -n "$data" ]]; then
        response=$(curl -k -s -u "${USER}:${PASS}" \
            -H "Content-Type: application/json" \
            -X "$method" "$url" -d "$data" 2>/dev/null)
    else
        response=$(curl -k -s -u "${USER}:${PASS}" \
            -H "Content-Type: application/json" \
            -X "$method" "$url" 2>/dev/null)
    fi

    # Smart error detection
    local has_errors=$(echo "$response" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    if 'error' in data and data['error'] is not None:
        print(str(data['error']))
        sys.exit(1)
    elif 'errors' in data and data['errors'] is not None:
        if isinstance(data['errors'], list):
            actual_errors = [e for e in data['errors'] if e is not None and str(e).strip()]
            if actual_errors:
                print(actual_errors[0])
                sys.exit(1)
    print('NO_ERROR')
except:
    print('PARSE_ERROR')
    sys.exit(1)
")

    if [[ "$has_errors" != "NO_ERROR" ]]; then
        print_error "$description failed: $has_errors" >&2
        return 1
    fi

    echo "$response"  # Clean JSON to stdout
}
```

### Smart JSON ID Extraction
```bash
extract_id() {
    local response="$1"
    local id_field="${2:-id}"

    echo "$response" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    entity_id = data.get('$id_field', '')
    if entity_id:
        print(entity_id)
    else:
        print('NO_ID_FOUND')
except Exception as e:
    print('JSON_PARSE_ERROR')
"
}
```

## 🔍 **Debugging Techniques**

### 1. **Test Individual Components**
```bash
# Test just the JSON parsing
echo "$response" | python3 -m json.tool

# Test just the ID extraction
echo "$response" | python3 -c "import json,sys; print(json.load(sys.stdin).get('id'))"

# Test URL encoding
search_param=$(printf 'name="%s"' "My Org Name")
echo "Encoded: $search_param"
```

### 2. **Response Validation**
```bash
# Check what you actually got
echo "Response length: ${#response}"
echo "First 100 chars: ${response:0:100}"
echo "Contains 'id': $(echo "$response" | grep -o '"id":[0-9]*')"
```

### 3. **Task Monitoring**
```bash
# Check running tasks
curl -k -u admin:pass "${BASE_URL}/tasks?search=state=running" | \
  python3 -c "import json,sys; print(f'Running: {json.load(sys.stdin)[\"total\"]}')"

# Monitor specific task
monitor_task() {
    local task_id="$1"
    while true; do
        status=$(curl -k -u admin:pass "${BASE_URL}/tasks/${task_id}" | \
          python3 -c "import json,sys; print(json.load(sys.stdin).get('state'))")
        echo "Task $task_id: $status"
        [[ "$status" =~ (stopped|succeeded|error) ]] && break
        sleep 5
    done
}
```

## 📋 **Best Practices Checklist**

### ✅ **Before Running Scripts**
- [ ] Set credentials as environment variables
- [ ] Test connectivity to Satellite server
- [ ] Check for running tasks that might conflict
- [ ] Verify organization and product IDs if reusing

### ✅ **During Development**
- [ ] Use `set -x` for debugging bash scripts
- [ ] Validate JSON responses with `python3 -m json.tool`
- [ ] Test with entities containing spaces and special characters
- [ ] Implement retry logic for transient failures

### ✅ **Error Handling**
- [ ] Check for both `error` and `errors` fields
- [ ] Distinguish between `null` and actual error content
- [ ] Handle pending task scenarios with appropriate waits
- [ ] Log to stderr, return data to stdout

### ✅ **Security**
- [ ] Use proper URL encoding for all parameters
- [ ] Never put credentials in URLs or logs
- [ ] Use `--data-urlencode` for search parameters
- [ ] Validate SSL certificates in production

## 🎯 **Production-Ready Patterns**

### Complete Workflow Pattern
```bash
#!/bin/bash
set -euo pipefail

# Configuration
FOREMAN_URL="${FOREMAN_URL:-}"
FOREMAN_USERNAME="${FOREMAN_USERNAME:-}"
FOREMAN_PASSWORD="${FOREMAN_PASSWORD:-}"

# Logging to stderr
print_info() { echo -e "\033[0;34m[INFO]\033[0m $1" >&2; }
print_error() { echo -e "\033[0;31m[ERROR]\033[0m $1" >&2; }

# Safe entity creation
create_entity() {
    local entity_type="$1" name="$2" parent_id="$3"

    # Check if exists first
    local search_param=$(printf 'name="%s"' "$name")
    local existing=$(curl -k -s -u "${FOREMAN_USERNAME}:${FOREMAN_PASSWORD}" \
        "${KATELLO_URL}/${entity_type}" \
        --data-urlencode "search=${search_param}" \
        --data-urlencode "organization_id=${parent_id}" -G 2>/dev/null | \
        python3 -c "
import json,sys
try:
    data = json.load(sys.stdin)
    if data.get('total', 0) > 0:
        print(data['results'][0]['id'])
    else:
        print('')
except:
    print('')
")

    if [[ -n "$existing" ]]; then
        print_info "$entity_type '$name' already exists (ID: $existing)"
        echo "$existing"
        return 0
    fi

    # Create new entity
    local response=$(api_call "POST" "${KATELLO_URL}/${entity_type}" \
        "{\"name\": \"$name\", \"organization_id\": $parent_id}" \
        "Creating $entity_type '$name'")

    extract_id "$response"
}

# Usage
ORG_ID=$(create_entity "organizations" "My Org" "")
PRODUCT_ID=$(create_entity "products" "My Product" "$ORG_ID")
```

## 🚀 **Key Takeaways**

1. **Always escape URL parameters** - Use `--data-urlencode` with `-G`
2. **Know your API endpoints** - Katello vs Foreman API paths matter
3. **Separate logging from data** - stderr for logs, stdout for results
4. **Handle null vs actual errors** - `"errors":null` ≠ failure
5. **Plan for async operations** - Katello tasks take time
6. **Test with real data** - Entity names with spaces reveal bugs
7. **Implement proper retries** - Network and task conflicts happen
8. **Validate early and often** - Check each step before proceeding

These skills are now embedded in the automation scripts and can be applied to any Katello/Foreman/Red Hat Satellite automation project!