@echo off
setlocal EnableDelayedExpansion
set iasver=2.5.3

::============================================================================
:: Coporton IDM Activation Script + Hosts Manager + File Protection
:: Modified: Added Manual Lock/Unlock Menu
::============================================================================

mode con: cols=120 lines=40
title Coporton IDM Activation Script (Activator + Registry + Hosts + Protection) v%iasver%

:: Ensure Admin Privileges
>nul 2>&1 "%SYSTEMROOT%\system32\cacls.exe" "%SYSTEMROOT%\system32\config\system"
if '%errorlevel%' NEQ '0' (
    echo Set UAC = CreateObject^("Shell.Application"^) > "%temp%\getadmin.vbs"
    echo UAC.ShellExecute "%~s0", "", "", "runas", 1 >> "%temp%\getadmin.vbs"
    "%temp%\getadmin.vbs"
    del "%temp%\getadmin.vbs"
    exit /B
)

:: Set paths
set "SCRIPT_DIR=%~dp0"
set "SRC_DIR=%SCRIPT_DIR%src\"
set "DATA_FILE=%SRC_DIR%data.bin"
set "DATAHLP_FILE=%SRC_DIR%dataHlp.bin"
set "REGISTRY_FILE=%SRC_DIR%registry.bin"
set "EXTENSIONS_FILE=%SRC_DIR%extensions.bin"
set "ascii_file=%SRC_DIR%banner_art.txt"

:: Temp files
set "tempfile_html=%temp%\idm_news.html"

:: Output colors
set "RESET=[0m"
set "GREEN=[32m"
set "RED=[31m"
set "YELLOW=[33m"
set "CYAN=[36m"

chcp 65001 >nul

:: Define the number of spaces for padding
set "padding=    "

:: Loop through each line in the ASCII art file and add spaces
if exist "%ascii_file%" (
    for /f "delims=" %%i in (%ascii_file%) do (
        echo !padding!%%i
    )
) else (
    echo.
    echo %CYAN%  IDM ACTIVATION SCRIPT + HOSTS MANAGER %RESET%
    echo.
)

:: Internet connection check
call :check_internet

:: Verify Script Version
echo Checking for script updates...

set "SCRIPT_VERSION=v%iasver%"
set "API_URL=https://api.github.com/repos/hcdbp24c3/cias/releases/latest"

curl -s "%API_URL%" -o "%temp%\latest_release.json"

:: Verify that the JSON file was downloaded correctly
if not exist "%temp%\latest_release.json" (
    echo %YELLOW% Failed to download release information. Skipping update check.%RESET%
    goto continue_script
)

:: Extract LATEST_VERSION from JSON
set "LATEST_VERSION="
for /f "tokens=2 delims=:" %%a in ('findstr /i "tag_name" "%temp%\latest_release.json"') do (
    set "line=%%a"
    set "line=!line:~2,-2!"
    for /f "delims=" %%v in ("!line!") do set "LATEST_VERSION=%%v"
)

if not defined LATEST_VERSION (
    goto continue_script
)

:: Strip 'v' prefix for numeric comparison
set "SCRIPT_VERSION_NUM=%SCRIPT_VERSION:v=%"
set "LATEST_VERSION_NUM=%LATEST_VERSION:v=%"

:: Compare Versions
call :CompareVersions "%SCRIPT_VERSION_NUM%" "%LATEST_VERSION_NUM%"

if "%is_newer%"=="1" (
    echo %GREEN% A new script version is available! %RESET%
    echo Current version: %SCRIPT_VERSION%
    echo Latest version : %LATEST_VERSION%
    goto ask_download
) else (
    echo %GREEN% Your script is up-to-date. Version: %SCRIPT_VERSION% %RESET%
    goto continue_script
)

::--------------------------
:: Version Comparison Logic
::--------------------------
:CompareVersions
setlocal EnableDelayedExpansion
set "current=%~1"
set "latest=%~2"

for /f "tokens=1-3 delims=." %%a in ("!current!") do (
    set "cur1=%%a"
    set "cur2=%%b"
    set "cur3=%%c"
)
for /f "tokens=1-3 delims=." %%a in ("!latest!") do (
    set "lat1=%%a"
    set "lat2=%%b"
    set "lat3=%%c"
)

if !lat1! GTR !cur1! (endlocal & set "is_newer=1" & exit /b)
if !lat1! LSS !cur1! (endlocal & set "is_newer=0" & exit /b)
if !lat2! GTR !cur2! (endlocal & set "is_newer=1" & exit /b)
if !lat2! LSS !cur2! (endlocal & set "is_newer=0" & exit /b)
if !lat3! GTR !cur3! (endlocal & set "is_newer=1" & exit /b)
if !lat3! LSS !cur3! (endlocal & set "is_newer=0" & exit /b)

endlocal & set "is_newer=0"
exit /b

::--------------------------
:: Ask to download new version
::--------------------------
:ask_download
echo %GREEN% ========================================================================
echo %GREEN%    :                                                                  :
echo %GREEN%    :  Do you want to download the latest version of the script?       : 
echo %GREEN%    :                        (1 = Yes / 2 = No)                        :
echo %GREEN% =======================================================================%RESET%
echo.

