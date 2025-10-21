---
name: Katello Complete Management
description: Complete Katello/Foreman/Satellite management via REST API for all 126+ entities. Use for creating repositories, managing content, users, hosts, products, lifecycle environments, content views, subscriptions, organizations, and any other Katello operations.
allowed-tools: Bash, WebFetch, Read
---

# Katello Complete Management

This skill provides comprehensive management of Katello/Foreman/Red Hat Satellite using the REST API, covering all 126+ available entities and operations.

## Prerequisites

- Katello/Foreman/Satellite instance URL
- Admin credentials (username/password)
- Access to the target system (can be provided via environment variables)

## Supported Entities (126 Total)

Based on the complete Foreman API v2 documentation, this skill supports all entities including:

### Content Management
- **Repositories** (docker, yum, deb, file, python, ansible_collection, ostree)
- **Products**
- **Content Views**
- **Lifecycle Environments**
- **Subscriptions**
- **Activation Keys**
- **Sync Plans**

### Host Management
- **Hosts**
- **Host Groups**
- **Host Collections**
- **Interfaces**
- **Host Subscriptions**
- **Registration**

### Infrastructure
- **Organizations**
- **Locations**
- **Domains**
- **Subnets**
- **Smart Proxies**
- **Compute Resources**
- **Images**

### Configuration Management
- **Puppet Classes**
- **Config Groups**
- **Environments**
- **Parameters**
- **Variables**

### Monitoring & Reporting
- **Reports**
- **Statistics**
- **Trends**
- **Mail Notifications**

### Security & Access
- **Users**
- **User Groups**
- **Roles**
- **Permissions**
- **Auth Sources**
- **Personal Access Tokens**

### Provisioning
- **Operating Systems**
- **Architectures**
- **Partition Tables**
- **Installation Media**
- **Provisioning Templates**
- **Job Templates**

### And Many More...
Including: Audits, Bookmarks, Common Parameters, Dashboard, Facts, Filters, Foreign Keys, HTTP Proxies, Override Values, Ping, Plugins, Realms, Settings, SSH Keys, Table Preferences, Tasks, Templates, and more.

## Environment Configuration

You can set credentials via environment variables:
```bash
export FOREMAN_URL="https://your-foreman.example.com"
export FOREMAN_USERNAME="admin"
export FOREMAN_PASSWORD="your-password"
export FOREMAN_ORG_ID="1"  # Optional: default organization

# Legacy support (backward compatibility)
# export SATELLITE_URL="https://your-satellite.example.com"
# export SATELLITE_USERNAME="admin"
# export SATELLITE_PASSWORD="your-password"
# export SATELLITE_ORG_ID="1"
```

## API Base Patterns

All operations follow consistent REST API patterns:

### Authentication
```bash
# All requests use basic auth
HEADERS='-H "Content-Type: application/json" -u "${FOREMAN_USERNAME}:${FOREMAN_PASSWORD}"'
BASE_URL="${FOREMAN_URL}/api/v2"  # Standard Foreman API
KATELLO_URL="${FOREMAN_URL}/katello/api/v2"  # Katello-specific API
```

### Standard Operations

**LIST entities:**
```bash
curl -k ${HEADERS} "${BASE_URL}/{entity_type}?organization_id=${ORG_ID}"
```

**GET single entity:**
```bash
curl -k ${HEADERS} "${BASE_URL}/{entity_type}/{id}"
```

**CREATE entity:**
```bash
curl -k ${HEADERS} -X POST "${BASE_URL}/{entity_type}" -d '{json_data}'
```

**UPDATE entity:**
```bash
curl -k ${HEADERS} -X PUT "${BASE_URL}/{entity_type}/{id}" -d '{json_data}'
```

**DELETE entity:**
```bash
curl -k ${HEADERS} -X DELETE "${BASE_URL}/{entity_type}/{id}"
```

## Core Entity Operations

