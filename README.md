# Katello Skills Project

Complete automation toolkit for Red Hat Satellite, Katello, and Foreman management via REST APIs.

## 📁 Directory Structure

```
katello-skills/
├── README.md                           # This file
├── data/                               # Data files
│   └── all_entities.json              # Complete API entity definitions
├── populate-katello-content/           # Main skill documentation
│   ├── SKILL.md                       # Complete Katello management skill
│   ├── lessons_learned.md             # Troubleshooting guide & best practices
│   ├── curl_best_practices.md         # URL encoding & parameter handling
│   └── api_endpoints_reference.md     # Katello vs Foreman API mapping
└── scripts/                           # Automation scripts
    ├── setup_complete_workflow.sh     # Full unique-org→product→pulp-repos→sync→CV→promote→AK workflow
    ├── entity_generator.sh            # Dynamic management for all 126+ entities
    ├── create_repositories.sh         # Repository creation script
    ├── wait_for_task.sh               # Task monitoring utility
    ├── test_org_creation.sh           # Organization creation testing
    ├── test_json_parsing.sh           # JSON parsing validation
    └── test_error_detection.sh        # Error detection testing
```

## 🚀 Quick Start

### 1. Set up credentials
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

### 2. Run the complete workflow
```bash
# Create unique org, product, 2 Pulp repos (fast), sync them, create content view, promote to Dev, and create activation key
./scripts/setup_complete_workflow.sh
```

### 3. Explore all entities
```bash
# Interactive entity explorer for all 126+ API entities
./scripts/entity_generator.sh --interactive
```

## 📖 Documentation

- **[Main Skill](populate-katello-content/SKILL.md)** - Complete Katello/Foreman automation guide
- **[Lessons Learned](populate-katello-content/lessons_learned.md)** - Production troubleshooting guide
- **[Curl Best Practices](populate-katello-content/curl_best_practices.md)** - URL encoding mastery
- **[API Reference](populate-katello-content/api_endpoints_reference.md)** - Endpoint mapping guide

## 🛠 Key Features

✅ **126+ Entity Support** - Complete API coverage for all Katello/Foreman entities
✅ **Production-Ready** - Battle-tested error handling and retry logic
✅ **Smart Error Detection** - Distinguishes null from actual errors
✅ **URL Parameter Escaping** - Proper handling of special characters
✅ **Async Task Handling** - Pending task detection and monitoring
✅ **Endpoint Routing** - Automatic Katello vs Foreman API selection

## 🎯 Use Cases

- **Red Hat Satellite Management** - Complete lifecycle automation
- **Content Management** - Repository sync, content view publishing, promotion
- **Host Registration** - Automated host onboarding and subscription
- **Infrastructure Provisioning** - Template and host group management
- **CI/CD Integration** - Pipeline-ready automation scripts

## 🔧 Prerequisites

- `curl` - HTTP client for API calls
- `python3` - JSON parsing and data manipulation
- Access to Red Hat Satellite/Katello/Foreman instance
- Admin or appropriate service account credentials

## 📝 Examples

### Create Organization and Product
```bash
# Using the entity generator
./scripts/entity_generator.sh --entity organizations --method create

# Using the workflow script (creates full stack)
./scripts/setup_complete_workflow.sh
```

### Monitor Running Tasks
```bash
# Wait for specific task
./scripts/wait_for_task.sh d68d9b65-567a-423f-8f5c-0da31dda861a

# List all running tasks
curl -k -u admin:pass "${FOREMAN_URL}/api/v2/tasks?search=state=running"
```

### Generate Documentation
```bash
# Create complete entity documentation
./scripts/entity_generator.sh --docs
```

## 🚨 Important Notes

1. **Always use proper URL encoding** for search parameters
2. **Distinguish Katello vs Foreman APIs** - content vs infrastructure
3. **Handle async operations** - many Katello operations are asynchronous
4. **Test with real data** - entity names with spaces reveal issues
5. **Monitor task completion** - content operations can take time

## 🤝 Contributing

The automation patterns in this project solve real production issues discovered through extensive troubleshooting. Key learnings include proper error detection, URL parameter escaping, and async task handling - all critical for reliable Satellite automation.

## 📄 License

See LICENSE file for details.