set "choice="
set /p choice=" Choose an option (1 = Yes / 2 = No): "

if "%choice%"=="1" (
    call :DownloadLatestScript
) else if "%choice%"=="2" (
    goto continue_script
) else (
    echo %RED% Invalid input. Please type 1 or 2 only.%RESET%
    timeout /t 2 >nul
    goto ask_download
)
goto :eof

:continue_script
echo Getting the latest version information...
curl -s "https://www.internetdownloadmanager.com/news.html" -o "%tempfile_html%"
set "online_version="

:: Find the first occurrence of the version
for /f "tokens=1* delims=<>" %%a in ('findstr /i "<H3>What's new in version" "%tempfile_html%" ^| findstr /r /c:"Build [0-9]*"') do (
    set "line=%%b"
    set "line=!line:What's new in version =!"
    set "line=!line:</H3>=!"
    set "online_version=!line!"
    goto :got_version
)

:got_version
if not defined online_version (
    echo %RED% Failed to retrieve online version. Assuming offline or check failed.%RESET%
    set "online_version=Unknown"
)

echo %GREEN% Latest online version: !online_version! %RESET%

:: Scan the online version and generate the download code
if not "!online_version!"=="Unknown" (
    for /f "tokens=1,2,4 delims=. " %%a in ("!online_version!") do (
        set "o_major=%%a"
        set "o_minor=%%b"
        set "o_build=%%c"
    )
    set "downloadcode=!o_major!!o_minor!build!o_build!"
    set "downloadurl=https://mirror2.internetdownloadmanager.com/idman%downloadcode%.exe"
) else (
    set "downloadurl=https://www.internetdownloadmanager.com/download.html"
)


:: Check installed version
echo Checking installed version...
set "installed="
for /f "tokens=3" %%a in ('reg query "HKCU\Software\DownloadManager" /v idmvers 2^>nul') do set "installed=%%a"
if not defined installed (
    for /f "tokens=3" %%a in ('reg query "HKLM\SOFTWARE\Internet Download Manager" /v Version 2^>nul') do set "installed=%%a"
)

timeout /t 1 >nul
if defined installed (
    set "installed=!installed:v=!"
    set "installed=!installed:Full=!"
    set "installed=!installed: =!"
    set "installed=!installed:b= Build !"
    echo %GREEN% Internet Download Manager found. Installed version: !installed!%RESET%
) else (
    setlocal disabledelayedexpansion
    echo %RED% Error: Unable to find Internet Download Manager installation directory.%RESET%
    echo %YELLOW% Please ensure Internet Download Manager is installed correctly. Then run this script again.%RESET%
    echo.
    echo Loading Menu . . .
    goto :menu
)

:: Parse installed version if possible
if not "!online_version!"=="Unknown" (
    for /f "tokens=1,2,4 delims=. " %%a in ("!installed!") do (
        set "i_major=%%a"
        set "i_minor=%%b"
        set "i_build=%%c"
    )
    :: Compare versions logic roughly
    set /a i_total = 10000 * !i_major! + 100 * !i_minor! + !i_build!
    set /a o_total = 10000 * !o_major! + 100 * !o_minor! + !o_build!

    echo.
    if !i_total! GEQ !o_total! (
        echo %GREEN% You already have the latest version of Internet Download Manager.%RESET%
    ) else (
        echo %YELLOW% A newer version of IDM is available!%RESET%
        echo %GREEN% Please update to the latest version: !online_version!%RESET%
    )
)
echo.

:: Cleaning
del "%tempfile_html%" >nul 2>&1
del "%temp%\latest_release.json" >nul 2>&1

:: Main menu
:menu
timeout /t 1 >nul
cls
echo.
echo %GREEN%  ======================================================
echo %GREEN%    :                                                  :
echo %GREEN%    :  [1] Download Latest IDM Version                 :
echo %GREEN%    :  [2] Activate Internet Download Manager          :
echo %GREEN%    :  [3] Extra FileTypes Extensions                  :
echo %GREEN%    :  [4] Do Everything (2 + 3)                       :
echo %RED%    :  [5] Completely Remove IDM Registry Entries      :
echo %CYAN%    :  [6] IDM Hosts Manager (Block/Unblock)           :
echo %CYAN%    :  [7] IDM File Protection (Lock/Unlock)           :
echo %GREEN%    :  [8] Exit                                        :
echo %GREEN%    :                                                  :
echo %GREEN%  ======================================================%RESET%
echo.
set "choice="
set /p choice=" Choose an option (1-8): "
if not defined choice goto :menu

if "%choice%"=="1" call :DownloadLatestIDM & goto :menu
if "%choice%"=="2" call :ActivateIDM & goto :menu
if "%choice%"=="3" call :AddExtensions & goto :menu
if "%choice%"=="4" call :DoEverything & goto :menu
if "%choice%"=="5" call :CleanRegistry & goto :menu
if "%choice%"=="6" goto :HOSTS_MENU
if "%choice%"=="7" goto :PROTECT_MENU
if "%choice%"=="8" call :quit

