/*
    astropix-fw main_top.v
    Nicolas Striebig, 2023
 */

`timescale 1ns / 1ps


module main_top(

    //Nexys
    input        cpu_resetn,
    input        sysclk,
    input [7:0]  sw,
    input        btnc, btnr, btnl, btnd, btnu,
    output [7:0] led,

    //voltage adjustment
    output [1:0] set_vadj, //Set FMC Voltage to 1.8V
    output       vadj_en,

    //FTDI
    inout  [7:0] prog_d,
    input        prog_clko, prog_rxen, prog_txen,
    output       prog_rdn, prog_wrn, prog_siwun, prog_oen,

    //OLED
    output       oled_sdin, oled_sclk, oled_dc, oled_res, oled_vbat, oled_vdd,

    //Astropix

    //Asic config SR
    input        config_sout,
    output       config_sin_p, config_sin_n,
    output       config_ck1_p, config_ck1_n,
    output       config_ck2_p, config_ck2_n,
    output       config_ld_p, config_ld_n,
    output       config_rb,
    output       config_ldtdac,

    //SPI left:
    output       spi_left_clk, spi_left_csn, spi_left_mosi,
    input        spi_left_miso0, spi_left_miso1,

    //SPI right:
    input        spi_right_clk, spi_right_csn, spi_right_mosi,
    output       spi_right_miso0, spi_right_miso1,

    //Astropix Digital Pins
    input interrupt,
    output res_n,
    output hold,

    //Chip Config debug output
    output debug_spi_csn, debug_spi_sck, debug_spi_mosi, debug_spi_miso0, debug_spi_miso1,

    //Astropix Sample Clk
    `ifdef TELESCOPE
    output [0:3] sample_clk_n, sample_clk_p,
    `else
    output sample_clk_n, sample_clk_p,
    `endif

    output sample_clk_se_n, sample_clk_se_p,

    output timestamp_clk,

    //GECCO

    //VB Config debug output:
    output vb_clock_test, vb_data_test, vb_load_test,

    //Injection:
    output       gecco_inj_chopper_p, gecco_inj_chopper_n,
    `ifndef TELESCOPE
    //mistake on current telescope pcb
    output       chip_inj_chopper,
    `endif
    //Voltage Boards:
    output       vb_clock_p, vb_clock_n, vb_data_p, vb_data_n, vb_load_p, vb_load_n

);

wire clk;
IBUFG clk_ibuf_inst(
    .I(sysclk),
    .O(clk)
);

//voltage selection on FMC:
assign vadj_en      = 1;
assign set_vadj[1]  = 0;
assign set_vadj[0]  = 1;

assign prog_siwun = 1;   //important for reading from FPGA


//Astropix2
assign hold = 1'b0;

// FTDI Communication / Order Sorter:
wire        ordersorter_header0;
wire        ordersorter_read;
wire [7:0]  ordersorter_address;
wire [7:0]  ordersorter_data;

// Pattern Generator:
wire        patgen_Reset;
wire        patgen_Suspend;
wire        patgen_writeStrobe;
wire [7:0]  patgen_address;
wire [7:0]  patgen_data;
wire        injection_gecco;
wire        injection_chip;
wire        patgen_synced;
wire        patgen_tsoverflow_sync;
wire [7:0]  patgen_skipsignals;

// configuration:
wire config_sin;
wire config_ck1;
wire config_ck2;
wire config_ld;
wire config_res_n;

wire cmd;
wire vb_clock;
wire vb_data;
wire vb_load;

// SPI:
wire        spi_config_reset;
wire [7:0]  spi_clock_divider;
wire [31:0] spi_write_fifo_dout;
wire        spi_write_fifo_rd_clk;
wire        spi_write_fifo_rd_en;
wire        spi_write_fifo_empty;

wire [63:0] spi_read_fifo_din;
wire        spi_read_fifo_wr_clk;
wire        spi_read_fifo_wr_en;
wire        spi_read_fifo_full;
wire        spi_config_readback_en;

wire [63:0] sr_readback_fifo_din;

wire fast_clk, fast_clk_sampleclk, clk_out_20M;
// Clocks
`ifdef ASTROPIX4
    assign sample_clk_se = 1'b0;
    assign fast_clk_sampleclk = clk_out_20M;
`elsif CLOCK_SE_DIFF
    assign sample_clk_se = fast_clk;
    assign fast_clk_sampleclk = 1'b0;
`else
    assign fast_clk_sampleclk = fast_clk;
    assign sample_clk_se = 1'b0;
    `ifdef CLOCK_SE_SE
        assign sample_clk_se_n = 1'bz;
    `endif
`endif

