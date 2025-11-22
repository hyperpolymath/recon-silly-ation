// Test runner for recon-silly-ation
// Comprehensive test suite for all modules

open Types

// Test result
type testResult = {
  name: string,
  passed: bool,
  message: string,
}

// Test suite
let tests = []
let testsPassed = ref(0)
let testsFailed = ref(0)

// Assert helper
let assert = (name: string, condition: bool, message: string): testResult => {
  if condition {
    testsPassed := testsPassed.contents + 1
    {name: name, passed: true, message: "✓ " ++ message}
  } else {
    testsFailed := testsFailed.contents + 1
    {name: name, passed: false, message: "✗ " ++ message}
  }
}

// Run all tests
let runTests = (): unit => {
  Js.Console.log("=== Running Test Suite ===\n")

  // Test: Deduplicator
  Js.Console.log("Testing Deduplicator...")

  let testContent1 = "# README\n\nHello world"
  let testContent2 = "# README\n\nHello world"
  let testContent3 = "# README\n\nDifferent content"

  let hash1 = Deduplicator.hashContent(testContent1)
  let hash2 = Deduplicator.hashContent(testContent2)
  let hash3 = Deduplicator.hashContent(testContent3)

  tests
  ->Js.Array2.push(
    assert(
      "dedup-hash-same",
      hash1 == hash2,
      "Same content produces same hash",
    ),
  )
  ->ignore

  tests
  ->Js.Array2.push(
    assert(
      "dedup-hash-different",
      hash1 != hash3,
      "Different content produces different hash",
    ),
  )
  ->ignore

  let metadata1: documentMetadata = {
    path: "README.md",
    documentType: README,
    lastModified: 1000.0,
    version: None,
    canonicalSource: Inferred,
    repository: "test/repo",
    branch: "main",
  }

  let doc1 = Deduplicator.createDocument(testContent1, metadata1)

  tests
  ->Js.Array2.push(
    assert(
      "dedup-doc-hash",
      Js.String2.length(doc1.hash) > 0,
      "Document hash is generated",
    ),
  )
  ->ignore

  // Test: Version comparison
  Js.Console.log("Testing Versions...")

  let v1: version = {major: 1, minor: 0, patch: 0}
  let v2: version = {major: 1, minor: 1, patch: 0}
  let v3: version = {major: 2, minor: 0, patch: 0}

  tests
  ->Js.Array2.push(
    assert(
      "version-compare-less",
      compareVersions(v1, v2) < 0,
      "1.0.0 < 1.1.0",
    ),
  )
  ->ignore

  tests
  ->Js.Array2.push(
    assert(
      "version-compare-greater",
      compareVersions(v3, v2) > 0,
      "2.0.0 > 1.1.0",
    ),
  )
  ->ignore

  // Test: Conflict detection
  Js.Console.log("Testing Conflict Detection...")

  let metadata2: documentMetadata = {
    ...metadata1,
    path: "docs/README.md",
    lastModified: 2000.0,
  }

  let doc2 = Deduplicator.createDocument(testContent1, metadata2)

  let conflicts = ConflictResolver.detectConflicts([doc1, doc2])

  tests
  ->Js.Array2.push(
    assert(
      "conflict-detection",
      Belt.Array.length(conflicts) > 0,
      "Detects duplicate content conflict",
    ),
  )
  ->ignore

  // Test: Conflict resolution
  Js.Console.log("Testing Conflict Resolution...")

  switch conflicts->Belt.Array.get(0) {
  | None => ()
  | Some(conflict) => {
      let resolution = ConflictResolver.resolveConflict(conflict, 0.9)

      tests
      ->Js.Array2.push(
        assert(
          "conflict-resolution",
          resolution.confidence > 0.0,
          "Generates resolution with confidence",
        ),
      )
      ->ignore

      tests
      ->Js.Array2.push(
        assert(
          "conflict-auto-resolve",
          !resolution.requiresApproval || resolution.confidence < 0.9,
          "Auto-resolve logic works correctly",
        ),
      )
      ->ignore
    }
  }

  // Test: Canonical source priority
  Js.Console.log("Testing Canonical Sources...")

  let licensePriority = Deduplicator.getCanonicalPriority(LicenseFile)
  let inferredPriority = Deduplicator.getCanonicalPriority(Inferred)

  tests
  ->Js.Array2.push(
    assert(
      "canonical-priority",
      licensePriority > inferredPriority,
      "LICENSE file has higher priority than inferred",
    ),
  )
  ->ignore

  // Test: Document type conversion
  Js.Console.log("Testing Document Types...")

  let readmeStr = documentTypeToString(README)
  let readmeType = documentTypeFromString(readmeStr)

  tests
  ->Js.Array2.push(
    assert(
      "doctype-conversion",
      readmeType == README,
      "Document type round-trip conversion works",
    ),
  )
  ->ignore

  // Test: Logic engine
  Js.Console.log("Testing Logic Engine...")

  let kb = LogicEngine.createKnowledgeBase()
  let kb = LogicEngine.addFact(
    kb,
    LogicEngine.Compound("test", [LogicEngine.Atom("value")]),
  )

  tests
  ->Js.Array2.push(
    assert(
      "logic-kb-create",
      Belt.Array.length(kb.facts) > 0,
      "Knowledge base can store facts",
    ),
  )
  ->ignore

  let relationships = LogicEngine.inferRelationships([doc1, doc2])

  tests
  ->Js.Array2.push(
    assert(
      "logic-inference",
      Belt.Array.length(relationships) > 0,
      "Logic engine infers relationships",
    ),
  )
  ->ignore

  // Test: Graph visualization
  Js.Console.log("Testing Graph Visualization...")

  let edges = Deduplicator.createDuplicateEdges([(doc2, doc1)])
  let dot = GraphVisualizer.generateDot([doc1, doc2], edges, GraphVisualizer.defaultConfig)

  tests
  ->Js.Array2.push(
    assert(
      "graph-dot-generation",
      Js.String2.includes(dot, "digraph"),
      "Generates valid DOT format",
    ),
  )
  ->ignore

  let mermaid = GraphVisualizer.generateMermaid([doc1, doc2], edges)

  tests
  ->Js.Array2.push(
    assert(
      "graph-mermaid-generation",
      Js.String2.includes(mermaid, "graph"),
      "Generates valid Mermaid format",
    ),
  )
  ->ignore

  // Test: CCCP compliance
  Js.Console.log("Testing CCCP Compliance...")

  let isPython = CCCPCompliance.isPythonFile("test.py")
  let isNotPython = CCCPCompliance.isPythonFile("test.js")

  tests
  ->Js.Array2.push(
    assert(
      "cccp-python-detect",
      isPython && !isNotPython,
      "Correctly detects Python files",
    ),
  )
  ->ignore

  // Print results
  Js.Console.log("\n=== Test Results ===")
  tests->Belt.Array.forEach(test => {
    if test.passed {
      Js.Console.log(test.message)
    } else {
      Js.Console.error(test.message)
    }
  })

  Js.Console.log(`\nTotal: ${tests->Belt.Array.length->Int.toString}`)
  Js.Console.log(`Passed: ${testsPassed.contents->Int.toString}`)
  Js.Console.log(`Failed: ${testsFailed.contents->Int.toString}`)

  if testsFailed.contents > 0 {
    Js.Console.log("\n❌ Some tests failed")
    %raw(`process.exit(1)`)
  } else {
    Js.Console.log("\n✅ All tests passed!")
    %raw(`process.exit(0)`)
  }
}

// Auto-run tests
let _ = runTests()
