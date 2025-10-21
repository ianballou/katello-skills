#!/bin/bash
# shopt -s expand_aliases
# set -e
# set -x

# Complete Katello Setup Script
# Creates: Unique Org -> Product -> 2 Pulp repos (fast) -> Sync -> Content View -> Dev Environment -> Promote -> Activation Key

set -euo pipefail

# Configuration
FOREMAN_URL="${FOREMAN_URL:-${SATELLITE_URL:-}}"  # Support both variable names for compatibility
FOREMAN_USERNAME="${FOREMAN_USERNAME:-${SATELLITE_USERNAME:-}}"
FOREMAN_PASSWORD="${FOREMAN_PASSWORD:-${SATELLITE_PASSWORD:-}}"

# Entity names - Generate unique names for each run
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
ORG_NAME="test-org-${TIMESTAMP}"
PRODUCT_NAME="test-product-${TIMESTAMP}"
YUM_REPO_NAME="pulp-zoo"
FILE_REPO_NAME="pulp-file-large"
CONTENT_VIEW_NAME="test-cv-${TIMESTAMP}"
DEV_ENV_NAME="Development"
ACTIVATION_KEY_NAME="test-ak-${TIMESTAMP}"

# API URLs
BASE_URL="${FOREMAN_URL}/api/v2"
KATELLO_URL="${FOREMAN_URL}/katello/api/v2"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() { echo -e "${BLUE}[INFO]${NC} $1" >&2; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1" >&2; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1" >&2; }
print_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }

# Check prerequisites
check_prerequisites() {
    print_info "Checking prerequisites..."

    if ! command -v curl &> /dev/null; then
        print_error "curl is required but not installed"
        exit 1
    fi

    if ! command -v python3 &> /dev/null; then
        print_error "python3 is required but not installed"
        exit 1
    fi

    print_success "Prerequisites check completed"
}

# Get credentials
get_credentials() {
    if [[ -z "$FOREMAN_URL" ]]; then
        read -p "Enter Foreman URL (e.g., https://foreman.example.com): " FOREMAN_URL
    fi

    if [[ -z "$FOREMAN_USERNAME" ]]; then
        read -p "Enter Foreman username: " FOREMAN_USERNAME
    fi

    if [[ -z "$FOREMAN_PASSWORD" ]]; then
        read -s -p "Enter Foreman password: " FOREMAN_PASSWORD
        echo
    fi

    # Test connectivity
    print_info "Testing connectivity to $FOREMAN_URL..."
    if curl -k -s --connect-timeout 10 "$FOREMAN_URL" > /dev/null; then
        print_success "Successfully connected to Foreman server"
    else
        print_error "Failed to connect to Foreman server"
        exit 1
    fi
}

# URL encoding helper function
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

# API call wrapper with error handling
api_call() {
    local method="$1"
    local url="$2"
    local data="$3"
    local description="$4"

    print_info "$description"

    local response
    if [[ -n "$data" ]]; then
        response=$(curl -k -s -u "${FOREMAN_USERNAME}:${FOREMAN_PASSWORD}" \
            -H "Content-Type: application/json" \
            -X "$method" "$url" -d "$data" 2>/dev/null)
    else
        response=$(curl -k -s -u "${FOREMAN_USERNAME}:${FOREMAN_PASSWORD}" \
            -H "Content-Type: application/json" \
            -X "$method" "$url" 2>/dev/null)
    fi

    # Check for actual errors (not just the presence of error fields)
    local has_errors=$(echo "$response" | python3 -c "
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

    if [[ "$has_errors" != "NO_ERROR" ]]; then
        print_error "$description failed: $has_errors"
        echo "Response: $response" >&2
        return 1
    fi

    # Return only the response, not mixed with log messages
    echo "$response"
}

# Wait for task completion
wait_for_task() {
    local task_id="$1"
    local description="$2"

    print_info "Monitoring task: $description"

    while true; do
        local status=$(curl -k -s -u "${FOREMAN_USERNAME}:${FOREMAN_PASSWORD}" \
            "${BASE_URL}/tasks/${task_id}" 2>/dev/null | \
            python3 -c "
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
                print_success "$description completed successfully"
                break
                ;;
            "error"|"failed")
                print_error "$description failed"
                return 1
                ;;
            "unknown")
                print_warning "Unable to check task status"
                break
                ;;
            *)
                sleep 5
                ;;
        esac
    done
}

