`timescale 1ns / 1ps

module spi_top (
    input  logic       clk,
    input  logic       reset,
    //Master Input
    input  logic       cpol,
    input  logic       cpha,
    input  logic [7:0] clk_div,
    input  logic [7:0] m_tx_data,
    input  logic [7:0] s_tx_data,
    input  logic       start,
    //Master Output
    output logic [7:0] m_rx_data,
    output logic [7:0] s_rx_data,
    output logic       m_rx_done,
    output logic       s_rx_done
);

    logic w_sclk, w_mosi, w_ss_n, w_miso;

    spi_slave U_SPI_SLAVE (
        .clk    (clk),
        .reset  (reset),
        .sclk   (w_sclk),
        .mosi   (w_mosi),
        .ss_n   (w_ss_n),
        .miso   (w_miso),
        .tx_data(s_tx_data),
        .rx_data(s_rx_data),
        .rx_done(s_rx_done),
        .busy   ()
    );


    spi_master U_SPI_MASTER (
        .clk    (clk),
        .reset  (reset),
        .cpol   (cpol),
        .cpha   (cpha),
        .clk_div(clk_div),
        .tx_data(m_tx_data),
        .start  (start),
        .rx_data(m_rx_data),
        .done   (m_rx_done),
        .busy   (),
        .sclk   (w_sclk),
        .mosi   (w_mosi),
        .miso   (w_miso),
        .ss_n   (w_ss_n)
    );

endmodule