echo %RED% Invalid option. Please enter a number from 1 to 8.%RESET%
timeout /t 2 >nul
goto :menu

::============================================================================
:: FILE PROTECTION MENU (MANUAL LOCK/UNLOCK)
::============================================================================
:PROTECT_MENU
cls
echo.
echo %CYAN% ================================================%RESET%
echo %CYAN%            IDM FILE PROTECTION MANAGER %RESET%
echo %CYAN% ================================================%RESET%
echo.
echo        [1] Lock Files (Protect from Update/Overwrite)
echo        [2] Unlock Files (Allow Update/Modify)
echo        [3] Check Current Status
echo        [4] Back to Main Menu
echo.
echo %CYAN% ================================================%RESET%
set /p pchoice=Choose an option (1-4): 

if "%pchoice%"=="1" goto LOCK_FILES_MANUAL
if "%pchoice%"=="2" goto UNLOCK_FILES_MANUAL
if "%pchoice%"=="3" goto CHECK_FILES_STATUS
if "%pchoice%"=="4" goto :menu

echo %RED% Invalid choice. Please select an option between 1 and 4.%RESET%
pause
goto PROTECT_MENU

:: =========================================================
:: FUNCTION: SAFE PATH FINDER (NO BLOCKS)
:: =========================================================
:GET_IDM_DIR_SAFE
set "IDM_DIR="
set "FullExePath="
:: Lấy đường dẫn từ Registry
for /f "tokens=2*" %%A in ('reg query "HKCU\SOFTWARE\DownloadManager" /v ExePath 2^>nul') do set "FullExePath=%%B"

:: Nếu không tìm thấy trong Registry
if not defined FullExePath goto :DIR_NOT_FOUND

:: Lấy thư mục cha từ đường dẫn full
for %%F in ("!FullExePath!") do set "IDM_DIR=%%~dpF"

:: Kiểm tra file tồn tại
if not exist "!IDM_DIR!IDMan.exe" goto :DIR_NOT_FOUND

:: Nếu tìm thấy OK thì thoát khỏi hàm này
exit /b

:DIR_NOT_FOUND
echo %RED% Error: Unable to find IDM installation path automatically.%RESET%
echo %YELLOW% Please make sure IDM is installed.%RESET%
pause
goto PROTECT_MENU

:: =========================================================
:: ACTION: LOCK FILES
:: =========================================================
:LOCK_FILES_MANUAL
cls
call :GET_IDM_DIR_SAFE

echo %YELLOW% Locking IDMan.exe and IDMGrHlp.exe...%RESET%
:: Chạy lệnh trực tiếp, không bao trong if ()
attrib +r +s "!IDM_DIR!IDMan.exe"
attrib +r +s "!IDM_DIR!IDMGrHlp.exe"

:: Kiểm tra lỗi bằng goto thay vì ngoặc đơn
if %errorlevel% NEQ 0 goto :LOCK_FAIL

echo.
echo %GREEN% [OK] Files successfully LOCKED (Read-Only + System).%RESET%
echo IDM Updater will not be able to overwrite these files.
echo.
echo ---------------------------------------------------
pause
goto PROTECT_MENU

:LOCK_FAIL
echo.
echo %RED% [ERROR] Failed to lock files.%RESET%
echo Please make sure IDM is not running and you have Admin rights.
echo.
echo ---------------------------------------------------
pause
goto PROTECT_MENU

:: =========================================================
:: ACTION: UNLOCK FILES
:: =========================================================
:UNLOCK_FILES_MANUAL
cls
call :GET_IDM_DIR_SAFE

echo %YELLOW% Unlocking IDMan.exe and IDMGrHlp.exe...%RESET%
attrib -r -s -h "!IDM_DIR!IDMan.exe"
attrib -r -s -h "!IDM_DIR!IDMGrHlp.exe"

if %errorlevel% NEQ 0 goto :UNLOCK_FAIL

echo.
echo %GREEN% [OK] Files successfully UNLOCKED.%RESET%
echo You can now update IDM manually or replace files.
echo.
echo ---------------------------------------------------
pause
goto PROTECT_MENU

:UNLOCK_FAIL
echo.
echo %RED% [ERROR] Failed to unlock files.%RESET%
echo Check permissions or if IDM is running.
echo.
echo ---------------------------------------------------
pause
goto PROTECT_MENU

:: =========================================================
:: ACTION: CHECK STATUS
:: =========================================================
:CHECK_FILES_STATUS
cls
call :GET_IDM_DIR_SAFE

echo %CYAN% Checking attributes for IDM files...%RESET%
echo.
echo [IDMan.exe]:
attrib "!IDM_DIR!IDMan.exe"
echo.
echo [IDMGrHlp.exe]:
attrib "!IDM_DIR!IDMGrHlp.exe"

echo.
echo %YELLOW% NOTE:%RESET%
echo If you see "R" and "S" (e.g., A  S  R), the file is LOCKED.
echo If you only see "A" (e.g., A       ), the file is UNLOCKED.
echo.
echo ---------------------------------------------------
pause
goto PROTECT_MENU

