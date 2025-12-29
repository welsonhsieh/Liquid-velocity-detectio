function velocity = computeVelocity(positions, fps, scale)
    % 計算速度 (單位：公尺/秒)
    diffs = diff(positions); % 每幀位移
    displacement = sqrt(sum(diffs.^2, 2)); % 位移量
    velocity = displacement * fps * scale;

    % 補齊長度，使 velocity 與 positions 對齊
    velocity = [0; velocity]; % 第一幀速度設為 0
end