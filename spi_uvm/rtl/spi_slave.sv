`timescale 1ns / 1ps

module spi_slave (
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
    output logic       rx_done,
    output logic       busy
);

    typedef enum logic [1:0] {
        IDLE  = 0,
        START,
        DATA,
        STOP
    } spi_state_e;

    spi_state_e state;
    logic [7:0] tx_shift_reg, rx_shift_reg;
    logic sclk_past;
    logic rising_edge, falling_edge, any_edge;
    logic [3:0] bit_cnt;

    //edge detector
    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            sclk_past <= 0;
        end else begin
            sclk_past <= sclk;
        end
    end

    assign rising_edge  = (!sclk_past & sclk);
    assign falling_edge = (sclk_past & !sclk);
    assign any_edge     = (sclk_past ^ sclk);

    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            miso         <= 1'b1;  //z값
            rx_data      <= 0;
            rx_done      <= 0;
            busy         <= 1'b0;
            tx_shift_reg <= 0;  //miso로 보낼 거
            rx_shift_reg <= 0;  //mosi로 받을 거
            bit_cnt      <= 0;
            state        <= IDLE;
        end else begin
            rx_done <= 1'b0;  //rx_done 한 클락만 유지
            case (state)
                IDLE: begin
                    if (!ss_n) begin
                        tx_shift_reg <= tx_data;
                        busy         <= 1'b1;
                        bit_cnt      <= 0;
                        state        <= START;
                    end
                end

                START: begin
                    miso         <= tx_shift_reg[7];  //첫 비트 전송
                    tx_shift_reg <= {tx_shift_reg[6:0], 1'b0};
                    state        <= DATA;
                end

                DATA: begin
                    if (ss_n) begin
                        state <= STOP;
                    end else begin
                        if (rising_edge) begin
                            rx_shift_reg <= {rx_shift_reg[6:0], mosi};
                            if (bit_cnt == 7) begin
                                rx_data <= {rx_shift_reg[6:0], mosi};
                                bit_cnt <= 0;
                                state   <= STOP;
                            end else begin
                                bit_cnt <= bit_cnt + 1;
                            end
                        end
                        if (falling_edge) begin
                            miso <= tx_shift_reg[7];
                            tx_shift_reg <= {tx_shift_reg[6:0], 1'b0};
                        end
                    end
                end

                STOP: begin
                    rx_done <= 1'b1;
                    busy    <= 1'b0;
                    miso    <= 1'b1;
                    state   <= IDLE;
                end
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule
