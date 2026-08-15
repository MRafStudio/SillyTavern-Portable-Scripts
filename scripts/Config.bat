@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

title SillyTavern Portable — Настройка компонентов
pushd %~dp0..

REM Файл с настройками
set "CONFIG_FILE=%~dp0settings.ini"

REM Загружаем настройки (если есть)
if exist "%CONFIG_FILE%" (
    for /f "usebackq delims=" %%a in ("%CONFIG_FILE%") do set %%a
)

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

for /f %%a in ('powershell -Command "Write-Host ([char]27) -NoNewline"') do set "ESC=%%a"

REM ============================================================================
REM   Нормализация корневого пути
REM ============================================================================
for %%F in ("%~dp0..") do set "ROOT_DIR=%%~fF"

REM ============================================================================
REM   Проверка наличия установленных компонентов
REM ============================================================================
set "ANY_INSTALLED=0"
if exist "python-3.11.9\python.exe" set ANY_INSTALLED=1
if exist "SillyTavern\package.json" set ANY_INSTALLED=1
if exist "data\llama\llama-server.exe" set ANY_INSTALLED=1
if exist "tts-cpu\silero_server_v2.py" set ANY_INSTALLED=1
if exist "marian\marian_server.py" set ANY_INSTALLED=1

if "%ANY_INSTALLED%"=="0" (
    cls
    echo.
    echo  %ESC%[1;31m################################################################################%ESC%[0m
    echo  %ESC%[1;31m##                                                                            ##%ESC%[0m
    echo  %ESC%[1;31m##%ESC%[0m              %ESC%[1;37mSillyTavern Portable%ESC%[0m   —   %ESC%[1;33mНастройка компонентов%ESC%[0m              %ESC%[1;31m##%ESC%[0m
    echo  %ESC%[1;31m##                                                                            ##%ESC%[0m
    echo  %ESC%[1;31m################################################################################%ESC%[0m
    echo.
    echo   %ESC%[1;31m  ✗   Нет установленных компонентов!%ESC%[0m
    echo   %ESC%[33m      Настройка невозможна без установленных компонентов.%ESC%[0m
    echo   %ESC%[33m      Сначала установите компоненты через меню установки.%ESC%[0m
    echo.
    echo   %ESC%[2m      Возврат в главное меню через 5 секунд...%ESC%[0m
    timeout /t 5 /nobreak >nul
    popd
    exit /b 0
)

:menu
cls
echo.
echo  %ESC%[1;36m################################################################################%ESC%[0m
echo  %ESC%[1;36m##                                                                            ##%ESC%[0m
echo  %ESC%[1;36m##%ESC%[0m              %ESC%[1;37mSillyTavern Portable%ESC%[0m   —   %ESC%[1;33mНастройка компонентов%ESC%[0m              %ESC%[1;36m##%ESC%[0m
echo  %ESC%[1;36m##                                                                            ##%ESC%[0m
echo  %ESC%[1;36m################################################################################%ESC%[0m
echo.
echo   %ESC%[1;33mКомпоненты:%ESC%[0m
if "!ENABLE_LLM!"=="1" ( set "LLM_STATUS=%ESC%[1;32mВключён%ESC%[0m" ) else ( set "LLM_STATUS=%ESC%[1;31mВыключен%ESC%[0m" )
if "!ENABLE_TTS!"=="1" ( set "TTS_STATUS=%ESC%[1;32mВключён%ESC%[0m" ) else ( set "TTS_STATUS=%ESC%[1;31mВыключен%ESC%[0m" )
if "!ENABLE_TRANSLATE!"=="1" ( set "TR_STATUS=%ESC%[1;32mВключён%ESC%[0m" ) else ( set "TR_STATUS=%ESC%[1;31mВыключен%ESC%[0m" )

echo     %ESC%[1;37m[1]%ESC%[0m LLM (llama.cpp)            — !LLM_STATUS!
echo     %ESC%[1;37m[2]%ESC%[0m TTS (Silero v2)            — !TTS_STATUS!
echo     %ESC%[1;37m[3]%ESC%[0m Переводчик (Marian NMT)    — !TR_STATUS!
echo.
echo   %ESC%[1;33mМодель LLM:%ESC%[0m
if not "!MODEL!"=="" (
    echo     %ESC%[1;32m  ✔   Текущая модель: !MODEL!%ESC%[0m
    if not "!MMPROJ!"=="" (
        echo     %ESC%[1;32m  ✔   Проектор: !MMPROJ!%ESC%[0m
    )
) else (
    echo     %ESC%[1;31m  ✗   Модель не выбрана%ESC%[0m
)
echo.
echo   %ESC%[1;33mПорты:%ESC%[0m
echo     %ESC%[1;37m[4]%ESC%[0m Порт SillyTavern              = !ST_PORT!
echo     %ESC%[1;37m[5]%ESC%[0m Порт LLM (llama.cpp)          = !LLM_PORT!
echo     %ESC%[1;37m[6]%ESC%[0m Порт TTS (Silero v2)          = !TTS_PORT!
echo     %ESC%[1;37m[7]%ESC%[0m Порт переводчика (Marian NMT) = !TRANSLATE_PORT!
echo.
echo   %ESC%[1;37m[8]%ESC%[0m %ESC%[1;33mВыбрать модель LLM%ESC%[0m
echo   %ESC%[1;37m[0]%ESC%[0m %ESC%[1mНазад в главное меню%ESC%[0m
echo   %ESC%[1;37m[R]%ESC%[0m %ESC%[1;33mСбросить настройки по умолчанию%ESC%[0m
echo.
set "choice="
set /p "choice=%ESC%[33mВыберите действие (0-8, R): %ESC%[0m"

set "choice=%choice: =%"

if "%choice%"=="" goto menu
if "%choice%"=="1" goto toggle_llm
if "%choice%"=="2" goto toggle_tts
if "%choice%"=="3" goto toggle_translate
if "%choice%"=="4" goto set_st_port
if "%choice%"=="5" goto set_llm_port
if "%choice%"=="6" goto set_tts_port
if "%choice%"=="7" goto set_translate_port
if "%choice%"=="8" goto select_model
if /i "%choice%"=="R" goto reset_defaults
if "%choice%"=="0" goto exit
goto menu

:toggle_llm
if "!ENABLE_LLM!"=="1" ( 
    set ENABLE_LLM=0
    echo   %ESC%[1;33m  →   LLM компонент ВЫКЛЮЧЕН%ESC%[0m
) else ( 
    set ENABLE_LLM=1
    echo   %ESC%[1;32m  ✔   LLM компонент ВКЛЮЧЁН%ESC%[0m
)
timeout /t 1 /nobreak >nul
goto save_settings

:toggle_tts
if "!ENABLE_TTS!"=="1" ( 
    set ENABLE_TTS=0
    echo   %ESC%[1;33m  →   TTS компонент ВЫКЛЮЧЕН%ESC%[0m
) else ( 
    set ENABLE_TTS=1
    echo   %ESC%[1;32m  ✔   TTS компонент ВКЛЮЧЁН%ESC%[0m
)
timeout /t 1 /nobreak >nul
goto save_settings

:toggle_translate
if "!ENABLE_TRANSLATE!"=="1" ( 
    set ENABLE_TRANSLATE=0
    echo   %ESC%[1;33m  →   Переводчик ВЫКЛЮЧЕН%ESC%[0m
) else ( 
    set ENABLE_TRANSLATE=1
    echo   %ESC%[1;32m  ✔   Переводчик ВКЛЮЧЁН%ESC%[0m
)
timeout /t 1 /nobreak >nul
goto save_settings

:set_st_port
echo.
set /p "ST_PORT=%ESC%[33mНовый порт для SillyTavern (по умолчанию 8000): %ESC%[0m"
if "%ST_PORT%"=="" set ST_PORT=8000
echo   %ESC%[32m  ✔   Порт SillyTavern изменён на !ST_PORT!%ESC%[0m
timeout /t 1 /nobreak >nul
goto save_settings

:set_llm_port
echo.
set /p "LLM_PORT=%ESC%[33mНовый порт для LLM (llama.cpp, по умолчанию 5001): %ESC%[0m"
if "%LLM_PORT%"=="" set LLM_PORT=5001
echo   %ESC%[32m  ✔   Порт LLM изменён на !LLM_PORT!%ESC%[0m
timeout /t 1 /nobreak >nul
goto save_settings

:set_tts_port
echo.
set /p "TTS_PORT=%ESC%[33mНовый порт для TTS (по умолчанию 8881): %ESC%[0m"
if "%TTS_PORT%"=="" set TTS_PORT=8881
echo   %ESC%[32m  ✔   Порт TTS изменён на !TTS_PORT!%ESC%[0m
timeout /t 1 /nobreak >nul
goto save_settings

:set_translate_port
echo.
set /p "TRANSLATE_PORT=%ESC%[33mНовый порт для переводчика (по умолчанию 5003): %ESC%[0m"
if "%TRANSLATE_PORT%"=="" set TRANSLATE_PORT=5003
echo   %ESC%[32m  ✔   Порт переводчика изменён на !TRANSLATE_PORT!%ESC%[0m
timeout /t 1 /nobreak >nul
goto save_settings

:select_model
REM Проверяем, установлен ли llama.cpp
if not exist "data\llama\llama-server.exe" (
    echo.
    echo   %ESC%[1;31m^[ОШИБКА^] Llama.cpp не установлен!%ESC%[0m
    echo   %ESC%[33m      Выбор модели невозможен без установленного llama.cpp.%ESC%[0m
    echo   %ESC%[33m      Сначала установите llama.cpp через меню установки компонентов.%ESC%[0m
    echo.
    pause
    goto menu
)

cls
echo.
echo   %ESC%[1;36m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━%ESC%[0m
echo   %ESC%[1;36m                         Выбор LLM модели                         %ESC%[0m
echo   %ESC%[1;36m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━%ESC%[0m
echo.
echo     %ESC%[1;37m[1]%ESC%[0m %ESC%[1;35mQwen 3.6-35B-A3B UD-IQ4_NL%ESC%[0m %ESC%[2m^(18.0 ГБ, мин. 24 GB VRAM, мультимодальная^)%ESC%[0m
echo     %ESC%[1;37m[2]%ESC%[0m %ESC%[1;33mGemma 4-26B-A4B UD-IQ4_NL%ESC%[0m %ESC%[2m^(13.6 ГБ, мин. 20 GB VRAM, мультимодальная^)%ESC%[0m
echo     %ESC%[1;37m[3]%ESC%[0m %ESC%[1;37mОчистить выбор модели%ESC%[0m
echo.
echo     %ESC%[1;37m[0]%ESC%[0m %ESC%[1mНазад%ESC%[0m
echo.
set "model_choice="
set /p "model_choice=%ESC%[33mВыберите модель (0-3): %ESC%[0m"

set "model_choice=%model_choice: =%"

if "%model_choice%"=="" goto select_model
if "%model_choice%"=="1" (
    set "MODEL=Qwen3.6-35B-A3B-UD-IQ4_NL.gguf"
    set "MMPROJ=mmproj-F16.gguf"
    echo   %ESC%[1;32m  ✔   Выбрана модель: Qwen 3.6-35B-A3B ^(UD-IQ4_NL^)%ESC%[0m
    echo   %ESC%[2m      Проектор: mmproj-F16.gguf ^(будет загружен автоматически^)%ESC%[0m
    goto save_settings
)
if "%model_choice%"=="2" (
    set "MODEL=gemma-4-26B-A4B-it-UD-IQ4_NL.gguf"
    set "MMPROJ=mmproj-BF16.gguf"
    echo   %ESC%[1;32m  ✔   Выбрана модель: Gemma 4-26B-A4B ^(UD-IQ4_NL^)%ESC%[0m
    echo   %ESC%[2m      Проектор: mmproj-BF16.gguf ^(будет загружен автоматически^)%ESC%[0m
    goto save_settings
)
if "%model_choice%"=="3" (
    set "MODEL="
    set "MMPROJ="
    echo   %ESC%[1;33m  →   Выбор модели очищен%ESC%[0m
    goto save_settings
)
goto select_model

:reset_defaults
set ENABLE_LLM=1
set ENABLE_TTS=1
set ENABLE_TRANSLATE=1
set ST_PORT=8000
set LLM_PORT=5001
set TTS_PORT=8881
set TRANSLATE_PORT=5003
set MODEL=
set MMPROJ=
echo.
echo   %ESC%[1;32m  ✔   Настройки сброшены до значений по умолчанию%ESC%[0m
echo   %ESC%[2m      LLM = Включён, TTS = Включён, Переводчик = Включён%ESC%[0m
echo   %ESC%[2m      Порты: ST=8000, LLM=5001, TTS=8881, Translate=5003%ESC%[0m
echo   %ESC%[2m      Модель: не выбрана%ESC%[0m
timeout /t 2 /nobreak >nul

:save_settings
(
    echo ENABLE_LLM=!ENABLE_LLM!
    echo ENABLE_TTS=!ENABLE_TTS!
    echo ENABLE_TRANSLATE=!ENABLE_TRANSLATE!
    echo ST_PORT=!ST_PORT!
    echo LLM_PORT=!LLM_PORT!
    echo TTS_PORT=!TTS_PORT!
    echo TRANSLATE_PORT=!TRANSLATE_PORT!
    echo MODEL=!MODEL!
    echo MMPROJ=!MMPROJ!
) > "%CONFIG_FILE%"
goto menu

:exit
(
    echo ENABLE_LLM=!ENABLE_LLM!
    echo ENABLE_TTS=!ENABLE_TTS!
    echo ENABLE_TRANSLATE=!ENABLE_TRANSLATE!
    echo ST_PORT=!ST_PORT!
    echo LLM_PORT=!LLM_PORT!
    echo TTS_PORT=!TTS_PORT!
    echo TRANSLATE_PORT=!TRANSLATE_PORT!
    echo MODEL=!MODEL!
    echo MMPROJ=!MMPROJ!
) > "%CONFIG_FILE%"

popd
exit /b 0