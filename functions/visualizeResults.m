function visualizeResults(frames, positions, velocity)
    % 視覺化結果
    figure;
    subplot(1,2,1);
    imshow(frames{1});
    hold on;
    plot(positions(:,1), positions(:,2), 'r-', 'LineWidth', 2);
    title('追蹤路徑');
    
    subplot(1,2,2);
    plot(velocity, 'b-', 'LineWidth', 2);
    xlabel('Frame');
    ylabel('Velocity (m/s)');
    title('流速曲線');
end