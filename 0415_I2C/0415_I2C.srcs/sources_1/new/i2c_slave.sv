`timescale 1ns / 1ps

module I2C_Slave (

    input  logic       clk,
    input  logic       reset,
    //internal output
    input        [7:0] tx_data,
    output logic [7:0] rx_data,  //constranint 바꾸기
    //external I2C port
    input  logic       scl,
    inout  wire        sda
);

    logic sda_o, sda_i;

    //assign sda_i = (sda === 1'bz) ? 1'b1 : sda;
    assign sda_i = sda;
    //assign sda   = sda_o;
    assign sda   = sda_o ? 1'bz : 1'b0;

    i2c_slave U_I2C_SLAVE (
        .*,
        .done (),
        .sda_o(sda_o),
        .sda_i(sda_i)
    );

endmodule


module i2c_slave (
    input  logic       clk,
    input  logic       reset,
    //internal output
    input  logic [7:0] tx_data,  //장치에서 입력받아 master로 넘김
    output logic [7:0] rx_data,
    output logic       done,
    //external I2C port
    input  logic       scl,
    input  logic       sda_i,
    output logic       sda_o
);

    parameter MY_ADDR = 7'h25;  //7'b0100101

    typedef enum logic [2:0] {
        IDLE = 3'b000,
        ADDR_RW,
        ADDR_ACK,
        DATA,
        DATA_ACK

    } i2c_slave_state_e;

    i2c_slave_state_e state;
    logic [7:0] tx_shift_reg, rx_shift_reg;
    logic sda_p2, sda_p1, scl_p2, scl_p1;
    logic sda_rising_edge, sda_falling_edge, scl_rising_edge, scl_falling_edge;
    logic m_start, m_stop;
    logic [2:0] bit_cnt;
    logic is_read;
    logic sda_r;
    logic ack_in, ack_out;

    assign sda_o = sda_r;

    //SCL edge detector
    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            scl_p2 <= 0;
            scl_p1 <= 0;
        end else begin
        scl_p1 <= scl;
        scl_p2 <= scl_p1;
        end
    end

    assign scl_rising_edge  = (!scl_p2 & scl_p1);
    assign scl_falling_edge = (scl_p2 & !scl_p1);

    //SDA edge detector
    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            sda_p2 <= 0;
            sda_p1 <= 0;
        end else begin
        sda_p1 <= sda_i;
        sda_p2 <= sda_p1;
        end
    end

    assign sda_rising_edge = (~sda_p2 & sda_p1);
    assign sda_falling_edge = (sda_p2 & ~sda_p1);

    //Master 동작 감지
    assign m_start = (scl_p1 & sda_falling_edge);
    assign m_stop = (scl_p1 & sda_rising_edge);


    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            state        <= IDLE;
            sda_r        <= 1'b1;  //sda 기본값 z
            done         <= 1'b0;
            tx_shift_reg <= 0;
            rx_shift_reg <= 0;
            is_read      <= 0;
            bit_cnt      <= 0;
            ack_out      <= 1'b1;
        end else begin
            done <= 1'b0;  //done 한 클락만 유지
            //언제든 Master의 STOP 동작이 감지되면 IDLE 상태로 돌아가는 로직
            if (m_stop) begin
                state <= IDLE;
            end
            case (state)
                IDLE: begin
                    sda_r   <= 1'b1;
                    bit_cnt <= 0;
                    is_read <= 0;
                    if (m_start) begin
                        state <= ADDR_RW;
                    end
                end
                ADDR_RW: begin
                    if (scl_rising_edge) begin  //SCL 하강 엣지에서 Write
                        rx_shift_reg <= {rx_shift_reg[6:0], sda_i};
                        if (bit_cnt == 7) begin //마지막 8번째 bit 수신하고 넘어감
                            bit_cnt <= 0;
                            state   <= ADDR_ACK;
                        end else begin
                            bit_cnt <= bit_cnt + 1;
                        end
                    end
                end
                ADDR_ACK: begin
                    if (scl_falling_edge) begin
                        if (rx_shift_reg[7:1] == MY_ADDR) begin
                                sda_r   <= 1'b0;
                            if(!rx_shift_reg[0]) begin  //read 동작일 때(rw = 0)
                                is_read <= 1;
                                //rx_shift_reg <= 8'h00;
                            end else begin  //write 동작(rw = 1)
                                tx_shift_reg <= tx_data;    //전송 데이터 채워놓기 임의의 8bit  
                                is_read <= 0;
                            end
                        end else begin  //addr이 맞지 않을 때 동작 종료
                            sda_r <= 1'b1;
                            state <= IDLE;
                        end
                    end
                    if (scl_rising_edge) begin
                        if (rx_shift_reg[7:1] == MY_ADDR) state <= DATA;

                    end
                end

                DATA: begin
                    if (is_read) begin  //read
                        if (scl_falling_edge) begin
                            sda_r <= 1'b1;
                        end else if (scl_rising_edge) begin
                            rx_shift_reg <= {rx_shift_reg[6:0], sda_i};
                            if (bit_cnt == 7) begin
                                bit_cnt <= 0;
                                ack_out <= 1'b0;    //8bit 데이터 다 받은 시점에 ack 변경

                                state <= DATA_ACK;
                            end else begin
                                bit_cnt <= bit_cnt + 1;
                            end
                        end

                    end else begin  //write
                        if(scl_falling_edge) begin   //상승 엣지에서 전송, shift
                            sda_r        <= tx_shift_reg[7];
                            tx_shift_reg <= {tx_shift_reg[6:0], 1'b0};
                            if (bit_cnt == 7) begin
                                bit_cnt <= 0;
                                state   <= DATA_ACK;
                            end else begin
                                bit_cnt <= bit_cnt + 1;
                            end
                        end
                    end

                    //else begin
                    //    bit_cnt <= bit_cnt + 1;
                    //end
                end
                DATA_ACK: begin
                    if (scl_falling_edge) begin
                        if (is_read) begin
                            sda_r <= ack_out;  // s -> m ack 송신
                        end else begin
                            sda_r <= 1'b1;  //m -> s ack
                        end
                    end
                    if (scl_rising_edge) begin
                        if (is_read) begin  //read
                            //sda_r <= 1'b1;
                            done    <= 1'b1;
                            rx_data <= rx_shift_reg;
                            state   <= DATA;
                        end else begin  //write
                            if (!sda_i) begin  //ACK 신호 받았을 때
                                tx_shift_reg <= tx_data;
                                bit_cnt <= 0;
                                done <= 1'b1;
                                state <= DATA;  //다음 데이터도 달라는 뜻이므로
                            end else begin  //NACK 신호 받았을 때
                                sda_r <= 1'b1;
                                state <= IDLE;   //이제 데이터 그만 주라는 뜻이므로
                            end
                        end
                    end
                end
                default: state <= IDLE;
            endcase
        end
    end



endmodule
