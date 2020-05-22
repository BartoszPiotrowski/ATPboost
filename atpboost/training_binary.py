import xgboost as xgb
import numpy as np
import scipy.sparse as sps
from time import time
from joblib import Parallel, delayed
from .utils import printline

def train(labels, array, weights=None, model="xgboost", params={}, n_jobs=-1,
         verbose=True, logfile=''):
    assert isinstance(labels, list)
    if verbose or logfile:
        printline("Training of {} model started...".format(model),
                  logfile, verbose)
    if model == "xgboost":
        trained_model = train_xgboost(labels, array, weights, params, n_jobs)
    if verbose or logfile:
        printline("Training finished.", logfile, verbose)
    return trained_model

def train_xgboost(labels, array, weights, params, n_jobs):
    num_boost_round = params['num_boost_round'] \
            if 'num_boost_round' in params else 5000
    eta = params['eta'] if 'eta' in params else 0.1
    max_depth = params['max_depth'] if 'max_depth' in params else 10
    booster = params['booster'] if 'booster' in params else 'gbtree'
    assert booster in {'gbtree', 'gblinear', 'dart'}
    # 'gblinear' and 'dart' also available;
    # 'gblinear' makes xgboost like lasso
    pretrained_model = params['pretrained_model'] \
            if 'pretrained_model' in params else None
    dtrain = xgb.DMatrix(array, label=labels, weight=weights)
    params_booster = {'eta': eta,
                      'max_depth': max_depth,
                      'objective': 'binary:logistic',
                      'booster': booster,
                      'n_jobs': n_jobs}
    return xgb.train(params_booster, dtrain, num_boost_round=num_boost_round,
                     xgb_model=pretrained_model,
                     evals=[(dtrain, 'train')], verbose_eval=100)
