import sys
from os.path import join
import random
random.seed(1)
sys.path.append('..')
import premises as prs

DATA_DIR = 'data/MPTP2078'
ATP_DIR = 'atp'
LOG_FILE = __file__.replace('.py', '.log')
N_JOBS = 10

statements = prs.Statements(from_file=join(DATA_DIR, 'statements'),
                            logfile=LOG_FILE)
features = prs.Features(from_file=join(DATA_DIR, 'features'), logfile=LOG_FILE)
chronology = prs.Chronology(from_file=join(DATA_DIR, 'chronology'),
                            logfile=LOG_FILE)
theorems = prs.utils.readlines(join(DATA_DIR, 'theorems_atpproved'))
params = {'features': features,
          'chronology': chronology}
# randomly generated rankings
rankings_random = prs.Rankings(theorems, model=None, params=params,
                             n_jobs=N_JOBS, logfile=LOG_FILE)

proofs = prs.atp_evaluation(rankings_random, statements, dirpath=ATP_DIR,
                                 n_jobs=N_JOBS, logfile=LOG_FILE)

for i in range(40):
    prs.utils.printline("ITERATION: {}".format(i), LOG_FILE)
    rankings = prs.knn(theorems, proofs, params)
    params_atp_eval = {}
    proofs.update(prs.atp_evaluation(rankings, statements, params_atp_eval,
                         dirpath=ATP_DIR, n_jobs=N_JOBS, logfile=LOG_FILE))
    proofs.print_stats(logfile=LOG_FILE)
