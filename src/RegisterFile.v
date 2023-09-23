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
//////////////////////////////////////////////////////////////////////////////////
// Company:     KIT-ADL
// Engineer:    Felix Ehrler, Richard Leys
//
// Create Date: 21.03.2016
// Design Name:
// Module Name: H35Demo_rf
// Project Name:
// Target Devices:
// Tool Versions:
// Description:
//
// Dependencies:
//
// Revision:
// Revision 0.01 - File Created
// Revision 1.0  - renamed module to "RegisterFile"
//               - simplified the structures for reading and writing
//               - removed double words from inputs/outputs
//              [02.08.2019, Rudolf Schimassek]
// Additional Comments:
//
//////////////////////////////////////////////////////////////////////////////////

module RegisterFile (
    input  wire        clk,
    input  wire        res_n,
    input  wire        read,
    output reg [7:0]   read_data,
    input  wire        write,
    input  wire [7:0]  write_data,
    output reg         done,
    input  wire [7:0]  address,

    output wire        ChipConfig_Clock1,
    output wire        ChipConfig_Clock2,
    output wire        ChipConfig_Data,
    output wire        ChipConfig_Load,
    output wire        ChipConfig_Res_n,
    output wire        ChipConfig_Readback,

    output wire        ChipConfig_LdDAC,
    output wire        ChipConfig_LdConfig,
    output wire        ChipConfig_LdVDAC,
    output wire        ChipConfig_LdTDAC,
    output wire        ChipConfig_LdRow,
    output wire        ChipConfig_LdColumn,
    output wire [3:0]  ChipConfig_WrRAM,
    output wire        ChipConfig_no_sr,

    output wire        patgen_Reset,
    output wire        patgen_Suspend,
    output wire        patgen_writeStrobe,
    output wire [3:0]  patgen_address,
    output wire [7:0]  patgen_data,
    output wire        patgen_synced,
	output wire 	   injection_gecco,
	output wire		   injection_chip,
	output wire        patgen_tsoverflow_sync,
	output wire [7:0]  patgen_skipsignals,

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

	output wire        VoltageBoard_Clock,
	output wire        VoltageBoard_Data,
	output wire        VoltageBoard_Load,

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
    input  wire        spi_read_fifo_rd_en,  //connect to ordersorter_read
    output wire        spi_config_readback_en,

    output wire        sr_readback_config_reset,
    input  wire [63:0] sr_readback_fifo_din,
    input  wire        sr_readback_fifo_wr_clk,
    input  wire        sr_readback_fifo_wr_en,
    output wire        sr_readback_fifo_full,
    input  wire        sr_readback_fifo_rd_en,  //connect to ordersorter_read

    input wire hit_interrupt
);


//---------------
// Signaling
//---------------
reg   [7:0]  ChipConfig;
reg   [7:0]  ChipConfig_Lds = 8'b0000_0000;
reg   [7:0]  ChipConfig_RAMwr;
reg   [7:0]  reset_reg;
wire  [7:0]  reset_wire;
reg   [7:0]  config_mode;

reg   [7:0]  VoltageBoard;
reg   [7:0]  patgen_address_reg;
reg   [7:0]  patgen_data_reg;
reg   [7:0]  patgen_Reset_reg;
reg   [7:0]  patgen_Suspend_reg;
reg   [7:0]  patgen_writeStrobe_reg;
reg   [7:0]  patgen_config;
reg   [7:0]  patgen_skipsignals_reg;

//SPI FIFOs:
reg   [7:0]  spi_config;
wire  [7:0]  spi_config_wire;
reg   [7:0]  spi_clock_divider_reg;
//  write FIFO
wire         spi_config_wr_fifo_reset;
wire  [7:0]  spi_write_fifo_din;
wire         spi_write_fifo_wr_en;
wire         spi_write_fifo_full;
//  read FIFO
wire         spi_config_rd_fifo_reset;
wire  [7:0]  spi_read_fifo_dout;
reg   [2:0]  spi_read_fifo_rdcount;
reg          spi_read_fifo_empty_at_start = 0;
wire         spi_read_fifo_load_from_fifo;
wire         spi_read_fifo_empty;
wire         spi_read_fifo_rd_en_real;

