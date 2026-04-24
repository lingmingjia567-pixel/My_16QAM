module mod_dd_ped (
    input wire clk,
    input wire reset_n,
    input wire strobe,             // 🌟 核心新增：定时脉冲
    input wire signed [19:0] in_i, 
    input wire signed [19:0] in_q, 
    output reg signed [19:0] phase_error, 
    output reg error_valid                
);

    parameter GATE_TH = 20'sd50000; // 门限可以保持 50000

    wire i_is_outer = (in_i > GATE_TH) || (in_i < -GATE_TH);		//检测i路幅值是否大于门限
    wire q_is_outer = (in_q > GATE_TH) || (in_q < -GATE_TH);		//检测q路幅值是否大于门限
    wire is_corner  = i_is_outer && q_is_outer;  //两路都大于，则为角点，允许后面的鉴相器工作

    wire sign_i = in_i[19];			//提取I路符号，0为正，1为负。   在数学里，角度变小，就是顺时针旋转
    wire sign_q = in_q[19];			//提取Q路符号

    wire signed [19:0] cross_1 = (sign_q == 1'b0) ? in_i : -in_i;			// cross_1 等价于：I_rx * Q_ideal的符号
    wire signed [19:0] cross_2 = (sign_i == 1'b0) ? in_q : -in_q;			// cross_2 等价于：Q_rx * I_ideal的符号

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n)
				begin
            phase_error <= 20'sd0;
            error_valid <= 1'b0;
				end 
		  else if (strobe) 
				begin 
					// 🎯 灵魂暴击：只有在巅峰时刻，才去抓误差！
					if (is_corner) begin
						phase_error <= cross_2 - cross_1;		//在数学里，角度变小，就是顺时针旋转。顺时针旋转：负数。逆时针旋转：正数
						error_valid <= 1'b1; 
					end else begin
						phase_error <= 20'sd0; 
						error_valid <= 1'b0;
					end
				end 
		  else 
				begin
					// 🛑 非巅峰时刻（比如过渡带），坚决不输出任何有效误差！
					error_valid <= 1'b0;
			end
		end

endmodule