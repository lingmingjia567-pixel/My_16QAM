// =========================================================
// 🦾 定时 NCO：产生 2x 符号率和 1x 符号率脉冲的“心脏”
// =========================================================
module mod_timing_nco (
    input  wire clk,                  // 10MHz 系统主时钟
    input  wire reset_n,
    input  wire signed [31:0] timing_mod, // 来自滤波器的大脑指令
    output wire strobe_2x,            // 2.5MHz 脉冲 (Gardner 移位用)
    output wire symbol_strobe         // 1.25MHz 脉冲 (判决与载波同步用)
);

    // 标称步进：2^32 / (10MHz / 2.5MHz) = 2^32 / 4 = 32'h40000000
    localparam [31:0] BASE_STEP = 32'h4000_0000;

    reg [31:0] timer_acc;
    reg timer_acc_msb_d;
    reg sk;

    // 1. 核心累加器：BASE + MOD
    // 只要 mod 是正的，溢出就变快（频率变高）；反之变慢。
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n)
            timer_acc <= 32'd0;
        else
            timer_acc <= timer_acc + (BASE_STEP + timing_mod);
    end

    // 2. 边缘检测产生 strobe_2x
    always @(posedge clk) timer_acc_msb_d <= timer_acc[31];
    assign strobe_2x = (~timer_acc_msb_d) & timer_acc[31];

    // 3. 二分频逻辑产生 symbol_strobe (1.25MHz)
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n)
            sk <= 1'b0;
        else if (strobe_2x)
            sk <= ~sk;
    end

    // 只有在 sk 为 1 的那个 2x 脉冲，才是我们要的 1x 符号巅峰脉冲
    assign symbol_strobe = strobe_2x & sk;

endmodule