function [refPoint, refFrameIdx] = selectReferencePoint(videoFile)
    % 使用 GUI 選擇影片幀並手動挑選參考點
    % 回傳:
    %   refPoint    - [x,y] (image coordinates) 或 [] 若取消
    %   refFrameIdx - frame index 或 [] 若取消

    v = VideoReader(videoFile);
    numFrames = floor(v.Duration * v.FrameRate);

    % 預設回傳值（避免未定義）
    refPoint = [];
    refFrameIdx = [];

    % 建立 GUI
    hFig = figure('Name','選擇參考點','NumberTitle','off',...
                  'MenuBar','none','ToolBar','none','Units','pixels',...
                  'Position',[200 200 900 500]);
    hAx  = axes('Parent', hFig, 'Units','normalized', 'Position',[0.02 0.12 0.6 0.85]);

    % 讀第一幀顯示
    try
        frame = read(v, 1);
    catch
        frame = zeros(480,640,3,'uint8'); % fallback
    end
    hImg = imshow(frame, 'Parent', hAx);
    axis(hAx,'image');
    title(hAx, '拖曳滑桿選幀，按「選擇參考點」後在畫面點選');


    % --- 建立顯示幀數的文字（先建立） ---
    hText = uicontrol('Style','text','Units','normalized','Position',[0.65 0.03 0.12 0.06],...
    'String','Frame: 1','FontSize',10);


    % 建滑桿（以像素為單位顯示）
    sliderPos = [0.02 0.03 0.6 0.06];
    hSlider = uicontrol('Style','slider','Units','normalized','Position',sliderPos, ...
    'Min',1,'Max',numFrames,'Value',1, ...
    'SliderStep',[1/(numFrames-1) min(10/(numFrames-1),1)], ...
    'Callback',@(src,evt) sliderCallback(src, v, hImg, hAx, hText));


    % 選擇按鈕
    hButton = uicontrol('Style','pushbutton','Units','normalized','String','選擇參考點', ...
        'Position',[0.79 0.03 0.12 0.06], ...
        'Callback',@(src,evt) pickPointCallback(hSlider, v, hAx, hFig));

    % 預先設定 appdata 為空
    setappdata(hFig,'refPoint',[]);
    setappdata(hFig,'refFrameIdx',[]);

    % CloseRequest 安全處理
    set(hFig, 'CloseRequestFcn', @(src,evt) onClose(src));

    % 允許滑桿拖曳時即時更新（支援較新 MATLAB）
    try
        addlistener(hSlider,'ContinuousValueChange',@(src,evt) sliderCallback(src, v, hImg, hAx, hText));
    catch
        % 若不支援 ContinuousValueChange，滑桿仍會在放開時觸發 Callback
    end

    % 等待使用者操作
    uiwait(hFig);

    % 取回結果（若使用者關閉視窗，appdata 會是空）
    if isvalid(hFig)
        refPoint = getappdata(hFig,'refPoint');
        refFrameIdx = getappdata(hFig,'refFrameIdx');
        delete(hFig);
    else
        refPoint = [];
        refFrameIdx = [];
    end
end

%% callback: 更新影格顯示
function sliderCallback(hSlider, v, hImg, hAx, hText)
    frameIdx = round(get(hSlider,'Value'));
    frameIdx = max(1, min(frameIdx, floor(v.Duration * v.FrameRate)));
    try
        frame = read(v, frameIdx);
    catch
        % 若 read 失敗，嘗試回到第一幀
        frame = read(v,1);
    end
    set(hImg,'CData',frame);
    set(hText,'String',sprintf('Frame: %d', frameIdx));
    axis(hAx,'image');
    drawnow;
    axes(hAx); % 確保焦點在 axes，ginput 才會正確
end

%% callback: 使用者按下「選擇參考點」
function pickPointCallback(hSlider, v, hAx, hFig)
    frameIdx = round(get(hSlider,'Value'));
    frameIdx = max(1, min(frameIdx, floor(v.Duration * v.FrameRate)));
    try
        frame = read(v, frameIdx);
    catch
        frame = read(v,1);
        frameIdx = 1;
    end

    % 顯示該幀並要求使用者點選
    axes(hAx);
    imshow(frame, 'Parent', hAx);
    axis(hAx,'image');
    title(hAx, sprintf('Frame %d - 請點選參考點', frameIdx));
    drawnow;
    axes(hAx);

    % 取得點選（若使用者按 ESC 或關閉，會進入 catch）
    try
        [x,y] = ginput(1);
        refPoint = round([x,y]);
        refFrameIdx = frameIdx;

        % 標記並顯示
        hold(hAx,'on');
        plot(hAx, refPoint(1), refPoint(2), 'ro', 'MarkerSize', 10, 'LineWidth', 2);
        text(hAx, refPoint(1)+5, refPoint(2), 'Ref', 'Color', 'yellow', 'FontSize', 12);
        hold(hAx,'off');

        % 儲存到 appdata
        setappdata(hFig,'refPoint',refPoint);
        setappdata(hFig,'refFrameIdx',refFrameIdx);
    catch
        % 使用者取消或中斷，保留空值
        setappdata(hFig,'refPoint',[]);
        setappdata(hFig,'refFrameIdx',[]);
    end

    % 結束 uiwait
    if isvalid(hFig)
        uiresume(hFig);
    end
end

%% CloseRequest 安全處理
function onClose(hFig)
    if isvalid(hFig)
        setappdata(hFig,'refPoint',[]);
        setappdata(hFig,'refFrameIdx',[]);
        uiresume(hFig);
        delete(hFig);
    end
end