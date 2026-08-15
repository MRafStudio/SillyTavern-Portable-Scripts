@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

REM Обработка параметра autoclose
set "AUTOCLOSE=0"
if "%1"=="1" set "AUTOCLOSE=1"

echo %AUTOCLOSE%

REM ============================================================================
REM   SillyTavern Portable — установка / обновление (русская версия)
REM ============================================================================

title SillyTavern Portable — Установка / Обновление

REM Переходим в корневую папку портативной установки
pushd %~dp0..

REM Получаем ESC-символ для ANSI-цветов
for /f %%a in ('powershell -Command "Write-Host ([char]27) -NoNewline"') do set "ESC=%%a"

cls
echo.
::echo %AUTOCLOSE%
echo  %ESC%[1;36m################################################################################%ESC%[0m
echo  %ESC%[1;36m##                                                                            ##%ESC%[0m
echo  %ESC%[1;36m##%ESC%[0m        %ESC%[1;37mSillyTavern Portable%ESC%[0m   —   %ESC%[1;33mУстановка / Обновление%ESC%[0m                   %ESC%[1;36m##%ESC%[0m
echo  %ESC%[1;36m##                                                                            ##%ESC%[0m
echo  %ESC%[1;36m################################################################################%ESC%[0m
echo.

REM ============================================================================
REM   ШАГ 0: Проверка разрядности системы (требуется x64)
REM ============================================================================
echo   %ESC%[1;33m[0/4]%ESC%[0m %ESC%[1mПроверка разрядности Windows...%ESC%[0m
set ARCH_OK=0
if "%PROCESSOR_ARCHITECTURE%"=="AMD64" set ARCH_OK=1
if "%PROCESSOR_ARCHITEW6432%"=="AMD64" set ARCH_OK=1
if %ARCH_OK%==0 (
    echo.
    echo   %ESC%[1;31m^[ОШИБКА^] Обнаружена 32-разрядная ^(x86^) версия Windows.%ESC%[0m
    echo   %ESC%[33m   SillyTavern Portable требует 64-разрядную систему ^(x64^).%ESC%[0m
    echo.
    echo   %ESC%[33m   Установка невозможна. Завершение.%ESC%[0m
    echo.
    pause
    popd
    exit /b 1
)
echo   %ESC%[1;32m  ✔   Система 64-разрядная (x64).%ESC%[0m
echo.

REM ============================================================================
REM   ШАГ 1: Проверка Git
REM ============================================================================
echo   %ESC%[1;33m[1/4]%ESC%[0m %ESC%[1mПроверка Git...%ESC%[0m
where git >nul 2>&1
if !errorlevel! neq 0 (
    echo.
    echo   %ESC%[1;31m^[ОШИБКА^]%ESC%[0m Git не найден в системе.
    echo   %ESC%[33m   SillyTavern требует Git для клонирования и обновления.%ESC%[0m
    echo.
    echo   %ESC%[36m   Скачайте и установите Git с официального сайта:%ESC%[0m
    echo   %ESC%[1;34m   https://git-scm.com/download/win%ESC%[0m
    echo.
    echo   %ESC%[2m   После установки перезапустите этот скрипт.%ESC%[0m
    echo.
    pause
    popd
    exit /b 1
)
echo   %ESC%[1;32m  ✔   Git найден:%ESC%[0m
for /f "tokens=*" %%a in ('git --version 2^>nul') do (
    echo   %ESC%[2m       %%a%ESC%[0m
)
echo.

REM ============================================================================
REM   ШАГ 2: Портативная установка Node.js (только x64)
REM ============================================================================
echo   %ESC%[1;33m[2/4]%ESC%[0m %ESC%[1mПроверка портативного Node.js...%ESC%[0m
set "NODE_DIR=%~dp0..\node-dist"
set "NODE_EXE=%NODE_DIR%\node.exe"

if not exist "%NODE_EXE%" (
    echo   %ESC%[33m  →   Портативный Node.js не найден. Загружаем...%ESC%[0m
    set "NODE_ARCH=win-x64"
    set "NODE_VERSION=20.11.0"
    set "NODE_ZIP=node-v!NODE_VERSION!-!NODE_ARCH!.zip"
    set "NODE_URL=https://nodejs.org/dist/v!NODE_VERSION!/!NODE_ZIP!"

    echo   %ESC%[2m       Загрузка !NODE_ZIP! ...%ESC%[0m
    powershell -Command "& { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri '!NODE_URL!' -OutFile '%TEMP%\!NODE_ZIP!' }"
    if !errorlevel! neq 0 (
        echo   %ESC%[1;31m^[ОШИБКА^] Не удалось загрузить Node.js. Проверьте соединение с интернетом.%ESC%[0m
        pause
        popd
        exit /b 1
    )
    echo   %ESC%[32m  ✔   Загрузка завершена.%ESC%[0m
    echo   %ESC%[33m  →   Распаковка в %NODE_DIR% ...%ESC%[0m
    if exist "%NODE_DIR%" rmdir /s /q "%NODE_DIR%"
    powershell -Command "& { Expand-Archive -Path '%TEMP%\!NODE_ZIP!' -DestinationPath '%TEMP%\node_extract' -Force; Move-Item -Path '%TEMP%\node_extract\*' -Destination '%NODE_DIR%' -Force; Remove-Item -Path '%TEMP%\node_extract' -Recurse -Force }"
    del "%TEMP%\!NODE_ZIP!" 2>nul
    echo   %ESC%[32m  ✔   Node.js успешно установлен портативно ^(x64^).%ESC%[0m
) else (
    echo   %ESC%[32m  ✔   Портативный Node.js уже есть ^(x64^).%ESC%[0m
)

REM === ИСПРАВЛЕНИЕ: Циклическая проверка доступности Node.js вместо timeout ===
echo   %ESC%[33m  →   Ожидание готовности Node.js...%ESC%[0m
:wait_node
"%NODE_EXE%" --version >nul 2>nul
if errorlevel 1 (
    timeout /t 1 /nobreak >nul
    goto wait_node
)
echo   %ESC%[32m  ✔   Node.js готов к работе.%ESC%[0m

REM Добавляем портативный Node.js в PATH
set "PATH=%NODE_DIR%;%PATH%"
set /p "=%ESC%[2m         Версия Node: %ESC%[0m" <nul
for /f "delims=" %%v in ('node --version 2^>nul') do (
    echo %%v
    goto :node_ok
)
echo %ESC%[1;31mX   Ошибка: node не запускается%ESC%[0m
:node_ok
echo.

REM ============================================================================
REM   ШАГ 3: Клонирование / обновление репозитория SillyTavern
REM ============================================================================
echo   %ESC%[1;33m[3/4]%ESC%[0m %ESC%[1mРабота с репозиторием SillyTavern...%ESC%[0m
set "ST_DIR=%~dp0..\SillyTavern"
if not exist "%ST_DIR%" (
    echo   %ESC%[33m  →   Папка SillyTavern не найдена. Клонируем репозиторий...%ESC%[0m
    git clone https://github.com/SillyTavern/SillyTavern.git "%ST_DIR%"
    if !errorlevel! neq 0 (
        echo   %ESC%[1;31m^[ОШИБКА^] Не удалось клонировать репозиторий. Проверьте Git и интернет.%ESC%[0m
        pause
        popd
        exit /b 1
    )
    echo   %ESC%[32m  ✔   Репозиторий успешно склонирован.%ESC%[0m
) else (
    echo   %ESC%[33m  →   Обновляем существующий репозиторий ^(git pull^)...%ESC%[0m
    pushd "%ST_DIR%"
    git pull
    if !errorlevel! neq 0 (
        echo   %ESC%[1;33m^[ПРЕДУПРЕЖДЕНИЕ^] Не удалось выполнить git pull.%ESC%[0m
        echo   %ESC%[33m       Возможны локальные изменения. Продолжаем с текущей версией.%ESC%[0m
    ) else (
        echo   %ESC%[32m  ✔   Репозиторий обновлён.%ESC%[0m
    )
    popd
)
echo.

REM ============================================================================
REM   ШАГ 4: Установка зависимостей npm (полностью portable кэш)
REM ============================================================================
echo   %ESC%[1;33m[4/4]%ESC%[0m %ESC%[1mУстановка зависимостей SillyTavern...%ESC%[0m
set "NPM_CACHE_DIR=%~dp0..\npm_cache"
if not exist "%NPM_CACHE_DIR%" mkdir "%NPM_CACHE_DIR%"

REM === ИСПРАВЛЕНИЕ: Полностью portable npm — изолируем от системных путей ===
set "NPM_CONFIG_CACHE=%NPM_CACHE_DIR%"
set "NPM_CONFIG_PREFIX=%~dp0..\npm_global"
set "NPM_CONFIG_USERCONFIG=%~dp0..\.npmrc"
set "HOME=%~dp0.."
set "USERPROFILE=%~dp0.."
set "APPDATA=%~dp0..\AppData\Roaming"
set "LOCALAPPDATA=%~dp0..\AppData\Local"

pushd "%ST_DIR%"

echo   %ESC%[2m       Используется портативный кэш npm: %NPM_CACHE_DIR%%ESC%[0m
echo   %ESC%[2m       Установка может занять несколько минут...%ESC%[0m

REM Запускаем npm установку с call для правильной передачи errorlevel
call "%NODE_DIR%\npm.cmd" install --no-save --no-audit --no-fund --loglevel=error --no-progress --omit=dev

if !errorlevel! neq 0 (
    echo.
    echo   %ESC%[1;31m^[ОШИБКА^] npm install завершился с ошибкой.%ESC%[0m
    echo   %ESC%[33m       Проверьте интернет-соединение.%ESC%[0m
    echo   %ESC%[33m       Если ошибка повторяется, запустите вручную:%ESC%[0m
    echo   %ESC%[36m       cd /d "%ST_DIR%" ^& "%NODE_DIR%\npm.cmd" install%ESC%[0m
    pause
    popd
    popd
    exit /b 1
)
popd
echo   %ESC%[1;32m  ✔   Зависимости успешно установлены.%ESC%[0m
echo.

REM ============================================================================
REM   ФИНАЛ
REM ============================================================================
echo  %ESC%[36m--------------------------------------------------------------------------------%ESC%[0m
echo   %ESC%[1;32mУстановка / Обновление завершены успешно!%ESC%[0m
echo.
echo   %ESC%[1;33mДля запуска SillyTavern используйте Start.bat или Start-Ext.bat%ESC%[0m
echo  %ESC%[36m--------------------------------------------------------------------------------%ESC%[0m
echo.

if "%AUTOCLOSE%"=="0" pause

popd
exit /b 0
