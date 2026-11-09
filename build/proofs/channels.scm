;; SPDX-License-Identifier: MPL-2.0
;; Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
;;
;; The Guix revision the proof toolchain comes from, pinned so a proof run is
;; reproducible (PROOF-POLICY §6). Used as:
;;
;;   guix time-machine -C build/proofs/channels.scm -- \
;;     shell --rebuild-cache -m build/proofs/manifest.scm -- \
;;     bash build/proofs/check-in-guix.sh idris2
;;
;; Guix moved from Savannah to Codeberg in 2025; the introduction (first signed
;; commit and its key) is the one in the Guix manual, unchanged by the move.

(list (channel
        (name 'guix)
        (url "https://codeberg.org/guix/guix.git")
        (branch "master")
        (commit "ebdc236c6770f15e9c8298356fd40c4b024c7083")  ; 2026-10-24
        (introduction
         (make-channel-introduction
          "9edb3f66fd807b096b48283debdcddccfea34bad"
          (openpgp-fingerprint
           "BBB0 2DDF 2CEA F6A8 0D1D  E643 A2A0 6DF2 A33A 54FA")))))
