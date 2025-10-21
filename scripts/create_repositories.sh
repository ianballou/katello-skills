#!/bin/bash

# Script to create 2 yum and 1 file repository on Red Hat Satellite/Foreman
# Target Foreman: Set FOREMAN_URL environment variable

set -euo pipefail

# Configuration
FOREMAN_URL="${FOREMAN_URL:-${SATELLITE_URL:-}}"
KATELLO_API_URL="${FOREMAN_URL}/katello/api/v2"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if required tools are available
check_prerequisites() {
    print_status "Checking prerequisites..."

    if ! command -v curl &> /dev/null; then
        print_error "curl is required but not installed"
        exit 1
    fi

    if ! command -v jq &> /dev/null; then
        print_warning "jq is not installed. JSON output will be raw format"
        JQ_AVAILABLE=false
    else
        JQ_AVAILABLE=true
    fi

    print_success "Prerequisites check completed"
}

# Function to get credentials
get_credentials() {
    FOREMAN_USERNAME="${FOREMAN_USERNAME:-${SATELLITE_USERNAME:-}}"
    FOREMAN_PASSWORD="${FOREMAN_PASSWORD:-${SATELLITE_PASSWORD:-}}"

    if [[ -z "$FOREMAN_USERNAME" ]]; then
        read -p "Enter Foreman username: " FOREMAN_USERNAME
    fi

    if [[ -z "$FOREMAN_PASSWORD" ]]; then
        read -s -p "Enter Foreman password: " FOREMAN_PASSWORD
        echo
    fi
}

# Function to test connectivity
test_connectivity() {
    print_status "Testing connectivity to Foreman server..."

    if curl -k -s --connect-timeout 10 "${FOREMAN_URL}" > /dev/null; then
        print_success "Successfully connected to Foreman server"
    else
        print_error "Failed to connect to Foreman server"
        exit 1
    fi
}

# Function to get organization ID
get_organization_id() {
    print_status "Getting organization information..."

    local response
    response=$(curl -k -s -u "${FOREMAN_USERNAME}:${FOREMAN_PASSWORD}" \
        "${KATELLO_API_URL}/organizations")

    if [[ $JQ_AVAILABLE == true ]]; then
        local orgs
        orgs=$(echo "$response" | jq -r '.results[] | "\(.id): \(.name)"')
        echo "Available organizations:"
        echo "$orgs"

        read -p "Enter organization ID: " ORG_ID
    else
        echo "Organization response (find your org ID):"
        echo "$response"
        read -p "Enter organization ID: " ORG_ID
    fi
}

# Function to get or create product
get_or_create_product() {
    local product_name="$1"
    print_status "Checking if product '$product_name' exists..."

    local response
    response=$(curl -k -s -u "${FOREMAN_USERNAME}:${FOREMAN_PASSWORD}" \
        "${KATELLO_API_URL}/products?organization_id=${ORG_ID}&name=${product_name}")

    local product_count
    if [[ $JQ_AVAILABLE == true ]]; then
        product_count=$(echo "$response" | jq -r '.total')
    else
        # Simple grep-based check
        if echo "$response" | grep -q "\"name\":\"${product_name}\""; then
            product_count=1
        else
            product_count=0
        fi
    fi

    if [[ $product_count -gt 0 ]]; then
        print_success "Product '$product_name' already exists"
        if [[ $JQ_AVAILABLE == true ]]; then
            PRODUCT_ID=$(echo "$response" | jq -r '.results[0].id')
        else
            echo "Product response:"
            echo "$response"
            read -p "Enter product ID from the response: " PRODUCT_ID
        fi
    else
        print_status "Creating product '$product_name'..."
        response=$(curl -k -s -u "${FOREMAN_USERNAME}:${FOREMAN_PASSWORD}" \
            -X POST "${KATELLO_API_URL}/products" \
            -H "Content-Type: application/json" \
            -d "{
                \"name\": \"${product_name}\",
                \"organization_id\": ${ORG_ID},
                \"description\": \"Product created by repository setup script\"
            }")

        if [[ $JQ_AVAILABLE == true ]]; then
            PRODUCT_ID=$(echo "$response" | jq -r '.id')
        else
            echo "Product creation response:"
            echo "$response"
            read -p "Enter the new product ID from the response: " PRODUCT_ID
        fi
        print_success "Created product '$product_name' with ID: $PRODUCT_ID"
    fi
}

