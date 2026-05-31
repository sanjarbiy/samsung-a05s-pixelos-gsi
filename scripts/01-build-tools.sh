#!/bin/bash
# Build lpunpack + lpmake (+ lpdump) from source.
# These read/write Android dynamic-partition (super) images.
# Needs: clang, git  (apt-get install -y clang lz4 android-sdk-libsparse-utils e2fsprogs git)
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
BUILD="${1:-$HERE/../.tools}"
mkdir -p "$BUILD"; cd "$BUILD"

if [ ! -d lpunpack_and_lpmake ]; then
  git clone --depth 1 https://github.com/LonelyFool/lpunpack_and_lpmake
fi
cd lpunpack_and_lpmake

# Fix: newer libstdc++ needs <algorithm> for std::find/std::sort in liblp.
for f in lib/liblp/*.cpp; do
  grep -q '#include <algorithm>' "$f" || sed -i '1i #include <algorithm>' "$f"
done

bash make.sh
echo
echo "Built:"
find "$PWD" -type f -executable \( -name lpmake -o -name lpunpack -o -name lpdump \) -print
echo
echo "Add to PATH or note: $PWD/bin"
