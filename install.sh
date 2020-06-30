virtualenv atpboost_venv
source atpboost_venv/bin/activate
pip3 install tqdm
pip3 install joblib
pip3 install sklearn
pip3 install xgboost

# installing E prover
wget http://wwwlehre.dhbw-stuttgart.de/~sschulz/WORK/E_DOWNLOAD/V_2.4/E.tgz
tar -xzf E.tgz
cd E
./configure
make
cd ..
cp E/PROVER/eprover .