# Function to create yum repository
create_yum_repository() {
    local repo_name="$1"
    local repo_url="$2"
    local repo_description="$3"

    print_status "Creating yum repository: $repo_name"

    local response
    response=$(curl -k -s -u "${FOREMAN_USERNAME}:${FOREMAN_PASSWORD}" \
        -X POST "${KATELLO_API_URL}/repositories" \
        -H "Content-Type: application/json" \
        -d "{
            \"name\": \"${repo_name}\",
            \"product_id\": ${PRODUCT_ID},
            \"content_type\": \"yum\",
            \"url\": \"${repo_url}\",
            \"description\": \"${repo_description}\",
            \"download_policy\": \"on_demand\",
            \"verify_ssl_on_sync\": false,
            \"upstream_username\": null,
            \"upstream_password\": null
        }")

    if echo "$response" | grep -q '"id"'; then
        if [[ $JQ_AVAILABLE == true ]]; then
            local repo_id
            repo_id=$(echo "$response" | jq -r '.id')
            print_success "Created yum repository '$repo_name' with ID: $repo_id"
        else
            print_success "Created yum repository '$repo_name'"
            echo "Repository response:"
            echo "$response"
        fi
    else
        print_error "Failed to create yum repository '$repo_name'"
        echo "Error response:"
        echo "$response"
        return 1
    fi
}

# Function to create file repository
create_file_repository() {
    local repo_name="$1"
    local repo_url="$2"
    local repo_description="$3"

    print_status "Creating file repository: $repo_name"

    local response
    response=$(curl -k -s -u "${FOREMAN_USERNAME}:${FOREMAN_PASSWORD}" \
        -X POST "${KATELLO_API_URL}/repositories" \
        -H "Content-Type: application/json" \
        -d "{
            \"name\": \"${repo_name}\",
            \"product_id\": ${PRODUCT_ID},
            \"content_type\": \"file\",
            \"url\": \"${repo_url}\",
            \"description\": \"${repo_description}\",
            \"download_policy\": \"immediate\",
            \"verify_ssl_on_sync\": false
        }")

    if echo "$response" | grep -q '"id"'; then
        if [[ $JQ_AVAILABLE == true ]]; then
            local repo_id
            repo_id=$(echo "$response" | jq -r '.id')
            print_success "Created file repository '$repo_name' with ID: $repo_id"
        else
            print_success "Created file repository '$repo_name'"
            echo "Repository response:"
            echo "$response"
        fi
    else
        print_error "Failed to create file repository '$repo_name'"
        echo "Error response:"
        echo "$response"
        return 1
    fi
}

# Function to sync repository
sync_repository() {
    local repo_name="$1"

    print_status "Initiating sync for repository: $repo_name"

    # First, get the repository ID by name
    local response
    response=$(curl -k -s -u "${FOREMAN_USERNAME}:${FOREMAN_PASSWORD}" \
        "${KATELLO_API_URL}/repositories?organization_id=${ORG_ID}&name=${repo_name}")

    local repo_id
    if [[ $JQ_AVAILABLE == true ]]; then
        repo_id=$(echo "$response" | jq -r '.results[0].id // empty')
    else
        echo "Repository search response:"
        echo "$response"
        read -p "Enter repository ID for $repo_name: " repo_id
    fi

    if [[ -n "$repo_id" && "$repo_id" != "null" ]]; then
        # Initiate sync
        local sync_response
        sync_response=$(curl -k -s -u "${FOREMAN_USERNAME}:${FOREMAN_PASSWORD}" \
            -X POST "${KATELLO_API_URL}/repositories/${repo_id}/sync")

        print_success "Sync initiated for repository '$repo_name'"
        echo "Sync response:"
        echo "$sync_response"
    else
        print_error "Could not find repository ID for '$repo_name'"
    fi
}

# Main execution
main() {
    echo "=========================================="
    echo "Red Hat Foreman/Satellite Repository Setup Script"
    echo "=========================================="
    echo "Target: ${FOREMAN_URL}"
    echo "Task: Create 2 Yum + 1 File repositories"
    echo "=========================================="

    check_prerequisites
    get_credentials
    test_connectivity
    get_organization_id

    # Create or get product for repositories
    local product_name="Custom Repositories"
    get_or_create_product "$product_name"

    echo
    print_status "Creating repositories..."

    # Create first yum repository (EPEL)
    create_yum_repository \
        "EPEL-8" \
        "https://dl.fedoraproject.org/pub/epel/8/Everything/x86_64/" \
        "Extra Packages for Enterprise Linux 8 - x86_64"

    # Create second yum repository (CentOS AppStream)
    create_yum_repository \
        "CentOS-8-AppStream" \
        "http://mirror.centos.org/centos/8-stream/AppStream/x86_64/os/" \
        "CentOS 8 Stream AppStream Repository"

    # Create file repository
    create_file_repository \
        "Custom-Files" \
        "https://files.example.com/custom/" \
        "Custom file repository for miscellaneous files"

    echo
    print_status "Repository creation completed!"

    # Ask if user wants to sync repositories
    read -p "Do you want to initiate sync for all repositories? (y/n): " sync_choice
    if [[ $sync_choice =~ ^[Yy]$ ]]; then
        print_status "Initiating repository synchronization..."
        sync_repository "EPEL-8"
        sync_repository "CentOS-8-AppStream"
        sync_repository "Custom-Files"
    fi

    echo
    print_success "Script execution completed!"
    echo "You can check repository status in the Foreman web interface:"
    echo "${FOREMAN_URL}"
}

# Execute main function
main "$@"