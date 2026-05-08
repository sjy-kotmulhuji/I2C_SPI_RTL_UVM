`timescale 1ns / 1ps

module i2c_top (
    input  logic       clk,
    input  logic       reset,
    input  logic       cmd_start,
    input  logic       cmd_write,
    input  logic       cmd_read,
    input  logic       cmd_stop,
    input  logic [7:0] tx_data,
    input  logic       ack_in,
    output logic [7:0] rx_data,
    output logic       done,
    output logic       ack_out,
    output logic       busy
);

    logic scl;
    wire  sda;



    I2C_Master U_I2C_M (
        .clk  (clk),
        .reset(reset),

        .cmd_start(cmd_start),
        .cmd_write(cmd_write),
        .cmd_read (cmd_read),
        .cmd_stop (cmd_stop),
        .tx_data  (tx_data),

        .ack_in(ack_in),

        .rx_data(),
        .done   (done),

        .ack_out(ack_out),
        .busy(busy),

        .scl(scl),
        .sda(sda)
    );


    I2C_Slave U_I2C_S (

        .clk    (clk),
        .reset  (reset),
        .tx_data(8'h05),
        .rx_data(),
        .scl    (scl),
        .sda    (sda)
    );

    //I2C_slave_2 U_I2C_S (
    //
    //    .clk    (clk),
    //    .reset  (reset),
    //    .tx_data(8'h05),
    //    .rx_data(),
    //    .done   (),
    //    .scl    (scl),
    //    .sda    (sda)
    //);


endmodule
