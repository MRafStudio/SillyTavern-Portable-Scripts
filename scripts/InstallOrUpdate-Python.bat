@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

REM ============================================================================
REM   Python 3.11.9 Portable — установка / обновление (общий для всех модулей)
REM ============================================================================

title Python Portable — Установка / Обновление

set "AUTOCLOSE=0"
if "%1"=="1" set "AUTOCLOSE=1"

pushd %~dp0..

for /f %%a in ('powershell -Command "Write-Host ([char]27) -NoNewline"') do set "ESC=%%a"

cls
::echo %AUTOCLOSE%
echo.
echo  %ESC%[1;36m################################################################################%ESC%[0m
echo  %ESC%[1;36m##                                                                            ##%ESC%[0m
echo  %ESC%[1;36m##%ESC%[0m           %ESC%[1;37mPython 3.11.9 Portable%ESC%[0m   —   %ESC%[1;33mУстановка / Обновление%ESC%[0m              %ESC%[1;36m##%ESC%[0m
echo  %ESC%[1;36m##                                                                            ##%ESC%[0m
echo  %ESC%[1;36m################################################################################%ESC%[0m
echo.

echo   %ESC%[1;33m[0/3]%ESC%[0m %ESC%[1mПроверка разрядности Windows...%ESC%[0m
set ARCH_OK=0
if "%PROCESSOR_ARCHITECTURE%"=="AMD64" set ARCH_OK=1
if "%PROCESSOR_ARCHITEW6432%"=="AMD64" set ARCH_OK=1

if %ARCH_OK%==0 (
    echo.
    echo   %ESC%[1;31m^[ОШИБКА^] Обнаружена 32-разрядная ^(x86^) версия Windows.%ESC%[0m
    if "%AUTOCLOSE%"=="0" pause
    popd
    exit /b 1
)
echo   %ESC%[1;32m  ✔   Система 64-разрядная (x64).%ESC%[0m
echo.

set "PYTHON_DIR=%~dp0..\python-3.11.9"
set "PYTHON_EXE=%PYTHON_DIR%\python.exe"

if exist "%PYTHON_EXE%" (
    echo   %ESC%[32m  ✔   Python уже установлен.%ESC%[0m
    set /p "=%ESC%[2m       Версия: %ESC%[0m" <nul
    "%PYTHON_EXE%" --version 2>nul
    echo.
    goto check_hf
)

echo   %ESC%[1;33m[1/3]%ESC%[0m %ESC%[1mЗагрузка Python 3.11.9...%ESC%[0m
echo   %ESC%[2m       ~180 МБ, первая загрузка может занять время%ESC%[0m

curl -# -L -o "%TEMP%\python-3.11.9-amd64.zip" "https://www.python.org/ftp/python/3.11.9/python-3.11.9-amd64.zip"
if !errorlevel! neq 0 (
    echo   %ESC%[1;31m^[ОШИБКА^] Не удалось загрузить Python.%ESC%[0m
    if "%AUTOCLOSE%"=="0" pause
    popd
    exit /b 1
)

echo   %ESC%[32m  ✔   Загрузка завершена.%ESC%[0m
echo.
echo   %ESC%[1;33m[2/3]%ESC%[0m %ESC%[1mРаспаковка...%ESC%[0m

if exist "%PYTHON_DIR%" rmdir /s /q "%PYTHON_DIR%"
mkdir "%PYTHON_DIR%"
powershell -Command "& { Expand-Archive -Path '%TEMP%\python-3.11.9-amd64.zip' -DestinationPath '%PYTHON_DIR%' -Force }"
del "%TEMP%\python-3.11.9-amd64.zip" 2>nul

echo   %ESC%[32m  ✔   Python успешно установлен в python-3.11.9\%ESC%[0m
set /p "=%ESC%[2m       Версия: %ESC%[0m" <nul
"%PYTHON_EXE%" --version 2>nul
echo.

:check_hf
REM ============================================================================
REM   Установка / обновление huggingface-hub (для hf.exe)
REM ============================================================================
echo   %ESC%[1;33m[3/3]%ESC%[0m %ESC%[1mПроверка hf.exe...%ESC%[0m

REM Добавляем Scripts в PATH для текущей сессии
set "PATH=%PYTHON_DIR%;%PYTHON_DIR%\Scripts;%PATH%"

where hf >nul 2>nul
if !errorlevel! neq 0 (
    echo   %ESC%[33m  →   Установка huggingface-hub...%ESC%[0m
    "%PYTHON_EXE%" -m pip install huggingface-hub --quiet --no-warn-script-location
    if !errorlevel! neq 0 (
        echo   %ESC%[1;31m^[ОШИБКА^] Не удалось установить huggingface-hub.%ESC%[0m
        echo   %ESC%[33m       Загрузка моделей будет недоступна.%ESC%[0m
    ) else (
        echo   %ESC%[32m  ✔   hf.exe установлен.%ESC%[0m
    )
) else (
    echo   %ESC%[33m  →   Обновление huggingface-hub...%ESC%[0m
    REM === ИСПРАВЛЕНИЕ: Всегда обновляем hf.exe до последней версии ===
    "%PYTHON_EXE%" -m pip install --upgrade huggingface-hub --quiet --no-warn-script-location
    if !errorlevel! neq 0 (
        echo   %ESC%[1;33m  ⚠   Не удалось обновить huggingface-hub. Используется текущая версия.%ESC%[0m
    ) else (
        echo   %ESC%[32m  ✔   hf.exe обновлён до последней версии.%ESC%[0m
    )
)

echo.
echo  %ESC%[36m--------------------------------------------------------------------------------%ESC%[0m
echo   %ESC%[1;32mPython 3.11.9 успешно установлен!%ESC%[0m
echo   %ESC%[2m  Путь: %PYTHON_DIR%%ESC%[0m
echo   %ESC%[2m  hf.exe: готов к загрузке моделей%ESC%[0m
echo  %ESC%[36m--------------------------------------------------------------------------------%ESC%[0m
echo.

if "%AUTOCLOSE%"=="0" pause
popd
exit /b 0
