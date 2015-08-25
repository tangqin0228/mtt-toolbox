
close all;
clear all;
clear classes;
syms clear;
clear classes;
reset(symengine);

%%
%%% 运动模型
Swx = 100;                                                              % x轴过程噪声功率谱密度
Swy = 100;                                                              % y轴过程噪声功率谱密度
T = 0.1;                                                                % 时间采样间隔
hd_mtnmodel_x = b1model.cv(Swx,T);                                      % x轴运动模型
hd_mtnmodel_y = b1model.cv(Swy,T);                                      % y轴运动模型
hd_mtnmodel = mtnmodel.dxdy(hd_mtnmodel_x,hd_mtnmodel_y);               % 运动模型
%%% 观测模型
R = [10000,0; 0,0.0001];                                                % 观测噪声协方差阵
StateSym = hd_mtnmodel.StateSym;
hd_msmodel = msmodel.drb(R,StateSym);                                   % 观测模型
%%% 滤波器模型
hd = mttfilter.ukf(hd_mtnmodel,hd_msmodel);                             % 滤波器模型
%%% 滤波过程
Xtrue = trajectory.dxy;                                                 % 目标真实状态
Num = size(Xtrue,2);                                                    % 序列长度
[theta,rho] = cart2pol(Xtrue(1,:),Xtrue(4,:));                          % 极坐标系下真实位置
Z = [rho+randn(1,Num)*sqrt(R(1,1));theta+randn(1,Num)*sqrt(R(2,2))];    % 观测向量序列
% [Xinit, Pinit] = twopointsinit([Xtrue(1,1:2);Xtrue(4,1:2)]+randn(2,2)*100, [Swx,Swy], T, [10000,0;0,10000]);
                                                                        % 起始状态
Xinit = [Xtrue(1,1);Xtrue(2,1);Xtrue(4,1);Xtrue(5,1)];
Pinit = blkdiag(100^2,200^2,100^2,200^2);

%%
%%% 利用predict和update进行滤波
DimState = 4;
DimMeasure = 2;
NumStep = size(Xtrue,2);
Xhat1 = zeros(DimState,NumStep);
Phat1 = zeros(DimState,DimState,NumStep);
h = waitbar(0,'0%','Name','Extended Kalman Filtering Progress ...',...
            'CreateCancelBtn',...
            'setappdata(gcbf,''canceling'',1)');
setappdata(h,'canceling',0)
for kk = 1:1:NumStep
    if getappdata(h,'canceling')
        break
    end
    [XhatPre, PhatPre] = hd.predict(Xinit, Pinit);
    [Xhat, Phat] = hd.update(XhatPre, PhatPre, Z(:,kk));
    Xinit = Xhat; Pinit = Phat;
    Xhat1(:,kk) = Xhat; Phat1(:,:,kk) = Phat;
    waitbar(kk/NumStep,h,sprintf('%3.0f %%',kk*100/NumStep))
end
delete(h)

%%
%%% 利用filter进行滤波
flag = 1;
Xinit = [Xtrue(1,1);Xtrue(2,1);Xtrue(4,1);Xtrue(5,1)];
Pinit = blkdiag(100^2,200^2,100^2,200^2);
[Xhat, Phat] = hd.filter(Xinit,Pinit,Z,flag);                   % 滤波

%%
%%% 利用mcfilter进行蒙特卡洛滤波
NumMc = 2;                                                             % 蒙特卡洛仿真次数
Xinit = [Xtrue(1,1);Xtrue(2,1);Xtrue(4,1);Xtrue(5,1)];
Pinit = blkdiag(100^2,200^2,100^2,200^2);
Zmc = repmat(Z,[1,1,NumMc]);                                            % 观测
XhatMc = hd.mcfilter(Xinit,Pinit,Zmc,flag);                             % 滤波过程

%%
% save demo_ukf.mat

%%
%%% 滤波轨迹
figure(11)
[xmeasure,ymeasure] = pol2cart(Z(2,:),Z(1,:));
hold on
plot(Xtrue(1,:),Xtrue(4,:),'--k');
plot(XhatMc(1,:,1),XhatMc(3,:,1),'-k');
plot(xmeasure,ymeasure,'-.k');
hold off
axis equal, box on, grid on
legend('真实','滤波','观测')

%%
%%% 位置滤波误差
figure(21)
xx = 1:1:size(Xhat,2);
hold on
plot(xx,Xtrue(1,:)-Xhat(1,:),'-.k');
plot(xx,Xtrue(4,:)-Xhat(3,:),'-k');
hold off
xlim([0,1300])
ylim([-200,200])
box on, grid on
legend('x轴','y轴')

%%
%%% 速度滤波误差
figure(22)
hold on
plot(xx,Xtrue(2,:)-Xhat(2,:),'-.k');
plot(xx,Xtrue(5,:)-Xhat(4,:),'-k');
hold off
xlim([0,1300])
ylim([-100,100])
box on, grid on
legend('x轴','y轴')

