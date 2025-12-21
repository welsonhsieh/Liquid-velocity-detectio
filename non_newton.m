addpath('functions');   % 把副程式資料夾加入搜尋路徑
addpath('video');

% 主程式：流體流速偵測
clear; clc;

% ==========================================
% 1. 互動式選取影片 & 自動讀取資訊
% ==========================================

% 彈出視窗讓使用者選擇檔案
[fileName, filePath] = uigetfile({'*.mp4;*.avi;*.mov', 'Video Files (*.mp4, *.avi, *.mov)'}, '請選取要分析的影片');

% 檢查是否取消選擇
if isequal(fileName, 0)
    disp('使用者取消選擇，程式停止。');
    return;
else
    fullPath = fullfile(filePath, fileName);
    fprintf('正在處理影片: %s\n', fileName);
    
    % --- 新增功能：自動獲取 FPS ---
    vObj = VideoReader(fullPath); % 建立影片讀取物件
    fps = vObj.FrameRate;         % 直接讀取影片的幀率
    fprintf('偵測到影片幀率 (FPS): %.2f\n', fps);
    % -----------------------------

    % 讀取影片畫面 (維持原本的副程式呼叫)
    videoFrames = readVideo(fullPath);
end

% ==========================================
% 2. 選擇參考點
% ==========================================
% 顯示第一幀並讓使用者點擊
refPoint = selectReferencePoint(videoFrames{1});

% ==========================================
% 3. 追蹤參考點
% ==========================================
trackedPositions = trackPoint(videoFrames, refPoint);

% ==========================================
% 4. 計算速度
% ==========================================
% fps = 30;  <--- 這行已刪除，改用上面自動讀取的 fps 變數
scale = 0.01; % 每像素對應的實際距離 (公尺/像素)

% 確保計算時使用的是真實的 fps
velocity = computeVelocity(trackedPositions, fps, scale);

% ==========================================
% 5. 視覺化結果
% ==========================================
visualizeResults(videoFrames, trackedPositions, velocity);