//  SR readback FIFO
reg   [7:0]  sr_readback_config;
wire  [7:0]  sr_readback_fifo_dout;
reg   [2:0]  sr_readback_fifo_rdcount;
reg          sr_readback_fifo_empty_at_start;
wire         sr_readback_fifo_load_from_fifo;
wire         sr_readback_fifo_empty;
wire         sr_readback_fifo_rd_en_real;

wire [7:0] interrupt_reg;

//---------------
// Assigments
//---------------
assign ChipConfig_Clock1 	 = ChipConfig[0];
assign ChipConfig_Clock2 	 = ChipConfig[1];
assign ChipConfig_Data 		 = ChipConfig[2];
assign ChipConfig_Load 		 = ChipConfig[3];
assign ChipConfig_Res_n      = ChipConfig[4];
assign ChipConfig_Readback   = ChipConfig[5];

assign ChipConfig_LdDAC      = ChipConfig_Lds[0];
assign ChipConfig_LdConfig   = ChipConfig_Lds[1];
assign ChipConfig_LdVDAC     = ChipConfig_Lds[2];
assign ChipConfig_LdTDAC     = ChipConfig_Lds[3];
assign ChipConfig_LdRow      = ChipConfig_Lds[4];
assign ChipConfig_LdColumn   = ChipConfig_Lds[5];
assign ChipConfig_WrRAM[3:0] = ChipConfig_RAMwr[3:0];
assign ChipConfig_no_sr      = ChipConfig_Lds[7];

assign reset_autoreset_analog  = reset_reg[0];
assign reset_reset_analog_b    = reset_reg[2];
assign reset_autoreset_digital = reset_reg[3];
assign reset_reset_digital_b   = reset_reg[5];
assign reset_autoreset_combine = reset_reg[7];
assign reset_wire = {reset_reg[7], reset_por_test_reset, reset_reg[5], reset_por,
                        reset_reg[3:2], reset_regulator_reset_out, reset_reg[0]};

assign config_mode_use_spi          = config_mode[0];
assign config_mode_bypass_cmd       = config_mode[1];
assign config_mode_encdr            = config_mode[2];
assign config_mode_en_pll           = config_mode[3];
assign config_mode_cmd_clock_invert = config_mode[4];
assign config_mode_interface_speed  = config_mode[5];
assign config_mode_take_fast        = config_mode[6];

assign patgen_Reset 		     = patgen_Reset_reg[0:0];
assign patgen_Suspend 		     = patgen_Suspend_reg[0:0];
assign patgen_writeStrobe 	     = patgen_writeStrobe_reg[0:0];
assign patgen_address 		     = patgen_address_reg[3:0];
assign patgen_data 			     = patgen_data_reg[7:0];
assign injection_gecco 		     = patgen_config[0];
assign injection_chip  		     = patgen_config[1];
assign patgen_synced		     = patgen_config[2];
assign patgen_tsoverflow_sync    = patgen_config[3];
assign patgen_skipsignals        = patgen_skipsignals_reg[7:0];

assign VoltageBoard_Clock = VoltageBoard[0:0];
assign VoltageBoard_Data  = VoltageBoard[1:1];
assign VoltageBoard_Load  = VoltageBoard[2:2];

assign spi_config_wr_fifo_reset = spi_config[0];
assign spi_config_rd_fifo_reset = spi_config[3];
assign spi_config_readback_en   = spi_config[6];
assign spi_config_reset         = spi_config[7];
assign spi_write_fifo_din = write_data;

assign spi_clock_divider = spi_clock_divider_reg;
assign spi_config_wire = {spi_config[7], spi_config[6],
                            spi_read_fifo_full, spi_read_fifo_empty, spi_config[3],
                            spi_write_fifo_full, spi_write_fifo_empty, spi_config[0]};
