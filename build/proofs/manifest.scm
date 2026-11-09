;; SPDX-License-Identifier: MPL-2.0
;; Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
;;
;; The proof toolchain for scripts/check-proofs.sh, from the Guix revision
;; pinned in channels.scm (PROOF-POLICY §6: a Guix manifest).
;;
;; Agda, its standard library, Coq and Lean 4 are Guix packages. Idris2 is
;; not: Guix removed its Idris packages on 2026-01-05 ("gnu: Remove (gnu
;; packages idris)"). `idris2` below packages Idris2 0.7.0, the version the
;; repository's proofs were checked with, bootstrapped from its Chez Scheme
;; sources. Once it builds here it is a candidate to offer upstream to Guix.
;;
;; EXPERIMENTAL until CI has built it: Guix's Chez Scheme is 10.x, and Idris2
;; 0.7.0 predates Chez 10. The source hash below is `guix hash -x
;; --serializer=nar` of the v0.7.0 checkout (commit 2778007), computed with
;; Guix 1.4.0 on 2026-11-09.

(use-modules (guix packages)
             (guix gexp)
             (guix git-download)
             (guix utils)
             (guix build-system gnu)
             ((guix licenses) #:prefix license:)
             (gnu packages bash)
             (gnu packages chez)
             (gnu packages multiprecision))

(define idris2-0.7
  (package
    (name "idris2")
    (version "0.7.0")
    (source (origin
              (method git-fetch)
              (uri (git-reference
                    (url "https://github.com/idris-lang/Idris2")
                    (commit (string-append "v" version))))
              (file-name (git-file-name name version))
              (sha256
               (base32
                "0qxfwsm2gxjxwzni85jb5b4snvjf77knqs9bnd2bqznrfxgxw2sp"))))
    (build-system gnu-build-system)
    (arguments
     (list
      #:tests? #f
      #:make-flags
      #~(list (string-append "PREFIX=" #$output)
              "SCHEME=scheme"
              (string-append "CC=" #$(cc-for-target)))
      #:phases
      #~(modify-phases %standard-phases
          (delete 'bootstrap)
          (delete 'configure)
          (add-before 'build 'set-home
            (lambda _ (setenv "HOME" "/tmp")))
          (replace 'build
            (lambda* (#:key make-flags #:allow-other-keys)
              (apply invoke "make" "bootstrap" make-flags)))
          (add-after 'install 'wrap-idris2
            (lambda* (#:key inputs #:allow-other-keys)
              (let ((chez (dirname (search-input-file inputs "bin/scheme")))
                    (prefix (string-append #$output "/idris2-" #$version)))
                (wrap-program (string-append #$output "/bin/idris2")
                  `("PATH" ":" prefix (,chez))
                  `("IDRIS2_PREFIX" = (,#$output))
                  `("LD_LIBRARY_PATH" ":" prefix
                    (,(string-append prefix "/lib"))))))))))
    (inputs (list bash-minimal chez-scheme gmp))
    (home-page "https://www.idris-lang.org/")
    (synopsis "Purely functional programming language with dependent types")
    (description
     "Idris2 is a purely functional programming language with first-class
types and quantitative type theory.  This builds version 0.7.0 from its Chez
Scheme bootstrap.")
    (license license:bsd-3)))

;; PROOF_PROVERS (space-separated: idris2 agda coq lean4) narrows the
;; manifest, so one prover's build failure does not block the others' jobs.
;; Unset, it holds every prover.
(define wanted
  (let ((v (getenv "PROOF_PROVERS")))
    (if (and v (not (string-null? v)))
        (string-tokenize v)
        '("idris2" "agda" "coq" "lean4"))))

(define (want? p) (member p wanted))

(concatenate-manifests
 (list (specifications->manifest
        (append '("bash" "coreutils" "diffutils" "findutils" "gawk" "grep" "sed")
                (if (want? "agda") '("agda" "agda-stdlib") '())
                (if (want? "coq") '("coq") '())
                (if (want? "lean4") '("lean4") '())))
       (packages->manifest
        (if (want? "idris2") (list idris2-0.7) '()))))
