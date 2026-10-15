# FriBidi recipe.
#
# Unicode bidi algorithm; Pango's only hard text-layout dependency besides
# GLib/HarfBuzz. Pinned release tarball, built before pango. Without this
# recipe pango's meson falls back to its `fribidi` wrap-git subproject, which
# clones https://github.com/fribidi/fribidi.git at `revision = master` --
# unpinned and unreproducible (qt-wasm: found while building under Racket 9.3).
#
# The release ships no checksum; DEP_SOURCE_SHA256 was computed on the first
# download (trust-on-first-use) and the size matched the GitHub release asset
# (1203284 bytes). Tag v1.0.17 = b93119f5fdc7ea47672cc304c1455ffa6dfe7536.

DEP_NAME=fribidi
DEP_VERSION=1.0.17
DEP_SOURCE_URL=https://github.com/fribidi/fribidi/releases/download/v1.0.17/fribidi-1.0.17.tar.xz
DEP_SOURCE_SHA256=6949dcde27d41cebad1fd741fcafc36d55a1020d2d872d4a6eb3914caabbada2
DEP_BUILD_SYSTEM=meson
DEP_BUILD_ARGS=(
  -Ddocs=false
  -Dbin=false
  -Dtests=false
)
DEP_INSTALL_LIB=libfribidi.a
DEP_LINK_FLAGS=(-lfribidi)
DEP_SYMBOLS_MODE=none
