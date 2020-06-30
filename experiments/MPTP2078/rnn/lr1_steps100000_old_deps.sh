python3 atpboost.py \
	--iterations 5 \
	--conjectures data/MPTP2078/conjectures \
	--train_deps data/MPTP2078/train_deps \
	--statements data/MPTP2078/statements \
	--features data/MPTP2078/features_binary \
	--chronology data/MPTP2078/chronology \
	--proving_script prove.sh \
	--ml_models rnn \
	--n_jobs 70 \
	--rnn_train_steps 100000 \
	--rnn_learning_rate 1 \
	--data_dir data/MPTP2078/atpboost_data \
	--logfile `echo $0 | sed 's/\.sh/.log/g'`

