@echo off
setlocal EnableDelayedExpansion
set iasver=3.1.0 (Stable Fix)

::============================================================================
:: Coporton IDM Activation Script + Hosts Manager + File Protection
:: Fixed Lock Issue & Menu Loop by Gemini AI
::============================================================================

mode con: cols=120 lines=40
title Coporton IDM Master Tool v%iasver%

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
set "MAGENTA=[35m"

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
    echo %CYAN%  IDM MASTER ACTIVATION TOOL %RESET%
    echo.
)

:: Internet connection check
call :check_internet

:: Verify Script Version
echo Checking for script updates...

set "SCRIPT_VERSION=v%iasver%"
set "API_URL=https://api.github.com/repos/hcdbp24c3/cias/releases/latest"

curl -s "%API_URL%" -o "%temp%\latest_release.json"

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

set "SCRIPT_VERSION_NUM=%SCRIPT_VERSION:v=%"
set "LATEST_VERSION_NUM=%LATEST_VERSION:v=%"

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

:CompareVersions
setlocal EnableDelayedExpansion
set "current=%~1"
set "latest=%~2"
for /f "tokens=1-3 delims=." %%a in ("!current!") do ( set "cur1=%%a" & set "cur2=%%b" & set "cur3=%%c" )
for /f "tokens=1-3 delims=." %%a in ("!latest!") do ( set "lat1=%%a" & set "lat2=%%b" & set "lat3=%%c" )
if !lat1! GTR !cur1! (endlocal & set "is_newer=1" & exit /b)
if !lat1! LSS !cur1! (endlocal & set "is_newer=0" & exit /b)
if !lat2! GTR !cur2! (endlocal & set "is_newer=1" & exit /b)
if !lat2! LSS !cur2! (endlocal & set "is_newer=0" & exit /b)
if !lat3! GTR !cur3! (endlocal & set "is_newer=1" & exit /b)
if !lat3! LSS !cur3! (endlocal & set "is_newer=0" & exit /b)
endlocal & set "is_newer=0"
exit /b

:ask_download
echo %GREEN% ========================================================================
echo %GREEN%    :  Do you want to download the latest version of the script?       : 
echo %GREEN%    :                        (1 = Yes / 2 = No)                        :
echo %GREEN% =======================================================================%RESET%
echo.
set "choice="
set /p choice=" Choose an option (1 = Yes / 2 = No): "
if "%choice%"=="1" ( call :DownloadLatestScript ) else if "%choice%"=="2" ( goto continue_script ) else ( goto ask_download )
goto :eof

:continue_script
echo Getting the latest version information...
curl -s "https://www.internetdownloadmanager.com/news.html" -o "%tempfile_html%"
set "online_version="
for /f "tokens=1* delims=<>" %%a in ('findstr /i "<H3>What's new in version" "%tempfile_html%" ^| findstr /r /c:"Build [0-9]*"') do (
    set "line=%%b"
    set "line=!line:What's new in version =!"
    set "line=!line:</H3>=!"
    set "online_version=!line!"
    goto :got_version
)

:got_version
if not defined online_version ( set "online_version=Unknown" )
echo %GREEN% Latest online version: !online_version! %RESET%

if not "!online_version!"=="Unknown" (
    for /f "tokens=1,2,4 delims=. " %%a in ("!online_version!") do ( set "o_major=%%a" & set "o_minor=%%b" & set "o_build=%%c" )
    set "downloadcode=!o_major!!o_minor!build!o_build!"
    set "downloadurl=https://mirror2.internetdownloadmanager.com/idman%downloadcode%.exe"
) else (
    set "downloadurl=https://www.internetdownloadmanager.com/download.html"
)

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
    goto :menu
)

