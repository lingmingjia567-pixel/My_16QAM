/*
* 数字信号源 (读取 MATLAB txt 外部数据并串行纯同步输出)
*/
module data_create(clk, reset_n, out);
input clk, reset_n;

// 🔴 1. 换回 reg！我们要做真正的同步触发器输出
output reg out; 

parameter DATA_DEPTH = 50000;
reg [3:0] rom_memory [0:DATA_DEPTH-1];

// 行地址计数器 和 比特分配计数器
reg [15:0] address;
reg [1:0] bit_cnt; 

initial begin
   $readmemb("C:/Users/21503/Desktop/My_16QAM-main/simulation/modelsim/QAM_o.txt", rom_memory);
end

// 🔴 2. 核心魔法：纯粹的同步状态机，全在上升沿干活！
always @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
        out <= 1'b0;
        address <= 16'd0;
        bit_cnt <= 2'd3;  
    end else begin
        // 动作A：当时钟上升沿到来时，先把当前指向的数据“吐”到输出端口
        out <= rom_memory[address][bit_cnt];
        
        // 动作B：同时，立刻把计数器拨到下一个位置，给下一次时钟沿做准备
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