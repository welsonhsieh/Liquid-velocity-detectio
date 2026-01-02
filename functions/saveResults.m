function saveResults(trackedPositions, velocity)
    try
        if isempty(trackedPositions) || isempty(velocity)
            errordlg('結果尚未準備好，請稍後再試','錯誤');
            return;
        end

        [fileName, filePath] = uiputfile({'*.csv','CSV 檔案 (*.csv)'; ...
                                          '*.mat','MAT 檔案 (*.mat)'}, ...
                                          '選擇保存檔案');
        if isequal(fileName,0)
            disp('使用者取消保存。');
            return;
        end

        fullPath = fullfile(filePath, fileName);
        [~,~,ext] = fileparts(fullPath);

        switch lower(ext)
            case '.csv'
                T = table(trackedPositions(:,1), trackedPositions(:,2), velocity, ...
                          'VariableNames',{'X','Y','Velocity'});
                writetable(T, fullPath);
                msgbox(['結果已保存至 CSV: ' fullPath],'成功');

            case '.mat'
                save(fullPath, 'trackedPositions', 'velocity');
                msgbox(['結果已保存至 MAT: ' fullPath],'成功');

            otherwise
                errordlg('不支援的檔案格式','錯誤');
        end
    catch ME
        errordlg(['保存失敗: ' ME.message],'錯誤');
    end
end