python3 atpboost.py \
	--iterations 5 \
	--conjectures data/MPTP2078/conjectures \
	--train_deps data/MPTP2078/train_deps \
	--statements data/MPTP2078/statements \
	--features data/MPTP2078/features_binary \
	--chronology data/MPTP2078/chronology \
	--proving_script prove.sh \
	--ml_models gnn \
	--n_jobs 70 \
	--gnn_batch_size 128 \
	--gnn_n_deps_per_example 128 \
	--data_dir data/MPTP2078/atpboost_data \
	--logfile `echo $0 | sed 's/\.sh/.log/g'`

