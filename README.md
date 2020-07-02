# Installation

Basic:
```
./install.sh # creates a virtual environment atpboost_venv
source atpboost_venv/bin/activate
```
Now you shoudl be able to run `tests/xgb.sh` and `tests/knn.sh` scripts.

With GNN and RNN support:

```
./install-nn.sh # creates a virtual environment atpboost_venv
source atpboost_venv/bin/activate
```
Now you shoudl be able to run all test scripts from `tests` directory.


# An example how to run ATPboost

```
python3 atpboost.py \
    --iterations 10 \
    --conjectures data/example/conjectures \
    --train_deps data/example/train_deps \
    --statements data/example/statements \
    --features data/example/features_binary \
    --chronology data/example/chronology \
    --ml_models xgboost \
    --mining 0.1 \
	--n_jobs 50 \
    --data_dir data/example/atpboost_data
```

# The paper describing an earlier version of ATPboost
* B. Piotrowski and J. Urban, ATPboost: Learning Premise Selection in Binary Setting with ATP Feedback IJCAR 2018, pp. 566-574, https://arxiv.org/abs/1802.03375
