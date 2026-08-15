@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

REM ============================================================================
REM   Marian NMT Portable — установка / обновление (русская версия)
REM ============================================================================
REM   Использует общий Python из python-3.11.9 (устанавливается отдельно)
REM ============================================================================

title Marian NMT Portable — Установка / Обновление

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
echo  %ESC%[1;36m##%ESC%[0m             %ESC%[1;37mMarian NMT Portable%ESC%[0m   —   %ESC%[1;33mУстановка / Обновление%ESC%[0m               %ESC%[1;36m##%ESC%[0m
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
    echo   %ESC%[33m   Marian NMT Portable требует 64-разрядную систему ^(x64^).%ESC%[0m
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
set "MARIAN_HOME=%~dp0..\marian"
set "PYTHON_DIR=%~dp0..\python-3.11.9"
set "PYTHON_EXE=%PYTHON_DIR%\python.exe"
set "VENV=%MARIAN_HOME%\.venv"
set "VENV_PYTHON=%VENV%\Scripts\python.exe"
set "CACHE_DIR=%MARIAN_HOME%\models_cache"

if not exist "%MARIAN_HOME%" mkdir "%MARIAN_HOME%"
if not exist "%CACHE_DIR%" mkdir "%CACHE_DIR%"

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
REM   ШАГ 3: Создание виртуального окружения Marian
REM ============================================================================
echo   %ESC%[1;33m[2/5]%ESC%[0m %ESC%[1mНастройка виртуального окружения Marian...%ESC%[0m

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
echo   %ESC%[2m       (transformers, torch, sentencepiece, sacremoses, protobuf, fastapi, uvicorn)%ESC%[0m
echo   %ESC%[2m       Это может занять несколько минут при первом запуске...%ESC%[0m

"%VENV_PYTHON%" -c "import transformers, torch, fastapi, uvicorn" 1>nul 2>nul
if !errorlevel! equ 0 (
    echo   %ESC%[32m  ✔   Зависимости уже установлены.%ESC%[0m
) else (
    echo   %ESC%[33m  →   Установка зависимостей...%ESC%[0m

    echo   %ESC%[2m       [1/3] Обновление pip...%ESC%[0m
    "%VENV_PYTHON%" -m pip cache purge >nul 2>nul
    "%VENV_PYTHON%" -m pip install --upgrade pip --quiet

    echo   %ESC%[2m       [2/3] Установка PyTorch...%ESC%[0m
    "%VENV_PYTHON%" -m pip install torch --index-url https://download.pytorch.org/whl/cpu --quiet
    if !errorlevel! neq 0 (
        echo   %ESC%[1;31m^[ОШИБКА^] Не удалось установить PyTorch.%ESC%[0m
        if "%AUTOCLOSE%"=="0" pause
        popd
        exit /b 1
    )

    echo   %ESC%[2m       [3/3] Установка transformers и вспомогательных библиотек...%ESC%[0m
    "%VENV_PYTHON%" -m pip install transformers sentencepiece sacremoses protobuf fastapi uvicorn --quiet
    if !errorlevel! neq 0 (
        echo   %ESC%[1;31m^[ОШИБКА^] Не удалось установить зависимости.%ESC%[0m
        if "%AUTOCLOSE%"=="0" pause
        popd
        exit /b 1
    )

    echo   %ESC%[32m  ✔   Зависимости успешно установлены.%ESC%[0m
)
echo.

REM ============================================================================
REM   ШАГ 5: Загрузка модели с правильным кэшем
REM ============================================================================
echo   %ESC%[1;33m[4/5]%ESC%[0m %ESC%[1mЗагрузка модели...%ESC%[0m
echo   %ESC%[2m       (Helsinki-NLP/opus-mt-en-ru, ~400 МБ)%ESC%[0m

if exist "%CACHE_DIR%\models--Helsinki-NLP--opus-mt-en-ru" (
    echo   %ESC%[32m  ✔   Модель уже скачана.%ESC%[0m
) else (
    echo   %ESC%[33m  →   Загрузка модели ^(~400 МБ^)...%ESC%[0m

    REM === ИСПРАВЛЕНИЕ: HF_HOME и TRANSFORMERS_CACHE задаём ДО импорта transformers ===
    set "HF_HOME=%CACHE_DIR%"
    set "TRANSFORMERS_CACHE=%CACHE_DIR%"

    "%VENV_PYTHON%" -c "import os; os.environ['HF_HOME'] = r'%CACHE_DIR%'; os.environ['TRANSFORMERS_CACHE'] = r'%CACHE_DIR%'; from pathlib import Path; from transformers import MarianMTModel, MarianTokenizer; cache_dir = Path(r'%CACHE_DIR%'); model_name = 'Helsinki-NLP/opus-mt-en-ru'; print('  Загрузка токенизатора...'); tokenizer = MarianTokenizer.from_pretrained(model_name, cache_dir=str(cache_dir)); print('  Загрузка модели...'); model = MarianMTModel.from_pretrained(model_name, cache_dir=str(cache_dir)); print('  Модель загружена')"

    if !errorlevel! neq 0 (
        echo   %ESC%[1;31m^[ОШИБКА^] Не удалось скачать модель. Проверьте интернет-соединение.%ESC%[0m
        if "%AUTOCLOSE%"=="0" pause
        popd
        exit /b 1
    )
    echo   %ESC%[32m  ✔   Модель успешно скачана.%ESC%[0m
)

REM ============================================================================
REM   ШАГ 6: Копирование серверных скриптов
REM ============================================================================
echo   %ESC%[1;33m[5/5]%ESC%[0m %ESC%[1mУстановка серверных скриптов...%ESC%[0m

set "MARIAN_SERVER_SRC=%~dp0..\scripts\py\marian_server.py"
set "MARIAN_SERVER_DST=%MARIAN_HOME%\marian_server.py"
set "DOWNLOAD_SRC=%~dp0..\scripts\py\download_marian.py"
set "DOWNLOAD_DST=%MARIAN_HOME%\download_marian.py"

if exist "%MARIAN_SERVER_SRC%" (
    if not exist "%MARIAN_SERVER_DST%" (
        copy "%MARIAN_SERVER_SRC%" "%MARIAN_SERVER_DST%" >nul
        echo   %ESC%[32m  ✔   marian_server.py скопирован.%ESC%[0m
    ) else (
        echo   %ESC%[32m  ✔   marian_server.py уже существует.%ESC%[0m
    )
) else (
    echo   %ESC%[1;33m  ⚠   Не найден marian_server.py в scripts\py\%ESC%[0m
    echo   %ESC%[33m       Скопируйте файл вручную в marian\%ESC%[0m
)

if exist "%DOWNLOAD_SRC%" (
    if not exist "%DOWNLOAD_DST%" (
        copy "%DOWNLOAD_SRC%" "%DOWNLOAD_DST%" >nul
        echo   %ESC%[32m  ✔   download_marian.py скопирован.%ESC%[0m
    )
)
echo.

REM ============================================================================
REM   ФИНАЛ
REM ============================================================================
echo  %ESC%[36m--------------------------------------------------------------------------------%ESC%[0m
echo   %ESC%[1;32mMarian NMT успешно установлен / обновлён!%ESC%[0m
echo.
echo   %ESC%[1;33mРасположение:%ESC%[0m
echo     %ESC%[2m  %MARIAN_HOME%%ESC%[0m
echo.
echo   %ESC%[2m  (Модель: Helsinki-NLP/opus-mt-en-ru, ~400 МБ)%ESC%[0m
echo   %ESC%[2m  (Серверный скрипт: marian_server.py)%ESC%[0m
echo   %ESC%[2m  (Использует общий Python: %PYTHON_DIR%)%ESC%[0m
echo  %ESC%[36m--------------------------------------------------------------------------------%ESC%[0m
echo.

if "%AUTOCLOSE%"=="0" pause
popd
exit /b 0
