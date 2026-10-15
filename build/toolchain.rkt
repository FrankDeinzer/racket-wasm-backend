#lang racket/base
;; Resolve (and, for Chez, optionally build) the two host toolchains the cross
;; build needs:
;;   * a native *threaded* host Chez Scheme -- the cross-compiler host that
;;     generates the tpb32l boot files / xpatch (build-wasm.md stage 0/3).
;;   * a same-version host Racket -- the `raco setup` `--cross-server`.
;;
;; Both can be passed explicitly (--scheme / --racket). If --scheme is omitted
;; and none is found, a threaded Chez is bootstrapped in the clone's ChezScheme
;; tree (./configure --threads && make), exactly as build-wasm.md stage 0 does.
(require racket/file
         racket/path
         racket/string
         "config.rkt"
         "util.rkt")

(provide resolve-host-scheme resolve-host-racket)

;; --- host Chez ----------------------------------------------------------

(define chez-src (build-path clone-dir "racket" "src" "ChezScheme"))

;; Look for an already-built threaded host Chez:
;;   * a prior `make cs`:   racket/src/build/cs/c/ChezScheme/<mach>/bin/<mach>/scheme
;;   * a prior stage-0:     racket/src/ChezScheme/<mach>/bin/<mach>/scheme
(define (find-built-scheme)
  (define roots
    (list (build-path clone-dir "racket" "src" "build" "cs" "c" "ChezScheme")
          chez-src))
  (for*/first ([root (in-list roots)]
               #:when (directory-exists? root)
               [mach (in-list (if (directory-exists? root) (directory-list root) '()))]
               ;; threaded native machine: t<arch>. Exclude the portable-bytecode
               ;; machines (tpb*): `tpb32l` is the WASM *target* (its `scheme` is a
               ;; JS wrapper + .wasm, not runnable here) and appears in the same build
               ;; dir after the first partial wasm build.
               #:when (and (regexp-match? #rx"^t" (path->string mach))
                           (not (regexp-match? #rx"^tpb" (path->string mach))))
               [exe (in-value (build-path root mach "bin" mach "scheme"))]
               #:when (file-exists? exe))
    exe))

(define (build-host-scheme!)
  (info-msg "no host Chez found; bootstrapping a threaded one (stage 0)")
  ;; The pb boot files let a plain ./configure build a native threaded Chez without
  ;; an existing scheme. Since Racket 9.3 they are NOT in the tree: `make fetch-pb`
  ;; clones them from https://github.com/racket/pb (branch PB_BRANCH = v9.3) into
  ;; racket/src/ChezScheme/boot/pb. Without them ./configure fails with "No suitable
  ;; machine type found in ./boot". See build-wasm.md "qt-wasm: Racket 9.3 rebase".
  (unless (directory-exists? (build-path chez-src "boot" "pb"))
    (info-msg "fetching pb boot files (make fetch-pb: git clone racket/pb)")
    (run "make" #:dir clone-dir #:args (list "fetch-pb")))
  (run "sh" #:dir chez-src #:args (list "-c" "./configure --threads && make"))
  (or (find-built-scheme)
      (error 'toolchain "host Chez build completed but no scheme binary found under ~a" chez-src)))

(define (resolve-host-scheme [explicit #f])
  (define s (or explicit (find-built-scheme) (build-host-scheme!)))
  (define p (if (path? s) s (string->path s)))
  (unless (file-exists? p)
    (error 'toolchain "host Chez not executable: ~a" p))
  (info-msg "host Chez: ~a" p)
  (path->string (path->complete-path p)))

;; --- host Racket --------------------------------------------------------

(define (find-host-racket)
  ;; Prefer one inside the clone (a prior `make cs`), then PATH.
  (define in-clone (build-path clone-dir "racket" "bin" "racket"))
  (cond
    [(file-exists? in-clone) in-clone]
    [(find-executable-path "racket") => values]
    [else #f]))

(define (resolve-host-racket [explicit #f])
  (define r (or explicit (find-host-racket)))
  (unless r
    (error 'toolchain
           (string-append "no host Racket found. Pass --racket <path> to a Racket of the "
                          "same version as the pinned tree (it loads the version-stamped xpatch).")))
  (define p (if (path? r) r (string->path r)))
  (unless (file-exists? p)
    (error 'toolchain "host Racket not executable: ~a" p))
  (info-msg "host Racket: ~a" p)
  (path->string (path->complete-path p)))
