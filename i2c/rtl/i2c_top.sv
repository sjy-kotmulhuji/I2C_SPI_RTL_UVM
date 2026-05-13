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

    i2c_master U_I2C_MASTER (
        .*,
        .scl(scl),
        .sda(sda)
    );

    i2c_slave U_I2C_SLAVE (
        .tx_data(8'h05),
        .rx_data(),
        .scl(scl),
        .sda(sda),
        .done()
    );

endmodule
