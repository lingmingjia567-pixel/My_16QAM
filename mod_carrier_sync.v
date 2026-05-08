// =========================================================
// 🚀 终极解旋转器 (Derotator DD-PLL) - 绝对直纹锁定版 🌟
// 功能：避开 FIR 大延迟，实现大频偏下的秒锁定与死直控制线
// =========================================================
module mod_carrier_sync (
    input wire clk,
    input wire reset_n,
    input wire signed [19:0] fir_i,       // 输入：带有 10Hz 频偏旋转的 RRC 滤波信号
    input wire signed [19:0] fir_q,
    input wire symbol_strobe,             
    output wire signed [19:0] derot_i,    // 🎯 输出：锁定后的死直 I 信号
    output wire signed [19:0] derot_q     // 🎯 输出：锁定后的死直 Q 信号
);

    wire signed [31:0] freq_control_word;
    wire signed [9:0] nco_sin_10bit;
    wire signed [9:0] nco_cos_10bit;
    wire out_valid_dummy;

    // 1. 基带微调 NCO (标称 0Hz 起步，只负责纠正频偏)
    my_nco_10m u_bb_nco (
        .clk        (clk),
        .reset_n    (reset_n),
        .clken      (1'b1),
        .phi_inc_i  (32'd0),            // 初始频率为 0
        // 🛑 核心开关：这里把极性接反！搭配后面 error_ext 正常的鉴相极性。
    
        .freq_mod_i (freq_control_word), 
        .fsin_o     (nco_sin_10bit),     
        .fcos_o     (nco_cos_10bit),     
        .out_valid  (out_valid_dummy)
    );

    wire signed [7:0] bb_sin = nco_sin_10bit[9:2];
    wire signed [7:0] bb_cos = nco_cos_10bit[9:2];

    // 2. 解旋转器 (复数乘法器: Derot = FIR * exp(j*theta_nco))
    // 采用 29 位防爆宽，防止符号位溢出。
    wire signed [28:0] mult_ii = $signed(fir_i) * $signed(bb_cos);
    wire signed [28:0] mult_qq = $signed(fir_q) * $signed(bb_sin);
    wire signed [28:0] mult_qi = $signed(fir_q) * $signed(bb_cos);
    wire signed [28:0] mult_iq = $signed(fir_i) * $signed(bb_sin);

    // 留出足够的符号位进行加减法
    // 🔴 史诗级修复：恢复完美的复数共轭乘法！(注意加减号的位置！)
    wire signed [29:0] sum_i = $signed(mult_ii) + $signed(mult_qq); // 之前是减，现在改回加！
    wire signed [29:0] sub_q = $signed(mult_qi) - $signed(mult_iq); // 之前是加，现在改回减！ 2

    // 归一化提取，截取中间段防止量化噪声超标
    assign derot_i = sum_i[26:7];
    assign derot_q = sub_q[26:7];

    // 3. DD 鉴相器
    wire signed [19:0] phase_error;
    wire error_valid;
    mod_dd_ped u_dd_ped (
        .clk         (clk),
        .reset_n     (reset_n),
        .strobe      (symbol_strobe),
        .in_i        (derot_i),        // 🎯 吃进纠正后的数据
        .in_q        (derot_q),
        .phase_error (phase_error),
        .error_valid (error_valid)
    );

    // 4. 环路滤波器 (PI 控制器 - 采用中等稳定增益)
    mod_loop_filter u_lf (
        .clk               (clk),
        .reset_n           (reset_n),
        .phase_error       (phase_error),
        .error_valid       (error_valid),
        .freq_control_word (freq_control_word)
    );

endmodule