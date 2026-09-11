<<<<<<< HEAD
; SPDX-License-Identifier: MPL-2.0
;; guix.scm — GNU Guix package definition for squisher-corpus
;; Usage: guix shell -f guix.scm
=======
;; SPDX-License-Identifier: MPL-2.0
;; Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
;;
;; Guix package definition for recon-silly-ation
;;
;; Usage:
;;   guix shell -D -f guix.scm    # Enter development shell
;;   guix build -f guix.scm       # Build package
;;
;; The build/check phases below invoke the Zig FFI bridge in
;; src/interface/ffi/. See: https://guix.gnu.org/manual/en/html_node/Defining-Packages.html
>>>>>>> 988d4f5d011adea8df6b220bde58cf1d9bc85b26

(use-modules (guix packages)
             (guix build-system gnu)
<<<<<<< HEAD
             (guix licenses))

(package
  (name "squisher-corpus")
=======
             (guix licenses)
             (gnu packages base)
             (gnu packages zig))

(package
  (name "recon-silly-ation")
>>>>>>> 988d4f5d011adea8df6b220bde58cf1d9bc85b26
  (version "0.1.0")
  (source #f)
  (build-system gnu-build-system)
<<<<<<< HEAD
  (synopsis "squisher-corpus")
  (description "squisher-corpus — part of the hyperpolymath ecosystem.")
  (home-page "https://github.com/hyperpolymath/squisher-corpus")
  (license ((@@ (guix licenses) license) "PMPL-1.0-or-later"
             "https://github.com/hyperpolymath/palimpsest-license")))
=======
  (arguments
   '(#:phases
     (modify-phases %standard-phases
       (delete 'configure)
       (replace 'build
         (lambda _ (with-directory-excursion "src/interface/ffi" (invoke "zig" "build"))))
       (replace 'check
         (lambda* (#:key tests? #:allow-other-keys)
           (when tests?
             (with-directory-excursion "src/interface/ffi" (invoke "zig" "build" "test")))))
       (replace 'install
         (lambda* (#:key outputs #:allow-other-keys)
           (let ((out (assoc-ref outputs "out")))
             (mkdir-p (string-append out "/share/doc"))
             (copy-file "README.adoc"
                        (string-append out "/share/doc/README.adoc"))))))))
  (native-inputs
   (list zig))
  (inputs
   (list))
  (home-page "https://github.com/hyperpolymath/recon-silly-ation")
  (synopsis "Experimental cross-document consistency reconciler")
  (description "recon-silly-ation is intended to find and safely reconcile
contradictions across documentation, history, metadata, terminology, language
policy, and attribution. Its proposed bounded ForthWall execution layer and
reconcile action are not yet implemented or proved.")
  (license (list
            ;; MPL-2.0 extends MPL-2.0
            mpl2.0)))
>>>>>>> 988d4f5d011adea8df6b220bde58cf1d9bc85b26
