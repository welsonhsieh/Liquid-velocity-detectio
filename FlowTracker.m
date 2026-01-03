classdef FlowTracker
    methods(Static)
        function frames = readVideo(filename)
            % 原本的 readVideo 程式碼

            % 讀取影片並輸出影格序列
            v = VideoReader(filename);
            frames = {};
            while hasFrame(v)
                frames{end+1} = readFrame(v);
            end

        end
        function [refPoint, refFrameIdx, roi, calibData] = selectReferencePoint(videoFile)
            % 原本的 selectReferencePoint 程式碼

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
            calibData = struct('pixelDist', [], 'physicalDist', [], 'unitPerPixel', []);
        
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
        
            % Draw Calibration Line 按鈕
            uicontrol('Style','pushbutton','String','Draw Calibration Line','Units','normalized',...
                'Position',[0.73 0.28 0.24 0.06],'FontSize',11,'Callback',@(s,~) drawCalibCb());
            
            % Clear Calibration 按鈕
            uicontrol('Style','pushbutton','String','Clear Calibration','Units','normalized',...
                'Position',[0.73 0.20 0.24 0.06],'FontSize',11,'Callback',@(s,~) clearCalibCb());
        
        
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
            calibData   = getappdata(0,'calibData');
        
            delete(hFig);  % 主程式最後再刪掉
        
        
        
            % ---------------- nested callback functions ----------------
            function clearCalibCb()
                setappdata(hFig,'calibData',struct('pixelDist',[], 'physicalDist',[], 'unitPerPixel',[]));
                old = findobj(hAx,'Type','images.roi.Line','Tag','calibLine');
                if ~isempty(old), delete(old); end
            end
        
            function drawCalibCb()
                % 移除舊線段
                old = findobj(hAx,'Type','images.roi.Line','Tag','calibLine');
                if ~isempty(old), delete(old); end
            
                % 畫新線段
                hL = drawline('Parent',hAx,'Color','y','LineWidth',2,'Tag','calibLine');
                if isempty(hL), return; end
            
                % 像素距離
                pos = hL.Position;
                pDist = hypot(diff(pos(:,1)), diff(pos(:,2)));
            
                % 基本防呆：零像素線段
                if pDist <= 0
                    errordlg('線段像素距離為 0，請重新標定','標定錯誤');
                    delete(hL);
                    return;
                end
            
                % 詢問單位與長度
                unitChoice = questdlg('輸入的實際長度單位是？','標定單位','mm','m','mm');
                if isempty(unitChoice)
                    delete(hL);
                    return;
                end
                answer = inputdlg(sprintf('請輸入該線段的實際長度（單位：%s）:', unitChoice), ...
                                  '標定長度', [1 50], {'50'});
                if isempty(answer)
                    delete(hL);
                    return;
                end
            
                physicalVal = str2double(answer{1});
                if ~isfinite(physicalVal) || physicalVal <= 0
                    errordlg('請輸入正數的實際長度','標定錯誤');
                    delete(hL);
                    return;
                end
            
                % 轉成公尺
                switch unitChoice
                    case 'mm'
                        physicalMeters = physicalVal / 1000;  % mm → m
                    case 'm'
                        physicalMeters = physicalVal;         % m → m
                    otherwise
                        physicalMeters = physicalVal;         % fallback
                end
            
                % 計算比例（公尺/像素）
                unitPerPixel = physicalMeters / pDist;
                if ~isfinite(unitPerPixel) || unitPerPixel <= 0
                    errordlg('比例計算失敗，請重新標定','標定錯誤');
                    delete(hL);
                    return;
                end
            
                % 保存到 figure 的 appdata
                setappdata(hFig,'calibData',struct( ...
                    'pixelDist', pDist, ...
                    'physicalDist', physicalMeters, ...     % 統一存 m
                    'unitPerPixel', unitPerPixel));         % m/pixel
            
                fprintf('標定完成: %.2f 像素 = %.6f m (%.6f m/px)\n', pDist, physicalMeters, unitPerPixel);
            end
        
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
                    setappdata(0,'calibData',getappdata(hFig,'calibData'));
                    close(hFig);  % 關閉 figure
                end
            end


        end
        function positions = trackPoint(frames, refPoint, startFrame, roi)
            % 原本的 trackPoint 程式碼

            % trackPoint 追蹤流體前緣（ROI 內偵測：edge first, blob fallback, diff fallback）
            % frames: cell array of RGB frames
            % refPoint: [x,y] 起始參考點（像素座標）
            % startFrame: 起始幀索引
            % roi: optional [x y w h] 限制搜尋區域
            % 返回 positions: numFrames x 2
        
            % --- 基本檢查與初始化 ---
            if nargin < 1 || isempty(frames)
                error('frames 必須為 cell array of images');
            end
            numFrames = numel(frames);
            positions = nan(numFrames,2);
            if nargin < 4, roi = []; end
            if nargin < 3 || isempty(startFrame), startFrame = 1; end
            startFrame = max(1, min(startFrame, numFrames));
        
            % 驗證 refPoint 與 ROI 對齊（若提供 ROI，refPoint 建議在 ROI 內）
            if nargin < 2 || isempty(refPoint) || any(isnan(refPoint))
                fsize = size(frames{startFrame});
                refPoint = [round(fsize(2)/2), round(fsize(1)/2)];
                warning('trackPoint: refPoint 無效，改用影像中心 [%d,%d]', refPoint(1), refPoint(2));
            end
            if ~isempty(roi)
                rx = roi(1); ry = roi(2); rw = roi(3); rh = roi(4);
                if refPoint(1) < rx || refPoint(1) > rx+rw || refPoint(2) < ry || refPoint(2) > ry+rh
                    error('refPoint 建議位於 ROI 內，請重新選擇參考點或調整 ROI');
                end
            end
        
            positions(startFrame,:) = refPoint;
            prevPos = refPoint;
            prevPrevPos = [];
        
            % --- 參數（可調） ---
            roiRadius = 200;    % blob fallback 搜尋半徑（仍在 ROI 內）
            minArea = 50;       % blob 最小面積
            maxJump = 20;       % 每幀最大允許移動距離（可調）
            bwarea_min = 50;    % 二值化後去小雜點
            edgeAreaThresh = 6; % 邊緣群組最小面積
            useEdgeFirst = true; % 優先使用邊緣偵測
            useDebug =true;     % 若要視覺化，設 true
            halfWidth = 20;      % local-edge 搜尋左右半寬（像素）
            cannyThresh = [0.02, 0.18];
        
            % debug figure
            if useDebug
                hFigDbg = figure('Name','trackPoint debug','NumberTitle','off');
                % fprintf('ROI = [x1=%d, y1=%d, x2=%d, y2=%d]\n', x1, y1, x2, y2);
            end
        
            % --- 主迴圈 ---
            for i = startFrame+1:numFrames
                frame = frames{i};
                if isempty(frame)
                    positions(i,:) = prevPos;
                    continue;
                end
        
                gray = rgb2gray(frame);
                gray = imadjust(gray);
                gray = imgaussfilt(gray, 0.8);
        
                % 若有 ROI，裁切子影像 sub（所有偵測都在 sub 上進行）
                if ~isempty(roi)
                    x = round(roi(1)); y = round(roi(2)); w = round(roi(3)); h = round(roi(4));
                    x1 = max(1,x); y1 = max(1,y);
                    x2 = min(size(gray,2), x + max(0,w)); y2 = min(size(gray,1), y + max(0,h));
        
                    % if useDebug
                    %     fprintf('ROI = [x1=%d, y1=%d, x2=%d, y2=%d]\n', x1, y1, x2, y2);
                    % end
        
                    if x2 < x1 || y2 < y1
                        sub = gray;
                        x1 = 1; y1 = 1; x2 = size(gray,2); y2 = size(gray,1);
                    else
                        sub = gray(y1:y2, x1:x2);
                    end
                    roiBottom = y + h;
                else
                    sub = gray;
                    x1 = 1; y1 = 1; x2 = size(gray,2); y2 = size(gray,1);
                end
        
                chosenType = 'none';
                newPos = prevPos; % default keepgit push origin main
        
        
                % --- 方法 A: 在 sub 上做 local-edge 偵測（以 prevPos 為中心） ---
                if useEdgeFirst
                    subProc = imgaussfilt(sub, 1.0);
                    subProc = adapthisteq(subProc);
                    edgesLocal = edge(subProc,'Canny',cannyThresh);
                    edgesLocal = imclose(edgesLocal, strel('line',3,0));
                    edgesLocal = bwareaopen(edgesLocal, max(1, edgeAreaThresh));
                
                    % prevPos 轉 sub 座標
                    xOffset = x1 - 1;
                    yOffset = y1 - 1;
                    prevX_sub = round(prevPos(1) - xOffset);
                    prevY_sub = round(prevPos(2) - yOffset);
                    prevX_sub = max(1, min(size(sub,2), prevX_sub));
                    prevY_sub = max(1, min(size(sub,1), prevY_sub));
                
                    % 窄欄搜尋
                    xL = max(1, prevX_sub - halfWidth);
                    xR = min(size(sub,2), prevX_sub + halfWidth);
                
                    [er, ec] = find(edgesLocal(:, xL:xR));  % er=row (y), ec=col (x) 相對 xL
                    if isempty(er)
                        % 放寬一次
                        xL2 = max(1, prevX_sub - halfWidth*2);
                        xR2 = min(size(sub,2), prevX_sub + halfWidth*2);
                        [er2, ec2] = find(edgesLocal(:, xL2:xR2));
                        er = er2; ec = ec2; xL = xL2;
                    end
                
                    if ~isempty(er)
                        % 垂直距離限制（避免跳到底）
                        maxYDelta = 100;  % 放寬一點
                        mask = er >= prevY_sub & er <= prevY_sub + maxYDelta;
                        er = er(mask); ec = ec(mask);
                    
                        if ~isempty(er)
                            ec_abs = ec + xL - 1;
                            %----------------------------------------------------
                            lambda = 0.9;  % 往下的偏好權重，越大越強
                            dists = hypot(double(ec_abs - prevX_sub), double(er - prevY_sub)) ...
                                    - lambda * double(er - prevY_sub);  % y 越大距離越小
                            [~, sel] = min(dists);
                            frontX_sub = ec_abs(sel);
                            frontY_sub = er(sel);
        
        
                            %--------------------------------------------------
                            % % 距離上一幀最近
                            % dists = hypot(double(ec_abs - prevX_sub), double(er - prevY_sub));
                            % [~, sel] = min(dists);
                            % frontX_sub = ec_abs(sel);
                            % frontY_sub = er(sel);
                            % 
                            fx_global = frontX_sub + xOffset;
                            fy_global = frontY_sub + yOffset;
        
                            % 強制在 ROI 內
                            if ~isempty(roi) && (fx_global < x1 || fx_global > x2 || fy_global < y1 || fy_global > y2)
                                newPos = prevPos;
                            else
                                newPos = limitMove(prevPos, [fx_global, fy_global], maxJump);
                                chosenType = 'edge';
                            end
        
                        end
                    end
        
                end
        
        
               % --- 方法 B: blob-based fallback 在 sub 上執行（若 edge 沒選到） ---
                if strcmp(chosenType,'none')
                    bwSub = imbinarize(sub, 'adaptive');
                    bwSub = bwareaopen(bwSub, bwarea_min);
                    ccSub = bwconncomp(bwSub);
                    if ccSub.NumObjects > 0
                        statsSub = regionprops(ccSub, 'Area','Centroid');
                        % 面積過濾
                        validIdxSub = find([statsSub.Area] >= minArea);
                        if ~isempty(validIdxSub)
                            xOffset = x1 - 1; yOffset = y1 - 1;
                            prevX_sub = prevPos(1) - xOffset;
                            prevY_sub = prevPos(2) - yOffset;
                
                            cents = cat(1, statsSub(validIdxSub).Centroid); % [x y] in sub
                            % 垂直距離限制
                            maxYDelta = 80; % 放寬一點
                            maskY = cents(:,2) >= prevY_sub & cents(:,2) <= prevY_sub + maxYDelta;
                            cents = cents(maskY,:); validIdxSub = validIdxSub(maskY);
                
                            if ~isempty(validIdxSub)
                                dists = hypot(cents(:,1) - prevX_sub, cents(:,2) - prevY_sub);
                                [~, m] = min(dists);
                                candX_global = cents(m,1) + xOffset;
                                candY_global = cents(m,2) + yOffset;
                
                                % 底部約束 + ROI 邊界檢查
                                if (~isempty(roi) && (candX_global < x1 || candX_global > x2 || candY_global < y1 || candY_global > y2)) ...
                                   || (candY_global > y2 - 10)
                                    newPos = prevPos;
                                else
                                    newPos = limitMove(prevPos, [candX_global, candY_global], maxJump);
                                    % 硬性 ROI 圍籬
                                    if ~isempty(roi)
                                        if newPos(1) < x1 || newPos(1) > x2 || newPos(2) < y1 || newPos(2) > y2
                                            newPos = prevPos;
                                        end
                                    end
                                    chosenType = 'blob';
                                end
                            end
                        end
                    end
                end
        
                % --- 方法 C: temporal-diff fallback（若 edge 與 blob 都沒選到） ---
                if strcmp(chosenType,'none') && i>1
                    prevFrame = frames{i-1};
                    diff = imabsdiff(rgb2gray(frame), rgb2gray(prevFrame));
                    diff = imgaussfilt(diff,0.8);
                    bwDiff = imbinarize(diff,'adaptive');
                    bwDiff = bwareaopen(bwDiff, 30);
                    subDiff = bwDiff(y1:y2, x1:x2);
                
                    [dr, dc] = find(subDiff);
                    if ~isempty(dr)
                        xOffset = x1 - 1; yOffset = y1 - 1;
                        prevX_sub = prevPos(1) - xOffset;
                        prevY_sub = prevPos(2) - yOffset;
                        maxYDelta = 80; % 放寬一點
                        mask = dr >= prevY_sub & dr <= prevY_sub + maxYDelta;
                        dr = dr(mask); dc = dc(mask);
                
                        if ~isempty(dr)
                            dists = hypot(double(dc - prevX_sub), double(dr - prevY_sub));
                            [~, sel] = min(dists);
                            fx_global = dc(sel) + xOffset;
                            fy_global = dr(sel) + yOffset;
                
                            % 底部約束 + ROI 邊界檢查
                            if (~isempty(roi) && (fx_global < x1 || fx_global > x2 || fy_global < y1 || fy_global > y2)) ...
                               || (fy_global > y2 - 10)
                                newPos = prevPos;
                            else
                                newPos = limitMove(prevPos, [fx_global, fy_global], maxJump);
                                % 硬性 ROI 圍籬
                                if ~isempty(roi)
                                    if newPos(1) < x1 || newPos(1) > x2 || newPos(2) < y1 || newPos(2) > y2
                                        newPos = prevPos;
                                    end
                                end
                                chosenType = 'diff';
                            end
                        end
                    end
                end
        
        
        
                % 寫入並更新 prevPos（已在 ROI 內或保留 prevPos）
                positions(i,:) = newPos;
                prevPrevPos = prevPos;
                prevPos = positions(i,:);
        
        
                fprintf('Frame %d: posY=%d, roiBottom=%d\n', i, positions(i,2), roiBottom);
                roiBottom = roi(2) + roi(4);  % ROI 底部 row
                if ~isempty(roi) && positions(i,2) >= roiBottom-1
                    fprintf('紅點已到達 ROI 底部 (frame %d)，停止追蹤。\n', i);
                    positions(i:end,:) = repmat(positions(i,:), numFrames-i+1, 1);
                    break;
                end
        
        
        
                % debug visualization
                if useDebug
                    imshow(frame); hold on;
                    rectangle('Position',[x1,y1,x2-x1,y2-y1],'EdgeColor','g','LineWidth',1.5);
                    plot(prevPos(1), prevPos(2), 'yo', 'MarkerFaceColor','y');
                    plot(positions(i,1), positions(i,2), 'ro', 'MarkerFaceColor','r');
                    title(sprintf('Frame %d: %s chosen', i, chosenType));
        
                    fprintf('ROI = [x1=%d, y1=%d, x2=%d, y2=%d]\n', x1, y1, x2, y2);
        
                    hold off; drawnow;
                end
            end
        
            if useDebug && exist('hFigDbg','var') && isvalid(hFigDbg)
                close(hFigDbg);
            end
            
        end
        function velocity = computeVelocity(positions, fps, scale)
            % 原本的 computeVelocity 程式碼

            % 計算速度 (單位：公尺/秒)
            diffs = diff(positions); % 每幀位移
            displacement = sqrt(sum(diffs.^2, 2)); % 位移量
            velocity = displacement * fps * scale;
        
            % 補齊長度，使 velocity 與 positions 對齊
            velocity = [0; velocity]; % 第一幀速度設為 0

        end
        function visualizeResults(frames, positions, velocity, startFrame, roi)
            % 原本的 visualizeResults 程式碼

            numFrames = length(frames);

            % 防護：確保 positions 長度正確
            if size(positions,1) < numFrames
                positions(numFrames,2) = NaN;
            end
            % 防護：確保 velocity 長度正確
            if length(velocity) < numFrames
                velocity(numFrames) = NaN;
            end
        
            % 建立 figure 與子圖
            figure;
            hAx1 = subplot(1,2,1);
            hImg = imshow(frames{startFrame}, 'Parent', hAx1);
            axis(hAx1,'image'); set(hAx1,'YDir','reverse'); hold(hAx1,'on');
        
            % 初始軌跡與點
            hTrail = plot(hAx1, positions(startFrame,1), positions(startFrame,2), 'r-', 'LineWidth', 2);
            hPoint = plot(hAx1, positions(startFrame,1), positions(startFrame,2), 'ro', ...
                          'MarkerSize',10, 'MarkerFaceColor','r', 'LineWidth',1.2);
        
            % 右側速度曲線
            hAx2 = subplot(1,2,2);
            hVel = plot(hAx2, startFrame:numFrames, nan(1,numFrames-startFrame+1), 'b-', 'LineWidth', 2);
            xlabel(hAx2, 'Frame'); ylabel(hAx2, 'Velocity (m/s)');
            title(hAx2, '流速曲線 (動態)');
            xlim(hAx2, [startFrame numFrames]);
        
            % 初始 y 範圍
            vvalid = velocity(~isnan(velocity));
            if isempty(vvalid)
                vmin = 0; vmax = 1;
            else
                vmin = min(vvalid); vmax = max(vvalid);
            end
            vrange = vmax - vmin;
            if vrange == 0, vrange = abs(vmax)+1; end
            ylim(hAx2, [vmin-0.5*vrange, vmax+0.5*vrange]);
        
            % 確認鍵
            choice = questdlg('是否開始播放結果？', ...
                              '確認', ...
                              '開始','取消','開始');
            if strcmp(choice,'取消')
                return;
            end
        
            
        
        
            uicontrol('Style','pushbutton','String','保存結果',...
                  'Units','normalized','Position',[0.8 0.02 0.15 0.05],...
                  'FontSize',11,'Callback',@(s,~) saveResults(positions, velocity));
        
        
        
            % 動態更新
            for i = startFrame:numFrames
                % 更新影像
                set(hImg,'CData',frames{i});
            
                % 畫 ROI 框（若有）
                if ~isempty(roi)
                    rectangle('Parent', hAx1, 'Position', roi, 'EdgeColor','g', 'LineWidth',2);
                end
            
                % 更新軌跡與紅點
                set(hTrail,'XData',positions(startFrame:i,1),'YData',positions(startFrame:i,2));
                set(hPoint,'XData',positions(i,1),'YData',positions(i,2));
            
                % 更新速度曲線
                set(hVel,'XData',startFrame:i,'YData',velocity(startFrame:i));
            
                drawnow;
                pause(0.05);
            end

        end
        
    end
