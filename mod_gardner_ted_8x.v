// =========================================================
// 🚀 16QAM Gardner TED (原汁原味的你的版本！)
// =========================================================
module mod_gardner_ted_8x (
    input wire clk,
    input wire reset_n,
    input wire signed [19:0] in_i, 
    input wire signed [19:0] in_q, 
    input wire strobe_2x,
    output reg signed [31:0] timing_error, 
    output reg error_valid       
);

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
        end else if (strobe_2x) begin 
            i_2 <= i_1; i_1 <= i_0; i_0 <= in_i;
            q_2 <= q_1; q_1 <= q_0; q_0 <= in_q;
            sk <= ~sk; 

            if (sk) begin 
                // 你的原版逻辑，一丝不改！
                i_sum = i_0 + i_2;
                q_sum = q_0 + q_2;
                
                i_mid_diff = i_1 - (i_sum >>> 1);
                q_mid_diff = q_1 - (q_sum >>> 1);

                if      ((!i_0[19]) && i_2[19]) i_err =  i_mid_diff;
                else if (i_0[19] && (!i_2[19])) i_err = -i_mid_diff;
                else                            i_err = 22'd0;

                if      ((!q_0[19]) && q_2[19]) q_err =  q_mid_diff;
                else if (q_0[19] && (!q_2[19])) q_err = -q_mid_diff;
                else                            q_err = 22'd0;

                // 恢复这神圣的 <<< 5
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