from time import strftime


class Logger():
    def __init__(self, logfile, verbose=None, verbose_stdout=5, verbose_file=6):
        self.logfile = logfile
        self.verbose_stdout = verbose_stdout if not verbose else verbose
        self.verbose_file = verbose_file if not verbose else verbose

    def print(self, message, verb_level=3, newline=False):
        t = strftime('%Y-%m-%d--%H:%M:%S')
        m = f"[{t}] {message}"
        if newline:
            m = '\n' + m
        if verb_level <= self.verbose_stdout:
            print(m)
        if verb_level <= self.verbose_file:
            with open(self.logfile, 'a') as f:
                f.write(m + '\n')
