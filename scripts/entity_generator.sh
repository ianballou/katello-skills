#!/bin/bash

# Katello/Foreman Complete Entity Management Script
# Dynamically generates curl commands for all 126+ entities from all_entities.json

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ENTITIES_JSON="${PROJECT_ROOT}/data/all_entities.json"
FOREMAN_URL="${FOREMAN_URL:-${SATELLITE_URL:-}}"
FOREMAN_USERNAME="${FOREMAN_USERNAME:-${SATELLITE_USERNAME:-}}"
FOREMAN_PASSWORD="${FOREMAN_PASSWORD:-${SATELLITE_PASSWORD:-}}"
FOREMAN_ORG_ID="${FOREMAN_ORG_ID:-${SATELLITE_ORG_ID:-1}}"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Print functions
print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check prerequisites
check_prerequisites() {
    print_info "Checking prerequisites..."

    if [[ ! -f "$ENTITIES_JSON" ]]; then
        print_error "all_entities.json not found at $ENTITIES_JSON"
        exit 1
    fi

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

# Get credentials if not provided
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

    # Set up API URLs and headers
    BASE_URL="${FOREMAN_URL}/api/v2"
    KATELLO_URL="${FOREMAN_URL}/katello/api/v2"
    HEADERS='-H "Content-Type: application/json" -u "'${FOREMAN_USERNAME}':'${FOREMAN_PASSWORD}'"'
}

# Extract all entity names from JSON
extract_entities() {
    print_info "Extracting entities from all_entities.json..."

    python3 << 'EOF'
import json
import sys
import os

# Load the entities JSON
script_dir = os.path.dirname(os.path.abspath(__file__))
entities_file = os.path.join(script_dir, 'all_entities.json')

try:
    with open(entities_file, 'r') as f:
        data = json.load(f)

    resources = data['docs']['resources']
    entities = []

    for entity_name, entity_data in resources.items():
        methods = entity_data.get('methods', [])
        entity_info = {
            'name': entity_name,
            'doc_url': entity_data.get('doc_url', ''),
            'description': entity_data.get('short_description') or entity_data.get('full_description', ''),
            'methods': []
        }

        for method in methods:
            method_info = {
                'name': method.get('name', ''),
                'apis': method.get('apis', []),
                'params': method.get('params', [])
            }
            entity_info['methods'].append(method_info)

        entities.append(entity_info)

    print(f"Found {len(entities)} entities")

    # Save entities list for later use
    with open('/tmp/katello_entities.json', 'w') as f:
        json.dump(entities, f, indent=2)

except Exception as e:
    print(f"Error processing entities: {e}")
    sys.exit(1)
EOF
}

# Generate curl command for specific entity operation
generate_curl_command() {
    local entity_name="$1"
    local method_name="$2"
    local api_url="$3"
    local http_method="$4"
    local params="$5"

    # Determine if it's a Katello or Foreman API
    local base_url
    if [[ "$api_url" =~ /katello/ ]]; then
        base_url="$KATELLO_URL"
        api_url="${api_url#/katello/api/v2}"
    else
        base_url="$BASE_URL"
        api_url="${api_url#/api/v2}"
    fi

    # Build the curl command
    local curl_cmd="curl -k ${HEADERS}"

    case "$http_method" in
        "GET")
            curl_cmd="${curl_cmd} \"${base_url}${api_url}\""
            ;;
        "POST")
            curl_cmd="${curl_cmd} -X POST \"${base_url}${api_url}\" -d '{\"example\": \"data\"}'"
            ;;
        "PUT")
            curl_cmd="${curl_cmd} -X PUT \"${base_url}${api_url}\" -d '{\"example\": \"data\"}'"
            ;;
        "DELETE")
            curl_cmd="${curl_cmd} -X DELETE \"${base_url}${api_url}\""
            ;;
        *)
            curl_cmd="${curl_cmd} \"${base_url}${api_url}\""
            ;;
    esac

    echo "$curl_cmd"
}

# List all available entities
list_entities() {
    print_info "Available entities:"

    python3 << 'EOF'
import json

try:
    with open('/tmp/katello_entities.json', 'r') as f:
        entities = json.load(f)

    for i, entity in enumerate(entities, 1):
        methods_count = len(entity['methods'])
        description = entity['description'][:50] + '...' if len(entity['description']) > 50 else entity['description']
        print(f"{i:3d}. {entity['name']:30} ({methods_count:2d} methods) - {description}")

except Exception as e:
    print(f"Error: {e}")
EOF
}

# Show methods for specific entity
show_entity_methods() {
    local entity_name="$1"

    print_info "Methods for entity: $entity_name"

    python3 << EOF
import json

try:
    with open('/tmp/katello_entities.json', 'r') as f:
        entities = json.load(f)

    entity = next((e for e in entities if e['name'] == '$entity_name'), None)
    if not entity:
        print("Entity not found")
        exit(1)

    print(f"Entity: {entity['name']}")
    print(f"Description: {entity['description']}")
    print(f"Documentation: {entity['doc_url']}")
    print("\nAvailable methods:")

    for i, method in enumerate(entity['methods'], 1):
        print(f"{i:2d}. {method['name']:20}")
        for api in method['apis']:
            print(f"    {api['http_method']:6} {api['api_url']}")
            if 'short_description' in api:
                print(f"    -> {api['short_description']}")
        print()

except Exception as e:
    print(f"Error: {e}")
EOF
}

