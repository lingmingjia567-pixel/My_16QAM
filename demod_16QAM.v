// =========================================================
// 🎯 接收端总成：解旋转架构 (Derotator Top) - 直纹图终极版 🌟
// 注入 0.2Hz 残余微小频偏，测试 DD-PLL 精调稳态死锁能力
// =========================================================
module demod_16QAM(carrier_clk, orgin_clk, reset_n, signal, demod_out);
input carrier_clk, reset_n, orgin_clk;
input signed [15:0] signal; 
output demod_out;

// --- 内部连线资源 ---
wire [3:0] p_data;
wire signed [7:0] mul_i, mul_q;
wire clk_4div; 
wire symbol_strobe; 
wire [1:0] i_data, q_data;
wire fir_q_vaild, fir_i_vaild;
reg signed [19:0] fir_i, fir_q;

// --- 滤波器数据截位连线 ---
wire signed [22:0] fir_i_temp_23b, fir_q_temp_23b;
// 🟢 退回黄金参数：恢复到最原始的 [22:3] 截位，信号满摆幅回到 8W 左右
wire signed [19:0] fir_i_temp = fir_i_temp_23b[22:3]; 
wire signed [19:0] fir_q_temp = fir_q_temp_23b[22:3];

assign p_data = {i_data[1], q_data[1], i_data[0], q_data[0]};

// 1. 基础分频
freq_div #(.DIV(4)) u_div4(
    .orgin_clk(orgin_clk), .reset_n(reset_n), .out_clk(clk_4div)
);

// =========================================================
// 🎯 前端固定开环本振 (只负责搬移和人为注入频偏)
// =========================================================
wire signed [9:0] fixed_sin_10bit, fixed_cos_10bit;
    my_nco_10m u_fixed_nco (
        .clk        (carrier_clk),
        .reset_n    (reset_n),
        .clken      (1'b1),
        // ✅ 完美制造 1KHz 的频偏靶子！
        .phi_inc_i  (32'd1074171321), 
        
        // ❌ 删掉那个没定义的 freq_control_word！
        // ✅ 改回 0！它不需要反馈控制，追踪频偏的任务交给后面的 mod_carrier_sync！
        .freq_mod_i (32'd0),          
        
        .fsin_o     (fixed_sin_10bit),
        .fcos_o     (fixed_cos_10bit),
        .out_valid  ()
    );

// 3. 解调乘法器
demod_mul u_demod_mul(
    .clk(carrier_clk), 
    .carrier_cos(fixed_cos_10bit[9:2]), 
    .carrier_sin(fixed_sin_10bit[9:2]),
    .signal(signal), .out_i(mul_i), .out_q(mul_q)
);

// 4. I/Q 低通滤波器
demod_fir demod_fir_i(
    .clk              (carrier_clk), 
    .reset_n          (reset_n), 
    .ast_sink_data    (mul_i),      
    .ast_sink_valid   (1'b1),         
    .ast_sink_error   (2'b00), 
    .ast_source_ready (1'b1),  
    .ast_source_data  (fir_i_temp_23b), 
    .ast_source_valid (fir_i_vaild)
);
always @(posedge carrier_clk or negedge reset_n) begin
    if(!reset_n) fir_i <= 20'b0;
    else if (fir_i_vaild) fir_i <= fir_i_temp;
end

demod_fir demod_fir_q(
    .clk              (carrier_clk), 
    .reset_n          (reset_n), 
    .ast_sink_data    (mul_q),      
    .ast_sink_valid   (1'b1), 
    .ast_sink_error   (2'b00), 
    .ast_source_ready (1'b1),  
    .ast_source_data  (fir_q_temp_23b), 
    .ast_source_valid (fir_q_vaild)
);
always @(posedge carrier_clk or negedge reset_n) begin
    if(!reset_n) fir_q <= 20'b0;
    else if (fir_q_vaild) fir_q <= fir_q_temp;
end

// =========================================================
// 🚀 【核心】解旋转 DD-PLL 环路
// =========================================================
wire signed [19:0] derot_i, derot_q;
mod_carrier_sync u_carrier_sync (
    .clk           (carrier_clk),
    .reset_n       (reset_n),
    .fir_i         (fir_i),         
    .fir_q         (fir_q),
    .symbol_strobe (symbol_strobe),
    .derot_i       (derot_i),       
    .derot_q       (derot_q)
);

// =========================================================
// 🔄 位定时同步环路 (Gardner) - 终极直连版
// =========================================================
wire signed [31:0] timing_error;
wire               timing_error_valid;
wire signed [31:0] timing_loop_out;
wire               strobe_2x;

mod_gardner_ted_8x u_ted (
    .clk            (carrier_clk),
    .reset_n        (reset_n),
    
    // 🟢 极简直连：直接吃进恢复到 8W 左右的 FIR 信号
    .in_i           (fir_i),
    .in_q           (fir_q),
    
    .strobe_2x      (strobe_2x),       
    .timing_error   (timing_error),
    .error_valid    (timing_error_valid)
);

mod_timing_filter u_timing_brain (
    .clk(carrier_clk), .reset_n(reset_n), 
    .timing_error(timing_error), .error_valid(timing_error_valid),
    .timing_loop_out(timing_loop_out)
);

mod_timing_nco u_timing_heart (
    .clk(carrier_clk), .reset_n(reset_n), .timing_mod(timing_loop_out),
    .strobe_2x(strobe_2x), .symbol_strobe(symbol_strobe)
);

// =========================================================
// 判决与后端输出
// =========================================================
wire signed [19:0] final_i;
wire signed [19:0] final_q;

// =========================================================
// 🗝️ 终极相位解密钥匙串 (最多试 4 次，必出 0 误码)
// 每次只留一行取消注释，其他的用 // 注释掉！
// =========================================================

// 🟢 钥匙 1：应对 0° 或 180° 锁定 (无 I/Q 交叉)
//assign final_i = derot_i;  
//assign final_q = derot_q;

// 🔴 钥匙 2：应对 90° 或 270° 锁定 (发生了 I/Q 交叉，强行旋回90°)
 assign final_i = derot_q;  
 assign final_q = -derot_i;

demod_dec demod_dec_i(
    .fir_data(final_i), .reset_n(reset_n), .carrier_clk(carrier_clk), 
    .signal_clk(symbol_strobe), .signal(i_data)   
);

demod_dec demod_dec_q(
    .fir_data(final_q), .reset_n(reset_n), .carrier_clk(carrier_clk), 
    .signal_clk(symbol_strobe), .signal(q_data)   
);

demod_p2s u_demod_p2s(
    .clk(carrier_clk), .reset_n(reset_n), 
    .symbol_strobe(symbol_strobe),                
    .signal(p_data), .serial(demod_out)
);

endmodule