::============================================================================
:: HOSTS MANAGER SECTION
::============================================================================
:HOSTS_MENU
cls
echo.
echo %CYAN% ================================================%RESET%
echo %CYAN%                 IDM HOST MANAGER %RESET%
echo %CYAN% ================================================%RESET%
echo.
echo        [1] Block IDM-related domains
echo        [2] Unblock IDM-related domains
echo        [3] Set file hosts to read-only
echo        [4] Restore file hosts access to default
echo        [5] Check if domains are blocked
echo        [6] Back to Main Menu
echo.
echo %CYAN% ================================================%RESET%
set /p hchoice=Choose an option (1-6): 

if "%hchoice%"=="1" goto BLOCK_IDM
if "%hchoice%"=="2" goto UNBLOCK_IDM
if "%hchoice%"=="3" goto SET_READONLY
if "%hchoice%"=="4" goto RESTORE_ACCESS
if "%hchoice%"=="5" goto CHECK_BLOCKED
if "%hchoice%"=="6" goto :menu

echo %RED% Invalid choice. Please select an option between 1 and 6.%RESET%
pause
goto HOSTS_MENU

:BLOCK_IDM
cls
echo %YELLOW% ===============================%RESET%
echo %YELLOW% ADDING BLOCK ENTRIES%RESET%
echo %YELLOW% ===============================%RESET%
:: Check if the file is read-only
for /f "tokens=*" %%A in ('icacls "%SystemRoot%\System32\drivers\etc\hosts" 2^>nul ^| findstr /i "DENY Everyone:(W)"') do set "readOnly=1"

if defined readOnly (
    echo %RED% ===============================%RESET%
    echo %RED% ERROR: The hosts file is set to read-only.%RESET%
    echo %RED% ===============================%RESET%
    echo Please use option 4 to restore file access to default before blocking domains.
    echo %RED% ===============================%RESET%
    pause
    set "readOnly="
    goto HOSTS_MENU
)

:: Adding block entries
echo Adding block entries for IDM-related domains to hosts file...
(
    echo #Internet Download Manager
    echo 127.0.0.1 tonec.com
    echo 127.0.0.1 www.tonec.com
    echo 127.0.0.1 registeridm.com
    echo 127.0.0.1 www.registeridm.com
    echo 127.0.0.1 secure.registeridm.com
    echo 127.0.0.1 internetdownloadmanager.com
    echo 127.0.0.1 www.internetdownloadmanager.com
    echo 127.0.0.1 secure.internetdownloadmanager.com
    echo 127.0.0.1 mirror.internetdownloadmanager.com
    echo 127.0.0.1 mirror2.internetdownloadmanager.com
    echo 127.0.0.1 mirror3.internetdownloadmanager.com
    echo 127.0.0.1 star.tonec.com
) >> "%SystemRoot%\System32\drivers\etc\hosts"

if errorlevel 1 (
    echo %RED% ===============================%RESET%
    echo %RED% FAILED TO ADD BLOCK ENTRIES%RESET%
    echo %RED% ===============================%RESET%
    echo Failed to add block entries. Access may be denied or file may be read-only.
    echo %RED% ===============================%RESET%
    pause
    goto HOSTS_MENU
)

echo %GREEN% ===============================%RESET%
echo %GREEN% BLOCK ENTRIES ADDED SUCCESSFULLY%RESET%
echo %GREEN% ===============================%RESET%
pause
goto HOSTS_MENU

:UNBLOCK_IDM
cls
echo %YELLOW% ===============================%RESET%
echo %YELLOW% REMOVING BLOCK ENTRIES%RESET%
echo %YELLOW% ===============================%RESET%
:: Check if the file is read-only
for /f "tokens=*" %%A in ('icacls "%SystemRoot%\System32\drivers\etc\hosts" 2^>nul ^| findstr /i "DENY Everyone:(W)"') do set "readOnly=1"

if defined readOnly (
    echo %RED% ===============================%RESET%
    echo %RED% ERROR: The hosts file is set to read-only.%RESET%
    echo %RED% ===============================%RESET%
    echo Please use option 4 to restore file access to default before unblocking domains.
    echo %RED% ===============================%RESET%
    pause
    set "readOnly="
    goto HOSTS_MENU
)

:: Removing block entries
echo Removing block entries for IDM-related domains from hosts file...
set "tempFile=%TEMP%\hosts_temp"
(for /f "usebackq delims=" %%A in ("%SystemRoot%\System32\drivers\etc\hosts") do (
    echo %%A | findstr /v /c:"127.0.0.1 tonec.com" | findstr /v /c:"127.0.0.1 www.tonec.com" | findstr /v /c:"127.0.0.1 registeridm.com" | findstr /v /c:"127.0.0.1 www.registeridm.com" | findstr /v /c:"127.0.0.1 secure.registeridm.com" | findstr /v /c:"127.0.0.1 internetdownloadmanager.com" | findstr /v /c:"127.0.0.1 www.internetdownloadmanager.com" | findstr /v /c:"127.0.0.1 secure.internetdownloadmanager.com" | findstr /v /c:"127.0.0.1 mirror.internetdownloadmanager.com" | findstr /v /c:"127.0.0.1 mirror2.internetdownloadmanager.com" | findstr /v /c:"127.0.0.1 mirror3.internetdownloadmanager.com" | findstr /v /c:"127.0.0.1 star.tonec.com" >> "%tempFile%"
)) >nul
move /y "%tempFile%" "%SystemRoot%\System32\drivers\etc\hosts" >nul

