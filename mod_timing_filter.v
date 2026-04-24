// =========================================================
// 🧠 定时环路滤波器：控制采样节奏的“指挥部”
// =========================================================
module mod_timing_filter (
    input  wire clk,
    input  wire reset_n,
    input  wire signed [31:0] timing_error,   // 来自 TED 的瞬时误差
    input  wire error_valid,                  // 误差有效标志
    output reg  signed [31:0] timing_loop_out // 输出给 NCO 的微调指令
);

    // 48 位的大底盘，防止积分溢出
    reg signed [47:0] timing_sum;

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            timing_sum <= 48'sd0;
            timing_loop_out <= 32'sd0;
        end else if (error_valid) begin
            // 1. 积分路径：把历史误差累加起来，对付频率微差
            timing_sum <= timing_sum - timing_error;

            // 2. PI 组合公式：[积分分支 >>> 16] + [比例分支 >>> 6]
            // 注意：移位数值越大，增益越小，环路越稳但不易捕捉；反之亦然。
            // 这里我们保持微调级别，防止定时“跑飞”。
            timing_loop_out <= (timing_sum >>> 12) - (timing_error >>> 4);
        end
    end

endmodule