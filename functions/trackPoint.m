function positions = trackPoint(frames, refPoint)
    % 使用光流追蹤參考點
    tracker = vision.PointTracker('MaxBidirectionalError', 2);
    initialize(tracker, refPoint, frames{1});
    
    positions = zeros(length(frames), 2);
    positions(1,:) = refPoint;
    
    for i = 2:length(frames)
        [pos, validity] = step(tracker, frames{i});
        if validity
            positions(i,:) = pos;
        else
            positions(i,:) = positions(i-1,:); % 若失敗則保持前一點
        end
    end
end