# Wait for all pending tasks in repositories
wait_for_pending_tasks() {
    local content_view_id="$1"

    print_info "Checking for pending tasks in content view repositories..."

    # Get repositories in the content view
    local repos_response=$(curl -k -s -u "${FOREMAN_USERNAME}:${FOREMAN_PASSWORD}" \
        "${KATELLO_URL}/content_views/${content_view_id}/repositories" 2>/dev/null)

    local repo_ids=$(echo "$repos_response" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    repo_ids = [str(repo['id']) for repo in data.get('results', [])]
    if repo_ids:
        print(','.join(repo_ids))
    else:
        print('')
except:
    print('')
")

    if [[ -z "$repo_ids" ]]; then
        print_info "No repositories found in content view"
        return 0
    fi

    print_info "Found repositories: $repo_ids"
    print_info "Waiting for any pending tasks to complete..."

    # Wait for running tasks to complete (up to 10 minutes)
    local max_wait=600  # 10 minutes
    local wait_time=0

    while [[ $wait_time -lt $max_wait ]]; do
        local running_tasks=$(curl -k -s -u "${FOREMAN_USERNAME}:${FOREMAN_PASSWORD}" \
            "${BASE_URL}/tasks?search=state=running" 2>/dev/null | \
            python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    print(data.get('total', 0))
except:
    print('0')
")

        if [[ "$running_tasks" == "0" ]]; then
            print_success "All pending tasks completed"
            return 0
        fi

        print_info "Still $running_tasks running tasks. Waiting..."
        sleep 10
        wait_time=$((wait_time + 10))
    done

    print_warning "Timeout waiting for tasks to complete. Attempting to proceed..."
    return 0
}

# Step 1: Create organization
create_organization() {
    print_info "Step 1: Creating unique organization '$ORG_NAME'"

    # Create organization (unique name guaranteed by timestamp)
    local response=$(api_call "POST" "${KATELLO_URL}/organizations" \
        "{\"name\": \"${ORG_NAME}\", \"description\": \"Test organization created by automation script - ${TIMESTAMP}\"}" \
        "Creating organization '$ORG_NAME'")

    ORG_ID=$(echo "$response" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    org_id = data.get('id', '')
    if org_id:
        print(org_id)
    else:
        print('NO_ID_FOUND')
except Exception as e:
    print('JSON_PARSE_ERROR')
")

    if [[ -z "$ORG_ID" || "$ORG_ID" == "NO_ID_FOUND" || "$ORG_ID" == "JSON_PARSE_ERROR" ]]; then
        print_error "Failed to create organization. ORG_ID='$ORG_ID'"
        print_error "API Response: $response"
        exit 1
    fi

    print_success "Created organization '$ORG_NAME' with ID: $ORG_ID"
}

# Step 2: Create product
create_product() {
    print_info "Step 2: Creating product '$PRODUCT_NAME' in organization '$ORG_NAME'"

    # Check if product already exists
    local search_param=$(printf 'name="%s"' "$PRODUCT_NAME")
    local existing_product=$(curl -k -s -u "${FOREMAN_USERNAME}:${FOREMAN_PASSWORD}" \
        "${KATELLO_URL}/products" --data-urlencode "organization_id=${ORG_ID}" --data-urlencode "search=${search_param}" -G 2>/dev/null | \
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
" 2>/dev/null || echo "")

    if [[ -n "$existing_product" ]]; then
        PRODUCT_ID="$existing_product"
        print_warning "Product '$PRODUCT_NAME' already exists with ID: $PRODUCT_ID"
    else
        local response=$(api_call "POST" "${KATELLO_URL}/products" \
            "{\"name\": \"${PRODUCT_NAME}\", \"organization_id\": ${ORG_ID}, \"description\": \"Product created by automation script\"}" \
            "Creating product '$PRODUCT_NAME'")

        PRODUCT_ID=$(echo "$response" | python3 -c "
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

        if [[ -z "$PRODUCT_ID" || "$PRODUCT_ID" == "NO_ID_FOUND" || "$PRODUCT_ID" == "JSON_PARSE_ERROR" ]]; then
            print_error "Failed to create product. PRODUCT_ID='$PRODUCT_ID'"
            print_error "API Response: $response"
            exit 1
        fi

        print_success "Created product '$PRODUCT_NAME' with ID: $PRODUCT_ID"
    fi
}

# Step 3: Create yum repository
create_yum_repository() {
    print_info "Step 3: Creating Pulp Zoo yum repository '$YUM_REPO_NAME' (fast sync)"

    local response=$(api_call "POST" "${KATELLO_URL}/repositories" \
        "{
            \"name\": \"${YUM_REPO_NAME}\",
            \"product_id\": ${PRODUCT_ID},
            \"content_type\": \"yum\",
            \"url\": \"https://fixtures.pulpproject.org/rpm-unsigned/\",
            \"download_policy\": \"immediate\",
            \"verify_ssl_on_sync\": true,
            \"description\": \"Pulp Zoo RPM repository for fast testing\"
        }" \
        "Creating yum repository '$YUM_REPO_NAME'")

    YUM_REPO_ID=$(echo "$response" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    print(data['id'])
except:
    print('')
" 2>/dev/null || echo "")

    if [[ -z "$YUM_REPO_ID" ]]; then
        print_error "Failed to create yum repository"
        exit 1
    fi

    print_success "Created yum repository '$YUM_REPO_NAME' with ID: $YUM_REPO_ID"
}

# Step 4: Create file repository
create_file_repository() {
    print_info "Step 4: Creating Pulp file repository '$FILE_REPO_NAME' (fast sync)"

    local response=$(api_call "POST" "${KATELLO_URL}/repositories" \
        "{
            \"name\": \"${FILE_REPO_NAME}\",
            \"product_id\": ${PRODUCT_ID},
            \"content_type\": \"file\",
            \"url\": \"https://fixtures.pulpproject.org/file-large/\",
            \"download_policy\": \"immediate\",
            \"verify_ssl_on_sync\": true,
            \"description\": \"Pulp file repository for fast testing\"
        }" \
        "Creating file repository '$FILE_REPO_NAME'")

    FILE_REPO_ID=$(echo "$response" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    print(data['id'])
except:
    print('')
" 2>/dev/null || echo "")

    if [[ -z "$FILE_REPO_ID" ]]; then
        print_error "Failed to create file repository"
        exit 1
    fi

    print_success "Created file repository '$FILE_REPO_NAME' with ID: $FILE_REPO_ID"
}

# Step 5: Sync yum repository
sync_yum_repository() {
    print_info "Step 5: Syncing yum repository '$YUM_REPO_NAME'"

    local response=$(api_call "POST" "${KATELLO_URL}/repositories/${YUM_REPO_ID}/sync" \
        "{}" \
        "Initiating sync for yum repository '$YUM_REPO_NAME'")

    local task_id=$(echo "$response" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    print(data.get('id', ''))
except:
    print('')
" 2>/dev/null || echo "")

    if [[ -n "$task_id" ]]; then
        wait_for_task "$task_id" "Yum repository sync"
    fi

    print_success "Yum repository '$YUM_REPO_NAME' synchronized"
}

# Step 6: Sync file repository
sync_file_repository() {
    print_info "Step 6: Syncing file repository '$FILE_REPO_NAME'"

    local response=$(api_call "POST" "${KATELLO_URL}/repositories/${FILE_REPO_ID}/sync" \
        "{}" \
        "Initiating sync for file repository '$FILE_REPO_NAME'")

    local task_id=$(echo "$response" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    print(data.get('id', ''))
except:
    print('')
" 2>/dev/null || echo "")

    if [[ -n "$task_id" ]]; then
        wait_for_task "$task_id" "File repository sync"
    fi

    print_success "File repository '$FILE_REPO_NAME' synchronized"
}

# Step 7: Create content view and add repositories
create_content_view() {
    print_info "Step 7: Creating content view '$CONTENT_VIEW_NAME' and adding repositories"

    # Create content view
    local response=$(api_call "POST" "${KATELLO_URL}/content_views" \
        "{
            \"name\": \"${CONTENT_VIEW_NAME}\",
            \"organization_id\": ${ORG_ID},
            \"description\": \"Content view created by automation script\"
        }" \
        "Creating content view '$CONTENT_VIEW_NAME'")

    CONTENT_VIEW_ID=$(echo "$response" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    print(data['id'])
except:
    print('')
" 2>/dev/null || echo "")

    if [[ -z "$CONTENT_VIEW_ID" ]]; then
        print_error "Failed to create content view"
        exit 1
    fi

    print_success "Created content view '$CONTENT_VIEW_NAME' with ID: $CONTENT_VIEW_ID"

    # Add repositories to content view
    api_call "PUT" "${KATELLO_URL}/content_views/${CONTENT_VIEW_ID}" \
        "{\"repository_ids\": [${YUM_REPO_ID}, ${FILE_REPO_ID}]}" \
        "Adding repositories to content view"

    print_success "Added repositories to content view '$CONTENT_VIEW_NAME'"
}

# Step 8: Publish content view
publish_content_view() {
    print_info "Step 8: Publishing content view '$CONTENT_VIEW_NAME'"

    # First, wait for any pending tasks
    wait_for_pending_tasks "$CONTENT_VIEW_ID"

    # Attempt to publish
    local response
    local max_attempts=3
    local attempt=1

    while [[ $attempt -le $max_attempts ]]; do
        print_info "Publishing attempt $attempt of $max_attempts..."

        response=$(curl -k -s -u "${FOREMAN_USERNAME}:${FOREMAN_PASSWORD}" \
            -H "Content-Type: application/json" \
            -X POST "${KATELLO_URL}/content_views/${CONTENT_VIEW_ID}/publish" \
            -d '{"description": "Initial publication by automation script"}' 2>/dev/null)

        # Check for errors using the same logic as api_call
        local has_errors=$(echo "$response" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)

    # Check for pending tasks specifically
    if 'displayMessage' in data and 'pending tasks detected' in str(data['displayMessage']).lower():
        print('PENDING_TASKS')
        sys.exit(1)

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

    # No actual errors found
    print('NO_ERROR')

except Exception as e:
    print('Failed to parse response')
    sys.exit(1)
")

        if [[ "$has_errors" == "PENDING_TASKS" ]]; then
            print_warning "Pending tasks detected, waiting 30 seconds..."
            sleep 30
            attempt=$((attempt + 1))
            continue
        elif [[ "$has_errors" != "NO_ERROR" ]]; then
            print_error "Publishing failed: $has_errors"
            if [[ $attempt -eq $max_attempts ]]; then
                exit 1
            fi
            attempt=$((attempt + 1))
            sleep 10
            continue
        fi

        # Success - break out of retry loop
        break
    done

    local task_id=$(echo "$response" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    print(data.get('id', ''))
except:
    print('')
" 2>/dev/null || echo "")

    if [[ -n "$task_id" ]]; then
        wait_for_task "$task_id" "Content view publication"
    fi

    # Get the content view version ID
    sleep 5  # Wait a moment for the publication to complete
    CV_VERSION_ID=$(curl -k -s -u "${FOREMAN_USERNAME}:${FOREMAN_PASSWORD}" \
        "${KATELLO_URL}/content_views/${CONTENT_VIEW_ID}/content_view_versions" 2>/dev/null | \
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
" 2>/dev/null || echo "")

    if [[ -z "$CV_VERSION_ID" ]]; then
        print_error "Failed to get content view version ID"
        exit 1
    fi

    print_success "Published content view '$CONTENT_VIEW_NAME' - Version ID: $CV_VERSION_ID"
}

# Step 9: Create Dev lifecycle environment
create_dev_environment() {
    print_info "Step 9: Creating Dev lifecycle environment '$DEV_ENV_NAME'"

    # Get Library environment ID (parent for Dev)
    LIBRARY_ENV_ID=$(curl -k -s -u "${FOREMAN_USERNAME}:${FOREMAN_PASSWORD}" \
        "${KATELLO_URL}/environments" --data-urlencode "organization_id=${ORG_ID}" --data-urlencode "name=Library" -G 2>/dev/null | \
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
" 2>/dev/null || echo "")

    if [[ -z "$LIBRARY_ENV_ID" ]]; then
        print_error "Failed to find Library environment"
        exit 1
    fi

    # Check if Dev environment already exists
    local search_param=$(printf 'name="%s"' "$DEV_ENV_NAME")
    local existing_dev_env=$(curl -k -s -u "${FOREMAN_USERNAME}:${FOREMAN_PASSWORD}" \
        "${KATELLO_URL}/environments" --data-urlencode "organization_id=${ORG_ID}" --data-urlencode "search=${search_param}" -G 2>/dev/null | \
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
" 2>/dev/null || echo "")

    if [[ -n "$existing_dev_env" ]]; then
        DEV_ENV_ID="$existing_dev_env"
        print_warning "Dev environment '$DEV_ENV_NAME' already exists with ID: $DEV_ENV_ID"
    else
        local response=$(api_call "POST" "${KATELLO_URL}/environments" \
            "{
                \"name\": \"${DEV_ENV_NAME}\",
                \"organization_id\": ${ORG_ID},
                \"prior_id\": ${LIBRARY_ENV_ID},
                \"description\": \"Development environment created by automation script\"
            }" \
            "Creating Dev environment '$DEV_ENV_NAME'")

        DEV_ENV_ID=$(echo "$response" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    print(data['id'])
except:
    print('')
" 2>/dev/null || echo "")

        if [[ -z "$DEV_ENV_ID" ]]; then
            print_error "Failed to create Dev environment"
            exit 1
        fi

        print_success "Created Dev environment '$DEV_ENV_NAME' with ID: $DEV_ENV_ID"
    fi
}

# Step 10: Promote content view to Dev environment
promote_content_view() {
    print_info "Step 10: Promoting content view to Dev environment"

    local response=$(api_call "POST" "${KATELLO_URL}/content_view_versions/${CV_VERSION_ID}/promote" \
        "{\"environment_ids\": [${DEV_ENV_ID}]}" \
        "Promoting content view to Dev environment")

    local task_id=$(echo "$response" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    print(data.get('id', ''))
except:
    print('')
" 2>/dev/null || echo "")

    if [[ -n "$task_id" ]]; then
        wait_for_task "$task_id" "Content view promotion"
    fi

    print_success "Promoted content view '$CONTENT_VIEW_NAME' to Dev environment '$DEV_ENV_NAME'"
}

# Step 11: Create activation key
create_activation_key() {
    print_info "Step 11: Creating activation key '$ACTIVATION_KEY_NAME' with default organization view"

    # Get Library environment ID (where default_organization_view is available)
    LIBRARY_ENV_ID=$(curl -k -s -u "${FOREMAN_USERNAME}:${FOREMAN_PASSWORD}" \
        "${KATELLO_URL}/environments" --data-urlencode "organization_id=${ORG_ID}" --data-urlencode "name=Library" -G 2>/dev/null | \
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
" 2>/dev/null || echo "")

    if [[ -z "$LIBRARY_ENV_ID" ]]; then
        print_error "Failed to find Library environment"
        exit 1
    fi

    # Get the default organization view ID
    DEFAULT_CV_ID=$(curl -k -s -u "${FOREMAN_USERNAME}:${FOREMAN_PASSWORD}" \
        "${KATELLO_URL}/content_views" --data-urlencode "organization_id=${ORG_ID}" --data-urlencode "name=Default Organization View" -G 2>/dev/null | \
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
" 2>/dev/null || echo "")

    if [[ -z "$DEFAULT_CV_ID" ]]; then
        print_error "Failed to find Default Organization View"
        exit 1
    fi

    print_info "Found Default Organization View with ID: $DEFAULT_CV_ID"

    # Create activation key pointing to default_organization_view in Library environment
    local response=$(api_call "POST" "${KATELLO_URL}/activation_keys" \
        "{
            \"name\": \"${ACTIVATION_KEY_NAME}\",
            \"organization_id\": ${ORG_ID},
            \"environment_id\": ${LIBRARY_ENV_ID},
            \"content_view_id\": ${DEFAULT_CV_ID},
            \"description\": \"Test activation key for default organization view - ${TIMESTAMP}\",
            \"unlimited_hosts\": true,
            \"auto_attach\": true
        }" \
        "Creating activation key '$ACTIVATION_KEY_NAME'")

    ACTIVATION_KEY_ID=$(echo "$response" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    print(data.get('id', ''))
except:
    print('')
" 2>/dev/null || echo "")

    if [[ -z "$ACTIVATION_KEY_ID" ]]; then
        print_error "Failed to create activation key"
        exit 1
    fi

    print_success "Created activation key '$ACTIVATION_KEY_NAME' with ID: $ACTIVATION_KEY_ID (points to default_organization_view in Library)"
}

# Generate summary report
generate_summary() {
    echo
    print_success "=== SETUP COMPLETE ==="
    echo
    echo "Created Resources:"
    echo "  Organization: $ORG_NAME (ID: $ORG_ID)"
    echo "  Product: $PRODUCT_NAME (ID: $PRODUCT_ID)"
    echo "  Yum Repository: $YUM_REPO_NAME (ID: $YUM_REPO_ID)"
    echo "  File Repository: $FILE_REPO_NAME (ID: $FILE_REPO_ID)"
    echo "  Content View: $CONTENT_VIEW_NAME (ID: $CONTENT_VIEW_ID)"
    echo "  Content View Version: $CV_VERSION_ID"
    echo "  Dev Environment: $DEV_ENV_NAME (ID: $DEV_ENV_ID)"
    echo "  Activation Key: $ACTIVATION_KEY_NAME (ID: $ACTIVATION_KEY_ID)"
    echo "    └── Points to: default_organization_view in Library environment"
    echo
    echo "You can now:"
    echo "  1. Register hosts using: subscription-manager register --activationkey=$ACTIVATION_KEY_NAME --org=$ORG_NAME"
    echo "  2. Promote to additional environments"
    echo "  3. Set up additional content views"
    echo "  4. Create more activation keys"
    echo
    echo "Access your Foreman at: $FOREMAN_URL"
}

# Verify setup
verify_setup() {
    print_info "Verifying setup..."

    # Check content view in Dev environment
    local cv_in_dev=$(curl -k -s -u "${FOREMAN_USERNAME}:${FOREMAN_PASSWORD}" \
        "${KATELLO_URL}/content_view_versions" --data-urlencode "content_view_id=${CONTENT_VIEW_ID}" --data-urlencode "environment=${DEV_ENV_NAME}" -G 2>/dev/null | \
        python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    print(data['total'])
except:
    print('0')
" 2>/dev/null || echo "0")

    if [[ "$cv_in_dev" -gt 0 ]]; then
        print_success "Content view successfully promoted to Dev environment"
    else
        print_warning "Content view promotion verification failed"
    fi

    # List repositories in the content view
    print_info "Repositories in content view:"
    curl -k -s -u "${FOREMAN_USERNAME}:${FOREMAN_PASSWORD}" \
        "${KATELLO_URL}/content_views/${CONTENT_VIEW_ID}/repositories" 2>/dev/null | \
        python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    for repo in data['results']:
        print(f'  - {repo[\"name\"]} ({repo[\"content_type\"]})')
except:
    print('  Error listing repositories')
" 2>/dev/null || echo "  Error listing repositories"
}

# Main execution
main() {
    echo "=============================================="
    echo "Katello Complete Workflow Setup"
    echo "=============================================="
    echo "Creating: Unique Org → Product → 2 Pulp Repos (Fast) → Sync → CV → Dev → AK"
    echo "=============================================="

    # Quick help for common usage
    if [[ "${1:-}" == "--help" ]]; then
        echo "Usage: $0"
        echo "Environment variables:"
        echo "  FOREMAN_URL        - Foreman server URL (required)"
        echo "  FOREMAN_USERNAME   - Username (optional, will prompt)"
        echo "  FOREMAN_PASSWORD   - Password (optional, will prompt)"
        echo "  FOREMAN_ORG_ID     - Organization ID (optional, defaults to 1)"
        echo ""
        echo "  Aliases (backward compatibility):"
        echo "  SATELLITE_URL      - Alias for FOREMAN_URL"
        echo "  SATELLITE_USERNAME - Alias for FOREMAN_USERNAME"
        echo "  SATELLITE_PASSWORD - Alias for FOREMAN_PASSWORD"
        echo ""
        echo "Example:"
        echo "  export FOREMAN_URL='https://foreman.example.com'"
        echo "  $0"
        exit 0
    fi

    check_prerequisites
    get_credentials

    create_organization
    create_product
    create_yum_repository
    create_file_repository
    sync_yum_repository
    sync_file_repository
    create_content_view
    publish_content_view
    create_dev_environment
    promote_content_view
    create_activation_key

    verify_setup
    generate_summary

    print_success "Workflow completed successfully!"
}

# Execute main function
main "$@"
