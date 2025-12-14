function refPoint = selectReferencePoint(frame)
    % 手動選擇參考點
    imshow(frame);
    title('請用滑鼠點選流體中的參考點');
    refPoint = round(ginput(1)); % 使用者點選座標
end