### Organizations
```bash
# List all organizations
curl -k ${HEADERS} "${BASE_URL}/organizations"

# Create organization
curl -k ${HEADERS} -X POST "${BASE_URL}/organizations" -d '{
  "name": "New Org",
  "description": "New organization for testing"
}'

# Get organization details
curl -k ${HEADERS} "${BASE_URL}/organizations/{id}"
```

### Products
```bash
# List products in organization
curl -k ${HEADERS} "${KATELLO_URL}/products?organization_id=${ORG_ID}"

# Create product
curl -k ${HEADERS} -X POST "${KATELLO_URL}/products" -d '{
  "name": "Custom Product",
  "organization_id": '${ORG_ID}',
  "description": "Custom product for repositories"
}'

# Sync all repositories in product
curl -k ${HEADERS} -X POST "${KATELLO_URL}/products/{id}/sync"
```

### Repositories
```bash
# List repositories
curl -k ${HEADERS} "${KATELLO_URL}/repositories?organization_id=${ORG_ID}"

# Create repository (content_type: docker, yum, deb, file, python, ansible_collection, ostree)
curl -k ${HEADERS} -X POST "${KATELLO_URL}/repositories" -d '{
  "name": "repo-name",
  "product_id": PRODUCT_ID,
  "content_type": "yum",
  "url": "https://repo-url.com/",
  "download_policy": "on_demand"
}'

# Sync repository
curl -k ${HEADERS} -X POST "${KATELLO_URL}/repositories/{id}/sync"

# Upload content to repository (for file repos)
curl -k ${HEADERS} -X POST "${KATELLO_URL}/repositories/{id}/upload_content" \
  -F "content=@/path/to/file"
```

### Content Views
```bash
# List content views
curl -k ${HEADERS} "${KATELLO_URL}/content_views?organization_id=${ORG_ID}"

# Create content view
curl -k ${HEADERS} -X POST "${KATELLO_URL}/content_views" -d '{
  "name": "Custom CV",
  "organization_id": '${ORG_ID}',
  "description": "Custom content view"
}'

# Add repositories to content view
curl -k ${HEADERS} -X PUT "${KATELLO_URL}/content_views/{id}" -d '{
  "repository_ids": [REPO_ID1, REPO_ID2]
}'

# Publish content view
curl -k ${HEADERS} -X POST "${KATELLO_URL}/content_views/{id}/publish" -d '{
  "description": "New version"
}'

# Promote content view version
curl -k ${HEADERS} -X POST "${KATELLO_URL}/content_view_versions/{version_id}/promote" -d '{
  "environment_ids": [ENV_ID]
}'
```

### Lifecycle Environments
```bash
# List lifecycle environments
curl -k ${HEADERS} "${KATELLO_URL}/environments?organization_id=${ORG_ID}"

# Create lifecycle environment
curl -k ${HEADERS} -X POST "${KATELLO_URL}/environments" -d '{
  "name": "Development",
  "organization_id": '${ORG_ID}',
  "prior_id": LIBRARY_ENV_ID,
  "description": "Development environment"
}'
```

### Hosts
```bash
# List hosts
curl -k ${HEADERS} "${BASE_URL}/hosts?organization_id=${ORG_ID}"

# Create host
curl -k ${HEADERS} -X POST "${BASE_URL}/hosts" -d '{
  "name": "test-host",
  "organization_id": '${ORG_ID}',
  "location_id": LOCATION_ID,
  "hostgroup_id": HOSTGROUP_ID,
  "operatingsystem_id": OS_ID,
  "architecture_id": ARCH_ID,
  "environment_id": PUPPET_ENV_ID,
  "mac": "aa:bb:cc:dd:ee:ff",
  "ip": "192.168.1.100"
}'

# Register host to subscription
curl -k ${HEADERS} -X POST "${BASE_URL}/hosts/subscriptions" -d '{
  "name": "host-name",
  "lifecycle_environment_id": LIFECYCLE_ENV_ID,
  "content_view_id": CONTENT_VIEW_ID
}'

# Update host facts
curl -k ${HEADERS} -X PUT "${KATELLO_URL}/consumers/{uuid}/profiles" -d '{
  "profile_type": "enabled_repos",
  "profile": {"enabled_repos": [...]}
}'
```

