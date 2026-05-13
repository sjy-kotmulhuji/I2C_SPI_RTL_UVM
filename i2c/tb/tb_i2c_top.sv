`timescale 1ns / 1ps

module tb_i2c_top ();

    logic       clk;
    logic       reset;
    logic       cmd_start;
    logic       cmd_write;
    logic       cmd_read;
    logic       cmd_stop;
    logic [7:0] tx_data;
    logic       ack_in;
    logic [7:0] rx_data;
    logic       done;
    logic       ack_out;
    logic       busy;

    localparam SLA = 7'h25;

    i2c_top dut (
        .clk      (clk),
        .reset    (reset),
        .cmd_start(cmd_start),
        .cmd_write(cmd_write),
        .cmd_read (cmd_read),
        .cmd_stop (cmd_stop),
        .tx_data  (tx_data),
        .ack_in   (ack_in),
        .rx_data  (rx_data),
        .done     (done),
        .ack_out  (ack_out),
        .busy     (busy)
    );

    always #5 clk = ~clk;

    task i2c_start();
        cmd_start = 1'b1;
        cmd_write = 1'b0;
        cmd_read  = 1'b0;
        cmd_stop  = 1'b0;
        @(posedge clk);
        wait (done);
        @(posedge clk);
    endtask

    task i2c_addr(bit wr);
        //tx_data = address(8'h12) + read(1)/write(0) 신호
        tx_data = (SLA << 1) + wr;  //8bit 주소 한 자리 shift 하고 LSB에 r/w 신호 넣어줌
        cmd_start = 1'b0;
        cmd_write = 1'b1;
        cmd_read = 1'b0;
        cmd_stop = 1'b0;
        @(posedge clk);
        wait (done);
        @(posedge clk);
    endtask

    task i2c_write(byte data);
        //tx_data = data data 전송받고 ack까지 받음
        tx_data   = data;
        cmd_start = 1'b0;
        cmd_write = 1'b1;
        cmd_read  = 1'b0;
        cmd_stop  = 1'b0;
        @(posedge clk);
        wait (done);  //ack까지 받은 후 done 신호 뜸
        @(posedge clk);
    endtask

    task i2c_read();
        cmd_start = 1'b0;
        cmd_write = 1'b0;
        cmd_read  = 1'b1;
        cmd_stop  = 1'b0;
        @(posedge clk);
        wait (done);
        @(posedge clk);
    endtask

    task i2c_stop();
        //stop
        cmd_start = 1'b0;
        cmd_write = 1'b0;
        cmd_read  = 1'b0;
        cmd_stop  = 1'b1;
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

        i2c_start();
        i2c_addr(0);
        i2c_write(8'h55);

        //i2c_start();
        //i2c_addr(SLA << 1 + 1'b0);
        i2c_write(8'haa);

        //i2c_start();
        //i2c_addr(SLA << 1 + 1'b0);
        i2c_write(8'h01);
        i2c_stop();

        i2c_start();
        i2c_addr(1);
        i2c_read();
        i2c_stop();

        #100;
        $finish;
    end

endmodule
