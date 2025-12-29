function positions = trackPoint(frames, ~, startFrame)
    % 前緣偵測追蹤器（不使用光流）
    % frames: cell array of RGB frames
    % startFrame: 起始幀索引
    % positions: numFrames x 2 (x,y)，NaN 表示未偵測

    numFrames = length(frames);
    positions = nan(numFrames, 2);

    for i = startFrame:numFrames
        frameGray = rgb2gray(frames{i});

        % 二值化（白色流體 vs 黑色背景）
        bw = imbinarize(frameGray, 'adaptive');

        % 找出白色區域的座標
        [rows, cols] = find(bw);

        if isempty(rows)
            positions(i,:) = [NaN, NaN];
            continue;
        end

        % 取最下方的 y（流體向下流動）
        frontY = max(rows);
        % 在該 y 的所有 x 取平均，避免雜訊
        frontX = mean(cols(rows == frontY));

        positions(i,:) = [frontX, frontY];
    end
end