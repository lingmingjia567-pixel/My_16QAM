/*
* 判决
*/
module demod_dec(fir_data,reset_n,carrier_clk,signal_clk,signal);
input signed [19:0] fir_data;
input reset_n,carrier_clk,signal_clk;
output reg [1:0] signal;

// 🔴 核心修改 1：把死板的门限 5000 改为适应新滤波器的 24000
localparam N = 20'd24000; 

reg [1:0] buffer;
wire signed [19:0] fir_abs; // 用线网实时计算绝对值，消灭时序错位

// 🔴 核心修改 2：使用组合逻辑实时求绝对值，零延迟
assign fir_abs = (fir_data < 0) ? -fir_data : fir_data;

always @(posedge carrier_clk or negedge reset_n) begin
	if(!reset_n) begin
		buffer <= 2'd0;
	end else begin
        // 🔴 核心修改 3：在同一个时钟上升沿，同时完美判定符号和幅度
		buffer[1] <= (fir_data > 0) ? 1'b0 : 1'b1;  // 判断极性：大于是0，小于是1
		buffer[0] <= (fir_abs > N) ? 1'b1 : 1'b0;   // 判断幅度：绝对值大于门限是1，否则是0
	end
end

always @(posedge signal_clk or negedge reset_n) begin
	if(!reset_n) begin
		signal <= 2'b0;
	end else begin
		signal <= buffer;
	end
end

endmodule