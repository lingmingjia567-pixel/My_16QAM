// =========================================================
// 🚀 载波鉴相器：参考工程双模架构 (极性粗锁 + DD 精锁)
// =========================================================
module mod_dd_ped (
    input wire clk,
    input wire reset_n,
    input wire strobe,             
    input wire signed [19:0] in_i, 
    input wire signed [19:0] in_q,
    output reg signed [19:0] phase_error,
    output reg error_valid
);

    // 状态计数器
    reg [15:0] sym_cnt;
    
    // 中间信号寄存
    reg signed [19:0] sygnyi, sygnyq;
    reg signed [20:0] pd_polar; // 极性鉴相输出
    
    // DD 判决中间信号 (纯组合逻辑 wire，不需要复位)
    wire [19:0] abs_i = in_i[19] ? (~in_i + 1'b1) : in_i;
    wire [19:0] abs_q = in_q[19] ? (~in_q + 1'b1) : in_q;
    wire is_outer_i = (abs_i > 20'd58000);
    wire is_outer_q = (abs_q > 20'd58000);
    wire signed [19:0] ideal_i_mag = is_outer_i ? 20'd87000 : 20'd29000;
    wire signed [19:0] ideal_q_mag = is_outer_q ? 20'd87000 : 20'd29000;
    wire signed [19:0] ideal_i = in_i[19] ? -ideal_i_mag : ideal_i_mag;
    wire signed [19:0] ideal_q = in_q[19] ? -ideal_q_mag : ideal_q_mag;
    wire signed [19:0] err_i = in_i - ideal_i;
    wire signed [19:0] err_q = in_q - ideal_q;
    
    wire signed [20:0] cross_1 = in_i[19] ? -{err_q[19], err_q} : {err_q[19], err_q};
    wire signed [20:0] cross_2 = in_q[19] ? -{err_i[19], err_i} : {err_i[19], err_i};
    wire signed [20:0] pd_dd = cross_1 - cross_2; // DD 鉴相输出

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            // 🛡️ 补全的复位逻辑：杀灭所有 X 状态！
            sym_cnt <= 16'd0;
            phase_error <= 20'd0;
            error_valid <= 1'b0;
            sygnyi <= 20'd0;
            sygnyq <= 20'd0;
            pd_polar <= 21'd0;
        end else if (strobe) begin
            // ---------------------------------------------
            // 模块 1：复刻 PolarDetect (极性提取)
            // ---------------------------------------------
            if (!in_i[19]) sygnyq <= in_q; else sygnyq <= -in_q;
            if (!in_q[19]) sygnyi <= in_i; else sygnyi <= -in_i;
            pd_polar <= {sygnyq[19], sygnyq} - {sygnyi[19], sygnyi};

          
        // ---------------------------------------------
            // 模块 2：架构级双模切换逻辑
            // ---------------------------------------------
            // 🎯 恢复双模切换前 2万粗锁，后 2万切入 DD 提供极低抖动！
        // 🎯 将粗锁跑道缩到30000！
            if (sym_cnt < 16'd35000) begin 
                sym_cnt <= sym_cnt + 1'b1;
                phase_error <= pd_polar[19:0];
            end else begin
                phase_error <= pd_dd[19:0];
            end
            
            error_valid <= 1'b1;
        end else begin
            error_valid <= 1'b0;
        end
    end
endmodule