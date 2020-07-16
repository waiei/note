--[[
    SM5.3 SetNoteDataConverter (A.C@waiei) 2020/07/17
    
    StepMania5.3で使用可能なSetNoteData()の引数に渡すテーブルを作成するモジュールです。

    使い方：

    例1）ファイルから
        local converter = LoadActor('note_converter.lua')
        local player = SCREENMAN:GetTopScreen():GetChild('PlayerP1')
        -- sscファイルから#NOTES:～;の部分を抜き出したテキストファイル
        -- パスは楽曲ディレクトリからの相対パス
        local steps = converter:File('lua/note.ssc')
        player:SetNoteDataFromLua(steps)

    例2）テキストから
        local converter = LoadActor('note_converter.lua')
        local player = SCREENMAN:GetTopScreen():GetChild('PlayerP1')
        -- 「#NOTES:」と「;」は有っても無くても動作する
        local text = '#NOTES:\n0000\n0001\n0010\n0100\n,\n2002\n0000\n0000\n3003\n;'
        local steps = converter:Text(text)
        player:SetNoteDataFromLua(steps)
    
    File(),Text()ともに第2引数に適用開始位置（拍）の指定ができます。※0～
    例えば1小節あけてから譜面を設定したい場合は
    converter:Text(text, 4)
    となります。
--]]

-- ここを変えるとnITG用の変換も可能かと
local maps = {
    Note_1 = 'TapNoteType_Tap',
    Note_2 = 'TapNoteSubType_Hold',
    Note_3 = 'TapNoteType_HoldTail',
    Note_4 = 'TapNoteSubType_Roll',
    Note_M = 'TapNoteType_Mine',
    Note_L = 'TapNoteType_Lift',
    Note_F = 'TapNoteType_Fake',
}

--[[
    変換
    notes    ノートテキストデータ（空白、コメント、改行削除済み）
    columns  カラム数
--]]
local function Convert(notes, columns, offset)
    local steps   = {}
    
    -- 内容のみ取得(#NOTES:＜この部分＞;)
    notes = split(';', notes)[1]
    notes = string.find(notes, ':', 0, true) and split(':', notes)[2] or notes    -- COUPLE/VSは考慮しない
    
    -- 各カラムのロングノート状態
    local subType = {}
    for i = 1, columns do
        subType[i] = {SubType = nil, Beat = 0}
    end

    -- 小節単位でループ
    local currentBeat = 0
    local currentBar  = 0
    for note in string.gmatch(notes, '[^,]+') do
        currentBeat = currentBar * 4.0 + offset
        currentBar  = currentBar + 1
        -- 行数
        local lineCount = math.floor(string.len(note) / columns)
        -- 1行の拍数
        local beatPerLine = 4.0 / lineCount
        
        -- 1行ずつ
        for step = 1, lineCount do
            local index = (step-1)*columns + 1
            local oneLine = string.sub(note, index, index + (columns-1))
            -- 1文字ずつ(c=カラム番号)
            for c=1, string.len(oneLine) do
                local column = string.sub(oneLine, c, c)
                -- 登録可能なノート
                if maps['Note_'..column] then
                    local map = maps['Note_'..column]
                    -- ロングノートでない時のみロングノート処理
                    if subType[c]['SubType'] == nil then
                        -- ロングノートの始点
                        if column == '2' or column == '4' then
                            subType[c] = {SubType = map, Beat = currentBeat}
                        -- 通常ノート処理
                        elseif column ~= '3' then
                            steps[#steps+1] = {currentBeat, c, map}
                        end
                    -- 本来置けない配置
                    elseif column ~= '3' then
                        steps[#steps+1] = {currentBeat, c, map}
                    -- 終点時にstepに登録
                    elseif column == '3' then
                        steps[#steps+1] = {
                            subType[c]['Beat'],
                            c,
                            subType[c]['SubType'],
                            length = currentBeat - subType[c]['Beat']
                        }
                        subType[c] = {SubType = nil, Beat = 0}
                    end
                end
            end
            currentBeat = currentBeat + beatPerLine
        end
    end

    -- ソート
    table.sort(steps, function(a,b)
        return a[1] < b[1]
    end)
    
    return steps
end

--[[
    ノートデータの成型
    notes    ノートテキストデータ
    columns  カラム数
--]]
local function FormatNote(notes, columns)
    -- 空白削除
    notes = string.gsub(notes, '%s', '')
    -- // 以降はコメント
    notes = split('//', notes)[1]
    -- カラム数より多い情報はカット
    if string.len(notes) > columns and not string.find(notes, '%p') then
        notes = string.sub(notes, 1, columns)
    end
    
    return notes
end

--[[
    ファイルから作成
    path    ファイル（楽曲ディレクトリからの相対パス）
    offset  開始位置（拍数）
--]]
local function FromFile(...)
    local self, path, offset = ...
    local root = GAMESTATE:GetCurrentSong():GetSongDir()
    -- ファイルの存在確認
    if not FILEMAN:DoesFileExist(root..''..path) then
        return {}
    end
    
    -- ロード
    local file = RageFileUtil:CreateRageFile()
    file:Open(root..''..path, 1)
    
    -- プレイヤー単位のカラム数
    local columns = GAMESTATE:GetCurrentStyle():ColumnsPerPlayer()

    -- 初期位置
    local notes = ''
    local line = ''
    file:Seek(0)
    while true do
        -- 1行ずつ取得
        notes = notes..FormatNote(file:GetLine(), columns)
        
        -- 終端に到達した場合チェック終了
        if file:AtEOF() then
            break
        end
    end

    -- 閉じる
    file:Close()
    file:destroy()
    file = nil
    
    return Convert(notes, columns, offset or 0)
end

--[[
    テキストから作成
    text    ノートデータのテキスト
            例） string.gsub('0110 1001 MMMM FFFF , 2442 0000 3333 L00L', ' ', '\n')
    offset  開始位置（拍数）
--]]
local function FromText(...)
    local self, text, offset = ...
    -- プレイヤー単位のカラム数
    local columns = GAMESTATE:GetCurrentStyle():ColumnsPerPlayer()

    -- 初期位置
    local notes = ''
    for i, line in pairs(split('\n', text)) do
        -- 1行ずつ取得
        notes = notes..FormatNote(line, columns)
    end
    
    return Convert(notes, columns, offset or 0)
end

return {
    File = FromFile,
    Text = FromText,
}

--[[
    Copyright (c) 2020 A.C
    Released under the MIT license
    https://opensource.org/licenses/mit-license.php
--]]