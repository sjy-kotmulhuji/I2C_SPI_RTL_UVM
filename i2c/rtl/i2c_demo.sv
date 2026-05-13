`timescale 1ns / 1ps

module i2c_demo (
    input  logic       clk,
    input  logic       reset,
    input  logic       btn_start,
    input  logic       sw_wr,      //write or read mode select switch
    input  logic [7:0] sw_data,
    output logic [7:0] led_data,
    output logic       scl,
    inout  wire        sda
);

    typedef enum logic [2:0] {
        IDLE  = 0,
        START,
        ADDR,
        WRITE,
        READ,
        STOP
    } i2c_state_e;

    localparam SLA = {7'h25};
    i2c_state_e       state;

    logic             cmd_start;
    logic             cmd_write;
    logic             cmd_read;
    logic             cmd_stop;
    logic       [7:0] tx_data;
    logic             ack_in;
    logic       [7:0] rx_data;
    logic             done;
    logic             ack_out;
    logic             busy;

    i2c_master U_I2C_MASTER (
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
        .busy     (busy),
        .scl      (scl),
        .sda      (sda)
    );

    //start button edge detector
    logic btn_prev1, btn_prev2;

    always_ff @( posedge clk ) begin 
        if(reset) begin
            btn_prev1 <= 0;
            btn_prev2 <= 0;
        end else begin
            btn_prev1 <= btn_start;
            btn_prev2 <= btn_prev1;
        end
    end

    assign start_push = ~btn_prev2 & btn_prev1;

    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            state     <= IDLE;
            cmd_start <= 1'b0;
            cmd_write <= 1'b0;
            cmd_read  <= 1'b0;
            cmd_stop  <= 1'b0;
            tx_data   <= 0;
        end else begin
            case (state)
                IDLE: begin
                    cmd_start <= 1'b0;
                    cmd_write <= 1'b0;
                    cmd_read  <= 1'b0;
                    cmd_stop  <= 1'b0;
                    if (start_push) begin
                        state <= START;
                    end
                end
                START: begin
                    cmd_start <= 1'b1;
                    cmd_write <= 1'b0;
                    cmd_read  <= 1'b0;
                    cmd_stop  <= 1'b0;
                    if (done) begin
                        state <= ADDR;
                    end
                end
                ADDR: begin
                    cmd_start <= 1'b0;
                    cmd_write <= 1'b1;
                    cmd_read  <= 1'b0;
                    cmd_stop  <= 1'b0;
                    if (!sw_wr) tx_data <= {SLA, 1'b0};  //write
                    else tx_data <= {SLA, 1'b1};  //read

                    if (done) begin
                        if (ack_out) begin  //NACK
                            state <= STOP;
                        end else begin
                            if (!sw_wr) state <= WRITE;
                            else state <= READ;
                        end
                    end
                end
                WRITE: begin
                    cmd_start <= 1'b0;
                    cmd_write <= 1'b1;
                    cmd_read  <= 1'b0;
                    cmd_stop  <= 1'b0;
                    tx_data   <= sw_data[7:0];
                    if (done) begin
                        if (!ack_out) state <= STOP;
                        else state <= STOP;
                    end
                end
                READ: begin
                    cmd_start <= 1'b0;
                    cmd_write <= 1'b0;
                    cmd_read  <= 1'b1;
                    cmd_stop  <= 1'b0;
                    ack_in    <= 1'b1;
                    if (done) begin
                        led_data  <= rx_data;
                        if (!ack_out) state <= STOP;
                        else state <= STOP;
                    end
                end
                STOP: begin
                    cmd_start <= 1'b0;
                    cmd_write <= 1'b0;
                    cmd_read  <= 1'b0;
                    cmd_stop  <= 1'b1;
                    if (done) begin
                        state <= IDLE;
                    end
                end
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end


endmodule
