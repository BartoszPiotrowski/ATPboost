import os
import sys
import random
import glob
import gc
from .src import fcoplib as cop
import numpy as np
import tensorflow as tf
tf.compat.v1.logging.set_verbosity(tf.compat.v1.logging.FATAL)
os.environ['TF_CPP_MIN_VLOG_LEVEL'] = '3'
os.environ['TF_CPP_MIN_LOG_LEVEL'] = '3'
from tensorflow.contrib.layers import fully_connected
from joblib import Parallel, delayed
from .tf_helpers import tf_linear_sq, mean_or_zero
from .graph_placeholder import GraphPlaceholder
from .graph_conv import graph_start, graph_conv
from .graph_data import GraphData
from .segments import Segments, SegmentsPH
from . import debug_node
from .utils import partition_by_size, load_obj


class NetworkConfig:
    def __init__(self):
        self.threads = 4
        self.start_shape = (4, 1, 4)
        self.next_shape = (32, 64, 32)
        #self.next_shape = (11,12,13)
        #self.res_blocks = 3
        #self.layers = 3
        self.res_blocks = 1
        self.layers = 5
        self.hidden = 128
        self.symbol_loss_ratio = 0
        self.balance_loss = True


class Network:
    def __init__(self, total_symbols=None, config=None):
        if config is None:
            self.config = NetworkConfig()

        graph = tf.Graph()
        graph.seed = 43

        self.session = tf.Session(
            graph=graph,
            config=tf.ConfigProto(
                inter_op_parallelism_threads=self.config.threads,
                intra_op_parallelism_threads=self.config.threads))

        with self.session.graph.as_default():
            self.structure = GraphPlaceholder()
            x = graph_start(self.structure, self.config.start_shape)
            #last_x = None
            for _ in range(self.config.res_blocks):
                for n in range(self.config.layers):
                    x = graph_conv(
                        x,
                        self.structure,
                        output_dims=self.config.next_shape,
                        use_layer_norm=False) # use_layer_norm is experimantal
                    #x = tuple(map(layer_norm, x))
                #if last_x is not None:
                #    x = [cx + lx for cx, lx in zip(x, last_x)]
                #last_x = x

            nodes, symbols, clauses = x

            self.total_symbols = total_symbols
            if self.total_symbols is not None:
                self.symbol_num = tf.shape(symbols)[0]
                symbol_logits = tf_linear(symbols, self.total_symbols)

                symbol_labels = tf.placeholder(tf.int64, [None])
                self.symbol_labels = symbol_labels

                self.symbol_loss = tf.losses.sparse_softmax_cross_entropy(
                    symbol_labels, symbol_logits
                )
                symbol_predictions = tf.argmax(symbol_logits, 1)
                self.symbol_predictions = symbol_predictions
                self.symbol_accuracy = tf.reduce_mean(
                    tf.cast(
                        tf.equal(symbol_labels, symbol_predictions),
                        tf.float32,
                    )
                )
            else:
                self.symbol_num = tf.constant(1)
                self.symbol_loss = tf.constant(0)
                self.symbol_accuracy = tf.constant(0)

            self.prob_segments = SegmentsPH(nonzero=True)

            theorems = Segments(self.prob_segments.data).collapse(clauses)
            conjectures = self.prob_segments.gather(theorems, 0)
            mask = 1 - tf.scatter_nd(
                tf.expand_dims(
                    self.prob_segments.start_indices_nonzero, 1), tf.ones(
                    tf.reshape(
                        self.prob_segments.nonzero_num, [1]), dtype=tf.int32), [
                    self.prob_segments.data_len], )
            prem_segments, premises = self.prob_segments.mask_data(
                theorems, mask,
                nonzero=True
            )

            network_outputs = tf.concat(
                [premises, prem_segments.fill(conjectures)], axis=1)
            hidden = fully_connected(network_outputs, self.config.hidden)
            premsel_logits = tf_linear_sq(hidden)
            self.premsel_logits = premsel_logits

            premsel_labels = tf.placeholder(tf.int32, [None])
            self.premsel_labels = premsel_labels

            pos_mask = tf.cast(premsel_labels, tf.bool)
            neg_mask = tf.logical_not(pos_mask)

            premsel_loss = tf.nn.sigmoid_cross_entropy_with_logits(
                labels=tf.cast(premsel_labels, tf.float32),
                logits=premsel_logits)
            if self.config.balance_loss:
                loss_on_true = tf.boolean_mask(premsel_loss, pos_mask)
                loss_on_false = tf.boolean_mask(premsel_loss, neg_mask)
                self.premsel_loss = (
                    mean_or_zero(loss_on_true) + mean_or_zero(loss_on_false)) / 2
            else:
                self.premsel_loss = tf.reduce_mean(premsel_loss)

            if self.config.symbol_loss_ratio == 0:
                loss = self.premsel_loss
            else:
                loss = self.premsel_loss + \
                        self.config.symbol_loss_ratio * self.symbol_loss

            optimizer = tf.train.AdamOptimizer()
            self.training = optimizer.minimize(loss)

            premsel_predictions = tf.cast(
                tf.greater(premsel_logits, 0), tf.int32)
            self.premsel_predictions = premsel_predictions
            self.premsel_num = tf.size(premsel_predictions)
            self.premsel_accuracy = tf.reduce_mean(
               tf.cast(
                   tf.equal(premsel_labels, premsel_predictions),
                   tf.float32,
               )
            )
            predictions_f = tf.cast(premsel_predictions, tf.float32)
            predictions_on_true = tf.boolean_mask(predictions_f, pos_mask)
            predictions_on_false = tf.boolean_mask(predictions_f, neg_mask)
            self.premsel_tpr = tf.reduce_mean(predictions_on_true)
            self.premsel_tnr = tf.reduce_mean(1 - predictions_on_false)

            self.session.run(tf.global_variables_initializer())
            self.saver = tf.train.Saver()

        self.session.graph.finalize()

    def feed(self, data, use_labels, non_destructive=True):
        graph_data, lens_labels_symbols, fnames = zip(*data)
        d = self.structure.feed(graph_data, non_destructive)
        prob_lens, labels, symbols = zip(*lens_labels_symbols)
        self.prob_segments.feed(d, prob_lens)
        if use_labels:
            d[self.premsel_labels] = np.concatenate(labels)
            if self.total_symbols is not None:
                d[self.symbol_labels] = np.concatenate(symbols)
        return d

    def predict(self, data):
        d = self.feed(data, use_labels=False)
        return self.session.run(self.premsel_predictions, d)

    def predict_logits(self, data):
        d = self.feed(data, use_labels=False)
        return self.session.run(self.premsel_logits, d)

    def predict_logits_1(self, data):
        conjs_logits = {}
        for conj_data in data:
            fname = conj_data[2]
            d = self.feed([conj_data], use_labels=False)
            conjs_logits[fname] = self.session.run(self.premsel_logits, d)
        return conjs_logits

    def get_metrics(self, data):
        d = self.feed(data, use_labels=True)
        return self.session.run(
            ((self.premsel_loss, self.premsel_tpr, self.premsel_tnr),
             (self.symbol_loss, self.symbol_accuracy),
             self.premsel_num, self.symbol_num), d)

    def train(self, data):
        d = self.feed(data, use_labels=True)
        return self.session.run(
            (self.training,
             (self.premsel_loss, self.premsel_tpr, self.premsel_tnr),
             (self.symbol_loss, self.symbol_accuracy),
             self.premsel_num, self.symbol_num), d)[1:]

    def debug(self, data, labels=None):
        d = self.feed(data, use_labels=True)
        debug_node.tf_debug_print(self.session.run(
            debug_node.debug_nodes, d
        ))

    def save(self, path, step=None):
        #print('Saving model to', path)
        self.saver.save(
            self.session,
            path,
            global_step=step,
            write_meta_graph=True,
            write_state=True)

    def load(self, path):
        self.saver.restore(self.session, path)

