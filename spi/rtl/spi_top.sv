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

    logic w_sclk, w_mosi, w_ss_n, w_miso;

    spi_slave U_SPI_SLAVE (
        .clk    (clk),
        .reset  (reset),
        .sclk   (w_sclk),
        .mosi   (w_mosi),
        .ss_n   (w_ss_n),
        .miso   (w_miso),
        .rx_data(),
        .rx_done(),
        .busy   ()
    );


    spi_master U_SPI_MASTER (
        .clk    (clk),
        .reset  (reset),
        .cpol   (cpol),
        .cpha   (cpha),
        .clk_div(clk_div),
        .tx_data(tx_data),
        .start  (start),
        .rx_data(),
        .done   (done),
        .busy   (),
        .sclk   (w_sclk),
        .mosi   (w_mosi),
        .miso   (w_miso),
        .ss_n   (w_ss_n)
    );

endmodule
