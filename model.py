import os
from joblib import Parallel, delayed
from importlib import import_module
from utils import read_lines, write_lines, read_features, read_deps, read_stms
from utils import mkdir_if_not_exists, rmdir_mkdir, write_empty, append_line
from utils import dict_features_numbers, similarity


class Model:
    def __init__(self, **kwargs):
        self.train_params = {}
        self.n_jobs = kwargs['n_jobs']
        self.logger = kwargs['logger']
        self.save_dir = kwargs['save_dir']
        self.chronology = kwargs['chronology']
        mkdir_if_not_exists(self.save_dir)

    def train(self, train_deps, train_neg_deps=None):
        # some models do not train (knn)
        self.train_deps = train_deps
        self.train_neg_deps = train_neg_deps

    def save(self):
        pass

    def delete(self):
        pass

    def make_predictions(self, scored_prems,
                         slices_lens=[4,8,16,32,64,128,256,512]):
        all_predictions = []
        for conj in scored_prems:
            sp = scored_prems[conj]
            sp.sort(key = lambda x: x[1], reverse = True)
            ranking = [p for p, s in sp]
            slices = [ranking[:i] for i in slices_lens]
            slices_to_save = [conj + ':' + ' '.join(s) for s in slices]
            all_predictions.extend(slices_to_save)
        write_lines(all_predictions, self.predictions_path)
        return self.predictions_path


class KNN(Model):
    def __init__(self, **kwargs):
        super(KNN, self).__init__(**kwargs)
        self.neighbours = kwargs['knn_neighbours']
        self.features = kwargs['features']
        self.save_dir = os.path.join(self.save_dir, 'knn')
        self.predictions_path = os.path.join(self.save_dir, 'predictions')
        mkdir_if_not_exists(self.save_dir)


    def predict(self, conjs):
        conjs = read_lines(conjs) if type(conjs) == str else conjs
        self.logger.print(f'Making predictions for {len(conjs)} conjectures...')
        chronology = read_lines(self.chronology)
        features = read_features(self.features)
        features_numbers = dict_features_numbers(features)
        deps = read_deps(self.train_deps)
        deps_u = read_deps(self.train_deps, unions=True)
        scored_prems = {}
        for conj in conjs:
            available_prems = set(chronology[:chronology.index(conj)])
            scored_prems[conj] = self.predict_1(conj, available_prems,
                 deps, deps_u, features, features_numbers, self.neighbours)
        self.predictions_path = self.make_predictions(scored_prems)
        self.logger.print(f'Predictions saved to {self.predictions_path}')
        return self.predictions_path


    @staticmethod
    def predict_1(conj, available_prems, deps, deps_u, features,
                  features_numbers, n_neighbours=100):
        assert not conj in available_prems
        available_thms = {t for t in deps_u if deps_u[t] <= available_prems}
        simils = {thm: similarity((conj, features[conj]),
                                  (thm,  features[thm]),
                                  features_numbers, len(available_thms))
                            for thm in available_thms} # TODO len(av_thms) ??
        simils_sorted = sorted(simils.values(), reverse=True)
        N_thresh = simils_sorted[min(n_neighbours, len(simils) - 1)]
        N_nearest_thms = {t for t in simils if simils[t] >= N_thresh}
        prems_scores = {}
        for thm in N_nearest_thms:
            prems_scores_one = {}
            for prf in deps[thm]:
                for prm in prf:
                    try: prems_scores_one[prm] += 1
                    except: prems_scores_one[prm] = 1
            for prm in prems_scores_one:
                scr = simils[thm] * prems_scores_one[prm] ** .3
                try: prems_scores[prm] = prems_scores[prm] + scr
                except: prems_scores[prm] = scr
        assert not conj in prems_scores
        sorted_prems = sorted(prems_scores,
                               key=prems_scores.__getitem__, reverse=True)
        maximum = prems_scores[sorted_prems[0]]
        if maximum == 0: maximum = 1 # sometimes maximum = 0
        prems_scores_norm = [(p, prems_scores[p]/maximum) for p in sorted_prems]
        return prems_scores_norm


