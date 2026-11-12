#!/bin/sh
# binutils 2.6 for macOS as universal binaries (arm64 + x86_64): ar, as, strip, objcopy and c++filt in OUT
# (default: ./dist). Apple Silicon runs them natively; before this the macOS release was an Intel build, which on
# an Apple Silicon Mac without Rosetta fails with "Bad CPU type in executable".
#
#   sh macos/build.sh [OUT]
#
# Each architecture is configured and built in its own copy of the tree (the configure scripts work in-tree).
# The same configure options as the Linux build; on macOS one more step: gas's configure (autoconf 2.x) tests for
# `inline` with a program modern clang rejects, decides the compiler has none and writes `#define inline` (empty)
# into gas/config.h, after which the SDK headers' inline functions (isalpha, __sputc...) are emitted in every object
# file and the link fails with duplicate symbols. The define is taken out once gas's config.h exists.
#
# Checked against the previous Intel-only release: all 3,898 C files of a PS1 game's exported decomp that compile,
# assembled from GCC 2.7.2 and 2.8.1 output at -O2 -G8, -O1, -O0 -G0, give byte-identical objects and identical
# assembler messages with the arm64 slice, the x86_64 slice and the old release's `as`; ar, objcopy, strip and
# c++filt likewise.
set -eu

ROOT=$(cd "$(dirname "$0")/.." && pwd)
OUT=${1:-"$ROOT/dist"}
mkdir -p "$OUT"
OUT=$(cd "$OUT" && pwd)  # (the build cds into each tree: a relative OUT would land there)
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
CFLAGS_COMMON="-DDARWIN -Wno-return-type -Wno-error -Wno-implicit-function-declaration -U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=0"
PROGRAMS="ar as strip objcopy c++filt"

# run LOG COMMAND...: the command's output in LOG, and its last lines shown if it fails
run() {
  log=$1; shift
  "$@" > "$log" 2>&1 || { echo "failed: $* (last lines of $log)" >&2; tail -40 "$log" >&2; exit 1; }
}

for arch in arm64 x86_64; do
  tree="$WORK/$arch"
  mkdir -p "$tree"
  (cd "$ROOT" && tar --exclude=./.git --exclude=./dist -cf - .) | (cd "$tree" && tar -xf -)
  cd "$tree"
  run configure.log env CC="cc -arch $arch" ./configure --target=mips-kmc-elf --prefix=/opt/cross --disable-gprof \
    --disable-gdb --disable-werror --host=i386-apple-darwin --build=i386-apple-darwin
  for d in bfd opcodes libiberty; do
    run "make-$d.log" make -C "$d" CC="cc -arch $arch" CFLAGS="-arch $arch $CFLAGS_COMMON"
  done
  run make-gas-config.log make -C gas CC="cc -arch $arch" config.h
  sed -i '' 's|^#define inline *$|/* #undef inline: clang has it (see macos/build.sh) */|' gas/config.h
  for d in gas binutils; do
    run "make-$d.log" make -C "$d" CC="cc -arch $arch" CFLAGS="-arch $arch $CFLAGS_COMMON"
  done
  mkdir -p "$WORK/out-$arch"
  cp binutils/ar "$WORK/out-$arch/ar"
  cp gas/as.new "$WORK/out-$arch/as"
  cp binutils/strip.new "$WORK/out-$arch/strip"
  cp binutils/objcopy "$WORK/out-$arch/objcopy"
  cp binutils/c++filt "$WORK/out-$arch/c++filt"
  for p in $PROGRAMS; do
    strip "$WORK/out-$arch/$p"
  done
done

mkdir -p "$OUT"
for p in $PROGRAMS; do
  lipo -create "$WORK/out-arm64/$p" "$WORK/out-x86_64/$p" -output "$OUT/$p"
  chmod +x "$OUT/$p"
done
lipo -info "$OUT"/*
