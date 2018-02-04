import sys
from os.path import join
import random
random.seed(1)
sys.path.append('..')
import premises as prs

N_JOBS = 10
DATA_DIR = 'data/MPTP2078'
ATP_DIR = 'atp'
LOG_FILE = __file__.replace('.py', '.log')

statements = prs.Statements(from_file=join(DATA_DIR, 'statements'),
                            logfile=LOG_FILE)
features = prs.Features(from_file=join(DATA_DIR, 'features'), logfile=LOG_FILE)
chronology = prs.Chronology(from_file=join(DATA_DIR, 'chronology'),
                            logfile=LOG_FILE)
theorems = prs.utils.readlines(join(DATA_DIR, 'theorems_atpproved'))
params_data_trans = {'features': features,
                     'chronology': chronology}

# randomly generated rankings
rankings_random = prs.Rankings(theorems, model=None, params=params_data_trans,
                             n_jobs=N_JOBS, logfile=LOG_FILE)

proofs = prs.atp_evaluation(rankings_random, statements, dirpath=ATP_DIR,
                                 n_jobs=N_JOBS, logfile=LOG_FILE)

for i in range(40):
    prs.utils.printline("ITERATION: {}".format(i), LOG_FILE)
    train_labels, train_array = prs.proofs_to_train(proofs, params_data_trans,
                                           n_jobs=N_JOBS, logfile=LOG_FILE)
    params_train = {}
    model = prs.train(train_labels, train_array, params=params_train,
                        n_jobs=N_JOBS, logfile=LOG_FILE)

    rankings = prs.Rankings(theorems, model, params_data_trans,
                         n_jobs=N_JOBS, logfile=LOG_FILE)
    params_atp_eval = {}
    proofs.update(prs.atp_evaluation(rankings, statements, params_atp_eval,
                             dirpath=ATP_DIR, n_jobs=N_JOBS, logfile=LOG_FILE))
    proofs.print_stats(logfile=LOG_FILE)
    params_data_trans['rankings_for_negative_mining'] = rankings
    params_data_trans['level_of_negative_mining'] = 'random'
