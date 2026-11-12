# binutils 2.6 for MIPS: native on Apple Silicon

GNU binutils 2.6 (1996) built for `mips-kmc-elf`: `as`, `ar`, `objcopy`, `strip` and `c++filt`. Decompilation
projects for PS1 and N64 games assemble with it because its output is what the original toolchains produced, byte for
byte. The PS1 GCC toolchains of [decompals/old-gcc](https://github.com/decompals/old-gcc) bundle it.

This is a fork of [decompals/mips-binutils-2.6](https://github.com/decompals/mips-binutils-2.6). Its macOS release
is an Intel build, so on an Apple Silicon Mac without Rosetta it fails with `Bad CPU type in executable`, and so does
every toolchain that bundles it. This fork's releases are **universal binaries (arm64 + x86_64)**. The sources are
upstream's, unchanged.

## Download

[Releases](https://github.com/ianderse/mips-binutils-2.6/releases):

| Archive | For |
|---|---|
| `binutils-2.6-mac.tar.gz` | macOS, Apple Silicon and Intel (universal) |
| `binutils-2.6-linux.tar.gz` | Linux x86 (static) |

The macOS archive has the same name as upstream's, so a toolchain that unpacks upstream's can unpack this one instead.

## Same output as upstream

A rebuild must not change what the assembler produces, since projects match it byte for byte. Every CI run assembles
gas's MIPS test sources, little- and big-endian, with the new `as` and with upstream's v0.3 release for the same
platform. It fails if any object or any message differs (`ci/compare-with-release.sh`). Both macOS architectures are
checked, with upstream's Intel build under Rosetta.

Before v0.4 was released, the 3,898 compiling C files of a PS1 game's exported decompilation were also assembled from
GCC 2.7.2 and 2.8.1 output (at -O2 -G8, -O1 and -O0 -G0) with both macOS slices and upstream's Intel `as`. The objects
were byte-identical and the messages identical throughout. `ar`, `objcopy`, `strip` and `c++filt` likewise.

## Building

macOS (Xcode command line tools):

```sh
sh macos/build.sh        # universal binaries in ./dist
```

Each architecture is configured and built in its own copy of the tree, then combined with `lipo`. One step differs
from the Linux build. gas's 1990s `configure` decides from a failed test that the compiler has no `inline`, and writes
`#define inline` into `gas/config.h`, which makes the link fail. The script takes that line out (see its comments).

Linux: see `.github/workflows/build.yml`. It is upstream's build plus `-std=gnu89`, which current GCC (C23 by default)
needs for these sources.

## License

GPL-2.0, as upstream (`COPYING`). GNU's original README for the tools is in `README`.
