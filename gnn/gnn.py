import argparse, os, sys
from .premsel_network import Data, Network, load_data
from time import strftime
from glob import glob
from multiprocessing import Process
from time import time


def mkdir_if_not_exists(dirpath):
    if not os.path.exists(dirpath):
        os.makedirs(dirpath)

def date_time():
    return strftime('%Y%m%d%H%M%S')

def write_lines(list_of_lines, filename):
    with open(filename, encoding ='utf-8', mode='wt') as f:
        f.write('\n'.join(list_of_lines) + '\n')

def read_lines(filename):
    with open(filename, encoding ='utf-8') as f:
        return f.read().splitlines()

def premises_names(data_dir):
    conj_prems = {}
    for filename in os.listdir(data_dir):
        filename_full = os.path.join(data_dir, filename)
        f_lines = read_lines(filename_full)
        assert 'conjecture' in f_lines[0]
        conj = f_lines[0].split('fof(')[1].split(',')[0].strip(' ')
        assert conj in filename
        del f_lines[0]
        prems = []
        for l in f_lines:
            p = l.split('fof(')[1].split(',')[0].strip(' ')
            prems.append(p)
        conj_prems[filename] = prems
    return conj_prems

def train_gnn_model(train_data_dir, epochs, batch_size, save_each=20,
                    save_dir='gnn_models'):
    if save_each > epochs:
        save_each = epochs
    train_data = Data(train_data_dir, batch_size)
    print("Constructing network...")
    network = Network()
    # Training
    for epoch_i in range(1, epochs + 1):
        print(f"Epoch {epoch_i}.")
        i = 0
        while not train_data.epoch_finished():
            batch = train_data.next_batch()
            try:
                metrics, _, _, _ = network.train(batch)
            except:
                print('Training on batch failed.')
            #if i % 100:
            #    print(f"Loss: {metrics[0]:.5f}, "
            #          f"TPR: {metrics[1]:.2f}, TNR {metrics[2]:.2f}")
            #i += 1
        print(f"Loss: {metrics[0]:.5f}, "
              f"TPR: {metrics[1]:.2f}, TNR {metrics[2]:.2f}")
        if epoch_i % save_each == 0 or epoch_i == epochs:
            save_path = save_dir + '/epoch_' + str(epoch_i)
            network.save(save_path)
    return save_path


def rankings_from_gnn_model(test_data_dir, network_path, rankings_dir):
    mkdir_if_not_exists(rankings_dir)
    print("Reconstructing network...")
    network = Network()
    network.load(network_path)
    batch_dirs = glob(test_data_dir + '/*')
    premises_batches = []
    logits_batches = []
    for batch_dir in batch_dirs:
        #print("Processing", batch_dir)
        test_data_batch = load_data(batch_dir)
        logits_batch = network.predict_logits_1(test_data_batch)
        premises_batch = premises_names(batch_dir)
        logits_batches.append(logits_batch)
        premises_batches.append(premises_batch)
    logits = {c: lb[c] for lb in logits_batches for c in lb}
    premises = {c: pb[c] for pb in premises_batches for c in pb}
    assert len(logits) == len(premises)
    premises_logits = {}
    for f in logits:
        assert len(premises[f]) == len(logits[f])
        premises_logits[f] = list(zip(premises[f], logits[f]))
    premises_logits_conj = {}
    for f in premises_logits:
        c, _ = f.split('@')
        if not c in premises_logits_conj:
            premises_logits_conj[c] = premises_logits[f]
        else:
            premises_logits_conj[c].extend(premises_logits[f])
    for c in premises_logits_conj:
        premises_logits = premises_logits_conj[c]
        premises_logits.sort(key = lambda x: x[1], reverse = True)
        ranking = premises_logits[:2048]
        ranking = [t[0] for t in ranking]
        write_lines(ranking, os.path.join(rankings_dir, c))
    return rankings_dir

def predictions_from_gnn_model(test_data_dir, network_path):
    print("Reconstructing network...")
    network = Network()
    network.load(network_path)
    batch_dirs = glob(test_data_dir + '/*')
    premises_batches = []
    logits_batches = []
    for batch_dir in batch_dirs:
        #print("Processing", batch_dir)
        test_data_batch = load_data(batch_dir)
        logits_batch = network.predict_logits_1(test_data_batch)
        premises_batch = premises_names(batch_dir)
        logits_batches.append(logits_batch)
        premises_batches.append(premises_batch)
    logits = {c: lb[c] for lb in logits_batches for c in lb}
    premises = {c: pb[c] for pb in premises_batches for c in pb}
    assert len(logits) == len(premises)
    scored_prems = {}
    for c in logits:
        assert len(premises[c]) == len(logits[c])
        scored_prems[c] = list(zip(premises[c], logits[c]))
    return scored_prems

