// =========================================================
// AWGN Channel Module (Pure English Version)
// =========================================================
module awgn_channel(
    input clk,                     
    input reset_n,
    input signed [15:0] tx_signal, 
    output signed [15:0] rx_signal 
);

// synthesis translate_off

    reg signed [15:0] noise_rom [0:399999]; 
    
    initial begin
        $readmemb("C:/Users/21503/Desktop/My_16QAM-main/simulation/modelsim/Noise_only.txt", noise_rom); 
    end

    reg [18:0] noise_ptr; 
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            noise_ptr <= 19'd0;
        end else begin
            if (noise_ptr == 19'd399999)
                noise_ptr <= 19'd0; 
            else
                noise_ptr <= noise_ptr + 1'b1;
        end
    end

    wire signed [15:0] current_noise = noise_rom[noise_ptr];
    
    // 🔴 核心恢复 1：解封噪声加法器！(用 17 位寄存器装，防止溢出)
    wire signed [16:0] noisy_sum = tx_signal + current_noise;

    // 🔴 核心恢复 2：解封饱和截断逻辑！(极其专业的 IC 设计习惯)
    // 如果加完噪声超过了 16位有符号数的最大/最小值，就强行顶格，防止波形突变反转
    assign rx_signal = (noisy_sum > 17'sd32767)  ? 16'sd32767 :
                       (noisy_sum < -17'sd32768) ? 16'sh8000  : 
                       noisy_sum[15:0];

// synthesis translate_on


// 🔴 核心剥离：把原来的直通线彻底切断！
// synthesis read_comments_as_HDL on
// assign rx_signal = tx_signal; 
// synthesis read_comments_as_HDL off

endmodule