# CLAUDE.md

## Project Overview

**recon-silly-ation** - Documentation Reconciliation System

A ReScript-based system that automatically reconciles, deduplicates, and resolves conflicts in Git repository documentation (README, LICENSE, SECURITY, etc.). Uses content-addressable storage with ArangoDB graph database and automatic conflict resolution based on confidence scoring.

This document provides context for Claude (AI assistant) when working on this codebase.

## Project Structure

```
recon-silly-ation/
├── src/                      # ReScript source code
│   ├── Types.res            # Core domain types
│   ├── Deduplicator.res     # Content-addressable deduplication
│   ├── ConflictResolver.res # Rule-based conflict resolution
│   ├── ArangoClient.res     # Type-safe database client
│   ├── Pipeline.res         # Idempotent orchestration
│   ├── CLI.res              # Command-line interface
│   ├── LLMIntegration.res   # LLM integration with guardrails
│   ├── LogicEngine.res      # miniKanren/Datalog inference
│   ├── CCCPCompliance.res   # Python detection & migration
│   ├── HaskellBridge.res    # Bridge to Haskell validator
│   └── GraphVisualizer.res  # DOT/Mermaid visualization
├── validator/               # Haskell schema validator
│   ├── DocumentValidator.hs # Validation logic
│   ├── Main.hs              # CLI entry point
│   └── validator-bridge.cabal
├── tests/                   # Test suite
│   └── TestRunner.res       # Comprehensive tests
├── docs/                    # Documentation
│   ├── doc-reconciliation-architecture.adoc
│   └── IMPLEMENTATION-SUMMARY.adoc
├── examples/                # Example configurations
├── .github/workflows/       # CI/CD
├── .gitlab/pages/           # Contributor submission portal
├── Dockerfile               # Multi-stage Docker build
├── docker-compose.yml       # Full stack deployment
├── justfile                 # Build automation
├── bsconfig.json            # ReScript configuration
├── package.json             # Node.js dependencies
└── CLAUDE.md                # This file
```

## Getting Started

### Prerequisites

- Node.js 16+ (18+ recommended)
- npm or yarn
- ArangoDB 3.11+ (optional, for persistence)
- Docker (optional, for containerized deployment)
- GHC 9.2+ (optional, for Haskell validator)
- Just (optional, for build automation)

### Installation

```bash
# Clone repository
git clone https://github.com/Hyperpolymath/recon-silly-ation.git
cd recon-silly-ation

# Install dependencies
npm install

# Build ReScript code
npm run build
```

### Running the Project

```bash
# Basic usage - scan a repository
node lib/js/src/CLI.bs.js --repo /path/to/repo

# Using just
just scan /path/to/repo

# With Docker
docker-compose up

# Run tests
npm test
```

## Development Guidelines

### Code Style

- **ReScript**: Follow ReScript best practices
- Use Belt standard library for functional operations
- Pattern match exhaustively (compiler enforced)
- Prefer immutable data structures
- Keep functions pure where possible

### Testing

- Run tests before committing: `npm test`
- Add tests for new features in `tests/`
- Ensure all tests pass before pushing
- Test suite runs automatically in CI

### Git Workflow

- Work on feature branches
- Write clear, descriptive commit messages
- Keep commits atomic and focused
- Rebase on main branch before merging

## Architecture

### Core Principles

1. **Type Safety** - ReScript provides compile-time guarantees
2. **Idempotency** - All pipeline stages can be rerun safely
3. **Content-Addressable** - SHA-256 hashing for deduplication
4. **Confidence Scoring** - Quantified resolution certainty (0.0-1.0)
5. **Auto-Resolution** - High confidence (>0.9) resolves automatically
6. **Human-in-Loop** - Low confidence escalates to manual review

### Pipeline Stages

```
Scan → Normalize → Deduplicate → Detect → Resolve → Ingest → Report
```

Each stage is idempotent and rerunnable.

### Data Flow

1. **Scanner** finds documentation files
2. **Deduplicator** hashes content, removes duplicates
3. **Conflict Detector** identifies conflicts
4. **Resolver** applies rules, generates resolutions
5. **ArangoDB Client** stores documents and relationships
6. **Reporter** generates summary

## Key Files and Directories

- **src/Types.res** - Complete type system, core domain model
- **src/Pipeline.res** - Orchestration logic, main entry point
- **src/ConflictResolver.res** - 6 built-in resolution rules
- **src/Deduplicator.res** - SHA-256 hashing, normalization
- **src/ArangoClient.res** - Database operations, graph queries
- **justfile** - Build automation with 25+ recipes
- **docs/doc-reconciliation-architecture.adoc** - Full architecture docs
- **Dockerfile** - Multi-stage build (ReScript + Haskell)

## Common Tasks

### Adding a New Resolution Rule

1. Edit `src/ConflictResolver.res`
2. Add rule to `builtInRules` array
3. Specify priority and confidence
4. Implement `applies` and `resolve` functions
5. Add test in `tests/TestRunner.res`

### Adding a New Document Type

1. Edit `src/Types.res`
2. Add variant to `documentType` enum
3. Update `documentTypeToString` and `documentTypeFromString`
4. Add detection logic in `Pipeline.scanRepository`
5. Optionally add validation in `validator/DocumentValidator.hs`