### Activation Keys
```bash
# List activation keys
curl -k ${HEADERS} "${KATELLO_URL}/activation_keys?organization_id=${ORG_ID}"

# Create activation key
curl -k ${HEADERS} -X POST "${KATELLO_URL}/activation_keys" -d '{
  "name": "dev-key",
  "organization_id": '${ORG_ID}',
  "environment_id": LIFECYCLE_ENV_ID,
  "content_view_id": CONTENT_VIEW_ID,
  "unlimited_hosts": true
}'

# Add subscriptions to activation key
curl -k ${HEADERS} -X POST "${KATELLO_URL}/activation_keys/{id}/subscriptions" -d '{
  "subscriptions": [{"id": "subscription_id", "quantity": 1}]
}'
```

### Host Collections
```bash
# List host collections
curl -k ${HEADERS} "${KATELLO_URL}/host_collections?organization_id=${ORG_ID}"

# Create host collection
curl -k ${HEADERS} -X POST "${KATELLO_URL}/host_collections" -d '{
  "name": "Web Servers",
  "organization_id": '${ORG_ID}',
  "description": "Collection of web servers"
}'

# Add hosts to collection
curl -k ${HEADERS} -X PUT "${KATELLO_URL}/host_collections/{id}/add_hosts" -d '{
  "host_ids": [HOST_ID1, HOST_ID2]
}'

# Install packages on host collection
curl -k ${HEADERS} -X PUT "${KATELLO_URL}/host_collections/{id}/install_content" -d '{
  "content_type": "package",
  "content": ["httpd", "nginx"]
}'
```

### Users and Permissions
```bash
# List users
curl -k ${HEADERS} "${BASE_URL}/users"

# Create user
curl -k ${HEADERS} -X POST "${BASE_URL}/users" -d '{
  "login": "newuser",
  "firstname": "New",
  "lastname": "User",
  "mail": "newuser@example.com",
  "password": "temppass123",
  "organization_ids": ['${ORG_ID}'],
  "location_ids": [LOCATION_ID]
}'

# List roles
curl -k ${HEADERS} "${BASE_URL}/roles"

# Assign role to user
curl -k ${HEADERS} -X POST "${BASE_URL}/users/{user_id}/roles/{role_id}"
```

### Smart Proxies
```bash
# List smart proxies
curl -k ${HEADERS} "${BASE_URL}/smart_proxies"

# Get proxy features
curl -k ${HEADERS} "${BASE_URL}/smart_proxies/{id}/features"

# Refresh proxy features
curl -k ${HEADERS} -X PUT "${BASE_URL}/smart_proxies/{id}/refresh"
```

### Subscriptions Management
```bash
# List subscriptions
curl -k ${HEADERS} "${KATELLO_URL}/subscriptions?organization_id=${ORG_ID}"

# Upload subscription manifest
curl -k ${HEADERS} -X POST "${KATELLO_URL}/organizations/{org_id}/subscriptions/upload" \
  -F "content=@manifest.zip"

# Refresh subscriptions
curl -k ${HEADERS} -X PUT "${KATELLO_URL}/organizations/{org_id}/subscriptions/refresh"

# Delete subscription manifest
curl -k ${HEADERS} -X DELETE "${KATELLO_URL}/organizations/{org_id}/subscriptions/delete_manifest"
```