# Execute entity method
execute_entity_method() {
    local entity_name="$1"
    local method_name="$2"

    print_info "Executing $entity_name.$method_name"

    python3 << EOF
import json
import subprocess
import os

try:
    with open('/tmp/katello_entities.json', 'r') as f:
        entities = json.load(f)

    entity = next((e for e in entities if e['name'] == '$entity_name'), None)
    if not entity:
        print("Entity not found")
        exit(1)

    method = next((m for m in entity['methods'] if m['name'] == '$method_name'), None)
    if not method:
        print("Method not found")
        exit(1)

    print(f"Executing {entity['name']}.{method['name']}")

    for api in method['apis']:
        api_url = api['api_url']
        http_method = api['http_method']

        # Determine base URL
        if '/katello/' in api_url:
            base_url = "$KATELLO_URL"
            api_url = api_url.replace('/katello/api/v2', '')
        else:
            base_url = "$BASE_URL"
            api_url = api_url.replace('/api/v2', '')

        # Build curl command
        curl_cmd = ['curl', '-k']
        curl_cmd.extend(['-H', 'Content-Type: application/json'])
        curl_cmd.extend(['-u', f'$FOREMAN_USERNAME:$FOREMAN_PASSWORD'])

        if http_method != 'GET':
            curl_cmd.extend(['-X', http_method])

        # Replace common parameters
        api_url = api_url.replace(':organization_id', str($FOREMAN_ORG_ID))
        api_url = api_url.replace(':id', '1')  # Default ID
        api_url = api_url.replace(':host_id', '1')  # Default host ID

        full_url = f"{base_url}{api_url}"
        curl_cmd.append(full_url)

        if http_method in ['POST', 'PUT']:
            curl_cmd.extend(['-d', '{}'])

        print(f"Command: {' '.join(curl_cmd)}")

        # Execute the command
        try:
            result = subprocess.run(curl_cmd, capture_output=True, text=True, timeout=30)
            print(f"Status: {result.returncode}")
            if result.stdout:
                print(f"Response: {result.stdout[:500]}...")
            if result.stderr:
                print(f"Error: {result.stderr}")
        except subprocess.TimeoutExpired:
            print("Command timed out")
        except Exception as e:
            print(f"Execution error: {e}")

        print("-" * 50)

except Exception as e:
    print(f"Error: {e}")
EOF
}

# Generate entity documentation
generate_entity_docs() {
    local output_file="${1:-entity_docs.md}"

    print_info "Generating entity documentation to $output_file"

    python3 << EOF > "$output_file"
import json

print("# Katello/Foreman API Entities Documentation")
print()
print("Generated from all_entities.json - Complete API reference")
print()

try:
    with open('/tmp/katello_entities.json', 'r') as f:
        entities = json.load(f)

    print(f"## Summary")
    print(f"Total entities: {len(entities)}")
    print()

    # Group entities by category
    categories = {
        'Content Management': ['repositories', 'products', 'content_views', 'environments', 'subscriptions', 'activation_keys', 'sync_plans'],
        'Host Management': ['hosts', 'hostgroups', 'host_collections', 'interfaces', 'host_subscriptions', 'registration'],
        'Infrastructure': ['organizations', 'locations', 'domains', 'subnets', 'smart_proxies', 'compute_resources'],
        'Security & Access': ['users', 'user_groups', 'roles', 'permissions', 'auth_sources', 'personal_access_tokens'],
        'Provisioning': ['operatingsystems', 'architectures', 'ptables', 'media', 'provisioning_templates', 'job_templates']
    }

    categorized = set()

    for category, entity_names in categories.items():
        print(f"## {category}")
        print()

        for entity_name in entity_names:
            entity = next((e for e in entities if e['name'] == entity_name), None)
            if entity:
                categorized.add(entity_name)
                print(f"### {entity['name']}")
                if entity['description']:
                    print(f"{entity['description']}")
                print()

                print("**Available Methods:**")
                for method in entity['methods']:
                    print(f"- **{method['name']}**")
                    for api in method['apis']:
                        print(f"  - \`{api['http_method']} {api['api_url']}\`")
                        if 'short_description' in api and api['short_description']:
                            print(f"    - {api['short_description']}")
                print()

    # Uncategorized entities
    uncategorized = [e for e in entities if e['name'] not in categorized]
    if uncategorized:
        print("## Other Entities")
        print()

        for entity in uncategorized:
            print(f"### {entity['name']}")
            if entity['description']:
                print(f"{entity['description']}")
            print()

            print("**Available Methods:**")
            for method in entity['methods']:
                print(f"- **{method['name']}**")
                for api in method['apis']:
                    print(f"  - \`{api['http_method']} {api['api_url']}\`")
                    if 'short_description' in api and api['short_description']:
                        print(f"    - {api['short_description']}")
            print()

except Exception as e:
    print(f"Error: {e}")
EOF

    print_success "Documentation generated: $output_file"
}

