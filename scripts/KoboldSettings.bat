@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

REM ============================================================================
REM   KoboldCpp Portable — Настройка через GUI
REM ============================================================================
title KoboldCpp Portable — Настройка

pushd %~dp0..

REM Получаем ESC-символ для ANSI-цветов
for /f %%a in ('powershell -Command "Write-Host ([char]27) -NoNewline"') do set "ESC=%%a"

REM ============================================================================
REM   Нормализация корневого пути
REM ============================================================================
for %%F in ("%~dp0..") do set "ROOT_DIR=%%~fF"

REM ============================================================================
REM   Загрузка настроек из settings.ini
REM ============================================================================
set "CONFIG_FILE=%~dp0settings.ini"

if not exist "%CONFIG_FILE%" (
    echo.
    echo   %ESC%[1;31m^[ОШИБКА^] Файл настроек не найден:%ESC%[0m
    echo   %ESC%[33m       %CONFIG_FILE%%ESC%[0m
    echo.
    pause
    popd
    exit /b 1
)

for /f "usebackq delims=" %%a in ("%CONFIG_FILE%") do set "%%a"

REM Значения по умолчанию
if not defined LLM_PORT set LLM_PORT=5001
if not defined MODEL set MODEL=
if not defined MMPROJ set MMPROJ=
if not defined ENABLE_WHISPER set ENABLE_WHISPER=0
if not defined WHISPER_MODEL set WHISPER_MODEL=

REM === Коррекция Whisper ===
if "!WHISPER_MODEL!"=="" set ENABLE_WHISPER=0

REM ============================================================================
REM   Проверка KoboldCpp (СНАЧАЛА!)
REM ============================================================================
set "KCPP_EXE=!ROOT_DIR!\kobold\koboldcpp.exe"
set "KCPP_TEMP=!ROOT_DIR!\kobold\temp"
set "MODELS_DIR=!ROOT_DIR!\kobold\models"
set "SETTINGS_DIR=!ROOT_DIR!\kobold\settings"

if not exist "!KCPP_EXE!" (
    cls
    echo.
    echo  %ESC%[1;31m################################################################################%ESC%[0m
    echo  %ESC%[1;31m##                                                                            ##%ESC%[0m
    echo  %ESC%[1;31m##%ESC%[0m              %ESC%[1;37mKoboldCpp Portable%ESC%[0m   —   %ESC%[1;33mНастройка%ESC%[0m                           %ESC%[1;31m##%ESC%[0m
    echo  %ESC%[1;31m##                                                                            ##%ESC%[0m
    echo  %ESC%[1;31m################################################################################%ESC%[0m
    echo.
    echo   %ESC%[1;31m  ✗   KoboldCpp не установлен!%ESC%[0m
    echo   %ESC%[33m       Установите KoboldCpp через главное меню [1]%ESC%[0m
    echo.
    pause
    popd
    exit /b 1
)

REM ============================================================================
REM   Проверка/создание папки settings и default.kcpps (ПОТОМ!)
REM ============================================================================
if not exist "!SETTINGS_DIR!" mkdir "!SETTINGS_DIR!"

set "KCPP_SETTINGS=!SETTINGS_DIR!\default.kcpps"
if not exist "!KCPP_SETTINGS!" (
    set "KCPP_SETTINGS_SRC=!ROOT_DIR!\scripts\data\default.kcpps"
    if exist "!KCPP_SETTINGS_SRC!" (
        copy "!KCPP_SETTINGS_SRC!" "!KCPP_SETTINGS!" >nul
        echo   %ESC%[33m  →   Создан файл настроек: kobold\settings\default.kcpps%ESC%[0m
    ) else (
        echo   %ESC%[1;31m^[ОШИБКА^] Шаблон default.kcpps не найден в scripts\data\%ESC%[0m
        pause
        popd
        exit /b 1
    )
)

REM ============================================================================
REM   Сканирование .kcpps файлов
REM ============================================================================
cls
echo.
echo  %ESC%[1;36m################################################################################%ESC%[0m
echo  %ESC%[1;36m##                                                                            ##%ESC%[0m
echo  %ESC%[1;36m##%ESC%[0m              %ESC%[1;37mKoboldCpp Portable%ESC%[0m   —   %ESC%[1;33mВыбор профиля настроек%ESC%[0m            %ESC%[1;36m##%ESC%[0m
echo  %ESC%[1;36m##                                                                            ##%ESC%[0m
echo  %ESC%[1;36m################################################################################%ESC%[0m
echo.
echo   %ESC%[1;33mДоступные профили:%ESC%[0m
echo.

set "KCPPS_COUNT=0"
for %%f in ("!SETTINGS_DIR!\*.kcpps") do (
    set /a "KCPPS_COUNT+=1"
    set "KCPPS_!KCPPS_COUNT!=%%~nxf"
    echo   %ESC%[1;37m[!KCPPS_COUNT!]%ESC%[0m %%~nxf
    if !KCPPS_COUNT! GEQ 4 goto :kcpps_list_done
)
:kcpps_list_done

if !KCPPS_COUNT!==0 (
    echo   %ESC%[1;31m  ✗   Нет файлов .kcpps%ESC%[0m
    pause
    popd
    exit /b 1
)

echo.
echo   %ESC%[1;37m[0]%ESC%[0m %ESC%[1mОтмена%ESC%[0m
echo.
set "choice="
set /p "choice=%ESC%[33mВыберите профиль (0-!KCPPS_COUNT!): %ESC%[0m"

set "choice=!choice: =!"
if "!choice!"=="0" goto :exit
if "!choice!"=="" goto :exit

set "SELECTED_KCPPS="
for /l %%i in (1,1,!KCPPS_COUNT!) do (
    if "!choice!"=="%%i" set "SELECTED_KCPPS=!KCPPS_%%i!"
)

if "!SELECTED_KCPPS!"=="" (
    echo   %ESC%[1;31m  ✗   Неверный выбор%ESC%[0m
    timeout /t 2 /nobreak >nul
    goto :kcpps_list_done
)

REM ============================================================================
REM   Формирование аргументов запуска
REM ============================================================================
    set "KCPP_ARGS=--config "!SETTINGS_DIR!\!SELECTED_KCPPS!" --port !LLM_PORT! --showgui"

if not "!MODEL!"=="" (
    set "MODEL_PATH=!MODELS_DIR!\!MODEL!"
    if exist "!MODEL_PATH!" (
        set "KCPP_ARGS=!KCPP_ARGS! --model "!MODEL_PATH!""
    ) else (
        echo   %ESC%[1;33m  ⚠   Модель !MODEL! не найдена. Запуск без модели.%ESC%[0m
        timeout /t 2 /nobreak >nul
    )
)

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
        )
    )
)

REM ============================================================================
REM   Запуск KoboldCpp с GUI
REM ============================================================================
cls
echo.
echo  %ESC%[1;36m################################################################################%ESC%[0m
echo  %ESC%[1;36m##                                                                            ##%ESC%[0m
echo  %ESC%[1;36m##%ESC%[0m              %ESC%[1;37mKoboldCpp Portable%ESC%[0m   —   %ESC%[1;33mРедактор настроек%ESC%[0m                %ESC%[1;36m##%ESC%[0m
echo  %ESC%[1;36m##                                                                            ##%ESC%[0m
echo  %ESC%[1;36m################################################################################%ESC%[0m
echo.
echo   %ESC%[1;33mЗапуск KoboldCpp с GUI...%ESC%[0m
echo   %ESC%[2mПрофиль: !SELECTED_KCPPS!%ESC%[0m
echo   %ESC%[2mПорт: !LLM_PORT!%ESC%[0m
if not "!MODEL!"=="" (
    if exist "!MODEL_PATH!" (
        echo   %ESC%[2mМодель: !MODEL!%ESC%[0m
    )
)
echo.
echo   %ESC%[33mНастройте параметры в окне KoboldCpp и закройте его.%ESC%[0m
echo   %ESC%[33mНастройки будут сохранены автоматически.%ESC%[0m
echo.

REM === ПОРТАТИВНЫЙ TEMP ===
if not exist "!KCPP_TEMP!" mkdir "!KCPP_TEMP!"
for /d %%D in ("!KCPP_TEMP!\_MEI*") do rmdir /s /q "%%D" 2>nul

REM Запускаем KoboldCpp GUI (без /B, чтобы ждать закрытия окна)
start /WAIT "" cmd /c "set TMP=!KCPP_TEMP!&&set TEMP=!KCPP_TEMP!&&"!KCPP_EXE!" !KCPP_ARGS!"

REM После закрытия
echo.
echo   %ESC%[1;32m  ✔   KoboldCpp закрыт.%ESC%[0m
echo   %ESC%[1;33m  →   Настройки сохранены в: !SELECTED_KCPPS!%ESC%[0m
echo   %ESC%[2m       Путь: !SETTINGS_DIR!\!SELECTED_KCPPS!%ESC%[0m
echo.
echo   %ESC%[33mПри следующем запуске через Start.bat будут использованы%ESC%[0m
echo   %ESC%[33mпараметры из этого профиля (с переопределением модели и порта).%ESC%[0m
echo.
pause

:exit
popd
exit /b 0