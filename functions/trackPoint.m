function positions = trackPoint(frames, refPoint, startFrame, roi)
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
    useDebug = false;     % 若要視覺化，設 true
    halfWidth = 20;      % local-edge 搜尋左右半寬（像素）
    cannyThresh = [0.02, 0.18];

    % debug figure
    if useDebug
        hFigDbg = figure('Name','trackPoint debug','NumberTitle','off');
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
            if x2 < x1 || y2 < y1
                sub = gray;
                x1 = 1; y1 = 1; x2 = size(gray,2); y2 = size(gray,1);
            else
                sub = gray(y1:y2, x1:x2);
            end
        else
            sub = gray;
            x1 = 1; y1 = 1; x2 = size(gray,2); y2 = size(gray,1);
        end

        chosenType = 'none';
        newPos = prevPos; % default keep

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
                maxYDelta = 50;  % 放寬一點
                mask = er >= prevY_sub & er <= prevY_sub + maxYDelta;
                er = er(mask); ec = ec(mask);
            
                if ~isempty(er)
                    ec_abs = ec + xL - 1;
            
                    % 優先取最下方一行的中間位置
                    maxY = max(er);
                    idxs = find(er == maxY);
                    xs_at_maxY = ec_abs(idxs);
            
                    if ~isempty(xs_at_maxY)
                        frontX_sub = round(mean(xs_at_maxY));
                        frontY_sub = maxY;
                    else
                        % fallback：距離上一幀最近
                        dists = hypot(double(ec_abs - prevX_sub), double(er - prevY_sub));
                        [~, sel] = min(dists);
                        frontX_sub = ec_abs(sel);
                        frontY_sub = er(sel);
                    end
            
                    fx_global = frontX_sub + xOffset;
                    fy_global = frontY_sub + yOffset;
            
                    % 邊界約束：避免超越 ROI 底部
                    if fy_global > y2 - 10
                        newPos = prevPos;
                    elseif ~isempty(roi) && (fx_global < x1 || fx_global > x2 || fy_global < y1 || fy_global > y2)
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
                    maxYDelta = 50;
                    maskY = cents(:,2) >= prevY_sub & cents(:,2) <= prevY_sub + maxYDelta;
                    cents = cents(maskY,:); validIdxSub = validIdxSub(maskY);
                    if ~isempty(validIdxSub)
                        dists = hypot(cents(:,1) - prevX_sub, cents(:,2) - prevY_sub);
                        [~, m] = min(dists);
                        candX_global = cents(m,1) + xOffset;
                        candY_global = cents(m,2) + yOffset;
                        if ~isempty(roi) && (candX_global < x1 || candX_global > x2 || candY_global < y1 || candY_global > y2)
                            newPos = prevPos;
                        else
                            newPos = limitMove(prevPos, [candX_global, candY_global], maxJump);
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
                maxYDelta = 50;
                mask = dr >= prevY_sub & dr <= prevY_sub + maxYDelta;
                dr = dr(mask); dc = dc(mask);
                if ~isempty(dr)
                    dists = hypot(double(dc - prevX_sub), double(dr - prevY_sub));
                    [~, sel] = min(dists);
                    fx_global = dc(sel) + xOffset;
                    fy_global = dr(sel) + yOffset;
                    newPos = limitMove(prevPos, [fx_global, fy_global], maxJump);
                    chosenType = 'diff';
                end
            end
        end


        % 寫入並更新 prevPos（已在 ROI 內或保留 prevPos）
        positions(i,:) = newPos;
        prevPrevPos = prevPos;
        prevPos = positions(i,:);

        % debug visualization
        if useDebug
            imshow(frame); hold on;
            rectangle('Position',[x1,y1,x2-x1,y2-y1],'EdgeColor','g','LineWidth',1.5);
            plot(prevPos(1), prevPos(2), 'yo', 'MarkerFaceColor','y');
            plot(positions(i,1), positions(i,2), 'ro', 'MarkerFaceColor','r');
            title(sprintf('Frame %d: %s chosen', i, chosenType));
            hold off; drawnow;
        end
    end

    if useDebug && exist('hFigDbg','var') && isvalid(hFigDbg)
        close(hFigDbg);
    end
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