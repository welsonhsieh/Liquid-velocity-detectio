function [refPoint, refFrameIdx, roi, calibData] = selectReferencePoint(videoFile)
    % 增加 calibData 回傳值，包含像素距離與物理長度比例
    v = VideoReader(videoFile);
    numFrames = floor(v.Duration * v.FrameRate);
    
    % 預設回傳值
    refPoint = []; refFrameIdx = []; roi = [];
    calibData = struct('pixelDist', [], 'physicalDist', [], 'unitPerPixel', []);
    
    hFig = figure('Name','影像標定與參考點選取','NumberTitle','off',...
                  'MenuBar','none','ToolBar','none','Units','pixels',...
                  'Position',[200 150 1100 700]);
    hAx  = axes('Parent', hFig, 'Units','normalized', 'Position',[0.05 0.15 0.65 0.75]);
    
    % --- UI 控制面板 ---
    panel = uipanel('Title','操作步驟','FontSize',10,'Position',[0.72 0.15 0.25 0.75]);
    
    % 按鈕群組
    uicontrol('Parent',panel,'Style','pushbutton','String','1. 畫 ROI (範圍)','Units','normalized',...
        'Position',[0.1 0.85 0.8 0.08],'Callback',@(s,~) drawRoiCb());
    
    uicontrol('Parent',panel,'Style','pushbutton','String','2. 標定參考長度','Units','normalized',...
        'Position',[0.1 0.72 0.8 0.08],'BackgroundColor',[1 0.9 0.8],'Callback',@(s,~) calibrateDistCb());
    
    uicontrol('Parent',panel,'Style','pushbutton','String','3. 選取參考點','Units','normalized',...
        'Position',[0.1 0.59 0.8 0.08],'Callback',@(s,~) pickPointCallback());
    
    uicontrol('Parent',panel,'Style','pushbutton','String','清除所有標註','Units','normalized',...
        'Position',[0.1 0.45 0.8 0.06],'Callback',@(s,~) clearAllCb());

    uicontrol('Parent',panel,'Style','pushbutton','String','完成並匯出','Units','normalized',...
        'Position',[0.1 0.15 0.8 0.1],'FontSize',12,'FontWeight','bold',...
        'BackgroundColor',[0.8 1 0.8],'Callback',@(s,~) uiresume(hFig));

    hText = uicontrol('Style','text','Units','normalized','Position',[0.05 0.08 0.65 0.04],...
                      'String','Frame: 1','FontSize',12);

    hSlider = uicontrol('Style','slider','Units','normalized','Position',[0.05 0.03 0.65 0.05], ...
        'Min',1,'Max',numFrames,'Value',1, ...
        'SliderStep',[1/(max(numFrames-1,1)) 10/(max(numFrames-1,1))], ...
        'Callback',@(src,~) sliderCallback());

    % 初始化影像
    frame = read(v, 1);
    hImg = imshow(frame, 'Parent', hAx);
    
    % 狀態儲存
    data = struct('refPoint',[], 'refFrameIdx',[], 'roi',[], ...
                  'calibLine',[], 'pixelDist',[], 'physicalDist',[], ...
                  'hRoi',[], 'hPt',[], 'hLine',[]);
    setappdata(hFig, 'state', data);

    uiwait(hFig);

    % --- 結束處理 ---
    if ishandle(hFig)
        st = getappdata(hFig, 'state');
        refPoint = st.refPoint;
        refFrameIdx = st.refFrameIdx;
        roi = st.roi;
        calibData.pixelDist = st.pixelDist;
        calibData.physicalDist = st.physicalDist;
        if ~isempty(st.pixelDist) && ~isempty(st.physicalDist)
            calibData.unitPerPixel = st.physicalDist / st.pixelDist;
        end
        delete(hFig);
    end

    % ---------------- Callback Functions ----------------
    
    function calibrateDistCb()
        st = getappdata(hFig, 'state');
        if ~isempty(st.hLine) && isvalid(st.hLine), delete(st.hLine); end
        
        title(hAx, '請在黑色紙板上拉出一條已知長度的線段');
        hL = drawline(hAx, 'Color', 'y', 'LineWidth', 2);
        
        % 計算像素距離
        pos = hL.Position;
        pDist = sqrt(diff(pos(:,1))^2 + diff(pos(:,2))^2);
        
        % 彈出輸入視窗
        answer = inputdlg('請輸入該線段的實際長度 (例如 50 代表 50mm):', '標定長度', [1 50], {'50'});
        
        if ~isempty(answer)
            st.physicalDist = str2double(answer{1});
            st.pixelDist = pDist;
            st.hLine = hL;
            fprintf('標定完成: %.2f 像素 = %.2f 物理單位\n', pDist, st.physicalDist);
        else
            delete(hL);
        end
        setappdata(hFig, 'state', st);
        title(hAx, '標定完成');
    end

    function drawRoiCb()
        st = getappdata(hFig, 'state');
        if ~isempty(st.hRoi) && isvalid(st.hRoi), delete(st.hRoi); end
        hR = drawrectangle(hAx, 'Color', 'g');
        st.roi = round(hR.Position);
        st.hRoi = hR;
        setappdata(hFig, 'state', st);
    end

    function pickPointCallback()
        st = getappdata(hFig, 'state');
        if ~isempty(st.hPt) && isvalid(st.hPt), delete(st.hPt); end
        title(hAx, '請點擊參考點');
        [x, y] = ginput(1);
        if ~isempty(x)
            st.refPoint = round([x, y]);
            st.refFrameIdx = round(get(hSlider, 'Value'));
            hold(hAx, 'on');
            st.hPt = plot(hAx, x, y, 'ro', 'MarkerSize', 10, 'LineWidth', 2);
            hold(hAx, 'off');
        end
        setappdata(hFig, 'state', st);
    end

    function sliderCallback()
        idx = round(get(hSlider,'Value'));
        set(hText, 'String', sprintf('Frame: %d', idx));
        try
            set(hImg, 'CData', read(v, idx));
            % 保持標註物在最上層
            st = getappdata(hFig, 'state');
            if ~isempty(st.hRoi) && isvalid(st.hRoi), uistack(st.hRoi, 'top'); end
            if ~isempty(st.hLine) && isvalid(st.hLine), uistack(st.hLine, 'top'); end
            if ~isempty(st.hPt) && isvalid(st.hPt), uistack(st.hPt, 'top'); end
        catch
        end
    end

    function clearAllCb()
        st = getappdata(hFig, 'state');
        fields = {'hRoi', 'hLine', 'hPt'};
        for i = 1:length(fields)
            if ~isempty(st.(fields{i})) && isvalid(st.(fields{i}))
                delete(st.(fields{i}));
            end
        end
        st.roi = []; st.pixelDist = []; st.physicalDist = []; st.refPoint = [];
        setappdata(hFig, 'state', st);
    end
end