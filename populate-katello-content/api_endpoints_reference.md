# Katello vs Foreman API Endpoints Reference

## The Issue

When working with Red Hat Satellite/Katello, you'll encounter this error:
```
{"message": "Route overridden by Katello, use the /katello API endpoint instead. See /apidoc for more details."}
```

This happens because Katello overrides certain Foreman API endpoints.

## Correct API Endpoints

### Use **KATELLO API** (`/katello/api/v2/`) for:

```bash
# Content management entities
/katello/api/v2/organizations
/katello/api/v2/products
/katello/api/v2/repositories
/katello/api/v2/content_views
/katello/api/v2/content_view_versions
/katello/api/v2/environments  # Lifecycle environments
/katello/api/v2/activation_keys
/katello/api/v2/subscriptions
/katello/api/v2/host_collections
/katello/api/v2/sync_plans
/katello/api/v2/gpg_keys
/katello/api/v2/packages
/katello/api/v2/errata
/katello/api/v2/docker_tags
/katello/api/v2/debs
/katello/api/v2/ansible_collections
/katello/api/v2/python_packages
/katello/api/v2/files
/katello/api/v2/capsules  # Capsule/Smart Proxy content
/katello/api/v2/consumers  # Host subscription consumers
```

### Use **FOREMAN API** (`/api/v2/`) for:

```bash
# Infrastructure and provisioning entities
/api/v2/hosts
/api/v2/hostgroups
/api/v2/interfaces
/api/v2/users
/api/v2/user_groups
/api/v2/roles
/api/v2/permissions
/api/v2/locations
/api/v2/domains
/api/v2/subnets
/api/v2/smart_proxies
/api/v2/compute_resources
/api/v2/images
/api/v2/operatingsystems
/api/v2/architectures
/api/v2/media  # Installation media
/api/v2/ptables  # Partition tables
/api/v2/provisioning_templates
/api/v2/job_templates
/api/v2/tasks
/api/v2/audits
/api/v2/bookmarks
/api/v2/settings
/api/v2/ping
/api/v2/statistics
/api/v2/facts
/api/v2/reports
```

### Special Cases - Both APIs Available:

Some entities are available in both APIs but with different capabilities:

```bash
# Host subscriptions (Katello-specific features)
/katello/api/v2/hosts/:id/subscriptions  # Subscription management
/api/v2/hosts/:id                        # Basic host info

# Registration (both available)
/api/v2/registration_commands            # Basic registration
/katello/api/v2/registration             # Katello-enhanced registration
```

## Fixed Examples

### ❌ Wrong (causes override error):
```bash
curl -k ${HEADERS} -X POST "${BASE_URL}/organizations" -d '{"name": "foo"}'
curl -k ${HEADERS} "${BASE_URL}/organizations?search=name=\"foo\""
```

### ✅ Correct:
```bash
curl -k ${HEADERS} -X POST "${KATELLO_URL}/organizations" -d '{"name": "foo"}'
curl -k ${HEADERS} "${KATELLO_URL}/organizations" --data-urlencode 'search=name="foo"' -G
```

## How to Determine Which API to Use

### Method 1: Check the documentation
Visit your Satellite at: `https://your-satellite.example.com/apidoc`

### Method 2: Try the call and check for override message
If you get the "Route overridden by Katello" message, switch to the Katello API.

### Method 3: General rule of thumb
- **Content-related**: Use Katello API
- **Infrastructure/Provisioning**: Use Foreman API
- **When in doubt**: Try Foreman first, switch to Katello if you get the override message

## Complete Working Examples

### Organizations
```bash
# List organizations
curl -k ${HEADERS} "${KATELLO_URL}/organizations"

# Create organization
curl -k ${HEADERS} -X POST "${KATELLO_URL}/organizations" -d '{
  "name": "test-org",
  "description": "Test organization"
}'

# Search organizations
curl -k ${HEADERS} "${KATELLO_URL}/organizations" \
  --data-urlencode 'search=name="test-org"' -G
```

### Products
```bash
# List products
curl -k ${HEADERS} "${KATELLO_URL}/products" \
  --data-urlencode "organization_id=1" -G

# Create product
curl -k ${HEADERS} -X POST "${KATELLO_URL}/products" -d '{
  "name": "test-product",
  "organization_id": 1
}'
```

### Repositories
```bash
# List repositories
curl -k ${HEADERS} "${KATELLO_URL}/repositories" \
  --data-urlencode "organization_id=1" -G

# Create repository
curl -k ${HEADERS} -X POST "${KATELLO_URL}/repositories" -d '{
  "name": "test-repo",
  "product_id": 5,
  "content_type": "yum",
  "url": "https://repo.example.com/"
}'
```

### Hosts (Foreman API)
```bash
# List hosts
curl -k ${HEADERS} "${BASE_URL}/hosts" \
  --data-urlencode "organization_id=1" -G

# Create host
curl -k ${HEADERS} -X POST "${BASE_URL}/hosts" -d '{
  "name": "test-host",
  "organization_id": 1,
  "location_id": 1
}'
```

### Host Subscriptions (Katello API)
```bash
# Register host for subscriptions
curl -k ${HEADERS} -X POST "${BASE_URL}/hosts/subscriptions" -d '{
  "name": "test-host",
  "lifecycle_environment_id": 1,
  "content_view_id": 1
}'

# List host subscriptions
curl -k ${HEADERS} "${KATELLO_URL}/hosts/1/subscriptions"
```

## Updated Script Pattern

```bash
#!/bin/bash

# API URLs
FOREMAN_URL="https://your-foreman.example.com"
BASE_URL="${FOREMAN_URL}/api/v2"          # Foreman API
KATELLO_URL="${FOREMAN_URL}/katello/api/v2"  # Katello API
HEADERS='-H "Content-Type: application/json" -u "username:password"'

# Content management - use Katello API
create_organization() {
    curl -k ${HEADERS} -X POST "${KATELLO_URL}/organizations" -d '{
        "name": "'"$1"'",
        "description": "Created by script"
    }'
}

# Infrastructure management - use Foreman API
create_host() {
    curl -k ${HEADERS} -X POST "${BASE_URL}/hosts" -d '{
        "name": "'"$1"'",
        "organization_id": '"$2"'
    }'
}
```

This reference should help you avoid the "Route overridden by Katello" error in the future!