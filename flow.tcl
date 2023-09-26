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
file mkdir bitstreams

proc read_design_files {} {

    global firmware_dir

    read_verilog $firmware_dir/src/main_top.v

    add_files -norecurse $firmware_dir/src
    add_files -norecurse $firmware_dir/src/oled
}

proc read_syn_ip {board_name} {

    puts "Read and Synth IP"
    global firmware_dir

    read_ip $firmware_dir/ip/async_fifo_ftdi/async_fifo_ftdi.xci
    read_ip $firmware_dir/ip/clk_wiz_0/clk_wiz_0.xci
    read_ip $firmware_dir/ip/spi_write_fifo/spi_write_fifo.xci
    read_ip $firmware_dir/ip/spi_read_fifo/spi_read_fifo.xci
    read_ip $firmware_dir/ip/sr_readback_fifo/sr_readback_fifo.xci

    # Oled IP
    read_ip $firmware_dir/ip/oled/charLib/charLib.xci
    read_ip $firmware_dir/ip/oled/init_sequence_rom/init_sequence_rom.xci
    read_ip $firmware_dir/ip/oled/pixel_buffer/pixel_buffer.xci

    report_ip_status

    # Upgrade clk_wiz if version is old or board_part to matching or missing
    upgrade_ip_helper $board_name clk_wiz clk_wiz_0

    # Upgrade fifo if version is old or board_part to matching or missing
    set fifo_ip [list async_fifo_ftdi spi_write_fifo spi_read_fifo sr_readback_fifo]
    foreach ip_core $fifo_ip {
        upgrade_ip_helper $board_name fifo_generator $ip_core
    }

    # Upgrade oled ip if version is old or board_part to matching or missing
    set oled_ip [list charLib pixel_buffer init_sequence_rom]
    foreach ip_core $oled_ip {
        upgrade_ip_helper $board_name blk_mem_gen $ip_core
    }

    synth_ip [get_ips]
}

proc upgrade_ip_helper {board_name base_ip ip_core} {
    # Upgrade IP if old, incorrect part or locked
    set old_version [expr {[get_property VLNV [get_ipdefs -filter VLNV=~*:$base_ip:*]] ne [get_property IPDEF [get_ips $ip_core]]}]
    set wrong_board [expr {$board_name ne [get_property BOARD [get_ips $ip_core]]}]
    set locked      [expr {$ip_core in [get_ips -filter "IS_LOCKED==1"]}]

    if {$old_version || $wrong_board || $locked} {
        puts "INFO: Upgrade $ip_core IP core"
        upgrade_ip [get_ips $ip_core]
        export_ip_user_files -of_objects [get_ips $ip_core] -no_script -sync -force -quiet
    } else {
        puts "INFO: Do not upgrade $ip_core IP core"
    }
}

proc run_bit {board version defines constraints_file} {

    global defines_list
    global chipversion
    global include_dirs
    global firmware_dir

    set supported_chipversions [list 2 3]
    set supported_defines [list CLOCK_SE_SE CLOCK_SE_DIFF CONFIG_SE TELESCOPE]
    array set supported_boards {
        astropix-nexys   {xc7a200tsbg484-1 digilentinc.com:nexys_video:part0:1.2}
    }
    #astropix-nexys   "xc7a200tsbg484-1"

    if {[info exists supported_boards($board)]} {
        set board_name  [lindex $supported_boards($board) 1]
        set part        [lindex $supported_boards($board) 0]
    } else {
        puts "ERROR: Unsupported board $board specified!"
        return -level 1 -code error
    }

    if {$version in $supported_chipversions} {
        set chipversion $version
        puts "INFO: Valid chipversion $chipversion specified!"
    } else {
        puts "ERROR: Invalid chipversion $version specified!"
        return -level 1 -code error
    }

    foreach item $defines {
        if {$item ni $supported_defines} {
            puts "ERROR: Invalid define $item specified! Valid defines are: $supported_defines"
            return -level 1 -code error
        }
    }

    if {("CLOCK_SE_SE" in $defines) && ("CLOCK_SE_DIFF" in $defines)} {
        puts "ERROR: CLOCK_SE cannot be both single-ended and differential"
        return -level 1 -code error
    } else {
        puts "INFO: CLOCK_SE config valid!"
    }

    if {"TELESCOPE" in $defines} {
        puts "INFO: Configured for telescope setup!"
    } else {
        puts "INFO: Not configured for telescope setup!"
    }

    set defines_list $defines
    puts "INFO: Set verilog defines $defines_list"

    set defines_string [join $defines _]
    append design_name "$board\_$chipversion\_$defines_string"


    # Set board file
    set_param board.repoPaths $firmware_dir/board_files
    set REPOPATH [get_param board.repoPaths]
    puts $REPOPATH

    # Start Flow
    create_project -force -part $part $design_name designs
    #create_project -force $design_name designs

    set_property board_part $board_name [current_project]

    read_design_files
    read_syn_ip $board_name

    # TCL constraints
    read_xdc -unmanaged $constraints_file

    #generate_target -verbose -force all [get_ips]

    synth_design -top main_top -include_dirs $include_dirs -verilog_define "SYNTHESIS=1 ASTROPIX${chipversion} $defines_list"
    opt_design
    place_design
    phys_opt_design
    route_design
    report_utilization
    report_timing -file "reports/report_timing.$design_name.log"
    write_verilog -force netlists/$design_name.v -mode timesim -sdf_anno true
    write_bitstream -force -file bitstreams/$design_name
    #write_cfgmem -format mcs -size 64 -interface SPIx1 -loadbit "up 0x0 $board.bit" -force -file $board
    #write_cfgmem -force -format bin -interface spix4 -size 16 -loadbit "up 0x0 output/$board.bit" -file output/$board.bin
    close_project
}
