`timescale 1ns / 1ps


module spi_top (
    input logic clk,
    input logic reset,

    // 🌟 [추가] 보드 스위치 입력 (마스터로 보낼 데이터)
    input logic [7:0] sw_data,

    // SPI 물리 핀
    input  logic sclk,
    input  logic mosi,
    input  logic ss_n,
    output logic miso,  // 🌟 마스터로 데이터가 나가는 핀

    // FND 출력 핀
    output logic [3:0] fnd_digit,
    output logic [7:0] fnd_data
);

    logic [7:0] w_rx_data;
    logic       w_rx_done;

    logic [7:0] display_data_reg;

    // 1. SPI Slave 인스턴스
    spi_slave U_SPI_SLAVE (
        .clk(clk),
        .reset(reset),
        .sclk(sclk),
        .mosi(mosi),
        .ss(ss_n),
        .tx_data(sw_data),      // 🌟 보드의 스위치 값을 송신 데이터로 연결!
        .miso(miso),  // 🌟 Top 모듈의 외부 핀으로 출력 연결!
        .rx_data(w_rx_data),
        .rx_done(w_rx_done),
        .busy()
    );

    // 2. FND 디스플레이용 데이터 래치 (기존 작성하신 훌륭한 로직 유지)
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            display_data_reg <= 8'd0;
        end else if (w_rx_done) begin
            display_data_reg <= w_rx_data;
        end
    end

    // 3. FND 컨트롤러 인스턴스
    fnd_controller U_FND_CTRL (
        .clk(clk),
        .reset(reset),
        .fnd_in_data(display_data_reg),
        .fnd_digit(fnd_digit),
        .fnd_data(fnd_data)
    );

endmodule

module spi_slave (
    input logic clk,
    input logic reset,
    input logic sclk,
    input logic mosi,
    input logic ss,
    input logic [7:0] tx_data,   // 🌟 [추가] 마스터에게 보낼 데이터 입력
    output logic miso,
    output logic [7:0] rx_data,
    output logic rx_done,
    output logic busy
);

    logic sclk_sync1, sclk_sync2, sclk_sync_d;
    logic sclk_rising_edge;
    logic sclk_falling_edge;     // 🌟 [추가] MISO로 데이터를 쏠 타이밍

    logic
        ss_sync1, ss_sync2, ss_sync_d;  // 🌟 [추가] SS 신호 동기화용
    logic ss_falling_edge;  // 🌟 [추가] 통신 시작 순간 감지용

    logic [7:0] rx_shift_reg;
    logic [7:0] tx_shift_reg;    // 🌟 [추가] 마스터로 보낼 데이터를 담을 레지스터
    logic [2:0] bit_cnt;

    // edge detector (작성하신 동기화 로직을 그대로 활용하여 falling edge도 추가)
    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            {sclk_sync2, sclk_sync1} <= 0;
            sclk_sync_d <= 0;

            {ss_sync2, ss_sync1} <= 2'b11; // 🌟 SS는 평소에 1(High)이므로 1로 초기화
            ss_sync_d <= 1;
        end else begin
            {sclk_sync2, sclk_sync1} <= {sclk_sync1, sclk};
            sclk_sync_d <= sclk_sync2;

            {ss_sync2, ss_sync1} <= {ss_sync1, ss};  // 🌟 SS 동기화
            ss_sync_d <= ss_sync2;
        end
    end

    // 작성하신 상승 엣지 검출
    assign sclk_rising_edge = sclk_sync2 & ~sclk_sync_d;
    // 🌟 [추가] 하강 엣지 검출 (0 -> 1이 아니라 1 -> 0으로 떨어질 때)
    assign sclk_falling_edge = ~sclk_sync2 & sclk_sync_d;
    assign ss_falling_edge = ~ss_sync2 & ss_sync_d;

    // 🌟 [추가] MISO 선 연결: SS가 0(활성화)일 때만 레지스터의 MSB를 내보냄, 아니면 선을 끊음(High-Z)
    assign miso = (!ss) ? tx_shift_reg[7] : 1'bz;

    // mode 0
    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            bit_cnt <= 0;
            rx_shift_reg <= 0;
            tx_shift_reg <= 0;  // 🌟 [추가] 
            rx_data <= 0;
            rx_done <= 0;
            busy <= 0;
        end else begin
            rx_done <= 0;

            // 🌟 [추가] SS가 1에서 0으로 떨어지는 순간, 마스터로 보낼 데이터를 장전!
            if (ss_falling_edge) begin
                tx_shift_reg <= tx_data;
            end

            if (!ss) begin
                busy <= 1;

                // [수신] 작성하신 원래 로직 (SCLK 상승 엣지에서 MOSI 읽기)
                if (sclk_rising_edge) begin
                    rx_shift_reg <= {rx_shift_reg[6:0], mosi};

                    if (bit_cnt == 7) begin
                        rx_data <= {rx_shift_reg[6:0], mosi};
                        bit_cnt <= 0;
                        rx_done <= 1;
                    end else begin
                        bit_cnt <= bit_cnt + 1;
                    end
                end 
                // 🌟 [송신 추가] SCLK 하강 엣지에서 MISO로 다음 비트를 밀어내기
                else if (sclk_falling_edge) begin
                    tx_shift_reg <= {tx_shift_reg[6:0], 1'b0};
                end

            end else begin
                bit_cnt <= 0;
                busy <= 0;
            end
        end
    end

endmodule
