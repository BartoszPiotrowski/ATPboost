import os, sys
from random import shuffle
from glob import glob
from .src import fcoplib as cop
from .graph_data import GraphData
from .utils import read_lines, write_lines, append_lines, read_deps, read_stms
from .utils import mkdir_if_not_exists, partition, save_obj, load_obj
from joblib import Parallel, delayed
from .premsel_network import enumerate_symbols



def prepare_training_data(train_deps, train_ranks, stms_path, save_dir,
                          n_deps_per_example=None, n_jobs=10):
    stms = read_stms(stms_path)
    for thm in train_deps:
        for i in range(len(train_deps[thm])):
            rank = train_ranks[thm]
            ds_pos = train_deps[thm][i]
            n_ds_neg = max(10, n_deps_per_example - len(ds_pos))
            ds_neg = rank[:n_ds_neg]
            suffix = '-' + str(i)
            make_training_file(thm, ds_pos, ds_neg, stms, save_dir, suffix)
    # postprocessing
    data_files = glob(save_dir + '/*')
    def load(fname):
        gd, lls = cop.load_premsel(fname)
        return GraphData(gd), lls, fname
    load_d = delayed(load)
    with Parallel(n_jobs=n_jobs) as parallel:
        data_list = parallel(load_d(fname) for fname in data_files)
    _, data_list = enumerate_symbols(data_list)
    for d in data_list:
        save_obj(d, d[-1] + '.pickle')
    return save_dir


def prepare_testing_data(conjs, conjs_ranks, stms_path, save_dir,
                         n_deps_per_example=None, n=128):
    stms = read_stms(stms_path)
    N = len(conjs) // n # n = size of a batch
    batches = partition(conjs, N)
    for i in range(len(batches)):
        batch_dir = os.path.join(save_dir, f'batch_{i}')
        mkdir_if_not_exists(batch_dir)
        for conj in batches[i]:
            ds = conjs_ranks[conj][:n_deps_per_example]
            # forget which are positive and which negative
            shuffle(ds) # just to be sure we not exploit any bug
            make_testing_file(conj, ds, stms, batch_dir)
    return save_dir


def prepare_training_data_from_pos_neg(conjectures_path, deps_pos_path,
                                       deps_neg_path, statements_path,
                                       save_dir, multiple_proofs=False,
                                       n_jobs=-1):
    if type(conjectures_path) == list:
        conjectures = conjectures_path
    else:
        conjectures = read_lines(conjectures_path)
    statements = read_stms(statements_path)
    deps_pos = read_deps(deps_pos_path, multiple_proofs=multiple_proofs)
    deps_neg = read_deps(deps_neg_path)
    for conj in conjectures:
        ds_neg = deps_neg[conj]
        if not multiple_proofs:
            ds_pos = deps_pos[conj]
            make_training_file(conj, ds_pos, ds_neg, statements, save_dir)
        else:
            assert type(deps_pos[conj]) == list
            assert type(deps_pos[conj][0]) == set
            for i in range(len(deps_pos[conj])):
                ds_pos = deps_pos[conj][i]
                suffix = '-' + str(i)
                make_training_file(conj, ds_pos, ds_neg, statements, save_dir,
                                  suffix)


def enumerate_symbols_save(data_files):
    def truncate_skolem_single(symbol):
        if symbol.startswith("'skolem"):
            return "skolem"
        if symbol.startswith("'def"):
            return "def"
        return symbol
    def truncate_skolem(symbols):
        return map(truncate_skolem_single, symbols)
    symbol_set = set()
    for f in data_files:
        d = load_obj(f)
        _, (_, _, (funcs, rels)), _ = d
        symbol_set.update(truncate_skolem(funcs + rels))
    symbol_to_num = dict(
        (symbol, i) for i, symbol in enumerate(sorted(symbol_set)))
    res_data = []
    for f in data_files:
        d = load_obj(f)
        graph_data, (lens, labels, (funcs, rels)), fname = d
        symbols = [symbol_to_num[symbol]
            for symbol in truncate_skolem(funcs + rels)]
        ds = (graph_data, (lens, labels, symbols), fname)
        save_obj(ds, fname + '.pickle')
    #    res_data.append((graph_data, (lens, labels, symbols), fname))
    #return symbol_to_num, res_data


def prepare_testing_data_from_pos_neg(conjectures_path,
    deps_pos_path, deps_neg_path, statements_path, save_dir, n=128):
    mkdir_if_not_exists(save_dir)
    conjectures = read_lines(conjectures_path)
    statements = read_stms(statements_path)
    deps_pos = read_deps(deps_pos_path)
    deps_neg = read_deps(deps_neg_path)
    N = len(conjectures) // n # n = size of a batch
    batches = partition(conjectures, N)
    for i in range(len(batches)):
        batch_dir = os.path.join(save_dir, f'batch_{i}')
        mkdir_if_not_exists(batch_dir)
        for conj in batches[i]:
            ds_pos = deps_pos[conj]
            ds_neg = deps_neg[conj]
            # forget which are positive and which negative
            ds = list(ds_pos) + list(ds_neg)
            shuffle(ds) # just to be sure we not exploit any bug
            make_testing_file(conj, ds, statements, batch_dir)
    return save_dir


def prepare_testing_data_for_ranks(theorems_path, statements_path,
                                   chronology_path, max_size_of_file=0,
                                   save_dir='test_data', n=256, n_jobs=-1):
    theorems = read_lines(theorems_path)
    chronology = read_lines(chronology_path)
    statements = read_stms(statements_path)
    mkdir_if_not_exists(save_dir)
    for thm in theorems:
        available_premises = chronology[:chronology.index(thm)]
        make_testing_file(thm, available_premises, statements,
                         save_dir, max_size_of_file)
    files = glob(save_dir + '/*')
    N = len(files) // n # n = size of a batch
    batches = partition(files, N)
    for i in range(len(batches)):
        batch_dir = os.path.join(save_dir, f'batch_{i}')
        mkdir_if_not_exists(batch_dir)
        for f in batches[i]:
            os.popen(f'mv {f} {batch_dir}')
    return save_dir


def make_training_file(thm, pos_premises, neg_premises, statements, save_dir,
                       suffix=''):
    file_name = os.path.join(save_dir, thm) + suffix
    thm_line = statements[thm]
    write_lines([thm_line], file_name)
    for p in pos_premises:
        p_line = statements[p].replace(',conjecture,', ',axiom_useful,')
        append_lines([p_line], file_name)
    for p in neg_premises:
        p_line = statements[p].replace(',conjecture,', ',axiom_redundant,')
        append_lines([p_line], file_name)


def make_testing_file(thm, premises, statements, save_dir, max_size_of_file=0):
    file_name = os.path.join(save_dir, thm)
    thm_line = statements[thm]
    if not max_size_of_file:
        write_lines([thm_line], file_name)
        for p in premises:
            p_line = statements[p].replace(',conjecture,', ',axiom_useful,')
            append_lines([p_line], file_name)
    else:
        n = len(premises) // max_size_of_file # n = number of portions
        portions = partition(premises, n)
        for i in range(len(portions)):
            premises_portion = portions[i]
            file_name_portion = file_name + '@' + str(i)
            write_lines([thm_line], file_name_portion)
            for p in premises_portion:
                p_line = statements[p].replace(',conjecture,', ',axiom_useful,')
                append_lines([p_line], file_name_portion)


