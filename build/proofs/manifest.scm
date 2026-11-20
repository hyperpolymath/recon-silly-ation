;; SPDX-License-Identifier: MPL-2.0
;; Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
;;
;; The proof toolchain for scripts/check-proofs.sh, from the Guix revision
;; pinned in channels.scm (PROOF-POLICY §6: a Guix manifest).
;;
;; Coq and Lean 4 are Guix packages as they stand. Two others need help here,
;; and both fixes are candidates to offer upstream to Guix:
;;
;; - Idris2. Guix has no Idris2 package (its Idris 1 module was removed on
;;   2026-01-05). `idris2-0.7` packages Idris2 0.7.0, the version the
;;   repository's proofs were checked with, bootstrapped from its Chez Scheme
;;   sources. It bootstraps on Guix's Chez Scheme 10.4.0; what failed at
;;   first was the "#!/bin/sh" launcher the bootstrap writes and then runs.
;;   The source hash is `guix hash -x --serializer=nar` of the v0.7.0 checkout
;;   (commit 2778007).
;; - Agda. Guix's agda 2.7.0.1 ships no interface files for its primitive
;;   modules (lib/prim), so the first check writes them into the read-only
;;   store and fails ("createDirectory: permission denied", exit 42); that is
;;   why agda-stdlib does not build at the pinned revision. Guix master has the
;;   same package. `agda-with-primitives` compiles them into a data directory
;;   of its own and points Agda at it (Agda_datadir).
;;
;; Built with `guix time-machine -C build/proofs/channels.scm -- build -m
;; build/proofs/manifest.scm` on 2026-11-17.

(use-modules (guix packages)
             (guix gexp)
             (guix git-download)
             (guix utils)
             (guix build-system gnu)
             (guix build-system trivial)
             ((guix licenses) #:prefix license:)
             (gnu packages agda)
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
          ;; The Chez and Racket backends write launcher scripts that begin
          ;; with "#!/bin/sh", and the bootstrap runs them; the build
          ;; container has no /bin/sh. Point them at bash-minimal, in the
          ;; compiler sources and in the bootstrap's pre-generated Scheme.
          (add-after 'unpack 'patch-generated-shebangs
            (lambda* (#:key inputs #:allow-other-keys)
              (let ((sh (search-input-file inputs "bin/sh")))
                (substitute* '("src/Compiler/Scheme/Chez.idr"
                               "src/Compiler/Scheme/ChezSep.idr"
                               "src/Compiler/Scheme/Racket.idr"
                               "bootstrap/idris2_app/idris2.ss")
                  (("#!/bin/sh") (string-append "#!" sh))))))
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

(define agda-with-primitives
  (package
    (name "agda-with-primitives")
    (version (package-version agda))
    (source #f)
    (build-system trivial-build-system)
    (arguments
     (list
      #:modules '((guix build utils))
      #:builder
      #~(begin
          (use-modules (guix build utils))
          (let* ((agda #$(this-package-input "agda"))
                 (real (string-append agda "/bin/agda"))
                 (shipped (find-files (string-append agda "/share")
                                      "^Agda-[0-9.]+$" #:directories? #t))
                 (data (string-append #$output "/share/agda-data"))
                 (prim (string-append data "/lib/prim"))
                 (bin (string-append #$output "/bin")))
            (unless (= 1 (length shipped))
              (error "expected one Agda data directory, found" shipped))
            (copy-recursively (car shipped) data)
            (for-each make-file-writable (find-files data))
            (setenv "HOME" (getcwd))
            (setenv "Agda_datadir" data)
            (with-directory-excursion prim
              (for-each (lambda (f) (invoke real f))
                        (find-files "." "\\.agda$")))
            (when (null? (find-files prim "\\.agdai$"))
              (error "no primitive interfaces were written under" prim))
            (mkdir-p bin)
            (call-with-output-file (string-append bin "/agda")
              (lambda (port)
                (format port "#!~a~%export Agda_datadir=~s~%exec ~s \"$@\"~%"
                        #$(file-append bash-minimal "/bin/sh") data real)))
            (chmod (string-append bin "/agda") #o555)))))
    (inputs (list agda bash-minimal))
    (search-paths (package-search-paths agda))
    (native-search-paths (package-native-search-paths agda))
    (home-page (package-home-page agda))
    (synopsis "Agda with its primitive modules compiled")
    (description
     "This runs Guix's Agda with a data directory in which the primitive
modules (Agda.Primitive and the other built-in modules) are already compiled,
so checking a file does not need to write to the store.")
    (license (package-license agda))))

;; agda-stdlib, compiled by agda-with-primitives so that its interfaces
;; match the Agda in the profile.
(define agda-stdlib/primitives
  (package
    (inherit agda-stdlib)
    (arguments
     (cons* #:agda agda-with-primitives (package-arguments agda-stdlib)))))

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
                (if (want? "coq") '("coq") '())
                (if (want? "lean4") '("lean4") '())))
       (packages->manifest
        (append (if (want? "idris2") (list idris2-0.7) '())
                (if (want? "agda")
                    (list agda-with-primitives agda-stdlib/primitives)
                    '())))))