class XGBoost(Model):
    def __init__(self, **kwargs):
        super(XGBoost, self).__init__(**kwargs)
        self.xgb = import_module('xgboost')
        self.xgb_prep = import_module('xgb.prepare_data')
        self.save_dir = os.path.join(self.save_dir, 'xgb')
        mkdir_if_not_exists(self.save_dir)
        self.model_path = os.path.join(self.save_dir, 'model')
        self.features = kwargs['features']
        self.predictions_path = os.path.join(self.save_dir, 'predictions')
        self.knn_prefiltering = kwargs['xgb_knn_prefiltering']
        self.train_params_rounds = kwargs['xgb_rounds']
        self.train_params['max_depth'] = 10
        self.train_params['eta'] = kwargs['xgb_eta']
        self.train_params['booster'] = 'gbtree'
        self.train_params['objective'] = 'binary:logistic'
        self.train_params['n_jobs'] = self.n_jobs


    def prepare(self):
        kwargs = {
            'train_deps': self.train_deps,
            'train_neg_deps': self.train_neg_deps,
            'features': self.features,
            'chronology': self.chronology,
            'save_dir': self.save_dir,
            'n_jobs': self.n_jobs,
        }
        return self.xgb_prep.deps_to_train_array(**kwargs)


    def train(self, train_deps, train_neg_deps=None):
        self.train_deps = train_deps
        self.train_neg_deps = train_neg_deps
        self.logger.print('Preparing training data...')
        labels, array = self.prepare()
        dtrain = self.xgb.DMatrix(array, label=labels)
        self.logger.print('Training data prepared')
        self.logger.print('Training XGBoost model...')
        model = self.xgb.train(self.train_params, dtrain,
                          num_boost_round=self.train_params_rounds,
                          evals=[(dtrain, 'train')], verbose_eval=100)
        self.logger.print('Training XGBoost model done')
        self.logger.print(self.show_config())
        self.save(model)
        self.logger.print(f'Model saved to {self.model_path}')


    def show_config(self, padding=' ' * 25):
        message = 'Parameters of the XGBoost model:\n'
        message += padding
        message += f"rounds: {self.train_params_rounds}\n"
        message += padding
        message += f"eta: {self.train_params['eta']}\n"
        message += padding
        message += f"max_depth: {self.train_params['max_depth']}\n"
        message += padding
        message += f"booster: {self.train_params['booster']}\n"
        message += padding
        message += f"objective: {self.train_params['objective']}"
        return message


    def predict(self, conjs, max_num_prems=None):
        if max_num_prems == None:
            max_num_prems = self.knn_prefiltering
        conjs = read_lines(conjs) if type(conjs) == str else conjs
        self.logger.print(f'Making predictions for {len(conjs)} conjectures...')
        chronology = read_lines(self.chronology)
        features = read_features(self.features)
        features_numbers = dict_features_numbers(features) # for knn prefilering
        deps = read_deps(self.train_deps, unions=True) # for knn prefilering
        model = self.load()
        scored_prems = {}
        for conj in conjs:
            available_prems = set(chronology[:chronology.index(conj)])
            if len(available_prems) < max_num_prems:
                candidate_prems = available_prems
            else:
                candidate_prems = self.knn_prefilter(conj, available_prems,
                                                     deps, features,
                                                     features_numbers)
            scored_prems[conj] = self.score_prems(conj, candidate_prems,
                                                  model, features)
        self.predictions_path = self.make_predictions(scored_prems)
        self.logger.print(f'Predictions saved to {self.predictions_path}')
        return self.predictions_path


    def knn_prefilter(self, conj, available_prems, deps, features,
                      features_numbers, N_thms=1024):
        candidate_prems = set()
        available_thms = {t for t in deps if deps[t] <= available_prems}
        simils = {thm: similarity((conj, features[conj]),
                                  (thm,  features[thm]),
                                  features_numbers, len(available_thms))
                            for thm in available_thms}
                                        # TODO is len(available_thms) ok here?
        simils_sorted = sorted(simils.values(), reverse=True)
        N_thresh = simils_sorted[min(N_thms, len(simils) - 1)]
        N_nearest_thms = {t for t in simils if simils[t] >= N_thresh}
        for thm in N_nearest_thms:
            candidate_prems.update(deps[thm])
        assert candidate_prems <= available_prems
        return candidate_prems


    def score_prems(self, conj, premises, xgb_model, features):
        pairs = [(conj, p) for p in premises]
        array = self.xgb_prep.pairs_to_array(pairs, features)
        array = self.xgb.DMatrix(array)
        scores = xgb_model.predict(array)
        premises_scores = list(zip(premises, scores))
        return premises_scores

    def save(self, model):
        model.save_model(self.model_path)
        return self.model_path

    def load(self):
        model = self.xgb.Booster()
        model.load_model(self.model_path)
        return model


