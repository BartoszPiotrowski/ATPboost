import os
from utils import read_stms, write_lines, read_deps


def prepare_training_data(deps, stms, save_dir):
    deps = read_deps(deps)
    stms = read_stms(stms, tokens=True, short=True)
    source_lines, target_lines = [], []
    for conj in deps:
        for ds in deps[conj]:
            target_lines.append(' '.join(ds))
            source_lines.append(stms[conj])
    target_file = os.path.join(save_dir, 'train.tgt')
    source_file = os.path.join(save_dir, 'train.src')
    write_lines(source_lines, source_file)
    write_lines(target_lines, target_file)
    os.popen(f'''
        onmt_preprocess \
            -train_src {save_dir}/train.src \
            -train_tgt {save_dir}/train.tgt \
            -overwrite -tgt_seq_length 1000 -src_seq_length 1000 \
            -save_data {save_dir}/onmt
             ''').read()
    return save_dir + '/onmt'
