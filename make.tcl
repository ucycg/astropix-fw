#   This script creates Vivado projects and bitfiles for the supported hardware platforms
#
#   Start vivado in tcl mode by typing:
#       vivado -mode tcl -source ../vivado/make.tcl
#

# Get project file dir
variable myLocation [file normalize [info script]]
proc getResourceDirectory {} {
    variable myLocation
    return [file dirname $myLocation]
}


set firmware_dir [getResourceDirectory]
puts "Firware directory: $firmware_dir"

set include_dirs [list $firmware_dir/src]

file mkdir reports

proc read_design_files {} {

    global firmware_dir

    read_verilog $firmware_dir/src/main_top.v

    add_files -norecurse $firmware_dir/src
}

proc read_syn_ip {} {

    puts "Read and Synth IP"
    global firmware_dir

    read_ip $firmware_dir/src/ip/async_fifo_ftdi/async_fifo_ftdi.xci
    read_ip $firmware_dir/src/ip/clk_wiz_0/clk_wiz_0.xci
    read_ip $firmware_dir/src/ip/spi_write_fifo/spi_write_fifo.xci
    read_ip $firmware_dir/src/ip/spi_read_fifo/spi_read_fifo.xci
    read_ip $firmware_dir/src/ip/sr_readback_fifo/sr_readback_fifo.xci
    synth_ip [get_ips]
}

proc run_bit { part board version defines constraints_file} {
    global defines_list
    global chipversion

    set chipversion $version
    set defines_list $defines

    create_project -force -part $part $board designs

    puts "Set verilog defines $defines_list"

    read_design_files
    read_syn_ip
    # read_xdc $xdc_file

    #Load constraints
    add_files -fileset [current_fileset -constrset] $constraints_file

    #generate_target -verbose -force all [get_ips]

    global include_dirs
    global firmware_dir

    synth_design -top main_top -include_dirs $include_dirs -verilog_define "SYNTHESIS=1 $defines_list"
    opt_design
    place_design
    phys_opt_design
    route_design
    report_utilization
    report_timing -file "reports/report_timing.$board.log"
    write_bitstream -force -file "$board\_V$chipversion\_$defines_list"
    #write_cfgmem -format mcs -size 64 -interface SPIx1 -loadbit "up 0x0 $board.bit" -force -file $board
    #write_cfgmem -force -format bin -interface spix4 -size 16 -loadbit "up 0x0 output/$board.bit" -file output/$board.bin
    close_project
}
#########

#
# Create projects and bitfiles
#

# Uncomment to set special defines
# set defines_list [list se_clock $defines_list]; # if single-ended sampleclock output should be used
# set defines_list [list se_clock_singleende $defines_list]; # if LVDS Receiver is not asembled on carrier pcb, remember to connect IN+ with Out
# set defines_list [list config_singleended]; # config_singleended # if GECCO Board has no lvds receivers for SR config

#       FPGA type           board name	       Version    Defines                      constraints file
run_bit xc7a200tsbg484-1    astropix-nexys     3          {config_singleended}         $firmware_dir/constraints/constraints.tcl
run_bit xc7a200tsbg484-1    astropix-nexys     2          {config_singleended}         $firmware_dir/constraints/constraints.tcl
run_bit xc7a200tsbg484-1    astropix-nexys     3          {}                           $firmware_dir/constraints/constraints.tcl
run_bit xc7a200tsbg484-1    astropix-nexys     2          {}                           $firmware_dir/constraints/constraints.tcl

exit