### Sync Plans
```bash
# List sync plans
curl -k ${HEADERS} "${KATELLO_URL}/sync_plans?organization_id=${ORG_ID}"

# Create sync plan
curl -k ${HEADERS} -X POST "${KATELLO_URL}/sync_plans" -d '{
  "name": "Daily Sync",
  "organization_id": '${ORG_ID}',
  "interval": "daily",
  "sync_date": "2024-01-01T02:00:00Z",
  "enabled": true
}'

# Add products to sync plan
curl -k ${HEADERS} -X PUT "${KATELLO_URL}/sync_plans/{id}/add_products" -d '{
  "product_ids": [PRODUCT_ID1, PRODUCT_ID2]
}'
```

### Task Management
```bash
# List tasks
curl -k ${HEADERS} "${BASE_URL}/tasks"

# Get task details
curl -k ${HEADERS} "${BASE_URL}/tasks/{id}"

# Cancel task
curl -k ${HEADERS} -X DELETE "${BASE_URL}/tasks/{id}"
```

## Advanced Entity Operations

### Bulk Operations
```bash
# Bulk host actions
curl -k ${HEADERS} -X PUT "${BASE_URL}/hosts/bulk/destroy" -d '{
  "organization_id": '${ORG_ID}',
  "included": {"search": "hostgroup = \"old-group\""}
}'

# Bulk content host actions (install packages)
curl -k ${HEADERS} -X PUT "${KATELLO_URL}/hosts/bulk/install_content" -d '{
  "organization_id": '${ORG_ID}',
  "included": {"ids": [HOST_ID1, HOST_ID2]},
  "content_type": "package",
  "content": ["httpd", "vim"]
}'
```

### Composite Content Views
```bash
# Create composite content view
curl -k ${HEADERS} -X POST "${KATELLO_URL}/content_views" -d '{
  "name": "Composite CV",
  "organization_id": '${ORG_ID}',
  "composite": true,
  "component_ids": [CV_VERSION_ID1, CV_VERSION_ID2]
}'
```

### Capsule/Smart Proxy Sync
```bash
# List capsule content
curl -k ${HEADERS} "${KATELLO_URL}/capsules/{id}/content/lifecycle_environments"

# Sync capsule
curl -k ${HEADERS} -X POST "${KATELLO_URL}/capsules/{id}/content/sync" -d '{
  "environment_id": LIFECYCLE_ENV_ID
}'
```

### Content Credential Management
```bash
# List GPG keys
curl -k ${HEADERS} "${KATELLO_URL}/gpg_keys?organization_id=${ORG_ID}"

# Create GPG key
curl -k ${HEADERS} -X POST "${KATELLO_URL}/gpg_keys" -d '{
  "name": "Custom GPG Key",
  "organization_id": '${ORG_ID}',
  "content": "-----BEGIN PGP PUBLIC KEY BLOCK-----\n..."
}'

# Upload GPG key from file
curl -k ${HEADERS} -X POST "${KATELLO_URL}/gpg_keys" \
  -F "name=Uploaded GPG" \
  -F "organization_id=${ORG_ID}" \
  -F "content=@gpgkey.asc"
```

## Helper Functions

### Dynamic Organization and Product Detection
```bash
#!/bin/bash

# Auto-detect organization ID
get_org_id() {
  local org_name="$1"
  curl -k ${HEADERS} "${BASE_URL}/organizations" 2>/dev/null | \
    python3 -c "
import json, sys
data = json.load(sys.stdin)
orgs = [o for o in data['results'] if o['name'] == '${org_name}']
print(orgs[0]['id'] if orgs else data['results'][0]['id'])
"
}

# Auto-detect or create product
get_or_create_product() {
  local product_name="$1"
  local org_id="$2"

  # Try to find existing product
  local product_id=$(curl -k ${HEADERS} "${KATELLO_URL}/products?organization_id=${org_id}&name=${product_name}" 2>/dev/null | \
    python3 -c "
import json, sys
data = json.load(sys.stdin)
print(data['results'][0]['id'] if data['total'] > 0 else '')
")

  if [[ -z "$product_id" ]]; then
    # Create new product
    product_id=$(curl -k ${HEADERS} -X POST "${KATELLO_URL}/products" -d "{
      \"name\": \"${product_name}\",
      \"organization_id\": ${org_id}
    }" 2>/dev/null | python3 -c "import json,sys; print(json.load(sys.stdin)['id'])")
  fi

  echo "$product_id"
}

# Usage
ORG_ID=$(get_org_id "Default Organization")
PRODUCT_ID=$(get_or_create_product "Custom Content" "$ORG_ID")
```

