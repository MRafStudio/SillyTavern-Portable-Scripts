@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

REM ============================================================================
REM   Silero TTS Portable — установка / обновление (русская версия)
REM ============================================================================
REM   Использует общий Python из python-3.11.9 (устанавливается отдельно)
REM ============================================================================

title Silero TTS Portable — Установка / Обновление

REM Обработка параметра autoclose
set "AUTOCLOSE=0"
if "%1"=="1" set "AUTOCLOSE=1"

REM Переходим в корневую папку портативной установки
pushd %~dp0..

for /f %%a in ('powershell -Command "Write-Host ([char]27) -NoNewline"') do set "ESC=%%a"

cls
::echo %AUTOCLOSE%
echo.
echo  %ESC%[1;36m################################################################################%ESC%[0m
echo  %ESC%[1;36m##                                                                            ##%ESC%[0m
echo  %ESC%[1;36m##%ESC%[0m             %ESC%[1;37mSilero TTS Portable%ESC%[0m   —   %ESC%[1;33mУстановка / Обновление%ESC%[0m               %ESC%[1;36m##%ESC%[0m
echo  %ESC%[1;36m##                                                                            ##%ESC%[0m
echo  %ESC%[1;36m################################################################################%ESC%[0m
echo.

REM ============================================================================
REM   ШАГ 0: Проверка разрядности системы
REM ============================================================================
echo   %ESC%[1;33m[0/5]%ESC%[0m %ESC%[1mПроверка разрядности Windows...%ESC%[0m
set ARCH_OK=0
if "%PROCESSOR_ARCHITECTURE%"=="AMD64" set ARCH_OK=1
if "%PROCESSOR_ARCHITEW6432%"=="AMD64" set ARCH_OK=1

if %ARCH_OK%==0 (
    echo.
    echo   %ESC%[1;31m^[ОШИБКА^] Обнаружена 32-разрядная ^(x86^) версия Windows.%ESC%[0m
    echo   %ESC%[33m   Silero TTS Portable требует 64-разрядную систему ^(x64^).%ESC%[0m
    echo.
    if "%AUTOCLOSE%"=="0" pause
    popd
    exit /b 1
)
echo   %ESC%[1;32m  ✔   Система 64-разрядная (x64).%ESC%[0m
echo.

REM ============================================================================
REM   ШАГ 1: Определение путей
REM ============================================================================
set "TTS_HOME=%~dp0..\tts-cpu"
set "PYTHON_DIR=%~dp0..\python-3.11.9"
set "PYTHON_EXE=%PYTHON_DIR%\python.exe"
set "VENV=%TTS_HOME%\.venv"
set "VENV_PYTHON=%VENV%\Scripts\python.exe"

if not exist "%TTS_HOME%" mkdir "%TTS_HOME%"

REM ============================================================================
REM   ШАГ 2: Проверка наличия общего Python
REM ============================================================================
echo   %ESC%[1;33m[1/5]%ESC%[0m %ESC%[1mПроверка общего Python...%ESC%[0m

if not exist "%PYTHON_EXE%" (
    echo   %ESC%[1;31m^[ОШИБКА^] Общий Python не найден.%ESC%[0m
    echo   %ESC%[33m       Запустите InstallOrUpdate-Python.bat или установку всех модулей.%ESC%[0m
    if "%AUTOCLOSE%"=="0" pause
    popd
    exit /b 1
)

set /p "=%ESC%[2m       Версия: %ESC%[0m" <nul
"%PYTHON_EXE%" --version 2>nul
echo.
echo.

REM ============================================================================
REM   ШАГ 3: Создание виртуального окружения Silero
REM ============================================================================
echo   %ESC%[1;33m[2/5]%ESC%[0m %ESC%[1mНастройка виртуального окружения Silero...%ESC%[0m

if exist "%VENV_PYTHON%" (
    echo   %ESC%[32m  ✔   Виртуальное окружение уже существует.%ESC%[0m
) else (
    echo   %ESC%[33m  →   Создание виртуального окружения...%ESC%[0m
    "%PYTHON_EXE%" -m venv "%VENV%"
    if !errorlevel! neq 0 (
        echo   %ESC%[1;31m^[ОШИБКА^] Не удалось создать виртуальное окружение.%ESC%[0m
        if "%AUTOCLOSE%"=="0" pause
        popd
        exit /b 1
    )
    echo   %ESC%[32m  ✔   Виртуальное окружение создано.%ESC%[0m
)
echo.

REM ============================================================================
REM   ШАГ 4: Установка зависимостей Python
REM ============================================================================
echo   %ESC%[1;33m[3/5]%ESC%[0m %ESC%[1mУстановка зависимостей...%ESC%[0m
echo   %ESC%[2m       (torch, torchaudio, fastapi, uvicorn, pydub, numpy, scipy, imageio-ffmpeg)%ESC%[0m
echo   %ESC%[2m       Это может занять несколько минут при первом запуске...%ESC%[0m

"%VENV_PYTHON%" -c "import fastapi, uvicorn, numpy, pydub, scipy, torch, imageio_ffmpeg" 1>nul 2>nul
if !errorlevel! equ 0 (
    echo   %ESC%[32m  ✔   Зависимости уже установлены.%ESC%[0m
) else (
    echo   %ESC%[33m  →   Установка зависимостей...%ESC%[0m
    
    echo   %ESC%[2m       [1/4] Обновление pip...%ESC%[0m
    "%VENV_PYTHON%" -m pip cache purge >nul 2>nul
    "%VENV_PYTHON%" -m pip install --upgrade pip --quiet
    
    echo   %ESC%[2m       [2/4] Установка PyTorch...%ESC%[0m
    "%VENV_PYTHON%" -m pip install torch torchaudio --index-url https://download.pytorch.org/whl/cpu --quiet
    if !errorlevel! neq 0 (
        echo   %ESC%[1;31m^[ОШИБКА^] Не удалось установить PyTorch.%ESC%[0m
        if "%AUTOCLOSE%"=="0" pause
        popd
        exit /b 1
    )
    
    echo   %ESC%[2m       [3/4] Установка FastAPI и утилит...%ESC%[0m
    "%VENV_PYTHON%" -m pip install fastapi uvicorn pydub numpy scipy --quiet
    if !errorlevel! neq 0 (
        echo   %ESC%[1;31m^[ОШИБКА^] Не удалось установить зависимости.%ESC%[0m
        if "%AUTOCLOSE%"=="0" pause
        popd
        exit /b 1
    )
    
    echo   %ESC%[2m       [4/4] Установка imageio-ffmpeg...%ESC%[0m
    "%VENV_PYTHON%" -m pip install imageio-ffmpeg --quiet
    if !errorlevel! neq 0 (
        echo   %ESC%[1;31m^[ОШИБКА^] Не удалось установить imageio-ffmpeg.%ESC%[0m
        if "%AUTOCLOSE%"=="0" pause
        popd
        exit /b 1
    )
    
    echo   %ESC%[32m  ✔   Зависимости успешно установлены.%ESC%[0m
)
echo.

REM ============================================================================
REM   ШАГ 5: Настройка ffmpeg
REM ============================================================================
echo   %ESC%[1;33m[4/5]%ESC%[0m %ESC%[1mНастройка ffmpeg...%ESC%[0m

set "FFMPEG_DIR=%TTS_HOME%\ffmpeg"
set "FFMPEG_EXE=%FFMPEG_DIR%\ffmpeg.exe"

if exist "%FFMPEG_EXE%" (
    echo   %ESC%[32m  ✔   ffmpeg уже установлен.%ESC%[0m
) else (
    echo   %ESC%[33m  →   Установка ffmpeg...%ESC%[0m
    if not exist "%FFMPEG_DIR%" mkdir "%FFMPEG_DIR%"
    
    for /f "delims=" %%i in ('dir /s /b "%VENV%\Lib\site-packages\imageio_ffmpeg\*.exe" 2^>nul') do (
        copy "%%i" "%FFMPEG_EXE%" >nul
        goto :ffmpeg_copied
    )
    echo   %ESC%[1;31m^[ОШИБКА^] Не удалось найти ffmpeg.exe.%ESC%[0m
    if "%AUTOCLOSE%"=="0" pause
    popd
    exit /b 1
    
    :ffmpeg_copied
    echo   %ESC%[32m  ✔   ffmpeg успешно установлен.%ESC%[0m
)

REM ============================================================================
REM   ШАГ 6: Загрузка модели и копирование серверного скрипта
REM ============================================================================
echo   %ESC%[1;33m[5/5]%ESC%[0m %ESC%[1mЗагрузка модели и установка серверного скрипта...%ESC%[0m

set "SILERO_MODEL_DIR=%TTS_HOME%\silero"
set "SILERO_MODEL_PATH=%SILERO_MODEL_DIR%\v5_ru.pt"

if not exist "%SILERO_MODEL_DIR%" mkdir "%SILERO_MODEL_DIR%"

if exist "%SILERO_MODEL_PATH%" (
    echo   %ESC%[32m  ✔   Модель уже скачана.%ESC%[0m
) else (
    echo   %ESC%[33m  →   Загрузка модели ^(~141 МБ^)...%ESC%[0m
    "%VENV_PYTHON%" -c "import urllib.request; urllib.request.urlretrieve('https://models.silero.ai/models/tts/ru/v5_ru.pt', r'%SILERO_MODEL_PATH%')"
    if !errorlevel! neq 0 (
        echo   %ESC%[1;31m^[ОШИБКА^] Не удалось скачать модель. Проверьте интернет-соединение.%ESC%[0m
        if "%AUTOCLOSE%"=="0" pause
        popd
        exit /b 1
    )
    echo   %ESC%[32m  ✔   Модель успешно скачана.%ESC%[0m
)

REM Копирование серверного скрипта и белого списка
set "SILERO_SERVER_SRC=%~dp0..\scripts\py\silero_server.py"
set "SILERO_SERVER_DST=%TTS_HOME%\silero_server.py"
set "WHITELIST_SRC=%~dp0..\scripts\py\no_translate_words.ini"
set "WHITELIST_DST=%TTS_HOME%\no_translate_words.ini"

if exist "%SILERO_SERVER_SRC%" (
    if not exist "%SILERO_SERVER_DST%" (
        copy "%SILERO_SERVER_SRC%" "%SILERO_SERVER_DST%" >nul
        echo   %ESC%[32m  ✔   silero_server.py скопирован.%ESC%[0m
    ) else (
        echo   %ESC%[32m  ✔   silero_server.py уже существует.%ESC%[0m
    )
) else (
    echo   %ESC%[1;33m  ⚠   Не найден silero_server.py в scripts\py\%ESC%[0m
    echo   %ESC%[33m       Скопируйте файл вручную в tts-cpu\%ESC%[0m
)

if exist "%WHITELIST_SRC%" (
    if not exist "%WHITELIST_DST%" (
        copy "%WHITELIST_SRC%" "%WHITELIST_DST%" >nul
        echo   %ESC%[32m  ✔   no_translate_words.ini скопирован.%ESC%[0m
    ) else (
        echo   %ESC%[32m  ✔   no_translate_words.ini уже существует.%ESC%[0m
    )
) else (
    echo   %ESC%[1;33m  ⚠   Не найден no_translate_words.ini в scripts\py\%ESC%[0m
    echo   %ESC%[33m       Скопируйте файл вручную в tts-cpu\%ESC%[0m
)
echo.

REM ============================================================================
REM   ФИНАЛ
REM ============================================================================
echo  %ESC%[36m--------------------------------------------------------------------------------%ESC%[0m
echo   %ESC%[1;32mSilero TTS успешно установлен / обновлён!%ESC%[0m
echo.
echo   %ESC%[1;33mРасположение:%ESC%[0m
echo     %ESC%[2m  %TTS_HOME%%ESC%[0m
echo.
echo   %ESC%[2m  (Модель: v5_ru.pt, ~141 МБ)%ESC%[0m
echo   %ESC%[2m  (Серверный скрипт: silero_server.py)%ESC%[0m
echo   %ESC%[2m  (Использует общий Python: %PYTHON_DIR%)%ESC%[0m
echo  %ESC%[36m--------------------------------------------------------------------------------%ESC%[0m
echo.

if "%AUTOCLOSE%"=="0" pause
popd
exit /b 0