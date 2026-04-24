// =========================================================
// 🚀 16QAM Gardner TED (真·闭环驱动改良版)
// =========================================================
module mod_gardner_ted_8x (
    input wire clk,              // 10MHz 系统时钟
    input wire reset_n,
    input wire signed [19:0] in_i, 
    input wire signed [19:0] in_q, 
    input wire strobe_2x,        // 🔴 致命修复：必须接入 NCO 的 2.5MHz 脉冲！
    
    output reg signed [31:0] timing_error, 
    output reg error_valid       
);

    // 只需要存 3 个点：当前(Late), 中间(Mid), 过去(Early)
    reg signed [19:0] i_0, i_1, i_2;
    reg signed [19:0] q_0, q_1, q_2;
    reg sk;

    reg signed [20:0] i_sum, q_sum;
    reg signed [20:0] i_mid_diff, q_mid_diff;
    reg signed [21:0] i_err, q_err;

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            i_0 <= 0; i_1 <= 0; i_2 <= 0;
            q_0 <= 0; q_1 <= 0; q_2 <= 0;
            sk <= 0;
            timing_error <= 0;
            error_valid <= 0;
        end else if (strobe_2x) begin // 🟢 灵魂回归：只有听见 NCO 快门响，才抓取波形！
            
            // 移位更新历史数据
            i_2 <= i_1; i_1 <= i_0; i_0 <= in_i;
            q_2 <= q_1; q_1 <= q_0; q_0 <= in_q;
            sk <= ~sk; // 内部二分频产生符号巅峰时刻

            if (sk) begin // 此时 i_0 是 Late, i_1 是 Mid, i_2 是 Early
                // 🎯 1. 计算均值对消 (16QAM 改良公式)
                i_sum = i_0 + i_2;
                q_sum = q_0 + q_2;
                
                i_mid_diff = i_1 - (i_sum >>> 1);
                q_mid_diff = q_1 - (q_sum >>> 1);

                // 🎯 2. 符号位跳变检测 (极性判断)
                if      ((!i_0[19]) && i_2[19]) i_err =  i_mid_diff;
                else if (i_0[19] && (!i_2[19])) i_err = -i_mid_diff;
                else                            i_err = 22'd0;

                if      ((!q_0[19]) && q_2[19]) q_err =  q_mid_diff;
                else if (q_0[19] && (!q_2[19])) q_err = -q_mid_diff;
                else                            q_err = 22'd0;

                // 🎯 3. 放大输出 (维持环路增益)
                timing_error <= (i_err + q_err) <<< 5;
                error_valid <= 1'b1;
            end else begin
                error_valid <= 1'b0;
            end
        end else begin
            error_valid <= 1'b0;
        end
    end
endmodule