// =========================================================
// 🚀 接收端总成：纯净 10MHz 链路 (全模块化定时同步版)
// =========================================================
module demod_16QAM(carrier_clk, orgin_clk, reset_n, signal, demod_out);
input carrier_clk, reset_n, orgin_clk;
input signed [15:0] signal; 
output demod_out;

// --- 内部连线资源 ---
wire [3:0] p_data;
wire signed [7:0] mul_i, mul_q;
wire signed [7:0] carrier_sin, carrier_cos;
wire clk_4div; 
wire symbol_strobe; // 🔴 核心节拍：由定时 NCO 吐出
wire [1:0] i_data, q_data;
wire fir_q_vaild, fir_i_vaild;
reg signed [19:0] fir_i, fir_q;

// --- 滤波器数据截位与归一化 ---
wire signed [22:0] fir_i_temp_23b, fir_q_temp_23b;
wire signed [19:0] fir_i_temp = fir_i_temp_23b[22:3];
wire signed [19:0] fir_q_temp = fir_q_temp_23b[22:3];

assign p_data = {i_data[1], q_data[1], i_data[0], q_data[0]};

// 1. 基础分频 (用于串并转换)
freq_div #(.DIV(4)) u_div4(
    .orgin_clk(orgin_clk), .reset_n(reset_n), .out_clk(clk_4div)
);

// 2. 载波同步环路 (DD-PLL)
mod_carrier_sync u_carrier_sync (
    .clk           (carrier_clk),
    .reset_n       (reset_n),
    .symbol_strobe (symbol_strobe), // 接收定时环路反馈的巅峰脉冲
    .fir_i         (fir_i),
    .fir_q         (fir_q),
    .carrier_sin   (carrier_sin),
    .carrier_cos   (carrier_cos)
);

// 3. 解调乘法器
demod_mul u_demod_mul(
    .clk(carrier_clk), .carrier_cos(carrier_cos), .carrier_sin(carrier_sin),
    .signal(signal), .out_i(mul_i), .out_q(mul_q)
);
// 4. I/Q 两路低通滤波器 (恢复完整的 Avalon-ST 引脚映射)
demod_fir demod_fir_i(
    .clk(carrier_clk), 
    .reset_n(reset_n),    // 🟢 恢复正常复位
    .ast_sink_data(mul_i),     
    .ast_sink_valid(1'b1),  
    .ast_sink_error(2'b00), // 🔴 救命恩人归位：强制声明上游无错误
    .ast_source_ready(1'b1),  
    .ast_sink_ready(),     
    .ast_source_data(fir_i_temp_23b), 
    .ast_source_valid(fir_i_vaild),                     
    .ast_source_error()
);

always @(posedge carrier_clk or negedge reset_n) begin
    if(!reset_n) fir_i <= 20'b0;
    else if (fir_i_vaild) fir_i <= fir_i_temp;
end

demod_fir demod_fir_q(
    .clk(carrier_clk), 
    .reset_n(reset_n),    // 🟢 恢复正常复位
    .ast_sink_data(mul_q),     
    .ast_sink_valid(1'b1),  
    .ast_sink_error(2'b00), // 🔴 救命恩人归位
    .ast_source_ready(1'b1),  
    .ast_sink_ready(), 
    .ast_source_data(fir_q_temp_23b), 
    .ast_source_valid(fir_q_vaild),                     
    .ast_source_error()
);

always @(posedge carrier_clk or negedge reset_n) begin
    if(!reset_n) fir_q <= 20'b0;
    else if (fir_q_vaild) fir_q <= fir_q_temp;
end
// =========================================================================
// 🔄 位定时同步环路 (Bit Timing Recovery Loop)
// 采用 Gardner 算法闭环结构，实现 1.25Msps 符号速率的精准跟踪
// =========================================================================

// --- 定时环路内部连线 ---
wire signed [31:0] timing_error;       // TED 输出的瞬时相位误差
wire               timing_error_valid; // 误差有效标志
wire signed [31:0] timing_loop_out;    // 环路滤波器输出的微调量
wire               strobe_2x;          // 2.5MHz 采样脉冲

// [TED] 1. 眼睛：定时误差提取器
mod_gardner_ted_8x u_ted (
    .clk            (carrier_clk),
    .reset_n        (reset_n),
    .in_i           (fir_i),
    .in_q           (fir_q),
    .strobe_2x      (strobe_2x),       // 🔴 这里改掉！原来是 symbol_strobe
    .timing_error   (timing_error),
    .error_valid    (timing_error_valid)
);

// [LF] 2. 大脑：环路滤波器 (PI 控制器，平滑误差信号)
mod_timing_filter u_timing_brain (
    .clk             (carrier_clk),
    .reset_n         (reset_n),
    .timing_error    (timing_error),
    .error_valid     (timing_error_valid),
    .timing_loop_out (timing_loop_out) // 输出给 NCO 的控制字
);

// [NCO] 3. 心脏：定时 NCO (产生 2.5MHz 和 1.25MHz 同步脉冲)
mod_timing_nco u_timing_heart (
    .clk           (carrier_clk),
    .reset_n       (reset_n),
    .timing_mod    (timing_loop_out),
    .strobe_2x     (strobe_2x),
    .symbol_strobe (symbol_strobe)     // 产生神级同步脉冲
);

// =========================================================
// 判决与后端输出 (带相位解密开关 🗝️)
// =========================================================

// 定义解密后的最终数据线
wire signed [19:0] final_i;
wire signed [19:0] final_q;

// 🟢 极其核心：请每次打开下面的一把钥匙（注释掉其他的），去试哪个能跑到 0 误码！

// 🗝️ 原味钥匙 (0度，默认锁对的情况)
assign final_i = fir_i;
assign final_q = fir_q;

// 🗝️ 钥匙一 (逆时针转90度) —— 这个试过了，不行，注释掉！
// assign final_i = -fir_q;
// assign final_q = fir_i;

// 🟢 🗝️ 钥匙二 (转180度) —— 打开这个！直接双路取反！
//assign final_i = -fir_i;
//assign final_q = -fir_q;

// 🗝️ 钥匙三 (顺时针转90度)
//assign final_i = fir_q;
//assign final_q = -fir_i;

// 把解密后的 final_i 和 final_q 送进判决器
demod_dec demod_dec_i(
    .fir_data(final_i), .reset_n(reset_n), .carrier_clk(carrier_clk), // 🔴 这里换成了 final_i
    .signal_clk(symbol_strobe), .signal(i_data)
);

demod_dec demod_dec_q(
    .fir_data(final_q), .reset_n(reset_n), .carrier_clk(carrier_clk), // 🔴 这里换成了 final_q
    .signal_clk(symbol_strobe), .signal(q_data)
);

demod_p2s u_demod_p2s(
    .clk           (carrier_clk),  
    .reset_n       (reset_n),
    .symbol_strobe (symbol_strobe),  
    .signal        (p_data),
    .serial        (demod_out)
);

endmodule