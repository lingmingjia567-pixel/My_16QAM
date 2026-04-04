// =========================================================
// 🚀 发射端高速乘法器 (16位基带 × 8位载波)
// =========================================================
module mod_mul(clk, signal, carrier, out);
input clk;
input signed [15:0] signal;  // 来自 RRC 滤波器的 16 位平滑波形
input signed [7:0] carrier;  // 来自载波发生器的 8 位正弦/余弦波
output signed [23:0] out;    // 16 + 8 = 24 位全精度输出

// 在 FPGA 里，乘法器后面加一级寄存器可以极大地提升运行时钟频率(Fmax)
reg signed [23:0] mul_result;

always @(posedge clk) begin
	mul_result <= signal * carrier;
end

assign out = mul_result;

endmodule