// =========================================================
// 🚀 解调端模4格雷差分解码 + 全同步并串转换 (终极修复版)
// =========================================================
module demod_p2s(
    input wire clk,             
    input wire reset_n,
    input wire symbol_strobe,   
    input wire [3:0] signal,    
    output wire serial          
);

    wire Ik = signal[3]; 
    wire Qk = signal[2]; 
    
    reg Ik_prev, Qk_prev;
    reg Ak_out, Bk_out;

    always @(*) begin
        if      (Ik == Ik_prev  && Qk == Qk_prev)  begin Ak_out = 1'b0; Bk_out = 1'b0; end
        else if (Ik == Qk_prev  && Qk == ~Ik_prev) begin Ak_out = 1'b0; Bk_out = 1'b1; end
        else if (Ik == ~Qk_prev && Qk == Ik_prev)  begin Ak_out = 1'b1; Bk_out = 1'b0; end
        else if (Ik == ~Ik_prev && Qk == ~Qk_prev) begin Ak_out = 1'b1; Bk_out = 1'b1; end
        else                                       begin Ak_out = 1'b0; Bk_out = 1'b0; end
    end

    reg [3:0] buffer;
    reg [2:0] div_cnt; // 🔴 核心修复：换成 3 位计数器 (0~7)
    reg serial_out_reg;

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            buffer <= 4'd0;
            serial_out_reg <= 1'b0;
            div_cnt <= 3'd0;
            Ik_prev <= 1'b0;
            Qk_prev <= 1'b0;
        end else if (symbol_strobe) begin
            Ik_prev <= Ik;
            Qk_prev <= Qk;
            // 🎯 脉冲到来：立刻打出第 1 颗子弹 (Ak_out)
            // 把剩下的 3 颗子弹装入弹夹准备移位
            buffer <= {Bk_out, signal[1], signal[0], 1'b0};
            serial_out_reg <= Ak_out; 
            div_cnt <= 3'd0;
        end else begin
            div_cnt <= div_cnt + 3'd1;
            // 🎯 核心时间轴修复：在第 1, 3, 5 个高频周期触发移位扣扳机
            // 完美保证在第 2, 4, 6 个周期输出新比特，每个比特精确存活 200ns！
            if (div_cnt == 3'd1 || div_cnt == 3'd3 || div_cnt == 3'd5) begin 
                serial_out_reg <= buffer[3];
                buffer <= {buffer[2:0], 1'b0};
            end
        end
    end

    assign serial = serial_out_reg;

endmodule