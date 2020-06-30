#include "cint.h"

static PyObject* py_caml_list4a(value l) {
  PyObject *smb = PyList_New(list_length(l));
  PyObject *nodes = PyList_New(list_length(l)*2);
  PyObject *sgn = PyList_New(list_length(l));
  for (int i = 0; l != Val_emptylist; l = snd(l)) {
    value quadruple = fst(l);
    long int x1 = Long_val(fst(quadruple));
    long int x2 = Long_val(snd(quadruple));
    long int x3 = Long_val(third(quadruple));
    int x4 = Bool_val(fourth(quadruple));
    PyList_SET_ITEM(smb, i, PyLong_FromLong(x1));
    PyList_SET_ITEM(nodes, 2*i, PyLong_FromLong(x2));
    PyList_SET_ITEM(nodes, 2*i+1, PyLong_FromLong(x3));
    PyList_SET_ITEM(sgn, i, PyLong_FromLong(x4 ? -1 : 1));
    ++i;
  }
  PyObject *result = PyTuple_Pack(3, smb, nodes, sgn);
  Py_DECREF(smb);
  Py_DECREF(nodes);
  Py_DECREF(sgn);
  return result;
}

static PyObject* py_caml_list4b(value l) {
  PyObject *nodes = PyList_New(list_length(l)*3);
  PyObject *sgn = PyList_New(list_length(l));
  for (int i = 0; l != Val_emptylist; l = snd(l)) {
    value quadruple = fst(l);
    long int x1 = Long_val(fst(quadruple));
    long int x2 = Long_val(snd(quadruple));
    long int x3 = Long_val(third(quadruple));
    int x4 = Bool_val(fourth(quadruple));
    PyList_SET_ITEM(nodes, 3*i, PyLong_FromLong(x1));
    PyList_SET_ITEM(nodes, 3*i+1, PyLong_FromLong(x2));
    PyList_SET_ITEM(nodes, 3*i+2, PyLong_FromLong(x3));
    PyList_SET_ITEM(sgn, i, PyLong_FromLong(x4 ? -1 : 1));
    ++i;
  }
  PyObject *result = PyTuple_Pack(2, nodes, sgn);
  Py_DECREF(nodes);
  Py_DECREF(sgn);
  return result;
}

static PyObject* py_caml_symb_edges(value data_list)
{
  PyObject *tup = PyTuple_New(list_length(data_list));
  for (int i = 0; data_list != Val_emptylist; data_list = snd(data_list)) {
    value len_data = fst(data_list);
    PyObject *lens = py_caml_list(fst(len_data));
    PyObject *data;
    if(i < 3) data = py_caml_list4a(snd(len_data));
    else data = py_caml_list4b(snd(len_data));
    PyTuple_SET_ITEM(tup, i, PyTuple_Pack(2,lens, data));
    Py_DECREF(lens);
    Py_DECREF(data);
    ++i;
  }
  return tup;
}

static PyObject* py_caml_cla_edges(value data_list, long *clauses_total_len)
{
  PyObject *tup = PyTuple_New(list_length(data_list));
  for (int i = 0; data_list != Val_emptylist; data_list = snd(data_list)) {
    value len_data = fst(data_list);
    PyObject *lens = py_caml_list(fst(len_data));
    PyObject *data = py_caml_list(snd(len_data));
    if(i == 1) *clauses_total_len = list_length(snd(len_data));
    PyTuple_SET_ITEM(tup, i, PyTuple_Pack(2,lens, data));
    Py_DECREF(lens);
    Py_DECREF(data);
    ++i;
  }
  return tup;
}

static PyObject* py_caml_ini_val(value types_list)
{
  PyObject *tup = PyTuple_New(list_length(types_list));
  for (int i = 0; types_list != Val_emptylist; types_list = snd(types_list)) {
    PyObject *types = py_caml_list(fst(types_list));
    PyTuple_SET_ITEM(tup, i, types);
    ++i;
  }
  return tup;
}

