-- SureBeat by Mansi Visuals (Windows Version) - Updated Version

-- Define paths to Aubio and FFmpeg binaries
local aubioonset_path = "C:\\ProgramData\\Blackmagic Design\\DaVinci Resolve\\Fusion\\Scripts\\Utility\\SureBeat\\Aubio\\bin\\aubioonset.exe"
local ffmpeg_path = "C:\\ProgramData\\Blackmagic Design\\DaVinci Resolve\\Fusion\\Scripts\\Utility\\SureBeat\\FFmpeg\\bin\\ffmpeg.exe"
local aubio_lib_path = "C:\\ProgramData\\Blackmagic Design\\DaVinci Resolve\\Fusion\\Scripts\\Utility\\SureBeat\\Aubio\\lib"
local temp_folder_path = "C:\\ProgramData\\Blackmagic Design\\DaVinci Resolve\\Fusion\\Scripts\\Utility\\SureBeat\\Temp"

-- Ensure Temp folder exists
function ensure_temp_folder()
    local folder_check_command = string.format('if not exist "%s" mkdir "%s"', temp_folder_path, temp_folder_path)
    os.execute(folder_check_command)
end

-- Function to delete Temp folder and its contents
function delete_temp_folder()
    local delete_command = string.format('rmdir /S /Q "%s"', temp_folder_path)
    os.execute(delete_command)
end

-- Ensure the Temp folder is there when the script starts
ensure_temp_folder()

-- Variables to store transient information
local transients = {}

-- Function to convert any audio file to .wav using FFmpeg
function convert_to_wav(input_path)
    local output_path = temp_folder_path .. "\\converted_audio.wav"
    local bat_file_path = temp_folder_path .. "\\convert_audio.bat"
    
    -- Create .bat file content
    local bat_content = string.format('"%s" -i "%s" -acodec pcm_s16le -ar 44100 "%s"\n', 
        ffmpeg_path, input_path, output_path)
    
    -- Write the .bat file
    local bat_file = io.open(bat_file_path, "w")
    if bat_file then
        bat_file:write(bat_content)
        bat_file:close()
        print("Created conversion .bat file:", bat_file_path)
    else
        print("Error: Unable to create .bat file for FFmpeg conversion.")
        return nil
    end
    
    -- Run the .bat file
    print("Running conversion .bat file...")
    os.execute('cmd /c "' .. bat_file_path .. '"')
    
    -- Check if the .wav file was created
    local file = io.open(output_path, "r")
    if not file then
        print("Error: .wav file could not be created. Check FFmpeg command and input file.")
        os.remove(bat_file_path)
        return nil
    end
    file:close()
    
    -- Clean up the .bat file
    os.remove(bat_file_path)
    print("Conversion completed and .bat file deleted:", output_path)

    return output_path
end

