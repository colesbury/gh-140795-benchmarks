"""
Runner for C-extension critical section micro-benchmarks.

Usage:
    python bench_critsec.py [--iterations N]
"""
import argparse
import sys
import time

N = 20_000_000


def run_ext_benchmarks(iterations, n):
    """Benchmark the public-API (non-inlined) path."""
    try:
        import _bench_critsec_ext as ext
    except ImportError as e:
        print(f"  SKIP (not built): {e}")
        return None

    obj1 = object()
    obj2 = object()
    results = {}

    # CS1
    times = []
    for _ in range(iterations):
        dt = ext.bench_critical_section(obj1, n)
        times.append(dt * 1000)
    mean = sum(times) / len(times)
    mn = min(times)
    stdev = (sum((t - mean) ** 2 for t in times) / len(times)) ** 0.5
    results["cs1"] = {"mean": mean, "min": mn, "stdev": stdev}
    print(f"  {'CS1 (Begin/End)':<30} {mean:10.2f} ms  (min {mn:.2f}, stdev {stdev:.2f})")

    # CS2
    times = []
    for _ in range(iterations):
        dt = ext.bench_critical_section2(obj1, obj2, n)
        times.append(dt * 1000)
    mean = sum(times) / len(times)
    mn = min(times)
    stdev = (sum((t - mean) ** 2 for t in times) / len(times)) ** 0.5
    results["cs2"] = {"mean": mean, "min": mn, "stdev": stdev}
    print(f"  {'CS2 (Begin2/End2)':<30} {mean:10.2f} ms  (min {mn:.2f}, stdev {stdev:.2f})")

    return results


def run_core_benchmarks(iterations, n):
    """Benchmark the Py_BUILD_CORE (inlined) path."""
    try:
        import _bench_critsec_core as core
    except ImportError as e:
        print(f"  SKIP (not built): {e}")
        return None

    obj1 = object()
    obj2 = object()
    results = {}

    # CS1
    times = []
    for _ in range(iterations):
        dt = core.bench_critical_section(obj1, n)
        times.append(dt * 1000)
    mean = sum(times) / len(times)
    mn = min(times)
    stdev = (sum((t - mean) ** 2 for t in times) / len(times)) ** 0.5
    results["cs1"] = {"mean": mean, "min": mn, "stdev": stdev}
    print(f"  {'CS1 (Begin/End)':<30} {mean:10.2f} ms  (min {mn:.2f}, stdev {stdev:.2f})")

    # CS2
    times = []
    for _ in range(iterations):
        dt = core.bench_critical_section2(obj1, obj2, n)
        times.append(dt * 1000)
    mean = sum(times) / len(times)
    mn = min(times)
    stdev = (sum((t - mean) ** 2 for t in times) / len(times)) ** 0.5
    results["cs2"] = {"mean": mean, "min": mn, "stdev": stdev}
    print(f"  {'CS2 (Begin2/End2)':<30} {mean:10.2f} ms  (min {mn:.2f}, stdev {stdev:.2f})")

    return results


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--iterations", type=int, default=7,
                        help="number of timing iterations (default 7)")
    parser.add_argument("-n", type=int, default=N,
                        help=f"loop count per iteration (default {N:,})")
    args = parser.parse_args()

    print(f"Python {sys.version}")
    print(f"GIL enabled: {sys._is_gil_enabled()}")
    print(f"N = {args.n:,}, iterations = {args.iterations}")
    print()

    print("Extension (public API, non-inlined):")
    ext_results = run_ext_benchmarks(args.iterations, args.n)
    print()

    print("Py_BUILD_CORE (inlined fast path):")
    core_results = run_core_benchmarks(args.iterations, args.n)

    return {"ext": ext_results, "core": core_results}


if __name__ == "__main__":
    main()
