// =========================================================
// 🚀 全同步并串转换器 (专为 8倍过采样 16QAM 接收机定制)
// =========================================================
module demod_p2s_sync(
    input wire clk,             // 统一接入系统高频时钟 (carrier_clk)
    input wire reset_n,
    input wire symbol_strobe,   // 接入 Gardner 算出来的完美同步脉冲
    input wire [3:0] p_data,    // 判决器吐出来的 4 比特并行数据
    output wire serial_out      // 最终的串行比特流
);

    reg [3:0] shift_reg;
    reg [1:0] div_cnt;          // 分频计数器 (数 2 个周期推一次)

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            shift_reg <= 4'b0;
            div_cnt <= 2'b0;
        end else if (symbol_strobe) begin
            // 🎯 脉冲到来：立刻把 4 个判决好的 bit 装进弹夹！
            shift_reg <= p_data;
            div_cnt <= 2'b0;    // 计数器清零
        end else begin
            // 🎯 没有脉冲时：利用高速时钟，每隔 2 个周期移位一次
            div_cnt <= div_cnt + 2'b1;
            if (div_cnt == 2'b01) begin 
                // 左移一位，最高位被顶出去
                shift_reg <= {shift_reg[2:0], 1'b0};
            end
        end
    end

    // 永远输出移位寄存器的最高位
    assign serial_out = shift_reg[3]; 

endmodule