### Content Verification Scripts
```bash
# Verify repository sync status
check_repo_sync() {
  local repo_id="$1"
  curl -k ${HEADERS} "${KATELLO_URL}/repositories/${repo_id}" 2>/dev/null | \
    python3 -c "
import json, sys
data = json.load(sys.stdin)
last_sync = data.get('last_sync', {})
status = last_sync.get('result', 'never_synced')
content = data.get('content_counts', {})
print(f'Sync Status: {status}')
if content:
    for content_type, count in content.items():
        print(f'{content_type}: {count}')
"
}

# Monitor task progress
monitor_task() {
  local task_id="$1"
  while true; do
    local status=$(curl -k ${HEADERS} "${BASE_URL}/tasks/${task_id}" 2>/dev/null | \
      python3 -c "import json,sys; print(json.load(sys.stdin)['state'])")

    echo "Task status: $status"
    [[ "$status" =~ (stopped|succeeded|error) ]] && break
    sleep 5
  done
}
```

## Content Type-Specific Examples

### Docker Repository with Advanced Configuration
```bash
curl -k ${HEADERS} -X POST "${KATELLO_URL}/repositories" -d '{
  "name": "nginx-secure",
  "product_id": '${PRODUCT_ID}',
  "content_type": "docker",
  "url": "https://registry.redhat.io",
  "docker_upstream_name": "ubi8/nginx-118",
  "upstream_username": "registry_username",
  "upstream_password": "registry_token",
  "include_tags": ["latest", "1.*"],
  "exclude_tags": ["*-source", "*-debug"],
  "download_policy": "on_demand",
  "verify_ssl_on_sync": true
}'
```

### Yum Repository with GPG Key
```bash
# First create/upload GPG key
GPG_KEY_ID=$(curl -k ${HEADERS} -X POST "${KATELLO_URL}/gpg_keys" -d '{
  "name": "EPEL GPG Key",
  "organization_id": '${ORG_ID}',
  "content": "-----BEGIN PGP PUBLIC KEY BLOCK-----\n...\n-----END PGP PUBLIC KEY BLOCK-----"
}' 2>/dev/null | python3 -c "import json,sys; print(json.load(sys.stdin)['id'])")

# Create repository with GPG key
curl -k ${HEADERS} -X POST "${KATELLO_URL}/repositories" -d '{
  "name": "epel-8",
  "product_id": '${PRODUCT_ID}',
  "content_type": "yum",
  "url": "https://dl.fedoraproject.org/pub/epel/8/Everything/x86_64/",
  "gpg_key_id": '${GPG_KEY_ID}',
  "download_policy": "on_demand",
  "verify_ssl_on_sync": true,
  "checksum_type": "sha256"
}'
```

### Python Repository with Package Filtering
```bash
curl -k ${HEADERS} -X POST "${KATELLO_URL}/repositories" -d '{
  "name": "python-essentials",
  "product_id": '${PRODUCT_ID}',
  "content_type": "python",
  "url": "https://pypi.org/",
  "generic_remote_options": {
    "includes": [
      "requests>=2.28.0",
      "django~=4.0",
      "flask>=2.0.0,<3.0.0",
      "numpy",
      "pandas"
    ],
    "excludes": ["*-dev", "*-test"],
    "keep_latest_packages": 3,
    "package_types": ["bdist_wheel", "sdist"],
    "prereleases": false
  }
}'
```

