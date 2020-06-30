virtualenv atpboost_venv --python=python36 # python 3.6. required for tensorflow 1.15 required for gnn
source atpboost_venv/bin/activate
pip3 install tqdm
pip3 install joblib
pip3 install sklearn
pip3 install xgboost
pip3 install tensorflow==1.15
pip3 install torch==1.5.1+cu101 torchvision==0.6.1+cu101 -f https://download.pytorch.org/whl/torch_stable.html
# for CUDA 10.1; see: https://pytorch.org/get-started/locally/ for other versions of CUDA
pip3 install opennmt-py

# installing E prover
wget http://wwwlehre.dhbw-stuttgart.de/~sschulz/WORK/E_DOWNLOAD/V_2.4/E.tgz
tar -xzf E.tgz
cd E
./configure
make
cd ..
cp E/PROVER/eprover .

