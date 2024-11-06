
# SureBeat by Mansi Visuals

SureBeat is a Lua-based plugin for DaVinci Resolve that helps creators sync their videos to audio by detecting transients and adding markers directly on the audio clip. By using `Aubio` for transient detection and `FFmpeg` for audio conversions, SureBeat simplifies beat-syncing workflows for DaVinci Resolve users.

## Features

- **Transient Detection**: Automatically detects audio transients and marks them on your timeline.
- **Tempo Detection**: Analyzes the tempo of audio and places markers based on BPM.
- **File Conversion**: Supports multiple audio formats (e.g., .wav, .mp3, .flac, .aac, .ogg) using `FFmpeg`.
- **Easy Integration**: Designed for DaVinci Resolve.

## Installation

1. **Download and Extract**  
   Download the SureBeat package and extract the contents. Ensure the folder structure is preserved:
   ```
   SureBeat/
   ├── SureBeat_main.luac              # Main script file
   ├── SureBeat.lua                    # Configuration file / Loadfile
   ├── Aubio/                          # Aubio binaries 
   │   ├── bin/
   │   │   ├── aubioonset
   │   │   └── aubiotempo
   │   └── lib/
   │       ├── libaubio.a
   │       ├── libaubio.dylib
   │       ├── libaubio.5.3.7.dylib
   │       ├── libaubio.5.dylib
   │       └── pkgconfig/
   │           └── aubio.pc
   ├── FFmpeg/                         # FFmpeg binaries
   │   └── bin/
   │       └── ffmpeg
   ├── LICENSE.txt                     # License file
   └── readme.md                       # README file
   ```

2. **Place SureBeat in the DaVinci Resolve Scripts Directory**  
   Move the entire `SureBeat` folder to the DaVinci Resolve Utility directory:
   ```
   /Library/Application Support/Blackmagic Design/DaVinci Resolve/Fusion/Scripts/Utility/
   ```

3. **Run SureBeat in DaVinci Resolve**  
   - Open DaVinci Resolve.
   - Navigate to **Workspace** and locate the SureBeat script under **Scripts**.
   - Run the script and follow the on-screen instructions to analyze audio and create markers.

## macOS Security Prompt for Unverified Binaries

Since SureBeat relies on external binaries (`Aubio` and `FFmpeg`) to perform transient and tempo detection as well as audio conversion, macOS may block these files as unverified. If macOS prompts you that the files cannot be verified:

1. Go to **System Preferences > Security & Privacy > General**.
2. Look for a message stating that `aubioonset`, `aubiotempo`, `libaubio`, or `ffmpeg` was blocked.
3. Click **Allow Anyway** next to the message.
4. Retry running SureBeat in DaVinci Resolve. You may be asked to confirm each binary file by selecting **Open** or **Done** when prompted.

These steps are essential to ensure SureBeat can access the necessary files.

4. **Console in DaVinci Resolve**  
   - Open DaVinci Resolve.
   - Navigate to **Workspace** and locate **Console**.
   - Here you can see more information about tasks being run in the background.
   - You can also see any errors that may occur. 
   - Please provide console output when raising an issue.

## Support

SureBeat is a passion project maintained in my free time. If you find it useful, please consider supporting further development through a donation:  
[Donate on Ko-Fi](https://ko-fi.com/surebeat)

## License

SureBeat by Mansi Visuals is proprietary software distributed for free use (see LICENSE.txt for details).

### Third-Party Licenses

SureBeat relies on the following open-source components:

- **Aubio**: Used for transient detection, licensed under the GPLv3. See [Aubio License](https://aubio.org).
- **FFmpeg**: Used for audio format support, licensed under LGPL/GPL. See [FFmpeg License](https://ffmpeg.org).

These licenses apply exclusively to their respective binaries.

## Disclaimer

SureBeat is provided “as-is” without warranty of any kind, express or implied. Mansi Visuals is not liable for any claims or damages arising from the use of this software.