# Interactive entity explorer
interactive_explorer() {
    while true; do
        echo
        echo "=== Katello/Foreman Entity Explorer ==="
        echo "1. List all entities"
        echo "2. Show entity methods"
        echo "3. Execute entity method"
        echo "4. Generate entity documentation"
        echo "5. Search entities"
        echo "6. Exit"
        echo
        read -p "Choose an option (1-6): " choice

        case $choice in
            1)
                list_entities
                ;;
            2)
                read -p "Enter entity name: " entity_name
                show_entity_methods "$entity_name"
                ;;
            3)
                read -p "Enter entity name: " entity_name
                read -p "Enter method name: " method_name
                execute_entity_method "$entity_name" "$method_name"
                ;;
            4)
                read -p "Enter output file name (default: entity_docs.md): " output_file
                generate_entity_docs "${output_file:-entity_docs.md}"
                ;;
            5)
                read -p "Enter search term: " search_term
                search_entities "$search_term"
                ;;
            6)
                print_info "Goodbye!"
                break
                ;;
            *)
                print_error "Invalid choice. Please try again."
                ;;
        esac
    done
}

# Search entities
search_entities() {
    local search_term="$1"

    print_info "Searching for entities matching: $search_term"

    python3 << EOF
import json

try:
    with open('/tmp/katello_entities.json', 'r') as f:
        entities = json.load(f)

    matches = []
    search_term = '$search_term'.lower()

    for entity in entities:
        if (search_term in entity['name'].lower() or
            search_term in entity['description'].lower()):
            matches.append(entity)
        else:
            # Search in methods
            for method in entity['methods']:
                if search_term in method['name'].lower():
                    matches.append(entity)
                    break

    if matches:
        print(f"Found {len(matches)} matching entities:")
        for entity in matches:
            methods_count = len(entity['methods'])
            description = entity['description'][:50] + '...' if len(entity['description']) > 50 else entity['description']
            print(f"- {entity['name']:30} ({methods_count:2d} methods) - {description}")
    else:
        print("No matching entities found")

except Exception as e:
    print(f"Error: {e}")
EOF
}

# Generate bash completion script
generate_completion() {
    cat > katello_completion.bash << 'EOF'
#!/bin/bash

_katello_entities() {
    local cur prev opts
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    # Entity names from JSON
    local entities=$(python3 -c "
import json
try:
    with open('/tmp/katello_entities.json', 'r') as f:
        entities = json.load(f)
    print(' '.join([e['name'] for e in entities]))
except:
    pass
")

    case "${prev}" in
        -e|--entity)
            COMPREPLY=( $(compgen -W "${entities}" -- ${cur}) )
            return 0
            ;;
        *)
            ;;
    esac

    opts="-h --help -e --entity -m --method -l --list -i --interactive"
    COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
    return 0
}

complete -F _katello_entities entity_generator.sh
EOF

    print_success "Bash completion generated: katello_completion.bash"
    print_info "Source with: source katello_completion.bash"
}

# Main function
main() {
    echo "========================================"
    echo "Katello/Foreman Complete Entity Manager"
    echo "========================================"
    echo "Supporting all 126+ API entities"
    echo "========================================"

    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                echo "Usage: $0 [OPTIONS]"
                echo "Options:"
                echo "  -e, --entity ENTITY    Work with specific entity"
                echo "  -m, --method METHOD    Execute specific method"
                echo "  -l, --list            List all entities"
                echo "  -i, --interactive     Interactive mode"
                echo "  -d, --docs            Generate documentation"
                echo "  -c, --completion      Generate bash completion"
                echo "  -h, --help            Show this help"
                exit 0
                ;;
            -l|--list)
                check_prerequisites
                extract_entities
                list_entities
                exit 0
                ;;
            -e|--entity)
                ENTITY_NAME="$2"
                shift 2
                ;;
            -m|--method)
                METHOD_NAME="$2"
                shift 2
                ;;
            -i|--interactive)
                INTERACTIVE=true
                shift
                ;;
            -d|--docs)
                check_prerequisites
                extract_entities
                generate_entity_docs
                exit 0
                ;;
            -c|--completion)
                generate_completion
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done

    check_prerequisites
    get_credentials
    extract_entities

    if [[ "${INTERACTIVE:-false}" == "true" ]]; then
        interactive_explorer
    elif [[ -n "${ENTITY_NAME:-}" ]]; then
        if [[ -n "${METHOD_NAME:-}" ]]; then
            execute_entity_method "$ENTITY_NAME" "$METHOD_NAME"
        else
            show_entity_methods "$ENTITY_NAME"
        fi
    else
        # Default to interactive mode
        interactive_explorer
    fi
}

# Execute main function
main "$@"
EOF