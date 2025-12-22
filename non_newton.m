addpath('functions');   % 把副程式資料夾加入搜尋路徑

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
    videoFrames = readVideo(fullPath);
end

% 2. 選擇參考點
refPoint = selectReferencePoint(fullPath);
if isempty(refPoint)
    disp('未選擇參考點或已取消。');
    return;
end

% 3. 追蹤參考點
trackedPositions = trackPoint(videoFrames, refPoint);

% 4. 計算速度
fps = 30; % 假設影片每秒 30 幀
scale = 0.01; % 每像素對應的實際距離 (公尺/像素)
velocity = computeVelocity(trackedPositions, fps, scale);

% 5. 視覺化結果
visualizeResults(videoFrames, trackedPositions, velocity);