## Complete Workflow Examples

### Full Organization Setup
```bash
#!/bin/bash
set -e

# Create organization
ORG_ID=$(curl -k ${HEADERS} -X POST "${BASE_URL}/organizations" -d '{
  "name": "Development Org",
  "description": "Development organization"
}' 2>/dev/null | python3 -c "import json,sys; print(json.load(sys.stdin)['id'])")

# Create lifecycle environments
LIBRARY_ID=$(curl -k ${HEADERS} "${KATELLO_URL}/environments?organization_id=${ORG_ID}&name=Library" 2>/dev/null | \
  python3 -c "import json,sys; print(json.load(sys.stdin)['results'][0]['id'])")

DEV_ENV_ID=$(curl -k ${HEADERS} -X POST "${KATELLO_URL}/environments" -d '{
  "name": "Development",
  "organization_id": '${ORG_ID}',
  "prior_id": '${LIBRARY_ID}'
}' 2>/dev/null | python3 -c "import json,sys; print(json.load(sys.stdin)['id'])")

PROD_ENV_ID=$(curl -k ${HEADERS} -X POST "${KATELLO_URL}/environments" -d '{
  "name": "Production",
  "organization_id": '${ORG_ID}',
  "prior_id": '${DEV_ENV_ID}'
}' 2>/dev/null | python3 -c "import json,sys; print(json.load(sys.stdin)['id'])")

# Create product and repositories
PRODUCT_ID=$(curl -k ${HEADERS} -X POST "${KATELLO_URL}/products" -d '{
  "name": "RHEL Content",
  "organization_id": '${ORG_ID}'
}' 2>/dev/null | python3 -c "import json,sys; print(json.load(sys.stdin)['id'])")

# Create content view and publish
CV_ID=$(curl -k ${HEADERS} -X POST "${KATELLO_URL}/content_views" -d '{
  "name": "RHEL Base",
  "organization_id": '${ORG_ID}'
}' 2>/dev/null | python3 -c "import json,sys; print(json.load(sys.stdin)['id'])")

# Publish and promote content view
curl -k ${HEADERS} -X POST "${KATELLO_URL}/content_views/${CV_ID}/publish"

CV_VERSION_ID=$(curl -k ${HEADERS} "${KATELLO_URL}/content_views/${CV_ID}/content_view_versions" 2>/dev/null | \
  python3 -c "import json,sys; print(json.load(sys.stdin)['results'][0]['id'])")

curl -k ${HEADERS} -X POST "${KATELLO_URL}/content_view_versions/${CV_VERSION_ID}/promote" -d '{
  "environment_ids": ['${DEV_ENV_ID}']
}'

echo "Organization setup complete!"
echo "Org ID: $ORG_ID"
echo "Library ID: $LIBRARY_ID"
echo "Dev Environment ID: $DEV_ENV_ID"
echo "Prod Environment ID: $PROD_ENV_ID"
echo "Product ID: $PRODUCT_ID"
echo "Content View ID: $CV_ID"
```

## Error Handling and Troubleshooting

### Common API Errors
```bash
# Wrapper function with error handling
api_call() {
  local method="$1"
  local url="$2"
  local data="$3"

  local response
  if [[ -n "$data" ]]; then
    response=$(curl -k ${HEADERS} -X "$method" "$url" -d "$data" 2>/dev/null)
  else
    response=$(curl -k ${HEADERS} -X "$method" "$url" 2>/dev/null)
  fi

  if echo "$response" | grep -q '"error"'; then
    echo "API Error: $(echo "$response" | python3 -c "import json,sys; print(json.load(sys.stdin).get('error', {}).get('message', 'Unknown error'))")" >&2
    return 1
  fi

  echo "$response"
}

# Usage
api_call "GET" "${BASE_URL}/organizations" || echo "Failed to list organizations"
```

