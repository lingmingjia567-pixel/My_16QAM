module top(signal_clk, carrier_clk, reset_n, in_data, out_data);
input signal_clk, carrier_clk, reset_n;
output wire in_data, out_data;

// 连线定义
wire signed [15:0] mod_data;    // 发射机出来的纯净信号
wire signed [15:0] noisy_data;  // 经过信道后的带噪信号

// ==========================================
// 1. 发射机 (Tx)
// ==========================================
mod_16QAM mod(
	.signal_clk(signal_clk),
	.carrier_clk(carrier_clk),
	.reset_n(reset_n),
	.mod_out(mod_data),     // 纯净信号输出
	.serial_data(in_data)
);

// ==========================================
// 2. AWGN 信道 (Channel)
// ==========================================
awgn_channel channel(
    .clk(carrier_clk),      // 🔴 注意：噪声是按 10MHz 采样的，所以必须接 carrier_clk！
    .reset_n(reset_n),
    .tx_signal(mod_data),   // 接入纯净信号
    .rx_signal(noisy_data)  // 输出带噪信号
);

// ==========================================
// 3. 接收机 (Rx)
// ==========================================
demod_16QAM demod(
	.carrier_clk(carrier_clk),
	.orgin_clk(signal_clk),
	.reset_n(reset_n),
	.signal(noisy_data),    // 吃进带噪信号
	.demod_out(out_data)
);

endmodule