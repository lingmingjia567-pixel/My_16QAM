// =========================================================
// 🚀 解调端模4格雷差分解码 + 并串转换 (终极完美映射版)
// =========================================================
module demod_p2s(serial_clk, signal_clk, reset_n, signal, serial);
	input serial_clk;
	input signal_clk;
	input reset_n;
	input [3:0] signal;
	output reg serial;

	reg [3:0] buffer;
	reg [1:0] cnt;

	reg Ik_prev, Qk_prev;

	// 🔴 修正1：精准提取符号位！
	// 根据顶层 assign p_data = {i_data[1], q_data[1], i_data[0], q_data[0]};
	wire Ik = signal[3]; // I路符号 (MSB)
	wire Qk = signal[2]; // Q路符号 (MSB) <-- 之前这里是 signal[1]，已修正！
	
	reg Ak_out, Bk_out;

	// 🔴 修正2：用最清晰的逆向旋转判断，代替复杂的异或逻辑，物理意义满分！
	always @(*) begin
		if      (Ik == Ik_prev  && Qk == Qk_prev)  begin Ak_out = 1'b0; Bk_out = 1'b0; end
		else if (Ik == Qk_prev  && Qk == ~Ik_prev) begin Ak_out = 1'b0; Bk_out = 1'b1; end
		else if (Ik == ~Qk_prev && Qk == Ik_prev)  begin Ak_out = 1'b1; Bk_out = 1'b0; end
		else if (Ik == ~Ik_prev && Qk == ~Qk_prev) begin Ak_out = 1'b1; Bk_out = 1'b1; end
		else                                       begin Ak_out = 1'b0; Bk_out = 1'b0; end
	end

	always @(posedge serial_clk or negedge reset_n) begin
		if (!reset_n) begin
			buffer <= 4'd0;
			serial <= 1'b0;
			cnt <= 2'd0;
			Ik_prev <= 1'b0;
			Qk_prev <= 1'b0;
		end else begin
			cnt <= cnt + 2'd1;
			
			if (cnt == 2'd0) begin
				// 🔴 修正3：重组解交织，低位幅度必须是 signal[1] 和 signal[0]
				// 顺序：{D3(解出的A), D2(解出的B), D1(传来的I幅度), D0(传来的Q幅度)}
				buffer <= {Ak_out, Bk_out, signal[1], signal[0]};
				serial <= Ak_out; 
				
				Ik_prev <= Ik;
				Qk_prev <= Qk;
			end else begin
				buffer <= {buffer[2:0], 1'b0};
				serial <= buffer[2];
			end
		end
	end
endmodule