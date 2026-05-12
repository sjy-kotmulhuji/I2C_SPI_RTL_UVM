`timescale 1ns / 1ps

module tb_spi_top ();

    logic       clk;
    logic       reset;
    logic       cpol;
    logic       cpha;
    logic [7:0] clk_div;
    logic [7:0] tx_data;
    logic       start;
    logic [7:0] rx_data;
    logic       done;

    always #5 clk = ~clk;

    spi_top dut (
        .clk    (clk),
        .reset  (reset),
        .cpol   (cpol),
        .cpha   (cpha),
        .clk_div(clk_div),
        .tx_data(tx_data),
        .start  (start),
        .rx_data(rx_data),
        .done   (done)
    );


    task spi_set_mode(logic [1:0] mode);
        {cpol, cpha} = mode;
        @(posedge clk);
    endtask

    task spi_send_data(logic [7:0] data);
        tx_data = data;
        start   = 1'b1;
        @(posedge clk);
        start = 1'b0;
        @(posedge clk);
        wait (done);
        @(posedge clk);
    endtask


    initial begin
        clk   = 0;
        reset = 1;
        repeat (3) @(posedge clk);
        reset = 0;
        @(posedge clk);
        clk_div = 5;  //SCLK = 10Mhz
        //miso = 1'b0;
        @(posedge clk);

        spi_set_mode(0);
        spi_send_data(8'h55);
        spi_set_mode(0);
        spi_send_data(8'haa);
        spi_set_mode(0);
        spi_send_data(8'h55);
        spi_set_mode(0);
        spi_send_data(8'haa);

        #20;
        $finish;
    end


endmodule
