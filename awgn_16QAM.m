% 16QAM完整系统仿真
clc; clear; close all;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% ====================== 一、系统参数配置 ======================
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
M = 16; % 16QAM调制阶数
k = log2(M); % 每符号比特数
N_sym = 50000; % 符号数
N_bits = N_sym * k; % 总比特数
Fs = 10e6; % 采样频率 10MHz
Rs = 1.25e6; % 符号速率 1.25Mbps
sps = Fs / Rs; % 每符号采样数 = 8
fc = 2.5e6; % 标称载波频率 2.5MHz
freq_offset = 500; % 频率偏差 500Hz
fc_offset = fc + freq_offset; % 偏移后的载波频率（用于直接解调）
phase_offset = 30; % 相位偏差（度）
phase_rad = phase_offset * pi/180; % 相位偏差（弧度，预计算）
rolloff = 0.5; % 滚降系数
span = 6; % 滤波器跨度
EbNo_dB = 10; % Eb/No (dB)

% 复数信号的SNR转换
% 参考：数字通信系统中 Eb/N0 与 SNR 转换方法的研究（张少侃，吕聪敏，甘浩）
SNR_dB = EbNo_dB + 10*log10(k) - 10*log10(sps);


%计算BER
EbNo_linear = 10^(EbNo_dB/10); 
TBer = (2/k) * (1 - 1/sqrt(M)) * erfc( sqrt( (3/(M-1)) * (EbNo_linear * k/2) ) );

