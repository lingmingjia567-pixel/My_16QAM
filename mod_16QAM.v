// =========================================================
// 🚀 16QAM 黄金发射端：加入 RRC 成形滤波器与正交上变频
// =========================================================
module mod_16QAM(signal_clk, carrier_clk, reset_n, mod_out, serial_data);
input signal_clk, carrier_clk, reset_n;

// 输出位宽拓宽到 16 位，承载绝美的波形细节
output signed [15:0] mod_out;
output wire serial_data; 

wire [3:0] p_data; 
wire signed [7:0] carrier_sin;
wire signed [7:0] carrier_cos;
wire [1:0] signal_I; 
wire [1:0] signal_Q; 
wire clk_4div; 

assign signal_I = {p_data[3], p_data[1]};
assign signal_Q = {p_data[2], p_data[0]};

// 1. 保留极其完美的原有分频与串并转换
freq_div #(.DIV(4)) u_div4(
	.orgin_clk(signal_clk), .reset_n(reset_n), .out_clk(clk_4div)
);

data_create u_data_create(
	.clk(signal_clk), .reset_n(reset_n), .out(serial_data)
);

mod_s2p u_mod_s2p(
	.clk_s(signal_clk), .clk_p(clk_4div), .reset_n(reset_n),
	.signal(serial_data), .code(p_data)
);

carrier_generator u_carrier(
	.clk(carrier_clk), .reset_n(reset_n), .sin(carrier_sin), .cos(carrier_cos)
);

// =========================================================
// 🌟 核心手术区：基带映射 -> 插零升采样 -> RRC滤波 -> 混频
// =========================================================

// 【步骤 A】：星座映射 (将 2 比特转为 -3, -1, 1, 3 的基带电平)
reg signed [3:0] map_i, map_q;
always @(*) begin
	case(signal_I)
		2'b00: map_i = -4'd3;
		2'b01: map_i = -4'd1;
		2'b11: map_i =  4'd1;
		2'b10: map_i =  4'd3;
	endcase
	case(signal_Q)
		2'b00: map_q = -4'd3;
		2'b01: map_q = -4'd1;
		2'b11: map_q =  4'd1;
		2'b10: map_q =  4'd3;
	endcase
end

// 【步骤 B】：插零升采样 
reg clk_4div_d1, clk_4div_d2;
always @(posedge carrier_clk or negedge reset_n) begin
	if(!reset_n) begin
		clk_4div_d1 <= 1'b0; clk_4div_d2 <= 1'b0;
	end else begin
		clk_4div_d1 <= clk_4div; clk_4div_d2 <= clk_4div_d1;
	end
end
wire clk_4div_rise = clk_4div_d1 & ~clk_4div_d2;

// 🔴 核心修复：新增首脉冲掩码逻辑 (tx_valid)
reg tx_valid;
always @(posedge carrier_clk or negedge reset_n) begin
	if(!reset_n)
		tx_valid <= 1'b0;
	else if (clk_4div_rise)
		tx_valid <= 1'b1; // 第一个（假数据）脉冲到来时，将标志位拉高。在此之前 tx_valid 为 0
end

reg signed [3:0] upsampled_i, upsampled_q;
always @(posedge carrier_clk or negedge reset_n) begin
	if(!reset_n) begin
		upsampled_i <= 4'd0; 
		upsampled_q <= 4'd0;
	end else if(clk_4div_rise && tx_valid) begin 
		upsampled_i <= map_i; 
		upsampled_q <= map_q;
	end else begin
		upsampled_i <= 4'd0;  
		upsampled_q <= 4'd0;  // 🔴 罪魁祸首：刚才就是这里漏写了 Q 路的清零！！！
	end
end

// 【步骤 C】：呼叫你刚刚生成的 RRC 成形滤波器 IP 核 (16位输出)
wire signed [15:0] fir_out_i, fir_out_q; 

mod_fir u_tx_fir_i (
	.clk(carrier_clk),
	.reset_n(reset_n),
	.ast_sink_data(upsampled_i),  
	.ast_sink_valid(1'b1),        
	.ast_source_ready(1'b1),      
	.ast_sink_error(2'b00),       
	.ast_source_data(fir_out_i),  
	.ast_sink_ready(),            
	.ast_source_valid(),          
	.ast_source_error()           
);

mod_fir u_tx_fir_q (
	.clk(carrier_clk),
	.reset_n(reset_n),
	.ast_sink_data(upsampled_q),  
	.ast_sink_valid(1'b1),
	.ast_source_ready(1'b1),
	.ast_sink_error(2'b00),
	.ast_source_data(fir_out_q),
	.ast_sink_ready(),
	.ast_source_valid(),
	.ast_source_error()
);

// 【步骤 D】：模块化调用高速混频器
wire signed [23:0] mix_i;
wire signed [23:0] mix_q;

mod_mul u_mod_mul_i(
	.clk(carrier_clk),
	.signal(fir_out_i),
	.carrier(carrier_cos),
	.out(mix_i)
);

mod_mul u_mod_mul_q(
	.clk(carrier_clk),
	.signal(fir_out_q),
	.carrier(carrier_sin),
	.out(mix_q)
);

// 【步骤 E】：I/Q 合并与黄金截断
// 因为前面的乘法器消耗了 1 个时钟周期，这里的加法我们也用一个寄存器接住，保证时序稳定
reg signed [24:0] mod_out_full;
always @(posedge carrier_clk or negedge reset_n) begin
	if (!reset_n)
		mod_out_full <= 25'd0;
	else
		mod_out_full <= mix_i + mix_q;
end

// 截取核心动态范围的高 16 位，输出完美波形给下一级
assign mod_out = mod_out_full[23:8];

endmodule