-- Function to detect transients using aubioonset without peak amplitude analysis
function detect_transients_with_aubioonset(audio_path, win)
    if not audio_path then
        print("Error: Audio path is invalid or .wav file was not created.")
        if win then
            win:GetItems().InfoDisplay:SetText("Error: Invalid audio path.")
        end
        return false
    end

    print("Starting transient detection using aubioonset with HFC method for percussive sounds")
    if win then
        win:GetItems().InfoDisplay:SetText("Analyzing transients, please wait...")
    end

    -- Define the output file path in the Temp folder
    local aubioonset_output_path = temp_folder_path .. "\\aubioonset_output.txt"
    
    -- Command to execute aubioonset and write output to file, running in a single cmd window
    local onset_command = string.format('cmd /c "set PATH=%s;%%PATH%% && "%s" -O hfc -t 0.2 -s -50 "%s" > "%s"', 
                                        aubio_lib_path, aubioonset_path, audio_path, aubioonset_output_path)
    os.execute(onset_command)

    -- Read the output file and process transients
    local onset_file = io.open(aubioonset_output_path, "r")
    if not onset_file then
        print("Error: Could not open aubioonset output file.")
        if win then
            win:GetItems().InfoDisplay:SetText("Error: Could not read aubioonset output.")
        end
        return false
    end

    transients = {}
    for line in onset_file:lines() do
        local onset_time = tonumber(line:match("([%d%.]+)"))
        if onset_time then
            table.insert(transients, { onset = onset_time })
            print(string.format("Transient detected at %.3f seconds", onset_time))
        end
    end
    onset_file:close()
    os.remove(aubioonset_output_path)

    -- Update UI with a status message if win is defined
    if win then
        win:GetItems().InfoDisplay:SetText("Analysis complete. Continue to create markers.")
    end
    print("Transient detection completed. Total transients detected:", #transients)
    
    return #transients > 0
end

-- Function to add markers based on detected transients
function add_markers(win, audio_file_name, add_transients)
    local resolve = Resolve()
    if not resolve then
        print("Error: DaVinci Resolve scripting API could not be initialized.")
        return false
    end

    local projectManager = resolve:GetProjectManager()
    local project = projectManager:GetCurrentProject()
    if not project then
        print("Error: No active project found.")
        return false
    end

    local timeline = project:GetCurrentTimeline()
    if not timeline then
        print("No active timeline found.")
        return false
    end

    local frame_rate = tonumber(timeline:GetSetting("timelineFrameRate"))
    local track_count = timeline:GetTrackCount("audio")
    local target_clip, clip_start_frame, clip_end_frame = nil, 0, 0

    for track = 1, track_count do
        for _, clip in ipairs(timeline:GetItemsInTrack("audio", track)) do
            print("Checking audio clip:", clip:GetName()) -- Debugging line
            if clip:GetName() == audio_file_name then -- Exact name matching
                target_clip = clip
                clip_start_frame = math.floor(clip:GetStart() * frame_rate)
                clip_end_frame = math.floor(clip:GetEnd() * frame_rate)
                break
            end
        end
        if target_clip then break end
    end

    if not target_clip then
        print("Failed to create markers. Could not find matching audio clip on the timeline.")
        win:GetItems().InfoDisplay:SetText("Failed to create markers. Could not find matching audio clip on the timeline.")
        return false
    end

    if add_transients then
        print("Adding transient markers to timeline...")
        for _, transient in ipairs(transients) do
            local relative_frame = math.floor(transient.onset * frame_rate)
            if clip_start_frame + relative_frame <= clip_end_frame then
                print(string.format("Adding red transient marker at frame %d (%.3f seconds)", relative_frame, transient.onset))
                target_clip:AddMarker(relative_frame, "Red", "Transient", "", 1)
            end
        end
    end

    print("Marker addition completed successfully.")
    return true
end

-- Function to list audio clips in the current timeline for debugging
function list_audio_clips_in_current_timeline()
    local resolve = Resolve()
    local projectManager = resolve:GetProjectManager()
    local project = projectManager:GetCurrentProject()
    local timeline = project:GetCurrentTimeline()
    
    print("Active Timeline Name:" .. timeline:GetName())
    print("Listing audio clips in the active timeline:")
    
    local track_count = timeline:GetTrackCount("audio")
    for track = 1, track_count do
        for _, clip in ipairs(timeline:GetItemsInTrack("audio", track)) do
            print("Audio Clip Found:", clip:GetName())
        end
    end
end

-- Main function with UI for detecting transients and creating markers
function main()
    local ui = fu.UIManager
    local disp = bmd.UIDispatcher(ui)

    local win = disp:AddWindow({
        ID = "AudioSelector",
        WindowTitle = "SureBeat by Mansi Visuals",
        Geometry = {100, 100, 800, 550},
        ui:VGroup{
            ID = "root",
            ui:Label{Text = "<b>SureBeat v0.0.2</b>", Alignment = {AlignHCenter = true}, StyleSheet = "font-size: 14px; color: white; padding-bottom: 10px;"},
            ui:Label{Text = "SureBeat helps you edit to the beat of your audio for sure!", Alignment = {AlignHCenter = true }, StyleSheet = "font-size: 16px; color: white;"},
            ui:HGroup{
                ui:Label{Text = "Audio File:", MinimumSize = {80, 30}, Alignment = {AlignRight = true}, StyleSheet = "font-size: 14px; color: white;"},
                ui:LineEdit{ID = "FilePath", Text = "No file selected", ReadOnly = true, MinimumSize = {500, 30}, StyleSheet = "font-size: 14px; color: #555; background-color: #f8f9fa; padding: 10px; border-radius: 5px;"},
                ui:Button{ID = "Browse", Text = "Browse", MinimumSize = {100, 30}, StyleSheet = "background-color: #DEC091; color: black; font-weight: bold; font-size: 14px; border-radius: 5px;"},
            },
            ui:HGroup{
                ui:CheckBox{ID = "AddTransients", Text = "Add Transient Markers (Red Markers)", Checked = true, StyleSheet = "color: white; font-size: 14px;"},
            },
            ui:HGroup{
                ui:Button{ID = "Analyze", Text = "Analyze", MinimumSize = {130, 30}, StyleSheet = "background-color: #DEC091; color: black; font-weight: bold; font-size: 14px; border-radius: 5px;"},
                ui:Button{ID = "CreateMarkers", Text = "Create Markers", MinimumSize = {130, 30}, StyleSheet = "background-color: #DEC091; color: black; font-weight: bold; font-size: 14px; border-radius: 5px;"},
            },
            ui:TextEdit{
                ID = "InfoDisplay",
                Text = "Status: Awaiting analysis.",
                ReadOnly = true,
                MinimumSize = {400, 60},
                StyleSheet = "color: #333; font-size: 14px; background-color: #f8f9fa; padding: 10px; border-radius: 5px;",
            },
            ui:Label{
                Text = "Crafted for DaVinci Resolve by Mansi Visuals with the help of ChatGPT",
                Alignment = {AlignHCenter = true},
                StyleSheet = "font-size: 16px; color: white; padding-top: 15px;",
            },
            ui:HGroup{
                ui:Button{
                    ID = "BuyCoffee", 
                    Text = "Buy Me A Coffee", 
                    MinimumSize = {130, 25}, 
                    StyleSheet = "background-color: #DEC091; color: black; font-weight: bold; font-size: 12px; border-radius: 5px;",
                }
            },
            ui:Label{
                Text = "SureBeat is a passion project and maintained in my free time, so please consider donating if you like it.",
                Alignment = {AlignHCenter = true},
                StyleSheet = "font-size: 10px; color: gray; padding-top: 5px;"
            },
        },
    })

    local audio_path = ""
    local audio_file_name = ""

    function BrowseButtonClicked()
        local file_path = fusion:RequestFile("Select Audio File", os.getenv("USERPROFILE") .. "\\Downloads", "*.wav;*.mp3")
        if file_path then
            audio_file_name = file_path:match("([^/\\]+)$") -- Adjusted for Windows paths
            win:GetItems().FilePath:SetText(audio_file_name)
            audio_path = file_path:lower():find("%.wav$") and file_path or convert_to_wav(file_path)
            if not audio_path then
                win:GetItems().InfoDisplay:SetText("Error: Failed to convert to .wav.")
            else
                win:GetItems().InfoDisplay:SetText("Selected file: " .. audio_file_name)
                print("Audio file selected:", audio_file_name)
            end
        end
    end

    function AnalyzeButtonClicked()
        if not audio_path or audio_path == "" then
            win:GetItems().InfoDisplay:SetText("Please select an audio file.")
            print("Error: No audio file selected.")
            return
        end

        print("Analyzing audio file. This may take some time depending on file length.")
        win:GetItems().InfoDisplay:SetText("Analyzing Audio... Please Wait...")
        local transients_detected = detect_transients_with_aubioonset(audio_path, win)
        win:GetItems().Analyze.Text = "Re-Analyze"
        if transients_detected then
            win:GetItems().InfoDisplay:SetText("Analysis complete. Continue to create markers.")
            print("Audio analysis completed. Transients detected:", transients_detected)
        else
            win:GetItems().InfoDisplay:SetText("Analysis failed.")
            print("Error: Analysis failed.")
        end
    end

    function CreateMarkersButtonClicked()
        if #transients == 0 then
            win:GetItems().InfoDisplay:SetText("Please analyze audio before creating markers.")
            print("Error: No analysis data to create markers.")
            return
        end

        local add_transients = win:GetItems().AddTransients.Checked
        if not add_transients then
            win:GetItems().InfoDisplay:SetText("Please select at least one marker type.")
            print("Error: No marker type selected.")
            return
        end

        print("Creating markers based on selected options...")
        win:GetItems().InfoDisplay:SetText("Creating markers...")
        if add_markers(win, audio_file_name, add_transients) then
            win:GetItems().CreateMarkers.Text = "Markers Created"
            win:GetItems().InfoDisplay:SetText("Markers created successfully.")
            print("Markers successfully created.")
        else
            win:GetItems().InfoDisplay:SetText("Failed to create markers. Could not find matching audio clip on the timeline.")
            print("Error: Failed to create markers, audio clip not found on timeline.")
        end
    end

    -- Function to open the Buy Me a Coffee link
    function OpenCoffeeLink()
        print("Opening Buy Me a Coffee link...")
        os.execute('start https://ko-fi.com/surebeat')
    end

    -- Link button actions to their respective functions
    win.On.Browse.Clicked = BrowseButtonClicked
    win.On.Analyze.Clicked = AnalyzeButtonClicked
    win.On.CreateMarkers.Clicked = CreateMarkersButtonClicked
    win.On.BuyCoffee.Clicked = OpenCoffeeLink

    -- Cleanup temp folder on UI close
    win.On[win.ID].Close = function(ev)
        print("Closing SureBeat plugin UI and cleaning up Temp folder...")
        delete_temp_folder()
        disp:ExitLoop()
    end

    win:Show()
    disp:RunLoop()
    win:Hide()
    print("SureBeat plugin terminated.")
end

-- List audio clips in the current timeline for debugging
list_audio_clips_in_current_timeline()

main()