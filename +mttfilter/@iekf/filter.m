function [Xhat, Phat, Stil, K, Ztil] = filter(obj, Xinit, Pinit, Z, flag)
% FILTER run iterated extended kalman filter with 
% input arguments
%  obj:   kalman filter object
%  Z:     measurement sequence
%  Xinit: initial state vector
%  Pinit: initial covariance matrix
% and output arguments
%  Xhat:  filtered state
%  Phat:  filtered covariance

if nargin < 4
    error('not enough input arguments');
end
if nargin == 4
    flag = 0;
end

%%% check input argument obj
if isnumeric(obj.Fx) && isnumeric(obj.Hx)
    warning('both motion model and measurement model are linear, there is no need to employ extended kalman filter')
end
if obj.MeasurementModel.Dimension~=obj.MotionModel.Dimension
    error('dimension(s) of motion model and measurement model must agree');
end
if ~isequal(obj.MotionModel.StateSym,obj.MeasurementModel.StateSym)
    error('state symbolic variables motion model and measurement model must be agree')
end

%%% check input argument Xinit
DimState = length(obj.StateSym);
if ~isvector(Xinit)
    error('first input argument must be a vector')
end
if isrow(Xinit)
    Xinit = Xinit.';
end
if length(Xinit)~=DimState
    error('size of first input argument is not appropriate')
end

%%% check input argument Pinit
if ~ismatrix(Pinit) || size(Pinit,1)~=DimState || size(Pinit,2)~=DimState
    error('size of second input argument is not appropriate')
end

%%% check input argument Z
DimMeasure = length(obj.MeasureSym);
if size(Z,1)~=DimMeasure && size(Z,2)==DimMeasure
    Z = Z.';
end
if size(Z,1)~=DimMeasure
    error('size of third input argument is not appropriate')
end

%%% 
NumIteration = obj.NumIteration;
NumStep = size(Z,2);
%%% 
Xhat = zeros(DimState,NumStep+1);
Phat = zeros(DimState,DimState,NumStep+1);
Stil = zeros(DimMeasure,DimMeasure,NumStep);
K    = zeros(DimState,DimMeasure,NumStep);
Ztil = zeros(DimMeasure,NumStep);
%%%
Xhat(:,1) = Xinit;
Phat(:,:,1) = Pinit;
%%%
if flag
    h = waitbar(0,'0%','Name','Iterated Extended Kalman Filtering Progress ...',...
                'CreateCancelBtn',...
                'setappdata(gcbf,''canceling'',1)');
    setappdata(h,'canceling',0)
end
%%% filtering steps
for kk = 1:1:NumStep
    if flag
        if getappdata(h,'canceling')
            break
        end
    end
    %%% prediction
    if isempty(obj.f)
        XhatPre = obj.Fx*Xhat(:,kk);
    elseif isa(obj.f, 'function_handle')
        XhatPre = feval(obj.f, obj, Xhat(:,kk));
    end
    
    %%% covariance prediction
    if isnumeric(obj.Fx)
        Fx = obj.Fx;
    elseif isa(obj.Fx, 'function_handle')
        Fx = feval(obj.Fx, obj, Xhat(:,kk));    
    end
    if isnumeric(obj.Fw)
        Fw = obj.Fw;
    elseif isa(obj.Fw, 'function_handle')
        Fw = feval(obj.Fw, obj, Xhat(:,kk));
    end
    if isnumeric(obj.Q)
        Q = obj.Q;
    elseif isa(obj.Q, 'function_handle')
        Q = feval(obj.Q, obj, Xhat(:,kk));
    end
    PhatPre = Fx*Phat(:,:,kk)*Fx.' + Fw*Q*Fw.';
    
    %%% iterated filtering
    XhatIte = XhatPre;
    for jj = 1:1:NumIteration
        %%% Kalman gain
        if isnumeric(obj.Hx)
            Hx = obj.Hx;
        elseif isa(obj.Hx, 'function_handle')
            Hx = feval(obj.Hx, obj, XhatIte);
        end
        if isnumeric(obj.Hv)
            Hv = obj.Hv;
        elseif isa(obj.Hv, 'function_handle')
            Hv = feval(obj.Hv, obj, XhatIte);
        end
        if isnumeric(obj.R)
            R = obj.R;
        elseif isa(obj.R, 'function_handle')
            R = feval(obj.R, obj, XhatIte);
        end
        Stil(:,:,kk) = Hx*PhatPre*Hx.' + Hv*R*Hv.';
        K(:,:,kk) = PhatPre*Hx.'/Stil(:,:,kk);
        
        %%% filtering
        if isempty(obj.h) && isnumeric(obj.Hx)
            ZPre = Hx*XhatPre + Hx*(XhatPre-XhatIte);
        elseif isa(obj.h, 'function_handle')
            ZPre = feval(obj.h, obj, XhatIte) + Hx*(XhatPre-XhatIte);
        end
        Ztil(:,kk) = Z(:,kk) - ZPre;
        XhatIte = XhatPre + K(:,:,kk)*Ztil(:,kk); 
    end
    Xhat(:,kk+1) = XhatIte;
    
    %%% covariance fitlering
    Phat(:,:,kk+1) = (eye(DimState)-K(:,:,kk)*Hx)*PhatPre*(eye(DimState)-K(:,:,kk)*Hx).' + K(:,:,kk)*R*K(:,:,kk).';
    
    if flag
        waitbar(kk/NumStep,h,sprintf('%3.0f %%',kk*100/NumStep))
    end
    
end
if flag
    delete(h)
end
Xhat = Xhat(:,2:end);
Phat = Phat(:,:,2:end);
end

