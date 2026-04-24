module mod_carrier_sync (
    input wire clk,
    input wire reset_n,
    input wire signed [19:0] fir_i, 
    input wire signed [19:0] fir_q, 
    input wire symbol_strobe, //
	 output wire signed [7:0] carrier_sin, // 对外依然吐出标准的 8 位
    output wire signed [7:0] carrier_cos  
);

    // 内部连线
    wire signed [19:0] phase_error;
    wire error_valid;
    wire signed [31:0] freq_control_word;
    wire out_valid_dummy;
    
    // 用来接住 NCO 吐出来的 10 位巨无霸数据
    wire signed [9:0] nco_sin_10bit;
    wire signed [9:0] nco_cos_10bit;

    // 1. 例化鉴相器 (PED)
  mod_dd_ped u_dd_ped (
        .clk         (clk),
        .reset_n     (reset_n),
        .strobe      (symbol_strobe), // 🌟 核心新增：传给底层的交警
        .in_i        (fir_i),
        .in_q        (fir_q),
        .phase_error (phase_error),
        .error_valid (error_valid)
	 );

    // 2. 例化环路滤波器 (LF)
    mod_loop_filter u_lf (
        .clk               (clk),
        .reset_n           (reset_n),
        .phase_error       (phase_error),
        .error_valid       (error_valid),
        .freq_control_word (freq_control_word)
    );

    // 3. 例化 NCO (接入致命引脚！)
    my_nco_10m u_nco (
        .clk        (clk),
        .reset_n    (reset_n),
        .clken      (1'b1),
        .phi_inc_i  (32'd1073741824),    // 🔴 致命修复：焊死 2.5MHz 的基础频率控制字
       // 🟢 20Hz 黄金验证测试！故意让本地 NCO 慢 20Hz
        //.phi_inc_i  (32'd1073733234),
		  .freq_mod_i (freq_control_word), // 这是给环路滤波器微调用的端口
        .fsin_o     (nco_sin_10bit),     
        .fcos_o     (nco_cos_10bit),     
        .out_valid  (out_valid_dummy)
    );

    // 4. 核心手术：高位截断
    assign carrier_sin = nco_sin_10bit[9:2];
    assign carrier_cos = nco_cos_10bit[9:2];

endmodule