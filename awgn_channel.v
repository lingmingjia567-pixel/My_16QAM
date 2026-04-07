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
    wire signed [16:0] noisy_sum = tx_signal + current_noise;

    assign rx_signal = (noisy_sum > 17'sd32767)  ? 16'sd32767 :
                       (noisy_sum < -17'sd32768) ? 16'sh8000  : 
                       noisy_sum[15:0];

// synthesis translate_on


// synthesis read_comments_as_HDL on

    // assign rx_signal = tx_signal;

// synthesis read_comments_as_HDL off

endmodule