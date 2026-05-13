`timescale 1ns / 1ps

module spi_top (
    input  logic       clk,
    input  logic       reset,
    //Master Input
    input  logic       cpol,
    input  logic       cpha,
    input  logic [7:0] clk_div,
    input  logic [7:0] tx_data,
    input  logic       start,
    //Master Output
    output logic [7:0] rx_data,
    output logic       done
);

    logic w_sclk, w_mosi, w_miso, w_ss_n;

    spi_master U_SPI_MASTER(
        .*,
    .busy(),
    .sclk(w_sclk),
    .mosi(w_mosi),
    .miso(w_miso),
    .ss_n(w_ss_n)
);

    spi_slave U_SPI_SLAVE(
        .*,
    .sclk(w_sclk),
    .mosi(w_mosi),
    .miso(w_miso),
    .ss_n(w_ss_n),
    .tx_data(),
    .rx_data(),
    .rx_done(),
    .busy()
);


endmodule