end

% ---------------- helper: detectFrontEdgeLocal ----------------
function [frontX_sub, frontY_sub, ok] = detectFrontEdgeLocal(subGray, prevPosGlobal, xOffset, yOffset, halfWidth, areaThresh, cannyThresh)
% 在 subGray 上搜尋以 prevPos 為中心的 edge，回傳 sub 座標
% 只選擇距離 prevPos 下方不超過 maxYDelta 的 edge，避免直接跳到底

    ok = false; frontX_sub = NaN; frontY_sub = NaN;
    if isempty(subGray), return; end

    % 邊緣偵測
    if nargin>=7 && ~isempty(cannyThresh)
        edges = edge(subGray, 'Canny', cannyThresh);
    else
        edges = edge(subGray, 'Canny');
    end
    edges = imclose(edges, strel('line',3,0));
    edges = bwareaopen(edges, max(1, areaThresh));

    % 上一幀位置轉成 sub 座標
    prevX_sub = round(prevPosGlobal(1) - xOffset);
    prevX_sub = max(1, min(size(subGray,2), prevX_sub));
    prevY_sub = round(prevPosGlobal(2) - yOffset);
    prevY_sub = max(1, min(size(subGray,1), prevY_sub));

    % 搜尋範圍
    xL = max(1, prevX_sub - halfWidth);
    xR = min(size(subGray,2), prevX_sub + halfWidth);

    [er, ec] = find(edges(:, xL:xR));
    if isempty(er)
        % 放寬搜尋範圍
        xL2 = max(1, prevX_sub - halfWidth*2);
        xR2 = min(size(subGray,2), prevX_sub + halfWidth*2);
        [er2, ec2] = find(edges(:, xL2:xR2));
        if isempty(er2), return; end
        er = er2; ec = ec2; xL = xL2;
    end

    % 限制只選在 prevY_sub 下方不超過 maxYDelta 的 edge
    maxYDelta = 50; % 可調整
    validMask = er >= prevY_sub & er <= prevY_sub + maxYDelta;
    er = er(validMask); ec = ec(validMask);
    if isempty(er), return; end

    % 選距離 prevPos 最近的 edge
    ec_abs = ec + xL - 1;
    dists = hypot(double(ec_abs - prevX_sub), double(er - prevY_sub));
    [~, idxMin] = min(dists);
    frontX_sub = ec_abs(idxMin);
    frontY_sub = er(idxMin);

    ok = true;
