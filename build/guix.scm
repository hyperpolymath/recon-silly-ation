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

(use-modules (guix packages)
             (guix gexp)
             (guix git-download)
             (guix build-system gnu)
             (guix licenses)
             (gnu packages base)
             (gnu packages zig))

(package
  (name "recon-silly-ation")
  (version "0.1.0")
  (source (local-file "." "source"
                       #:recursive? #t
                       #:select? (lambda (file stat)
                                   (not (string-contains file ".git")))))
  (build-system gnu-build-system)
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
