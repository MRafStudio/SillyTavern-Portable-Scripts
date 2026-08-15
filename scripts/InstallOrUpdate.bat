@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

title SillyTavern Portable — Установка / Обновление компонентов
pushd %~dp0..

for /f %%a in ('powershell -Command "Write-Host ([char]27) -NoNewline"') do set "ESC=%%a"

:menu
cls
echo.
echo  %ESC%[1;36m################################################################################%ESC%[0m
echo  %ESC%[1;36m##                                                                            ##%ESC%[0m
echo  %ESC%[1;36m##%ESC%[0m       %ESC%[1;37mSillyTavern Portable%ESC%[0m   —   %ESC%[1;33mУстановка / Обновление компонентов%ESC%[0m        %ESC%[1;36m##%ESC%[0m
echo  %ESC%[1;36m##                                                                            ##%ESC%[0m
echo  %ESC%[1;36m################################################################################%ESC%[0m
echo.

REM ============================================================================
REM   Проверка статуса установки компонентов
REM ============================================================================

REM Python
if exist "python-3.11.9\python.exe" (
    set "PY_STATUS=Обновить"
    set "PY_COLOR=%ESC%[1;32m"
    set "PY_INSTALLED=1"
) else (
    set "PY_STATUS=Установить"
    set "PY_COLOR=%ESC%[1;33m"
    set "PY_INSTALLED=0"
)

REM SillyTavern
if exist "SillyTavern\package.json" (
    set "ST_STATUS=Обновить"
    set "ST_COLOR=%ESC%[1;32m"
    set "ST_INSTALLED=1"
) else (
    set "ST_STATUS=Установить"
    set "ST_COLOR=%ESC%[1;33m"
    set "ST_INSTALLED=0"
)

REM Llama.cpp
if exist "data\llama\llama-server.exe" (
    set "LLAMA_STATUS=Обновить"
    set "LLAMA_COLOR=%ESC%[1;32m"
    set "LLAMA_INSTALLED=1"
) else (
    set "LLAMA_STATUS=Установить"
    set "LLAMA_COLOR=%ESC%[1;33m"
    set "LLAMA_INSTALLED=0"
)

REM Silero TTS
if exist "tts-cpu\silero_server_v2.py" (
    set "SILERO_STATUS=Обновить"
    set "SILERO_COLOR=%ESC%[1;32m"
    set "SILERO_INSTALLED=1"
) else (
    set "SILERO_STATUS=Установить"
    set "SILERO_COLOR=%ESC%[1;33m"
    set "SILERO_INSTALLED=0"
)

REM Marian NMT
if exist "marian\marian_server.py" (
    set "MARIAN_STATUS=Обновить"
    set "MARIAN_COLOR=%ESC%[1;32m"
    set "MARIAN_INSTALLED=1"
) else (
    set "MARIAN_STATUS=Установить"
    set "MARIAN_COLOR=%ESC%[1;33m"
    set "MARIAN_INSTALLED=0"
)

REM Подсчитываем количество установленных компонентов
set /a "INSTALLED_COUNT=!PY_INSTALLED!+!ST_INSTALLED!+!LLAMA_INSTALLED!+!SILERO_INSTALLED!+!MARIAN_INSTALLED!"

REM ============================================================================
REM   Вывод меню в зависимости от статуса установки
REM ============================================================================

if !INSTALLED_COUNT!==0 (
    echo   %ESC%[1;33mНичего не установлено. Выберите действие:%ESC%[0m
    echo.
    echo   %ESC%[1;37m[1]%ESC%[0m !ST_COLOR!Установить SillyTavern Portable%ESC%[0m
    echo.
    echo   %ESC%[1;37m[0]%ESC%[0m %ESC%[1mНазад в главное меню%ESC%[0m
    echo.
	set "choice="
    set /p "choice=%ESC%[33mВыберите действие (0-1): %ESC%[0m"
    
    set "choice=!choice: =!"
    if "!choice!"=="" goto menu
    if "!choice!"=="1" goto first_start
    if "!choice!"=="0" goto exit
    goto menu
) else (
    echo   %ESC%[1;33mУстановленные компоненты:%ESC%[0m
    echo.
    if !PY_INSTALLED!==1 echo     %ESC%[1;32m✔%ESC%[0m Python 3.11.9
    if !ST_INSTALLED!==1 echo     %ESC%[1;32m✔%ESC%[0m SillyTavern
    if !LLAMA_INSTALLED!==1 echo     %ESC%[1;32m✔%ESC%[0m Llama.cpp
    if !SILERO_INSTALLED!==1 echo     %ESC%[1;32m✔%ESC%[0m Silero TTS v2
    if !MARIAN_INSTALLED!==1 echo     %ESC%[1;32m✔%ESC%[0m Marian NMT
    echo.
    echo   %ESC%[1;33mВыберите действие:%ESC%[0m
    echo.
    echo   %ESC%[1;37m[1]%ESC%[0m !PY_COLOR!!PY_STATUS! Python 3.11.9%ESC%[0m
    echo   %ESC%[1;37m[2]%ESC%[0m !ST_COLOR!!ST_STATUS! SillyTavern%ESC%[0m
    echo   %ESC%[1;37m[3]%ESC%[0m !LLAMA_COLOR!!LLAMA_STATUS! Llama.cpp%ESC%[0m
    echo   %ESC%[1;37m[4]%ESC%[0m !SILERO_COLOR!!SILERO_STATUS! Silero TTS v2%ESC%[0m
    echo   %ESC%[1;37m[5]%ESC%[0m !MARIAN_COLOR!!MARIAN_STATUS! Marian NMT%ESC%[0m
    echo.
    echo   %ESC%[1;37m[8]%ESC%[0m %ESC%[1mОбновить все компоненты%ESC%[0m
    echo.
    echo   %ESC%[1;37m[0]%ESC%[0m %ESC%[1mНазад в главное меню%ESC%[0m
    echo.
	set "choice="
    set /p "choice=%ESC%[33mВыберите действие (0-8): %ESC%[0m"
    
    set "choice=!choice: =!"
    if "!choice!"=="" goto menu
    if "!choice!"=="1" goto install_python
    if "!choice!"=="2" goto install_silly
    if "!choice!"=="3" goto install_llama
    if "!choice!"=="4" goto install_silero
    if "!choice!"=="5" goto install_marian
    if "!choice!"=="8" goto install_all
    if "!choice!"=="0" goto exit
    goto menu
)

:first_start
cls
echo.
echo   %ESC%[1;33m→%ESC%[0m %ESC%[1mЗапуск установки всех компонентов...%ESC%[0m
echo.
call "%~dp0InstallOrUpdate-All.bat" 1
goto menu

:install_all
cls
echo.
echo   %ESC%[1;33m→%ESC%[0m %ESC%[1mЗапуск обновления всех компонентов...%ESC%[0m
echo.
call "%~dp0InstallOrUpdate-All.bat" 0
goto menu

:install_python
cls
echo.
echo   %ESC%[1;33m→%ESC%[0m %ESC%[1mЗапуск !PY_STATUS! Python 3.11.9...%ESC%[0m
echo.
call "%~dp0InstallOrUpdate-Python.bat" 0
goto menu

:install_silly
cls
echo.
echo   %ESC%[1;33m→%ESC%[0m %ESC%[1mЗапуск !ST_STATUS! SillyTavern...%ESC%[0m
echo.
call "%~dp0InstallOrUpdate-SillyTavern.bat" 0
goto menu

:install_llama
cls
echo.
echo   %ESC%[1;33m→%ESC%[0m %ESC%[1mЗапуск !LLAMA_STATUS! Llama.cpp...%ESC%[0m
echo.
call "%~dp0InstallOrUpdate-Llama.bat" 0
goto menu

:install_silero
cls
echo.
echo   %ESC%[1;33m→%ESC%[0m %ESC%[1mЗапуск !SILERO_STATUS! Silero TTS...%ESC%[0m
echo.
call "%~dp0InstallOrUpdate-Silero-v2.bat" 0
REM call "%~dp0InstallOrUpdate-Silero.bat" 0
goto menu

:install_marian
cls
echo.
echo   %ESC%[1;33m→%ESC%[0m %ESC%[1mЗапуск !MARIAN_STATUS! Marian NMT...%ESC%[0m
echo.
call "%~dp0InstallOrUpdate-Marian.bat" 0
goto menu

:exit
popd
exit /b 0