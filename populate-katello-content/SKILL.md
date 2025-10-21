---
name: Populate Katello Content
description: Sync repositories and populate content in Katello/Foreman via API. Use when asked to create repositories, sync content, add docker/yum/deb repositories, populate products, or set up content sources.
allowed-tools: Bash, WebFetch, Read
---

# Populate Katello Content

This skill helps create and sync repositories in Katello/Foreman using the REST API.

## Prerequisites

- Katello/Foreman instance URL
- Admin credentials (username/password)
- Product ID or name where repositories should be created
- Repository source information (URL, upstream name for Docker, etc.)

## Testing Repositories

For testing purposes, use small repositories from **https://fixtures.pulpproject.org/** which provides:
- Small, predictable test repositories for all content types
- Fast sync times ideal for testing
- No authentication required
- Maintained by the Pulp project for testing

Example test repository URLs:
- Docker: `https://fixtures.pulpproject.org/` with `docker_upstream_name: "docker/manifests"`
- Yum: `https://fixtures.pulpproject.org/rpm-unsigned/`
- Python: `https://fixtures.pulpproject.org/python-pypi/`
- File: `https://fixtures.pulpproject.org/file/`
- Debian: `https://fixtures.pulpproject.org/debian/`

## Common Use Cases

1. **Create and sync Docker/container repositories**
2. **Create and sync Yum/RPM repositories**
3. **Create and sync Debian repositories**
4. **Create and sync Ansible Collection repositories**
5. **Create and sync Python package repositories**
6. **Create and sync OSTree repositories**
7. **Create and sync File repositories**
8. **Verify sync status**
9. **Check repository content**

## Instructions

### Step 1: Gather Required Information

Before creating repositories, collect:
- Katello/Foreman URL (e.g., `https://katello.example.com`)
- Credentials (username and password)
- Organization ID or name
- Product ID or name (create product if needed)
- Repository details:
  - Repository name
  - Content type (docker, yum, deb, file, etc.)
  - Upstream URL
  - For Docker: `docker_upstream_name` (e.g., `organization/image`)
  - For Yum: GPG key if needed
  - Download policy (immediate, on_demand, streamed)

### Step 2: Find Organization and Product IDs

```bash
# List organizations
curl -k -u 'USERNAME:PASSWORD' \
  'https://KATELLO_URL/katello/api/v2/organizations' | python3 -m json.tool

# List products in organization
curl -k -u 'USERNAME:PASSWORD' \
  'https://KATELLO_URL/katello/api/v2/products?organization_id=ORG_ID' | python3 -m json.tool
```

### Step 3: Create Repository

**For Docker/Container Repositories:**
```bash
curl -k -u 'USERNAME:PASSWORD' -X POST \
  'https://KATELLO_URL/katello/api/v2/repositories' \
  -H 'Content-Type: application/json' \
  -d '{
    "name": "REPO_NAME",
    "product_id": PRODUCT_ID,
    "content_type": "docker",
    "url": "https://REGISTRY_URL",
    "docker_upstream_name": "namespace/image-name",
    "download_policy": "on_demand",
    "include_tags": [],
    "exclude_tags": ["*-source"]
  }'
```

**For Yum/RPM Repositories:**
```bash
curl -k -u 'USERNAME:PASSWORD' -X POST \
  'https://KATELLO_URL/katello/api/v2/repositories' \
  -H 'Content-Type: application/json' \
  -d '{
    "name": "REPO_NAME",
    "product_id": PRODUCT_ID,
    "content_type": "yum",
    "url": "https://YUM_REPO_URL",
    "download_policy": "on_demand",
    "verify_ssl_on_sync": true
  }'
```

**For Debian Repositories:**
```bash
curl -k -u 'USERNAME:PASSWORD' -X POST \
  'https://KATELLO_URL/katello/api/v2/repositories' \
  -H 'Content-Type: application/json' \
  -d '{
    "name": "REPO_NAME",
    "product_id": PRODUCT_ID,
    "content_type": "deb",
    "url": "https://DEB_REPO_URL",
    "deb_releases": "focal",
    "deb_components": "main",
    "deb_architectures": "amd64",
    "download_policy": "immediate"
  }'
```

