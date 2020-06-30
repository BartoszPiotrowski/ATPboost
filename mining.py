from os.path import join
from random import sample
from prove import prove
from deps import merge_deps, extract_deps
from utils import write_lines, merge_predictions, unify_predictions
from utils import read_deps, save_deps
from utils import read_lines


def mining(models, args):
    args.logger.print('Mining...')
    pos_deps, neg_deps = [], []
    train_thms = set(read_deps(args.train_deps))
    num_mining_thms = max(round(args.mining * len(train_thms)), 1)
    mining_thms = sample(train_thms, num_mining_thms)
    preds = [model.predict(mining_thms) for model in models]
    proofs = prove(preds, args)
    if not proofs:
        return None, None
    deps = extract_deps(proofs)
    deps = merge_deps(*deps, output_file=join(args.data_dir, 'mining_deps'))
    pos_deps, neg_deps = _mining(preds, deps)
    pos_deps_path = join(args.data_dir, 'mined_pos_deps')
    neg_deps_path = join(args.data_dir, 'mined_neg_deps')
    save_deps(pos_deps, pos_deps_path)
    save_deps(neg_deps, neg_deps_path)
    args.logger.print('Mining done')
    return pos_deps_path, neg_deps_path

def _mining(preds, deps):
    preds = merge_predictions(preds)
    preds = unify_predictions(preds)
    pos_deps = read_deps(deps, unions=True)
    mining_thms = set(pos_deps) & set(preds)
    neg_deps = {thm: preds[thm] - pos_deps[thm] for thm in mining_thms}
    return pos_deps, neg_deps


