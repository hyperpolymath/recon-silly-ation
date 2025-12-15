;; SPDX-License-Identifier: AGPL-3.0-or-later
;; SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
;; ECOSYSTEM.scm — recon-silly-ation

(ecosystem
  (version "1.0.0")
  (name "recon-silly-ation")
  (type "project")
  (purpose "*Documentation Reconciliation System* - Automatically reconcile, deduplicate, and resolve conflicts in Git repository documentation using content-addressable storage and graph-based conflict resolutio...")

  (position-in-ecosystem
    "Part of hyperpolymath ecosystem. Follows RSR guidelines.")

  (related-projects
    (project (name "rhodium-standard-repositories")
             (url "https://github.com/hyperpolymath/rhodium-standard-repositories")
             (relationship "standard")))

  (what-this-is "*Documentation Reconciliation System* - Automatically reconcile, deduplicate, and resolve conflicts in Git repository documentation using content-addressable storage and graph-based conflict resolutio...")
  (what-this-is-not "- NOT exempt from RSR compliance"))