if not "!online_version!"=="Unknown" (
    for /f "tokens=1,2,4 delims=. " %%a in ("!installed!") do ( set "i_major=%%a" & set "i_minor=%%b" & set "i_build=%%c" )
    set /a i_total = 10000 * !i_major! + 100 * !i_minor! + !i_build!
    set /a o_total = 10000 * !o_major! + 100 * !o_minor! + !o_build!
    echo.
    if !i_total! GEQ !o_total! ( echo %GREEN% You already have the latest version.%RESET% ) else ( echo %YELLOW% A newer version is available!%RESET% )
)
echo.
del "%tempfile_html%" >nul 2>&1
del "%temp%\latest_release.json" >nul 2>&1

:: Main menu
:menu
timeout /t 1 >nul
cls
echo.
echo %GREEN%  ======================================================
echo %GREEN%    :                                                :
echo %GREEN%    :  [1] Download Latest IDM Version               :
echo %GREEN%    :  [2] Activate IDM (Safe Lock)                  :
echo %GREEN%    :  [3] Extra FileTypes Extensions                :
echo %GREEN%    :  [4] Do Everything (2 + 3)                     :
echo %RED%    :  [5] Completely Remove IDM Registry Entries    :
echo %CYAN%    :  [6] IDM Hosts Manager (Block/Unblock)         :
echo %MAGENTA%    :  [7] IDM File Protection (Lock/Unlock Exe)     :
echo %GREEN%    :  [8] Exit                                      :
echo %GREEN%    :                                                :
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
if "%choice%"=="7" goto :FILE_PROTECT_MENU
if "%choice%"=="8" call :quit

echo %RED% Invalid option. Please enter a number from 1 to 8.%RESET%
timeout /t 2 >nul
goto :menu


::============================================================================
:: HOSTS MANAGER SECTION
::============================================================================
:HOSTS_MENU
cls
echo.
echo %CYAN% ================================================%RESET%
echo %CYAN%                IDM HOST MANAGER %RESET%
echo %CYAN% ================================================%RESET%
echo.
echo       [1] Block IDM-related domains
echo       [2] Unblock IDM-related domains
echo       [3] Set file hosts to read-only
echo       [4] Restore file hosts access to default
echo       [5] Check if domains are blocked
echo       [6] Back to Main Menu
echo.
echo %CYAN% ================================================%RESET%
set /p hchoice=Choose an option (1-6): 

if "%hchoice%"=="1" goto BLOCK_IDM
if "%hchoice%"=="2" goto UNBLOCK_IDM
if "%hchoice%"=="3" goto SET_READONLY
if "%hchoice%"=="4" goto RESTORE_ACCESS
if "%hchoice%"=="5" goto CHECK_BLOCKED
if "%hchoice%"=="6" goto MENU

echo %RED% Invalid choice. Please select an option between 1 and 6.%RESET%
pause
goto HOSTS_MENU

:BLOCK_IDM
cls
:: Code for block IDM (Shortened for brevity, logic remains same)
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
echo %GREEN% Block entries added.%RESET%
pause
goto HOSTS_MENU

:UNBLOCK_IDM
cls
set "tempFile=%TEMP%\hosts_temp"
(for /f "usebackq delims=" %%A in ("%SystemRoot%\System32\drivers\etc\hosts") do (
    echo %%A | findstr /v /c:"tonec.com" | findstr /v /c:"registeridm.com" | findstr /v /c:"internetdownloadmanager.com" >> "%tempFile%"
)) >nul
move /y "%tempFile%" "%SystemRoot%\System32\drivers\etc\hosts" >nul
echo %GREEN% Block entries removed.%RESET%
pause
goto HOSTS_MENU

:SET_READONLY
icacls "%SystemRoot%\System32\drivers\etc\hosts" /deny Everyone:(W) >nul 2>&1
echo %GREEN% Hosts set to Read-Only.%RESET%
pause
goto HOSTS_MENU

:RESTORE_ACCESS
icacls "%SystemRoot%\System32\drivers\etc\hosts" /reset >nul 2>&1
echo %GREEN% Hosts access restored.%RESET%
pause
goto HOSTS_MENU

:CHECK_BLOCKED
cls
echo Pinging tonec.com...
ping -n 1 tonec.com | find "127.0.0.1" >nul
if errorlevel 1 ( echo %RED% NOT BLOCKED %RESET% ) else ( echo %GREEN% BLOCKED %RESET% )
pause
goto HOSTS_MENU

