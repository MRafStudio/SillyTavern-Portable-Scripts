@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

REM ============================================================================
REM   SillyTavern Portable — Запуск всех сервисов
REM ============================================================================
title SillyTavern Portable — Запуск

REM Получаем ESC-символ для ANSI-цветов
for /f %%a in ('powershell -Command "Write-Host ([char]27) -NoNewline"') do set "ESC=%%a"

REM ============================================================================
REM   Загрузка настроек из settings.ini
REM ============================================================================
set "CONFIG_FILE=%~dp0settings.ini"

if not exist "%CONFIG_FILE%" (
    echo.
    echo   %ESC%[1;31m^[ОШИБКА^] Файл настроек не найден:%ESC%[0m
    echo   %ESC%[33m       %CONFIG_FILE%%ESC%[0m
    echo   %ESC%[33m       Запустите настройку через меню [2]%ESC%[0m
    echo.
    pause
    exit /b 1
)

for /f "usebackq delims=" %%a in ("%CONFIG_FILE%") do set "%%a"

REM Значения по умолчанию
if not defined ENABLE_LLM set ENABLE_LLM=1
if not defined ENABLE_TTS set ENABLE_TTS=1
if not defined ENABLE_TRANSLATE set ENABLE_TRANSLATE=1
if not defined ST_PORT set ST_PORT=8000
if not defined LLM_PORT set LLM_PORT=5001
if not defined TTS_PORT set TTS_PORT=8881
if not defined TRANSLATE_PORT set TRANSLATE_PORT=5003
if not defined MODEL set MODEL=
if not defined MMPROJ set MMPROJ=
if not defined ENABLE_WHISPER set ENABLE_WHISPER=0
if not defined WHISPER_MODEL set WHISPER_MODEL=

REM === Коррекция Whisper ===
if "!WHISPER_MODEL!"=="" set ENABLE_WHISPER=0

REM ============================================================================
REM   Нормализация корневого пути (убираем scripts\.. из путей)
REM ============================================================================
for %%F in ("%~dp0..") do set "ROOT_DIR=%%~fF"

REM ============================================================================
REM   Проверка обязательных параметров
REM ============================================================================
if "!ENABLE_LLM!"=="1" (
    if "!MODEL!"=="" (
        echo.
        echo   %ESC%[1;31m^[ОШИБКА^] Модель LLM не выбрана!%ESC%[0m
        echo   %ESC%[33m       Запустите загрузку моделей через меню [3]%ESC%[0m
        echo.
        pause
        exit /b 1
    )
)

REM ============================================================================
REM   Баннер
REM ============================================================================
cls
echo.
echo  %ESC%[1;36m################################################################################%ESC%[0m
echo  %ESC%[1;36m##                                                                            ##%ESC%[0m
echo  %ESC%[1;36m##%ESC%[0m               %ESC%[1;37mSillyTavern Portable%ESC%[0m   —   %ESC%[1;33mЗапуск сервисов%ESC%[0m                   %ESC%[1;36m##%ESC%[0m
echo  %ESC%[1;36m##                                                                            ##%ESC%[0m
echo  %ESC%[1;36m################################################################################%ESC%[0m
echo.
echo   %ESC%[1;33mСтатус сервисов:%ESC%[0m
if "!ENABLE_LLM!"=="1" (
    echo     %ESC%[1;32m✔ %ESC%[0m LLM ^(KoboldCpp^)            %ESC%[2mhttp://localhost:!LLM_PORT!%ESC%[0m
) else (
    echo     %ESC%[1;31m✗ %ESC%[0m LLM ^(KoboldCpp^)            %ESC%[2mвыключен%ESC%[0m
)
if "!ENABLE_TTS!"=="1" (
    echo     %ESC%[1;32m✔ %ESC%[0m TTS ^(Silero v2^)            %ESC%[2mhttp://localhost:!TTS_PORT!%ESC%[0m
) else (
    echo     %ESC%[1;31m✗ %ESC%[0m TTS ^(Silero^)               %ESC%[2mвыключен%ESC%[0m
)
if "!ENABLE_TRANSLATE!"=="1" (
    echo     %ESC%[1;32m✔ %ESC%[0m Переводчик ^(Marian NMT^)    %ESC%[2mhttp://localhost:!TRANSLATE_PORT!%ESC%[0m
) else (
    echo     %ESC%[1;31m✗ %ESC%[0m Переводчик ^(Marian NMT^)    %ESC%[2mвыключен%ESC%[0m
)
echo     %ESC%[1;32m✔ %ESC%[0m SillyTavern UI             %ESC%[2mhttp://localhost:!ST_PORT!%ESC%[0m
echo.
echo   %ESC%[2mЗакройте это окно (или Ctrl+C) для остановки всех сервисов.%ESC%[0m
echo  %ESC%[36m--------------------------------------------------------------------------------%ESC%[0m
echo.

REM ============================================================================
REM   1. Запуск KoboldCpp (LLM)
REM ============================================================================
if "!ENABLE_LLM!"=="1" (
    echo   %ESC%[1;32m[1/4]%ESC%[0m %ESC%[1mЗапуск KoboldCpp...%ESC%[0m %ESC%[2m^(http://localhost:!LLM_PORT!^)%ESC%[0m
    set "MODELS_DIR=!ROOT_DIR!\kobold\models"
    set "KCPP_EXE=!ROOT_DIR!\kobold\koboldcpp.exe"
    set "KCPP_TEMP=!ROOT_DIR!\kobold\temp"
    set "MODEL_PATH=!MODELS_DIR!\!MODEL!"
    
    if not exist "!MODEL_PATH!" (
        echo.
        echo   %ESC%[1;31m^[ОШИБКА^] Модель не найдена:!%ESC%[0m
        echo   %ESC%[33m       !MODEL_PATH!%ESC%[0m
        echo   %ESC%[33m       Запустите загрузку моделей через меню [3]%ESC%[0m
        echo.
        pause
        exit /b 1
    )
    
    set "KCPP_SETTINGS=!ROOT_DIR!\kobold\settings\default.kcpps"
    
    REM === Проверяем/создаём default.kcpps ===
    if not exist "!KCPP_SETTINGS!" (
        set "KCPP_SETTINGS_SRC=!ROOT_DIR!\scripts\data\default.kcpps"
        if exist "!KCPP_SETTINGS_SRC!" (
            if not exist "!ROOT_DIR!\kobold\settings" mkdir "!ROOT_DIR!\kobold\settings"
            copy "!KCPP_SETTINGS_SRC!" "!KCPP_SETTINGS!" >nul
            echo   %ESC%[33m  →   Создан файл настроек KoboldCpp: settings\default.kcpps%ESC%[0m
        ) else (
            echo   %ESC%[1;33m  ⚠   Шаблон default.kcpps не найден. Запуск без файла настроек.%ESC%[0m
            set "KCPP_SETTINGS="
        )
    )
    
    REM === Формируем аргументы запуска ===
    set "KCPP_ARGS=--model "!MODEL_PATH!" --port !LLM_PORT! --skiplauncher"
    
    if not "!MMPROJ!"=="" (
        set "MMPROJ_PATH=!MODELS_DIR!\!MMPROJ!"
        if exist "!MMPROJ_PATH!" (
            set "KCPP_ARGS=!KCPP_ARGS! --mmproj "!MMPROJ_PATH!""
        )
    )
	
    REM === Whisper ===
    if "!ENABLE_WHISPER!"=="1" (
        if not "!WHISPER_MODEL!"=="" (
            set "WHISPER_PATH=!ROOT_DIR!\kobold\models\whisper\!WHISPER_MODEL!"
            if exist "!WHISPER_PATH!" (
                set "KCPP_ARGS=!KCPP_ARGS! --whispermodel "!WHISPER_PATH!""
            ) else (
                echo   %ESC%[1;33m  ⚠   Whisper модель не найдена: !WHISPER_MODEL!%ESC%[0m
                set ENABLE_WHISPER=0
            )
        )
    )
    
    if not "!KCPP_SETTINGS!"=="" (
        set "KCPP_ARGS=!KCPP_ARGS! --config "!KCPP_SETTINGS!""
    )
  
    REM === ПОРТАТИВНЫЙ TEMP для KoboldCpp (PyInstaller onefile) ===
    if not exist "!KCPP_TEMP!" mkdir "!KCPP_TEMP!"
    for /d %%D in ("!KCPP_TEMP!\_MEI*") do rmdir /s /q "%%D" 2>nul
    
    start "" /B cmd /c "set TMP=!KCPP_TEMP!&&set TEMP=!KCPP_TEMP!&&"!KCPP_EXE!" !KCPP_ARGS!"
    
    REM Ожидание готовности KoboldCpp (max 120 сек)
    echo   %ESC%[1;33m  →   Ожидание готовности KoboldCpp...%ESC%[0m
    set /a "attempts=0"
    :wait_kobold
    timeout /t 2 /nobreak >nul
    curl -s http://localhost:!LLM_PORT!/v1/models >nul 2>&1
    if not errorlevel 1 goto :kobold_ready
    set /a "attempts+=1"
    if !attempts! GEQ 60 (
        echo   %ESC%[1;31m  ✗   KoboldCpp не ответил за 120 секунд.%ESC%[0m
        echo   %ESC%[33m       Проверьте вывод выше на ошибки.%ESC%[0m
        pause
        exit /b 1
    )
    goto :wait_kobold
    :kobold_ready
    echo   %ESC%[1;32m  ✔   KoboldCpp готов!%ESC%[0m
    echo.
)

REM ============================================================================
REM   2. Запуск Marian NMT (Переводчик)
REM ============================================================================
if "!ENABLE_TRANSLATE!"=="1" (
    echo   %ESC%[1;32m[2/4]%ESC%[0m %ESC%[1mЗапуск Marian NMT...%ESC%[0m %ESC%[2m^(http://localhost:!TRANSLATE_PORT!^)%ESC%[0m
    
    set "MARIAN_HOME=!ROOT_DIR!\marian"
    set "VENV_PYTHON=!MARIAN_HOME!\.venv\Scripts\python.exe"
    set "MARIAN_SERVER=!MARIAN_HOME!\marian_server.py"
    
    if not exist "!VENV_PYTHON!" (
        echo   %ESC%[1;31m  ✗   Python-окружение Marian не найдено.%ESC%[0m
        echo   %ESC%[33m       Установите Marian через меню [1]%ESC%[0m
        pause
        exit /b 1
    )
    
    if not exist "!MARIAN_SERVER!" (
        echo   %ESC%[1;31m  ✗   Серверный скрипт Marian не найден.%ESC%[0m
        pause
        exit /b 1
    )
    
    set "MARIAN_PORT=!TRANSLATE_PORT!"
    start "" /B cmd /c "set MARIAN_PORT=!TRANSLATE_PORT! && "!VENV_PYTHON!" "!MARIAN_SERVER!""
    
    REM Ожидание готовности Marian (max 60 сек)
    echo   %ESC%[1;33m  →   Ожидание готовности Marian...%ESC%[0m
    set /a "marian_attempts=0"
    :wait_marian
    timeout /t 2 /nobreak >nul
    curl -s http://localhost:!TRANSLATE_PORT!/ >nul 2>&1
    if not errorlevel 1 goto :marian_ready
    set /a "marian_attempts+=1"
    if !marian_attempts! GEQ 30 (
        echo   %ESC%[1;33m  ⚠   Marian не ответил за 60 секунд.%ESC%[0m
        echo   %ESC%[33m       Silero будет использовать транслитерацию.%ESC%[0m
        goto :marian_skip
    )
    goto :wait_marian
    :marian_ready
    echo   %ESC%[1;32m  ✔   Marian готов!%ESC%[0m
    :marian_skip
    echo.
)

REM ============================================================================
REM   3. Запуск Silero TTS
REM ============================================================================
if "!ENABLE_TTS!"=="1" (
    echo   %ESC%[1;32m[3/4]%ESC%[0m %ESC%[1mЗапуск Silero TTS v2...%ESC%[0m %ESC%[2m^(http://localhost:!TTS_PORT!^)%ESC%[0m
    
    set "TTS_HOME=!ROOT_DIR!\tts-cpu"
    set "VENV_PYTHON=!TTS_HOME!\.venv\Scripts\python.exe"
    set "SILERO_SERVER=!TTS_HOME!\silero_server_v2.py"
    
    if not exist "!VENV_PYTHON!" (
        echo   %ESC%[1;31m  ✗   Python-окружение Silero не найдено.%ESC%[0m
        echo   %ESC%[33m       Установите Silero через меню [1]%ESC%[0m
        pause
        exit /b 1
    )
    
    if not exist "!SILERO_SERVER!" (
        echo   %ESC%[1;31m  ✗   Серверный скрипт Silero не найден.%ESC%[0m
        pause
        exit /b 1
    )
    
    set "SILERO_PORT=!TTS_PORT!"
    set "PATH=!TTS_HOME!\ffmpeg;%PATH%"
    set "TORCH_HOME=!TTS_HOME!\.cache\torch"
    start "" /B cmd /c "set SILERO_PORT=!TTS_PORT!&&set ENABLE_TRANSLATE=!ENABLE_TRANSLATE!&&set TORCH_HOME=!TORCH_HOME!&&set DEBUG_SILERO=0&&"!VENV_PYTHON!" "!SILERO_SERVER!""
    
    REM Ожидание готовности Silero (max 30 сек)
    echo   %ESC%[1;33m  →   Ожидание готовности Silero...%ESC%[0m
    set /a "silero_attempts=0"
    :wait_silero
    timeout /t 1 /nobreak >nul
    curl -s http://localhost:!TTS_PORT!/v1/models >nul 2>&1
    if not errorlevel 1 goto :silero_ready
    set /a "silero_attempts+=1"
    if !silero_attempts! GEQ 30 (
        echo   %ESC%[1;33m  ⚠   Silero не ответил за 30 секунд.%ESC%[0m
        echo   %ESC%[33m       TTS может быть недоступен.%ESC%[0m
        goto :silero_skip
    )
    goto :wait_silero
    :silero_ready
    echo   %ESC%[1;32m  ✔   Silero готов!%ESC%[0m
    :silero_skip
    echo.
)

REM ============================================================================
REM   Ожидание готовности Marian (если включен и ещё не готов)
REM ============================================================================
if "!ENABLE_TRANSLATE!"=="1" (
    echo   %ESC%[1;33m  →   Проверка готовности Marian...%ESC%[0m
    set /a "marian_check=0"
    :check_marian_ready
    curl -s http://localhost:!TRANSLATE_PORT!/ >nul 2>&1
    if not errorlevel 1 goto :marian_confirmed
    set /a "marian_check+=1"
    if !marian_check! GEQ 30 (
        echo   %ESC%[1;33m  ⚠   Marian не готов. Silero будет использовать транслитерацию.%ESC%[0m
        goto :marian_confirmed_skip
    )
    timeout /t 1 /nobreak >nul
    goto :check_marian_ready
    :marian_confirmed
    echo   %ESC%[1;32m  ✔   Marian подтверждён готов!%ESC%[0m
    :marian_confirmed_skip
    echo.
)

REM ============================================================================
REM   4. Запуск SillyTavern UI
REM ============================================================================
echo   %ESC%[1;32m[4/4]%ESC%[0m %ESC%[1mЗапуск SillyTavern...%ESC%[0m %ESC%[2m^(http://localhost:!ST_PORT!^)%ESC%[0m

set "NODE_DIR=!ROOT_DIR!\node-dist"
set "ST_DIR=!ROOT_DIR!\SillyTavern"

if not exist "%NODE_DIR%\node.exe" (
    echo   %ESC%[1;31m  ✗   Node.js не найден.%ESC%[0m
    pause
    exit /b 1
)

if not exist "%ST_DIR%\server.js" (
    echo   %ESC%[1;31m  ✗   SillyTavern не найден.%ESC%[0m
    pause
    exit /b 1
)

set "PATH=%NODE_DIR%;%PATH%"
set NODE_ENV=production

REM === Портативные env vars для SillyTavern (npm, кэши, данные) ===
set "HOME=!ROOT_DIR!"
set "USERPROFILE=!ROOT_DIR!"
set "APPDATA=!ROOT_DIR!\AppData\Roaming"
set "LOCALAPPDATA=!ROOT_DIR!\AppData\Local"
if not exist "!APPDATA!" mkdir "!APPDATA!" 2>nul
if not exist "!LOCALAPPDATA!" mkdir "!LOCALAPPDATA!" 2>nul

echo.
echo  %ESC%[36m--------------------------------------------------------------------------------%ESC%[0m
echo   %ESC%[2mВсе сервисы запущены. Откройте браузер:%ESC%[0m
echo   %ESC%[1;37mhttp://localhost:!ST_PORT!%ESC%[0m
echo  %ESC%[36m--------------------------------------------------------------------------------%ESC%[0m
echo.

"%NODE_DIR%\node.exe" "%ST_DIR%\server.js" --listen --port !ST_PORT! --browserLaunchEnabled=true %*

echo.
echo   %ESC%[1;35m-=>%ESC%[0m %ESC%[1mSillyTavern Portable остановлен.%ESC%[0m
echo.
pause
exit /b 0