import sys
from os.path import join
from random import sample
sys.path.append('.')
import atpboost

N_JOBS = 25
DATA_DIR = 'data/MPTP2078'
ATP_DIR = 'atp'
LOG_FILE = __file__.replace('.py', '.log')

statements = atpboost.Statements(from_file=join(DATA_DIR, 'statements'),
                            logfile=LOG_FILE)
features = atpboost.Features(from_file=join(DATA_DIR, 'features'), logfile=LOG_FILE)
chronology = atpboost.Chronology(from_file=join(DATA_DIR, 'chronology'),
                            logfile=LOG_FILE)
proofs_train = atpboost.Proofs(from_file=join(DATA_DIR, 'atpproved.train'),
                          logfile=LOG_FILE)
proofs_test = atpboost.Proofs(from_dict={})
theorems = atpboost.utils.readlines(join(DATA_DIR, 'theorems_atpproved'))
train_theorems = set(proofs_train)
test_theorems = set(theorems) - set(train_theorems)
params = {'features': features,
          'chronology': chronology}

for i in range(40):
    atpboost.utils.printline("ADDING PROOFS ROUND: {}".format(i), logfile=LOG_FILE)

    rankings_train = atpboost.knn(train_theorems, proofs_train, params, n_jobs=N_JOBS)
    rankings_test = atpboost.knn(test_theorems, proofs_train, params, n_jobs=N_JOBS)
    params_atp_eval = {}
    proofs_train.update(atpboost.atp_evaluation(rankings_train, statements,
          params_atp_eval, dirpath=ATP_DIR, n_jobs=N_JOBS, logfile=LOG_FILE))
    atpboost.utils.printline("STATS OF TRAINING PROOFS", logfile=LOG_FILE)
    proofs_train.print_stats(logfile=LOG_FILE)

    proofs_test.update(atpboost.atp_evaluation(rankings_test, statements,
         params_atp_eval, dirpath=ATP_DIR, n_jobs=N_JOBS, logfile=LOG_FILE))
    atpboost.utils.printline("STATS OF TEST PROOFS", logfile=LOG_FILE)
    proofs_test.print_stats(logfile=LOG_FILE)
