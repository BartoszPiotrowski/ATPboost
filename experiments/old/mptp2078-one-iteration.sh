python3 atpboost.py \
	--iterations 1 \
	--conjectures data/MPTP2078/conjectures \
	--train_deps data/MPTP2078/train_deps \
	--statements data/MPTP2078/statements \
	--features data/MPTP2078/features_binary \
	--chronology data/MPTP2078/chronology \
	--proving_script prove-old.sh \
	--ml_models xgboost \
	--mining 0 \
	--n_jobs 70 \
	--xgb_rounds 5000 \
	--xgb_knn_prefiltering 10000 \
	--data_dir data/MPTP2078/atpboost_data \
	--logfile `echo $0 | sed 's/\.sh/.log/g'`

