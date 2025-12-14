function frames = readVideo(filename)
    % 讀取影片並輸出影格序列
    v = VideoReader(filename);
    frames = {};
    while hasFrame(v)
        frames{end+1} = readFrame(v);
    end
end