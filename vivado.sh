source /tools/Xilinx/Vivado/2022.1/settings64.sh

mkdir -p log

vivado -mode batch -source make.tcl -log log/vivado.log -journal log/vivado.jou