::============================================================================
:: FILE PROTECTION SECTION (FIXED)
::============================================================================
:FILE_PROTECT_MENU
:: Always find path fresh to be sure
set "DEFAULT_DEST_DIR="
for /f "tokens=2*" %%A in ('reg query "HKCU\SOFTWARE\DownloadManager" /v ExePath 2^>nul') do ( set "DEFAULT_DEST_DIR=%%B" )
if defined DEFAULT_DEST_DIR ( for %%A in ("%DEFAULT_DEST_DIR%") do set "DEFAULT_DEST_DIR=%%~dpA" ) else ( echo %RED% IDM Not Found.%RESET% & pause & goto menu )

cls
echo.
echo %MAGENTA% ================================================%RESET%
echo %MAGENTA%          IDM EXECUTABLE PROTECTION %RESET%
echo %MAGENTA% ================================================%RESET%
echo.
echo   Target: %DEFAULT_DEST_DIR%
echo.
echo       [1] LOCK Files (Safe Mode)
echo           - Prevents Overwrite/Delete. Allows Execution.
echo.
echo       [2] UNLOCK Files
echo           - Resets permissions to default.
echo.
echo       [3] Back to Main Menu
echo.
echo %MAGENTA% ================================================%RESET%
set /p fchoice=Choose an option (1-3): 

if "%fchoice%"=="1" goto LOCK_FILES
if "%fchoice%"=="2" goto UNLOCK_FILES
if "%fchoice%"=="3" goto menu
goto FILE_PROTECT_MENU

:LOCK_FILES
echo.
echo %YELLOW% Locking files (Safe Mode)...%RESET%
echo.
:: 1. Set Read-Only Attribute (Basic protection)
attrib +r "%DEFAULT_DEST_DIR%IDMan.exe"
attrib +r "%DEFAULT_DEST_DIR%IDMGrHlp.exe"

:: 2. Grant Read & Execute Explicitly (Fixes "Cannot Run" issue)
icacls "%DEFAULT_DEST_DIR%IDMan.exe" /grant Everyone:(RX) >nul 2>&1
icacls "%DEFAULT_DEST_DIR%IDMGrHlp.exe" /grant Everyone:(RX) >nul 2>&1

:: 3. Deny Write Data & Delete (Prevents Update, Allows Run)
:: WD = Write Data, AD = Append Data, D = Delete
icacls "%DEFAULT_DEST_DIR%IDMan.exe" /deny Everyone:(WD,AD,D) >nul 2>&1
icacls "%DEFAULT_DEST_DIR%IDMGrHlp.exe" /deny Everyone:(WD,AD,D) >nul 2>&1

if errorlevel 1 (
    echo %RED% Failed to lock. Run as Admin.%RESET%
) else (
    echo %GREEN% Files LOCKED. Updates blocked, but IDM should run fine.%RESET%
)
pause
goto FILE_PROTECT_MENU

:UNLOCK_FILES
echo.
echo %YELLOW% Unlocking files...%RESET%
echo.
:: 1. Remove Read-Only Attribute
attrib -r "%DEFAULT_DEST_DIR%IDMan.exe"
attrib -r "%DEFAULT_DEST_DIR%IDMGrHlp.exe"

:: 2. Reset ACL Permissions
icacls "%DEFAULT_DEST_DIR%IDMan.exe" /reset >nul 2>&1
icacls "%DEFAULT_DEST_DIR%IDMGrHlp.exe" /reset >nul 2>&1

if errorlevel 1 (
    echo %RED% Failed to unlock.%RESET%
) else (
    echo %GREEN% Files UNLOCKED. You can now update manually.%RESET%
)
pause
goto FILE_PROTECT_MENU


::============================================================================
:: CORE FUNCTIONS (Modified for Safe Lock)
::============================================================================

:DownloadLatestScript
:: (Same download logic as before)
start "" "https://github.com/hcdbp24c3/cias/releases"
exit