if errorlevel 1 (
    echo %RED% ===============================%RESET%
    echo %RED% FAILED TO REMOVE BLOCK ENTRIES%RESET%
    echo %RED% ===============================%RESET%
    echo Failed to remove block entries. Access may be denied or file may be read-only.
    echo %RED% ===============================%RESET%
    pause
    goto HOSTS_MENU
)

echo %GREEN% ===============================%RESET%
echo %GREEN% BLOCK ENTRIES REMOVED SUCCESSFULLY%RESET%
echo %GREEN% ===============================%RESET%
pause
goto HOSTS_MENU

:SET_READONLY
cls
echo %YELLOW% ===============================%RESET%
echo %YELLOW% SETTING FILE HOSTS TO READ-ONLY%RESET%
echo %YELLOW% ===============================%RESET%
echo Setting file hosts to read-only...
icacls "%SystemRoot%\System32\drivers\etc\hosts" /deny Everyone:(W) >nul 2>&1
if errorlevel 1 (
    echo %RED% ===============================%RESET%
    echo %RED% FAILED TO SET FILE HOSTS TO READ-ONLY%RESET%
    echo %RED% ===============================%RESET%
    echo Failed to set file hosts to read-only. Check your permissions.
    echo %RED% ===============================%RESET%
    pause
    goto HOSTS_MENU
)
echo %GREEN% ===============================%RESET%
echo %GREEN% FILE HOSTS SET TO READ-ONLY%RESET%
echo %GREEN% ===============================%RESET%
pause
goto HOSTS_MENU

:RESTORE_ACCESS
cls
echo %YELLOW% ===============================%RESET%
echo %YELLOW% RESTORING FILE HOSTS ACCESS TO DEFAULT%RESET%
echo %YELLOW% ===============================%RESET%
echo Restoring file hosts access to default...
icacls "%SystemRoot%\System32\drivers\etc\hosts" /reset >nul 2>&1
if errorlevel 1 (
    echo %RED% ===============================%RESET%
    echo %RED% FAILED TO RESTORE FILE HOSTS ACCESS%RESET%
    echo %RED% ===============================%RESET%
    echo Failed to restore file hosts access. Check your permissions.
    echo %RED% ===============================%RESET%
    pause
    goto HOSTS_MENU
)
echo %GREEN% ===============================%RESET%
echo %GREEN% FILE HOSTS ACCESS RESTORED TO DEFAULT%RESET%
echo %GREEN% ===============================%RESET%
pause
goto HOSTS_MENU

:CHECK_BLOCKED
cls
echo %YELLOW% ===============================%RESET%
echo %YELLOW% CHECKING BLOCKED DOMAINS%RESET%
echo %YELLOW% ===============================%RESET%
set "file=%SystemRoot%\System32\drivers\etc\hosts"
set "domains=tonec.com www.tonec.com registeridm.com www.registeridm.com secure.registeridm.com internetdownloadmanager.com www.internetdownloadmanager.com secure.internetdownloadmanager.com mirror.internetdownloadmanager.com mirror2.internetdownloadmanager.com mirror3.internetdownloadmanager.com star.tonec.com"
set "found=0"

:: Flush DNS cache
echo Flushing DNS cache...
ipconfig /flushdns >nul 2>&1

:: Check if domains are blocked using nslookup
for %%D in (%domains%) do (
    echo Pinging %%D to check if it is blocked...
    for /f "tokens=2 delims=[]" %%A in ('nslookup %%D 2^>nul ^| findstr /i "Address"') do (
        if "%%A"=="127.0.0.1" (
            echo %GREEN% [BLOCKED] %%D %RESET%
        ) else (
            echo %RED% [NOT BLOCKED] %%D %RESET%
            set "found=1"
        )
    )
)

echo.
if !found! equ 0 (
    echo %GREEN% ===============================%RESET%
    echo %GREEN% ALL DOMAINS ARE BLOCKED%RESET%
    echo %GREEN% ===============================%RESET%
) else (
    echo %RED% ===============================%RESET%
    echo %RED% SOME DOMAINS ARE NOT BLOCKED%RESET%
    echo %RED% ===============================%RESET%
)

pause
goto HOSTS_MENU


::============================================================================
:: ORIGINAL FUNCTIONS (From Script B)
::============================================================================

::----------------------
:: Download function for the latest script
:DownloadLatestScript
set "DOWNLOAD_URL="