static PyObject* py_caml_axiom_mask(long axiom_num)
{
  static value * closure_f = NULL;
  if (closure_f == NULL) closure_f = caml_named_value("cop_unif_mask");
  value v = caml_callback(*closure_f, Val_unit);

  PyObject* res = PyList_New(axiom_num);
  long start_index = axiom_num - list_length(v);
  long i;
  for(i=0; i<start_index; i++) PyList_SET_ITEM(res, i, PyLong_FromLong(0));
  for(; i<axiom_num; i++){
    PyObject *pyl = PyLong_FromLong(Long_val(fst(v)));
    PyList_SET_ITEM(res, i, pyl);
    v = snd(v);
  }

  return res;
}

PyObject* py_graph_indices(PyObject *self, PyObject *args)
{
  static value *closure_f = NULL;
  if (closure_f == NULL) closure_f = caml_named_value("cop_graph_indices");
  value gi_ml = caml_callback(*closure_f, Val_unit);
  long axiom_num;

  PyObject *symb_edges = py_caml_symb_edges(fst(gi_ml));
  PyObject *cla_edges = py_caml_cla_edges(snd(gi_ml), &axiom_num);
  PyObject *ini_val = py_caml_ini_val(third(gi_ml));
  PyObject *axiom_mask = py_caml_axiom_mask(axiom_num);
  PyObject *result = PyTuple_Pack(4, symb_edges, cla_edges, ini_val, axiom_mask);

  Py_DECREF(symb_edges);
  Py_DECREF(cla_edges);
  Py_DECREF(ini_val);
  Py_DECREF(axiom_mask);
  return result;
}

PyObject* py_caml_str(value caml_str)
{
  char *c_str;
  c_str = String_val(caml_str);
  return PyUnicode_FromString(c_str);
}

PyObject* py_caml_str_list(value l)
{
  PyObject *lst = PyList_New(list_length(l));
  for (int i = 0; l != Val_emptylist; l = snd(l)) {
    PyObject *pyl = py_caml_str(fst(l));
    PyList_SET_ITEM(lst, i, pyl);
    ++i;
  }
  return lst;
}

PyObject* py_caml_symbols(value caml_symbols)
{
  PyObject *funcs = py_caml_str_list(fst(caml_symbols));
  PyObject *rels = py_caml_str_list(snd(caml_symbols));
  return PyTuple_Pack(2, funcs, rels);
}

PyObject* py_load_premsel(PyObject *self, PyObject *args)
{
  const char* arg;
  if (!PyArg_ParseTuple(args, "s", &arg)) return NULL;

  PyGILState_STATE gstate = PyGILState_Ensure();
  static value *closure_f = NULL;
  if (closure_f == NULL) closure_f = caml_named_value("cop_load_premsel");
  value gi_ml = caml_callback(*closure_f, caml_copy_string(arg));
  long axiom_num;

  PyObject *symb_edges = py_caml_symb_edges(fst(gi_ml));
  PyObject *cla_edges = py_caml_cla_edges(snd(gi_ml), &axiom_num);
  PyObject *ini_val = py_caml_ini_val(third(gi_ml));
  PyObject *axiom_mask = PyList_New(0);

  PyObject *graph_data = PyTuple_Pack(4, symb_edges, cla_edges, ini_val, axiom_mask);
  Py_DECREF(symb_edges);
  Py_DECREF(cla_edges);
  Py_DECREF(ini_val);
  Py_DECREF(axiom_mask);

  PyObject *prob_lens = py_caml_list(fst(fourth(gi_ml)));
  PyObject *prob_types = py_caml_list(snd(fourth(gi_ml)));
  PyObject *symbols = py_caml_symbols(third(fourth(gi_ml)));
  PyObject *lens_types_symbols = PyTuple_Pack(3, prob_lens, prob_types, symbols);
  Py_DECREF(prob_lens);
  Py_DECREF(prob_types);
  Py_DECREF(symbols);

  PyObject *result = PyTuple_Pack(2, graph_data, lens_types_symbols);
  Py_DECREF(graph_data);
  Py_DECREF(lens_types_symbols);

  PyGILState_Release(gstate);

  return result;
}

