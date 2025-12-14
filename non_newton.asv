addpath('functions');   % 把副程式資料夾加入搜尋路徑
addpath('video');

% 主程式：流體流速偵測
clear; clc;

% 1. 讀取影片
videoFrames = readVideo('DJI_20251002122216_0047_D.mp4');

% 2. 選擇參考點
refPoint = selectReferencePoint(videoFrames{1});

% 3. 追蹤參考點
trackedPositions = trackPoint(videoFrames, refPoint);

% 4. 計算速度
fps = 30; % 假設影片每秒 30 幀
scale = 0.01; % 每像素對應的實際距離 (公尺/像素)
velocity = computeVelocity(trackedPositions, fps, scale);

% 5. 視覺化結果
visualizeResults(videoFrames, trackedPositions, velocity);