def save(self, path, step=None):
    #print('Saving model to ', path)
    tf_graph = self.session.graph
    tf_names = "./other/meta_graph_test/data_spec_to_tf_names.txt"
    name_to_node = dict()
    with open(tf_names) as f:
        for line in f:
            line = line.strip()
            a,b = line.split(" = ")
            name_to_node[a] = tf_graph.get_tensor_by_name(b)
    inputs = {n: name_to_node[n] for n in name_to_node \
              if n not in {'logits', 'labels'}}
    outputs = {'logits': name_to_node['logits']}
    tf.saved_model.simple_save(self.session, path,
                           inputs=inputs,
                           outputs=outputs)

    def load(self, path):
        self.saver.restore(self.session, path)


class Data:
    def __init__(self, datadir, batch_size=64):
        self.batch_size = batch_size
        self.data_files = glob.glob(datadir + '/*.pickle')
        self._permutation = list(range(len(self.data_files)))
        random.shuffle(self._permutation)


    def next_batch(self):
        batch_size = min(self.batch_size, len(self._permutation))
        batch_indices, self._permutation = \
            self._permutation[:batch_size], self._permutation[batch_size:]
        batch_files = [self.data_files[i] for i in batch_indices]
        batch_data = [load_obj(f) for f in batch_files]
        return batch_data


    def epoch_finished(self):
        if len(self._permutation) == 0:
            self._permutation = list(range(len(self.data_files)))
            random.shuffle(self._permutation)
            #self._permutation = np.random.permutation(self.data_size)
            return True
        else:
            return False




