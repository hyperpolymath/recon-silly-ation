# Build automation for recon-silly-ation
# https://github.com/casey/just

# Default recipe
default:
    @just --list

# Install dependencies
install:
    npm install

# Build ReScript code
build:
    npm run build

# Clean build artifacts
clean:
    npm run clean
    rm -rf lib/

# Watch mode for development
watch:
    npm run watch

# Run the CLI
run *ARGS:
    node lib/js/src/CLI.bs.js {{ARGS}}

# Run pipeline on a repository
scan REPO:
    node lib/js/src/CLI.bs.js --repo {{REPO}}

# Run in daemon mode
daemon REPO INTERVAL="300":
    node lib/js/src/CLI.bs.js --repo {{REPO}} --daemon --interval {{INTERVAL}}

# Run tests
test:
    npm test

# Type check
check:
    npm run build

# Format code (using rescript format)
format:
    find src -name "*.res" -exec rescript format {} \;

# Start ArangoDB in Docker
arango-start:
    docker run -d \
        --name recon-arango \
        -p 8529:8529 \
        -e ARANGO_ROOT_PASSWORD=dev \
        arangodb/arangodb:latest

# Stop ArangoDB
arango-stop:
    docker stop recon-arango
    docker rm recon-arango

# ArangoDB logs
arango-logs:
    docker logs -f recon-arango

# Full development setup
dev-setup: install arango-start
    @echo "Development environment ready!"
    @echo "ArangoDB: http://localhost:8529 (root/dev)"

# Run full pipeline with local ArangoDB
dev-run REPO:
    node lib/js/src/CLI.bs.js \
        --repo {{REPO}} \
        --arango-url http://localhost:8529 \
        --arango-password dev

# Generate documentation
docs:
    @echo "Generating documentation..."
    @echo "See docs/ directory for architecture and implementation details"

# CCCP compliance check
cccp-check REPO:
    @echo "Running CCCP compliance check..."
    node lib/js/src/CLI.bs.js --repo {{REPO}} --cccp-only

# Generate report
report REPO:
    node lib/js/src/CLI.bs.js --repo {{REPO}} --report-only

# Full CI check
ci: install build test
    @echo "CI checks passed!"

# Production build
prod: clean install build
    @echo "Production build complete!"

# Docker build
docker-build:
    docker build -t recon-silly-ation:latest .

# Docker run
docker-run REPO:
    docker run --rm \
        -v {{REPO}}:/workspace \
        -e ARANGO_URL=http://host.docker.internal:8529 \
        recon-silly-ation:latest \
        --repo /workspace

# Initialize new repository for reconciliation
init REPO:
    @echo "Initializing {{REPO}} for documentation reconciliation..."
    mkdir -p {{REPO}}/.recon
    cp examples/config.json {{REPO}}/.recon/config.json
    @echo "Configuration created at {{REPO}}/.recon/config.json"

# Validate repository structure
validate REPO:
    @echo "Validating {{REPO}}..."
    node lib/js/src/CLI.bs.js --repo {{REPO}} --validate-only

# Export database to JSON
export-db OUTPUT="export.json":
    @echo "Exporting database to {{OUTPUT}}..."
    node lib/js/src/CLI.bs.js --export {{OUTPUT}}

# Import database from JSON
import-db INPUT:
    @echo "Importing database from {{INPUT}}..."
    node lib/js/src/CLI.bs.js --import {{INPUT}}

# Backup database
backup:
    @echo "Backing up database..."
    mkdir -p backups
    node lib/js/src/CLI.bs.js --export backups/backup-$(date +%Y%m%d-%H%M%S).json

# Restore database from backup
restore BACKUP:
    @echo "Restoring from {{BACKUP}}..."
    node lib/js/src/CLI.bs.js --import {{BACKUP}}

# Show project statistics
stats REPO:
    @echo "=== Repository Statistics ==="
    @echo "Total files:"
    @find {{REPO}} -type f | wc -l
    @echo "Documentation files:"
    @find {{REPO}} -type f -name "*.md" | wc -l
    @echo "Python files (CCCP violations):"
    @find {{REPO}} -type f -name "*.py" | wc -l

# Help message
help:
    @echo "recon-silly-ation - Documentation Reconciliation System"
    @echo ""
    @echo "Common commands:"
    @echo "  just install          - Install dependencies"
    @echo "  just build            - Build the project"
    @echo "  just scan REPO        - Scan a repository"
    @echo "  just dev-setup        - Setup development environment"
    @echo "  just dev-run REPO     - Run with local ArangoDB"
    @echo "  just test             - Run tests"
    @echo "  just cccp-check REPO  - Check CCCP compliance"
    @echo ""
    @echo "For full list: just --list"