**For Ansible Collection Repositories:**
```bash
curl -k -u 'USERNAME:PASSWORD' -X POST \
  'https://KATELLO_URL/katello/api/v2/repositories' \
  -H 'Content-Type: application/json' \
  -d '{
    "name": "REPO_NAME",
    "product_id": PRODUCT_ID,
    "content_type": "ansible_collection",
    "url": "https://galaxy.ansible.com/",
    "ansible_collection_requirements": "---\ncollections:\n  - name: namespace.collection\n    version: \">=1.0.0\"",
    "ansible_collection_auth_url": "https://sso.redhat.com/auth/realms/redhat-external/protocol/openid-connect/token",
    "ansible_collection_auth_token": "YOUR_TOKEN_HERE"
  }'
```
**Note:** Ansible Collection URLs must have a trailing slash or you'll get "URL needs to have a trailing /" error.

**For Python Package Repositories:**
```bash
curl -k -u 'USERNAME:PASSWORD' -X POST \
  'https://KATELLO_URL/katello/api/v2/repositories' \
  -H 'Content-Type: application/json' \
  -d '{
    "name": "REPO_NAME",
    "product_id": PRODUCT_ID,
    "content_type": "python",
    "url": "https://pypi.org/",
    "generic_remote_options": {
      "includes": ["django~=4.0", "requests"],
      "excludes": ["obsolete-package"],
      "keep_latest_packages": 3,
      "package_types": ["bdist_wheel", "sdist"]
    }
  }'
```

**For OSTree Repositories:**
```bash
curl -k -u 'USERNAME:PASSWORD' -X POST \
  'https://KATELLO_URL/katello/api/v2/repositories' \
  -H 'Content-Type: application/json' \
  -d '{
    "name": "REPO_NAME",
    "product_id": PRODUCT_ID,
    "content_type": "ostree",
    "url": "https://OSTREE_REPO_URL",
    "generic_remote_options": {
      "depth": 0,
      "include_refs": ["stable/*"],
      "exclude_refs": ["*/dev"]
    }
  }'
```

**For File Repositories:**
```bash
curl -k -u 'USERNAME:PASSWORD' -X POST \
  'https://KATELLO_URL/katello/api/v2/repositories' \
  -H 'Content-Type: application/json' \
  -d '{
    "name": "REPO_NAME",
    "product_id": PRODUCT_ID,
    "content_type": "file",
    "url": "https://FILE_REPO_URL",
    "download_policy": "immediate"
  }'
```

### Step 4: Sync Repository

```bash
# Initiate sync
curl -k -u 'USERNAME:PASSWORD' -X POST \
  'https://KATELLO_URL/katello/api/v2/repositories/REPO_ID/sync' \
  -H 'Content-Type: application/json'
```

**Optional sync parameters:**
- `"incremental": true` - Perform incremental sync
- `"skip_metadata_check": true` - Force sync even if no upstream changes
- `"validate_contents": true` - Validate checksums (yum only)

### Step 5: Verify Sync Status

```bash
# Check repository details and sync status
curl -k -u 'USERNAME:PASSWORD' \
  'https://KATELLO_URL/katello/api/v2/repositories/REPO_ID' | python3 -m json.tool

# Check specific fields
curl -k -u 'USERNAME:PASSWORD' \
  'https://KATELLO_URL/katello/api/v2/repositories/REPO_ID' 2>/dev/null \
  | python3 -m json.tool | grep -E '"last_sync"|"content_counts"' -A 10
```

### Step 6: Verify Content (Via API)

**For Docker repositories:**
```bash
# List docker tags
curl -k -u 'USERNAME:PASSWORD' \
  'https://KATELLO_URL/katello/api/v2/docker_tags?repository_id=REPO_ID&per_page=100'

# Get count
curl -k -u 'USERNAME:PASSWORD' \
  'https://KATELLO_URL/katello/api/v2/docker_tags?repository_id=REPO_ID' 2>/dev/null \
  | python3 -c "import json,sys; print(f\"Total tags: {json.load(sys.stdin)['total']}\")"
```

**For Yum repositories:**
```bash
# List packages
curl -k -u 'USERNAME:PASSWORD' \
  'https://KATELLO_URL/katello/api/v2/packages?repository_id=REPO_ID&per_page=100'

# Get package count
curl -k -u 'USERNAME:PASSWORD' \
  'https://KATELLO_URL/katello/api/v2/repositories/REPO_ID' 2>/dev/null \
  | python3 -c "import json,sys; data=json.load(sys.stdin); print(f\"RPMs: {data['content_counts']['rpm']}, Errata: {data['content_counts']['erratum']}\")"
```

**For Debian repositories:**
```bash
# List debs
curl -k -u 'USERNAME:PASSWORD' \
  'https://KATELLO_URL/katello/api/v2/debs?repository_id=REPO_ID&per_page=100'
```

