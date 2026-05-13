`timescale 1ns / 1ps

module spi_master_fnd (
    input  logic       clk,
    input  logic       reset,
    input  logic [7:0] tx_data,
    input  logic       start,
    output logic       sclk,
    output logic       mosi,
    input  logic       miso,
    output logic       ss_n,
    output logic [3:0] fnd_digit,
    output logic [7:0] fnd_data
);

    logic [7:0] w_rx_data;
    logic       w_rx_done;
    logic       w_start;
    logic [7:0] display_data_reg;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            display_data_reg <= 8'd0;
        end else if (w_rx_done) begin
            display_data_reg <= w_rx_data;
        end
    end

    spi_master U_SPI_MASTER (
        .*,
        .busy   (),
        .cpol   (0),
        .cpha   (0),
        .clk_div(4),
        .start  (w_start),
        .rx_data(w_rx_data),
        .done   (w_rx_done)
    );

    fnd_controller U_FND_CTRL (
        .clk        (clk),
        .reset      (reset),
        .fnd_in_data(display_data_reg),
        .fnd_digit  (fnd_digit),
        .fnd_data   (fnd_data)
    );

    btn_debounce(
        .clk(clk), .reset(reset), .i_btn(start), .o_btn(w_start)
    );

endmodule
