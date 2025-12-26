function positions = trackPoint(frames, refPoint, startFrame)
    % 使用光流追蹤參考點
    % 輸入：
    %   frames     - 影片影格 cell array
    %   refPoint   - 使用者選的參考點 [x, y]
    %   startFrame - 起始幀索引 (例如 160)
    %
    % 輸出：
    %   positions  - 每幀的追蹤座標 (NaN 表示未追蹤)

    numFrames = length(frames);
    positions = nan(numFrames, 2); % 預設 NaN
    
    % 初始化光流物件 (Lucas-Kanade)
    opticFlow = opticalFlowLK('NoiseThreshold',0.01);

    % 灰階影像
    prevGray = rgb2gray(frames{startFrame});
    positions(startFrame,:) = refPoint;

    % 往後追蹤
    for i = startFrame+1:numFrames
        currGray = rgb2gray(frames{i});
        flow = estimateFlow(opticFlow, currGray);

        % 取出參考點附近的光流向量
        x = round(positions(i-1,1));
        y = round(positions(i-1,2));

        if x > 0 && y > 0 && x <= size(flow.Vx,2) && y <= size(flow.Vx,1)
            dx = flow.Vx(y,x);
            dy = flow.Vy(y,x);
            positions(i,:) = positions(i-1,:) + [dx, dy];
        else
            positions(i,:) = positions(i-1,:); % 邊界外就保持前一點
        end
    end

    % （可選）往前追蹤：這裡先設為 NaN
    % for i = startFrame-1:-1:1
    %     positions(i,:) = NaN;
    % end
end