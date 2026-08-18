@echo off
setlocal
rem ============================================================================
rem  Play Crimson Desert (RX 580)  --  AMD shader-cache guard + launcher
rem ============================================================================
rem
rem  WHAT THIS DOES
rem    Before starting Crimson Desert it looks at two AMD driver cache folders:
rem        %LOCALAPPDATA%\AMD\DxcCache    (compiled DX12 / DXIL shaders)
rem        %LOCALAPPDATA%\AMD\VkCache     (compiled Vulkan pipelines)
rem    If DxcCache is bigger than 1500 MB, or VkCache bigger than 512 MB, it
rem    deletes the FILES INSIDE those two folders and nothing else. Then it
rem    prints your free RAM and your Windows commit limit, and starts the game.
rem
rem  WHY
rem    On an 8 GB RX 580 box, DxcCache grew to 4.0 GB. Crimson Desert then
rem    committed 30,916 MB against a 32,318 MB Windows commit limit, i.e. it
rem    left only 805 MB of headroom. The game's shader-compile worker died
rem    silently and the game sat on "Compiling Shaders" forever, showing a
rem    black frame at 82 fps. Emptying DxcCache dropped peak commit from
rem    30,916 MB to 8,768 MB and the game reached actual gameplay.
rem
rem  IS IT SAFE
rem    Yes. Both folders are pure caches owned by the AMD driver. The driver
rem    recreates and refills them by itself. The only cost is that the first
rem    launch after a clean is slower, because shaders compile again.
rem    The script deletes the CONTENTS and keeps the folders, so the driver
rem    does not have to recreate the directories.
rem    It never touches your game files, your saves, or your settings.
rem    It never touches %LOCALAPPDATA%\AMD\DxCache - note the spelling, no
rem    second 'c'. That is a different folder that the Radeon service holds
rem    open, and the checks below reject it by name.
rem    Before any delete it verifies that the resolved path sits under
rem    ...\AMD\ and that its last folder name is exactly DxcCache or VkCache.
rem    If any check fails, nothing is deleted and the game still starts.
rem
rem  TUNING
rem    Thresholds are in MB and can be overridden without editing this file:
rem        set RX580_DXC_LIMIT_MB=800
rem        set RX580_VK_LIMIT_MB=256
rem    Set them to a huge number to effectively disable cleaning.
rem
rem  IF YOU DO NOT WANT A LAUNCHER
rem    You do not need this file at all. Deleting the contents of
rem    %LOCALAPPDATA%\AMD\DxcCache by hand in Explorer does the same job.
rem
rem  LOG
rem    Every run appends one line to
rem        %LOCALAPPDATA%\AMD\rx580-cache-guard.log
rem ============================================================================


rem ---------------------------------------------------------------------------
rem  Game path fallback. Only used if CrimsonDesert.exe is not found next to
rem  this .cmd, one folder up, or in a bin64 subfolder. Edit the path below to
rem  match your install if none of those apply. An existing GAME_EXE
rem  environment variable wins over this line.
rem ---------------------------------------------------------------------------
if not defined GAME_EXE set "GAME_EXE=D:\ALL GAMES\Crimson-Desert\Crimson Desert\bin64\CrimsonDesert.exe"


title Crimson Desert - RX 580 cache guard

echo.
echo  ============================================================
echo   Crimson Desert - RX 580 shader-cache guard
echo   Keeps the AMD shader cache from eating the commit limit.
echo  ============================================================
echo.

if not defined LOCALAPPDATA echo   [SKIP] LOCALAPPDATA is not set - skipping the cache check.
if not defined LOCALAPPDATA goto :findgame


rem ---------------------------------------------------------------------------
rem  Everything below is one inline PowerShell program. It is built up in
rem  pieces purely so it stays readable. It uses single quotes only, so that
rem  no quote inside it can collide with the quotes cmd.exe needs.
rem  It measures both caches, empties them if they are over budget, reports
rem  memory, and appends the log line.
rem ---------------------------------------------------------------------------
set "_PSCMD="
set "_PSCMD=%_PSCMD% $ErrorActionPreference='SilentlyContinue';"
set "_PSCMD=%_PSCMD% $base=$env:LOCALAPPDATA;"
set "_PSCMD=%_PSCMD% if([string]::IsNullOrWhiteSpace($base)){Write-Host '   [SKIP] LOCALAPPDATA is empty - refusing to touch anything.';exit 0};"
set "_PSCMD=%_PSCMD% $amd=Join-Path $base 'AMD';"

rem -- read an MB threshold from the environment, fall back to the default ----
set "_PSCMD=%_PSCMD% function Lim($n,$d){$v=[Environment]::GetEnvironmentVariable($n);$i=0;if($v -and [int]::TryParse($v.Trim(),[ref]$i) -and $i -ge 0){return $i};return $d};"