:: Extract download URL from JSON file
for /f "tokens=1,* delims=:" %%a in ('findstr /i "browser_download_url" "%temp%\latest_release.json"') do (
    set "line=%%b"
    set "line=!line:~2!"
    set "line=!line: =!"
    set "line=!line:~0,-1!"
    set "DOWNLOAD_URL=!line!"
)

:: Verify that the download URL was extracted correctly
if not "!DOWNLOAD_URL!"=="" (
    echo %GREEN% Opening your browser to download the latest script...%RESET%
    echo.
    start "" "!DOWNLOAD_URL!"
    echo %YELLOW% If your download does not start automatically, copy and paste this URL into your browser:%RESET%
    echo %YELLOW% !DOWNLOAD_URL!%RESET%
) else (
    echo %RED% Failed to retrieve download URL.%RESET%
)
exit

::----------------------
:DownloadLatestIDM
call :check_internet

if /i "!online_version!"=="Unknown" (
    echo %RED% No version info available. Try checking for updates first.%RESET%
    exit /b
)
echo %GREEN% Opening your browser to download the latest IDM...%RESET%
echo.
start "" "%downloadurl%"
echo %YELLOW% If your download does not start automatically, copy and paste this URL into your browser:%RESET%
echo.
exit /b

::----------------------
:: Internet check subroutine
:check_internet
echo Checking internet connectivity...
ping -n 1 8.8.8.8 >nul 2>&1
if errorlevel 1 (
    echo %RED% Internet not available. Some features may not work.%RESET%
    echo %YELLOW% Continuing in offline mode...%RESET%
)
exit /b

::----------------------
:ActivateIDM
:: Check IDM installation directory from the registry

for /f "tokens=2*" %%A in ('reg query "HKCU\SOFTWARE\DownloadManager" /v ExePath 2^>nul') do (
    set "DEFAULT_DEST_DIR=%%B"
)

if defined DEFAULT_DEST_DIR (
    for %%A in ("%DEFAULT_DEST_DIR%") do set "DEFAULT_DEST_DIR=%%~dpA"
    timeout /t 1 >nul
) else (
    setlocal disabledelayedexpansion
    echo %RED% Error: Unable to find IDM installation directory.%RESET%
    echo %YELLOW% Please install IDM and try again.%RESET%
    echo %GREEN% Download it here: !downloadurl!%RESET%
    pause
    exit /b
)

call :verifyFile "%DATA_FILE%" "data.bin"
call :verifyFile "%DATAHLP_FILE%" "dataHlp.bin"
call :verifyFile "%REGISTRY_FILE%" "registry.bin"
call :verifyDestinationDirectory
call :terminateProcess "IDMan.exe"
regedit /s "%REGISTRY_FILE%"

:: === MODIFICATION START: Backup and Attribute Locking ===

echo %YELLOW% Backing up original files (if not already backed up)...%RESET%
if not exist "%DEFAULT_DEST_DIR%IDMan.exe.bak" copy "%DEFAULT_DEST_DIR%IDMan.exe" "%DEFAULT_DEST_DIR%IDMan.exe.bak" >nul
if not exist "%DEFAULT_DEST_DIR%IDMGrHlp.exe.bak" copy "%DEFAULT_DEST_DIR%IDMGrHlp.exe" "%DEFAULT_DEST_DIR%IDMGrHlp.exe.bak" >nul

echo %YELLOW% Unlocking files for modification...%RESET%
:: Remove Read-Only/System attributes from destination (in case they were locked previously)
attrib -r -s -h "%DEFAULT_DEST_DIR%IDMan.exe" >nul 2>&1
attrib -r -s -h "%DEFAULT_DEST_DIR%IDMGrHlp.exe" >nul 2>&1

echo %GREEN% Copying patched files...%RESET%
copy /Y "%DATA_FILE%" "%DEFAULT_DEST_DIR%IDMan.exe" >nul
copy /Y "%DATAHLP_FILE%" "%DEFAULT_DEST_DIR%IDMGrHlp.exe" >nul

echo %YELLOW% Locking files (Read-Only) to prevent updates from reverting them...%RESET%
:: Add Read-Only and System attributes to prevent modification
attrib +r +s "%DEFAULT_DEST_DIR%IDMan.exe"
attrib +r +s "%DEFAULT_DEST_DIR%IDMGrHlp.exe"

:: === MODIFICATION END ===

:: ——— PROMPT FOR USER INPUT ———
echo.
SET /P FName=Enter your First Name: 
SET /P LName=Enter your Last Name: 
echo.

:: ——— FALLBACK TO DEFAULTS IF BLANK ———
if "%FName%"=="" set "FName=Coporton"
if "%LName%"=="" set "LName=WorkStation"

:: Re-register user info using the values the user just entered
reg add "HKCU\SOFTWARE\DownloadManager" /v FName /t REG_SZ /d "%FName%" /f >nul
reg add "HKCU\SOFTWARE\DownloadManager" /v LName /t REG_SZ /d "%LName%" /f >nul

echo %GREEN% Internet Download Manager Activated and Locked.%RESET%
exit /b