class GNN(Model):
    def __init__(self, **kwargs):
        super(GNN, self).__init__(**kwargs)
        warn = import_module('warnings'); warn.filterwarnings("ignore")
        self.gnn_prep= import_module('gnn.data_preparation')
        self.gnn= import_module('gnn.gnn')
        self.stms = kwargs['statements']
        self.save_dir = os.path.join(self.save_dir, 'gnn')
        self.model_dir = os.path.join(self.save_dir, 'model')
        self.training_dir = os.path.join(self.save_dir, 'training')
        self.testing_dir = os.path.join(self.save_dir, 'testing')
        self.predictions_path = os.path.join(self.save_dir, 'predictions')
        self.n_deps_per_example = kwargs['gnn_n_deps_per_example']
        self.batch_size = kwargs['gnn_batch_size']
        self.epochs = kwargs['gnn_epochs']
        self.features = kwargs['features']


    def prepare_training_dir(self):
        train_deps = read_deps(self.train_deps)
        train_deps_u = read_deps(self.train_deps, unions=True)
        thms = set(train_deps)
        chronology = read_lines(self.chronology)
        features = read_features(self.features)
        features_numbers = dict_features_numbers(features)
        train_ranks = {}
        for thm in thms:
            available_prems = set(chronology[:chronology.index(thm)])
            sp = KNN.predict_1(thm, available_prems, train_deps, train_deps_u,
                               features, features_numbers)
            sp.sort(key = lambda x: x[1], reverse = True)
            train_ranks[thm] = [p for p, s in sp]
        rmdir_mkdir(self.training_dir)
        self.gnn_prep.prepare_training_data(train_deps, train_ranks, self.stms,
                       self.training_dir, self.n_deps_per_example, self.n_jobs)
        return self.training_dir


    def prepare_testing_dir(self, conjs):
        train_deps = read_deps(self.train_deps)
        train_deps_u = read_deps(self.train_deps, unions=True)
        chronology = read_lines(self.chronology)
        features = read_features(self.features)
        features_numbers = dict_features_numbers(features)
        conjs_ranks = {}
        for conj in conjs:
            available_prems = set(chronology[:chronology.index(conj)])
            sp = KNN.predict_1(conj, available_prems, train_deps, train_deps_u,
                               features, features_numbers)
            sp.sort(key = lambda x: x[1], reverse = True)
            conjs_ranks[conj] = [p for p, s in sp]
        rmdir_mkdir(self.testing_dir)
        self.gnn_prep.prepare_testing_data(conjs, conjs_ranks, self.stms,
                                       self.testing_dir, self.n_deps_per_example)
        return self.testing_dir


    def predict(self, conjs):
        conjs = read_lines(conjs) if type(conjs) == str else conjs
        self.prepare_testing_dir(conjs)
        scored_prems = self.gnn.predictions_from_gnn_model(self.testing_dir,
                                                           self.model_path)

        self.predictions_path = self.make_predictions(scored_prems)
        self.logger.print(f'Predictions saved to {self.predictions_path}')
        return self.predictions_path


    def train(self, train_deps, train_neg_deps=None):
        self.logger.print('Preparing training data...')
        self.train_deps = train_deps
        self.train_neg_deps = train_neg_deps
        training_dir = self.prepare_training_dir()
        self.logger.print('Training data prepared')
        rmdir_mkdir(self.model_dir)
        self.logger.print('Training GNN model...')
        self.model_path = self.gnn.train_gnn_model(training_dir,
                           epochs=self.epochs, batch_size=self.batch_size,
                           save_each=20, save_dir=self.model_dir)
        self.logger.print('Training GNN model done')
        self.logger.print(f'Model saved to {self.model_path}')



