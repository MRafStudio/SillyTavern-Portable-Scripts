@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

REM ============================================================================
REM   SillyTavern Portable — Главное меню
REM ============================================================================

title SillyTavern Portable — Главное меню
pushd %~dp0

REM Получаем ESC-символ для ANSI-цветов
for /f %%a in ('powershell -Command "Write-Host ([char]27) -NoNewline"') do set "ESC=%%a"

:menu
cls
echo.
echo  %ESC%[1;36m################################################################################%ESC%[0m
echo  %ESC%[1;36m##                                                                            ##%ESC%[0m
echo  %ESC%[1;36m##%ESC%[0m                   %ESC%[1;37mSillyTavern Portable%ESC%[0m   —   %ESC%[1;33mГлавное меню%ESC%[0m                  %ESC%[1;36m##%ESC%[0m
echo  %ESC%[1;36m##                                                                            ##%ESC%[0m
echo  %ESC%[1;36m################################################################################%ESC%[0m
echo.

REM ============================================================================
REM   Проверка статуса установки компонентов
REM ============================================================================
echo   %ESC%[1;33mСтатус компонентов:%ESC%[0m

REM Проверка Python (общий)
if exist "python-3.11.9\python.exe" (
    echo     %ESC%[1;32m✔  %ESC%[0m Python 3.11.9 %ESC%[2m^(общий^)%ESC%[0m
) else (
    echo     %ESC%[1;31m✗  %ESC%[0m Python 3.11.9 %ESC%[2m^(общий^) — не установлен%ESC%[0m
)

REM Проверка SillyTavern
if exist "SillyTavern\package.json" (
    set "ST_INSTALLED=1"
    echo     %ESC%[1;32m✔  %ESC%[0m SillyTavern
) else (
    set "ST_INSTALLED=0"
    echo     %ESC%[1;31m✗  %ESC%[0m SillyTavern — не установлен
)

REM Проверка Llama.cpp
if exist "data\llama\llama-server.exe" (
    set "LLAMA_INSTALLED=1"
    sc query "LlamaCPP-ST" >nul 2>&1
    if not errorlevel 1 (
        echo     %ESC%[1;32m✔  %ESC%[0m Llama.cpp %ESC%[2m^(служба LlamaCPP-ST^)%ESC%[0m
    ) else (
        echo     %ESC%[1;32m✔  %ESC%[0m Llama.cpp %ESC%[2m^(служба не установлена — [4]^)%ESC%[0m
    )
) else (
    set "LLAMA_INSTALLED=0"
    echo     %ESC%[1;31m✗  %ESC%[0m Llama.cpp — не установлен
)

REM Проверка Silero TTS
if exist "tts-cpu\silero_server_v2.py" (
    echo     %ESC%[1;32m✔  %ESC%[0m Silero TTS v2
) else (
    echo     %ESC%[1;31m✗  %ESC%[0m Silero TTS v2 — не установлен
)

REM Проверка Marian NMT
if exist "marian\marian_server.py" (
    echo     %ESC%[1;32m✔  %ESC%[0m Marian NMT
) else (
    echo     %ESC%[1;31m✗  %ESC%[0m Marian NMT — не установлен
)

echo.
echo   %ESC%[1;37m[1]%ESC%[0m %ESC%[1mУстановка / Обновление компонентов%ESC%[0m
echo   %ESC%[1;37m[2]%ESC%[0m %ESC%[1mНастройка компонентов%ESC%[0m
echo   %ESC%[1;37m[3]%ESC%[0m %ESC%[1mЗагрузка LLM моделей%ESC%[0m
echo   %ESC%[1;37m[4]%ESC%[0m %ESC%[1mСлужба LLM ^(llama.cpp, 24/7^)%ESC%[0m
echo.

REM Условный цвет для пункта запуска
if "!ST_INSTALLED!"=="1" (
    echo   %ESC%[1;37m[*]%ESC%[0m %ESC%[1mЗапуск SillyTavern%ESC%[0m %ESC%[2m^(по умолчанию, Enter^)%ESC%[0m
) else (
    echo   %ESC%[1;30m[*]%ESC%[0m %ESC%[1;30mЗапуск SillyTavern%ESC%[0m %ESC%[2m^(не установлен, выполните установку^)%ESC%[0m
)

echo.
echo   %ESC%[1;37m[0]%ESC%[0m %ESC%[1mВыход%ESC%[0m
echo.
set "choice="
set /p "choice=%ESC%[33mВыберите действие (0-3, Enter для запуска): %ESC%[0m"

REM Удаляем возможные пробелы
set "choice=%choice: =%"

REM Если ничего не ввели — переходим к запуску
if "%choice%"=="" goto run
if "%choice%"==" =" goto run
if "%choice%"=="*" goto run
if "%choice%"=="1" goto setup
if "%choice%"=="2" goto config
if "%choice%"=="3" goto download_model
if "%choice%"=="4" goto llama_service
if "%choice%"=="0" goto exit
goto menu

:run
if "!ST_INSTALLED!"=="0" (
    cls
    echo.
    echo   %ESC%[1;31m^[ОШИБКА^] SillyTavern не установлен!%ESC%[0m
    echo   %ESC%[33m       Запустите установку через пункт меню [1]%ESC%[0m
    echo.
    pause
    goto menu
)
cls
echo.
echo   %ESC%[1;33m→%ESC%[0m %ESC%[1mЗапуск SillyTavern...%ESC%[0m
echo.
call "%~dp0scripts\StartSillyTavern.bat"
pause
goto menu

:setup
call "%~dp0scripts\InstallOrUpdate.bat"
goto menu

:config
call "%~dp0scripts\Config.bat"
goto menu

:download_model
call "%~dp0scripts\Download-Model.bat" 0
goto menu

:llama_service
call "%~dp0scripts\Llama-Service.bat"
goto menu

:exit
popd
exit /b 0