# recon-silly-ation

**Documentation Reconciliation System** - Automatically reconcile, deduplicate, and resolve conflicts in Git repository documentation using content-addressable storage and graph-based conflict resolution.

[![CI](https://github.com/Hyperpolymath/recon-silly-ation/workflows/CI/badge.svg)](https://github.com/Hyperpolymath/recon-silly-ation/actions)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![ReScript](https://img.shields.io/badge/ReScript-v11.0-blue)](https://rescript-lang.org)

## Features

🚀 **Content-Addressable Storage** - SHA-256 hashing for automatic deduplication
🤖 **Auto-Resolution** - Confidence-scored conflict resolution (>0.9 auto-applies)
📊 **Graph Database** - ArangoDB for multi-model storage and traversal
🔄 **Idempotent Pipeline** - Rerunnable 7-stage reconciliation process
🧠 **Logical Inference** - miniKanren/Datalog-style cross-document reasoning
🛡️ **Schema Validation** - Haskell bridge for type-safe validation
🤖 **LLM Integration** - Auto-generate docs with guardrails (always requires approval)
⚠️ **CCCP Compliance** - Python detection with ReScript/Deno migration suggestions
📈 **Visualization** - DOT/Mermaid graph generation
🐳 **Docker Ready** - Full stack deployment with Docker Compose

## Quick Start

### Installation

```bash
# Clone repository
git clone https://github.com/Hyperpolymath/recon-silly-ation.git
cd recon-silly-ation

# Install dependencies
npm install

# Build
npm run build
```

### Basic Usage

```bash
# Scan a repository
node lib/js/src/CLI.bs.js --repo /path/to/repo

# With custom ArangoDB
node lib/js/src/CLI.bs.js \
  --repo /path/to/repo \
  --arango-url http://localhost:8529 \
  --arango-db reconciliation

# Run in daemon mode (continuous scanning)
node lib/js/src/CLI.bs.js \
  --repo /path/to/repo \
  --daemon \
  --interval 300
```

### Using Just

```bash
# Setup development environment
just dev-setup

# Scan a repository
just scan /path/to/repo

# Run with local ArangoDB
just dev-run /path/to/repo

# Run tests
just test

# Run in daemon mode
just daemon /path/to/repo 300
```

### Docker Deployment

```bash
# Full stack (ReScript service + ArangoDB)
docker-compose up

# With UI
docker-compose --profile ui up

# Custom repository path
REPO_PATH=/my/repo docker-compose up
```

## Architecture

### Pipeline Stages

```
Scan → Normalize → Deduplicate → Detect → Resolve → Ingest → Report
```

Each stage is **idempotent** and can be rerun safely.

### Core Guarantees

1. **Zero Duplicates** - Content hashing ensures no duplicate content
2. **Always Latest** - Temporal ordering + semver ensures most recent versions
3. **Auto-Resolution** - High-confidence (>0.9) conflicts resolved automatically
4. **Minimal Manual Input** - Smart inference reduces human intervention

### Technology Stack

- **ReScript** - Type-safe functional programming
- **ArangoDB** - Multi-model graph database
- **Haskell** - Schema validation bridge
- **Docker** - Containerized deployment
- **Just** - Build automation

## Documentation Types Supported

- ✅ README
- ✅ LICENSE
- ✅ SECURITY
- ✅ CONTRIBUTING
- ✅ CODE_OF_CONDUCT
- ✅ FUNDING
- ✅ CITATION
- ✅ CHANGELOG
- ✅ AUTHORS
- ✅ SUPPORT

## Resolution Rules

| Rule | Confidence | Description |
|------|-----------|-------------|
| `duplicate-keep-latest` | 1.0 | Keep most recent for exact duplicates |
| `funding-yaml-canonical` | 0.98 | FUNDING.yml is authoritative |
| `license-file-canonical` | 0.95 | LICENSE file is authoritative |
| `explicit-canonical` | 1.0 | Explicitly marked canonical wins |
| `keep-highest-semver` | 0.85 | Prefer highest semantic version |
| `canonical-over-inferred` | 0.80 | Canonical source over inferred |

## Configuration

### Environment Variables

```bash
export ARANGO_URL=http://localhost:8529
export ARANGO_DATABASE=reconciliation
export ARANGO_USERNAME=root
export ARANGO_PASSWORD=your_password
```

### CLI Options

```
-r, --repo <path>           Repository path (can specify multiple)
-d, --daemon                Run in daemon mode
-i, --interval <seconds>    Scan interval (default: 300)
-t, --threshold <float>     Auto-resolve threshold (default: 0.9)
--arango-url <url>          ArangoDB URL
--arango-db <name>          Database name
--arango-user <username>    Username
--arango-password <pass>    Password
-h, --help                  Show help
```

## Advanced Features

### LLM Integration

Generate missing documentation with AI:

```rescript
// Generate SECURITY.md
let response = await LLMIntegration.generateMissingDoc(
  SECURITY,
  repoContext,
  Anthropic(apiKey)
)
```

**Guardrails:**
- ✅ NEVER auto-commit LLM output
- ✅ Always `requiresApproval: true`
- ✅ Validation before use
- ✅ Audit trail maintained

### Logical Inference

Cross-document reasoning:

```prolog
duplicate(X, Y) :- same_hash(X, Y), different_path(X, Y).
authoritative(X) :- has_canonical_source(X).
supersedes(X, Y) :- same_type(X, Y), version_greater(X, Y).
```

### Schema Validation

Type-safe Haskell validator:

```bash
# Validate a document
validator-bridge LICENSE /path/to/LICENSE
```

### CCCP Compliance

Python detection and migration recommendations:

```bash
just cccp-check /path/to/repo
```

Outputs "Patrojisign/insulti" warnings with migration suggestions to ReScript/Deno.

## Graph Visualization

Generate DOT/Mermaid diagrams:

```rescript
// Generate DOT format
let dot = GraphVisualizer.generateDot(documents, edges, config)

// Generate Mermaid
let mermaid = GraphVisualizer.generateMermaid(documents, edges)
```

Render with Graphviz:

```bash
dot -Tsvg -o graph.svg graph.dot
```

## Development

### Prerequisites

- Node.js 16+
- ReScript 11+
- ArangoDB 3.11+ (optional, for persistence)
- GHC 9.2+ (optional, for Haskell validator)
- Just (optional, for build automation)

### Build from Source

```bash
# Install dependencies
npm ci

# Build ReScript
npm run build

# Build Haskell validator (optional)
cd validator
cabal build
cabal install --installdir=/usr/local/bin

# Run tests
npm test
```

### Project Structure

```
recon-silly-ation/
├── src/                      # ReScript source
│   ├── Types.res            # Core types
│   ├── Deduplicator.res     # Deduplication
│   ├── ConflictResolver.res # Resolution
│   ├── ArangoClient.res     # Database
│   ├── Pipeline.res         # Orchestration
│   ├── CLI.res              # Command-line
│   ├── LLMIntegration.res   # AI integration
│   ├── LogicEngine.res      # Inference
│   ├── CCCPCompliance.res   # Python detection
│   ├── HaskellBridge.res    # Validator bridge
│   └── GraphVisualizer.res  # Visualization
├── validator/               # Haskell validator
│   ├── DocumentValidator.hs
│   └── Main.hs
├── tests/                   # Test suite
├── docs/                    # Documentation
├── examples/                # Example configs
├── .github/workflows/       # CI/CD
├── .gitlab/pages/           # Contributor portal
├── Dockerfile               # Container build
├── docker-compose.yml       # Stack deployment
└── justfile                 # Build automation
```

## Testing

```bash
# Run all tests
npm test

# Or with just
just test

# Individual test suites
node lib/js/tests/TestRunner.bs.js
```

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

Contributor submission portal: https://your-gitlab-pages-url

## CI/CD

GitHub Actions workflow includes:

- ✅ Matrix builds (Node 16, 18, 20)
- ✅ ReScript compilation
- ✅ Haskell validator build
- ✅ Docker image build
- ✅ Integration tests with ArangoDB
- ✅ Linting (Hadolint, ShellCheck)

## License

MIT License - see [LICENSE](LICENSE) for details.

## Security

See [SECURITY.md](SECURITY.md) for vulnerability reporting.

## Acknowledgments

- ReScript team for excellent type system
- ArangoDB for multi-model database
- miniKanren community for logic programming inspiration
- Anthropic for Claude AI capabilities

## Links

- **Documentation**: [docs/](docs/)
- **Architecture**: [docs/doc-reconciliation-architecture.adoc](docs/doc-reconciliation-architecture.adoc)
- **Implementation**: [docs/IMPLEMENTATION-SUMMARY.adoc](docs/IMPLEMENTATION-SUMMARY.adoc)
- **Issues**: https://github.com/Hyperpolymath/recon-silly-ation/issues
- **ReScript**: https://rescript-lang.org
- **ArangoDB**: https://www.arangodb.com

---

Made with ❤️ using ReScript + ArangoDB + Haskell
