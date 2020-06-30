import os
import pickle
import gzip
from time import strftime
from glob import glob


def read_lines(filename):
    with open(filename, encoding ='utf-8') as f:
        return f.read().splitlines()


def write_lines(list_of_lines, filename):
    with open(filename, encoding ='utf-8', mode='wt') as f:
        f.write('\n'.join(list_of_lines) + '\n')


def append_lines(list_of_lines, filename):
    with open(filename, encoding ='utf-8', mode='a') as f:
        f.write('\n'.join(list_of_lines) + '\n')

def save_obj(obj, filename):
    with gzip.open(filename, 'wb') as f:
        pickle.dump(obj, f, pickle.HIGHEST_PROTOCOL)

def load_obj(filename):
    with gzip.open(filename, 'rb') as f:
        return pickle.load(f)

#def save_zipped_pickle(obj, filename, protocol=-1):
#    with gzip.open(filename, 'wb') as f:
#        cPickle.dump(obj, f, protocol)
#
#def load_zipped_pickle(filename):
#    with gzip.open(filename, 'rb') as f:
#        loaded_object = cPickle.load(f)
#        return loaded_object



def humanbytes(B):
   'Return the given bytes as a human friendly KB, MB, GB, or TB string'
   B = float(B)
   KB = float(1024)
   MB = float(KB ** 2) # 1,048,576
   GB = float(KB ** 3) # 1,073,741,824
   TB = float(KB ** 4) # 1,099,511,627,776
   if B < KB:
      return '{0} {1}'.format(B,'Bytes' if 0 == B > 1 else 'Byte')
   elif KB <= B < MB:
      return '{0:.2f} KB'.format(B/KB)
   elif MB <= B < GB:
      return '{0:.2f} MB'.format(B/MB)
   elif GB <= B < TB:
      return '{0:.2f} GB'.format(B/GB)
   elif TB <= B:
      return '{0:.2f} TB'.format(B/TB)


def partition(lst, n):
    '''
    Splits a list into n rougly equal partitions.
    '''
    if n == 0:
        return [lst]
    if n > len(lst):
        n = len(lst)
    division = len(lst) / n
    return [lst[round(division * i):round(division * (i + 1))] for i in range(n)]

def partition_by_size(lst, size):
    assert type(size) == int
    n = (len(lst) - 1) // size + 1
    return [lst[(size * i):(size * (i + 1))] for i in range(n)]


def mkdir_if_not_exists(dirpath):
    if not os.path.exists(dirpath):
        os.makedirs(dirpath)

def date_time():
    return strftime('%Y%m%d%H%M%S')


class Logger():
    def __init__(self, logfile):
        self.logfile = logfile

    def print(self, message):
        t = strftime('%Y-%m-%d--%H:%M:%S')
        m = f"[{t}] {message}\n"
        print(m)
        with open(self.logfile, 'a') as f:
            f.write(m)


def read_deps(path, multiple_proofs=False):
    deps = {}
    deps_lines = read_lines(path)
    for l in deps_lines:
        thm, ds = l.split(':')
        ds = set(ds.split(' '))
        ds = ds - {''}
        assert thm not in ds, (thm, ds)
        if not multiple_proofs:
            if thm in deps:
                deps[thm].update(ds)
            else:
                deps[thm] = ds
        else:
            if thm in deps:
                deps[thm].append(ds)
            else:
                deps[thm] = [ds]
    return deps

def read_rankings(path):
    rankings = {}
    rankings_lines = read_lines(path)
    for l in rankings_lines:
        thm, rk = l.split(':')
        rk = rk.split(' ')
        assert thm not in rk
        assert thm not in rankings
        rankings[thm] = rk
    return rankings


def read_stms(path):
    stms_lines = read_lines(path)
    names = [l.split(',')[0].split('(')[1].replace(' ', '')
                for l in stms_lines]
    stms = [l.replace(' ', '').replace(',axiom,', ',conjecture,')
                 for l in stms_lines]
    return dict(zip(names, stms))


def rankings_from_predictions(predictions_dir, rankings_dir):
    mkdir_if_not_exists(rankings_dir)
    for file in os.listdir(predictions_dir):
        ranking = make_ranking(predictions_dir + '/' + file)
        write_lines(ranking, rankings_dir + '/' + file)

def make_ranking(file):
    lines = read_lines(file)
    scores = []
    for l in lines:
        p, s = l.split(' ')
        s = float(s)
        scores.append((p, s))
    scores.sort(key = lambda x: x[1], reverse = True)
    ranking = [x[0] for x in scores]
    return ranking