PyObject* py_load_cnfpremsel(PyObject *self, PyObject *args)
{
  const char* arg;
  if (!PyArg_ParseTuple(args, "s", &arg)) return NULL;

  PyGILState_STATE gstate = PyGILState_Ensure();
  static value *closure_f = NULL;
  if (closure_f == NULL) closure_f = caml_named_value("cop_load_cnfpremsel");
  value gi_ml = caml_callback(*closure_f, caml_copy_string(arg));
  long axiom_num;

  PyObject *symb_edges = py_caml_symb_edges(fst(gi_ml));
  PyObject *cla_edges = py_caml_cla_edges(snd(gi_ml), &axiom_num);
  PyObject *ini_val = py_caml_ini_val(third(gi_ml));
  PyObject *axiom_mask = PyList_New(0);

  PyObject *graph_data = PyTuple_Pack(4, symb_edges, cla_edges, ini_val, axiom_mask);
  Py_DECREF(symb_edges);
  Py_DECREF(cla_edges);
  Py_DECREF(ini_val);
  Py_DECREF(axiom_mask);

  PyObject *prob_types = py_caml_list(fst(fourth(gi_ml)));
  PyObject *symbols = py_caml_symbols(snd(fourth(gi_ml)));
  PyObject *lens_types_symbols = PyTuple_Pack(2, prob_types, symbols);
  Py_DECREF(prob_types);
  Py_DECREF(symbols);

  PyObject *result = PyTuple_Pack(2, graph_data, lens_types_symbols);
  Py_DECREF(graph_data);
  Py_DECREF(lens_types_symbols);

  PyGILState_Release(gstate);

  return result;
}

PyObject* py_graph_symbols(PyObject *self, PyObject *args)
{
  static value *closure_f = NULL;
  if (closure_f == NULL) closure_f = caml_named_value("cop_graph_symbols");
  return py_caml_symbols(caml_callback(*closure_f, Val_unit));
}

/*
PyObject* py_label_list_to_indices(PyObject *self, PyObject *args)
{
  PyObject* arg;
  if (!PyArg_ParseTuple(args, "O", &arg)) return NULL;

  PyGILState_STATE gstate = PyGILState_Ensure();
  static value *closure_f = NULL;
  if (closure_f == NULL) closure_f = caml_named_value("label_list_to_indices");
  value gi_ml = caml_callback(*closure_f, caml_py_str_list(arg));

  long axiom_num;

  PyObject *symb_edges = py_caml_symb_edges(fst(gi_ml));
  PyObject *cla_edges = py_caml_cla_edges(snd(gi_ml), &axiom_num);
  PyObject *ini_val = py_caml_ini_val(third(gi_ml));
  PyObject *axiom_mask = PyList_New(0);
  PyObject *graph_data = PyTuple_Pack(4, symb_edges, cla_edges, ini_val, axiom_mask);
  Py_DECREF(symb_edges);
  Py_DECREF(cla_edges);
  Py_DECREF(ini_val);
  Py_DECREF(axiom_mask);

  PyObject *prob_lens = py_caml_list(fourth(gi_ml));
  PyObject *result = PyTuple_Pack(2, graph_data, prob_lens);
  Py_DECREF(graph_data);
  Py_DECREF(prob_lens);

  PyGILState_Release(gstate);
  return result;
}

value caml_single_str(const char *str)
{
  CAMLparam0 ();
  CAMLlocal1 (result);

  result = caml_alloc(2, 0);
  fst(result) = caml_copy_string(str);
  snd(result) = Val_int(0);

  CAMLreturn (result);
}

PyObject* py_check_single_label(PyObject *self, PyObject *args)
{
  const char* arg;
  if (!PyArg_ParseTuple(args, "s", &arg)) return NULL;

  static value *closure_f = NULL;
  if (closure_f == NULL) closure_f = caml_named_value("label_list_to_indices");
  caml_callback(*closure_f, caml_single_str(arg));
}
*/
