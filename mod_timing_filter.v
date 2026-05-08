// =========================================================
// 🧠 定时环路滤波器：双模自动变速箱版 (终极完美形态)
// =========================================================
module mod_timing_filter (
    input  wire clk,
    input  wire reset_n,
    input  wire signed [31:0] timing_error,   
    input  wire error_valid,                  
    output reg  signed [31:0] timing_loop_out 
);

    reg signed [47:0] timing_sum;
    reg [15:0] lock_cnt; // 🎯 引入换挡计时器

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            timing_sum <= 48'sd0;
            timing_loop_out <= 32'sd0;
            lock_cnt <= 16'd0;
        end else if (error_valid) begin
            
            // 计时器：跑到 30000 符号时切入稳态
            if (lock_cnt < 16'd35000)
                lock_cnt <= lock_cnt + 1'b1;

            // 🛡️ 抗极限溢出逻辑 
            if (timing_sum > 48'sd1000000000) 
                timing_sum <= 48'sd1000000000;
            else if (timing_sum < -48'sd1000000000) 
                timing_sum <= -48'sd1000000000;
            else begin
                // 🚦 积分路换挡：
                if (lock_cnt < 16'd35000)
                    timing_sum <= timing_sum - timing_error; // 一挡：原厂全速累加
                else
                    timing_sum <= timing_sum - (timing_error >>> 4); // 二挡：增加阻尼，冻结漂移
            end

            // 🚦 比例路换挡：输出决策
            if (lock_cnt < 16'd35000)
                // 一挡：12/4 原厂大马力，迅速找准眼图中心！
                timing_loop_out <= (timing_sum >>> 12) - (timing_error >>> 4);
            else
                // 二挡：12/8 重型避震器，无视 10dB Gardner 自噪声！
                timing_loop_out <= (timing_sum >>> 12) - (timing_error >>> 8);
                
        end
    end

endmodule