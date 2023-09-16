#!/usr/bin/tclsh

# This script creates Vivado projects and bitfiles for the supported hardware platforms

# Get project file dir
variable myLocation [file normalize [info script]]
proc getResourceDirectory {} {
    variable myLocation
    return [file dirname $myLocation]
}

global firmware_dir
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

proc run_bit {board version defines constraints_file} {
    global defines_list
    global chipversion


    if {$board == "astropix-nexys"} {
        set part "xc7a200tsbg484-1"
    } else {
        puts "ERROR: Unsupported board $board specified!"
        return -level 1 -code error
    }

    set chipversions [list 2 3]
    if {[lsearch -exact $chipversions $version] == -1} {
        puts "ERROR: Invalid chipversion $version specified!"
        return -level 1 -code error
    } else {
        set chipversion $version
        puts "INFO: Valid chipversion $chipversion specified!"
    }

    if {([lsearch -exact $defines CLOCK_SE_DIFF] != -1) && ([lsearch -exact $defines CLOCK_SE_SE] != -1)} {
        puts "ERROR: CLOCK_SE cannot be both single-ended and differential"
        return -level 1 -code error
    } else {
        puts "CLOCK_SE config valid!"
    }

    if {[lsearch -exact $defines TELESCOPE] != -1} {
        puts "INFO: Configured for telescope setup!"
    } else {
        puts "INFO: Not configured for telescope setup!"
    }

    set defines_list $defines
    puts "INFO: Set verilog defines $defines_list"

    set defines_string [join $defines _]
    append design_name "$board\_$chipversion\_$defines_string"

    # Start Flow
    create_project -force -part $part $design_name designs
    read_design_files
    read_syn_ip

    # TCL constraints
    read_xdc -unmanaged $constraints_file

    #generate_target -verbose -force all [get_ips]

    global include_dirs
    global firmware_dir

    synth_design -top main_top -include_dirs $include_dirs -verilog_define "SYNTHESIS=1 $defines_list"
    opt_design
    place_design
    phys_opt_design
    route_design
    report_utilization
    report_timing -file "reports/report_timing.$design_name.log"
    write_bitstream -force -file $design_name
    #write_cfgmem -format mcs -size 64 -interface SPIx1 -loadbit "up 0x0 $board.bit" -force -file $board
    #write_cfgmem -force -format bin -interface spix4 -size 16 -loadbit "up 0x0 output/$board.bit" -file output/$board.bin
    close_project
}