**For Ansible Collection repositories:**
```bash
# List ansible collections
curl -k -u 'USERNAME:PASSWORD' \
  'https://KATELLO_URL/katello/api/v2/ansible_collections?repository_id=REPO_ID&per_page=100'
```

**For Python repositories:**
```bash
# List python packages
curl -k -u 'USERNAME:PASSWORD' \
  'https://KATELLO_URL/katello/api/v2/python_packages?repository_id=REPO_ID&per_page=100'
```

**For File repositories:**
```bash
# List files
curl -k -u 'USERNAME:PASSWORD' \
  'https://KATELLO_URL/katello/api/v2/files?repository_id=REPO_ID&per_page=100'
```

### Step 7: Advanced Database Verification (Optional - Requires Postgres MCP)

If you have the postgres MCP server configured, you can verify data relationships directly:

```sql
-- Example: Check Docker manifest list relationships
SELECT
    dt.id as tag_id,
    dt.name as tag_name,
    dml.id as manifest_list_id,
    dm.id as child_manifest_id,
    dm.digest as child_digest
FROM katello_docker_tags dt
LEFT JOIN katello_docker_manifest_lists dml
    ON dt.docker_taggable_id = dml.id
    AND dt.docker_taggable_type = 'Katello::DockerManifestList'
LEFT JOIN katello_docker_manifest_list_manifests dmlm
    ON dml.id = dmlm.docker_manifest_list_id
LEFT JOIN katello_docker_manifests dm
    ON dmlm.docker_manifest_id = dm.id
WHERE dt.id = DOCKER_TAG_ID
ORDER BY dm.id;
```

**Note:** This step is completely optional and only useful for deep debugging of data relationships. The API verification in Step 6 is sufficient for normal use.

## API Endpoints Reference

- **Organizations**: `GET /katello/api/v2/organizations`
- **Products**: `GET /katello/api/v2/products?organization_id=:id`
- **Create Repository**: `POST /katello/api/v2/repositories`
- **Sync Repository**: `POST /katello/api/v2/repositories/:id/sync`
- **Repository Details**: `GET /katello/api/v2/repositories/:id`
- **Repository Types**: `GET /katello/api/v2/repositories/repository_types`

## Content Types

All supported content types for repositories:

### docker - Container Images
- **Content**: Docker/OCI container images, manifests, manifest lists, tags, blobs
- **Key Parameters**:
  - `docker_upstream_name`: Upstream repository path (e.g., "namespace/image")
  - `include_tags`: Array of tags to sync (wildcards supported)
  - `exclude_tags`: Array of tags to exclude (default: `["*-source"]`)
- **Example URL**: `https://quay.io`, `https://registry.redhat.io`

### yum - RPM Packages
- **Content**: RPM packages, SRPMs, errata, modulemd, package groups
- **Key Parameters**:
  - `gpg_key_id`: GPG key for package verification
  - `download_policy`: immediate, on_demand, streamed
  - `verify_ssl_on_sync`: SSL verification toggle
- **Example URL**: `https://cdn.redhat.com/content/...`, custom yum repos

### deb - Debian Packages
- **Content**: Debian/Ubuntu packages
- **Key Parameters**:
  - `deb_releases`: Whitespace-separated list of releases (e.g., "focal jammy")
  - `deb_components`: Whitespace-separated components (e.g., "main contrib")
  - `deb_architectures`: Whitespace-separated architectures (e.g., "amd64 arm64")
- **Example URL**: `http://archive.ubuntu.com/ubuntu/`

### ansible_collection - Ansible Collections
- **Content**: Ansible collections and roles
- **Key Parameters**:
  - `ansible_collection_requirements`: YAML requirements file content
  - `ansible_collection_auth_url`: Authentication endpoint (for Automation Hub)
  - `ansible_collection_auth_token`: Bearer token for authentication
- **Example URL**: `https://galaxy.ansible.com`, `https://console.redhat.com/api/automation-hub/`

### python - Python Packages
- **Content**: Python packages from PyPI-compatible repositories
- **Key Parameters (via generic_remote_options)**:
  - `includes`: Array of package specs to sync (e.g., `["django~=4.0", "requests"]`)
  - `excludes`: Array of package specs to exclude
  - `keep_latest_packages`: Number of latest versions to keep (0 = all)
  - `package_types`: Array of distribution types (`["bdist_wheel", "sdist", "bdist_egg"]`)
