`timescale 1ns / 1ps



module spi_master (
    input logic clk,
    input logic reset,
    input logic cpol,  //idle 0: low, 1: high
    input logic cpha,  // first sampling, 0: first edge, 1: second edge
    input logic [7:0] clk_div,
    input logic [7:0] tx_data,
    input logic start,
    output logic [7:0] rx_data,
    output logic done,
    output logic busy,
    output logic sclk,
    output logic mosi,
    input logic miso,
    output logic ss_n,
    output logic [3:0] fnd_digit,
    output logic [7:0] fnd_data
);

    logic [7:0] w_rx_data;
    logic       w_rx_done;

    logic [7:0] display_data_reg;

    assign w_rx_done = done;
    assign w_rx_data = rx_data;


    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            display_data_reg <= 8'd0;
        end else if (w_rx_done) begin
            display_data_reg <= w_rx_data;
        end
    end

    // 3. FND 컨트롤러 인스턴스
    fnd_controller U_FND_CTRL (
        .clk        (clk),
        .reset      (reset),
        .fnd_in_data(display_data_reg),
        .fnd_digit  (fnd_digit),
        .fnd_data   (fnd_data)
    );

    typedef enum logic [1:0] {
        IDLE  = 2'b00,
        START,
        DATA,
        STOP
    } spi_state_e;

    spi_state_e state;
    logic [7:0] div_cnt;
    logic half_tick;
    logic [7:0] tx_shift_reg, rx_shift_reg;
    logic [2:0] bit_cnt;
    logic step, sclk_r;

    assign sclk = sclk_r;

    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            div_cnt   <= 0;
            half_tick <= 1'b0;
        end else begin
            if (state == DATA) begin
                if (div_cnt == clk_div) begin
                    div_cnt   <= 0;
                    half_tick <= 1'b1;
                end else begin
                    div_cnt   <= div_cnt + 1;
                    half_tick <= 1'b0;
                end
            end
        end
    end

    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            state        <= IDLE;
            mosi         <= 1'b1;
            ss_n         <= 1'b1;
            busy         <= 1'b0;
            done         <= 1'b0;
            tx_shift_reg <= 0;
            rx_shift_reg <= 0;
            bit_cnt      <= 0;
            step         <= 1'b0;
            rx_data      <= 0;
            sclk_r       <= cpol;
        end else begin
            done <= 1'b0;
            case (state)
                IDLE: begin
                    mosi   <= 1'b1;
                    ss_n   <= 1'b1;
                    sclk_r <= cpol;
                    if (start) begin
                        tx_shift_reg <= tx_data;
                        bit_cnt      <= 0;
                        step         <= 1'b0;
                        busy         <= 1'b1;
                        ss_n         <= 1'b0;
                        state        <= START;
                    end
                end

                START: begin
                    if (!cpha) begin
                        mosi <= tx_shift_reg[7];
                        tx_shift_reg <= {tx_shift_reg[6:0], 1'b0};
                    end
                    state <= DATA;
                end

                DATA: begin
                    if (half_tick) begin
                        sclk_r <= ~sclk_r;
                        if (step == 0) begin  //수신 구간
                            step <= 1'b1;
                            if (!cpha) begin
                                rx_shift_reg <= {rx_shift_reg[6:0], miso};
                            end else begin
                                mosi <= tx_shift_reg[7];
                                tx_shift_reg <= {tx_shift_reg[6:0], 1'b0};
                            end
                        end else begin  //송신 구간
                            step <= 1'b0;
                            if (!cpha) begin
                                if (bit_cnt < 7) begin
                                    mosi <= tx_shift_reg[7];
                                    tx_shift_reg <= {tx_shift_reg[6:0], 1'b0};
                                end
                            end else begin
                                rx_shift_reg <= {rx_shift_reg[6:0], miso};
                            end
                            if (bit_cnt == 7) begin
                                state <= STOP;
                                if (!cpha) begin
                                    rx_data <= rx_shift_reg;
                                end else begin
                                    //rx_data <= rx_shift_reg;
                                    rx_data <= {rx_shift_reg[6:0], miso};
                                end
                            end else begin
                                bit_cnt <= bit_cnt + 1;
                            end
                        end
                    end
                end

                STOP: begin
                    sclk_r <= 1'b0;
                    ss_n   <= 1'b1;
                    done   <= 1'b1;
                    busy   <= 1'b0;
                    mosi   <= 1'b1;
                    state  <= IDLE;
                end
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule


module master_top (
    input logic clk,
    input logic reset,

    // 보드의 스위치 및 버튼 입력
    input logic [7:0] sw_data,   // 보낼 데이터 (스위치 8개)
    input logic       btn_send,  // 전송 시작 버튼
    input logic       miso,

    // 외부로 나가는 SPI 핀 (Pmod 점퍼선 연결용)
    output logic sclk,
    output logic mosi,
    output logic ss_n,

    output logic [3:0] fnd_digit,
    output logic [7:0] fnd_data
);

    // 1. 버튼 엣지 디텍터 (One-shot Pulse 생성)
    logic btn_sync1, btn_sync2, btn_d;
    logic start_pulse;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            {btn_sync2, btn_sync1} <= 2'b00;
            btn_d <= 1'b0;
        end else begin
            {btn_sync2, btn_sync1} <= {
                btn_sync1, btn_send
            };  // 메타스테빌리티 방지용 2단 동기화
            btn_d <= btn_sync2;  // 이전 상태 저장
        end
    end

    // 버튼을 누르는 순간 딱 1클럭만 High가 되는 start 펄스
    assign start_pulse = btn_sync2 & ~btn_d;


    // 2. SPI 마스터 IP 인스턴스화
    spi_master U_SPI_MASTER (
        .clk  (clk),
        .reset(reset),

        // 슬레이브 보드 설정과 동일하게 Mode 0 (CPOL=0, CPHA=0) 고정
        .cpol(1'b0),
        .cpha(1'b0),

        // SCLK 속도 조절 (예: 시스템 클럭 100MHz일 때 49를 넣으면 SCLK는 약 1MHz)
        // (100MHz / (2 * (49 + 1))) = 1MHz
        .clk_div(8'd49),

        .tx_data(sw_data),  // 스위치 값을 전송 데이터로 연결
        .start(start_pulse),  // 엣지 디텍터를 통과한 딱 1클럭짜리 펄스 연결

        .rx_data(), // 슬레이브에서 받는 데이터가 없으므로 비워둠
        .done(),    // 필요시 LED에 연결해서 전송 완료 확인용으로 써도 됨
        .busy(),

        // 외부 핀으로 출력
        .sclk(sclk),
        .mosi(mosi),
        .miso(miso), // 마스터가 받는 핀은 쓰지 않으므로 0으로 고정
        .ss_n(ss_n),

        .fnd_digit(fnd_digit),
        .fnd_data (fnd_data)
    );

endmodule
