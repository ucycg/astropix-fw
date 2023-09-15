# astropix-fw
Unified firmware for AstroPix V2,V3, ... as well as special configuration for single ended asic config or the [telescope setup](https://github.com/nic-str/astropix-telescope).


1. **Source vivado environment**

    Linux:
    ```bash
    cd <Vivado install-dir>
    source settings64.sh
    ```
    Windows:
    ```bash
    cd <Vivado install-dir>
    settings64.bat
    ```
2. **Adjust settings in make.tcl**
    ```tcl
    # Example for default V3 Firmware
    #       FPGA type           board name	       Version    Defines               constraints file
    run_bit xc7a200tsbg484-1    astropix-nexys     3          {}                    $firmware_dir/constraints/constraints.tcl

    # Example V3 firmware with single ended config
    #       FPGA type           board name	       Version    Defines               constraints file
    run_bit xc7a200tsbg484-1    astropix-nexys     3          {CONFIG_SE}  $firmware_dir/constraints/constraints.tcl
    ```
3. **Run vivado in tcl or batch mode with make.tcl**
    ```bash
    vivado -mode batch -source make.tcl
    ```
    A bitfile with the current configuraiton in its name will be created in the main directory