class RNN(Model):
    def __init__(self, **kwargs):
        super(RNN, self).__init__(**kwargs)
        self.rnn_prep= import_module('rnn.prepare_data')
        self.stms = kwargs['statements']
        self.save_dir = os.path.join(self.save_dir, 'rnn')
        self.model_path = os.path.join(self.save_dir, 'model')
        self.predictions_path = os.path.join(self.save_dir, 'predictions')
        self.train_steps = kwargs['rnn_train_steps']
        self.learning_rate = kwargs['rnn_learning_rate']
        os.environ['MKL_THREADING_LAYER'] = 'GNU'


    def prepare(self):
        mkdir_if_not_exists(self.save_dir)
        return self.rnn_prep.prepare_training_data(
            self.train_deps, self.stms, self.save_dir)


    def train(self, train_deps, train_neg_deps=None):
        self.train_deps = train_deps
        self.train_neg_deps = train_neg_deps
        train_data = self.prepare()
        os.popen(
            f'''
            onmt_train \
                -data {train_data} \
                -train_steps {self.train_steps} \
                -learning_rate {self.learning_rate} \
                -world_size 1 -gpu_ranks 0 \
                -save_model {self.model_path}
            '''
        ).read()
        return self.model_path


    def predict(self, conjs):
        conjs = read_lines(conjs) if type(conjs) == str else conjs
        stms = read_stms(self.stms, tokens=True, short=True)
        conjs_stms = [stms[c] for c in conjs]
        source = write_lines(conjs_stms, os.path.join(self.save_dir, 'test.src'))
        os.popen(
            f'''
            onmt_translate \
                -model {self.model_path}_step_{str(self.train_steps)}.pt \
                -src {source} \
                -beam_size 10 -n_best 10 \
                -replace_unk -verbose \
                -gpu 0 \
                -output {self.predictions_path}
            '''
        ).read()
        preds_raw = read_lines(self.predictions_path)
        assert len(preds_raw) and len(preds_raw) % len(conjs) == 0
        write_empty(self.predictions_path)
        # when we produced n translations per theorem:
        n = int(len(preds_raw) / len(conjs))
        if n > 1:
            conjs = [c for c in conjs for _ in range(n)]
            assert conjs[0] == conjs[1]
            assert len(conjs) == len(preds_raw)
        deps_unions = {c: set() for c in conjs}
        chrono = read_lines(self.chronology)
        for i in range(len(preds_raw)):
            c = conjs[i]
            available_prems = set(chrono[:chrono.index(c)])
            ds = preds_raw[i].split(' ')
            ds = [d for d in ds if d in available_prems]
            if ds:
                deps_unions[c].update(ds)
                append_line(f"{c}:{' '.join(ds)}", self.predictions_path)
        for c in deps_unions:
            ds = deps_unions[c]
            if ds:
                append_line(f"{c}:{' '.join(ds)}", self.predictions_path)
        return self.predictions_path


class LightGBM(Model):
    def __init__(self, **kwargs):
        pass
