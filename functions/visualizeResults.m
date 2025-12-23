function visualizeResults(frames, positions, velocity, startFrame)
    numFrames = length(frames);
    figure;

    % 左邊影片
    hAx1 = subplot(1,2,1);
    hImg = imshow(frames{startFrame}, 'Parent', hAx1);
    hold(hAx1, 'on');
    hTrail = plot(hAx1, positions(startFrame,1), positions(startFrame,2), 'r-', 'LineWidth', 2);
    hPoint = plot(hAx1, positions(startFrame,1), positions(startFrame,2), 'ro', 'MarkerSize', 8, 'LineWidth', 2);

    % 右邊速度曲線
    hAx2 = subplot(1,2,2);
    hVel = plot(hAx2, startFrame, velocity(startFrame), 'b-', 'LineWidth', 2);
    xlabel(hAx2,'Frame'); ylabel(hAx2,'Velocity (m/s)');
    xlim(hAx2,[startFrame numFrames]);

    % 動態更新
    for i = startFrame+1:numFrames
        set(hImg,'CData',frames{i});
        set(hTrail,'XData',positions(startFrame:i,1),'YData',positions(startFrame:i,2));
        set(hPoint,'XData',positions(i,1),'YData',positions(i,2));
        set(hVel,'XData',startFrame:i,'YData',velocity(startFrame:i));
        drawnow;
        pause(0.05);
    end
end