:verifyFile
if not exist "%~1" echo %RED% Missing: %~2%RESET% & pause & exit /b
exit /b

:verifyDestinationDirectory
if not exist "%DEFAULT_DEST_DIR%" echo %RED% Destination not found.%RESET% & pause & exit /b
exit /b

:terminateProcess
taskkill /F /IM %~1 >nul 2>&1
exit /b

::----------------------
:AddExtensions
regedit /s "%EXTENSIONS_FILE%"
echo %GREEN% Extra FileTypes Extensions updated.%RESET%
exit /b

::----------------------
:DoEverything
call :ActivateIDM
call :AddExtensions
echo.
echo [%DATE% %TIME%] Activated IDM >> %SCRIPT_DIR%log.txt
echo %GREEN% Congratulations. All tasks completed successfully!%RESET%
echo.
exit /b

::----------------------
:CleanRegistry
:: Full registry cleaning logic

call :terminateProcess "IDMan.exe"
echo %YELLOW% Cleaning IDM-related Registry Entries...%RESET%
echo %YELLOW% Unlocking files before cleaning...%RESET%

:: Unlock files in case we need to delete/restore them later
for /f "tokens=2*" %%A in ('reg query "HKCU\SOFTWARE\DownloadManager" /v ExePath 2^>nul') do (
    set "DEFAULT_DEST_DIR=%%B"
)
if defined DEFAULT_DEST_DIR (
    for %%A in ("%DEFAULT_DEST_DIR%") do set "DEFAULT_DEST_DIR=%%~dpA"
    attrib -r -s -h "!DEFAULT_DEST_DIR!IDMan.exe" >nul 2>&1
    attrib -r -s -h "!DEFAULT_DEST_DIR!IDMGrHlp.exe" >nul 2>&1
)

