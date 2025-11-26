# Build Guide: Standalone PC Client

This guide explains how to package the `usb_receiver_new.py` script and `adb.exe` into a single standalone executable (`.exe`) that can be distributed to users who do not have Python installed.

## Prerequisites

1.  **Python Installed**: Ensure Python is installed on your development machine.
2.  **PyInstaller**: Install PyInstaller using pip:
    ```bash
    pip install pyinstaller
    ```
3.  **ADB Files**: You need the Android Platform Tools files in the same directory as your script:
    -   `adb.exe`
    -   `AdbWinApi.dll`
    -   `AdbWinUsbApi.dll`
    (You can find these in your Android SDK `platform-tools` folder).

## Steps to Build

1.  **Open Terminal**: Navigate to the directory containing `usb_receiver_new.py`.

2.  **Run PyInstaller Command**:
    Run the following command to create a single-file executable. This command tells PyInstaller to bundle the ADB files along with the script.

    ```bash
    pyinstaller --noconfirm --onefile --windowed --name "WebcamoReceiver" --add-data "adb.exe;." --add-data "AdbWinApi.dll;." --add-data "AdbWinUsbApi.dll;." usb_receiver_new.py
    ```

    **Explanation of flags:**
    -   `--onefile`: Packages everything into a single `.exe` file.
    -   `--windowed`: Hides the console window (optional, remove if you want to see logs).
    -   `--name "WebcamoReceiver"`: Names the output file `WebcamoReceiver.exe`.
    -   `--add-data "source;dest"`: Bundles external files. On Windows, use `;` as separator. We are adding `adb.exe` and its DLLs to the root (`.`) of the bundle.

3.  **Locate the Executable**:
    After the build completes, you will find a `dist` folder. Inside, there will be a `WebcamoReceiver.exe`.

## Distribution

-   You can now give `WebcamoReceiver.exe` to any user.
-   They do **not** need Python or ADB installed.
-   When they run it, it will automatically start the ADB reverse connection and wait for the phone to connect.

## Troubleshooting

-   **"ADB not found"**: Ensure you included the DLLs (`AdbWinApi.dll`, `AdbWinUsbApi.dll`) in the `--add-data` arguments.
-   **Console closes immediately**: If you used `--windowed` and there's an error, you won't see it. Try building without `--windowed` to debug.
