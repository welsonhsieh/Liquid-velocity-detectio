function visualizeResults(frames, positions, velocity, startFrame, roi)
    numFrames = length(frames);

    % 防護：確保 positions 長度正確
    if size(positions,1) < numFrames
        positions(numFrames,2) = NaN;
    end
    % 防護：確保 velocity 長度正確
    if length(velocity) < numFrames
        velocity(numFrames) = NaN;
    end

    % 建立 figure 與子圖
    figure;
    hAx1 = subplot(1,2,1);
    hImg = imshow(frames{startFrame}, 'Parent', hAx1);
    axis(hAx1,'image'); set(hAx1,'YDir','reverse'); hold(hAx1,'on');

    % 初始軌跡與點
    hTrail = plot(hAx1, positions(startFrame,1), positions(startFrame,2), 'r-', 'LineWidth', 2);
    hPoint = plot(hAx1, positions(startFrame,1), positions(startFrame,2), 'ro', ...
                  'MarkerSize',10, 'MarkerFaceColor','r', 'LineWidth',1.2);

    % 右側速度曲線
    hAx2 = subplot(1,2,2);
    hVel = plot(hAx2, startFrame:numFrames, nan(1,numFrames-startFrame+1), 'b-', 'LineWidth', 2);
    xlabel(hAx2, 'Frame'); ylabel(hAx2, 'Velocity (m/s)');
    title(hAx2, '流速曲線 (動態)');
    xlim(hAx2, [startFrame numFrames]);

    % 初始 y 範圍
    vvalid = velocity(~isnan(velocity));
    if isempty(vvalid)
        vmin = 0; vmax = 1;
    else
        vmin = min(vvalid); vmax = max(vvalid);
    end
    vrange = vmax - vmin;
    if vrange == 0, vrange = abs(vmax)+1; end
    ylim(hAx2, [vmin-0.5*vrange, vmax+0.5*vrange]);

    % 確認鍵
    choice = questdlg('是否開始播放結果？', ...
                      '確認', ...
                      '開始','取消','開始');
    if strcmp(choice,'取消')
        return;
    end

    


    uicontrol('Style','pushbutton','String','保存結果',...
          'Units','normalized','Position',[0.8 0.02 0.15 0.05],...
          'FontSize',11,'Callback',@(s,~) saveResults(positions, velocity));



    % 動態更新
    for i = startFrame:numFrames
        % 更新影像
        set(hImg,'CData',frames{i});
    
        % 畫 ROI 框（若有）
        if ~isempty(roi)
            rectangle('Parent', hAx1, 'Position', roi, 'EdgeColor','g', 'LineWidth',2);
        end
    
        % 更新軌跡與紅點
        set(hTrail,'XData',positions(startFrame:i,1),'YData',positions(startFrame:i,2));
        set(hPoint,'XData',positions(i,1),'YData',positions(i,2));
    
        % 更新速度曲線
        set(hVel,'XData',startFrame:i,'YData',velocity(startFrame:i));
    
        drawnow;
        pause(0.05);
    end
<<<<<<< HEAD

=======
    
>>>>>>> quickEnd
end