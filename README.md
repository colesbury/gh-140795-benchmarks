# Critical Section Benchmarks for PR #146066

Benchmarks for [python/cpython#146066](https://github.com/python/cpython/pull/146066)
("Put the thread state in PyCriticalSection structs").

## Build Configuration

Both base and PR were built with:
```
CC=clang-20 ./configure -C --disable-gil --with-tail-call-interp --enable-optimizations --with-lto=thin
```

- CPU: AMD EPYC 9R45 96-Core @ 4510 MHz
- OS: Linux 6.17.0-1009-aws (x86_64)
- Compiler: clang-20.1.2

## Micro-benchmarks

Three call paths for `PyCriticalSection_Begin`/`End` in a tight loop (20M iterations):

| Path | Description | File |
|------|-------------|------|
| Main executable | Compiled into libpython with PGO + thin LTO | `bench_critical_section_main_exe.patch` |
| Extension (Py_BUILD_CORE) | Shared library with inlined fast path | `_bench_critsec_core.c` |
| Extension (public API) | Shared library calling exported functions | `_bench_critsec_ext.c` |

Interpreter-core benchmarks (dict/list ops that use critical sections internally):
`bench_critsec_interp.py`

## Building the C extensions

```bash
./build_extensions.sh /path/to/cpython-build /path/to/output
```

This compiles both `_bench_critsec_ext` and `_bench_critsec_core` against the
given CPython build tree.

## Main-executable benchmark (patch)

The patch adds benchmark functions to `Python/critical_section.c` (part of
libpython) so they get the same PGO + thin LTO as the rest of the interpreter.
Thin wrappers in `_testinternalcapi` expose them to Python.

```bash
cd /path/to/cpython-build
git apply /path/to/bench_critical_section_main_exe.patch
make -j$(nproc)
```

Then:
```python
import _testinternalcapi
# Returns elapsed seconds
_testinternalcapi.bench_critical_section(obj, 20_000_000)
_testinternalcapi.bench_critical_section2(obj1, obj2, 20_000_000)
```

## Running everything

`run_all.sh` runs all micro-benchmarks and [fastmark](https://github.com/colesbury/fastmark)
for two CPython builds:

```bash
./run_all.sh /path/to/cpython-base /path/to/cpython-pr
```

## Results

See `results.txt` for full details. Summary:

| Path (CS1, 20M iters) | Base (ms) | PR (ms) | Change |
|------------------------|-----------|---------|--------|
| Main executable (PGO+LTO) | 180.93 | 186.37 | +3.0% |
| Extension (Py_BUILD_CORE) | 186.54 | 190.24 | +2.0% |
| Extension (public API) | 202.66 | 208.26 | +2.8% |

Fastmark (82 pyperformance benchmarks): **geometric mean -0.11%** (neutral).

The PR has a consistent ~2-3% overhead on isolated critical section
micro-benchmarks (~2 ns per Begin/End pair), but this is lost in noise
on real workloads.
