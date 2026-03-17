#!/bin/bash
# Build the critical-section micro-benchmark C extensions.
#
# Usage: ./build_extensions.sh /path/to/cpython/build /path/to/output
#   $1 = CPython build tree (with ./python and Include/)
#   $2 = Output directory for .so files

set -euo pipefail

CPYTHON="$1"
OUTDIR="${2:-.}"
PYTHON="$CPYTHON/python"

# Get python extension suffix
EXT_SUFFIX=$("$PYTHON" -c "import sysconfig; print(sysconfig.get_config_var('EXT_SUFFIX'))")

SCRIPTDIR="$(cd "$(dirname "$0")" && pwd)"

# For a non-installed build tree, Include/ has headers and pyconfig.h is
# in the build root directory.
CPYTHON_INCLUDE="$CPYTHON/Include"
INTERNAL_INCLUDE="$CPYTHON/Include/internal"
PYCONFIG_DIR="$CPYTHON"   # pyconfig.h lives in the build root

mkdir -p "$OUTDIR"

echo "Building extensions for $("$PYTHON" --version) ..."
echo "  EXT_SUFFIX=$EXT_SUFFIX"

# 1) Public API extension (non-inlined path)
echo "  _bench_critsec_ext${EXT_SUFFIX}"
clang-20 -shared -fPIC -O2 \
    -I"$CPYTHON_INCLUDE" -I"$PYCONFIG_DIR" \
    -o "$OUTDIR/_bench_critsec_ext${EXT_SUFFIX}" \
    "$SCRIPTDIR/_bench_critsec_ext.c"

# 2) Py_BUILD_CORE extension (inlined fast path)
echo "  _bench_critsec_core${EXT_SUFFIX}"
clang-20 -shared -fPIC -O2 \
    -I"$CPYTHON_INCLUDE" -I"$PYCONFIG_DIR" -I"$INTERNAL_INCLUDE" \
    -DPy_BUILD_CORE_MODULE \
    -o "$OUTDIR/_bench_critsec_core${EXT_SUFFIX}" \
    "$SCRIPTDIR/_bench_critsec_core.c"

echo "Done."
