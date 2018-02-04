import os
from time import strftime
from random import shuffle


def remove_supersets(list_of_sets):
    '''Removes proper supersets from the list of sets'''
    list_of_sets_clean = []
    l = len(list_of_sets)
    for i1 in range(l):
        for i2 in range(l):
            if list_of_sets[i1] > list_of_sets[i2]:
                break
        else:
            list_of_sets_clean.append(list_of_sets[i1])
    return list_of_sets_clean

def read_dict(filename, type_of_names=str, type_of_values=str, sep=':',
             type_of_values_in_list=str, sep_in_list=', ', to_strip=' "'):
    with open(filename) as file:
        slines = [l.split(sep) for l in file.read().splitlines()]
    names = [type_of_names(l[0]) for l in slines]
    values_raw = [l[1] for l in slines]
    if type_of_values in {int, str, float}:
        values = [type_of_values(v.strip(to_strip)) for v in values_raw]
    elif type_of_values == list:
        values = []
        for v in values_raw:
            if v:
                values.append([type_of_values_in_list(i.strip(to_strip))
                                   for i in v.split(sep_in_list)])
            else:
                values.append([])
    else:
        print("Error: cannot read the file to dict.")
        return
    return dict(zip(names, values))

def readlines(filename):
    with open(filename, encoding ='utf-8') as f:
        return f.read().splitlines()

def mkdir_if_not_exists(dirpath):
    if not os.path.exists(dirpath):
        os.makedirs(dirpath)

def printline(message, logfile='', verbose=True, time=True):
    if verbose:
        print(message)
    if logfile:
        with open(logfile, 'a') as f:
            if time:
                message = "[{}] {}".format(strftime("%Y-%m-%d %H:%M:%S"), message)
            print(message, file=f)

def shuffled(l):
    shuffle(l)
    return l

def partition(lst, n):
    if n > len(lst):
        n = len(lst)
    division = len(lst) / n
    return [lst[round(division * i):round(division * (i + 1))] for i in range(n)]
