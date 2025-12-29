function positions = trackPoint(frames, refPoint, startFrame)
% 前緣偵測追蹤器（ROI + 最近 blob + 預測 + 安全防護 + 可選 debug）
% frames: cell array of RGB frames
% refPoint: [x,y] 起始參考點（像素座標）
% startFrame: 起始幀索引
% 返回 positions: numFrames x 2

    % --- 基本初始化與防護 ---
    numFrames = numel(frames);
    positions = nan(numFrames, 2);

    if nargin < 3 || isempty(startFrame)
        startFrame = 1;
    end
    if startFrame < 1 || startFrame > numFrames
        error('trackPoint: startFrame 超出範圍 (%d)', startFrame);
    end

    if nargin < 2 || isempty(refPoint) || any(isnan(refPoint))
        fsize = size(frames{startFrame});
        refPoint = [round(fsize(2)/2), round(fsize(1)/2)];
        warning('trackPoint: refPoint 無效，改用影像中心 [%d,%d] 作為起始點.', refPoint(1), refPoint(2));
    end

    positions(startFrame,:) = refPoint;
    prevPos = positions(startFrame,:);
    prevPrevPos = []; % will be set after first update
    fprintf('trackPoint init: startFrame=%d refPoint=[%.1f,%.1f] numFrames=%d\n', ...
        startFrame, prevPos(1), prevPos(2), numFrames);

    % --- 參數（可調） ---
    roiRadius = 200;    % ROI 半徑（像素）
    minArea = 200;       % 最小 blob 面積（像素）
    maxArea = 1e6;      % 最大 blob 面積（像素）
    maxJump = 150;      % 最大允許跳躍距離（像素）
    bottomMargin = 5;   % 排除貼底 blob 的閾值（像素）
    bwarea_min = 50;    % bwareaopen 參數
    useDebug = true;   % 若要視覺化候選，設 true
    useEdgeFallback = true; % 若 blob 不穩定，啟用邊緣前緣偵測 fallback

    % --- 追蹤迴圈 ---
    for i = startFrame+1:numFrames
        % 確保 prevPos 有效
        if isempty(prevPos) || any(isnan(prevPos))
            lastIdx = find(~isnan(positions(:,1)), 1, 'last');
            if ~isempty(lastIdx)
                prevPos = positions(lastIdx,:);
            else
                prevPos = refPoint;
            end
        end

        frame = frames{i};
        gray = rgb2gray(frame);
        gray = imadjust(gray);                 % 增強對比
        bw = imbinarize(gray, 'adaptive');
        bw = bwareaopen(bw, bwarea_min);       % 去小雜點

        cc = bwconncomp(bw);
        if cc.NumObjects == 0
            % 若沒有 blob，嘗試邊緣前緣（若啟用）
            if useEdgeFallback
                [frontX, frontY, okEdge] = detectFrontEdge(gray);
                if okEdge
                    candX = frontX; candY = frontY;
                    positions(i,:) = limitMove(prevPos, [candX candY], maxJump);
                    prevPrevPos = prevPos;
                    prevPos = positions(i,:);
                    fprintf('Frame %d: edge fallback chosen=[%.1f,%.1f]\n', i, positions(i,1), positions(i,2));
                    continue;
                end
            end
            positions(i,:) = prevPos;
            fprintf('Frame %d: no blobs -> keep prev=[%.1f,%.1f]\n', i, prevPos(1), prevPos(2));
            continue;
        end

        stats = regionprops(cc, 'Area', 'BoundingBox', 'Centroid');
        imgH = size(gray,1);

        % 篩選合法候選（面積與非貼底）
        validIdx = [];
        for k = 1:length(stats)
            a = stats(k).Area;
            bbox = stats(k).BoundingBox; % [x y w h]
            bottomY = bbox(2) + bbox(4);
            if a >= minArea && a <= maxArea && (imgH - bottomY) > bottomMargin
                validIdx(end+1) = k; %#ok<AGROW>
            end
        end

        % 放寬條件（若全部被排除）
        if isempty(validIdx)
            for k = 1:length(stats)
                if stats(k).Area >= minArea/4
                    validIdx(end+1) = k; %#ok<AGROW>
                end
            end
        end

        if isempty(validIdx)
            % 還是沒有候選，嘗試邊緣前緣或保留 prev
            if useEdgeFallback
                [frontX, frontY, okEdge] = detectFrontEdge(gray);
                if okEdge
                    positions(i,:) = limitMove(prevPos, [frontX frontY], maxJump);
                    prevPrevPos = prevPos;
                    prevPos = positions(i,:);
                    fprintf('Frame %d: edge fallback chosen=[%.1f,%.1f]\n', i, positions(i,1), positions(i,2));
                    continue;
                end
            end
            positions(i,:) = prevPos;
            fprintf('Frame %d: no valid candidates -> keep prev=[%.1f,%.1f]\n', i, prevPos(1), prevPos(2));
            continue;
        end

        % 預測下一位置（線性外推）
        if ~isempty(prevPrevPos) && ~any(isnan(prevPrevPos))
            alpha = 1.0;
            predPos = prevPos + (prevPos - prevPrevPos) * alpha;
        else
            predPos = prevPos;
        end

        % ROI 優先：以 predPos 為中心搜尋 validIdx 中的 roiCandidates
        x0 = predPos(1); y0 = predPos(2);
        roiCandidates = [];
        for idx = validIdx
            c = stats(idx).Centroid;
            if hypot(c(1)-x0, c(2)-y0) <= roiRadius
                roiCandidates(end+1) = idx; %#ok<AGROW>
            end
        end

        % 選擇候選：先從 roiCandidates 選最近者，否則從 validIdx 選最近或最大面積
        chosenIdx = [];
        if ~isempty(roiCandidates)
            cents = cat(1, stats(roiCandidates).Centroid);
            dists = hypot(cents(:,1)-x0, cents(:,2)-y0);
            [~,m] = min(dists);
            chosenIdx = roiCandidates(m);
        else
            centsAll = cat(1, stats(validIdx).Centroid);
            if ~isempty(prevPos) && ~any(isnan(prevPos))
                distsAll = hypot(centsAll(:,1)-prevPos(1), centsAll(:,2)-prevPos(2));
                [~,m2] = min(distsAll);
                chosenIdx = validIdx(m2);
            else
                areas = arrayfun(@(s) s.Area, stats(validIdx));
                [~,m3] = max(areas);
                chosenIdx = validIdx(m3);
            end
        end

        % 從 chosenIdx 取前緣（底邊中點）
        bbox = stats(chosenIdx).BoundingBox;
        candX = bbox(1) + bbox(3)/2;
        candY = bbox(2) + bbox(4);

        % 若距離過大，嘗試選最近 candidate 或以速度限制分段移動
        distToPrev = hypot(candX - prevPos(1), candY - prevPos(2));
        if distToPrev > maxJump
            centsAll = cat(1, stats(validIdx).Centroid);
            distsAll = hypot(centsAll(:,1)-prevPos(1), centsAll(:,2)-prevPos(2));
            [minD, minIdx] = min(distsAll);
            if minD <= maxJump
                chosenIdx = validIdx(minIdx);
                bbox = stats(chosenIdx).BoundingBox;
                candX = bbox(1) + bbox(3)/2;
                candY = bbox(2) + bbox(4);
            else
                % 接受最接近的 candidate，但限制每幀最大位移為 maxJump
                % 找最接近的 candidate
                [~, closestIdxRel] = min(distsAll);
                chosenIdx = validIdx(closestIdxRel);
                bboxClosest = stats(chosenIdx).BoundingBox;
                candXraw = bboxClosest(1) + bboxClosest(3)/2;
                candYraw = bboxClosest(2) + bboxClosest(4);
                % 限制移動向量
                dx = candXraw - prevPos(1);
                dy = candYraw - prevPos(2);
                dist = hypot(dx,dy);
                if dist > 0
                    scale = min(1, maxJump / dist);
                    candX = prevPos(1) + dx * scale;
                    candY = prevPos(2) + dy * scale;
                else
                    candX = prevPos(1);
                    candY = prevPos(2);
                end
            end
        end

        % 寫入並輸出 debug
        positions(i,:) = [candX, candY];
        if ~isempty(prevPos) && ~any(isnan(prevPos))
            jumpDist = hypot(positions(i,1)-prevPos(1), positions(i,2)-prevPos(2));
            prevX = prevPos(1); prevY = prevPos(2);
        else
            jumpDist = NaN; prevX = NaN; prevY = NaN;
        end
        numCandidates = numel(validIdx);
        fprintf('Frame %d: chosen=[%.1f,%.1f] prev=[%.1f,%.1f] jump=%.1f candidates=%d\n', ...
            i, positions(i,1), positions(i,2), prevX, prevY, jumpDist, numCandidates);

        % 更新 prevPrevPos 與 prevPos
        prevPrevPos = prevPos;
        prevPos = positions(i,:);

        % 可選視覺化（debug）
        if useDebug
            imshow(frame); hold on;
            for k = validIdx
                rectangle('Position', stats(k).BoundingBox, 'EdgeColor','y');
            end
            rectangle('Position', bbox, 'EdgeColor','r', 'LineWidth',2);
            plot(prevPos(1), prevPos(2), 'ro', 'MarkerFaceColor','r');
            hold off; drawnow;
            pause(0.02);
        end
    end
end

% ---------------- helper functions ----------------
function p = limitMove(prev, cand, maxStep)
    dx = cand(1) - prev(1);
    dy = cand(2) - prev(2);
    d = hypot(dx,dy);
    if d <= maxStep || d == 0
        p = cand;
    else
        s = maxStep / d;
        p = [prev(1) + dx * s, prev(2) + dy * s];
    end
end

function [frontX, frontY, ok] = detectFrontEdge(gray)
    % 簡單邊緣前緣偵測：Canny -> 找最下方 edge row
    edges = edge(gray, 'Canny');
    edges = bwareaopen(edges, 20);
    [er, ec] = find(edges);
    if isempty(er)
        frontX = NaN; frontY = NaN; ok = false;
        return;
    end
    frontY = max(er);
    xs = ec(er == frontY);
    frontX = mean(xs);
    ok = true;
end