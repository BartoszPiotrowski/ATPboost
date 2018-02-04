# ATPboost
Python package for doing Machine Learning experiments for Premise Selection task.

The goal adressed by the package is to provide a Python framework facilitating experiments with binary classification ML models for Premise Selection. This include simple ATP evaluation of these experiments with [E prover](http://wwwlehre.dhbw-stuttgart.de/~sschulz/E/E.html) and handling multiple proofs of one theorem -- this situation is naturally occuring when proving with ATPs and it needs to be taken into account when creating training data for ML models.

The experiments made with the package are continuation of the work exemplified by papers like:
* [Premise Selection for Mathematics by Corpus Analysis and Kernel Methods](https://link.springer.com/article/10.1007/s10817-013-9286-5)
* [DeepMath - Deep Sequence Models for Premise Selection](https://arxiv.org/abs/1606.04442)
* [Premise Selection for Theorem Proving by Deep Graph Embedding](http://papers.nips.cc/paper/6871-premise-selection-for-theorem-proving-by-deep-graph-embedding)

The package contains bunch of example experiments on corpus originating from [Mizar Mathematical Library](http://mizar.org/library/).

## Requirements
1. Python 3 (version >= 3.5)
2. `xgboost` and `sklearn` Python packages. Can be installed by running:
```
pip3 install xgboost sklearn
```
3. The newest version of `joblib` parallelization package (`joblib-0.11.1.dev0`) so far available only on GitHub. Can be installed by running:
```
pip3 install http://github.com/joblib/joblib/archive/master.zip
```
(Version `joblib-0.11` does not provide `loky` backend which works properly with `xgboost`.)

4. E prover. Can be installed by running:
```
wget http://wwwlehre.dhbw-stuttgart.de/~sschulz/WORK/E_DOWNLOAD/V_2.0/E.tgz
tar -xzf E.tgz
cd E
./configure
make
```
After installation there is also needed to set `EPROVER` environment variable to make known for our package where E prover is. Assuming you are still in `E` directory run:

```export EPROVER=`realpath PROVER/eprover` ```

To make this variable permanent -- put the line above to your `.bashrc` or `.zshrc` changing `` `realpath PROVER/eprover` ``
to `'path/to/E/PROVER/eprover'`.