### Extending LLM Integration

1. Edit `src/LLMIntegration.res`
2. Add new prompt type to `llmPromptType`
3. Create prompt template function
4. **CRITICAL**: Ensure `requiresApproval: true`
5. Add validation logic
6. Update audit trail

### Debugging

- Check ReScript compilation: `npm run build`
- View generated JS: `lib/js/src/*.bs.js`
- Enable verbose logging in Pipeline
- Use ArangoDB web UI: http://localhost:8529
- Check Docker logs: `docker-compose logs -f`

## Dependencies

### Production

- **rescript** (^11.0.1) - ReScript compiler
- **@rescript/core** (^1.5.0) - Standard library
- **arangojs** (^8.8.1) - ArangoDB client

### Development

- **just** - Build automation
- **docker** - Containerization
- **ghc/cabal** - Haskell compiler (for validator)

## Environment Variables

```bash
# ArangoDB connection
ARANGO_URL=http://localhost:8529
ARANGO_DATABASE=reconciliation
ARANGO_USERNAME=root
ARANGO_PASSWORD=<secret>

# LLM integration (optional)
ANTHROPIC_API_KEY=<key>
OPENAI_API_KEY=<key>

# Validation (optional)
VALIDATOR_PATH=/usr/local/bin/validator-bridge
```

## Additional Resources

- **Architecture Docs**: docs/doc-reconciliation-architecture.adoc
- **Implementation Summary**: docs/IMPLEMENTATION-SUMMARY.adoc
- **ReScript Docs**: https://rescript-lang.org/docs
- **ArangoDB Docs**: https://www.arangodb.com/docs
- **Just Manual**: https://just.systems/man

## Notes for Claude

### Current Focus

Phase 1 MVP is COMPLETE. All core features implemented:

- ✅ Content-addressable deduplication
- ✅ Conflict resolution with confidence scoring
- ✅ ArangoDB graph storage
- ✅ Idempotent pipeline
- ✅ LLM integration with guardrails
- ✅ Logical inference (miniKanren/Datalog)
- ✅ Haskell validation bridge
- ✅ CCCP compliance checking
- ✅ Graph visualization
- ✅ Docker deployment
- ✅ Comprehensive tests
- ✅ CI/CD automation

### Important Constraints

1. **Type Safety**: Never bypass ReScript's type system
2. **Idempotency**: All operations must be rerunnable
3. **LLM Guardrails**: NEVER auto-commit LLM output, always `requiresApproval: true`
4. **Content Hashing**: Use SHA-256 for all content hashing
5. **Confidence Threshold**: Default 0.9 for auto-resolution
6. **Database**: ArangoDB is multi-model (document + graph)
7. **No Python**: CCCP compliance - recommend ReScript/Deno migrations

### Code Patterns to Follow

```rescript
// Good: Pattern matching with exhaustiveness
let docType = switch doc.metadata.documentType {
| README => "readme"
| LICENSE => "license"
| SECURITY => "security"
// ... all variants covered
}

// Good: Belt for functional operations
documents->Belt.Array.map(doc => doc.hash)

// Good: Result type for error handling
let result: result<document, string> = ...
switch result {
| Ok(doc) => // handle success
| Error(msg) => // handle error
}

// Good: Confidence scoring
let resolution = {
  confidence: 0.95,
  requiresApproval: false, // Only if > threshold
  ...
}
```

### Code Patterns to Avoid

```rescript
// Bad: Throwing exceptions (use Result instead)
raise(Js.Exn.raiseError("error"))

// Bad: Mutable state (use immutable by default)
let x = ref(0)

// Bad: Auto-committing LLM output
let llmResponse = {
  requiresApproval: false, // NEVER DO THIS
  ...
}

// Bad: Bypassing type system
%raw(`unsafe.js.code()`)
```

### Testing Strategy

1. **Unit Tests**: Test individual functions in TestRunner.res
2. **Integration Tests**: Test full pipeline with real data
3. **Type Tests**: Rely on ReScript compiler for type safety
4. **Property Tests**: Consider adding property-based tests

Before committing:
```bash
npm run build  # Ensure compilation
npm test       # Run all tests
just ci        # Run full CI checks locally
```

### Critical Invariants

1. **Same hash = same content** - Deduplication guarantee
2. **Confidence > 0.9 = auto-resolve** - Resolution threshold
3. **LLM output requires approval** - Never auto-commit
4. **Canonical source priority** - Explicit > File > Inferred
5. **Idempotent stages** - Can rerun any stage safely

### Performance Considerations

- Deduplication is O(n) in document count
- Hash generation is O(m) in content length
- Graph queries are indexed by hash
- Batch database operations when possible

## Contact

- **Repository**: https://github.com/Hyperpolymath/recon-silly-ation
- **Issues**: https://github.com/Hyperpolymath/recon-silly-ation/issues
- **Maintainer**: Hyperpolymath

---

*Last Updated: 2025-11-22*
*This document should be updated as the project evolves.*
*Phase 1 MVP: COMPLETE ✅*
