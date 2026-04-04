// =========================================================
// 🚀 10MHz采样率下的 2.5MHz 极简正交载波发生器
// =========================================================
module carrier_generator(
	input clk,           // 10MHz 采样时钟
	input reset_n,
	output reg signed [7:0] sin,
	output reg signed [7:0] cos
);

	reg [1:0] cnt; // 只需要一个 0~3 的计数器，4个状态就是一个完整的周期！
	
	// 4个状态循环切换 (0, 1, 2, 3)
	always @(posedge clk or negedge reset_n) begin
		if(!reset_n) 
			cnt <= 2'd0;
		else 
			cnt <= cnt + 2'd1;
	end
	
	// 输出绝对正交的载波 (幅值放大到 127，完美适配 8-bit 有符号数)
	always @(*) begin
		case(cnt)
			// cos = 1, 0, -1, 0  |  sin = 0, 1, 0, -1
			2'd0: begin cos =  8'd127; sin =  8'd0;   end
			2'd1: begin cos =  8'd0;   sin =  8'd127; end
			2'd2: begin cos = -8'd127; sin =  8'd0;   end
			2'd3: begin cos =  8'd0;   sin = -8'd127; end
		endcase
	end

endmodule