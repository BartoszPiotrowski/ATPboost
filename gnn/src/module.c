#include "cint.h"
#include "graph_indices.h"

static PyMethodDef FCoplibMethods[] =
  {
   {"start", py_start, METH_VARARGS, "(arg: filename) Open problem"},
   {"action", py_action, METH_VARARGS, "(arg: n) Performs one move in the proof"},
   {"backtrack", py_backtrack, METH_NOARGS, "Undo last move in the proof"},
   {"restart",  py_restart, METH_NOARGS, "Restart the current proof game"},
   {"st_print",  py_st_print, METH_NOARGS, "Prints the current state + action to console"},
/*
   {"print_state_indices",  py_print_state_indices, METH_NOARGS, "Prints the indices for graph neural network"},
*/
   {"st_features",  py_st_features, METH_NOARGS,
    "current state as 4 sequences of features"},
   {"st_features_fast",  py_st_features_fast, METH_NOARGS,
    "current state as a sequence of features"},
   {"st_represent",  py_st_represent, METH_NOARGS,
    "current state as 4 sequences of tokens (parseable into tree)"},
   {"contr_features",  py_contr_features, METH_VARARGS,
    "(arg: n) n-th available action represented by features"},
   {"contr_represent",  py_contr_represent, METH_VARARGS,
    "(arg: n) n-th available action as sequence of tokens (parseable into tree)"},
   {"all_contras",  py_all_contras, METH_NOARGS, "All actions as pairs (hash, string)."},
   {"nos_contras",  py_nos_contras, METH_NOARGS, "Available actions as hashes."},
   {"graph_indices",  py_graph_indices, METH_NOARGS, "State representation as a computational graph"},
   {"graph_symbols",  py_graph_symbols, METH_NOARGS, "Strings representing functions and relations in the same order as in graph_indices"},
   {"load_premsel", py_load_premsel, METH_VARARGS, "(arg: filename) Load a premise selection file as a single graph"},
   {"load_cnfpremsel", py_load_cnfpremsel, METH_VARARGS, "(arg: filename) Load a premise selection file as a single graph"},
   {"action_fl",  py_action_fl, METH_VARARGS,
    "Like action but with natural order of actions"},
   {"unif_mask",  py_unif_mask, METH_VARARGS,
    "Mask selecting the appliable actions in the current context"},
   {"act_to_actfl",  py_act_to_actfl, METH_VARARGS,
    "Converts original action index into the natural (flattened clauses) action index in the current context"},
/*
   {"load_problem_map",  py_load_problem_map, METH_VARARGS,
    "Build an internal map LABEL -> CNF formulas from a file"},
   {"label_list_to_indices",  py_label_list_to_indices, METH_VARARGS,
   "Given a list of labels, build a graph according to the CNF formulas loaded by 'load_problem_map'"},
*/
   {NULL, NULL, 0, NULL}        // Sentinel
  };

static struct PyModuleDef module = {
    PyModuleDef_HEAD_INIT,
    "fcoplib",   /* name of module */
    NULL, /* module documentation, may be NULL */
    -1,       /* size of per-interpreter state of the module,
                 or -1 if the module keeps state in global variables. */
    FCoplibMethods
};

PyMODINIT_FUNC
PyInit_fcoplib(void)
{
  cop_caml_init();
  return PyModule_Create(&module);
}
