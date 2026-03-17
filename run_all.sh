#!/bin/bash
# Run all benchmarks for base and PR builds, write results to stdout.
#
# Usage: ./run_all.sh /path/to/cpython-base /path/to/cpython-pr

set -euo pipefail

BASE="${1:-/tmp/cpython-base}"
PR="${2:-/tmp/cpython-pr}"
SCRIPTDIR="$(cd "$(dirname "$0")" && pwd)"
FASTMARK="$HOME/fastmark"

echo "============================================"
echo "CPython Critical Section PR Benchmark"
echo "============================================"
echo
echo "BASE: $("$BASE/python" --version) @ $(git -C "$BASE" rev-parse --short HEAD)"
echo "PR:   $("$PR/python" --version) @ $(git -C "$PR" rev-parse --short HEAD)"
echo "Date: $(date -u '+%Y-%m-%d %H:%M UTC')"
echo "CPU:  $(lscpu | grep 'Model name' | sed 's/.*:\s*//')"
echo

# ---- Build C extensions ----
echo "Building C extensions for base..."
bash "$SCRIPTDIR/build_extensions.sh" "$BASE" "/tmp/bench-base"
echo "Building C extensions for PR..."
bash "$SCRIPTDIR/build_extensions.sh" "$PR" "/tmp/bench-pr"
echo

# ---- Install fastmark deps ----
for PY in "$BASE/python" "$PR/python"; do
    echo "Installing fastmark deps for $("$PY" --version)..."
    "$PY" -m pip install --quiet -r "$FASTMARK/requirements.txt" 2>&1 | tail -1 || true
done
echo

# ---- Fastmark ----
echo "============================================"
echo "1. FASTMARK BENCHMARKS"
echo "============================================"
echo
echo "--- BASE ---"
PYTHON_GIL=0 "$BASE/python" "$FASTMARK/fastmark.py" --json /tmp/fastmark-base.json
echo
echo "--- PR ---"
PYTHON_GIL=0 "$PR/python" "$FASTMARK/fastmark.py" --json /tmp/fastmark-pr.json
echo

# ---- Micro-benchmarks: interpreter core ----
echo "============================================"
echo "2. INTERPRETER CORE CRITICAL SECTIONS"
echo "============================================"
echo
echo "--- BASE ---"
PYTHON_GIL=0 "$BASE/python" "$SCRIPTDIR/bench_critsec_interp.py"
echo
echo "--- PR ---"
PYTHON_GIL=0 "$PR/python" "$SCRIPTDIR/bench_critsec_interp.py"
echo

# ---- Micro-benchmarks: C extension (public API) ----
echo "============================================"
echo "3. C EXTENSION CRITICAL SECTIONS (public API)"
echo "============================================"
echo
echo "--- BASE ---"
PYTHON_GIL=0 PYTHONPATH="/tmp/bench-base" "$BASE/python" -c "
import _bench_critsec_ext as ext, time, sys
print(f'Python {sys.version}')
print(f'GIL enabled: {sys._is_gil_enabled()}')
N = 20_000_000
obj1, obj2 = object(), object()
for name, func, args in [
    ('CS1 (Begin/End)', ext.bench_critical_section, (obj1, N)),
    ('CS2 (Begin2/End2)', ext.bench_critical_section2, (obj1, obj2, N)),
]:
    times = [func(*args) * 1000 for _ in range(7)]
    mn = min(times)
    mean = sum(times) / len(times)
    print(f'  {name:<30} mean={mean:.2f} ms  min={mn:.2f} ms')
"
echo
echo "--- PR ---"
PYTHON_GIL=0 PYTHONPATH="/tmp/bench-pr" "$PR/python" -c "
import _bench_critsec_ext as ext, time, sys
print(f'Python {sys.version}')
print(f'GIL enabled: {sys._is_gil_enabled()}')
N = 20_000_000
obj1, obj2 = object(), object()
for name, func, args in [
    ('CS1 (Begin/End)', ext.bench_critical_section, (obj1, N)),
    ('CS2 (Begin2/End2)', ext.bench_critical_section2, (obj1, obj2, N)),
]:
    times = [func(*args) * 1000 for _ in range(7)]
    mn = min(times)
    mean = sum(times) / len(times)
    print(f'  {name:<30} mean={mean:.2f} ms  min={mn:.2f} ms')
"
echo

# ---- Micro-benchmarks: Py_BUILD_CORE extension (inlined) ----
echo "============================================"
echo "4. Py_BUILD_CORE CRITICAL SECTIONS (inlined)"
echo "============================================"
echo
echo "--- BASE ---"
PYTHON_GIL=0 PYTHONPATH="/tmp/bench-base" "$BASE/python" -c "
import _bench_critsec_core as core, time, sys
print(f'Python {sys.version}')
print(f'GIL enabled: {sys._is_gil_enabled()}')
N = 20_000_000
obj1, obj2 = object(), object()
for name, func, args in [
    ('CS1 (Begin/End)', core.bench_critical_section, (obj1, N)),
    ('CS2 (Begin2/End2)', core.bench_critical_section2, (obj1, obj2, N)),
]:
    times = [func(*args) * 1000 for _ in range(7)]
    mn = min(times)
    mean = sum(times) / len(times)
    print(f'  {name:<30} mean={mean:.2f} ms  min={mn:.2f} ms')
"
echo
echo "--- PR ---"
PYTHON_GIL=0 PYTHONPATH="/tmp/bench-pr" "$PR/python" -c "
import _bench_critsec_core as core, time, sys
print(f'Python {sys.version}')
print(f'GIL enabled: {sys._is_gil_enabled()}')
N = 20_000_000
obj1, obj2 = object(), object()
for name, func, args in [
    ('CS1 (Begin/End)', core.bench_critical_section, (obj1, N)),
    ('CS2 (Begin2/End2)', core.bench_critical_section2, (obj1, obj2, N)),
]:
    times = [func(*args) * 1000 for _ in range(7)]
    mn = min(times)
    mean = sum(times) / len(times)
    print(f'  {name:<30} mean={mean:.2f} ms  min={mn:.2f} ms')
"
echo

# ---- Compare fastmark scores ----
echo "============================================"
echo "5. FASTMARK SCORE COMPARISON"
echo "============================================"
"$PR/python" -c "
import json, math
with open('/tmp/fastmark-base.json') as f:
    base = json.load(f)
with open('/tmp/fastmark-pr.json') as f:
    pr = json.load(f)

print(f'{\"Benchmark\":<30} {\"Base (ms)\":>10} {\"PR (ms)\":>10} {\"Change\":>10}')
print('-' * 65)
for name in sorted(base.keys()):
    if name == 'score':
        continue
    if name not in pr:
        continue
    b, p = base[name], pr[name]
    pct = (p / b - 1) * 100
    print(f'{name:<30} {b:10.1f} {p:10.1f} {pct:+9.1f}%')
if 'score' in base and 'score' in pr:
    b, p = base['score'], pr['score']
    pct = (p / b - 1) * 100
    print()
    print(f'{\"SCORE\":<30} {b:10.1f} {p:10.1f} {pct:+9.1f}%')
"
