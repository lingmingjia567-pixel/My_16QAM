// =========================================================
// 🚀 16QAM 黄金判决器 (修复版：带 signed 防止无符号灾难)
// =========================================================
module demod_dec(fir_data, reset_n, carrier_clk, signal_clk, signal);
input signed [19:0] fir_data;
input reset_n;
input carrier_clk; 
input signal_clk;  
output reg [1:0] signal;

// 🔴 终极武器 1：对焦齿轮 (取值 0~7)
parameter PHASE_OFFSET = 3'd4; 
// 🔴 终极武器 2：有符号判决门限 (加了 signed 和 'sd)
parameter signed [19:0] THRESHOLD = 20'sd50000;

// 8 倍下采样计数器 (10MHz 采 1.25MHz)
reg [2:0] cnt;
always @(posedge carrier_clk or negedge reset_n) begin
	if (!reset_n)
		cnt <= 3'd0;
	else
		cnt <= cnt + 3'd1;
end


// 巅峰抓取与星座映射 
always @(posedge carrier_clk or negedge reset_n) begin // 
	if (!reset_n) begin
		signal <= 2'b00;
	end else if (cnt == PHASE_OFFSET) begin 
		
		// 🔴 正统格雷码字典：全部采用有符号比较，完美识别负数
		if (fir_data > THRESHOLD)
			signal <= 2'b10;       // 收到+3，就是 10
		else if (fir_data > 20'sd0) // 🔴 0 也加上了 20'sd
			signal <= 2'b11;       // 收到+1，就是 11
		else if (fir_data > -THRESHOLD)
			signal <= 2'b01;       // 收到-1，就是 01
		else
			signal <= 2'b00;       // 收到-3，就是 00
			
	end
end

endmodule