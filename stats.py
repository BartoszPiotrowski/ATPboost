from utils import read_deps, read_lines


def stats_init(train_deps, conjs, padding=' ' * 25):
    train_deps = read_deps(train_deps)
    conjs = read_lines(conjs)
    n_conjs_proved = len(set(train_deps) & set(conjs))
    n_all_deps = sum([len(train_deps[t]) for t in train_deps])
    n_thms_in_deps = len(train_deps)

    message = 'Initial data statistics: \n'
    message += padding
    message += f'Number of conjectures to prove       : {len(conjs)}\n'
    message += padding
    message += f'Number of training dependencies      : {n_all_deps}\n'
    message += padding
    message += f'Theorems in training dependencies    : {n_thms_in_deps}\n'
    #message += padding
    #message += f'Conjectures with dependencies        : ' + \
    #           f'{n_conjs_proved} ' + \
    #           f'({100 * n_conjs_proved / len(conjs):.2f}%)'

    return message


def stats(train_deps, conjs, conjs_proved, padding=' ' * 25):
    train_deps = read_deps(train_deps)
    conjs = read_lines(conjs)
    conjs_proved = [read_lines(d)[0].split(':')[0] for d in conjs_proved]
    assert set(conjs_proved) <= set(conjs), set(conjs_proved) - set(conjs)
    assert set(conjs_proved) <= set(train_deps), set(conjs_proved) - set(train_deps)
    n_conjs_proved_total = len(set(train_deps) & set(conjs))
    n_conjs_proved_now = len(set(conjs_proved))
    n_all_deps = sum([len(train_deps[t]) for t in train_deps])
    n_conj_deps = sum([len(train_deps[t]) for t in train_deps if t in conjs])
    n_thms_in_deps = len(train_deps)

    message = "Loop statistics: \n"
    message += padding
    message += f"Conjectures proved (all iterations)  : " + \
               f"{n_conjs_proved_total} / {len(conjs)} " + \
               f"({100 * n_conjs_proved_total / len(conjs):.2f}%)\n"
    message += padding
    message += f"Conjectures proved (this iteration)  : " + \
               f"{n_conjs_proved_now} / {len(conjs)} " + \
               f"({100 * n_conjs_proved_now / len(conjs):.2f}%)\n"
    message += padding
    message += f"Conjectures' dependencies            : {n_conj_deps}\n"
    message += padding
    message += f"Training dependencies                : {n_all_deps}\n"
    message += padding
    message += f"Theorems in training dependencies    : {n_thms_in_deps}"

    return message
