% function P_com = Company(ef, LMP)
ef=[
    0.9365
    0.9693
    0.9690
    0.9686
    0.9696
    0.9349
    0.9083
    0.9058
    0.9044
    0.9025
    0.8997
    0.8935
    0.8957
    0.8956
    0.8980
    0.9011
    0.9046
    0.9090
    0.9110
    0.9114
    0.9107
    0.9090
    0.9077
    0.9087
  ];

LMP=[
    3.0788
    2.9002
    2.8080
    2.7651
    2.9691
    3.1375
    3.3268
    3.4342
    3.6136
    3.7239
    3.5714
    3.4111
    3.3524
    3.3850
    3.5246
    3.6713
    3.8199
    3.9582
    4.0095
    3.9426
    3.8085
    3.6185
    3.4259
    3.3048]*100;
    
    yalmip('clear'); % 清除YALMIP的内部缓存，保证模型纯净

%% 1. 企业模型

T = 24; % 优化时间跨度为24小时
MAX_TOTAL_POWER = 55; % 新增：企业总功率上限 (MW)

PRODUCTION = 5000; % 最终产品仓库的最低库存要求 (吨)

% 煤消耗
EF1 = 0.83*200*0.99*0.60413*44*1000/0.85/22867/12;  % 生料磨
EF2 = 0.8*44*1000/0.85/22867/12;                    % 回转窑
EF3 = 2450*1000*0.60413*0.99*44/0.85/22867/12;      % 热风炉

    % 碳排放与成本参数
    ef_pro = 0.53; % t-CO2 / t-熟料 (来自工艺过程)
    ef_coal = 2.5;     % t-CO2 / t-煤
    c_CO2_1 = 40;   % 元/吨，第一档价格
    c_CO2_2 = 60;   % 元/吨，第二档价格
    CO2_1 = 100;  % 吨，第一档的排放量上限

% 生产流程图定义
end_nodes_data = {
        '原料破碎', '料堆'; 
        '料堆', '运输'; 
        '运输', '原料仓库'; 
        '原料仓库', '生料研磨';
        '煤炭仓库', '生料研磨'; 
        '生料研磨', '生料仓库';
        '生料仓库', '预热'; 
        '预热', '熟料煅烧'; 
        '煤炭仓库', '熟料煅烧'; 
        '熟料煅烧', '冷却'; 
        '冷却', '熟料仓库'; 
        '熟料仓库', '熟料研磨';
        '熟料研磨', '水泥仓库'; 
        '水泥仓库', '成品包装'; 
        '成品包装', '产品仓库'
    };
weights = [ 0.92; 1; 1; 1; 0.83; 0.95; 1; 1; 3000/0.85/22867; 1; 0.97; 1; 0.97; 1; 1 ];

NodeTable = table( ...
        {'原料破碎'; '料堆'; '运输'; '原料仓库'; '煤炭仓库'; '生料研磨'; '生料仓库'; '预热'; '熟料煅烧'; '冷却'; '熟料仓库'; '熟料研磨'; '水泥仓库'; '成品包装'; '产品仓库'}, ...
        {'可控工序'; '物料储库'; '可控工序'; '物料储库'; '物料储库'; '可控工序'; '物料储库'; '不可控工序'; '不可控工序'; '不可控工序'; '物料储库'; '可控工序'; '物料储库'; '可控工序'; '物料储库'}, ...
        'VariableNames', {'Name', 'Type'} ...
    );

% 工序
process = {'原料破碎'; '运输'; '生料研磨'; '预热'; '熟料煅烧'; '冷却'; '熟料研磨'; '成品包装'};
% 仓储
storage = {'料堆'; '原料仓库'; '煤炭仓库'; '生料仓库'; '熟料仓库'; '水泥仓库'; '产品仓库'};

EdgeTable = table(end_nodes_data, weights, 'VariableNames', {'EndNodes', 'Weight'});
G = digraph(EdgeTable, NodeTable);
A = adjacency(G, 'weighted');
    
all_nodes = G.Nodes.Name;
num_proc = length(process);
num_stor = length(storage);

idx_proc = cellfun(@(x) find(strcmp(all_nodes, x)), process);
idx_stor = cellfun(@(x) find(strcmp(all_nodes, x)), storage);
%% 3. YALMIP决策变量定义
    M1=sdpvar(1, T, 'full');% 原料破碎处理量 (吨/小时)
    M2=sdpvar(1, T, 'full');% 运输处理量 (吨/小时)
    M3=sdpvar(1, T, 'full');% 生料研磨处理量 (吨/小时)
    M4=sdpvar(1, T, 'full');% 预热处理量 (吨/小时)
    M5=sdpvar(1, T, 'full');% 熟料煅烧处理量 (吨/小时)
    M6=sdpvar(1, T, 'full');% 冷却处理量 (吨/小时)
    M7=sdpvar(1, T, 'full');% 熟料磨处理量 (吨/小时)
    M8=sdpvar(1, T, 'full');% 成品包装
  
    S1=sdpvar(1, T, 'full');% 
    S2=sdpvar(1, T, 'full');% 
    S3=sdpvar(1, T, 'full');% 
    S4=sdpvar(1, T, 'full');% 
    S5=sdpvar(1, T, 'full');% 
    S6=sdpvar(1, T, 'full');% 
    S8=sdpvar(1, T, 'full');% 
