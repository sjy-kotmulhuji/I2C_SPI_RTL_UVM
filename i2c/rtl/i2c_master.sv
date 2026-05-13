`timescale 1ns / 1ps

module i2c_master (
    input logic clk,
    input logic reset,

    //command port
    input  logic       cmd_start,
    input  logic       cmd_write,
    input  logic       cmd_read,
    input  logic       cmd_stop,
    input  logic [7:0] tx_data,
    //ack신호(0) 줄지 nack신호(1) 줄지 host에서 받아옴
    input  logic       ack_in,
    //internal output
    output logic [7:0] rx_data,
    output logic       done,
    //slave -> master로 보낸 ACK/NACK 신호를 host에서 판단함
    output logic       ack_out,
    output logic       busy,
    //external I2C port
    output logic       scl,
    inout  wire        sda
);

    //SDA port 연결
    logic sda_o, sda_i;

    assign sda_i = (sda === 1'bz) ? 1'b1 : sda;
    assign sda   = sda_o ? 1'bz : 1'b0;

    typedef enum logic [2:0] {
        IDLE = 3'b000,
        START,
        WAIT_CMD,
        DATA,
        DATA_ACK,
        STOP
    } i2c_state_e;

    i2c_state_e       state;
    logic       [7:0] div_cnt;  //0~249
    logic             qtr_tick;
    logic scl_r, sda_r;
    logic [1:0] step;
    logic [2:0] bit_cnt;
    logic [7:0] tx_shift_reg, rx_shift_reg;
    logic is_read, ack_in_r;


    //assign ack_in_r = ack_in;
    assign scl   = scl_r;
    assign sda_o = sda_r;
    assign busy  = (state != IDLE);  //IDLE에서만 busy 0

    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            div_cnt  <= 0;
            qtr_tick <= 0;
        end else begin
            if (div_cnt == 249) begin  //scl : 100Khz
                div_cnt  <= 0;
                qtr_tick <= 1'b1;  //quarter tick
            end else begin
                div_cnt  <= div_cnt + 1;
                qtr_tick <= 1'b0;
            end
        end
    end

    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            state        <= IDLE;
            scl_r        <= 1'b1;
            sda_r        <= 1'b1;
            //busy         <= 1'b0; //초기화는 해야 하는 거 아냐,?
            step         <= 0;
            done         <= 1'b0;
            tx_shift_reg <= 0;
            rx_shift_reg <= 0;
            is_read      <= 0;
            bit_cnt      <= 0;  //default
            ack_in_r     <= 1'b1;  //nack 상태로 초기화(이유없음)
        end else begin
            done <= 1'b0;
            case (state)
                IDLE: begin
                    scl_r <= 1'b1;
                    sda_r <= 1'b1;
                    //busy  <= 1'b0;
                    if (cmd_start) begin
                        state <= START;
                        step  <= 0;
                        //busy  <= 1'b1;
                    end
                end
                START: begin
                    if (qtr_tick) begin
                        case (step)
                            2'd0: begin
                                sda_r <= 1'b1;
                                scl_r <= 1'b1;
                                step  <= 2'd1;
                            end
                            2'd1: begin
                                sda_r <= 1'b0;
                                step  <= 2'd2;
                            end
                            2'd2: begin
                                step <= 2'd3;
                            end
                            2'd3: begin
                                scl_r <= 1'b0;
                                step <= 2'd0;
                                done  <= 1'b1;  //demo에서 done 값 받아 다음 상태 실행
                                state <= WAIT_CMD;
                            end
                        endcase
                    end
                end
                WAIT_CMD: begin
                    step <= 0;
                    if (cmd_write) begin
                        tx_shift_reg <= tx_data;
                        bit_cnt <= 0;  //최상위 bit부터 출력하므로?
                        is_read <= 1'b0;  //write
                        state <= DATA;
                    end else if (cmd_read) begin
                        rx_shift_reg <= 0;
                        bit_cnt      <= 0;
                        is_read      <= 1'b1;  //read
                        state        <= DATA;
                    end else if (cmd_stop) begin
                        state <= STOP;
                    end else if (cmd_start) begin
                        state <= START;
                    end
                end
                DATA: begin
                    if (qtr_tick) begin
                        case (step)
                            2'd0: begin
                                scl_r <= 1'b0;
                                //read일 때 1 출력해서 z 상태로 만듦.
                                sda_r <= is_read ? 1'b1 : tx_shift_reg[7];   //read이면 1, write이면 전송
                                //전송값으로 step 0~3 유지(0이면 0, 1이면 1)
                                step <= 2'd1;
                            end
                            2'd1: begin
                                scl_r <= 1'b1;
                                step  <= 2'd2;
                            end
                            2'd2: begin
                                scl_r <= 1'b1;
                                if(is_read) begin   //read 동작 시 step 3에서 sampling
                                    rx_shift_reg <= {rx_shift_reg[6:0], sda_i};
                                end
                                step <= 2'd3;
                            end
                            2'd3: begin
                                scl_r <= 1'b0;
                                if (!is_read) begin
                                    tx_shift_reg <= {
                                        tx_shift_reg[6:0], 1'b0
                                    };  //write일 때 shift
                                end
                                step <= 2'd0;
                                if (bit_cnt == 7) begin
                                    ack_in_r <= 1'b0;
                                    state <= DATA_ACK;
                                end else begin
                                    bit_cnt <= bit_cnt + 1;
                                end
                            end
                        endcase
                    end
                end
                DATA_ACK: begin
                    if (qtr_tick) begin
                        case (step)
                            2'd0: begin
                                scl_r <= 1'b0;
                                if (is_read) begin
                                    sda_r <= ack_in_r;  //read일 때 host로부터 받은 ack 값 출력
                                end else begin
                                    sda_r <= 1'b1;  //write인 경우 slave에서 ack 신호 받아야 하므로 끊어줌
                                end
                                step <= 2'd1;
                            end
                            2'd1: begin
                                scl_r <= 1'b1;
                                step  <= 2'd2;
                            end
                            2'd2: begin
                                scl_r <= 1'b1;
                                if (!is_read) begin  //write일 때
                                    ack_out <= sda_i;   //slave로부터 ack 신호 수신
                                end else begin   //read일 때 ack: 1byte 데이터 다 받았다는 의미이므로 rx_data 출력
                                    rx_data <= rx_shift_reg;
                                end
                                step <= 2'd3;
                            end
                            2'd3: begin
                                scl_r <= 1'b0;
                                done  <= 1'b1;
                                step  <= 2'd0;
                                state <= WAIT_CMD;
                            end
                        endcase
                    end
                end
                STOP: begin
                    if (qtr_tick) begin
                        case (step)
                            2'd0: begin
                                sda_r <= 1'b0;
                                scl_r <= 1'b0;
                                step  <= 2'd1;
                            end
                            2'd1: begin
                                scl_r <= 1'b1;
                                step  <= 2'd2;
                            end
                            2'd2: begin
                                sda_r <= 1'b1;
                                step  <= 2'd3;
                            end
                            2'd3: begin
                                step  <= 2'd0;
                                done  <= 1'b1;
                                state <= IDLE;
                            end
                        endcase
                    end
                end
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end


endmodule
