// =========================================================
// 🚀 发射端高速乘法器 (19位基带 × 8位载波) - 12-bit 升级版
// =========================================================
module mod_mul(clk, signal, carrier, out);
input clk;
input signed [18:0] signal;  // 🔴 扩容：接住来自 RRC 滤波器升级后的 19 位高精度波形
input signed [7:0] carrier;  // 载波发生器的 8 位正弦/余弦波 (保持不变)
output signed [26:0] out;    // 🔴 扩容：19 + 8 = 27 位全精度无损输出

// 保持你优秀的打拍习惯，极大地提升 Fmax
reg signed [26:0] mul_result; // 🔴 寄存器同步扩容到 27 位

always @(posedge clk) begin
	mul_result <= signal * carrier; // 硬件底层会自动推断出 19x8 的乘法器
end

assign out = mul_result;

endmodule