- **Example URL**: `https://pypi.org`

### ostree - OSTree Repositories
- **Content**: OSTree commits and refs for atomic updates
- **Key Parameters (via generic_remote_options)**:
  - `depth`: Number of commits to traverse (0 = all)
  - `include_refs`: Array of refs to include (wildcards: `*`, `?`)
  - `exclude_refs`: Array of refs to exclude (evaluated after include_refs)
- **Example URL**: OSTree repository URLs
- **Import Parameters**:
  - `ostree_ref`: Branch reference to the last commit
  - `ostree_repository_name`: Repository name in the archive (required for import)

### file - Generic Files
- **Content**: Arbitrary files and ISO images
- **Key Parameters**:
  - `download_policy`: immediate, on_demand
  - Standard authentication and SSL parameters
- **Example URL**: Any HTTP/HTTPS file repository

## Download Policies

- `immediate` - Download all content during sync
- `on_demand` - Download content when requested by clients
- `streamed` - Stream content from upstream (not cached locally)

## Tips & Best Practices

### General
1. **Check API docs**: If unsure about parameters, use WebFetch to check the API documentation at `https://KATELLO_URL/apidoc/v2/repositories/create.html`

2. **Use meaningful names**: Repository names should be descriptive and unique within the product

3. **On-demand for large repos**: Use `download_policy: "on_demand"` for large repositories to save disk space

4. **Verify SSL**: Set `verify_ssl_on_sync: false` only for testing/development environments

5. **Database verification** (Optional): If postgres MCP is available, use it to verify data relationships and content counts. Otherwise, use the API to verify:
   ```bash
   # Verify repository details via API
   curl -k -u 'admin:changeme' \
     'https://KATELLO_URL/katello/api/v2/repositories/REPO_ID' \
     | python3 -m json.tool | grep -E 'content_counts|last_sync'
   ```

6. **Testing**: Use small test repositories from `https://fixtures.pulpproject.org/` for fast testing and development

### Content Type-Specific

**Docker:**
- Exclude unwanted tags: Use `exclude_tags: ["*-source", "*-debug"]` to skip source/debug images
- Use `on_demand` download policy to save space (images downloaded when pulled by clients)
- Format `docker_upstream_name` as `namespace/repository` (e.g., `quay/busybox`, `redhat/ubi9`)

**Yum:**
- Use GPG keys for package verification in production
- Consider `skip_metadata_check: false` for initial syncs
- Use `validate_contents: true` to verify checksums if encountering corruption

**Debian:**
- Specify releases explicitly (e.g., `"focal jammy"` for Ubuntu 20.04 and 22.04)
- Use spaces to separate multiple values in `deb_releases`, `deb_components`, `deb_architectures`
- Common components: `main`, `contrib`, `non-free`, `universe`, `multiverse`

**Ansible Collections:**
- **IMPORTANT**: URL must have trailing slash (e.g., `https://galaxy.ansible.com/` not `https://galaxy.ansible.com`)
- Use YAML format for `ansible_collection_requirements`
- For Red Hat Automation Hub, auth_url: `https://sso.redhat.com/auth/realms/redhat-external/protocol/openid-connect/token`
- Leave auth fields empty for public Galaxy collections
- Example requirements: `"---\ncollections:\n  - name: community.general\n    version: \">=1.0.0\""`

**Python:**
- Use version specifiers in includes: `"django~=4.0"`, `"requests>=2.28.0"`
- Set `keep_latest_packages` to limit versions (useful for CI/CD pipelines)
- Available package types: `bdist_dmg`, `bdist_dumb`, `bdist_egg`, `bdist_msi`, `bdist_rpm`, `bdist_wheel`, `bdist_wininst`, `sdist`
- Leave `includes` empty to sync all packages (use with caution)

**OSTree:**
- Set `depth: 0` to traverse all commits (default)
- Use wildcards in refs: `"stable/*"`, `"rhel/9/*/edge"`
- `exclude_refs` evaluated after `include_refs` for filtering

**File:**
- Useful for ISOs, firmware updates, and custom file distributions
- Supports direct file uploads in addition to sync

## Example: Complete Workflow

