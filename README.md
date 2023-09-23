# astropix-fw
Unified firmware for AstroPix V2,V3 with support for several special configurations, as wells as the [telescope setup](https://github.com/nic-str/astropix-telescope).

#### Prerequisites

1. **Install [Vivado](https://www.xilinx.com/support/download/index.html/content/xilinx/en/downloadNav/vivado-design-tools.html) 2022.1 or newer**
2. **Setup vivado run script**
    Set the path to your Vivado settings file
    \
    Linux:
    ```bash
    # vivado.sh
    # example: source /tools/Xilinx/Vivado/2022.1/settings64.sh
    source <your-install-dir>/settings64.sh
    ```

    Windows:
    ```bash
    # vivado_win.bat
    # example: call "c:\Xilinx\Vivado\2022.1\settings64.bat"
    call "<your-install-dir>/settings64.bat"
    ```

#### Getting started
1. **Adjust settings in make.tcl**
    Usually it is only necessary to adjust the Version number depending on the AstroPix Chip version:
    ```tcl
    # Example for default V3 Firmware, standard nexys setup
    #           board name	       Version    Defines               constraints file
    run_bit     astropix-nexys     3          {}                    $firmware_dir/constraints/constraints.tcl
    ```

2. **(Optional): Advanced settings**
    If needed one or multiple of the following options can be set:
    - **CLOCK_SE_DIFF**: Single-ended sampleclock with LVDS receiver on carrier pcb
    - **CLOCK_SE_SE**: Single-ended sampleclock without LVDS receiver on carrier pcb
    - **CONFIG_SE**: Single ended asic config
    - **TELESCOPE**: Telescope setup: onchip injection disabled, 4 differential sampleclock outputs
    ```tcl
    # Example V2 telescope firmware with single ended asic config
    #           board name	       Version    Defines               constraints file
    run_bit     astropix-nexys     2          {TELESCOPE CONFIG_SE} $firmware_dir/constraints/constraints.tcl
    ```
    \
    Multiple bitfiles with different configuraitons can be generated in one run, just add another line to the makefile:
    ```tcl
    # Generate both V3 default bitfile and V3 single-ended config bitfile
    #           board name	       Version    Defines               constraints file
    run_bit     astropix-nexys     3          {}                    $firmware_dir/constraints/constraints.tcl
    run_bit     astropix-nexys     3          {CONFIG_SE}           $firmware_dir/constraints/constraints.tcl
    ```

3. **Run vivado script**
    Linux:
    ```bash
    ./vivado.sh
    ```

    Windows:
    ```bash
    vivado_win.bat
    ```
    A bitfile with the current configuration in its name will be created in the main directory.