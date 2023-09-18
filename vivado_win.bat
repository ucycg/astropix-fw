@echo OFF
call "F:\Xilinx\Vivado\2022.1\settings64.bat"

echo Sourced Vivado environment
if not exist "log" mkdir log
echo Create log folder

CMD /c vivado -mode batch -source make.tcl -log log/vivado.log -journal log/vivado.jou