### Status Monitoring
```bash
# Check overall system status
check_system_status() {
  echo "=== System Status ==="
  curl -k ${HEADERS} "${BASE_URL}/ping" 2>/dev/null | python3 -m json.tool

  echo -e "\n=== Task Summary ==="
  curl -k ${HEADERS} "${BASE_URL}/tasks?search=state!=stopped" 2>/dev/null | \
    python3 -c "
import json, sys
data = json.load(sys.stdin)
states = {}
for task in data['results']:
    state = task['state']
    states[state] = states.get(state, 0) + 1
print(f'Running tasks: {states}')
"

  echo -e "\n=== Storage Usage ==="
  curl -k ${HEADERS} "${BASE_URL}/statistics" 2>/dev/null | \
    python3 -c "
import json, sys
data = json.load(sys.stdin)
print(f'Hosts: {data.get(\"hosts\", 0)}')
print(f'Content Hosts: {data.get(\"content_hosts\", 0)}')
"
}
```

## Advanced Query Examples

### Complex Search Queries
```bash
# Find hosts by multiple criteria
curl -k ${HEADERS} "${BASE_URL}/hosts" --data-urlencode 'search=hostgroup="web-servers" and environment="production" and status.failed=true' -G

# Find repositories by content type and sync status
curl -k ${HEADERS} "${KATELLO_URL}/repositories" --data-urlencode 'search=content_type=yum and last_sync.result=error' -G

# Find content view versions in specific environments
curl -k ${HEADERS} "${KATELLO_URL}/content_view_versions" --data-urlencode 'search=environment="development"' -G
```

### Reporting and Analytics
```bash
# Generate content summary report
generate_content_report() {
  local org_id="$1"

  echo "=== Content Summary Report ==="
  echo "Organization ID: $org_id"
  echo

  echo "Products:"
  curl -k ${HEADERS} "${KATELLO_URL}/products?organization_id=${org_id}" 2>/dev/null | \
    python3 -c "
import json, sys
data = json.load(sys.stdin)
for product in data['results']:
    print(f'  - {product[\"name\"]} (ID: {product[\"id\"]})')
"

  echo -e "\nRepositories by Type:"
  curl -k ${HEADERS} "${KATELLO_URL}/repositories?organization_id=${org_id}" 2>/dev/null | \
    python3 -c "
import json, sys
data = json.load(sys.stdin)
types = {}
for repo in data['results']:
    content_type = repo['content_type']
    types[content_type] = types.get(content_type, 0) + 1
for content_type, count in types.items():
    print(f'  {content_type}: {count}')
"

  echo -e "\nSync Status Summary:"
  curl -k ${HEADERS} "${KATELLO_URL}/repositories?organization_id=${org_id}" 2>/dev/null | \
    python3 -c "
import json, sys
data = json.load(sys.stdin)
statuses = {}
for repo in data['results']:
    status = repo.get('last_sync', {}).get('result', 'never_synced')
    statuses[status] = statuses.get(status, 0) + 1
for status, count in statuses.items():
    print(f'  {status}: {count}')
"
}
```

## Security Best Practices

### Secure API Access
```bash
# Use service account with minimal permissions
# Create dedicated API user
API_USER_ID=$(curl -k ${HEADERS} -X POST "${BASE_URL}/users" -d '{
  "login": "api-service",
  "firstname": "API",
  "lastname": "Service",
  "mail": "api@example.com",
  "password": "generated-secure-password",
  "admin": false,
  "organization_ids": ['${ORG_ID}']
}' 2>/dev/null | python3 -c "import json,sys; print(json.load(sys.stdin)['id'])")

# Assign specific role (not admin)
curl -k ${HEADERS} -X POST "${BASE_URL}/users/${API_USER_ID}/roles" -d '{
  "role_id": CONTENT_MANAGER_ROLE_ID
}'
```

