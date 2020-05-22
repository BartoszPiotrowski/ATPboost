import sys
from os.path import join
from random import sample
sys.path.append('.')
import atpboost

N_JOBS = 70
DATA_DIR = 'data/MPTP2078'
ATP_DIR = 'atp'
LOG_FILE = __file__.replace('.py', '.log')

XGB_MODEL=DATA_DIR+'/model.xgb'

statements = atpboost.Statements(from_file=join(DATA_DIR, 'statements'),
                            logfile=LOG_FILE)
features = atpboost.Features(from_file=join(DATA_DIR, 'features'),
                             logfile=LOG_FILE)
chronology = atpboost.Chronology(from_file=join(DATA_DIR, 'chronology'),
                            logfile=LOG_FILE)
proofs_train = atpboost.Proofs(from_file=join(DATA_DIR, 'atpproved.train'),
                          logfile=LOG_FILE)
theorems = atpboost.utils.readlines(join(DATA_DIR, 'theorems_atpproved'))
train_theorems = set(proofs_train)
test_theorems = set(theorems) - set(train_theorems)

params_data_trans = {'features': features,
                     'chronology': chronology}
train_labels, train_array = atpboost.proofs_to_train(proofs_train,
                             params_data_trans, n_jobs=N_JOBS, logfile=LOG_FILE)
model = XGB_MODEL
rankings_test = atpboost.Rankings(test_theorems, model, params_data_trans,
                     n_jobs=N_JOBS, logfile=LOG_FILE)
rankings_test.save_scores()
rankings_test.save(DATA_DIR + '/rankings_test')
params_atp_eval = {}
proofs_test = atpboost.atp_evaluation(rankings_test, statements, params_atp_eval,
                                 dirpath=ATP_DIR, n_jobs=N_JOBS, logfile=LOG_FILE)
atpboost.utils.printline("STATS OF TEST PROOFS", logfile=LOG_FILE)
proofs_test.print_stats(logfile=LOG_FILE)
