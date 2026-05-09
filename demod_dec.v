// =========================================================
// 🚀 16QAM 黄金判决器 (终极闭环驱动版)
// =========================================================
module demod_dec(fir_data, reset_n, carrier_clk, signal_clk, signal);
input signed [19:0] fir_data;
input reset_n;
input carrier_clk; 
input signal_clk;  // 🔴 顶层送进来的闭环快门脉冲 (symbol_strobe)
output reg [1:0] signal;

// 有符号判决门限
parameter signed [19:0] THRESHOLD = 20'sd50000;

// 🔴 核心改造：拔掉机械的 8 倍计数器，彻底放弃 PHASE_OFFSET！
// 巅峰抓取与星座映射 
always @(posedge carrier_clk or negedge reset_n) begin
    if (!reset_n) begin
        signal <= 2'b00;
    end else if (signal_clk) begin 
        // 🟢 只要听到智能快门咔嚓声 (signal_clk为高)，立刻无脑拍照判决！
        
        // 正统格雷码字典：全部采用有符号比较
        if (fir_data > THRESHOLD)
            signal <= 2'b10;       // 收到+3，就是 10
        else if (fir_data > 20'sd0) 
            signal <= 2'b11;       // 收到+1，就是 11
        else if (fir_data > -THRESHOLD)
            signal <= 2'b01;       // 收到-1，就是 01
        else
            signal <= 2'b00;       // 收到-3，就是 00
            
    end
end

endmodule