// FTDI Configuration:
ftdi_top ftdi_top_I(
    .clk(clk),
    .res_n(cpu_resetn),
    .prog_clko(prog_clko),
    .FTDI_TXE_N(prog_txen),
    .FTDI_RXF_N(prog_rxen),
    .FTDI_RD_N(prog_rdn),
    .FTDI_OE_N(prog_oen),
    .FTDI_WR_N(prog_wrn),
    .FTDI_DATA(prog_d),

    .ChipConfig_Clock1(config_ck1),
    .ChipConfig_Clock2(config_ck2),
    .ChipConfig_Data(config_sin),
    .ChipConfig_Load(config_ld),
    .ChipConfig_Res_n(config_res_n),
    .ChipConfig_Readback(config_rb),
    .ChipConfig_LoadTDAC(config_ldtdac),

    .patgen_Reset(patgen_Reset),
    .patgen_Suspend(patgen_Suspend),
    .patgen_writeStrobe(patgen_writeStrobe),
    .patgen_address(patgen_address[7:0]),
    .patgen_data(patgen_data[7:0]),
    .patgen_synced(patgen_synced),
    .injection_gecco(injection_gecco),
    .injection_chip(injection_chip),
    .patgen_tsoverflow_sync(patgen_tsoverflow_sync),
    .patgen_skipsignals(patgen_skipsignals),

    .VoltageBoard_Clock(vb_clock),  // vbclk_wire
    .VoltageBoard_Data(vb_data),    // vboard_sin
    .VoltageBoard_Load(vb_load),    // vbld_wire

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
    .spi_config_readback_en(spi_config_readback_en),

    .sr_readback_config_reset(sr_readback_config_reset),
    .sr_readback_fifo_din(sr_readback_fifo_din),
    .sr_readback_fifo_wr_clk(sr_readback_fifo_wr_clk),
    .sr_readback_fifo_wr_en(sr_readback_fifo_wr_en),
    .sr_readback_fifo_full(sr_readback_fifo_full),

    .ordersorter_data(ordersorter_data[7:0]),

    .hit_interrupt(interrupt)
);

wire clockwiz_locked;