#    def load_data(self, data_files, n_jobs=-1):
#        def load(fname):
#            gd, lls = cop.load_premsel(fname)
#            return (GraphData(gd), lls, fname)
#        load_d = delayed(load)
#        with Parallel(n_jobs=n_jobs) as parallel:
#            data = parallel(load_d(fname) for fname in data_files)
#        _, data = enumerate_symbols(data)
#        return data

def load_data(datadir):
    fnames = os.listdir(datadir)
    data = []
    for fname in fnames:
        graph_data, lens_labels_symbols = cop.load_premsel(
            os.path.join(datadir, fname))
        data.append((GraphData(graph_data), lens_labels_symbols, fname))
    return data


def enumerate_symbols(data):
    def truncate_skolem_single(symbol):
        if symbol.startswith("'skolem"):
            return "skolem"
        if symbol.startswith("'def"):
            return "def"
        return symbol
    def truncate_skolem(symbols):
        return map(truncate_skolem_single, symbols)
    symbol_set = set()
    for _, (_, _, funcs_rels), _ in data:
        funcs, rels = funcs_rels
        symbol_set.update(truncate_skolem(funcs + rels))
    symbol_to_num = dict(
        (symbol, i) for i, symbol in enumerate(sorted(symbol_set)))
    res_data = []
    for graph_data, (lens, labels, (funcs, rels)), fname in data:
        symbols = [symbol_to_num[symbol]
            for symbol in truncate_skolem(funcs + rels)]
        res_data.append((graph_data, (lens, labels, symbols), fname))
    return symbol_to_num, res_data



if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument('traindatadir', type=str)
    parser.add_argument('--testdatadir', type=str, default=None)
    parser.add_argument('--epochs', type=int, default=10)
    parser.add_argument('--batch_size', type=int, default=50)
    parser.add_argument('--load_path', type=str, default=None)
    parser.add_argument('--save_path', type=str, default=None)
    args = parser.parse_args()

    print("Loading data...")
    #test_data, train_data = load_data(args.datadir)
    train_data = Data(args.traindatadir)

    print("Constructing network...")
    network = Network()
    if args.load_path:
        network.load(args.load_path)
    #network.debug(data.test_data)

    premsel_accum = [1.0, 0.0, 0.0]
    symbol_accum = [1.0, 0.0]

    def update_accum(accum, current):
        for i, (acc, cur) in enumerate(zip(accum, current)):
            accum[i] = np.interp(0.1, [0, 1], [acc, cur])

    def stats_str(stats):
        if len(stats) == 2:
            return "loss {:.4f}, accuracy {:.4f}".format(*stats)
        else:
            return "loss {:.4f}, accuracy {:.4f} ({:.4f} / {:.4f})".format(
                stats[0], (stats[1] + stats[2]) / 2, stats[1], stats[2])

    # Training
    print("Training...")
    batch_size = args.batch_size
    for epoch_i in range(0, args.epochs):
        print(f"\nEpoch {epoch_i}.")
        #random.shuffle(train_data)
        #for i in range(0, len(train_data), batch_size):
        #    if (i // batch_size) % 100 == 0:
        #        if network.config.symbol_loss_ratio == 0:
        #            symbols_str = ""
        #        else:
        #            symbols_str = "; Symbols " + stats_str(symbol_accum)
        #        print('Training. Batch: {} / {}. Premsel: {}{}'.format(
        #            i, len(train_data), stats_str(premsel_accum), symbols_str,))
        #    batch = train_data[i:i + batch_size]
        while not train_data.epoch_finished():
            batch = train_data.next_batch()
            premsel_cur, symbol_cur, _, _ = network.train(batch)

            update_accum(premsel_accum, premsel_cur)
            update_accum(symbol_accum, symbol_cur)

        if args.save_path:
            network.save(args.save_path + '/' + str(epoch_i))

    if args.testdatadir:
        print("Testing...")
        test_data = Data(args.testdatadir)

        print("Reconstructing network...")
        network = Network()
        if args.load_path:
            network.load(args.load_path)

        testing_metrics = network.get_metrics(test_data.data)[0]
        print('Testing metrics:')
        print(f'  TPR: {testing_metrics[1]}')
        print(f'  TNR: {testing_metrics[2]}')

        predictions = network.predict_logits_1(test_data.data)
        for c in predictions:
            print(c)
            print(predictions[c])
        #print(predictions)

        predictions = network.predict_logits_1(train_data.data)
        for c in predictions:
            print(c)
            print(predictions[c])
