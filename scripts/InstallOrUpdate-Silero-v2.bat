@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

REM ============================================================================
REM   Silero TTS Portable v2 — установка / обновление (русская версия)
REM ============================================================================
REM   Использует общий Python из python-3.11.9 (устанавливается отдельно)
REM   Версия 2.0: torch.hub, v5_4_ru, WAV, intensity, sanitization
REM ============================================================================

title Silero TTS Portable v2 — Установка / Обновление

REM Обработка параметра autoclose
set "AUTOCLOSE=0"
if "%1"=="1" set "AUTOCLOSE=1"

REM Переходим в корневую папку портативной установки
pushd %~dp0..

REM Получаем абсолютный путь к корню (убираем .. из путей)
for %%F in ("%~dp0..") do set "ROOT_DIR=%%~fF"

for /f %%a in ('powershell -Command "Write-Host ([char]27) -NoNewline"') do set "ESC=%%a"

cls
echo.
echo  %ESC%[1;36m################################################################################%ESC%[0m
echo  %ESC%[1;36m##                                                                            ##%ESC%[0m
echo  %ESC%[1;36m##%ESC%[0m             %ESC%[1;37mSilero TTS Portable v2%ESC%[0m   —   %ESC%[1;33mУстановка / Обновление%ESC%[0m           %ESC%[1;36m##%ESC%[0m
echo  %ESC%[1;36m##                                                                            ##%ESC%[0m
echo  %ESC%[1;36m##%ESC%[0m        %ESC%[1;32mtorch.hub%ESC%[0m  •  %ESC%[1;32mv5_4_ru%ESC%[0m  •  %ESC%[1;32mWAV%ESC%[0m  •  %ESC%[1;32mintensity%ESC%[0m  •  %ESC%[1;32mSanitization%ESC%[0m      %ESC%[1;36m##%ESC%[0m
echo  %ESC%[1;36m##                                                                            ##%ESC%[0m
echo  %ESC%[1;36m################################################################################%ESC%[0m
echo.

REM ============================================================================
REM   ШАГ 0: Проверка разрядности системы
REM ============================================================================
echo   %ESC%[1;33m[0/6]%ESC%[0m %ESC%[1mПроверка разрядности Windows...%ESC%[0m
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
REM   ШАГ 1: Определение путей (абсолютные, без ..)
REM ============================================================================
set "TTS_HOME=%ROOT_DIR%\tts-cpu"
set "PYTHON_DIR=%ROOT_DIR%\python-3.11.9"
set "PYTHON_EXE=%PYTHON_DIR%\python.exe"
set "VENV=%TTS_HOME%\.venv"
set "VENV_PYTHON=%VENV%\Scripts\python.exe"

if not exist "%TTS_HOME%" mkdir "%TTS_HOME%"

REM ============================================================================
REM   ШАГ 2: Проверка наличия общего Python
REM ============================================================================
echo   %ESC%[1;33m[1/6]%ESC%[0m %ESC%[1mПроверка общего Python...%ESC%[0m

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
echo   %ESC%[1;33m[2/6]%ESC%[0m %ESC%[1mНастройка виртуального окружения Silero...%ESC%[0m

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
echo   %ESC%[1;33m[3/6]%ESC%[0m %ESC%[1mУстановка зависимостей...%ESC%[0m
echo   %ESC%[2m       (torch, torchaudio, fastapi, uvicorn, soundfile, numpy, scipy)%ESC%[0m
echo   %ESC%[2m       Это может занять несколько минут при первом запуске...%ESC%[0m

"%VENV_PYTHON%" -c "import fastapi, uvicorn, numpy, soundfile, scipy, torch, num2words, omegaconf" 1>nul 2>nul
if !errorlevel! equ 0 (
    echo   %ESC%[32m  ✔   Зависимости уже установлены.%ESC%[0m
) else (
    echo   %ESC%[33m  →   Установка зависимостей...%ESC%[0m

    echo   %ESC%[2m       [1/3] Обновление pip...%ESC%[0m
    "%VENV_PYTHON%" -m pip cache purge >nul 2>nul
    "%VENV_PYTHON%" -m pip install --upgrade pip --quiet

    echo   %ESC%[2m       [2/3] Установка PyTorch...%ESC%[0m
    "%VENV_PYTHON%" -m pip install torch torchaudio --index-url https://download.pytorch.org/whl/cpu --quiet
    if !errorlevel! neq 0 (
        echo   %ESC%[1;31m^[ОШИБКА^] Не удалось установить PyTorch.%ESC%[0m
        if "%AUTOCLOSE%"=="0" pause
        popd
        exit /b 1
    )

    echo   %ESC%[2m       [3/3] Установка FastAPI, uvicorn, soundfile, num2words, omegaconf...%ESC%[0m
    "%VENV_PYTHON%" -m pip install fastapi uvicorn soundfile numpy scipy num2words omegaconf --quiet
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
REM   ШАГ 5: Предзагрузка модели Silero через torch.hub
REM ============================================================================
echo   %ESC%[1;33m[4/6]%ESC%[0m %ESC%[1mПредзагрузка модели Silero v5_4_ru...%ESC%[0m

echo   %ESC%[2m       (torch.hub загрузит модель в %%LOCALAPPDATA%%\torch\hub)...%ESC%[0m

set "PY_SCRIPT=%TEMP%\silero_preload_%RANDOM%.py"
(
    echo import torch, os
    echo os.environ['TORCH_HOME'] = r'%TTS_HOME%\.cache\torch'
    echo torch.hub.load(
    echo     repo_or_dir='snakers4/silero-models',
    echo     model='silero_tts',
    echo     language='ru',
    echo     speaker='v5_4_ru',
    echo     trust_repo=True,
    echo     force_reload=False,
    echo ^)
    echo print('Model preloaded successfully'^)
) > "%PY_SCRIPT%"

"%VENV_PYTHON%" "%PY_SCRIPT%" 2^>^&1 | findstr /i "loaded error success"
if !errorlevel! neq 0 (
    echo   %ESC%[1;33m  ⚠   Модель будет загружена при первом запуске сервера.%ESC%[0m
) else (
    echo   %ESC%[32m  ✔   Модель предзагружена.%ESC%[0m
)

if exist "%PY_SCRIPT%" del "%PY_SCRIPT%" >nul 2>nul
echo.

REM ============================================================================
REM   ШАГ 6: Копирование серверного скрипта и белого списка
REM ============================================================================
echo   %ESC%[1;33m[5/6]%ESC%[0m %ESC%[1mУстановка серверного скрипта...%ESC%[0m

set "SILERO_SERVER_SRC=%ROOT_DIR%\scripts\py\silero_server_v2.py"
set "SILERO_SERVER_DST=%TTS_HOME%\silero_server_v2.py"
set "WHITELIST_SRC=%ROOT_DIR%\scripts\py\no_translate_words.ini"
set "WHITELIST_DST=%TTS_HOME%\no_translate_words.ini"

if exist "%SILERO_SERVER_SRC%" (
    copy /Y "%SILERO_SERVER_SRC%" "%SILERO_SERVER_DST%" >nul
    echo   %ESC%[32m  ✔   silero_server_v2.py скопирован как silero_server_v2.py.%ESC%[0m
) else (
    echo   %ESC%[1;31m^[ОШИБКА^] Не найден silero_server_v2.py в scripts\py\%ESC%[0m
    echo   %ESC%[33m       Убедитесь, что файл silero_server_v2.py лежит в scripts\py\%ESC%[0m
    if "%AUTOCLOSE%"=="0" pause
    popd
    exit /b 1
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
)
echo.

REM ============================================================================
REM   ШАГ 7: Создание Start-TTS.bat
REM ============================================================================
echo   %ESC%[1;33m[6/6]%ESC%[0m %ESC%[1mСоздание скрипта запуска...%ESC%[0m

set "START_BAT=%TTS_HOME%\Start-TTS.bat"
(
    echo @echo off
    echo chcp 65001 ^>nul
    echo setlocal enabledelayedexpansion
    echo.
    echo REM === Silero TTS Server v2 ===
    echo set "TTS_HOME=%TTS_HOME%"
    echo set "VENV_PYTHON=%VENV_PYTHON%"
    echo.
    echo REM === Настройки Silero v2 ===
    echo set "SILERO_MODEL=v5_4_ru"
    echo set "SILERO_LANGUAGE=ru"
    echo set "SILERO_DEVICE=cpu"
    echo set "SILERO_SAMPLE_RATE=48000"
    echo set "SILERO_DEFAULT_VOICE=xenia"
    echo.
    echo REM === Параметры качества (как у Шурочки) ===
    echo set "SILERO_PUT_ACCENT=1"
    echo set "SILERO_PUT_YO=1"
    echo set "SILERO_PUT_STRESS_HOMO=1"
    echo set "SILERO_PUT_YO_HOMO=1"
    echo set "SILERO_INTENSITY=3"
    echo.
    echo REM === Marian (опционально) ===
    echo set "ENABLE_TRANSLATE=0"
    echo set "MARIAN_URL=http://127.0.0.1:5003/translate"
    echo.
    echo REM === torch.hub cache ===
    echo set "TORCH_HOME=%TTS_HOME%\.cache\torch"
    echo.
    echo title Silero TTS Server v2
    echo echo [%%date%% %%time%%] Запуск Silero TTS v2...
    echo echo Модель: v5_4_ru, Голос: xenia, Устройство: cpu
    echo echo Параметры: accent=on, yo=on, intensity=3
    echo echo.
    echo.
    echo "%%VENV_PYTHON%%" "%%TTS_HOME%%\silero_server_v2.py"
    echo.
    echo echo.
    echo echo [%%date%% %%time%%] Сервер остановлен.
    echo pause
) > "%START_BAT%"

echo   %ESC%[32m  ✔   Start-TTS.bat создан.%ESC%[0m
echo.

REM ============================================================================
REM   ФИНАЛ
REM ============================================================================
echo  %ESC%[36m--------------------------------------------------------------------------------%ESC%[0m
echo   %ESC%[1;32mSilero TTS v2 успешно установлен / обновлён!%ESC%[0m
echo.
echo   %ESC%[1;33mЧто нового в v2:%ESC%[0m
echo     %ESC%[2m  • torch.hub.load — авто-загрузка v5_4_ru%ESC%[0m
echo     %ESC%[2m  • Все параметры apply_tts (accent, yo, homo, intensity)%ESC%[0m
echo     %ESC%[2m  • WAV экспорт (PCM_16) — максимальное качество%ESC%[0m
echo     %ESC%[2m  • Чанки по предложениям (сохранены из v1)%ESC%[0m
echo.
echo   %ESC%[1;33mЗапуск:%ESC%[0m
echo     %ESC%[2m  %START_BAT%%ESC%[0m
echo.
echo   %ESC%[2m  (Модель: v5_4_ru через torch.hub)%ESC%[0m
echo   %ESC%[2m  (Использует общий Python: %PYTHON_DIR%)%ESC%[0m
echo  %ESC%[36m--------------------------------------------------------------------------------%ESC%[0m
echo.

if "%AUTOCLOSE%"=="0" pause
popd
exit /b 0