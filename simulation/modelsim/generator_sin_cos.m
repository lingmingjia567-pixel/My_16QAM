% 16QAM调制载波ROM初始化文件生成（sin + cos）
depth = 256;       % ROM深度（采样点数，0~2π）
width = 8;         % 数据位宽（8bit有符号数）
amplitude = 42;    % 幅值缩放（匹配原代码的round(42*sin(...))）

% ---------------------- 核心修改：指定目标路径 ----------------------
% 定义目标路径（Windows路径需用双反斜杠转义，或单正斜杠）
target_path = 'D:\Quartus13.1\altera\program\16QAM';
% 检查路径是否存在，不存在则自动创建（避免fopen因路径不存在报错）
if ~exist(target_path, 'dir')
    mkdir(target_path);
    disp(['已自动创建路径：', target_path]);
end

% ---------------------- 生成正弦波ROM文件（指定路径） ----------------------
% 拼接完整文件路径：路径 + 文件名
sin_mif_path = fullfile(target_path, 'sin.mif');
fid_sin = fopen(sin_mif_path, 'wt');  % 写入模式，覆盖原有文件
fprintf(fid_sin, 'depth = %d;\n', depth);
fprintf(fid_sin, 'width = %d;\n', width);
fprintf(fid_sin, 'address_radix = UNS;\n');  % 地址无符号数
fprintf(fid_sin, 'data_radix = DEC;\n');     % 数据十进制
fprintf(fid_sin, 'content begin\n');
for x = 1 : depth
    addr = x - 1;
    sin_val = round(amplitude * sin(2*pi*addr/depth));
    fprintf(fid_sin, '%d:%d;\n', addr, sin_val);
end
fprintf(fid_sin, 'end;\n');
fclose(fid_sin);

% ---------------------- 生成余弦波ROM文件（指定路径） ----------------------
cos_mif_path = fullfile(target_path, 'cos.mif');
fid_cos = fopen(cos_mif_path, 'wt');
fprintf(fid_cos, 'depth = %d;\n', depth);
fprintf(fid_cos, 'width = %d;\n', width);
fprintf(fid_cos, 'address_radix = UNS;\n');
fprintf(fid_cos, 'data_radix = DEC;\n');
fprintf(fid_cos, 'content begin\n');
for x = 1 : depth
    addr = x - 1;
    cos_val = round(amplitude * cos(2*pi*addr/depth));
    fprintf(fid_cos, '%d:%d;\n', addr, cos_val);
end
fprintf(fid_cos, 'end;\n');
fclose(fid_cos);

disp(['sin.mif 和 cos.mif 已生成至路径：', target_path]);

% --- 专门为 FPGA 生成轻量级 12阶 等波纹低通滤波器 ---
% 完美复刻报告参数：Fs=500kHz, Fpass=10kHz, Fstop=100kHz
d_lpf = designfilt('lowpassfir', ...
    'PassbandFrequency', 10e3, ...
    'StopbandFrequency', 100e3, ...
    'PassbandRipple', 1, ...
    'StopbandAttenuation', 80, ...
    'SampleRate', 500e3, ...
    'DesignMethod', 'equiripple');

fpga_coeffs = d_lpf.Coefficients;
fprintf('\n专供 FPGA 的等波纹低通滤波器阶数：%d\n', length(fpga_coeffs)-1);

% 写入 Shape_lpf.txt 文件中
fid = fopen('C:\Users\21503\Desktop\16\My_16QAM-main\simulation\modelsim\Shape_lpf.txt','w');
if fid == -1
    error('无法打开文件以写入滤波器系数');
end
% 按照原格式输出浮点数，Quartus FIR Compiler 会自动定点化
fprintf(fid,'%12.12f\r\n', fpga_coeffs);
fclose(fid);
fprintf('轻量级滤波系数已成功写入 Shape_lpf.txt\n');
