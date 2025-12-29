function positions = trackPoint(frames, refPoint, startFrame)
% 混合區域光流 + 前緣檢測（支援流向參數，含 debug）
% frames: cell array of RGB or grayscale images
% refPoint: [x,y] (image coordinates)
% startFrame: starting frame index
%
% 回傳 positions (numFrames x 2) 格式為 [x,y]

    % --- 可調參數 ---
    flowDirection = 'down';      % 'down' for your case
    winRadius = 15;              % 區域半徑 (2*winRadius+1)
    flowNoiseThresh = 0.01;      % 光流最小幅值 (像素/幀)，調小以更敏感
    stuckFramesThresh = 8;       % 連續幾幀不動就強制前緣檢測
    smoothAlpha = 0.25;          % 平滑係數 (0~1)
    useAdaptiveBinarize = true;  % 前緣檢測用 adaptive threshold
    enableDebug = false;         % 若要看每幀決策，設 true

    numFrames = length(frames);
    positions = nan(numFrames, 2);

    % 檢查 startFrame 合法性
    if startFrame < 1 || startFrame > numFrames
        error('startFrame 超出範圍');
    end

    % 初始化光流物件（全域更新，但只取局部）
    opticFlow = opticalFlowLK('NoiseThreshold',0.01);

    % 初始化起始位置
    positions(startFrame,:) = refPoint;
    prevPos = refPoint;
    lastMovedCount = 0;

    % 餵入起始灰階影像以初始化內部狀態
    prevGray = toGray(frames{startFrame});
    estimateFlow(opticFlow, prevGray);

    for i = startFrame+1:numFrames
        currGray = toGray(frames{i});
        flow = estimateFlow(opticFlow, currGray);

        % 影像尺寸
        [h, w] = size(currGray);

        % 若 prevPos 為 NaN，嘗試用 refPoint 或影像中心
        if any(isnan(prevPos))
            prevPos = [w/2, h/2];
        end

        % 計算局部窗口（確保在邊界內）
        x = round(prevPos(1)); y = round(prevPos(2));
        x1 = max(1, x - winRadius); x2 = min(w, x + winRadius);
        y1 = max(1, y - winRadius); y2 = min(h, y + winRadius);

        % 若窗口無效（例如單一像素），視為無光流
        if x2 < x1 || y2 < y1
            dx_med = 0; dy_med = 0; mag = 0;
        else
            localVx = flow.Vx(y1:y2, x1:x2);
            localVy = flow.Vy(y1:y2, x1:x2);
            if isempty(localVx) || isempty(localVy)
                dx_med = 0; dy_med = 0; mag = 0;
            else
                % 用中位數降低雜訊影響；若想更平滑可改 mean
                dx_med = median(localVx(:), 'omitnan');
                dy_med = median(localVy(:), 'omitnan');
                if isnan(dx_med), dx_med = 0; end
                if isnan(dy_med), dy_med = 0; end
                mag = hypot(dx_med, dy_med);
            end
        end

        usedMethod = 'none';
        if mag >= flowNoiseThresh
            % 光流可信，更新位置
            newPos = prevPos + [dx_med, dy_med];
            newPos = clampPoint(newPos, w, h);
            updatedPos = (1 - smoothAlpha) * prevPos + smoothAlpha * newPos;
            positions(i,:) = updatedPos;
            usedMethod = 'opticalFlow';
            % 判斷是否實際移動
            if hypot(updatedPos(1)-prevPos(1), updatedPos(2)-prevPos(2)) < 1e-3
                lastMovedCount = lastMovedCount + 1;
            else
                lastMovedCount = 0;
            end
        else
            % 光流不可靠 -> 用前緣檢測補位（選擇最接近 prevPos 的區域）
            frontPos = detectFrontEdge(currGray, prevPos, useAdaptiveBinarize, flowDirection);
            if ~any(isnan(frontPos))
                updatedPos = (1 - smoothAlpha) * prevPos + smoothAlpha * frontPos;
                positions(i,:) = updatedPos;
                usedMethod = 'frontEdge';
                lastMovedCount = 0;
            else
                % 兩者都失敗，保持前一點（或可設 NaN）
                positions(i,:) = prevPos;
                usedMethod = 'hold';
                lastMovedCount = lastMovedCount + 1;
            end
        end

        % 若連續多幀幾乎不動，強制用前緣檢測重新定位（不平滑）
        if lastMovedCount >= stuckFramesThresh
            frontPos = detectFrontEdge(currGray, prevPos, useAdaptiveBinarize, flowDirection);
            if ~any(isnan(frontPos))
                positions(i,:) = frontPos;
                lastMovedCount = 0;
                usedMethod = 'frontEdge_forced';
            end
        end

        prevPos = positions(i,:);

        if enableDebug
            fprintf('Frame %d: method=%s mag=%.4f pos=[%.1f,%.1f]\n', ...
                i, usedMethod, mag, prevPos(1), prevPos(2));
        end
    end

    % ---------------- helper functions ----------------
    function p = clampPoint(p, W, H)
        p(1) = min(max(p(1), 1), W);
        p(2) = min(max(p(2), 1), H);
    end

    function center = detectFrontEdge(grayImg, approxPos, adaptiveFlag, direction)
        % 回傳 [x,y] 或 [NaN,NaN]
        center = [NaN, NaN];
        try
            % 增強對比（必要時可開啟）
            % grayImg = imadjust(grayImg);

            if adaptiveFlag
                T = adaptthresh(grayImg, 0.4);
                bw = imbinarize(grayImg, T);
            else
                level = graythresh(grayImg);
                bw = imbinarize(grayImg, level);
            end

            % 形態學處理
            bw = imopen(bw, strel('disk',2));
            bw = imclose(bw, strel('disk',3));
            bw = imfill(bw, 'holes');

            cc = bwconncomp(bw);
            if cc.NumObjects == 0
                return;
            end
            stats = regionprops(cc, 'Area', 'BoundingBox', 'Centroid');

            % 選擇最接近 approxPos 的區域（避免選到遠處痕跡）
            cents = cat(1, stats.Centroid);
            dists = hypot(cents(:,1)-approxPos(1), cents(:,2)-approxPos(2));
            [~, idx] = min(dists);

            % 若最接近的區域太遠（例如超過某距離），視為失敗
            maxAcceptDist = max(size(grayImg))/2; % 寬鬆上限
            if dists(idx) > maxAcceptDist
                return;
            end

            bbox = stats(idx).BoundingBox; % [x y w h]
            switch lower(direction)
                case 'down'
                    frontX = bbox(1) + bbox(3)/2;
                    frontY = bbox(2) + bbox(4); % 底邊界
                case 'up'
                    frontX = bbox(1) + bbox(3)/2;
                    frontY = bbox(2); % 上邊界
                case 'right'
                    frontX = bbox(1) + bbox(3); % 右邊界
                    frontY = bbox(2) + bbox(4)/2;
                case 'left'
                    frontX = bbox(1); % 左邊界
                    frontY = bbox(2) + bbox(4)/2;
                otherwise
                    frontX = bbox(1) + bbox(3)/2;
                    frontY = bbox(2) + bbox(4);
            end
            center = [frontX, frontY];
        catch
            center = [NaN, NaN];
        end
    end

    function g = toGray(img)
        % 支援 RGB 或已是灰階的情況，並確保為 single/double 範圍正常
        if size(img,3) == 3
            g = rgb2gray(img);
        else
            g = img;
        end
        % 若是 double 且範圍 0..1，轉為 uint8 會影響 adaptthresh，但 opticalFlow 可接受 double
        % 這裡保持原型態，opticalFlow 與 imbinarize 都能處理 double/uint8
    end
end