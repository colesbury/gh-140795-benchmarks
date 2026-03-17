/*
 * Micro-benchmark: critical sections via the Py_BUILD_CORE inlined path.
 *
 * This extension defines Py_BUILD_CORE_MODULE and includes the internal
 * headers, so it gets the inlined _PyCriticalSection_Begin / End fast path.
 * This simulates what CPython internal extension modules (like _ssl, _json,
 * etc.) do.
 */
#ifndef Py_BUILD_CORE_MODULE
#define Py_BUILD_CORE_MODULE
#endif
#include "Python.h"
#include "pycore_critical_section.h"
#include <time.h>

static PyObject *
bench_critical_section(PyObject *self, PyObject *args)
{
    PyObject *obj;
    int iterations;
    if (!PyArg_ParseTuple(args, "Oi", &obj, &iterations))
        return NULL;

    struct timespec start, end;

    /* Warm up */
    for (int i = 0; i < 1000; i++) {
        Py_BEGIN_CRITICAL_SECTION(obj);
        Py_END_CRITICAL_SECTION();
    }

    clock_gettime(CLOCK_MONOTONIC, &start);
    for (int i = 0; i < iterations; i++) {
        Py_BEGIN_CRITICAL_SECTION(obj);
        Py_END_CRITICAL_SECTION();
    }
    clock_gettime(CLOCK_MONOTONIC, &end);

    double elapsed = (double)(end.tv_sec - start.tv_sec)
                   + (double)(end.tv_nsec - start.tv_nsec) / 1e9;
    return PyFloat_FromDouble(elapsed);
}

static PyObject *
bench_critical_section2(PyObject *self, PyObject *args)
{
    PyObject *obj1, *obj2;
    int iterations;
    if (!PyArg_ParseTuple(args, "OOi", &obj1, &obj2, &iterations))
        return NULL;

    struct timespec start, end;

    /* Warm up */
    for (int i = 0; i < 1000; i++) {
        Py_BEGIN_CRITICAL_SECTION2(obj1, obj2);
        Py_END_CRITICAL_SECTION2();
    }

    clock_gettime(CLOCK_MONOTONIC, &start);
    for (int i = 0; i < iterations; i++) {
        Py_BEGIN_CRITICAL_SECTION2(obj1, obj2);
        Py_END_CRITICAL_SECTION2();
    }
    clock_gettime(CLOCK_MONOTONIC, &end);

    double elapsed = (double)(end.tv_sec - start.tv_sec)
                   + (double)(end.tv_nsec - start.tv_nsec) / 1e9;
    return PyFloat_FromDouble(elapsed);
}

static PyMethodDef methods[] = {
    {"bench_critical_section",  bench_critical_section,  METH_VARARGS,
     "Benchmark critical section (Py_BUILD_CORE inlined path)."},
    {"bench_critical_section2", bench_critical_section2, METH_VARARGS,
     "Benchmark critical section2 (Py_BUILD_CORE inlined path)."},
    {NULL, NULL, 0, NULL}
};

static struct PyModuleDef module = {
    PyModuleDef_HEAD_INIT,
    "_bench_critsec_core",
    "Critical section micro-benchmark (Py_BUILD_CORE inlined path)",
    -1,
    methods
};

PyMODINIT_FUNC
PyInit__bench_critsec_core(void)
{
    return PyModule_Create(&module);
}
