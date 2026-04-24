// =========================================================
// 🧠 载波环路滤波器 (Loop Filter) - 绝对时间延时唤醒版 🚀
// 功能：平滑鉴相器误差，产生 NCO 频率微调指令
// 特点：48位宽积分器，带“两阶段绝对时间捕获”防死锁机制
// =========================================================
module mod_loop_filter (
    input wire clk,
    input wire reset_n,
    input wire signed [19:0] phase_error,
    input wire error_valid,
    output wire signed [31:0] freq_control_word
);

    // 依然保留 48 位的核动力底盘
    reg signed [47:0] sum;
    reg signed [31:0] loopout;

    // ⏱️ 核心修改 1：升级为 32 位计数器，防止 65535 溢出卡死！
    reg [31:0] wait_cnt;
    
    // 采用顺序捕获策略：等待 Gardner 定时同步锁定后，再开启 DD-PLL 载波同步。
    // 避免因初始采样点偏差（眼图未张开）导致判决器输出错误极性，从而引发两环路交叉耦合死锁。
    // ⏱️ 核心修改 2：18000 个符号 * 8个时钟/符号 = 144000 个绝对系统时钟
    parameter WAKEUP_TIME = 32'd144000;

    // 符号扩展：将 20 位误差扩展到 48 位，保持正负号不变
    wire signed [47:0] error_ext = {{28{phase_error[19]}}, phase_error};
    
    // =======================================================
    // 🌟 核心开关 1：极性翻转开关
    // =======================================================
	 wire signed [47:0] error_fixed = -error_ext;

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            sum <= 48'sd0;
            loopout <= 32'sd0;
            wait_cnt <= 32'd0;
        end else begin 
            // 🚀 核心修改 3：把倒计时拿到最外层！只要有 clk 时钟，就绝对往下数！
            
            if (wait_cnt < WAKEUP_TIME) begin
                // 🛑 第一阶段：休眠期（等够 144000 个时钟，约 18000 个符号）
                wait_cnt <= wait_cnt + 1'b1;
                sum <= 48'sd0;     // 积分器强行清零
                loopout <= 32'sd0; // 输出 0，让载波 NCO 保持原速运转
            end else if (error_valid) begin
                // 🟢 第二阶段：全面唤醒！
                // 只有等绝对时间结束了，且当前正好有一个有效误差脉冲时，才进行闭环计算
                
                // 1. 积分器（I分支）：持续累加误差，消除稳态偏差
                sum <= sum + error_fixed;
                
                // 2. 比例与积分相加输出 (移位控制增益)
               loopout <= ($signed(sum) >>> 20) + ($signed(error_fixed) >>> 14);
            end
            
        end
    end

    // 🔴 最终缝合：恢复闭环输出！
    assign freq_control_word = loopout;

endmodule