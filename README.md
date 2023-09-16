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
    Usually it is only necessary to adjust the Version number depending on the AstroPix Chip version:
    ```tcl
    # Example for default V3 Firmware, standard nexys setup
    #           board name	       Version    Defines               constraints file
    run_bit     astropix-nexys     3          {}                    $firmware_dir/constraints/constraints.tcl
    ```

3. **(Optional): Advanced settings**
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
    Multiple bitfiles with different configuraitons can be generated in one run, just add another line to the makefile:
    ```tcl
    # Generate both V3 default bitfile and V3 single-ended config bitfile
    #           board name	       Version    Defines               constraints file
    run_bit     astropix-nexys     3          {}                    $firmware_dir/constraints/constraints.tcl
    run_bit     astropix-nexys     3          {CONFIG_SE}           $firmware_dir/constraints/constraints.tcl
    ```
4. **Run vivado in tcl or batch mode with make.tcl**
    ```bash
    vivado -mode batch -source make.tcl
    ```
    A bitfile with the current configuration in its name will be created in the main directory.