### SSL Certificate Management
```bash
# For production, always verify SSL
HEADERS_SECURE='-H "Content-Type: application/json" -u "${FOREMAN_USERNAME}:${FOREMAN_PASSWORD}"'

# Add CA certificate for private CAs
curl --cacert /path/to/ca.crt ${HEADERS_SECURE} "${BASE_URL}/organizations"
```

## Integration Examples

### CI/CD Pipeline Integration
```bash
#!/bin/bash
# Content promotion pipeline

promote_content() {
  local cv_id="$1"
  local from_env="$2"
  local to_env="$3"

  # Get latest version in source environment
  local cv_version_id=$(curl -k ${HEADERS} \
    "${KATELLO_URL}/content_view_versions?content_view_id=${cv_id}&environment=${from_env}" 2>/dev/null | \
    python3 -c "import json,sys; print(json.load(sys.stdin)['results'][0]['id'])")

  # Promote to target environment
  local task_id=$(curl -k ${HEADERS} -X POST \
    "${KATELLO_URL}/content_view_versions/${cv_version_id}/promote" -d "{
      \"environment_ids\": [${to_env}]
    }" 2>/dev/null | python3 -c "import json,sys; print(json.load(sys.stdin)['id'])")

  # Monitor promotion task
  monitor_task "$task_id"
}
```

### Automated Host Registration
```bash
# Generate registration command
get_registration_command() {
  local org_id="$1"
  local location_id="$2"
  local activation_key="$3"

  curl -k ${HEADERS} -X POST "${BASE_URL}/registration_commands" -d "{
    \"registration\": {
      \"organization_id\": ${org_id},
      \"location_id\": ${location_id},
      \"activation_keys\": [\"${activation_key}\"],
      \"update_packages\": true,
      \"install_packages\": \"vim,htop\"
    }
  }" 2>/dev/null | python3 -c "import json,sys; print(json.load(sys.stdin)['command'])"
}
```

This comprehensive skill covers all 126+ entities in the Katello/Foreman API, providing complete automation capabilities for Red Hat Satellite and related systems. Use the patterns above as templates for any entity operation you need to perform.

## Critical Lessons Learned & Best Practices

### 🚨 **Essential Fixes for Production**

1. **URL Parameter Escaping** - Always use `--data-urlencode` with `-G`:
   ```bash
   # CORRECT
   search_param=$(printf 'name="%s"' "$name")
   curl -k ${HEADERS} "${API_URL}" --data-urlencode "search=${search_param}" -G
   ```

2. **API Endpoint Selection** - Use correct API paths:
   - **Katello API** (`/katello/api/v2/`): organizations, products, repositories, content_views
   - **Foreman API** (`/api/v2/`): hosts, users, smart_proxies, templates

3. **Output Stream Separation** - Log messages to stderr, data to stdout:
   ```bash
   print_info() { echo -e "${BLUE}[INFO]${NC} $1" >&2; }
   ```

4. **Smart Error Detection** - Distinguish null from actual errors:
   ```python
   if 'errors' in data and data['errors'] is not None:
       actual_errors = [e for e in data['errors'] if e is not None and str(e).strip()]
       if actual_errors:  # Only fail on real errors
   ```

5. **Pending Task Handling** - Implement proper wait and retry logic for async operations

### 📁 **Additional Resources**

**Documentation:**
- `lessons_learned.md` - Comprehensive troubleshooting guide
- `curl_best_practices.md` - URL encoding and parameter handling
- `api_endpoints_reference.md` - Complete Katello vs Foreman API mapping

**Scripts:**
- `../scripts/setup_complete_workflow.sh` - Production-ready automation script
- `../scripts/entity_generator.sh` - Dynamic entity management for all 126+ types
- `../scripts/create_repositories.sh` - Repository creation script
- `../scripts/wait_for_task.sh` - Task monitoring utility

These battle-tested patterns ensure reliable automation in production Satellite environments.