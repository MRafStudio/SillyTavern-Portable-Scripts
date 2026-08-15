@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

REM Обработка параметра firststart
set "FIRSTSTART=0"
if "%1"=="1" set "FIRSTSTART=1"

REM ============================================================================
REM   Установка или обновление всех компонентов Portable
REM ============================================================================

title SillyTavern Portable — Установка / Обновление всех компонентов
pushd %~dp0..

for /f %%a in ('powershell -Command "Write-Host ([char]27) -NoNewline"') do set "ESC=%%a"

cls
echo.
echo  %ESC%[1;36m################################################################################%ESC%[0m
echo  %ESC%[1;36m##                                                                            ##%ESC%[0m
echo  %ESC%[1;36m##%ESC%[0m          %ESC%[1;37mSillyTavern Portable%ESC%[0m   —   %ESC%[1;33mУстановка / Обновление всех компонентов%ESC%[0m      %ESC%[1;36m##%ESC%[0m
echo  %ESC%[1;36m##                                                                            ##%ESC%[0m
echo  %ESC%[1;36m################################################################################%ESC%[0m
echo.

REM ============================================================================
REM   ШАГ 1: Установка общего Python (если ещё не установлен)
REM ============================================================================
echo   %ESC%[1;33m→%ESC%[0m %ESC%[1mУстановка / Обновление общего Python 3.11.9...%ESC%[0m
echo.
call "%~dp0InstallOrUpdate-Python.bat" 1
if errorlevel 1 (
    echo   %ESC%[1;31m[ОШИБКА] Python не установился. Остановка.%ESC%[0m
    pause
    popd
    exit /b 1
)

echo.
echo   %ESC%[1;33m→%ESC%[0m %ESC%[1mУстановка / Обновление SillyTavern...%ESC%[0m
echo.
call "%~dp0InstallOrUpdate-SillyTavern.bat" 1
if errorlevel 1 (
    echo   %ESC%[1;31m[ОШИБКА] SillyTavern не установился. Остановка.%ESC%[0m
    pause
    popd
    exit /b 1
)

echo.
echo   %ESC%[1;33m→%ESC%[0m %ESC%[1mУстановка / Обновление KoboldCpp...%ESC%[0m
echo.
call "%~dp0InstallOrUpdate-Kobold.bat" 1
if errorlevel 1 (
    echo   %ESC%[1;31m[ОШИБКА] Kobold не установился. Остановка.%ESC%[0m
    pause
    popd
    exit /b 1
)

echo.
echo   %ESC%[1;33m→%ESC%[0m %ESC%[1mУстановка / Обновление Silero TTS...%ESC%[0m
echo.
call "%~dp0InstallOrUpdate-Silero-v2.bat" 1
REM call "%~dp0InstallOrUpdate-Silero.bat" 1
if errorlevel 1 (
    echo   %ESC%[1;31m[ОШИБКА] Silero не установился. Остановка.%ESC%[0m
    pause
    popd
    exit /b 1
)

echo.
echo   %ESC%[1;33m→%ESC%[0m %ESC%[1mУстановка / Обновление Marian NMT...%ESC%[0m
echo.
call "%~dp0InstallOrUpdate-Marian.bat" 1
if errorlevel 1 (
    echo   %ESC%[1;31m[ОШИБКА] Marian не установился. Остановка.%ESC%[0m
    pause
    popd
    exit /b 1
)

cls
echo.
echo  %ESC%[1;32m  ✔   Все компоненты успешно установлены / обновлены!%ESC%[0m
echo.
echo   %ESC%[1;33mУстановленные компоненты:%ESC%[0m
echo     %ESC%[2m- Python 3.11.9 ^(общий^)%ESC%[0m
echo     %ESC%[2m- SillyTavern%ESC%[0m
echo     %ESC%[2m- KoboldCpp%ESC%[0m
echo     %ESC%[2m- Silero TTS v2%ESC%[0m
REM echo     %ESC%[2m- Silero TTS%ESC%[0m
echo     %ESC%[2m- Marian NMT%ESC%[0m
echo.

if "%FIRSTSTART%"=="1" (
	echo   %ESC%[1;33mТеперь необходимо выбрать LLM модель для работы KoboldCpp.%ESC%[0m
	pause
	
	call "%~dp0Download-Model.bat" 1
	popd
	exit /b 0	
)
pause

popd
exit /b 0