:DownloadLatestIDM
call :check_internet
start "" "%downloadurl%"
exit /b

:check_internet
ping -n 1 8.8.8.8 >nul 2>&1
exit /b

:ActivateIDM
for /f "tokens=2*" %%A in ('reg query "HKCU\SOFTWARE\DownloadManager" /v ExePath 2^>nul') do ( set "DEFAULT_DEST_DIR=%%B" )
if defined DEFAULT_DEST_DIR ( for %%A in ("%DEFAULT_DEST_DIR%") do set "DEFAULT_DEST_DIR=%%~dpA" ) else ( echo %RED% Error: IDM path not found.%RESET% & pause & exit /b )

call :verifyFile "%DATA_FILE%" "data.bin"
call :verifyFile "%DATAHLP_FILE%" "dataHlp.bin"
call :verifyFile "%REGISTRY_FILE%" "registry.bin"
call :terminateProcess "IDMan.exe"

:: --- SAFE UNLOCK ---
echo %YELLOW% Unlocking for update...%RESET%
attrib -r "%DEFAULT_DEST_DIR%IDMan.exe" >nul
attrib -r "%DEFAULT_DEST_DIR%IDMGrHlp.exe" >nul
icacls "%DEFAULT_DEST_DIR%IDMan.exe" /reset >nul 2>&1
icacls "%DEFAULT_DEST_DIR%IDMGrHlp.exe" /reset >nul 2>&1

regedit /s "%REGISTRY_FILE%"
echo Copying activation files...
copy /y "%DATA_FILE%" "%DEFAULT_DEST_DIR%IDMan.exe" >nul
copy /y "%DATAHLP_FILE%" "%DEFAULT_DEST_DIR%IDMGrHlp.exe" >nul

:: --- SAFE LOCK (Using new logic) ---
echo %YELLOW% Locking files (Safe Mode)...%RESET%
attrib +r "%DEFAULT_DEST_DIR%IDMan.exe"
attrib +r "%DEFAULT_DEST_DIR%IDMGrHlp.exe"
icacls "%DEFAULT_DEST_DIR%IDMan.exe" /grant Everyone:(RX) >nul 2>&1
icacls "%DEFAULT_DEST_DIR%IDMGrHlp.exe" /grant Everyone:(RX) >nul 2>&1
icacls "%DEFAULT_DEST_DIR%IDMan.exe" /deny Everyone:(WD,AD,D) >nul 2>&1
icacls "%DEFAULT_DEST_DIR%IDMGrHlp.exe" /deny Everyone:(WD,AD,D) >nul 2>&1

:: User Input
echo.
SET /P FName=Enter First Name: 
SET /P LName=Enter Last Name: 
if "%FName%"=="" set "FName=Coporton"
if "%LName%"=="" set "LName=WorkStation"
reg add "HKCU\SOFTWARE\DownloadManager" /v FName /t REG_SZ /d "%FName%" /f >nul
reg add "HKCU\SOFTWARE\DownloadManager" /v LName /t REG_SZ /d "%LName%" /f >nul

echo %GREEN% IDM Activated & Safely Locked.%RESET%
exit /b

:verifyFile
if not exist "%~1" echo %RED% Missing: %~2%RESET% & pause & exit /b
exit /b

:terminateProcess
taskkill /F /IM %~1 >nul 2>&1
exit /b

:AddExtensions
regedit /s "%EXTENSIONS_FILE%"
echo %GREEN% Extensions updated.%RESET%
exit /b

:DoEverything
call :ActivateIDM
call :AddExtensions
echo %GREEN% All Done.%RESET%
exit /b

:CleanRegistry
call :terminateProcess "IDMan.exe"
echo %YELLOW% Cleaning Registry...%RESET%
reg delete "HKLM\Software\Internet Download Manager" /f >nul 2>&1
reg delete "HKCU\Software\DownloadManager" /f >nul 2>&1
echo %GREEN% Done.%RESET%
exit /b

:quit
echo.
echo %GREEN% Goodbye! %RESET%
timeout /t 2 >nul
exit