rem -- pretty-print a size ---------------------------------------------------
set "_PSCMD=%_PSCMD% function Fmt($m){if($m -lt 0){return 'not present'};return ([string]$m+' MB')};"

rem -- total size of a folder in MB, -1 when the folder does not exist -------
set "_PSCMD=%_PSCMD% function SizeMB($p){if(-not (Test-Path -LiteralPath $p -PathType Container)){return -1};$b=0;Get-ChildItem -LiteralPath $p -Recurse -Force -File -ErrorAction SilentlyContinue | ForEach-Object {$b=$b+$_.Length};return [math]::Round($b/1MB,1)};"

rem -- SAFETY GATE. Returns a path only if it is really ...\AMD\<leaf> and the
rem -- leaf name matches exactly. 'DxCache' can never match 'DxcCache' here. --
set "_PSCMD=%_PSCMD% function SafePath($leaf){$p=Join-Path $amd $leaf;"
set "_PSCMD=%_PSCMD% if(-not (Test-Path -LiteralPath $p -PathType Container)){return $null};"
set "_PSCMD=%_PSCMD% $f=(Get-Item -LiteralPath $p -Force).FullName.TrimEnd('\');"
set "_PSCMD=%_PSCMD% if($f.Length -lt 10){return $null};"
set "_PSCMD=%_PSCMD% if($f -notlike '*\AMD\*'){return $null};"
set "_PSCMD=%_PSCMD% if((Split-Path $f -Leaf) -ne $leaf){return $null};"
set "_PSCMD=%_PSCMD% if((Split-Path (Split-Path $f -Parent) -Leaf) -ne 'AMD'){return $null};"
set "_PSCMD=%_PSCMD% return $f};"

rem -- delete the contents of a validated folder, keep the folder itself -----
rem -- SilentlyContinue everywhere so a file locked by the driver cannot ------
rem -- stop the launch. ------------------------------------------------------
set "_PSCMD=%_PSCMD% function Purge($leaf){$t=SafePath $leaf;"
set "_PSCMD=%_PSCMD% if($null -eq $t){Write-Host ('   [SKIP]  safety check failed for '+$leaf+' - nothing was deleted.');return $false};"
set "_PSCMD=%_PSCMD% $n=0;Get-ChildItem -LiteralPath $t -Force -ErrorAction SilentlyContinue | ForEach-Object {Remove-Item -LiteralPath $_.FullName -Recurse -Force -ErrorAction SilentlyContinue;$n=$n+1};"
set "_PSCMD=%_PSCMD% Write-Host ('   [CLEAN] emptied '+$t);"
set "_PSCMD=%_PSCMD% Write-Host ('           '+$n+' entries removed, folder kept. Next launch compiles shaders again.');"
set "_PSCMD=%_PSCMD% return $true};"

rem -- measure ---------------------------------------------------------------
set "_PSCMD=%_PSCMD% $dxcLim=Lim 'RX580_DXC_LIMIT_MB' 1500;"
set "_PSCMD=%_PSCMD% $vkLim=Lim 'RX580_VK_LIMIT_MB' 512;"
set "_PSCMD=%_PSCMD% $dxc=SizeMB (Join-Path $amd 'DxcCache');"
set "_PSCMD=%_PSCMD% $vk=SizeMB (Join-Path $amd 'VkCache');"
set "_PSCMD=%_PSCMD% Write-Host '  --- AMD driver shader caches -------------------------------';"
set "_PSCMD=%_PSCMD% Write-Host ('   DxcCache  DX12 shaders    : '+(Fmt $dxc).PadRight(14)+'clean above '+$dxcLim+' MB');"
set "_PSCMD=%_PSCMD% Write-Host ('   VkCache   Vulkan pipes    : '+(Fmt $vk).PadRight(14)+'clean above '+$vkLim+' MB');"

rem -- clean if over budget --------------------------------------------------
set "_PSCMD=%_PSCMD% $did=@();"
set "_PSCMD=%_PSCMD% if($dxc -gt $dxcLim){if(Purge 'DxcCache'){$did=$did+'DxcCache'}}elseif($dxc -lt 0){Write-Host '   DxcCache does not exist yet - nothing to do.'}else{Write-Host '   DxcCache is within budget - left untouched.'};"
set "_PSCMD=%_PSCMD% if($vk -gt $vkLim){if(Purge 'VkCache'){$did=$did+'VkCache'}}elseif($vk -lt 0){Write-Host '   VkCache does not exist yet - nothing to do.'}else{Write-Host '   VkCache is within budget - left untouched.'};"

