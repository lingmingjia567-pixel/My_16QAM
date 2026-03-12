/*
* 数字信号源 (读取 MATLAB txt 外部数据并串行输出)
*/
module data_create(clk, reset_n, out);
input clk, reset_n;

// 🔴 1. 改回 wire，去掉触发器的 1 拍延迟
output wire out; 

parameter DATA_DEPTH = 9988;
reg [3:0] rom_memory [0:DATA_DEPTH-1];

// 行地址计数器 和 比特分配计数器
reg [15:0] address;
reg [1:0] bit_cnt; 

initial begin
    $readmemb("QAM_o.txt", rom_memory);
end

// 🔴 2. 核心魔法：使用 assign 实时连线
// 意思是：如果 reset_n 是 0（复位中），out 直接强制接地（输出0）；
// 否则，out 瞬间接通当前的 rom_memory[address][bit_cnt]，零延迟！
assign out = (!reset_n) ? 1'b0 : rom_memory[address][bit_cnt];

// 3. 时序逻辑里只负责让地址和计数器乖乖按节拍变动，不再管 out
always @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
        address <= 16'd0;
        bit_cnt <= 2'd3;  
    end else begin
        if (bit_cnt == 2'd0) begin
            bit_cnt <= 2'd3; 
            if (address == DATA_DEPTH - 1) begin
                address <= 16'd0; 
            end else begin
                address <= address + 1'b1;
            end
        end else begin
            bit_cnt <= bit_cnt - 1'b1;
        end
    end
end

endmodule