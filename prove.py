import os, subprocess, uuid
from joblib import Parallel, delayed
from utils import merge_predictions, mkdir_if_not_exists
from utils import read_lines, read_stms
from tqdm import tqdm
from random import shuffle


def prove(predictions, args):
    predictions = merge_predictions(predictions)
    proofs_dir = os.path.join(args.data_dir, 'proofs')
    mkdir_if_not_exists(proofs_dir)
    n_jobs = args.n_jobs
    args.logger.print('Proving...')
    args.logger.print(f'Proofs will be saved to {proofs_dir}')
    with Parallel(n_jobs=n_jobs) as parallel:
        prove_one_d = delayed(prove_one)
        proofs = parallel(prove_one_d(conj, deps, args.statements, proofs_dir,
                             args.proving_script, args.logger) \
                          for conj, deps in tqdm(predictions))
    proofs_found = [p for p in proofs if p]
    args.logger.print(f'Proving done ({len(proofs_found)} proofs found).')
    return proofs_found

def prove_one(conj, deps, stms_path, dir_path, proving_script, logger):
    assert not conj in set(deps), (conj, deps)
    deps = list(deps)
    shuffle(deps)
    input_filename = problem_file(conj, deps, stms_path, dir_path)
    output_filename = input_filename.replace('.p', '.out')
    run_prover(input_filename, output_filename, proving_script)
    if "# Proof found!" in read_lines(output_filename):
        logger.print('PROVED#' + conj + ':' + ' '.join(deps) \
                     + '#Output: ' + output_filename, verb_level=7)
        return output_filename
    else:
        logger.print('NOT proved#' + conj + ':' + ' '.join(deps) \
                     + '#Output: ' + output_filename, verb_level=7)
        return None


def problem_file(conj, list_of_deps, stms_path, dir_path):
    stms = read_stms(stms_path)
    uuid4 = uuid.uuid4().hex
    input_filename = os.path.join(dir_path, uuid4 + '.p')
    with open(input_filename, 'w') as problem:
        conj_stms = stms[conj].replace(' ', '').replace(',axiom,', ',conjecture,')
        print(conj_stms, file=problem)
        for p in list_of_deps:
            print(stms[p], file=problem)
    return input_filename


def run_prover(input_filename, output_filename, proving_script):
    os.popen(f'./{proving_script} {input_filename} {output_filename}').read()


#CPU_TIME=10
#MEMORY_LIMIT=2000
#PATH_TO_EPROVER = os.environ['EPROVER']

#def run_prover(input_filename, output_filename):
#    output = open(output_filename, 'w')
#    subprocess.call([
#        PATH_TO_EPROVER,
#        '--free-numbers',
#        '-s',
#        '-R',
#        '--auto-schedule',
#        '--cpu-limit=' + str(CPU_TIME+1),
#        '--soft-cpu-limit=' + str(CPU_TIME),
#        '--memory-limit=' + str(MEMORY_LIMIT),
#        '--print-statistics',
#        '-p',
#        '--tstp-format',
#        input_filename],
#        stdout=output, stderr = open(os.devnull, 'w'))
#    output.close()