### Creating a Single Docker Repository
```bash
# 1. Find organization
ORG_ID=$(curl -k -u 'admin:changeme' \
  'https://katello.example.com/katello/api/v2/organizations' 2>/dev/null \
  | python3 -c "import json,sys; print(json.load(sys.stdin)['results'][0]['id'])")

# 2. Find or create product
PRODUCT_ID=$(curl -k -u 'admin:changeme' \
  "https://katello.example.com/katello/api/v2/products?organization_id=$ORG_ID" 2>/dev/null \
  | python3 -c "import json,sys; print([p['id'] for p in json.load(sys.stdin)['results'] if p['name']=='My Product'][0])")

# 3. Create repository
REPO_ID=$(curl -k -u 'admin:changeme' -X POST \
  'https://katello.example.com/katello/api/v2/repositories' \
  -H 'Content-Type: application/json' \
  -d '{
    "name": "nginx",
    "product_id": '$PRODUCT_ID',
    "content_type": "docker",
    "url": "https://quay.io",
    "docker_upstream_name": "nginx/nginx"
  }' 2>/dev/null | python3 -c "import json,sys; print(json.load(sys.stdin)['id'])")

# 4. Sync repository
curl -k -u 'admin:changeme' -X POST \
  "https://katello.example.com/katello/api/v2/repositories/$REPO_ID/sync"

# 5. Wait and check status
sleep 30
curl -k -u 'admin:changeme' \
  "https://katello.example.com/katello/api/v2/repositories/$REPO_ID" \
  | python3 -m json.tool | grep -E '"last_sync"|"content_counts"' -A 5
```

### Creating All Repository Types (Tested and Working)
```bash
# 1. Create product
PRODUCT_ID=$(curl -k -u 'admin:changeme' -X POST \
  'https://katello.example.com/katello/api/v2/products' \
  -H 'Content-Type: application/json' \
  -d '{"organization_id": 1, "name": "Test Content Types"}' 2>/dev/null \
  | python3 -c "import json,sys; print(json.load(sys.stdin)['id'])")

# 2. Create Docker repository
curl -k -u 'admin:changeme' -X POST \
  'https://katello.example.com/katello/api/v2/repositories' \
  -H 'Content-Type: application/json' \
  -d '{
    "name": "test-docker",
    "product_id": '$PRODUCT_ID',
    "content_type": "docker",
    "url": "https://quay.io",
    "docker_upstream_name": "quay/busybox",
    "download_policy": "on_demand"
  }' 2>/dev/null

# 3. Create Yum repository
curl -k -u 'admin:changeme' -X POST \
  'https://katello.example.com/katello/api/v2/repositories' \
  -H 'Content-Type: application/json' \
  -d '{
    "name": "test-yum",
    "product_id": '$PRODUCT_ID',
    "content_type": "yum",
    "url": "https://dl.fedoraproject.org/pub/epel/9/Everything/x86_64/",
    "download_policy": "on_demand"
  }' 2>/dev/null

# 4. Create Debian repository
curl -k -u 'admin:changeme' -X POST \
  'https://katello.example.com/katello/api/v2/repositories' \
  -H 'Content-Type: application/json' \
  -d '{
    "name": "test-deb",
    "product_id": '$PRODUCT_ID',
    "content_type": "deb",
    "url": "http://archive.ubuntu.com/ubuntu/",
    "deb_releases": "focal",
    "deb_components": "main",
    "deb_architectures": "amd64",
    "download_policy": "on_demand"
  }' 2>/dev/null

# 5. Create Ansible Collection repository
curl -k -u 'admin:changeme' -X POST \
  'https://katello.example.com/katello/api/v2/repositories' \
  -H 'Content-Type: application/json' \
  -d '{
    "name": "test-ansible",
    "product_id": '$PRODUCT_ID',
    "content_type": "ansible_collection",
    "url": "https://galaxy.ansible.com/",
    "ansible_collection_requirements": "---\ncollections:\n  - name: community.general\n    version: \">=1.0.0\""
  }' 2>/dev/null

# 6. Create Python repository
curl -k -u 'admin:changeme' -X POST \
  'https://katello.example.com/katello/api/v2/repositories' \
  -H 'Content-Type: application/json' \
  -d '{
    "name": "test-python",
    "product_id": '$PRODUCT_ID',
    "content_type": "python",
    "url": "https://pypi.org/",
    "generic_remote_options": {
      "includes": ["requests"],
      "keep_latest_packages": 2
    }
  }' 2>/dev/null

# 7. Create File repository
curl -k -u 'admin:changeme' -X POST \
  'https://katello.example.com/katello/api/v2/repositories' \
  -H 'Content-Type: application/json' \
  -d '{
    "name": "test-file",
    "product_id": '$PRODUCT_ID',
    "content_type": "file",
    "url": "https://releases.ansible.com/ansible-tower/setup/",
    "download_policy": "immediate"
  }' 2>/dev/null

# 8. Create OSTree repository
curl -k -u 'admin:changeme' -X POST \
  'https://katello.example.com/katello/api/v2/repositories' \
  -H 'Content-Type: application/json' \
  -d '{
    "name": "test-ostree",
    "product_id": '$PRODUCT_ID',
    "content_type": "ostree",
    "url": "https://ostree.fedoraproject.org/",
    "generic_remote_options": {
      "depth": 1,
      "include_refs": ["fedora/stable/*"]
    }
  }' 2>/dev/null

# 9. Verify all repositories created
curl -k -u 'admin:changeme' \
  "https://katello.example.com/katello/api/v2/repositories?product_id=$PRODUCT_ID" 2>/dev/null \
  | python3 -c "
import json, sys
data = json.load(sys.stdin)
print(f'Total Repositories: {data[\"total\"]}\n')
for repo in data['results']:
    print(f\"✓ {repo['name']:20} | Type: {repo['content_type']:20} | ID: {repo['id']}\")"
```

