#!/usr/bin/tclsh
source flow.tcl

#
# Create bitfiles
#

# Add to list to set special defines
# CLOCK_SE_DIFF # if single-ended sampleclock output should be used
# CLOCK_SE_SE # if LVDS Receiver is not asembled on carrier pcb, remember to connect IN+ with Out
# CONFIG_SE # if GECCO Board has no lvds receivers for SR config
# TELESCOPE # if telescope setup is used

#       FPGA type           board name	        Version    Defines                                  constraints file
run_bit xc7a200tsbg484-1    astropix-nexys      2          {TELESCOPE CLOCK_SE_SE}                  $firmware_dir/constraints/constraints.tcl