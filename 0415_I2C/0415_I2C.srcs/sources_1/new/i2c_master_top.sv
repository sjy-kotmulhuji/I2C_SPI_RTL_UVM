`timescale 1ns / 1ps

module i2c_master_top (


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
    output logic       busy,
    output logic       scl,
    inout  wire        sda

);



endmodule
