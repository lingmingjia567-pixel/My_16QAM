// =========================================================
// 🚀 调制端串并转换 + 模4格雷差分编码 (终极完美映射版)
// =========================================================
module mod_s2p(clk_s, clk_p, reset_n, signal, code);
	input clk_s;
	input clk_p;
	input reset_n;
	input signal; 
	output reg [3:0] code;

	reg [3:0] buffer;
	reg [1:0] cnt;

	reg Ik_prev, Qk_prev;

	// 🔴 完美抓取符号位：当 cnt==3 时，buffer={X, D3, D2, D1}, signal=D0
	wire Ak = buffer[2]; // D3 (I路符号)
	wire Bk = buffer[1]; // D2 (Q路符号)  <-- 之前这里错抓成了 D1，现在彻底修正！
	
	wire Ak_xor_Bk = Ak ^ Bk;
	wire not_Ak_xor_Bk = ~Ak_xor_Bk;
	
	wire Ik_next = (not_Ak_xor_Bk & (Ak ^ Ik_prev)) ^ (Ak_xor_Bk & (Ak ^ Qk_prev));
	wire Qk_next = (not_Ak_xor_Bk & (Bk ^ Qk_prev)) ^ (Ak_xor_Bk & (Bk ^ Ik_prev));

	always @(posedge clk_s or negedge reset_n) begin
		if (!reset_n) begin
			buffer <= 4'd0;
			code <= 4'd0;
			cnt <= 2'd0;
			Ik_prev <= 1'b0;
			Qk_prev <= 1'b0;
		end else begin
			buffer <= {buffer[2:0], signal};
			cnt <= cnt + 2'd1;

			if (cnt == 2'd3) begin
				// 🔴 完美重组：{I路符号(编码后), Q路符号(编码后), I路幅度(原D1), Q路幅度(原D0)}
				code <= {Ik_next, Qk_next, buffer[0], signal};
				
				Ik_prev <= Ik_next;
				Qk_prev <= Qk_next;
			end
		end
	end
endmodule