## Troubleshooting

### General Issues

**Repository name already exists:**
- Choose a different name or check if the repository already exists
- Query: `GET /katello/api/v2/repositories?name=REPO_NAME&product_id=PRODUCT_ID`

**Authentication failed:**
- Verify username and password
- Check if the user has required permissions (`Katello::Product` permissions)
- Verify the user is a member of the organization

**Sync fails:**
- Check `last_sync.result` for error details
- Verify upstream URL is accessible from Katello/Foreman server
- Check network connectivity and firewall rules
- Review `/var/log/foreman/production.log` and Pulp logs

**No content synced:**
- Check if upstream repository is empty
- Review sync task output for warnings
- Verify content filters aren't excluding all content

### Content Type-Specific Issues

**Docker:**
- **Error: "manifest unknown"**: Ensure `docker_upstream_name` format is `namespace/image` (not full URL)
- **No tags synced**: Check tag filters; verify tags exist matching `include_tags` patterns
- **Auth failures**: For private registries, set `upstream_username` and `upstream_password`
- **Format error**: Don't include registry URL in `docker_upstream_name` (use separate `url` field)

**Yum:**
- **GPG check failed**: Verify `gpg_key_id` matches repository's signing key
- **Metadata errors**: Try `skip_metadata_check: true` for problematic repos
- **Checksum failures**: Use `validate_contents: true` to identify corrupt packages
- **Modular dependency errors**: Ensure modulemd metadata is synced

**Debian:**
- **No packages found**: Verify `deb_releases`, `deb_components`, and `deb_architectures` match upstream
- **Release not found**: Check exact release codename (e.g., "focal" not "20.04")
- **InRelease verification failed**: Check `verify_ssl_on_sync` or GPG key configuration
- **Multiple values not recognized**: Ensure whitespace (not comma) separation

**Ansible Collections:**
- **"URL needs to have a trailing /"**: Add trailing slash to URL (e.g., `https://galaxy.ansible.com/`)
- **Requirements parse error**: Validate YAML syntax in `ansible_collection_requirements`
- **Collection not found**: Verify collection namespace and name exist on Galaxy/Hub
- **Auth token expired**: Refresh `ansible_collection_auth_token`
- **Version conflict**: Check version specifiers in requirements (use quotes: `">=1.0.0"`)

**Python:**
- **Package not found**: Verify package name and version exist on PyPI/upstream
- **Version parsing error**: Use correct version specifiers (`~=`, `>=`, `==`, `!=`)
- **Too many packages**: Set `keep_latest_packages` or use more specific `includes`
- **Package type not found**: Verify `package_types` match available distributions (use `bdist_wheel` and `sdist` for most packages)

**OSTree:**
- **Ref not found**: Verify ref names match upstream branches
- **Depth too shallow**: Increase `depth` value or set to 0 for all commits
- **Import fails**: Ensure `ostree_repository_name` matches repository name in archive
- **Wildcard not matching**: Check ref pattern syntax (`*` for any chars, `?` for single char)

**File:**
- **Download fails**: Verify URL points to actual files, not directory listings
- **Wrong content type**: Ensure upstream serves correct MIME types
- **Upload fails**: Check file size limits and available disk space

## Related Skills

This skill works well with:
- **Database verification** using postgres MCP (optional, for advanced debugging)
- **API documentation lookup** using WebFetch for parameter reference
- **Testing content availability** via API endpoints
