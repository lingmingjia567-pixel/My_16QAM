// =========================================================
// 🚀 载波环路滤波器：双模自适应版 (快捕获 + 稳态抗噪)
// =========================================================
module mod_loop_filter (
    input wire clk,
    input wire reset_n,
    input wire signed [19:0] phase_error,
    input wire error_valid,
    output wire signed [31:0] freq_control_word
);

    reg signed [47:0] sum;
    reg signed [31:0] loopout;
    
    // 自动换挡计时器 (同步你的 Polar/DD 切换点)
    reg [15:0] lock_cnt;
    
    wire signed [47:0] pd_ext = {{28{phase_error[19]}}, phase_error};

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            sum <= 48'sd0;
            loopout <= 32'sd0;
            lock_cnt <= 16'd0;
        end else if (error_valid) begin
            
            // 计时器：当计数到 35000 时，系统认为已经进入稳态
            if (lock_cnt < 16'd35000)
                lock_cnt <= lock_cnt + 1'b1;
                
            // 🛡️ 积分路 (抗饱和逻辑)
            if (sum > 48'sd1000000000)
                sum <= 48'sd1000000000;
            else if (sum < -48'sd1000000000)
                sum <= -48'sd1000000000;
            else begin
                // 🚦 积分路换挡：
                if (lock_cnt < 16'd35000)
                    sum <= sum + (pd_ext >>> 5);  // 一挡：高增益，暴力拉平频偏
                else
                    sum <= sum + (pd_ext >>> 11); // 二挡：极低增益，无视噪声毛刺
            end
                
            // 🚦 比例路换挡：
            if (lock_cnt < 16'd35000)
                loopout <= sum + (pd_ext <<< 3);  // 一挡：强阻尼，防止失步
            else
                loopout <= sum + (pd_ext >>> 3);  // 二挡：微增益，稳定相位
            
        end
    end

    assign freq_control_word = loopout;

endmodule