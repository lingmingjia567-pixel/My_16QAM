// =========================================================
// 🚀 接收端总成：纯净 10MHz 链路
// =========================================================
module demod_16QAM(carrier_clk, orgin_clk, reset_n, signal, demod_out);
input carrier_clk, reset_n, orgin_clk;
input signed [15:0] signal; // 🔴 扩容为 16 位，接住发射端的绝美波形
output demod_out;

wire [3:0] p_data;
wire signed [7:0] mul_i;
wire signed [7:0] mul_q;
wire signed [7:0] carrier_sin;
wire signed [7:0] carrier_cos;
wire clk_4div; 
wire [1:0] i_data;
wire [1:0] q_data;

wire fir_q_vaild;
wire fir_i_vaild;
reg signed [19:0] fir_i;
reg signed [19:0] fir_q;
wire signed [19:0] fir_i_temp;
wire signed [19:0] fir_q_temp;

assign p_data = {i_data[1], q_data[1], i_data[0], q_data[0]};

// 保留 4 分频 (用于串并转换)
freq_div #(.DIV(4)) u_div4(
	.orgin_clk(orgin_clk), .reset_n(reset_n), .out_clk(clk_4div)
);

// 载波生成 (与发送端完全一致)
carrier_generator u_carrier(
	.clk(carrier_clk), .reset_n(reset_n), .sin(carrier_sin), .cos(carrier_cos)
);

// 乘法器
demod_mul u_demod_mul(
	.clk(carrier_clk), .carrier_cos(carrier_cos), .carrier_sin(carrier_sin),
	.signal(signal), .out_i(mul_i), .out_q(mul_q)
);

// =========================================================
// 🔴 核心改造：所有滤波器全部统一使用 10MHz (carrier_clk)！
// =========================================================
demod_fir demod_fir_i(
	.clk(carrier_clk), // 拆除炸弹，换上高铁引擎！
	.reset_n(reset_n),                               
	.ast_sink_data(mul_i),     
	.ast_sink_valid(1'b1),  
	.ast_sink_error(2'b00), 
	.ast_source_ready(1'b1),  
	.ast_sink_ready(),      
	.ast_source_data(fir_i_temp),  
	.ast_source_valid(fir_i_vaild),                        
	.ast_source_error()
);

always @(posedge carrier_clk or negedge reset_n) begin
	if(!reset_n)
		fir_i <= 20'b0;
	else if (fir_i_vaild)
		fir_i <= fir_i_temp;
end

demod_fir demod_fir_q(
	.clk(carrier_clk), // 同上！
	.reset_n(reset_n),                               
	.ast_sink_data(mul_q),     
	.ast_sink_valid(1'b1),  
	.ast_sink_error(2'b00),
	.ast_source_ready(1'b1),  
	.ast_sink_ready(), 
	.ast_source_data(fir_q_temp),  
	.ast_source_valid(fir_q_vaild),                        
	.ast_source_error()
);

always @(posedge carrier_clk or negedge reset_n) begin
	if(!reset_n)
		fir_q <= 20'b0;
	else if (fir_q_vaild)
		fir_q <= fir_q_temp;
end

// 判决与串并转换
demod_dec demod_dec_i(
	.fir_data(fir_i), .reset_n(reset_n), .carrier_clk(carrier_clk),
	.signal_clk(orgin_clk), .signal(i_data)
);

demod_dec demod_dec_q(
	.fir_data(fir_q), .reset_n(reset_n), .carrier_clk(carrier_clk),
	.signal_clk(orgin_clk), .signal(q_data)
);

demod_p2s u_demod_p2s(
	.serial_clk(orgin_clk), .signal_clk(clk_4div), .reset_n(reset_n),
	.signal(p_data), .serial(demod_out)
);
	
endmodule