"""
Micro-benchmark: interpreter-core critical sections.

Measures the overhead of Py_BEGIN_CRITICAL_SECTION / Py_END_CRITICAL_SECTION
as used by built-in types (dict, list) in the free-threaded build.

These operations enter/exit a critical section on every call in the
free-threaded interpreter.
"""
import time
import sys

N = 5_000_000

def bench_dict_getitem(n):
    """dict.__getitem__ enters a critical section on the dict."""
    d = {"key": 1}
    key = "key"
    for _ in range(n):
        d[key]

def bench_dict_setitem(n):
    """dict.__setitem__ enters a critical section on the dict."""
    d = {"key": 1}
    key = "key"
    for _ in range(n):
        d[key] = 1

def bench_list_append_pop(n):
    """list.append + list.pop each enter a critical section."""
    lst = []
    for _ in range(n):
        lst.append(1)
        lst.pop()

def bench_dict_contains(n):
    """dict.__contains__ enters a critical section on the dict."""
    d = {"key": 1}
    key = "key"
    for _ in range(n):
        key in d

def bench_dict_len(n):
    """dict.__len__ enters a critical section on the dict."""
    d = {"key": 1}
    for _ in range(n):
        len(d)

BENCHMARKS = [
    ("dict_getitem", bench_dict_getitem),
    ("dict_setitem", bench_dict_setitem),
    ("dict_contains", bench_dict_contains),
    ("dict_len", bench_dict_len),
    ("list_append_pop", bench_list_append_pop),
]

def run(warmup=2, iterations=5):
    print(f"Python {sys.version}")
    print(f"GIL enabled: {sys._is_gil_enabled()}")
    print(f"N = {N:,}")
    print()
    print(f"{'Benchmark':<25} {'Mean (ms)':>10} {'Min (ms)':>10} {'Stdev':>10}")
    print("-" * 60)

    results = {}
    for name, func in BENCHMARKS:
        times = []
        for _ in range(warmup):
            func(N)
        for _ in range(iterations):
            t0 = time.perf_counter()
            func(N)
            dt = time.perf_counter() - t0
            times.append(dt * 1000)
        mean = sum(times) / len(times)
        mn = min(times)
        stdev = (sum((t - mean) ** 2 for t in times) / len(times)) ** 0.5
        print(f"{name:<25} {mean:10.2f} {mn:10.2f} {stdev:10.2f}")
        results[name] = {"mean": mean, "min": mn, "stdev": stdev, "times": times}
    return results

if __name__ == "__main__":
    run()