rem -- memory report ---------------------------------------------------------
set "_PSCMD=%_PSCMD% $ram=-1;$climit=-1;$cavail=-1;"
set "_PSCMD=%_PSCMD% try{$o=Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop;$ram=[int][math]::Round($o.FreePhysicalMemory/1024);$climit=[int][math]::Round($o.TotalVirtualMemorySize/1024);$cavail=[int][math]::Round($o.FreeVirtualMemory/1024)}catch{};"
set "_PSCMD=%_PSCMD% Write-Host '';"
set "_PSCMD=%_PSCMD% Write-Host '  --- memory -------------------------------------------------';"
set "_PSCMD=%_PSCMD% Write-Host ('   Free physical RAM        : '+$ram+' MB');"
set "_PSCMD=%_PSCMD% Write-Host ('   Windows commit limit     : '+$climit+' MB');"
set "_PSCMD=%_PSCMD% Write-Host ('   Windows commit available : '+$cavail+' MB');"
set "_PSCMD=%_PSCMD% if($cavail -ge 0 -and $cavail -lt 4000){Write-Host '';Write-Host '   *** WARNING: under 4000 MB of commit is available even after cleaning.';Write-Host '   *** Crimson Desert has hung on the Compiling Shaders screen in this';Write-Host '   *** state. Close browsers and other games, or raise your pagefile.'};"

rem -- log line --------------------------------------------------------------
set "_PSCMD=%_PSCMD% $dir=$amd;if(-not (Test-Path -LiteralPath $dir -PathType Container)){$dir=$base};"
set "_PSCMD=%_PSCMD% $log=Join-Path $dir 'rx580-cache-guard.log';"
set "_PSCMD=%_PSCMD% $what='none';if($did.Count -gt 0){$what=($did -join '+')};"
set "_PSCMD=%_PSCMD% Add-Content -LiteralPath $log -Value ((Get-Date).ToString('yyyy-MM-dd HH:mm:ss')+'  DxcCache='+(Fmt $dxc)+' limit='+$dxcLim+'MB  VkCache='+(Fmt $vk)+' limit='+$vkLim+'MB  cleaned='+$what+'  freeRAM='+$ram+'MB  commitLimit='+$climit+'MB  commitAvail='+$cavail+'MB') -ErrorAction SilentlyContinue;"
set "_PSCMD=%_PSCMD% Write-Host '';"
set "_PSCMD=%_PSCMD% Write-Host ('   log: '+$log);"

powershell -NoProfile -ExecutionPolicy Bypass -Command "%_PSCMD%"
if errorlevel 1 echo   [WARN] the cache check did not complete cleanly - launching anyway.


rem ---------------------------------------------------------------------------
rem  Find CrimsonDesert.exe. Order: next to this file, one folder up,
rem  bin64 subfolder, then the GAME_EXE fallback above. Nothing is launched
rem  unless the file actually exists.
rem ---------------------------------------------------------------------------
:findgame
set "_EXE="
if exist "%~dp0CrimsonDesert.exe" set "_EXE=%~dp0CrimsonDesert.exe"
if not defined _EXE if exist "%~dp0..\CrimsonDesert.exe" set "_EXE=%~dp0..\CrimsonDesert.exe"
if not defined _EXE if exist "%~dp0bin64\CrimsonDesert.exe" set "_EXE=%~dp0bin64\CrimsonDesert.exe"
if not defined _EXE if defined GAME_EXE if exist "%GAME_EXE%" set "_EXE=%GAME_EXE%"
if not defined _EXE goto :nogame

set "_FULL="
set "_DIR="
for %%I in ("%_EXE%") do (
  set "_FULL=%%~fI"
  set "_DIR=%%~dpI"
)
if not defined _FULL goto :nogame
if "%_DIR:~-1%"=="\" set "_DIR=%_DIR:~0,-1%"

echo.
echo  ============================================================
echo   Launching "%_FULL%"
echo  ============================================================
echo.
timeout /t 3 /nobreak >nul 2>nul
start "" /D "%_DIR%" "%_FULL%"
exit /b 0


:nogame
echo.
echo   [ERROR] CrimsonDesert.exe was not found. Nothing was launched.
echo.
echo   Looked for it here:
echo     "%~dp0CrimsonDesert.exe"
echo     "%~dp0..\CrimsonDesert.exe"
echo     "%~dp0bin64\CrimsonDesert.exe"
echo     "%GAME_EXE%"
echo.
echo   Two ways to fix it:
echo     1. Copy this .cmd into the folder that contains CrimsonDesert.exe
echo        - usually ...\Crimson Desert\bin64\ - and run it from there.
echo     2. Or open this .cmd in Notepad, find the GAME_EXE line near the
echo        top, and set it to the full path of CrimsonDesert.exe.
echo.
pause
exit /b 2
