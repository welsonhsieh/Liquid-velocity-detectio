function [refPoint, refFrameIdx, roi] = selectReferencePoint(videoFile)
    % 使用 GUI 選擇影片幀、手動挑選參考點並畫 ROI
    % 回傳:
    %   refPoint    - [x,y] (image coordinates) 或 [] 若取消
    %   refFrameIdx - frame index 或 [] 若取消
    %   roi         - [x y w h] 或 [] 若未畫 ROI

    v = VideoReader(videoFile);
    numFrames = floor(v.Duration * v.FrameRate);

    % 預設回傳值
    refPoint = [];
    refFrameIdx = [];
    roi = [];

    % 建立 GUI
    hFig = figure('Name','選擇參考點與 ROI','NumberTitle','off',...
                  'MenuBar','none','ToolBar','none','Units','pixels',...
                  'Position',[200 200 1000 600]);
    hAx  = axes('Parent', hFig, 'Units','normalized', 'Position',[0.02 0.12 0.68 0.85]);

    % 完成按鈕（只有按下才結束）
    uicontrol('Style','pushbutton','String','完成','Units','normalized',...
          'Position',[0.73 0.38 0.24 0.06],'FontSize',11,'Callback',@(s,~) finishCb());

    % 讀第一幀顯示
    try
        frame = read(v, 1);
    catch
        frame = zeros(480,640,3,'uint8'); % fallback
    end
    hImg = imshow(frame, 'Parent', hAx);
    axis(hAx,'image');
    title(hAx, '拖曳滑桿選幀，先畫 ROI（可選），再按「選擇參考點」，最後按「完成」');

    % 幀數文字
    hText = uicontrol('Style','text','Units','normalized','Position',[0.73 0.82 0.24 0.06],...
                      'String','Frame: 1','FontSize',11,'HorizontalAlignment','left');

    % --- 建立滑桿 ---
    sliderPos = [0.02 0.03 0.68 0.06];
    hSlider = uicontrol('Style','slider','Units','normalized','Position',sliderPos, ...
        'Min',1,'Max',numFrames,'Value',1, ...
        'SliderStep',[1/(max(numFrames-1,1)) min(10/(max(numFrames-1,1)),1)], ...
        'Callback',@(src,evt) sliderCallback(src));

    try
        addlistener(hSlider,'ContinuousValueChange',@(src,evt) sliderCallback(src));
    catch
    end

    % Draw ROI 按鈕
    uicontrol('Style','pushbutton','String','Draw ROI','Units','normalized',...
        'Position',[0.73 0.72 0.24 0.06],'FontSize',11,'Callback',@(s,~) drawRoiCb());

    % Clear ROI 按鈕
    uicontrol('Style','pushbutton','String','Clear ROI','Units','normalized',...
        'Position',[0.73 0.64 0.24 0.06],'FontSize',11,'Callback',@(s,~) clearRoiCb());

    % 選擇參考點按鈕
    uicontrol('Style','pushbutton','String','選擇參考點','Units','normalized',...
        'Position',[0.73 0.54 0.24 0.06],'FontSize',11,'Callback',@(s,~) pickPointCallback());

    % 取消按鈕
    uicontrol('Style','pushbutton','String','取消','Units','normalized',...
        'Position',[0.73 0.46 0.24 0.06],'FontSize',11,'Callback',@(s,~) cancelCb());

    % appdata 初始
    setappdata(hFig,'refPoint',[]);
    setappdata(hFig,'refFrameIdx',[]);
    setappdata(hFig,'roi',[]);

    % 等待使用者操作（直到按完成或取消）
    waitfor(hFig);  % 等待 figure 關閉

    % 取回結果（figure 已經關閉，但 appdata 還在）

    refPoint    = getappdata(0,'refPoint');
    refFrameIdx = getappdata(0,'refFrameIdx');
    roi         = getappdata(0,'roi');

    delete(hFig);  % 主程式最後再刪掉



    % ---------------- nested callback functions ----------------
    function sliderCallback(hSliderLocal)
        frameIdx = round(get(hSliderLocal,'Value'));
        frameIdx = max(1, min(frameIdx, numFrames));
        try
            frameLocal = read(v, frameIdx);
        catch
            frameLocal = read(v,1); frameIdx = 1;
        end
        set(hImg,'CData',frameLocal);
        set(hText,'String',sprintf('Frame: %d', frameIdx));
        axis(hAx,'image'); drawnow;
    end

    function drawRoiCb()
        axes(hAx);
        hRect = drawrectangle('Parent',hAx);
        if isempty(hRect), return; end
        pos = hRect.Position;
        imgC = get(hImg,'CData');
        imgH = size(imgC,1); imgW = size(imgC,2);
        x = max(1, round(pos(1))); y = max(1, round(pos(2)));
        x2 = min(imgW, round(x + pos(3))); y2 = min(imgH, round(y + pos(4)));
        w = max(0, x2 - x); h = max(0, y2 - y);
        if w==0 || h==0, return; end
        posClamped = [x, y, w, h];
        setappdata(hFig,'roi',posClamped);
        old = findobj(hAx,'Type','rectangle','Tag','roiRect');
        if ~isempty(old), delete(old); end
        rectangle('Position',posClamped,'EdgeColor','g','LineWidth',2,'Tag','roiRect');
    end

    function clearRoiCb()
        setappdata(hFig,'roi',[]);
        old = findobj(hAx,'Type','rectangle','Tag','roiRect');
        if ~isempty(old), delete(old); end
    end

    function pickPointCallback()
        frameIdx = round(get(hSlider,'Value'));
        frameIdx = max(1, min(frameIdx, numFrames));
        try
            frameLocal = read(v, frameIdx);
        catch
            frameLocal = read(v,1); frameIdx = 1;
        end
        axes(hAx); imshow(frameLocal,'Parent',hAx); axis(hAx,'image');
        title(hAx, sprintf('Frame %d - 請點選參考點', frameIdx));
        try
            [x,y] = ginput(1);
            if ~isempty(x)
                rp = round([x,y]);
                setappdata(hFig,'refPoint',rp);
                setappdata(hFig,'refFrameIdx',frameIdx);
                disp(['選到的參考點: ', mat2str(rp), ' frameIdx=', num2str(frameIdx)]);
                hold(hAx,'on');
                plot(hAx, rp(1), rp(2), 'ro','MarkerSize',10,'LineWidth',2);
                text(hAx, rp(1)+5, rp(2),'Ref','Color','yellow','FontSize',12);
                hold(hAx,'off');
            end
        catch
        end
    end

    function cancelCb()
        if isvalid(hFig)
            setappdata(hFig,'refPoint',[]);
            setappdata(hFig,'refFrameIdx',[]);
            setappdata(hFig,'roi',[]);
            uiresume(hFig);
            delete(hFig);
        end
    end

    function finishCb()
        if isvalid(hFig)
            setappdata(0,'refPoint',getappdata(hFig,'refPoint'));
            setappdata(0,'refFrameIdx',getappdata(hFig,'refFrameIdx'));
            setappdata(0,'roi',getappdata(hFig,'roi'));
            close(hFig);  % 關閉 figure
        end
    end




end