Mflow = [
    M1;    % 1 原料破碎
    S1;    % 2 料堆
    M2;    % 3 运输
    S2;    % 4 原料仓库
    S4;    % 5 煤炭仓库
    M3;    % 6 生料研磨
    S3;    % 7 生料仓库
    M4;    % 8 预热（不可控）
    M5;    % 9 熟料煅烧（不可控）
    M6;    % 10 冷却（不可控）
    S5;    % 11 熟料仓库
    M7;    % 12 熟料研磨
    S6;    % 13 水泥仓库
    M8;    % 14 成品包装
    S8;    % 15 产品仓库
];
M = [M1; M2; M3; M4; M5; M6; M7; M8];
S = [S1; S2; S3; S4; S5; S6; S8];

    S_storage = sdpvar(num_stor, T, 'full'); % 仓库库存水平 (吨)
    P_proc = sdpvar(num_proc, T, 'full');    % 工序电力消耗 (MW)
    C_proc = sdpvar(1, T, 'full');    % 工序煤炭消耗量 (吨/小时)
    
    CO2_emission = sdpvar(1, T, 'full');     % 总碳排放量 (吨)
    CO2_bin1 = sdpvar(1, T, 'full');         % 第一档碳排放量
    CO2_bin2 = sdpvar(1, T, 'full');         % 第二档碳排放量
    is_in_bin2 = binvar(1, T, 'full');       % 是否进入第二档的标志

%% 基础参数定义
% 各工序最大功率
P_max = repmat([2; 4; 15; 0.38; 6.1; 1.52; 18; 3.2],1,T);
P_min = repmat([0; 0; 0; 0; 0], 1 ,T);
%仓库水平约束，仓库初始值
S_initial = [1200; 1200; 500; 800; 800; 1000; 0];
S_max = [100000; 8000; 8000; 8000; 8000; 8000; 8000];
S_min = [0; 0; 0; 0; 0; 0; 0];
%% 约束
 Constraints=[];
    M_big = 1e6;

 Constraints = [Constraints, Mflow >= 0];
 Constraints = [Constraints, S_storage(num_stor,T) >= 5000];
 for t = 1:T
    Constraints = [Constraints, P_proc(1,t) == ((1/(3.14*165*0.22))^2*M1(t)^2 + (2/12.5 + 0.2)*M1(t) + 200 + 311)/1000];
    Constraints = [Constraints, P_proc(2,t) == M2(t)*3600*4*0.03*0.01*42/180/1000];
    Constraints = [Constraints, P_proc(3,t) == (1.8 * M3(t)+M3(t)/6+0.5*M3(t)+1400)/1000]; % 临时线性替代 x^1.5
    Constraints = [Constraints, P_proc(4,t) == 380/1000];
    Constraints = [Constraints, P_proc(5,t) == 6100/1000];
    Constraints = [Constraints, P_proc(6,t) == 1520/1000];
    Constraints = [Constraints, P_proc(7,t) == (40*3.14 + 9.8*5.05*M7(t))/1000];
    Constraints = [Constraints, P_proc(8,t) == 0.8 * M8(t)/1000]; 
    Constraints = [Constraints, C_proc(t) == EF1*M3(t) + EF2*M5(t) + EF3*M5(t)];
    Inflow = A'*Mflow(:,t);
    %Constraints = [Constraints, (eye(15)-A)*Mflow(:,t)==0]; % 物料平衡约束
    %Constraints = [Constraints, S_min <= S_storage(:,t) <= S_max];
    %Constraints = [Constraints, S_storage(:,t) == S_initial + S_ac]; % 仓库库存平衡
    Constraints = [Constraints, Inflow(idx_proc) == Mflow(idx_proc, t)];
    Constraints = [Constraints, zeros(8,1) <= P_proc(:,t) <= P_max(:,t)]; 
    if t == 1
        Constraints = [Constraints, S_storage(:, t) == S_initial + Inflow(idx_stor) - Mflow(idx_stor, t)];
    else
        Constraints = [Constraints, S_storage(:, t) == S_storage(:, t-1) + Inflow(idx_stor) - Mflow(idx_stor, t)];
    end
    Constraints = [Constraints, S_min <= S_storage(:,t) <= S_max];
    
    
    Constraints = [Constraints, CO2_bin1(t) + CO2_bin2(t) == CO2_emission(t)];
    Constraints = [Constraints, 0 <= CO2_bin1(t) <= CO2_1];
    Constraints = [Constraints, 0 <= CO2_bin2(t)];
    Constraints = [Constraints, CO2_bin2(t) <= M_big * is_in_bin2(t)];
    Constraints = [Constraints, CO2_bin1(t) >= CO2_emission(t) - M_big * is_in_bin2(t)];
 end



%% 目标函数
Electricity_Cost = sum(LMP' .* sum(P_proc, 1));  % LMP为1×T，P_proc为num_proc×T
Carbon_Cost = sum(c_CO2_1 * CO2_bin1 + c_CO2_2 * CO2_bin2);

Objective = Electricity_Cost + Carbon_Cost;
    
    %% 6. 求解与输出 (修正后的健壮版本)
    % ---------------------------------------------------------------------
    % 将 'verbose' 设置为 1 会显示 Gurobi 的求解日志，便于调试
    ops = sdpsettings('solver', 'gurobi', 'verbose', 1);
    ops.gurobi.InfUnbdInfo = 0;
    DualReductions = 0;
    sol = optimize(Constraints, Objective, ops);
    

% end

[model,recoverymodel] = export(Constraints, Objective, sdpsettings('solver','gurobi','verbose',0));
IIS=gurobi_iis(model);
gurobi_write(model,'TestModel.lp')
