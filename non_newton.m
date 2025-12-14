% 主程式：流體流速偵測與視覺化
% 作者：Your Name
% 日期：2025-12-11

%% 1. 影片讀取與預處理
videoFile = 'input.mp4'; % 輸入影片檔案
videoObj = VideoReader(videoFile);
frameRate = videoObj.FrameRate;
numFrames = floor(videoObj.Duration * frameRate);

% 讀取第一幀作為特徵點選擇依據
firstFrame = readFrame(videoObj);
grayFirst = rgb2gray(firstFrame);

%% 2. 特徵點選擇（以 Harris 角點為例）
corners = detectHarrisFeatures(grayFirst);
strongest = corners.selectStrongest(50); % 選取 50 個最強角點
points = strongest.Location;

% 可改為手動選點或其他方法
% figure; imshow(firstFrame); [x, y] = ginput(1); points = [x, y];

%% 3. 初始化 KLT 追蹤器
pointTracker = vision.PointTracker('MaxBidirectionalError', 2);
initialize(pointTracker, points, firstFrame);

% 儲存追蹤結果
trajectories = cell(size(points,1), 1);
for i = 1:size(points,1)
    trajectories{i} = points(i, :);
end

% 重設影片讀取位置
videoObj.CurrentTime = 1 / frameRate;

%% 4. 逐幀追蹤與速度計算
pixelPerMM = 10; % 假設 1 mm = 10 像素，需根據實際標定調整
allSpeeds = [];

for frameIdx = 2:numFrames
    if ~hasFrame(videoObj), break; end
    frame = readFrame(videoObj);
    [trackedPoints, validity] = pointTracker(frame);
    
    % 記錄有效點的軌跡
    for i = 1:size(points,1)
        if validity(i)
            trajectories{i}(end+1, :) = trackedPoints(i, :);
        else
            trajectories{i}(end+1, :) = [NaN, NaN];
        end
    end
    
    % 計算速度（像素/秒 -> mm/秒）
    delta = trackedPoints - points;
    speed_pixel = sqrt(sum(delta.^2, 2)) * frameRate;
    speed_mm = speed_pixel / pixelPerMM;
    allSpeeds = [allSpeeds, speed_mm];
    
    % 更新點
    points = trackedPoints;
end

%% 5. 結果視覺化
% 疊加軌跡於最後一幀
finalFrame = frame;
for i = 1:length(trajectories)
    traj = trajectories{i};
    validIdx = all(~isnan(traj), 2);
    if sum(validIdx) > 1
        finalFrame = insertShape(finalFrame, 'Line', ...
            [traj(validIdx,1), traj(validIdx,2)], 'Color', 'red', 'LineWidth', 2);
    end
end

% 疊加速度數值
for i = 1:size(points,1)
    if ~isnan(points(i,1))
        finalFrame = insertText(finalFrame, points(i,:), ...
            sprintf('%.2f mm/s', allSpeeds(i,end)), 'FontSize', 12, 'BoxColor', 'yellow');
    end
end

figure; imshow(finalFrame); title('流體特徵點軌跡與速度');

%% 6. 影片輸出（可選）
outputVideo = VideoWriter('output_with_trajectory.mp4', 'MPEG-4');
open(outputVideo);
% 逐幀疊加軌跡與速度（略，類似上面步驟）
close(outputVideo);

%% 7. 單位轉換與誤差分析（需根據標定結果補充）
% 例如：pixelPerMM = 標尺像素長度 / 實際長度（mm）

% 誤差估算可根據標定精度、追蹤點分散度等進行