for %%k in (
    "HKLM\Software\Classes\CLSID\{7B8E9164-324D-4A2E-A46D-0165FB2000EC}"
    "HKLM\Software\Classes\CLSID\{6DDF00DB-1234-46EC-8356-27E7B2051192}"
    "HKLM\Software\Classes\CLSID\{D5B91409-A8CA-4973-9A0B-59F713D25671}"
    "HKLM\Software\Classes\CLSID\{5ED60779-4DE2-4E07-B862-974CA4FF2E9C}"
    "HKLM\Software\Classes\CLSID\{07999AC3-058B-40BF-984F-69EB1E554CA7}"
    "HKLM\Software\Classes\CLSID\{E8CF4E59-B7A3-41F2-86C7-82B03334F22A}"
    "HKLM\Software\Classes\CLSID\{9C9D53D4-A978-43FC-93E2-1C21B529E6D7}"
    "HKLM\Software\Classes\CLSID\{79873CC5-3951-43ED-BDF9-D8759474B6FD}"
    "HKLM\Software\Classes\CLSID\{E6871B76-C3C8-44DD-B947-ABFFE144860D}"
    "HKLM\Software\Classes\Wow6432Node\CLSID\{7B8E9164-324D-4A2E-A46D-0165FB2000EC}"
    "HKLM\Software\Classes\Wow6432Node\CLSID\{6DDF00DB-1234-46EC-8356-27E7B2051192}"
    "HKLM\Software\Classes\Wow6432Node\CLSID\{D5B91409-A8CA-4973-9A0B-59F713D25671}"
    "HKLM\Software\Classes\Wow6432Node\CLSID\{5ED60779-4DE2-4E07-B862-974CA4FF2E9C}"
    "HKLM\Software\Classes\Wow6432Node\CLSID\{07999AC3-058B-40BF-984F-69EB1E554CA7}"
    "HKLM\Software\Classes\Wow6432Node\CLSID\{E8CF4E59-B7A3-41F2-86C7-82B03334F22A}"
    "HKLM\Software\Classes\Wow6432Node\CLSID\{9C9D53D4-A978-43FC-93E2-1C21B529E6D7}"
    "HKLM\Software\Classes\Wow6432Node\CLSID\{79873CC5-3951-43ED-BDF9-D8759474B6FD}"
    "HKLM\Software\Classes\Wow6432Node\CLSID\{E6871B76-C3C8-44DD-B947-ABFFE144860D}"
    "HKCU\Software\Classes\CLSID\{7B8E9164-324D-4A2E-A46D-0165FB2000EC}"
    "HKCU\Software\Classes\CLSID\{6DDF00DB-1234-46EC-8356-27E7B2051192}"
    "HKCU\Software\Classes\CLSID\{D5B91409-A8CA-4973-9A0B-59F713D25671}"
    "HKCU\Software\Classes\CLSID\{5ED60779-4DE2-4E07-B862-974CA4FF2E9C}"
    "HKCU\Software\Classes\CLSID\{07999AC3-058B-40BF-984F-69EB1E554CA7}"
    "HKCU\Software\Classes\CLSID\{E8CF4E59-B7A3-41F2-86C7-82B03334F22A}"
    "HKCU\Software\Classes\CLSID\{9C9D53D4-A978-43FC-93E2-1C21B529E6D7}"
    "HKCU\Software\Classes\CLSID\{79873CC5-3951-43ED-BDF9-D8759474B6FD}"
    "HKCU\Software\Classes\CLSID\{E6871B76-C3C8-44DD-B947-ABFFE144860D}"
    "HKCU\Software\Classes\Wow6432Node\CLSID\{7B8E9164-324D-4A2E-A46D-0165FB2000EC}"
    "HKCU\Software\Classes\Wow6432Node\CLSID\{6DDF00DB-1234-46EC-8356-27E7B2051192}"
    "HKCU\Software\Classes\Wow6432Node\CLSID\{D5B91409-A8CA-4973-9A0B-59F713D25671}"
    "HKCU\Software\Classes\Wow6432Node\CLSID\{5ED60779-4DE2-4E07-B862-974CA4FF2E9C}"
    "HKCU\Software\Classes\Wow6432Node\CLSID\{07999AC3-058B-40BF-984F-69EB1E554CA7}"
    "HKCU\Software\Classes\Wow6432Node\CLSID\{E8CF4E59-B7A3-41F2-86C7-82B03334F22A}"
    "HKCU\Software\Classes\Wow6432Node\CLSID\{9C9D53D4-A978-43FC-93E2-1C21B529E6D7}"
    "HKCU\Software\Classes\Wow6432Node\CLSID\{79873CC5-3951-43ED-BDF9-D8759474B6FD}"
    "HKCU\Software\Classes\Wow6432Node\CLSID\{E6871B76-C3C8-44DD-B947-ABFFE144860D}"
    "HKU\.DEFAULT\Software\Classes\CLSID\{7B8E9164-324D-4A2E-A46D-0165FB2000EC}"
    "HKU\.DEFAULT\Software\Classes\CLSID\{6DDF00DB-1234-46EC-8356-27E7B2051192}"
    "HKU\.DEFAULT\Software\Classes\CLSID\{D5B91409-A8CA-4973-9A0B-59F713D25671}"
    "HKU\.DEFAULT\Software\Classes\CLSID\{5ED60779-4DE2-4E07-B862-974CA4FF2E9C}"
    "HKU\.DEFAULT\Software\Classes\CLSID\{07999AC3-058B-40BF-984F-69EB1E554CA7}"
    "HKU\.DEFAULT\Software\Classes\CLSID\{E8CF4E59-B7A3-41F2-86C7-82B03334F22A}"
    "HKU\.DEFAULT\Software\Classes\CLSID\{9C9D53D4-A978-43FC-93E2-1C21B529E6D7}"
    "HKU\.DEFAULT\Software\Classes\CLSID\{79873CC5-3951-43ED-BDF9-D8759474B6FD}"
    "HKU\.DEFAULT\Software\Classes\CLSID\{E6871B76-C3C8-44DD-B947-ABFFE144860D}"
    "HKU\.DEFAULT\Software\Classes\Wow6432Node\CLSID\{7B8E9164-324D-4A2E-A46D-0165FB2000EC}"
    "HKU\.DEFAULT\Software\Classes\Wow6432Node\CLSID\{6DDF00DB-1234-46EC-8356-27E7B2051192}"
    "HKU\.DEFAULT\Software\Classes\Wow6432Node\CLSID\{D5B91409-A8CA-4973-9A0B-59F713D25671}"
    "HKU\.DEFAULT\Software\Classes\Wow6432Node\CLSID\{5ED60779-4DE2-4E07-B862-974CA4FF2E9C}"
    "HKU\.DEFAULT\Software\Classes\Wow6432Node\CLSID\{07999AC3-058B-40BF-984F-69EB1E554CA7}"
    "HKU\.DEFAULT\Software\Classes\Wow6432Node\CLSID\{E8CF4E59-B7A3-41F2-86C7-82B03334F22A}"
    "HKU\.DEFAULT\Software\Classes\Wow6432Node\CLSID\{9C9D53D4-A978-43FC-93E2-1C21B529E6D7}"
    "HKU\.DEFAULT\Software\Classes\Wow6432Node\CLSID\{79873CC5-3951-43ED-BDF9-D8759474B6FD}"
    "HKU\.DEFAULT\Software\Classes\Wow6432Node\CLSID\{E6871B76-C3C8-44DD-B947-ABFFE144860D}"
    "HKLM\Software\Internet Download Manager"
    "HKLM\Software\Wow6432Node\Internet Download Manager"
    "HKCU\Software\Download Manager"
    "HKCU\Software\Wow6432Node\Download Manager"
) do reg delete %%k /f >nul 2>&1

:: Clean license values
for %%v in ("FName" "LName" "Email" "Serial" "CheckUpdtVM" "tvfrdt" "LstCheck" "scansk" "idmvers") do (
    reg delete "HKCU\Software\DownloadManager" /v %%v /f >nul 2>&1
)

echo %GREEN% Registry cleanup completed.%RESET%
exit /b

::----------------------
:quit
echo.
echo %GREEN% Thank you for using Coporton IDM Activation Script + Hosts Manager. Have a great day... %RESET%
timeout /t 2 >nul
exit
