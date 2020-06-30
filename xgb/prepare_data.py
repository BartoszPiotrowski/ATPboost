import os
import scipy.sparse as sps
from joblib import Parallel, delayed
from random import sample
from sklearn.feature_extraction import FeatureHasher
from utils import read_features, read_deps, read_lines, load_obj, save_obj
from utils import partition
from deps import clean_deps, unify_deps
from tqdm import tqdm


def deps_to_train_array(train_deps=None, train_neg_deps=None, n_jobs=1, **kwargs):
    thms = list(set(read_deps(train_deps)))
    split = partition(thms, max(1, len(thms) // 100))
    with Parallel(n_jobs=n_jobs) as parallel:
        labels_arrays = parallel(delayed(deps_to_train_array_1_job)(
            i_thms=i_thms, deps=train_deps, deps_neg=train_neg_deps, **kwargs) \
            for i_thms in tqdm(list(enumerate(split))))
    labels, array = merge_saved_arrays(labels_arrays)
    return labels, array


def deps_to_train_array_1_job(i_thms=None, deps=None, deps_neg=None,
                              chronology=None, features=None, save_dir=None,
                              **kwargs):
    i, thms = i_thms
    deps = unify_deps(clean_deps(read_deps(deps)))
    chronology = read_lines(chronology)
    if deps_neg:
        deps_neg = read_deps(deps_neg, unions=True)
    labels, pairs = [], []
    for thm in thms:
        pos_premises = deps[thm]
        if deps_neg and thm in deps_neg:
            neg_premises = deps_neg[thm]
        else:
            neg_premises = set()
        available_premises = chronology[:chronology.index(thm)]
        labels_thm, pairs_thm = thm_to_labels_and_pairs(thm, pos_premises,
                                available_premises, neg_premises, **kwargs)
        labels.extend(labels_thm)
        pairs.extend(pairs_thm)
    array = pairs_to_array(pairs, read_features(features))
    assert len(labels) == array.shape[0]
    labels_path = os.path.join(save_dir, 'labels_' + str(i) + '.pickle')
    array_path = os.path.join(save_dir, 'array_' + str(i) + '.pickle')
    save_obj(labels, labels_path)
    save_obj(array, array_path)
    return labels_path, array_path


def thm_to_labels_and_pairs(thm, pos_premises, available_premises, neg_premises,
                            ratio_neg_pos=16, **kwargs):
    not_pos_premises = set(available_premises) - pos_premises
    assert not pos_premises & not_pos_premises
    if len(not_pos_premises) == 0:
        labels = [1] * len(pos_premises)
        pairs = [(thm, prm) for prm in pos_premises]
        return labels, pairs
    num_neg = min(len(not_pos_premises), ratio_neg_pos * len(pos_premises))
    neg_premises.update(sample(not_pos_premises - neg_premises,
                                 max(0, num_neg - len(neg_premises))))
    pairs_pos = [(thm, prm) for prm in pos_premises]
    pairs_neg = [(thm, prm) for prm in neg_premises]
    labels = [1] * len(pairs_pos) + [0] * len(pairs_neg)
    pairs = pairs_pos + pairs_neg
    return labels, pairs

# pair means here (thm, prm)
def pairs_to_array(pairs, features):
    assert len(pairs)
    featurised_pairs = []
    for thm, prm in pairs:
        thm_f = features[thm]
        prm_f = features[prm]
        if type(thm_f) == set: # 'binary' features
            thm_f_appended = ['T' + f for f in thm_f]
            prm_f_appended = ['P' + f for f in prm_f]
            fea_pair = thm_f_appended + prm_f_appended
        elif type(thm_f) == dict: # 'enigma' features
            fea_pair = {}
            for f in thm_f:
                fea_pair['T' + f] = thm_f[f]
            for f in prm_f:
                fea_pair['P' + f] = prm_f[f]
        else:
            raise TypeError
        featurised_pairs.append(fea_pair)
    hasher = FeatureHasher(n_features=2**14, input_type='string') # 2**15 == 32768
    array = hasher.transform(featurised_pairs)
    return array


def merge_saved_arrays(labels_arrays):
    save_dir = os.path.dirname(labels_arrays[0][0])
    save_path_labels = os.path.join(save_dir, 'cumulated_labels.pickle')
    save_path_array = os.path.join(save_dir, 'cumulated_array.pickle')
    cumul_labels = []
    for l_a in labels_arrays:
        labels_path, array_path = l_a
        labels = load_obj(labels_path)
        array = load_obj(array_path)
        cumul_labels.extend(labels)
        cumul_array = sps.vstack([cumul_array, array]) \
                if 'cumul_array' in dir() else array
        save_obj(cumul_labels, save_path_labels + '.part')
        save_obj(cumul_array, save_path_array + '.part')
    save_obj(cumul_labels, save_path_labels)
    save_obj(cumul_array, save_path_array)
    assert len(cumul_labels) == cumul_array.shape[0]
    return cumul_labels, cumul_array

if __name__=='__main__':
    # tests
    deps = 'data/example/train_deps'
    deps_neg = 'data/example/train_neg_deps'
    features = 'data/example/features_binary'
    #features = 'data/example/features'
    chronology = 'data/example/chronology'
    #labels_path, array_path = deps_to_train_array_1_job(
    #    i_thms=(3, ['l100_finseq_1', 'l100_modelc_2', 'l100_sincos10']),
    #    deps=deps,
    #    features=features,
    #    chronology=chronology,
    #    deps_neg=deps_neg,
    #    save_dir='tmp/data'
    #)

    labels, array = deps_to_train_array(
        train_deps=deps,
        features=features,
        chronology=chronology,
        deps_neg=deps_neg,
        save_dir='tmp/data',
        n_jobs=1
    )