end
% ---------------- helper: limitMove ----------------
function p = limitMove(prev, cand, maxStep)
    if isempty(prev) || any(isnan(prev))
        p = cand; return;
    end
    dx = cand(1) - prev(1); dy = cand(2) - prev(2);
    d = hypot(dx, dy);
    if d <= maxStep || d == 0
        p = cand;
    else
        s = maxStep / d;
        p = [prev(1) + dx * s, prev(2) + dy * s];
    end  
end
function saveResults(trackedPositions, velocity)
    try
        if isempty(trackedPositions) || isempty(velocity)
            errordlg('結果尚未準備好，請稍後再試','錯誤');
            return;
        end

        [fileName, filePath] = uiputfile({'*.csv','CSV 檔案 (*.csv)'; ...
                                          '*.mat','MAT 檔案 (*.mat)'}, ...
                                          '選擇保存檔案');
        if isequal(fileName,0)
            disp('使用者取消保存。');
            return;
        end

        fullPath = fullfile(filePath, fileName);
        [~,~,ext] = fileparts(fullPath);

        switch lower(ext)
            case '.csv'
                T = table(trackedPositions(:,1), trackedPositions(:,2), velocity, ...
                          'VariableNames',{'X','Y','Velocity'});
                writetable(T, fullPath);
                msgbox(['結果已保存至 CSV: ' fullPath],'成功');

            case '.mat'
                save(fullPath, 'trackedPositions', 'velocity');
                msgbox(['結果已保存至 MAT: ' fullPath],'成功');

            otherwise
                errordlg('不支援的檔案格式','錯誤');
        end
    catch ME
        errordlg(['保存失敗: ' ME.message],'錯誤');
    end
end