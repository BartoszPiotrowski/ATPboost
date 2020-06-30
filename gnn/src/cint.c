#include "cint.h"

void cop_caml_init() {
  char *argv[] = {"-", NULL};
  caml_main(argv);
}

void print_caml_list(value l) {
  printf("[");
  for (; l != Val_emptylist; l = snd(l))
    printf(" %ld", Long_val(fst(l)));
  printf(" ]\n");
}

// Given OCaml list of ints, return corresponding Python
PyObject* py_caml_list(value l) {
  PyObject *lst = PyList_New(list_length(l));
  for (int i = 0; l != Val_emptylist; l = snd(l)) {
    PyObject *pyl = PyLong_FromLong(Long_val(fst(l)));
    PyList_SET_ITEM(lst, i, pyl);
    ++i;
  }
  return lst;
}

PyObject* py_start(PyObject *self, PyObject *args) {
  const char* arg;
  if (!PyArg_ParseTuple(args, "s", &arg)) return NULL;

  PyGILState_STATE gstate = PyGILState_Ensure();
  static value * closure_f = NULL;
  if (closure_f == NULL) closure_f = caml_named_value("cop_start");
  value v = caml_callback(*closure_f, caml_copy_string(arg));
  PyObject* data = Py_BuildValue("(ll)", Long_val(fst(v)), Long_val(snd(v)));
  PyGILState_Release(gstate);

  return data;
}

PyObject* py_action(PyObject *self, PyObject *pyn) {
  long n;
  if (!PyArg_ParseTuple(pyn, "l", &n)) return NULL;
  
  PyGILState_STATE gstate = PyGILState_Ensure();
  static value * closure_f = NULL;
  if (closure_f == NULL) closure_f = caml_named_value("cop_action");
  value v = caml_callback(*closure_f, Val_long(n));
  PyObject* data = Py_BuildValue("(ll)", Long_val(fst(v)), Long_val(snd(v)));
  PyGILState_Release(gstate);

  return data;
}

PyObject* py_backtrack(PyObject *self, PyObject *args) {
  static value * closure_f = NULL;
  if (closure_f == NULL) closure_f = caml_named_value("cop_backtrack");
  caml_callback(*closure_f, Val_unit);

  Py_RETURN_NONE;
}

PyObject* py_restart(PyObject *self, PyObject *args) {
  PyGILState_STATE gstate = PyGILState_Ensure();
  static value * closure_f = NULL;
  if (closure_f == NULL) closure_f = caml_named_value("cop_restart");
  value v = caml_callback(*closure_f, Val_unit);
  PyObject* data = Py_BuildValue("(ll)", Long_val(fst(v)), Long_val(snd(v)));
  PyGILState_Release(gstate);
  return data;
}

/*void py_contr_print(long n) {
  static value * closure_f = NULL;
  if (closure_f == NULL) closure_f = caml_named_value("cop_contr_print");
  caml_callback(*closure_f, Val_long(n));
}*/

PyObject*  py_st_print(PyObject *self, PyObject *args) {
  static value * closure_f = NULL;
  if (closure_f == NULL) closure_f = caml_named_value("cop_st_print");
  caml_callback(*closure_f, Val_unit);

  Py_RETURN_NONE;
}

PyObject* py_st_features(PyObject *self, PyObject *args) {
  static value * closure_f = NULL;
  if (closure_f == NULL) closure_f = caml_named_value("cop_st_features");
  value v = caml_callback(*closure_f, Val_unit);
  PyGILState_STATE gstate = PyGILState_Ensure();
  PyObject* f1 = py_caml_list(fst(v));
  PyObject* f2 = py_caml_list(snd(v));
  PyObject* f3 = py_caml_list(third(v));
  PyObject* f4 = py_caml_list(fourth(v));
  PyObject* data = Py_BuildValue("(OOOO)", f1, f2, f3, f4);
  Py_DECREF(f1);
  Py_DECREF(f2);
  Py_DECREF(f3);
  Py_DECREF(f4);
  PyGILState_Release(gstate);
  return data;
}

PyObject* py_st_features_fast(PyObject *self, PyObject *args) {
  static value * closure_f = NULL;
  if (closure_f == NULL) closure_f = caml_named_value("cop_st_features_fast");
  value v = caml_callback(*closure_f, Val_unit);
  PyGILState_STATE gstate = PyGILState_Ensure();
  PyObject* data = py_caml_list(v);
  PyGILState_Release(gstate);
  return data;
}

