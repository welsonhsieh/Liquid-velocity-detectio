%addpath('functions');   % 把副程式資料夾加入搜尋路徑

% 主程式：流體流速偵測
clear; clc;


% 1. 互動式選取影片檔案
% [檔案名, 路徑] = uigetfile({'*.mp4;*.avi;*.mov', '影片檔案 (*.mp4, *.avi, *.mov)'}, '請選擇要分析的影片');
[fileName, filePath] = uigetfile({'*.mp4;*.avi;*.mov', 'Video Files (*.mp4, *.avi, *.mov)'}, '選取影片檔案');

% 檢查使用者是否取消了選擇
if isequal(fileName, 0)
    disp('使用者取消選擇，程式停止。');
    return;
else
    fullPath = fullfile(filePath, fileName);
    fprintf('正在讀取影片: %s\n', fullPath);
    
    % 使用完整的路徑讀取影片
    videoFrames = FlowTracker.readVideo(fullPath);
end

% 2. 選擇參考點
[refPoint, refFrameIdx, roi, calibData] = FlowTracker.selectReferencePoint(fullPath);
if isempty(refPoint)
    disp('未選擇參考點或已取消。');
    return;
end




% 3. 追蹤參考點
fprintf('Main: refPoint = [%.0f, %.0f], refFrameIdx = %d\n', refPoint(1), refPoint(2), refFrameIdx);
disp(['frame size at refFrame: ', mat2str(size(videoFrames{refFrameIdx}))]);

trackedPositions = FlowTracker.trackPoint(videoFrames, refPoint, refFrameIdx, roi);

% 4. 計算速度
fps = 30;  % or from video metadata
if isempty(calibData) || isempty(calibData.unitPerPixel)
    disp('未完成標定，使用預設比例（警告：數值可能不準）。');
    scale = 0.01;              % fallback m/px
else
    scale = calibData.unitPerPixel;  % m/px
    fprintf('使用標定比例: %.6f m/px\n', scale);
end

velocity = FlowTracker.computeVelocity(trackedPositions, fps, scale);

% 5. 視覺化結果
FlowTracker.visualizeResults(videoFrames, trackedPositions, velocity, refFrameIdx, roi);