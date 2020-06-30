#include <Python.h>
#include <caml/callback.h>
#include <caml/alloc.h>
#include <stdio.h>
#include <sys/time.h>

#define fst(a) Field(a, 0)
#define snd(a) Field(a, 1)
#define third(a) Field(a, 2)
#define fourth(a) Field(a, 3)

void cop_caml_init();
void print_caml_list(value l);
PyObject* py_caml_list(value l);
PyObject* py_start(PyObject *, PyObject *);
PyObject* py_action(PyObject *, PyObject *);
PyObject* py_backtrack(PyObject *, PyObject *);
PyObject* py_restart(PyObject *, PyObject *);
PyObject* py_st_print(PyObject *, PyObject *);
PyObject* py_st_features(PyObject *, PyObject *);
PyObject* py_st_features_fast(PyObject *, PyObject *);
PyObject* py_st_represent(PyObject *, PyObject *);
PyObject* py_contr_features(PyObject *, PyObject *);
PyObject* py_contr_represent(PyObject *, PyObject *);
PyObject* py_caml_int_string_list(value l);
PyObject* py_all_contras(PyObject *, PyObject *);
PyObject* py_nos_contras(PyObject *, PyObject *);
PyObject* py_action_fl(PyObject *, PyObject *);
PyObject* py_unif_mask(PyObject *, PyObject *);
PyObject* py_act_to_actfl(PyObject *, PyObject *);

// Length of an OCaml list
static inline unsigned long list_length(value l) {
  long ret = 0;
  for (; l != Val_emptylist; l = Field(l, 1)) {
    ++ret;
  }
  return ret;
}
