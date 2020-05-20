from xgboost import DMatrix
from joblib import Parallel, delayed
from random import sample
import numpy as np
import scipy.sparse as sps
from sklearn.feature_extraction import FeatureHasher
#import gensim as gs
from time import time
from .utils import printline, partition

# pair means here (thm features, prm features)
def pairs_to_array(pairs, params):
    num_of_features = params['num_of_features']
    merge_mode = params['merge_mode']
    if merge_mode == 'comb':
        list_of_pairs = [list(thm_f) + list(prm_f) for thm_f, prm_f in pairs]
    elif merge_mode == 'concat':
        num_of_features = 2 * num_of_features
        list_of_pairs = []
        for thm_f, prm_f in pairs:
            thm_f_appended = ['T' + f for f in thm_f]
            prm_f_appended = ['P' + f for f in prm_f]
            list_of_pairs.append(thm_f_appended + prm_f_appended)
    else:
        print("Error: unknown merge mode.")
    hasher = FeatureHasher(n_features=num_of_features, input_type='string')
    csc_array = hasher.transform(list_of_pairs)
    return csc_array

def proofs_to_train_n_thms(thms, proofs, params):
    labels, pairs = [], []
    for thm in thms:
        labels_thm, pairs_thm = thm_to_labels_and_pairs(thm, proofs, params)
        labels.extend(labels_thm)
        pairs.extend(pairs_thm)
    array = pairs_to_array(pairs, params)
    return labels, array

def thm_to_labels_and_pairs(thm, proofs, params):
    features = params['features']
    chronology = params['chronology']
    ratio_neg_pos = params['ratio_neg_pos']
    only_short_proofs = params['only_short_proofs']
    available_premises = chronology.available_premises(thm)
    pos_premises_all = proofs.union_of_proofs(thm)
    pos_premises = proofs.union_of_short_proofs(thm)
    if not only_short_proofs:
        pos_premises = pos_premises_all
    not_pos_premises = set(available_premises) - pos_premises_all
    assert not pos_premises & not_pos_premises
    if len(not_pos_premises) == 0:
        labels = [1] * len(pos_premises)
        pairs = [(features[thm], features[prm]) for prm in pos_premises]
        return labels, pairs
    if thm in params['thms_for_negative_mining']:
        level_of_negative_mining = params['level_of_negative_mining']
        ranking_thm = params['rankings_for_negative_mining'][thm]
        neg_premises_misclass = misclassified_negatives(
            ranking_thm, pos_premises_all, level_of_negative_mining)
        neg_premises_not_misclass = not_pos_premises - neg_premises_misclass
        num_neg_premises_not_misclass = \
            min(len(neg_premises_not_misclass), ratio_neg_pos * len(pos_premises))
        neg_premises_not_misclass_sample = \
            set(sample(neg_premises_not_misclass, num_neg_premises_not_misclass))
        neg_premises = neg_premises_misclass | neg_premises_not_misclass_sample
    else:
        num_neg = min(len(not_pos_premises), ratio_neg_pos * len(pos_premises))
        neg_premises = set(sample(not_pos_premises, num_neg))
    pairs_pos = [(features[thm], features[prm]) for prm in pos_premises]
    pairs_neg = [(features[thm], features[prm]) for prm in neg_premises]
    labels = [1] * len(pairs_pos) + [0] * len(pairs_neg)
    pairs = pairs_pos + pairs_neg
    return labels, pairs

def proofs_to_train(proofs, params, n_jobs=-1, verbose=True, logfile=''):
    # checking and initializing params
    assert len(proofs) > 0
    assert 'features' in params
    assert 'chronology' in params
    if not 'merge_mode' in params:
        params['merge_mode'] = 'concat'
    if not 'ratio_neg_pos' in params:
        params['ratio_neg_pos'] = 16
    if not 'only_short_proofs' in params:
        params['only_short_proofs'] = True
    if not 'num_of_features' in params:
        params['num_of_features'] = 1
    assert params['num_of_features'] > 0
    if params['num_of_features'] <= 1:
        params['num_of_features'] = \
        int(params['num_of_features'] * params['features'].num_of_features)
    else:
        params['num_of_features'] = \
        min(params['num_of_features'], params['features'].num_of_features)
    if not 'rankings_for_negative_mining' in params:
        params['thms_for_negative_mining'] = {}
    else:
        assert set(params['rankings_for_negative_mining']) >= set(proofs)
        if not 'level_of_negative_mining' in params:
            params['level_of_negative_mining'] = 2
        if not 'part_for_negative_mining' in params:
            params['part_for_negative_mining'] = 0.5
        params['thms_for_negative_mining'] = sample(set(proofs),
                    int(len(proofs) * params['part_for_negative_mining']))
    # printing informations
    if verbose or logfile:
        printline("Transforming proofs of {} theorems to training data...".format(
                      len(proofs)), logfile, verbose)
        num_of_all_features = params['features'].num_of_features
        printline("    Number of features used: {} / {}".format(
                params['num_of_features'], params['features'].num_of_features),
                        logfile, verbose)
        printline(("    Mode of combining theorems and premises to examples: "
               "merge_mode={}".format(params['merge_mode'])), logfile, verbose)
        printline("    Negatives to positive ratio: {}".format(
                params['ratio_neg_pos']), logfile, verbose)
        if params['thms_for_negative_mining']:
            printline("    Negative mining:", logfile, verbose)
            printline("        Level of negative mining: {}".format(
                    params['level_of_negative_mining']), logfile, verbose)
            printline("        Part of theorems for negative mining: {}".format(
                    params['part_for_negative_mining']), logfile, verbose)
        else:
            printline("    No negative mining.", logfile, verbose)
    all_proved_thms = list(proofs)
    thms_split = partition(all_proved_thms, max(n_jobs, 4))
    with Parallel(n_jobs=n_jobs) as parallel:
        d_proofs_to_train_n_thms = delayed(proofs_to_train_n_thms)
        labels_and_arrays = parallel(
            d_proofs_to_train_n_thms(thms, proofs, params)
                        for thms in thms_split)
    labels = [i for p in labels_and_arrays for i in p[0]]
    arrays = [p[1] for p in labels_and_arrays]
    array = sps.vstack(arrays)
    assert len(labels) == array.shape[0]
    if verbose or logfile:
        printline("Transformation finished.", logfile, verbose)
    return labels, array

# returns the most misclassified negatives
def misclassified_negatives(ranking, atp_useful, level_of_negative_mining=2):
    if isinstance(level_of_negative_mining, int):
        n_pos = len(atp_useful)
        n_neg = int(n_pos * level_of_negative_mining)
        mis_negs = [ranking[i] for i in range(min(n_neg, len(ranking)))
                    if not ranking[i] in set(atp_useful)]
    elif level_of_negative_mining == 'all':
        max_pos = max([i if prm in atp_useful else 0
                    for i, prm in enumerate(ranking)])
        mis_negs = [ranking[i] for i in range(min(max_pos, len(ranking)))
                    if not ranking[i] in set(atp_useful)]
    elif level_of_negative_mining == 'random':
        max_pos = max([i if prm in atp_useful else 0
                    for i, prm in enumerate(ranking)])
        mis_negs_all = [ranking[i] for i in range(min(max_pos, len(ranking)))
                    if not ranking[i] in set(atp_useful)]
        mis_negs = sample(mis_negs_all, len(mis_negs_all) // 2)
    else:
        print("Error: no such level of negative mining.")
    return set(mis_negs)

