/*
 * ATLASPix3_SoftAndFirmware
 * Copyright (C) 2019  Rudolf Schimassek (rudolf.schimassek@kit.edu)
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * This module was initially developed by Felix Ehrler and Richard Leys
 */
`timescale 1ns / 1ps
module ftdi_top (
    input  wire			clk,
    input  wire 		res_n,
    input  wire 		prog_clko,
    input  wire 		FTDI_TXE_N,
    input  wire 		FTDI_RXF_N,
    output wire 		FTDI_RD_N,
    output wire 		FTDI_OE_N,
    output wire 		FTDI_WR_N,
    inout  wire [7:0] 	FTDI_DATA,

    output wire 		ChipConfig_Clock1,
    output wire 		ChipConfig_Clock2,
    output wire 		ChipConfig_Data,
    output wire 		ChipConfig_Load,
    output wire         ChipConfig_Res_n,
    output wire         ChipConfig_Readback,

    output wire         ChipConfig_LdDAC,
    output wire         ChipConfig_LdConfig,
    output wire         ChipConfig_LdVDAC,
    output wire         ChipConfig_LdTDAC,
    output wire         ChipConfig_LdRow,
    output wire         ChipConfig_LdColumn,
    output wire [3:0]   ChipConfig_WrRAM,
    output wire         ChipConfig_no_sr,

    output wire        reset_autoreset_analog,
    input  wire        reset_regulator_reset_out,
    output wire        reset_reset_analog_b,
    output wire        reset_autoreset_digital,
    input  wire        reset_por,
    output wire        reset_reset_digital_b,
    input  wire        reset_por_test_reset,
    output wire        reset_autoreset_combine,

    output wire        config_mode_use_spi,
    output wire        config_mode_bypass_cmd,
    output wire        config_mode_encdr,
    output wire        config_mode_en_pll,
    output wire        config_mode_cmd_clock_invert,
    output wire        config_mode_interface_speed,
    output wire        config_mode_take_fast,

    output wire 		patgen_Reset,
    output wire 		patgen_Suspend,
    output wire 		patgen_writeStrobe,
    output wire [7:0] 	patgen_address,
    output wire [7:0] 	patgen_data,
	output wire 		injection_gecco,
	output wire 		injection_chip,
	output wire 		patgen_synced,
	output wire         patgen_tsoverflow_sync,
	output wire [7:0]   patgen_skipsignals,

    output wire 		VoltageBoard_Clock,
    output wire 		VoltageBoard_Data,
    output wire 		VoltageBoard_Load,

    output wire        spi_config_reset,
    output wire [7:0]  spi_clock_divider,
    output wire [31:0] spi_write_fifo_dout,
    input  wire        spi_write_fifo_rd_clk,
    input  wire        spi_write_fifo_rd_en,
    output wire        spi_write_fifo_empty,

    input  wire [63:0] spi_read_fifo_din,
    input  wire        spi_read_fifo_wr_clk,
    input  wire        spi_read_fifo_wr_en,
    output wire        spi_read_fifo_full,
    output wire        spi_config_readback_en,

    output wire        sr_readback_config_reset,
    input  wire [63:0] sr_readback_fifo_din,
    input  wire        sr_readback_fifo_wr_clk,
    input  wire        sr_readback_fifo_wr_en,
    output wire        sr_readback_fifo_full,

    output wire [7:0] 	ordersorter_data,

    input wire hit_interrupt
);
    // Parametersrs
    //---------------


    // Signaling
    //---------------
    wire  [7:0] rfg_read_data;
    wire  rfg_read_done;


    wire [3:0] ordersorter_state;



//-- FIFO Connection
wire            wi_clk;
wire            wi_wr;
wire    [7:0]   wi_data;
wire            wi_full;
wire            wi_almost_full;

//-- FIFO interface for reading data from the FTDI
wire            ri_read;
wire    [7:0]   ri_data;
wire            ri_empty;
wire            ri_almost_empty;

// Assigments
//---------------
assign ordersorter_data = {ordersorter_state [3:0], ri_data [3:0]};


//-- Order Sorter
wire [7:0] ordersorter_header;
wire [7:0] ordersorter_address;
wire [15:0] ordersorter_length;
wire [7:0] ordersorter_value;
wire ordersorter_read;
wire  ordersorter_write;
wire  writeFIFO_prog_full;

OrderSorter ordersorter_I (
    .ri_data(ri_data),
    .ri_empty(ri_empty),
    .ri_read(ri_read),
    .pcreadfifofull(writeFIFO_prog_full),
    .clk(clk),
    .res_n(res_n),
    .header(ordersorter_header),
    .address(ordersorter_address),
    .length(ordersorter_length),
    .value(ordersorter_value),
    .read(ordersorter_read),
    .write(ordersorter_write),
    .state(ordersorter_state [3:0])
);

//Parameter definition
parameter   PRIORITY = 1'b0; // 1'b0 = read priority,  1'b1 = write priority



//wire and register definitions

//fifo control signals
wire            writeFIFO_almost_empty;
wire            writeFIFO_empty;
wire            writeFIFO_rd_en;
wire            readFIFO_almost_full;
//wire            readFIFO_full;
wire            readFIFO_wr_en;

//wires for connecting the FIFO data busses to the IO buffer
wire    [7:0]   data2ftdi;
wire    [7:0]   data2fifo;


//Asynchronous assignments
assign writeFIFO_rd_en  = ~FTDI_TXE_N && ~FTDI_WR_N;
assign readFIFO_wr_en   = ~FTDI_RXF_N && ~FTDI_RD_N;

// FIFO for writing to the FTDI
//----------------------
async_fifo_ftdi writeFIFO_I (
	.rd_clk(prog_clko),
	.rd_en(writeFIFO_rd_en || ~res_n),
	.rst(~res_n),
    .dout(data2ftdi),

    // Write to FIFO when there is a read_done from RFG
    .wr_clk(clk),
	.wr_en(rfg_read_done),
    .din(rfg_read_data),
	.almost_empty(writeFIFO_almost_empty),

	.empty(writeFIFO_empty),
	.full(wi_full),
	.almost_full(wi_almost_full),
	.prog_full(writeFIFO_prog_full)
);


//FIFO for reading data from the FTDI
//---------------------
async_fifo_ftdi readFIFO_I (
	.din(data2fifo),
	.rd_clk(clk),
	.rd_en(ri_read),
	.rst(~res_n),
	.wr_clk(prog_clko),
	.wr_en(readFIFO_wr_en),
	.almost_empty(ri_almost_empty),
	.almost_full(readFIFO_almost_full),
	.dout(ri_data),
	.empty(ri_empty),
	.full()
);

//controlling FSM
ftdi_interface_control_fsm fsm_I (
    .clk(prog_clko),
    .res_n(res_n),
    .rxf_n(FTDI_RXF_N),
    .txe_n(FTDI_TXE_N),
    .rf_almost_full(readFIFO_almost_full),
    .wf_almost_empty(writeFIFO_almost_empty),
    .wf_empty(writeFIFO_empty),
    .prio(PRIORITY),
    .rd_n(FTDI_RD_N),
    .oe_n(FTDI_OE_N),
    .wr_n(FTDI_WR_N)
);

//IO Buffer for the bidirectional data bus to the FTDI
genvar i;
generate
    for (i = 0; i < 8; i = i + 1) begin: buffer
        IOBUF ftdi_data_obuft_I (
            .I(data2ftdi[i]),
            .O(data2fifo[i]),
            .T(~FTDI_OE_N),
            .IO(FTDI_DATA[i])
        );
    end
endgenerate



assign patgen_address[7:4] = 0;

    // Instances
    //---------------
RegisterFile rfg_I (
    .clk(clk),
    .res_n(res_n),
    .read(ordersorter_read),
    .read_data(rfg_read_data),
    .write(ordersorter_write),
    .write_data(ordersorter_value),
    .done(rfg_read_done),
    .address(ordersorter_address[7:0]),

    .ChipConfig_Clock1(ChipConfig_Clock1),
    .ChipConfig_Clock2(ChipConfig_Clock2),
    .ChipConfig_Data(ChipConfig_Data),
    .ChipConfig_Load(ChipConfig_Load),
    .ChipConfig_Res_n(ChipConfig_Res_n),
    .ChipConfig_Readback(ChipConfig_Readback),

    .ChipConfig_LdDAC(ChipConfig_LdDAC),
    .ChipConfig_LdConfig(ChipConfig_LdConfig),
    .ChipConfig_LdVDAC(ChipConfig_LdVDAC),
    .ChipConfig_LdTDAC(ChipConfig_LdTDAC),
    .ChipConfig_LdRow(ChipConfig_LdRow),
    .ChipConfig_LdColumn(ChipConfig_LdColumn),
    .ChipConfig_WrRAM(ChipConfig_WrRAM),
    .ChipConfig_no_sr(ChipConfig_no_sr),

    .reset_autoreset_analog(reset_autoreset_analog),
    .reset_regulator_reset_out(reset_regulator_reset_out),
    .reset_reset_analog_b(reset_reset_analog_b),
    .reset_autoreset_digital(reset_autoreset_digital),
    .reset_por(reset_por),
    .reset_reset_digital_b(reset_reset_digital_b),
    .reset_por_test_reset(reset_por_test_reset),
    .reset_autoreset_combine(reset_autoreset_combine),

    .config_mode_use_spi(config_mode_use_spi),
    .config_mode_bypass_cmd(config_mode_bypass_cmd),
    .config_mode_encdr(config_mode_encdr),
    .config_mode_en_pll(config_mode_en_pll),
    .config_mode_cmd_clock_invert(config_mode_cmd_clock_invert),
    .config_mode_interface_speed(config_mode_interface_speed),
    .config_mode_take_fast(config_mode_take_fast),

    .patgen_Reset(patgen_Reset),
    .patgen_Suspend(patgen_Suspend),
    .patgen_writeStrobe(patgen_writeStrobe),
    .patgen_address(patgen_address[3:0]),
    .patgen_data(patgen_data),
	.patgen_synced(patgen_synced),
	.injection_gecco(injection_gecco),
	.injection_chip(injection_chip),
	.patgen_tsoverflow_sync(patgen_tsoverflow_sync),
	.patgen_skipsignals(patgen_skipsignals),

    .VoltageBoard_Clock(VoltageBoard_Clock),
    .VoltageBoard_Data(VoltageBoard_Data),
    .VoltageBoard_Load(VoltageBoard_Load),

    .spi_config_reset(spi_config_reset),
    .spi_clock_divider(spi_clock_divider),
    .spi_write_fifo_dout(spi_write_fifo_dout),
    .spi_write_fifo_rd_clk(spi_write_fifo_rd_clk),
    .spi_write_fifo_rd_en(spi_write_fifo_rd_en),
    .spi_write_fifo_empty(spi_write_fifo_empty),

    .spi_read_fifo_din(spi_read_fifo_din),
    .spi_read_fifo_wr_clk(spi_read_fifo_wr_clk),
    .spi_read_fifo_wr_en(spi_read_fifo_wr_en),
    .spi_read_fifo_full(spi_read_fifo_full),
    .spi_read_fifo_rd_en(ordersorter_read),
    .spi_config_readback_en(spi_config_readback_en),

    .sr_readback_config_reset(sr_readback_config_reset),
    .sr_readback_fifo_din(sr_readback_fifo_din),
    .sr_readback_fifo_wr_clk(sr_readback_fifo_wr_clk),
    .sr_readback_fifo_wr_en(sr_readback_fifo_wr_en),
    .sr_readback_fifo_full(sr_readback_fifo_full),
    .sr_readback_fifo_rd_en(ordersorter_read),

    .hit_interrupt(hit_interrupt)
);




endmodule
