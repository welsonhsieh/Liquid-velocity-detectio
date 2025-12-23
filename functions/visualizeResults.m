function visualizeResults(frames, positions, velocity)
    % 動態視覺化結果：逐幀顯示追蹤軌跡與速度曲線
    
    numFrames = length(frames);
    
    % 建立視窗
    figure;
    
    % 左邊：影片 + 追蹤點
    hAx1 = subplot(1,2,1);
    hImg = imshow(frames{1}, 'Parent', hAx1);
    hold(hAx1, 'on');
    hTrail = plot(hAx1, positions(1,1), positions(1,2), 'r-', 'LineWidth', 2);
    hPoint = plot(hAx1, positions(1,1), positions(1,2), 'ro', 'MarkerSize', 8, 'LineWidth', 2);
    title(hAx1, '追蹤路徑 (動態)');
    
    % 右邊：速度曲線
    hAx2 = subplot(1,2,2);
    hVel = plot(hAx2, 1, velocity(1), 'b-', 'LineWidth', 2);
    xlabel(hAx2, 'Frame');
    ylabel(hAx2, 'Velocity (m/s)');
    title(hAx2, '流速曲線 (動態)');
    xlim(hAx2, [1 numFrames]);
    ylim(hAx2, [min(velocity)-0.1, max(velocity)+0.1]);
    
    % 動態更新
    for i = 2:numFrames
        % 更新影像
        set(hImg, 'CData', frames{i});
        
        % 更新軌跡與當前點
        set(hTrail, 'XData', positions(1:i,1), 'YData', positions(1:i,2));
        set(hPoint, 'XData', positions(i,1), 'YData', positions(i,2));
        
        % 更新速度曲線
        set(hVel, 'XData', 1:i, 'YData', velocity(1:i));
        
        drawnow;      % 即時刷新
        pause(0.05);  % 控制播放速度 (秒)
    end
end