assign spi_write_fifo_wr_en = write & (address == 23);
assign spi_read_fifo_rd_en_real = spi_read_fifo_rd_en && address == 24 && spi_read_fifo_load_from_fifo;
assign spi_read_fifo_load_from_fifo = (!spi_read_fifo_empty_at_start && spi_read_fifo_rdcount != 0)
                                    || (!spi_read_fifo_empty && spi_read_fifo_rdcount == 0);

assign sr_readback_config_reset = sr_readback_config[7];
wire [7:0] sr_readback_config_wire = {sr_readback_config[7], sr_readback_config[6],
                            sr_readback_fifo_full, sr_readback_fifo_empty, sr_readback_config[3],
                            sr_readback_fifo_full, sr_readback_fifo_empty, sr_readback_config[0]};
assign sr_readback_config_rd_fifo_reset = sr_readback_config[0];
assign sr_readback_fifo_rd_en_real = sr_readback_fifo_rd_en && address == 60 && sr_readback_fifo_load_from_fifo;
assign sr_readback_fifo_load_from_fifo = (!sr_readback_fifo_empty_at_start && sr_readback_fifo_rdcount != 0)
                                    || (!sr_readback_fifo_empty && sr_readback_fifo_rdcount == 0);

assign interrupt_reg = {7'b0, hit_interrupt};

// Instances
//---------------

reg res_spi_write_fifo = 0;
spi_write_fifo spi_write_fifo_i(
    .rst(res_spi_write_fifo),
    .din(spi_write_fifo_din),
    .wr_en(spi_write_fifo_wr_en),
    .wr_clk(clk),
    .full(),
    .prog_full(spi_write_fifo_full),
    .dout(spi_write_fifo_dout),
    .rd_clk(spi_write_fifo_rd_clk),
    .rd_en(spi_write_fifo_rd_en),
    .empty(spi_write_fifo_empty)
);

reg res_spi_read_fifo = 0;
spi_read_fifo spi_read_fifo_i(
    .rst(res_spi_read_fifo),
    .din(spi_read_fifo_din),
    .wr_en(spi_read_fifo_wr_en),
    .wr_clk(spi_read_fifo_wr_clk),
    .full(spi_read_fifo_full),
    .dout(spi_read_fifo_dout),
    .rd_clk(clk),
    .rd_en(spi_read_fifo_rd_en_real),
    .empty(spi_read_fifo_empty)
);

reg res_sr_readback_fifo = 0;
sr_readback_fifo sr_readback_fifo_i(
    .rst(res_sr_readback_fifo),
    .din(sr_readback_fifo_din),
    .wr_en(sr_readback_fifo_wr_en),
    .wr_clk(sr_readback_fifo_wr_clk),
    .full(sr_readback_fifo_full),
    .dout(sr_readback_fifo_dout),
    .rd_clk(clk),
    .rd_en(sr_readback_fifo_rd_en_real),
    .empty(sr_readback_fifo_empty)
);

//FIFO reset synchronisation:
always @ (posedge clk) begin
    if((!res_n) | spi_config_wr_fifo_reset) begin
        res_spi_write_fifo <= 1;
    end
    else begin
        res_spi_write_fifo <= 0;
    end
    if((!res_n) | spi_config_rd_fifo_reset) begin
        res_spi_read_fifo <= 1;
    end
    else begin
        res_spi_read_fifo <= 0;
    end

    if(!res_n || sr_readback_config_rd_fifo_reset) begin
        res_sr_readback_fifo <= 1;
    end
    else begin
        res_sr_readback_fifo <= 0;
    end
end


//------------------------
// Reading Registers:
//------------------------
always @(posedge clk) begin
    if (~res_n) begin
        read_data                   <= 0;
        done                        <= 0;

        spi_read_fifo_rdcount        <= 0;
        spi_read_fifo_empty_at_start <= 0;

        sr_readback_fifo_rdcount <= 0;
        sr_readback_fifo_empty_at_start <= 0;
    end
    else begin
    if (read == 1) begin
        done <= 1;
        case(address)
            0:  read_data <= ChipConfig;
            2:  read_data <= patgen_Reset_reg;
            3:  read_data <= patgen_Suspend_reg;
            4:  read_data <= patgen_writeStrobe_reg;
			5:  read_data <= patgen_config;
            6:  read_data <= patgen_address_reg;
            7:  read_data <= patgen_data_reg;
            12: read_data <= VoltageBoard;
            16: read_data <= ChipConfig_Lds;
            17: read_data <= ChipConfig_RAMwr;
            18: read_data <= reset_wire;
            19: read_data <= config_mode;
            21: read_data <= spi_config_wire;
            22: read_data <= spi_clock_divider_reg;
            //23 writing FIFO, no read possible
            24: begin
                spi_read_fifo_rdcount <= spi_read_fifo_rdcount + 3'd1;

                //store empty state at beginning of the data set:
                if(spi_read_fifo_rdcount == 0)
                    spi_read_fifo_empty_at_start <= spi_read_fifo_empty;

                //load data if it was already present at beginning of the data set:
                if(spi_read_fifo_load_from_fifo)
                    read_data <= spi_read_fifo_dout;
                else
                    read_data <= 8'hff;
            end
            28: read_data <= patgen_skipsignals_reg;

            //51: fifo only for writing
            60: begin
                sr_readback_fifo_rdcount <= sr_readback_fifo_rdcount + 3'd1;

                //store empty state at beginning of the data set:
                if(sr_readback_fifo_rdcount == 0)
                    sr_readback_fifo_empty_at_start <= sr_readback_fifo_empty;

                //load data if it was already present at beginning of the data set:
                if(sr_readback_fifo_load_from_fifo)
                    read_data <= sr_readback_fifo_dout;
                else
                    read_data <= 8'hff;
            end
            61: read_data[7:0] <= sr_readback_config_wire;

            70: read_data[7:0] <= interrupt_reg;

            // Test Register
            80: read_data[7:0] <= 8'hAB;
        endcase
    end
    else begin
         done <= 0;
    end
end
end

//------------------------
// Writing Registers:
//------------------------
always @(posedge clk) begin
    if (~ res_n) begin
        ChipConfig          <= 0;
        ChipConfig_Lds      <= 8'b0000_0000;
        ChipConfig_RAMwr    <= 0;

        reset_reg           <= 8'b00100100; //the resets are active low
        config_mode         <= 0;

        patgen_Reset_reg        <= 1;
        patgen_Suspend_reg      <= 0;
        patgen_writeStrobe_reg  <= 0;
        patgen_address_reg      <= 0;
        patgen_data_reg         <= 0;
		patgen_config           <= 0;
		patgen_skipsignals_reg  <= 0;

        VoltageBoard <= 0;

        spi_config           <= 128;

        sr_readback_config   <= 0;
    end
    else begin
        if(write == 1) begin
            case(address)
                0:  ChipConfig                    <= write_data;
                2:  patgen_Reset_reg              <= write_data;
                3:  patgen_Suspend_reg            <= write_data;
                4:  patgen_writeStrobe_reg        <= write_data;
				5:  patgen_config				  <= write_data;
                6:  patgen_address_reg            <= write_data;
                7:  patgen_data_reg               <= write_data;
                12: VoltageBoard                  <= write_data;
                16: ChipConfig_Lds[7:0]           <= write_data[7:0];
                17: ChipConfig_RAMwr[7:0]         <= write_data[7:0];
                18: reset_reg[7:0]                <= write_data[7:0];
                19: config_mode[7:0]              <= write_data[7:0];
                21: spi_config                    <= write_data[7:0];
                22: spi_clock_divider_reg         <= write_data[7:0];
                //23 writing to FIFO, done using assignments
                //24: reading FIFO for SPI, no writing possible
                28: patgen_skipsignals_reg        <= write_data[7:0];
                //60: SR readback read-only
                61: sr_readback_config            <= write_data[7:0];
            endcase
        end
    end
end

endmodule