PyObject* py_st_represent(PyObject *self, PyObject *args) {
  static value * closure_f = NULL;
  if (closure_f == NULL) closure_f = caml_named_value("cop_st_represent");
  value v = caml_callback(*closure_f, Val_unit);
  PyGILState_STATE gstate = PyGILState_Ensure();
  PyObject* f1 = py_caml_list(fst(v));
  PyObject* f2 = py_caml_list(snd(v));
  PyObject* f3 = py_caml_list(third(v));
  PyObject* f4 = py_caml_list(fourth(v));
  PyObject* data = Py_BuildValue("(OOOO)", f1, f2, f3, f4);
  Py_DECREF(f1);
  Py_DECREF(f2);
  Py_DECREF(f3);
  Py_DECREF(f4);
  PyGILState_Release(gstate);
  return data;
}

PyObject* py_contr_features(PyObject *self, PyObject *pyn) {
  long n;
  if (!PyArg_ParseTuple(pyn, "l", &n)) return NULL;
  
  static value * closure_f = NULL;
  if (closure_f == NULL) closure_f = caml_named_value("cop_contr_features");
  value v = caml_callback(*closure_f, Val_long(n));
  PyGILState_STATE gstate = PyGILState_Ensure();
  PyObject* data = py_caml_list(v);
  PyGILState_Release(gstate);
  return data;
}

PyObject* py_contr_represent(PyObject *self, PyObject *pyn) {
  long n;
  if (!PyArg_ParseTuple(pyn, "l", &n)) return NULL;

  static value * closure_f = NULL;
  if (closure_f == NULL) closure_f = caml_named_value("cop_contr_represent");
  value v = caml_callback(*closure_f, Val_long(n));
  PyGILState_STATE gstate = PyGILState_Ensure();
  PyObject* data = py_caml_list(v);
  PyGILState_Release(gstate);
  return data;
}

PyObject* py_caml_int_string_list(value l) {
  PyObject *lst = PyList_New(list_length(l));
  for (int i = 0; l != Val_emptylist; l = snd(l)) {
    PyObject* data = Py_BuildValue("(ls)", Long_val(fst(fst(l))), String_val(snd(fst(l))));
    PyList_SET_ITEM(lst, i, data);
    ++i;
  }
  return lst;
}

PyObject* py_all_contras(PyObject *self, PyObject *args) {
  static value * closure_f = NULL;
  if (closure_f == NULL) closure_f = caml_named_value("cop_all_contras");
  value v = caml_callback(*closure_f, Val_unit);
  PyGILState_STATE gstate = PyGILState_Ensure();
  PyObject* data = py_caml_int_string_list(v);
  PyGILState_Release(gstate);
  return data;
}

PyObject* py_nos_contras(PyObject *self, PyObject *args) {
  static value * closure_f = NULL;
  if (closure_f == NULL) closure_f = caml_named_value("cop_nos_contras");
  value v = caml_callback(*closure_f, Val_unit);
  PyGILState_STATE gstate = PyGILState_Ensure();
  PyObject* data = py_caml_list(v);
  PyGILState_Release(gstate);
  return data;
}

PyObject* py_action_fl(PyObject *self, PyObject *pyn) {
  long n;
  if (!PyArg_ParseTuple(pyn, "l", &n)) return NULL;
  
  PyGILState_STATE gstate = PyGILState_Ensure();
  static value * closure_f = NULL;
  if (closure_f == NULL) closure_f = caml_named_value("cop_action_fl");
  value v = caml_callback(*closure_f, Val_long(n));
  PyObject* data = Py_BuildValue("(ll)", Long_val(fst(v)), Long_val(snd(v)));
  PyGILState_Release(gstate);

  return data;
}

PyObject* py_unif_mask(PyObject *self, PyObject *args) {
  static value * closure_f = NULL;
  if (closure_f == NULL) closure_f = caml_named_value("cop_unif_mask");
  value v = caml_callback(*closure_f, Val_unit);
  PyGILState_STATE gstate = PyGILState_Ensure();
  PyObject* data = py_caml_list(v);
  PyGILState_Release(gstate);
  return data;
}

PyObject* py_act_to_actfl(PyObject *self, PyObject *pyn) {
  long n;
  if (!PyArg_ParseTuple(pyn, "l", &n)) return NULL;
  
  PyGILState_STATE gstate = PyGILState_Ensure();
  static value * closure_f = NULL;
  if (closure_f == NULL) closure_f = caml_named_value("cop_act_to_actfl");
  value v = caml_callback(*closure_f, Val_long(n));
  PyObject* data = PyLong_FromLong(Long_val(v));
  PyGILState_Release(gstate);

  return data;
}
