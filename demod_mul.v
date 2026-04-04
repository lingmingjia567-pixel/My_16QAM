// =========================================================
// 🚀 接收端解调乘法器 (16位接收 × 8位载波)
// =========================================================
module demod_mul(clk, carrier_cos, carrier_sin, signal, out_i, out_q);
input clk;
input signed [7:0] carrier_cos;
input signed [7:0] carrier_sin;
input signed [15:0] signal; // 🔴 扩容：接收来自顶层的 16 位大水管

output signed [7:0] out_i;
output signed [7:0] out_q;

reg signed [23:0] mul_i;
reg signed [23:0] mul_q;

always @(posedge clk) begin
	mul_i <= carrier_cos * signal;
	mul_q <= carrier_sin * signal;
end
wire signed [23:0] test_mul_full = carrier_cos * signal;
// 24位结果中，低位是噪声，高位是符号。我们截取黄金的 [22:15] 区间还原为 8 位
assign out_i = {mul_i[23],mul_i[15:9]};
assign out_q = {mul_q[23],mul_q[15:9]};

endmodule