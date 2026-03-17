/*
 * Micro-benchmark: critical sections via the public C API.
 *
 * This extension does NOT define Py_BUILD_CORE, so it goes through the
 * exported PyCriticalSection_Begin / PyCriticalSection_End functions
 * (non-inlined).  This is the path taken by third-party extensions.
 */
#include "Python.h"
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
        PyCriticalSection cs;
        PyCriticalSection_Begin(&cs, obj);
        PyCriticalSection_End(&cs);
    }

    clock_gettime(CLOCK_MONOTONIC, &start);
    for (int i = 0; i < iterations; i++) {
        PyCriticalSection cs;
        PyCriticalSection_Begin(&cs, obj);
        PyCriticalSection_End(&cs);
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
        PyCriticalSection2 cs;
        PyCriticalSection2_Begin(&cs, obj1, obj2);
        PyCriticalSection2_End(&cs);
    }

    clock_gettime(CLOCK_MONOTONIC, &start);
    for (int i = 0; i < iterations; i++) {
        PyCriticalSection2 cs;
        PyCriticalSection2_Begin(&cs, obj1, obj2);
        PyCriticalSection2_End(&cs);
    }
    clock_gettime(CLOCK_MONOTONIC, &end);

    double elapsed = (double)(end.tv_sec - start.tv_sec)
                   + (double)(end.tv_nsec - start.tv_nsec) / 1e9;
    return PyFloat_FromDouble(elapsed);
}

static PyMethodDef methods[] = {
    {"bench_critical_section",  bench_critical_section,  METH_VARARGS,
     "Benchmark PyCriticalSection_Begin/End (public API, non-inlined)."},
    {"bench_critical_section2", bench_critical_section2, METH_VARARGS,
     "Benchmark PyCriticalSection2_Begin/End (public API, non-inlined)."},
    {NULL, NULL, 0, NULL}
};

static struct PyModuleDef module = {
    PyModuleDef_HEAD_INIT,
    "_bench_critsec_ext",
    "Critical section micro-benchmark (public API path)",
    -1,
    methods
};

PyMODINIT_FUNC
PyInit__bench_critsec_ext(void)
{
    return PyModule_Create(&module);
}
