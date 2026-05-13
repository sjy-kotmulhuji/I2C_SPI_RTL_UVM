`timescale 1ns / 1ps

module spi_slave_fnd (
    input  logic       clk,
    input  logic       reset,
    //SPI port
    input  logic       sclk,
    input  logic       mosi,
    input  logic       ss_n,
    output logic       miso,
    //To FND
    input  logic [7:0] tx_data,
    output logic [7:0] rx_data,
    output logic [3:0] fnd_digit,
    output logic [7:0] fnd_data
);

    logic [7:0] w_rx_data;
    logic       w_rx_done;

    logic [7:0] display_data_reg;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            display_data_reg <= 8'd0;
        end else if (w_rx_done) begin
            display_data_reg <= w_rx_data;
        end
    end

    spi_slave U_SPI_SLAVE (
        .*,
        .rx_data(w_rx_data),
        .rx_done(w_rx_done)
    );

    fnd_controller U_FND_CNTL (
        .clk        (clk),
        .reset      (reset),
        .fnd_in_data(display_data_reg),
        .fnd_digit  (fnd_digit),
        .fnd_data   (fnd_data)
    );
endmodule
