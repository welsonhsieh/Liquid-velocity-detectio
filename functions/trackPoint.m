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
    
    % 初始化追蹤器在選定幀
    tracker = vision.PointTracker('MaxBidirectionalError', 2);
    initialize(tracker, refPoint, frames{startFrame});
    positions(startFrame,:) = refPoint;
    
    % 往後追蹤
    for i = startFrame+1:numFrames
        [pos, validity] = step(tracker, frames{i});
        if validity
            positions(i,:) = pos;
        else
            positions(i,:) = positions(i-1,:); % 若失敗則保持前一點
        end
    end
    
    % （可選）往前追蹤：如果你想要從選定幀往前也追蹤
    % 需要重新初始化一個 tracker，或用反向光流
    % 這裡先簡單設為 NaN
    % for i = startFrame-1:-1:1
    %     positions(i,:) = NaN;
    % end
end