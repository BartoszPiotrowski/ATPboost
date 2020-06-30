python3 atpboost.py \
	--conjectures data/MPTP2078/conjectures \
	--train_deps data/MPTP2078/train_deps \
	--statements data/MPTP2078/statements \
    --features data/MPTP2078/features_binary \
    --chronology data/MPTP2078/chronology \
	--ml_models xgboost \
	--xgb_rounds 4000 \
	--xgb_eta 0.2 \
	--xgb_knn_prefiltering 0 \
    --mining 0.1 \
    --iterations 100 \
	--n_jobs 70 \
	--data_dir data/MPTP2078/atpboost_data \

