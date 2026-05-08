`timescale 1ns / 1ps

module fnd_top (
    input logic clk,
    input logic reset,
    input logic [7:0] rx_data,
    input logic rx_done,
    output logic 
);

    fnd_controller FND_CNTL (
        .clk      (),
        .reset    (),
        .i_data   (),
        .i_digit  (),
        .fnd_digit(),
        .fnd_data ()
    );

endmodule


module fnd_controller (
    input        clk,
    input        reset,
    input  [7:0] i_data,
    input  [1:0] i_digit,
    output [3:0] fnd_digit,
    output [7:0] fnd_data
);
    wire [3:0] w_digit_1, w_digit_10, w_digit_100, w_digit_1000, w_mux_4x1_out;
    wire [1:0] w_digit_sel;
    wire       w_1khz;


    decoder_2x4 U_DEC_2x4 (
        .digit_sel(w_digit_sel),
        .dec_out  (fnd_digit)
    );

    counter_4 U_COUNTER_4 (
        .clk      (w_1khz),
        .reset    (reset),
        .digit_sel(w_digit_sel)
    );

    clk_div U_CLK_DIV (
        .clk   (clk),
        .reset (reset),
        .o_1khz(w_1khz)
    );

    bcd U_BCD (
        .bcd     (w_mux_4x1_out),
        .fnd_data(fnd_data)
    );

    mux_4X1 U_Mux_4x1 (
        .digit_1   (w_digit_1),
        .digit_10  (w_digit_10),
        .digit_100 (w_digit_100),
        .digit_1000(w_digit_1000),
        .sel       (w_digit_sel),
        .mux_out   (w_mux_4x1_out)
    );

    digit_splitter U_DIGIT_SPL (
        .in_data   (sum),
        .digit_1   (w_digit_1),
        .digit_10  (w_digit_10),
        .digit_100 (w_digit_100),
        .digit_1000(w_digit_1000)
    );

endmodule

module clk_div (        //fnd 동작은 눈으로 확인할 수 있도록 클락 속도 조정
    input      clk,
    input      reset,
    output reg o_1khz
);

    reg [16:0] counter_r;  //[$clog2(100000):0] 이렇게도 가능 

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            counter_r <= 0;  //초기화 안 하면 X(Uninitialized)
            o_1khz    <= 1'b0;
        end else begin
            if (counter_r == 99_999) begin  //17bit라 10만 이후로도 카운트 가능하기 때문에 0으로 떨궈줌
                counter_r <= 0;
                o_1khz    <= 1'b1;
            end else begin
                counter_r <= counter_r + 1;
                o_1khz    <= 1'b0;
            end
        end
    end

endmodule

module counter_4 (
    input        clk,
    input        reset,
    output [1:0] digit_sel
);

    reg [1:0] counter_r;

    assign digit_sel = counter_r;

    always@(posedge clk, posedge reset) begin   //동일 프로젝트 내에선 상승 엣지, 하강 엣지 하나로 통일
        if (reset) begin
            counter_r <= 0;
        end else begin
            counter_r <= counter_r + 1; //3 이상이 돼도 overflow로 발생한 carry가 그냥 사라지므로 0~3 반복
        end
    end

endmodule


module mux_4X1 (
    input [3:0] digit_1,
    input [3:0] digit_10,
    input [3:0] digit_100,
    input [3:0] digit_1000,
    input [1:0] sel,

    output reg [3:0] mux_out
);

    always @(*) begin
        case (sel)
            2'b00: mux_out = digit_1;
            2'b01: mux_out = digit_10;
            2'b10: mux_out = digit_100;
            2'b11: mux_out = digit_1000;
        endcase

    end

endmodule

module decoder_2x4 (
    input [1:0] digit_sel,
    output reg [3:0] dec_out
);
    always @(*) begin
        case (digit_sel)
            2'b00: dec_out = 4'b1110;
            2'b01: dec_out = 4'b1101;
            2'b10: dec_out = 4'b1011;
            2'b11: dec_out = 4'b0111;
        endcase
    end

endmodule

module digit_splitter (
    input  [7:0] in_data,
    output [3:0] digit_1,
    output [3:0] digit_10,
    output [3:0] digit_100,
    output [3:0] digit_1000
);

    assign digit_1 = in_data % 10;
    assign digit_10 = (in_data / 10) % 10;
    assign digit_100 = (in_data / 100) % 10;
    assign digit_1000 = (in_data / 1000) % 10;

endmodule

module bcd (
    input [3:0] bcd,
    output reg [7:0] fnd_data
);
    always @(bcd) begin         //assign 쓰면 코드 너무 길어져서 case문 쓰기 위해 always문 사용
        case (bcd)
            4'd0:    fnd_data = 8'hc0;
            4'd1:    fnd_data = 8'hf9;
            4'd2:    fnd_data = 8'ha4;
            4'd3:    fnd_data = 8'hb0;
            4'd4:    fnd_data = 8'h99;
            4'd5:    fnd_data = 8'h92;
            4'd6:    fnd_data = 8'h82;
            4'd7:    fnd_data = 8'hf8;
            4'd8:    fnd_data = 8'h80;
            4'd9:    fnd_data = 8'h90;
            default: fnd_data = 8'hFF;  //bcd가 다른 값일 때
        endcase
    end
endmodule
