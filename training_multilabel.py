from time import time
from random import sample
from math import log
from joblib import Parallel, delayed
from .data_structures import Proofs, Features, Rankings


# thm1, thm2 -- theorems with features; we measure similarity between them
# dict_features_dict_features_numbers -- info about in how many theorems different
# features occur;
# higher power -> rare features have more influence on similarity
# returns number from [0,1]; 1 - identical, 0 - nothing in common
def similarity(thm1, thm2, dict_features_numbers, n_of_theorems, power):
    ftrs1 = set(thm1[1])
    ftrs2 = set(thm2[1])
    ftrsI = ftrs1 & ftrs2
    # we need to add unseen features to our dict with numbers
    for f in (ftrs1 | ftrs2):
        if not f in dict_features_numbers:
            dict_features_numbers[f] = 1
    trans = lambda l,n: log(l/n) ** power
    s1 = sum([trans(n_of_theorems, dict_features_numbers[f]) for f in ftrs1])
    s2 = sum([trans(n_of_theorems, dict_features_numbers[f]) for f in ftrs2])
    sI = sum([trans(n_of_theorems, dict_features_numbers[f]) for f in ftrsI])
    return (sI / (s1 + s2 - sI)) ** (1 / power) # Jaccard index

# theorem -- theorem and its features (as a tuple) with unknown premises useful
# for proving it; the function creates a ranking of premises
def knn_one_theorem(theorem, thm_features,
                    proofs, features,
                    chronology,
                    dict_features_numbers,
                    N, power):
    # chronology is important
    available_premises = chronology.available_premises(theorem)
    proofs = {t: proofs[t] for t in available_premises \
                if not theorem in set().union(*list(proofs[t]))}
    features = {t: features[t] for t in available_premises}
    # separation of train and test
    assert not theorem in proofs
    similarities = {t: similarity((theorem, thm_features),
                                 (t, features[t]),
                                 dict_features_numbers,
                                 len(features), power)
                    for t in proofs}
    similarities_sorted_values = sorted(similarities.values(), reverse=True)
    N_threshold = similarities_sorted_values[min(N, len(similarities) - 1)]
    N_nearest_theorems = {t for t in set(similarities)
                          if similarities[t] > N_threshold}
    premises_scores = {}
    assert not theorem in N_nearest_theorems
    for thm in N_nearest_theorems:
        premises_scores_one = {}
        for prf in proofs[thm]:
            for prm in prf:
                try: premises_scores_one[prm] = premises_scores_one[prm] + 1
                except: premises_scores_one[prm] = 1
        for prf in premises_scores_one:
            scr = similarities[thm] * premises_scores_one[prf] ** .3
            try: premises_scores[prf] = premises_scores[prf] + scr
            except: premises_scores[prf] = scr
    assert not theorem in premises_scores
    sorted_premises = sorted(premises_scores,
                           key=premises_scores.__getitem__, reverse=True)
    m = premises_scores[sorted_premises[0]] # max
    if m == 0: m = 1 # sometimes m = 0
    premises_scores_norm = [(p, premises_scores[p] / m) for p in sorted_premises
                           if not p == thm]
    return premises_scores_norm

# wrapper for knn_one_theorem() useful for using with Parallel
def                      knnot(t, tf, dtp, dtf, ch, dfn, N, p):
    return (t, knn_one_theorem(t, tf, dtp, dtf, ch, dfn, N, p))

# creates rankings of useful premises for given theorems using knn_one_theorem()
# returns results as a dictionary
# (keys: theorems names, values: lists of premises)
def knn(test_theorems, proofs, params, n_jobs=-1):
    chronology = params['chronology']
    features = params['features']
    N = params['N'] if 'N' in params else 50
    power = params['power'] if 'power' in params else 2
    # separation of train and test
    # assert not set(proofs) & set(test_theorems)
    proofs_train = proofs.with_trivial(set(chronology))
    features_train = features.subset(set(proofs_train))
    dict_features_numbers = features_train.dict_features_numbers()
    with Parallel(n_jobs=n_jobs) as parallel:
        dknnot = delayed(knnot)
        rankings = parallel(
           dknnot(thm, features[thm], proofs_train, features_train, chronology,
                  dict_features_numbers, N, power)
            for thm in test_theorems)
    return Rankings(from_dict=dict(rankings))
