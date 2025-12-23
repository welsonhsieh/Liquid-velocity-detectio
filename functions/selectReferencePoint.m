function [refPoint, refFrameIdx] = selectReferencePoint(videoFile)
    % 使用 GUI 選擇影片幀並手動挑選參考點
    %
    % 輸出：
    %   refPoint - [x, y]，若使用者關閉視窗或取消，回傳 []

    v = VideoReader(videoFile);
    numFrames = floor(v.Duration * v.FrameRate);

    % 建立 GUI 視窗
    hFig = figure('Name','選擇參考點','NumberTitle','off',...
                  'MenuBar','none','ToolBar','none');
    hAx  = axes('Parent', hFig);
    frame = read(v, 1);
    hImg = imshow(frame, 'Parent', hAx);
    title(hAx, '拖曳滑桿選幀，按「選擇參考點」後在畫面點選')

    % 建立滑桿
    hSlider = uicontrol('Style','slider','Min',1,'Max',numFrames,...
        'Value',1,'SliderStep',[max(1/numFrames, eps) min(10/numFrames, 1)],...
        'Position',[100 20 300 20]);

    % 顯示幀數
    hText = uicontrol('Style','text','Position',[420 20 120 20],...
        'String','Frame: 1');

    % 建立「選擇參考點」按鈕
    hButton = uicontrol('Style','pushbutton','String','選擇參考點',...
        'Position',[550 18 120 25],...
        'Callback',@(src,event) pickPoint(v, round(get(hSlider,'Value')), hAx, hFig));

    % 綁定滑桿更新事件（拖曳即時更新）
    addlistener(hSlider, 'Value', 'PostSet', @(src,event) ...
        updateFrame(round(get(hSlider,'Value')), v, hImg, hText, hAx));

    % 若使用者直接關閉視窗，避免報錯
    set(hFig, 'CloseRequestFcn', @(src, event) onClose(src));

    % 等待使用者選點
    uiwait(hFig);

    % 取回座標（可能為空）
    if isvalid(hFig)
        refPoint = getappdata(hFig, 'refPoint');
        refFrameIdx = getappdata(hFig, 'refFrameIdx');
        % 關閉 GUI
        delete(hFig);
    else
        % 視窗已被 onClose 刪除
        refPoint = [];
    end
end

function updateFrame(frameIdx, v, hImg, hText, hAx)
    % 更新顯示的影格
    frameIdx = max(1, min(frameIdx, floor(v.Duration * v.FrameRate)));
    frame = read(v, frameIdx);
    set(hImg, 'CData', frame);
    set(hText, 'String', sprintf('Frame: %d', frameIdx));

    % 把焦點設回座標軸（避免 ginput 游標消失）
    axes(hAx);
end

function pickPoint(v, frameIdx, hAx, hFig)
    % 顯示選定幀並讓使用者選點
    frameIdx = max(1, min(frameIdx, floor(v.Duration * v.FrameRate)));
    frame = read(v, frameIdx);
    axes(hAx);
    imshow(frame, 'Parent', hAx);
    title(hAx, sprintf('Frame %d - 請點選參考點', frameIdx));

    % 再次確保焦點在影像座標軸
    axes(hAx);

    try
        [x,y] = ginput(1);
    refPoint = round([x,y]);
    refFrameIdx = frameIdx; % 記錄當下幀數

        % 標記選取的點
        hold(hAx, 'on');
        plot(hAx, refPoint(1), refPoint(2), 'ro', 'MarkerSize', 10, 'LineWidth', 2);
        text(refPoint(1)+5, refPoint(2), 'Ref', 'Color', 'yellow', 'FontSize', 12, 'Parent', hAx);
        hold(hAx, 'off');

        % 儲存座標到 GUI handle
        setappdata(hFig, 'refPoint', refPoint);
        setappdata(hFig, 'refFrameIdx', frameIdx);
    catch
        % 使用者按 ESC 或視窗被打斷
        setappdata(hFig, 'refPoint', []);
        setappdata(hFig, 'refFrameIdx', []);
    end

    % 結束等待
    if isvalid(hFig)
        uiresume(hFig);
    end
end

function onClose(hFig)
    % 使用者關閉視窗時，回傳空值並安全結束
    setappdata(hFig, 'refPoint', []);
    setappdata(hFig, 'refFrameIdx', []);
    uiresume(hFig);
    delete(hFig);
end