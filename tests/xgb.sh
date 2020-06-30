python3 atpboost.py \
	--iterations 2 \
	--conjectures data/example/conjectures \
	--train_deps data/example/train_deps \
	--statements data/example/statements \
	--features data/example/features_binary \
	--chronology data/example/chronology \
	--proving_script prove-2s.sh \
	--ml_models xgboost \
	--mining 0.1 \
	--n_jobs -1 \
	--data_dir data/example/atpboost_data \
	--logfile `echo $0 | sed 's/\.sh/.log/g'`

