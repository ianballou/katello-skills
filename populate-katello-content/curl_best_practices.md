# Curl Best Practices for Katello/Foreman APIs

## URL Parameter Escaping Issues and Solutions

### ❌ Common Problem: Improper Search Parameter Handling

When using search parameters with curl, many examples show incorrect usage like:

```bash
# WRONG - This will fail!
curl -k ${HEADERS} "${BASE_URL}/organizations?search=name=\"foo\""

# WRONG - Shell interprets quotes and special characters
curl -k ${HEADERS} "${KATELLO_URL}/repositories?search=content_type=yum and last_sync.result=error"
```

### ✅ Correct Solutions

#### Method 1: Using `--data-urlencode` with `-G` (Recommended)

```bash
# Correct way to search for organization named "foo"
curl -k ${HEADERS} "${BASE_URL}/organizations" --data-urlencode 'search=name="foo"' -G

# Correct way to search with complex criteria
curl -k ${HEADERS} "${BASE_URL}/hosts" \
  --data-urlencode 'search=hostgroup="web-servers" and environment="production"' -G

# Correct way to search repositories
curl -k ${HEADERS} "${KATELLO_URL}/repositories" \
  --data-urlencode 'search=content_type=yum and last_sync.result=error' -G
```

#### Method 2: Manual URL Encoding

```bash
# Using printf to build the search parameter
search_param=$(printf 'name="%s"' "foo")
curl -k ${HEADERS} "${BASE_URL}/organizations" --data-urlencode "search=${search_param}" -G

# For complex searches with variables
org_name="My Organization"
search_param=$(printf 'name="%s"' "$org_name")
curl -k ${HEADERS} "${BASE_URL}/organizations" --data-urlencode "search=${search_param}" -G
```

#### Method 3: Multiple Parameters

```bash
# Multiple query parameters (organization_id + search)
curl -k ${HEADERS} "${KATELLO_URL}/products" \
  --data-urlencode "organization_id=1" \
  --data-urlencode 'search=name="prod"' \
  -G
```

## Complete Examples with Proper Escaping

### Organization Operations

```bash
# List all organizations
curl -k ${HEADERS} "${BASE_URL}/organizations"

# Search for specific organization
curl -k ${HEADERS} "${BASE_URL}/organizations" \
  --data-urlencode 'search=name="foo"' -G

# Search with pattern matching
curl -k ${HEADERS} "${BASE_URL}/organizations" \
  --data-urlencode 'search=name~"test*"' -G
```

### Product Operations

```bash
# List products in organization
curl -k ${HEADERS} "${KATELLO_URL}/products" \
  --data-urlencode "organization_id=1" -G

# Search for specific product in organization
curl -k ${HEADERS} "${KATELLO_URL}/products" \
  --data-urlencode "organization_id=1" \
  --data-urlencode 'search=name="prod"' -G
```

### Repository Operations

```bash
# List repositories with filters
curl -k ${HEADERS} "${KATELLO_URL}/repositories" \
  --data-urlencode "organization_id=1" \
  --data-urlencode "product_id=5" -G

# Search repositories by content type
curl -k ${HEADERS} "${KATELLO_URL}/repositories" \
  --data-urlencode 'search=content_type=docker' -G

# Complex repository search
curl -k ${HEADERS} "${KATELLO_URL}/repositories" \
  --data-urlencode 'search=content_type=yum and last_sync.result=success' -G
```

### Host Operations

```bash
# Search hosts with multiple criteria
curl -k ${HEADERS} "${BASE_URL}/hosts" \
  --data-urlencode 'search=hostgroup="web-servers" and os="RHEL 8"' -G

# Search hosts by subscription status
curl -k ${HEADERS} "${BASE_URL}/hosts" \
  --data-urlencode 'search=subscription_status=invalid' -G
```

### Content View Operations

```bash
# Search content views in environment
curl -k ${HEADERS} "${KATELLO_URL}/content_view_versions" \
  --data-urlencode "content_view_id=10" \
  --data-urlencode 'environment=Development' -G

# Search content views by name pattern
curl -k ${HEADERS} "${KATELLO_URL}/content_views" \
  --data-urlencode "organization_id=1" \
  --data-urlencode 'search=name~"rhel*"' -G
```

## Why This Matters

### Security Issues
- Unescaped parameters can be exploited for injection attacks
- Special characters can break API queries
- Quotes and spaces must be properly handled

### Functional Issues
```bash
# This will fail if organization name contains spaces
ORG_NAME="My Test Org"
curl -k ${HEADERS} "${BASE_URL}/organizations?search=name=\"${ORG_NAME}\""

# This works correctly
search_param=$(printf 'name="%s"' "$ORG_NAME")
curl -k ${HEADERS} "${BASE_URL}/organizations" --data-urlencode "search=${search_param}" -G
```

## Bash Helper Functions

```bash
# URL encoding function
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

# Safe API search function
api_search() {
    local endpoint="$1"
    local search_query="$2"
    local org_id="${3:-}"

    local url="${KATELLO_URL}${endpoint}"
    if [[ "$endpoint" != /katello/* ]]; then
        url="${BASE_URL}${endpoint}"
    fi

    if [[ -n "$org_id" ]]; then
        curl -k ${HEADERS} "$url" \
          --data-urlencode "organization_id=${org_id}" \
          --data-urlencode "search=${search_query}" -G
    else
        curl -k ${HEADERS} "$url" \
          --data-urlencode "search=${search_query}" -G
    fi
}

# Usage examples
api_search "/organizations" 'name="foo"'
api_search "/products" 'name="prod"' "1"
api_search "/repositories" 'content_type=yum and last_sync.result=success' "1"
```

## Updated Script Templates

### Search and Create Pattern

```bash
# Safe organization search and create
find_or_create_org() {
    local org_name="$1"

    # Search for existing organization
    local search_param=$(printf 'name="%s"' "$org_name")
    local existing_org=$(curl -k ${HEADERS} "${BASE_URL}/organizations" \
        --data-urlencode "search=${search_param}" -G 2>/dev/null | \
        python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    if data['total'] > 0:
        print(data['results'][0]['id'])
    else:
        print('')
except:
    print('')
")

    if [[ -n "$existing_org" ]]; then
        echo "$existing_org"
    else
        # Create new organization
        local response=$(curl -k ${HEADERS} -X POST "${BASE_URL}/organizations" \
            -d "{\"name\": \"${org_name}\"}" 2>/dev/null)
        echo "$response" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    print(data['id'])
except:
    print('')
"
    fi
}
```

## Key Takeaways

1. **Always use `--data-urlencode` with `-G`** for query parameters
2. **Never put query parameters directly in the URL** when they contain special characters
3. **Use printf to safely build search parameters** with variables
4. **Test with organization names containing spaces** to verify escaping works
5. **Implement helper functions** to standardize safe API calls

This ensures your curl commands work reliably across all environments and with all types of data.