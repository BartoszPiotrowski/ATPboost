import sys
from os.path import join
import random
random.seed(1)
sys.path.append('.')
import atpboost

DATA_DIR = 'data/MPTP2078'
ATP_DIR = 'atp'
LOG_FILE = __file__.replace('.py', '.log')
N_JOBS = 10

statements = atpboost.Statements(from_file=join(DATA_DIR, 'statements'),
                            logfile=LOG_FILE)
features = atpboost.Features(from_file=join(DATA_DIR, 'features'), logfile=LOG_FILE)
chronology = atpboost.Chronology(from_file=join(DATA_DIR, 'chronology'),
                            logfile=LOG_FILE)
theorems = atpboost.utils.readlines(join(DATA_DIR, 'theorems_atpproved'))
params = {'features': features,
          'chronology': chronology}
# randomly generated rankings
rankings_random = atpboost.Rankings(theorems, model=None, params=params,
                             n_jobs=N_JOBS, logfile=LOG_FILE)

proofs = atpboost.atp_evaluation(rankings_random, statements, dirpath=ATP_DIR,
                                 n_jobs=N_JOBS, logfile=LOG_FILE)

for i in range(40):
    atpboost.utils.printline("ITERATION: {}".format(i), LOG_FILE)
    rankings = atpboost.knn(theorems, proofs, params)
    params_atp_eval = {}
    proofs.update(atpboost.atp_evaluation(rankings, statements, params_atp_eval,
                         dirpath=ATP_DIR, n_jobs=N_JOBS, logfile=LOG_FILE))
    proofs.print_stats(logfile=LOG_FILE)