fprintf('系统初始化完成，符号数：%d，总比特数：%d\n', N_sym, N_bits);
fprintf('标称载波频率：%.1f MHz，符号速率：%.1f Mbps\n', fc/1e6, Rs/1e6);
fprintf('频率偏差：%d Hz，相位偏差：%d°，Eb/No：%d dB\n', freq_offset, phase_offset, EbNo_dB);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% ====================== 二、生成随机比特流 ======================
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
fprintf('生成随机比特流...\n');
rng(42);
data_bits = randi([0 1], N_bits, 1);
data_symbols = bi2de(reshape(data_bits, k, N_sym).', 'left-msb');

%部分差分编码 (Tx) 

fprintf('执行高2比特部分差分编码...\n');
A = data_symbols > 7; % 取最高位 bit 3
B = (data_symbols - A*8) > 3; % 取次高位 bit 2

C = zeros(N_sym, 1); 
D = zeros(N_sym, 1);
for i = 1:N_sym
    if i == 1
        Cp = 0; Dp = 0; % 第一个符号假定前置状态为0
    else
        Cp = C(i-1); Dp = D(i-1);
    end
    % 严格对应参考的模4格雷加法逻辑
    C(i) = mod(((~mod(A(i)+B(i),2))&mod(A(i)+Cp,2)) + (mod(A(i)+B(i),2)&mod(A(i)+Dp,2)),2);
    D(i) = mod(((~mod(A(i)+B(i),2))&mod(B(i)+Dp,2)) + (mod(A(i)+B(i),2)&mod(B(i)+Cp,2)),2);
end
% 差分编码后的高2比特数据，与原数据的低2比特（不变）重新合并
diff_tx_symbols = C*8 + D*4 + mod(data_symbols, 4);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% ====================== 三、16QAM调制 ======================
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
fprintf('16QAM调制及射频发射...\n');

% 1. 基带调制 (使用完美对齐FPGA的自定义字典)
qam_dict = zeros(1, 16);
qam_dict(0+1)  = -3-3j; qam_dict(1+1)  = -3-1j; qam_dict(2+1)  = -1-3j; qam_dict(3+1)  = -1-1j;
qam_dict(4+1)  = -3+3j; qam_dict(5+1)  = -3+1j; qam_dict(6+1)  = -1+3j; qam_dict(7+1)  = -1+1j;
qam_dict(8+1)  =  3-3j; qam_dict(9+1)  =  3-1j; qam_dict(10+1) =  1-3j; qam_dict(11+1) =  1-1j;
qam_dict(12+1) =  3+3j; qam_dict(13+1) =  3+1j; qam_dict(14+1) =  1+3j; qam_dict(15+1) =  1+1j;

qam_dict_norm = qam_dict / sqrt(10); % 归一化平均功率
% 查表映射发送数据 (直接去字典里拿对应的值)
tx_symbols = qam_dict_norm(diff_tx_symbols + 1).';

% ==================== 👇 插入以下代码 👇 ====================
fprintf('\n--- 🕵️ 软硬件对比验证：前 10 个基带符号映射结果 ---\n');
% 将归一化的小数还原成完美的整数 (-3, -1, 1, 3)，方便和 FPGA 电平对比
I_amps = round(real(tx_symbols(1:10)) * sqrt(10));
Q_amps = round(imag(tx_symbols(1:10)) * sqrt(10));

for idx = 1:10
    % 获取当前符号的 4位 二进制字符串
    bin_str = dec2bin(diff_tx_symbols(idx), 4);
    fprintf('第 %2d 个符号 | 差分编码后比特: [%s]  >>>  I路电平: %+2d  |  Q路电平: %+2d\n', ...
        idx, bin_str, I_amps(idx), Q_amps(idx));
end
fprintf('--------------------------------------------------------\n\n');
% ==================== 👆 插入以上代码 👆 ====================

% 2. 脉冲成形
fprintf('实际生效参数：span=%d, sps=%d\n', span, sps);
rrc_filter = rcosdesign(rolloff, span, sps, 'sqrt');
fprintf('RRC滤波器长度：%d\n', length(rrc_filter)); 

% 升采样
tx_upsampled = upsample(tx_symbols, sps);
% 滤波
tx_baseband = filter(rrc_filter, 1, tx_upsampled);

% 3. 上变频（标称频率）- 使用复数载波
t = (0:length(tx_baseband)-1)' / Fs;
% 复数载波
complex_carrier = exp(1j*2*pi*fc*t);
% 复数上变频：直接将复数基带信号与复数载波相乘
tx_signal = tx_baseband .* complex_carrier;

% 显示时域波形
figure('Position', [50, 50, 1200, 400], 'Name', '16QAM时域波形', 'Color', 'white');
show_len = min(100, length(tx_signal));
t_plot = t(1:show_len) * 1e6;

subplot(1,2,1);
% 只显示已调信号的实部（这是实际的已调信号波形）
plot(t_plot, real(tx_signal(1:show_len)), 'b-', 'LineWidth', 1.5);
grid on; xlabel('时间 (μs)'); ylabel('幅度'); title('16QAM已调信号波形');

subplot(1,2,2);
% 显示I路和Q路的时域信号波形
plot(t_plot, real(tx_baseband(1:show_len)), 'b-', 'LineWidth', 1.5, 'DisplayName', 'I路');
hold on;
plot(t_plot, imag(tx_baseband(1:show_len)), 'r-', 'LineWidth', 1.5, 'DisplayName', 'Q路');
grid on; xlabel('时间 (μs)'); ylabel('幅度'); title('基带信号I路和Q路时域信号波形');
legend('Location', 'best');



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% ====================== 四、信道仿真（仅添加高斯白噪声） ======================
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
fprintf('添加信道噪声...\n');

% 理想信道 (仅高斯白噪声，无频率/相位偏差)
rng(42); % 使用固定种子
% 使用AWGN函数添加噪声
rx_signal = awgn(tx_signal, SNR_dB, 'measured');


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% ====================== 五、解调（三种模式） ======================
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% 定义不同解调模式的函数句柄（调用同一个通用函数，仅参数不同）
% 1. 模式1：用与发送端相同的载波解调
demod_func_same_carrier = @(sig) demodulate_process_unified(sig, Fs, fc, 0, true, sps, span, rrc_filter);
% 2. 模式2：用带频率偏差的载波解调
demod_func_freq_offset = @(sig) demodulate_process_unified(sig, Fs, fc_offset, 0, false, sps, span, rrc_filter);
% 3. 模式3：用带相位偏差的载波解调
demod_func_phase_offset = @(sig) demodulate_process_unified(sig, Fs, fc, phase_rad, false, sps, span, rrc_filter);

fprintf('开始解调...\n');

% 执行三种模式的解调
rx_sym_same_carrier = demod_func_same_carrier(rx_signal); % 相同载波解调
rx_sym_freq_offset = demod_func_freq_offset(rx_signal); % 频率偏差载波解调
rx_sym_phase_offset = demod_func_phase_offset(rx_signal); % 相位偏差载波解调

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% ====================== 六、对齐与截断 ======================
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
delay_symbols = span;
valid_len = N_sym - 2*delay_symbols;
start_idx = delay_symbols + 1; 

% 有效数据提取
rx_sym_same_carrier_valid = rx_sym_same_carrier(start_idx : start_idx+valid_len-1);
rx_sym_freq_offset_valid = rx_sym_freq_offset(start_idx : start_idx+valid_len-1);
rx_sym_phase_offset_valid = rx_sym_phase_offset(start_idx : start_idx+valid_len-1);


tx_symbols_valid = tx_symbols(start_idx : start_idx+valid_len-1);
data_bits_valid = data_bits( (start_idx-1)*k+1 : (start_idx+valid_len-1)*k );


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% ====================== 七、误码率计算 ======================
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
[ber_same_carrier, err_same_carrier] = calculate_ber(rx_sym_same_carrier_valid, data_bits_valid, M, true);
[ber_freq_offset, err_freq_offset] = calculate_ber(rx_sym_freq_offset_valid, data_bits_valid, M);
[ber_phase_offset, err_phase_offset] = calculate_ber(rx_sym_phase_offset_valid, data_bits_valid, M);

fprintf('\n===== 误比特率结果 (Eb/No=%d dB) =====\n', EbNo_dB);
fprintf('1. 相同载波解调: BER = %.2e, 错误比特数 = %d/%d\n', ber_same_carrier, err_same_carrier, valid_len*k);
fprintf('2. 频率偏差载波解调: BER = %.2e\n', ber_freq_offset);
fprintf('3. 相位偏差载波解调: BER = %.2e\n', ber_phase_offset);
fprintf('4. 理论误比特率: BER = %.2e\n', TBer);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% ====================== 八、星座图和频谱图 ======================
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% 创建星座图对比
create_constellation_plots_sync(tx_symbols_valid, rx_sym_same_carrier_valid, ...
rx_sym_freq_offset_valid, rx_sym_phase_offset_valid, ... 
M, freq_offset, phase_offset, EbNo_dB, ... 
ber_same_carrier, ber_freq_offset, ber_phase_offset, valid_len); 

% 创建频谱图
create_spectrum_plot(tx_signal, Fs, fc);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% ====================== 九、生成BER曲线图 ======================
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% 定义要扫描的Eb/No点
EbNo_points = [0, 2, 4, 6, 8, 10, 12];
num_points = length(EbNo_points);

% 预分配数组
ber_theory = zeros(1, num_points);
ber_sim = zeros(1, num_points);

% 扫描每个Eb/No点
for i = 1:num_points
current_EbNo = EbNo_points(i);
% 计算理论误比特率
EbNo_linear = 10^(current_EbNo/10); 
ber_theory(i) = (2/k) * (1 - 1/sqrt(M)) * erfc( sqrt( (3/(M-1)) * (EbNo_linear * k/2) ) );
% 为该Eb/No添加噪声并解调（相同载波模式）
rng(42); % 使用固定种子
% 使用AWGN函数添加噪声
% 计算当前Eb/No对应的SNR（考虑sps因子）
current_SNR = current_EbNo + 10*log10(k) - 10*log10(sps);
rx_signal_current = awgn(tx_signal, current_SNR, 'measured');
rx_sym_current = demod_func_same_carrier(rx_signal_current);
% 提取有效数据
rx_sym_current_valid = rx_sym_current(start_idx : start_idx+valid_len-1);
% 计算BER
[ber_sim(i), ~] = calculate_ber(rx_sym_current_valid, data_bits_valid, M);
end

% 绘制BER曲线图 
figure('Position', [100, 100, 800, 600], 'Name', '16QAM BER性能曲线', 'Color', 'white');

% 绘制平滑的理论曲线
EbNo_smooth = 0:0.1:12;
ber_theory_smooth = zeros(1, length(EbNo_smooth));
for i = 1:length(EbNo_smooth)
EbNo_linear = 10^(EbNo_smooth(i)/10); 
ber_theory_smooth(i) = (2/k) * (1 - 1/sqrt(M)) * erfc( sqrt( (3/(M-1)) * (EbNo_linear * k/2) ) );
end

% 对仿真数据进行插值，生成平滑曲线
ber_sim_smooth = interp1(EbNo_points, ber_sim, EbNo_smooth, 'spline');

% 对数坐标图
semilogy(EbNo_smooth, ber_theory_smooth, 'b-', 'LineWidth', 2.5, 'DisplayName', '理论BER');
hold on;
% 绘制仿真平滑曲线
semilogy(EbNo_smooth, ber_sim_smooth, 'r--', 'LineWidth', 1.5, 'DisplayName', '仿真BER（平滑）');
% 绘制原始仿真点
semilogy(EbNo_points, ber_sim, 'ro', 'MarkerSize', 8, 'MarkerFaceColor', 'r', 'DisplayName', '仿真BER（原始点）');

% 设置图形属性
grid on;
xlabel('Eb/No (dB)', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('BER', 'FontSize', 12, 'FontWeight', 'bold');
title('16QAM误比特率性能曲线', 'FontSize', 14, 'FontWeight', 'bold');
legend('Location', 'best');
xlim([0, 12]);
ylim([1e-4, 1]);

% 添加当前Eb/No点的标注
current_idx = find(EbNo_points == EbNo_dB);
if ~isempty(current_idx)
plot(EbNo_dB, ber_sim(current_idx), 'gs', 'MarkerSize', 12, 'LineWidth', 2, ...
'MarkerFaceColor', 'g', 'DisplayName', sprintf('当前Eb/No=%d dB', EbNo_dB));
end

fprintf('\nBER曲线图已生成\n');

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% ====================== 十、数据文档输出 ================================
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
1.% 2.matlab原比特流输出
output_file = 'C:\Users\21503\Desktop\My_16QAM-main\simulation\modelsim\QAM_o.txt';
fid = fopen(output_file, 'w');
if fid == -1
error('无法打开文件: %s', output_file);
end

Q = 4; % 每样本4比特
for i = 1:Q:length(data_bits)
if i + Q - 1 <= length(data_bits)
for j = 0:Q-1
fprintf(fid, '%d', data_bits(i+j));
end
fprintf(fid, '\r\n');
end
end

fprintf(fid, ';');
fclose(fid);
fprintf('原始参考比特流已成功写入文件: %s\n', output_file);
fprintf('写入比特数: %d\n', length(data_bits));

% 2.QAM调制数据拓展后输出
%为便于FPGA仿真时对比输入数据及解调后的数据，将QAM调制数据与写入txt文件中，以方便在TESTBENCH文件中读出，并显示在MODELSIM仿
%真波形中。
ud=ones(1,N_sym*Fs/Rs); %生成一个包含1行400000列的全一数组，意味着每个 QAM 符号会被采样 8 次（升采样），目的是让基带信号更平滑，适配硬件的采样时钟。
%考虑到FPGA实现时，解调QAM有时延，将调制数据写入txt文件时，延时 ? 个数据周期，以方便MODELSIM仿真观察
for i2=1:N_sym-4 %后4个符号的滤波结果是 “无效的边缘值”（受滤波器初始状态影响）,空出前 4 个符号的位置（ud (1:32)），只填充第 5 个符号及以后的数据，避免无效数据进入 FPGA 仿真；
ud(Fs/Rs*(i2-1+4)+1:Fs/Rs*(i2+4))=data_symbols(i2); %把每个随机符号 data_symbols(i2)（0-15）填充到 ud 的对应 8 个采样点位置，覆盖掉原来的 1；
end
ud(Fs/Rs*7:length(ud))=ud(1:length(ud)-Fs/Rs*7+1);
Q=4;
fid=fopen('D:\Quartus13.1\altera\program\QamCodeModem\simulation\modelsim\QAM_bit.txt','w');
for k2=1:length(ud)
B_s=dec2bin(ud(k2),Q);
for j=1:Q
if B_s(j)=='1'
tb=1;
else
tb=0;
end
fprintf(fid,'%d',tb); 
end
fprintf(fid,'\r\n');
end
fprintf(fid,';'); 
fclose(fid);


%将成形滤波器系数写入Shape_lpf.txt文件中
%滤波系数进行10bit量化
% 滤波系数进行 9-bit 量化 (最大值 255)
h_pm9 = round(rrc_filter/max(abs(rrc_filter))*(2^8-1));

fid=fopen('D:\Quartus13.1\altera\program\QamCodeModem\simulation\modelsim\Shape_lpf.txt','w');
% 用 %d 写入整数变量 h_pm9
fprintf(fid,'%d\r\n', h_pm9); 
fclose(fid);

% ==================== 👇 插入以下代码：滤波器量化对比与分析 👇 ====================
fprintf('\n--- 📉 滤波器量化评估分析 ---\n');
% 1. 将 9-bit 整数量化值，反向还原到浮点比例，以便和原滤波器绝对对齐比较
rrc_quantized_restore = h_pm9 / (2^8-1) * max(abs(rrc_filter));

% 2. 计算绝对量化误差
quant_error = rrc_filter - rrc_quantized_restore;

% 3. 计算信号量化噪声比 (SQNR - Signal to Quantization Noise Ratio)
sqnr_dB = 10 * log10( sum(rrc_filter.^2) / sum(quant_error.^2) );

fprintf('滤波器系数最大量化误差: %f\n', max(abs(quant_error)));
fprintf('滤波器量化信噪比 (SQNR): %.2f dB\n', sqnr_dB);
if sqnr_dB > 40
    fprintf('结论: SQNR 极高，9-bit 量化精度完全足够，不会是导致解调失败的元凶！\n');
else
    fprintf('⚠️ 警告: SQNR 偏低，量化误差过大，建议将系数提升至 10-bit 或 12-bit！\n');
end
fprintf('-----------------------------------------\n\n');

% 4. 绘制时域抽头对比图
figure('Position', [150, 150, 1000, 600], 'Name', 'RRC滤波器量化误差分析', 'Color', 'white');

% 子图1：波形重叠对比 (使用 stem 绘制离散抽头)
subplot(2, 1, 1);
stem(rrc_filter, 'b', 'LineWidth', 1.5, 'MarkerSize', 6, 'DisplayName', '理想浮点滤波器');
hold on;
stem(rrc_quantized_restore, 'r--', 'LineWidth', 1.5, 'MarkerSize', 4, 'DisplayName', '9-bit量化后还原');
grid on;
title(sprintf('RRC成型滤波器：浮点原值 vs 9-bit量化值 (SQNR = %.2f dB)', sqnr_dB), 'FontSize', 12, 'FontWeight', 'bold');
xlabel('抽头索引 (Tap Index)'); ylabel('幅度');
legend('Location', 'best');

% 子图2：误差绝对值
subplot(2, 1, 2);
stem(quant_error, 'k', 'LineWidth', 1.2, 'MarkerFaceColor', 'k');
grid on;
title('定点化引入的绝对量化误差', 'FontSize', 12, 'FontWeight', 'bold');
xlabel('抽头索引 (Tap Index)'); ylabel('误差幅度');
% ==================== 👆 插入以上代码 👆 ====================




%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% ====================== 辅助函数定义 ======================
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% --- 通用解调函数（核心：参数控制所有解调逻辑）---
% 输入参数：
% rx_signal: 接收信号
% Fs: 采样频率
% fc_use: 解调使用的载波频率（标称fc/偏移fc_offset）
% phase_comp_rad: 相位补偿弧度（0=无补偿，phase_rad=有补偿）
% is_ideal_timing: 是否理想定时（true=直接下采样，false=定时恢复）
% sps/span/rrc_filter: 滤波器参数
function rx_symbols = demodulate_process_unified(rx_signal, Fs, fc_use, phase_comp_rad, is_ideal_timing, sps, span, rrc_filter)
t = (0:length(rx_signal)-1)' / Fs;
% 1. 复数下变频
% 复数下变频：直接将复数接收信号与共轭复数载波相乘
complex_carrier = exp(-1j*(2*pi*fc_use*t + phase_comp_rad)); % 共轭复数载波
rx_complex = rx_signal .* complex_carrier;
% 2. 匹配滤波
rx_complex_filt = filter(rrc_filter, 1, rx_complex);
% 3. 消除滤波器延迟
total_delay = span * sps;
rx_complex = rx_complex_filt(total_delay+1 : end);
% 4. 定时处理（参数控制：理想定时/定时恢复）
if is_ideal_timing
% 理想模式：直接下采样（无定时恢复）
rx_symbols = downsample(rx_complex, sps);
else
% 非理想模式：定时恢复（能量最大化选最佳采样点）
num_candidates = sps;
energies = zeros(1, num_candidates);
for offset = 1:num_candidates
if offset <= length(rx_complex)
rx_temp = downsample(rx_complex(offset:end), sps);
if length(rx_temp) > 10
energies(offset) = mean(abs(rx_temp).^2);
end
end
end
[~, best_offset] = max(energies);

% 下采样（选最佳偏移）
if best_offset <= length(rx_complex)
rx_complex_best = rx_complex(best_offset:end);
rx_symbols = downsample(rx_complex_best, sps);
else
rx_symbols = downsample(rx_complex, sps);
end
end

% 5. 功率归一化
if length(rx_symbols) > 0
avg_power = mean(abs(rx_symbols).^2);
if avg_power > 0
rx_symbols = rx_symbols / sqrt(avg_power);
end
end
end

% --- BER 计算 ---
% ⭐⭐⭐ 核心修改二：在BER计算前加入部分差分解码 (Rx) ⭐⭐⭐
function [ber, error_bits] = calculate_ber(rx_symbols, ref_bits, M, write_to_file)
    if nargin < 4
        write_to_file = false;
    end
    k = log2(M);
    
    % 1. 先进行硬判决，解调出包含相位模糊的数据
    qam_dict = zeros(1, 16);
    qam_dict(0+1)=-3-3j; qam_dict(1+1)=-3-1j; qam_dict(2+1)=-1-3j; qam_dict(3+1)=-1-1j;
    qam_dict(4+1)=-3+3j; qam_dict(5+1)=-3+1j; qam_dict(6+1)=-1+3j; qam_dict(7+1)=-1+1j;
    qam_dict(8+1)=3-3j;  qam_dict(9+1)=3-1j;  qam_dict(10+1)=1-3j; qam_dict(11+1)=1-1j;
    qam_dict(12+1)=3+3j; qam_dict(13+1)=3+1j; qam_dict(14+1)=1+3j; qam_dict(15+1)=1+1j;
    qam_dict_norm = qam_dict / sqrt(10);
    
    % 计算接收信号到16个标准点的欧式距离，找最近的那个点
    distances = abs(rx_symbols - qam_dict_norm);
    [~, min_idx] = min(distances, [], 2);
    rx_data = min_idx - 1;
    
    % 2. 提取接收到的高 2 比特 (包含模糊)
    C_rx = floor(rx_data / 8);
    D_rx = floor(mod(rx_data, 8) / 4);
    
    A_dec = zeros(length(rx_data), 1);
    B_dec = zeros(length(rx_data), 1);
    
    % 3. 逆向作差，恢复出原始的绝对相位信息 (抵消常数模糊)
    for i = 1:length(rx_data)
        if i == 1
            cp = 0; dp = 0; % 解码首个符号时，假定初态为0
        else
            cp = C_rx(i-1); dp = D_rx(i-1);
        end
        c = C_rx(i); d = D_rx(i);
        
        % 反向逻辑映射查表
        if c == cp && d == dp
            A_dec(i) = 0; B_dec(i) = 0;
        elseif c == dp && d == 1-cp
            A_dec(i) = 0; B_dec(i) = 1;
        elseif c == 1-dp && d == cp
            A_dec(i) = 1; B_dec(i) = 0;
        elseif c == 1-cp && d == 1-dp
            A_dec(i) = 1; B_dec(i) = 1;
        end
    end
    
    % 4. 把解码后的高2比特，与不变的低2比特重组，获得最终原始符号！
    rx_data_decoded = A_dec*8 + B_dec*4 + mod(rx_data, 4);
    
    % 5. 转为二进制比特流用于算误码率
    rx_bits_mat = de2bi(rx_data_decoded, k, 'left-msb');
    rx_bits = reshape(rx_bits_mat.', [], 1);
% 只在 write_to_file 为 true 时写入解调后的比特流
if write_to_file
% 将解调后的比特流写入 QAM_d.txt（FPGA仿真格式：每4比特一行）
output_file = 'D:\Quartus13.1\altera\program\QamCodeModem\simulation\modelsim\QAM_d.txt';
%output_file = 'D:\Quartus13.1\altera\program\QAM\simulation\modelsim\QAM_d.txt';
fid = fopen(output_file, 'w');
if fid == -1
error('无法打开文件: %s', output_file);
end
% 写入解调后的比特流
Q = 4; % 每样本4比特
for i = 1:Q:length(rx_bits)
if i + Q - 1 <= length(rx_bits)
for j = 0:Q-1
fprintf(fid, '%d', rx_bits(i+j));
end
fprintf(fid, '\r\n');
end
end
fprintf(fid, ';');
fclose(fid);
fprintf('解调后的比特流已成功写入文件: %s\n', output_file);
fprintf('写入比特数: %d\n', length(rx_bits));
end
len = min(length(rx_bits), length(ref_bits));
error_bits = sum(rx_bits(1:len) ~= ref_bits(1:len));
ber = error_bits / len;
end

% --- 创建星座图---
function create_constellation_plots_sync(tx_symbols, rx_same_carrier, ...
rx_freq_offset, rx_phase_offset, ...
M, freq_offset, phase_offset, EbNo_dB, ...
ber_same_carrier, ber_freq_offset, ber_phase_offset, valid_len)
figure('Position', [50, 50, 1200, 400], 'Name', '16QAM星座图对比（三种解调模式）', 'Color', 'white');
% 创建标准星座图红十字点
    qam_dict = zeros(1, 16);
    qam_dict(0+1)=-3-3j; qam_dict(1+1)=-3-1j; qam_dict(2+1)=-1-3j; qam_dict(3+1)=-1-1j;
    qam_dict(4+1)=-3+3j; qam_dict(5+1)=-3+1j; qam_dict(6+1)=-1+3j; qam_dict(7+1)=-1+1j;
    qam_dict(8+1)=3-3j;  qam_dict(9+1)=3-1j;  qam_dict(10+1)=1-3j; qam_dict(11+1)=1-1j;
    qam_dict(12+1)=3+3j; qam_dict(13+1)=3+1j; qam_dict(14+1)=1+3j; qam_dict(15+1)=1+1j;
    constellation_points = qam_dict / sqrt(10);
show_points = min(2000, valid_len);
% 子图1：相同载波解调星座图
subplot(1,3,1);
if length(rx_same_carrier) >= show_points
scatter(real(rx_same_carrier(1:show_points)), imag(rx_same_carrier(1:show_points)), ...
15, 'g', 'filled', 'MarkerFaceAlpha', 0.6);
end
hold on;
scatter(real(constellation_points), imag(constellation_points), ...
100, 'r', 'x', 'LineWidth', 2);
grid on; axis equal;
xlim([-1.8 1.8]); ylim([-1.8 1.8]);
xlabel('I', 'FontSize', 10); ylabel('Q', 'FontSize', 10);
title(sprintf('相同载波解调\nBER = %.2e', ber_same_carrier), 'FontSize', 11);
% 子图2：频率偏差载波解调星座图
subplot(1,3,2);
if length(rx_freq_offset) >= show_points
scatter(real(rx_freq_offset(1:show_points)), imag(rx_freq_offset(1:show_points)), ...
15, [1 0.5 0], 'filled', 'MarkerFaceAlpha', 0.6);
end
hold on;
scatter(real(constellation_points), imag(constellation_points), ...
100, 'r', 'x', 'LineWidth', 2);
grid on; axis equal;
xlim([-1.8 1.8]); ylim([-1.8 1.8]);
xlabel('I', 'FontSize', 10); ylabel('Q', 'FontSize', 10);
title(sprintf('频率偏差%dHz解调\nBER = %.2e', freq_offset, ber_freq_offset), 'FontSize', 11);
% 子图3：相位偏差载波解调星座图
subplot(1,3,3);
if length(rx_phase_offset) >= show_points
scatter(real(rx_phase_offset(1:show_points)), imag(rx_phase_offset(1:show_points)), ...
15, [0.5 0 0.5], 'filled', 'MarkerFaceAlpha', 0.6);
end
hold on;
scatter(real(constellation_points), imag(constellation_points), ...
100, 'r', 'x', 'LineWidth', 2);
grid on; axis equal;
xlim([-1.8 1.8]); ylim([-1.8 1.8]);
xlabel('I', 'FontSize', 10); ylabel('Q', 'FontSize', 10);
title(sprintf('相位偏差%d°解调\nBER = %.2e', phase_offset, ber_phase_offset), 'FontSize', 11);
sgtitle(sprintf('16QAM星座图对比 - 三种解调模式 (Eb/No=%d dB)', EbNo_dB), 'FontSize', 14);
end

% --- 创建频谱图 ---
function create_spectrum_plot(tx_signal, Fs, fc)
figure('Position', [100, 100, 1400, 900], 'Name', '16QAM已调信号频谱图', 'Color', 'white');
NFFT = 4096;
window = hamming(NFFT);
noverlap = floor(NFFT/2);
[pxx_tx, f_tx] = pwelch(tx_signal, window, noverlap, NFFT, Fs, 'centered');
pxx_tx_dB = 10*log10(pxx_tx);
plot(f_tx/1e6, pxx_tx_dB, 'b-', 'LineWidth', 1.5);
grid on;
xlabel('频率 (MHz)', 'FontSize', 11);
ylabel('功率谱密度 (dB/Hz)', 'FontSize', 11);
title('16QAM已调信号频谱', 'FontSize', 12);
xlim([-Fs/2e6, Fs/2e6]);
hold on;
plot([fc/1e6, fc/1e6], [min(pxx_tx_dB), max(pxx_tx_dB)], 'r--', 'LineWidth', 1);
plot([-fc/1e6, -fc/1e6], [min(pxx_tx_dB), max(pxx_tx_dB)], 'r--', 'LineWidth', 1);
legend('功率谱', '标称载波频率', 'Location', 'best');
end

fprintf('\n仿真完成！\n');