clk_wiz_0 I_clk_wiz_0(
    .clk_in1(clk),
    .reset(1'b0),
    .locked(clockwiz_locked),
    .clk_out_sampleclk(fast_clk),
    .clk_out_timestamp(timestamp_int_clk),
    .clk_out_20M(clk_out_20M)
);

reg timestamp_clk_div2;

assign timestamp_clk = timestamp_clk_div2;

/* always @(posedge timestamp_int_clk, negedge cpu_resetn) begin
    if(!cpu_resetn) timestamp_clk_div2 <= 0;
    else timestamp_clk_div2 <= ~timestamp_clk_div2;
end */

reg [1:0] counter;

always @(posedge timestamp_int_clk) begin
    if(!cpu_resetn) begin
        counter <= 2'b0;
        timestamp_clk_div2 <= 1'b0;
    end
    else if (counter == 2'b11) begin
        timestamp_clk_div2 <= ~timestamp_clk_div2; // Divided clock output
        counter <= 2'b00;
    end
    else
        counter <= counter + 1;
end


// Pattern Generator
wire gecco_inj_chopper;
wire inj_chopper_pat;
assign gecco_inj_chopper = injection_gecco & inj_chopper_pat;
assign chip_inj_chopper = injection_chip & inj_chopper_pat;


sync_async_patgen patgen(
    .clk(clk),
    .rst(patgen_Reset),
    .suspend(patgen_Suspend),
    .write(patgen_writeStrobe),
    .addr(patgen_address[3:0]),
    .din(patgen_data),
    .synced(patgen_synced),
    .syncrst(injtrigger),
    .out(inj_chopper_pat),
    .running(),
    .done()
);

assign spi_right_miso0 = 1'b0;
assign spi_right_miso1 = 1'b0;

spi_readout spi_readout_i(
    .clock(clk),
    .reset(~cpu_resetn | spi_config_reset),
    .clock_divider(spi_clock_divider),

    .spi_csb(spi_left_csn),
    .spi_clock(spi_left_clk),
    .spi_mosi(spi_left_mosi),
    .spi_miso0(spi_left_miso0),
    .spi_miso1(spi_left_miso1),

    .interruptB(interrupt), //change name to interruptB

    .readback_en(spi_config_readback_en),
    .data_in_fifo_data(spi_write_fifo_dout),
    .data_in_fifo_clock(spi_write_fifo_rd_clk),
    .data_in_fifo_rd_en(spi_write_fifo_rd_en),
    .data_in_fifo_empty(spi_write_fifo_empty),

    .data_out_fifo_data(spi_read_fifo_din),
    .data_out_fifo_clock(spi_read_fifo_wr_clk),
    .data_out_fifo_wr_en(spi_read_fifo_wr_en),
    .data_out_fifo_full(spi_read_fifo_full)
);

sr_readback u_sr_readback (
    .clock                  (clk),
    .reset                  (!cpu_resetn || sr_readback_config_reset),
    .sr_ck1                 (config_ck1),
    .sr_ck2                 (config_ck2),
    .sr_ld                  (config_ld),
    .sr_sout                (config_sout),
    .data_out_fifo_data     (sr_readback_fifo_din),
    .data_out_fifo_full     (sr_readback_fifo_full),
    .data_out_fifo_clock    (sr_readback_fifo_wr_clk),
    .data_out_fifo_wr_en    (sr_readback_fifo_wr_en),
    .data_ready(data_ready)
);

oled oled_I (
    .clk(clk),
    .rstn(cpu_resetn),
    .btnC(btnc),
    .btnD(btnd),
    .btnU(btnu),
    .oled_sdin(oled_sdin),
    .oled_sclk(oled_sclk),
    .oled_dc(oled_dc),
    .oled_res(oled_res),
    .oled_vbat(oled_vbat),
    .oled_vdd(oled_vdd),
    .led()
);

// Buffers:
`ifdef TELESCOPE
    localparam DIFF_DRIVERS = 8;
    //vb_clock and vb_load are connected inverted to the receivers on GECCO board
    wire [7:0] obuf_p;
    wire [7:0] obuf_n;
    wire [7:0] obuf_i = {gecco_inj_chopper, ~vb_clock, vb_data, ~vb_load, {4{fast_clk_sampleclk}}};
    assign {gecco_inj_chopper_p, vb_clock_p, vb_data_p, vb_load_p, sample_clk_p[0:3]} = obuf_p;
    assign {gecco_inj_chopper_n, vb_clock_n, vb_data_n, vb_load_n, sample_clk_n[0:3]} = obuf_n;
`else
    localparam DIFF_DRIVERS = 5;
    wire [4:0] obuf_p;
    wire [4:0] obuf_n;
    wire [4:0] obuf_i = {gecco_inj_chopper, ~vb_clock, vb_data, ~vb_load, fast_clk_sampleclk};
    assign {gecco_inj_chopper_p, vb_clock_p, vb_data_p, vb_load_p, sample_clk_p} = obuf_p;
    assign {gecco_inj_chopper_n, vb_clock_n, vb_data_n, vb_load_n, sample_clk_n} = obuf_n;
`endif

genvar i;
generate
    for (i = 0; i < DIFF_DRIVERS; i = i + 1) begin
        OBUFDS #(
            .IOSTANDARD("LVDS_25")
        ) OBUFDS_I (
            .I(obuf_i[i]),
            .O(obuf_p[i]),
            .OB(obuf_n[i])
        );
    end
endgenerate

`ifdef CLOCK_SE_SE
    OBUF #(
        .IOSTANDARD("LVCMOS25")
    ) OBUF_clock_se (
        .I(sample_clk_se),
        .O(sample_clk_se_p)
    );

`else
    OBUFDS #(
            .IOSTANDARD("LVDS_25")
        ) OBUFDS_clock_diff (
            .I(sample_clk_se),
            .O(sample_clk_se_p),
            .OB(sample_clk_se_n)
        );
`endif

//Clock


wire [3:0] obuf2_p;
wire [3:0] obuf2_n;
wire [3:0] obuf2_i = {config_sin, config_ck1, config_ck2, config_ld};
assign {config_sin_p, config_ck1_p, config_ck2_p, config_ld_p} = obuf2_p;
assign {config_sin_n, config_ck1_n, config_ck2_n, config_ld_n} = obuf2_n;

//Asicconfig Buffers
`ifdef CONFIG_SE
    generate
        for (i = 0; i < 4; i = i + 1) begin
            OBUF #(
                .IOSTANDARD("LVCMOS25")
            ) OBUF_config_se (
                .I(obuf2_i[i]),
                .O(obuf2_p[i])
            );
        end
    endgenerate
`else
    generate
        for (i = 0; i < 4; i = i + 1) begin
            OBUFDS #(
                .IOSTANDARD("LVDS_25")
            ) OBUFDS_config_diff (
                .I(obuf2_i[i]),
                .O(obuf2_p[i]),
                .OB(obuf2_n[i])
            );
        end
    endgenerate
`endif

//DEBUG OUTPUTS
//SPI PMOD JB Debug output
assign debug_spi_csn = spi_right_csn;
assign debug_spi_sck = spi_left_clk;
assign debug_spi_mosi = spi_left_mosi;
assign debug_spi_miso0 = spi_left_miso0;
assign debug_spi_miso1 = spi_left_miso1;

//Chip VB JB Debug output
assign vb_clock_test = vb_clock;
assign vb_data_test = vb_data;
assign vb_load_test = vb_load;

//DEBUG: res_n low if Center-Button is pressed
assign res_n = ~config_res_n && ~btnc;

//LED contents:
assign led[0] = res_n; //Reset_n
assign led[1] = spi_config_reset; //SPI Reset
assign led[2] = spi_write_fifo_empty; //SPI WR FIFO EMPTY
assign led[3] = spi_read_fifo_full; //SPI READ FIFO EMPTY
assign led[4] = spi_config_readback_en; //SPI READ-ONLY MODE;
assign led[5] = interrupt;
assign led[6] = hold;
assign led[7] = data_ready;

endmodule
