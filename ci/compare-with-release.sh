#!/bin/sh
# Assemble gas's MIPS test sources with a new `as` and with the same platform's `as` from an earlier release, little-
# and big-endian, and fail if any object or any assembler message differs: a rebuild (another host compiler, a new
# architecture) must not change what this assembler produces, which decomp projects match byte for byte.
#
#   sh ci/compare-with-release.sh NEW_AS RELEASE_ARCHIVE_URL
set -eu

NEW_AS=$1
URL=$2
ROOT=$(cd "$(dirname "$0")/.." && pwd)
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

curl -fsSL "$URL" | tar -xzf - -C "$WORK" as
OLD_AS="$WORK/as"
same=0; failed_alike=0; differ=0
for src in "$ROOT"/gas/testsuite/gas/mips/*.s; do
  for endian in -EL -EB; do
    "$OLD_AS" $endian -o "$WORK/old.o" "$src" > "$WORK/old.msg" 2>&1 && old=0 || old=$?
    "$NEW_AS" $endian -o "$WORK/new.o" "$src" > "$WORK/new.msg" 2>&1 && new=0 || new=$?
    # the messages name the file the same way for both: only the assembler differs
    if [ "$old" -ne "$new" ] || ! cmp -s "$WORK/old.msg" "$WORK/new.msg"; then
      echo "DIFFERENT exit status or messages: $(basename "$src") $endian"; differ=$((differ + 1))
    elif [ "$old" -ne 0 ]; then
      failed_alike=$((failed_alike + 1))
    elif cmp -s "$WORK/old.o" "$WORK/new.o"; then
      same=$((same + 1))
    else
      echo "DIFFERENT object: $(basename "$src") $endian"; differ=$((differ + 1))
    fi
    rm -f "$WORK/old.o" "$WORK/new.o"
  done
done
echo "identical: $same, failing identically: $failed_alike, different: $differ"
[ "$differ" -eq 0 ] && [ "$same" -gt 0 ]
