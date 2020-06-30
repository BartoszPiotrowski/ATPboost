#!/bin/python3

import argparse
from loop import loop

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument(
        '--conjectures',
        type=str)
    parser.add_argument(
        '--train_deps',
        type=str)
    parser.add_argument(
        '--train_neg_deps',
        type=str,
        default=None)
    parser.add_argument(
        '--data_dir',
        type=str,
        default='atpboost_data')
    parser.add_argument(
        '--statements',
        type=str)
    parser.add_argument(
        '--features',
        type=str)
    parser.add_argument(
        '--chronology',
        type=str,
        default=None)
    parser.add_argument(
        '--mining',
        type=float,
        default=0.1,
        help='Fraction of proved theorems used for mining; 0 means no mining.')
    parser.add_argument(
        '--iterations',
        default=10,
        type=int)
    parser.add_argument(
        '--proving_script',
        type=str,
        default='prove.sh')
    parser.add_argument(
        '--ml_models',
        default='xgboost,gnn,rnn,knn',
        type=str)
    parser.add_argument(
        '--logfile',
        default='atpboost.log',
        type=str)
    parser.add_argument(
        '--n_jobs',
        default=10,
        type=int)
    parser.add_argument(
        '--gnn_batch_size',
        default=64,
        type=int)
    parser.add_argument(
        '--gnn_epochs',
        default=100,
        type=int)
    parser.add_argument(
        '--gnn_n_deps_per_example',
        default=256,
        type=int)
    parser.add_argument(
        '--knn_neighbours',
        default=100,
        type=int)
    parser.add_argument(
        '--xgb_rounds',
        default=1000,
        type=int)
    parser.add_argument(
        '--xgb_eta',
        default=0.1,
        type=float)
    parser.add_argument(
        '--xgb_knn_prefiltering',
        default=10000,
        type=int)
    parser.add_argument(
        '--rnn_train_steps',
        default=100000,
        type=int)
    parser.add_argument(
        '--rnn_learning_rate',
        default=0.1,
        type=float)
    args = parser.parse_args()

loop(args)
