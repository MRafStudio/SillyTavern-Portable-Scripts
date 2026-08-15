@REM scripts\Llama-Service.bat — установка/удаление службы Llama.cpp (SillyTavern Portable)
@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

title Llama.cpp — Служба Windows (SillyTavern Portable)

REM ============================================================================
REM   Пути
REM ============================================================================
set "SCRIPTS_DIR=%~dp0"
if "%SCRIPTS_DIR:~-1%"=="\" set "SCRIPTS_DIR=%SCRIPTS_DIR:~0,-1%"

for %%F in ("%SCRIPTS_DIR%\..") do set "ROOT_DIR=%%~fF"

set "DATA_DIR=%ROOT_DIR%\data"
set "LLAMA_DIR=%DATA_DIR%\llama"
set "LLAMA_EXE=%LLAMA_DIR%\llama-server.exe"
set "MODELS_DIR=%DATA_DIR%\llm\models"
set "SETTINGS=%SCRIPTS_DIR%\settings.ini"
set "PY=%ROOT_DIR%\python-3.11.9\python.exe"
set "NSSM_EXE=%ROOT_DIR%\scripts\bin\nssm.exe"

REM Имя службы — уникальное (на машине может стоять служба LlamaCPP от Hermes Portable!)
set "SERVICE_NAME=LlamaCPP-ST"
set "LLAMA_PORT=5001"

REM Дефолтная модель — из settings.ini (единый источник правды)
set "MODEL="
set "MMPROJ="
if exist "%SETTINGS%" (
    for /f "usebackq delims=" %%a in ("%SETTINGS%") do set "%%a"
)
if not defined LLM_PORT set LLM_PORT=5001
if not defined MODEL set MODEL=Qwen3.6-27B-Q5_K_M.gguf
if not defined MMPROJ set MMPROJ=mmproj-F16.gguf

REM Изоляция данных
set "TEMP=%DATA_DIR%\temp"
set "TMP=%DATA_DIR%\temp"
if not exist "%TEMP%" mkdir "%TEMP%" 2>nul

REM ============================================================================
REM   ESC
REM ============================================================================
for /f "delims=#" %%a in ('"prompt #$E# & echo on & for %%_ in (1) do rem"') do set "ESC=%%a"

REM ============================================================================
REM   Меню
REM ============================================================================
:menu
cls
echo.
echo %ESC%[1;33m-= Llama.cpp — служба Windows (SillyTavern Portable) =-%ESC%[0m
echo.
sc query "%SERVICE_NAME%" >nul 2>&1
if not errorlevel 1 (
    echo %ESC%[1;32m+ %ESC%[0m Служба %SERVICE_NAME% — установлена
    for /f "tokens=4" %%s in ('sc query "%SERVICE_NAME%" ^| findstr "STATE"') do set "SV_STATE=%%s"
    if /i "!SV_STATE!"=="RUNNING" (
        echo %ESC%[1;32m  ✔ %ESC%[0m Служба работает ^(http://127.0.0.1:!LLM_PORT!^)
    ) else (
        echo %ESC%[1;33m  . %ESC%[0m Служба остановлена — запустите вручную или после перезагрузки ПК
    )
) else (
    echo %ESC%[1;33m. %ESC%[0m Служба %SERVICE_NAME% — не установлена
)
echo.
echo   [1] Установить службу %SERVICE_NAME% ^(автозапуск, 24/7^)
echo   [2] Удалить службу %SERVICE_NAME%
echo   [0] Назад
echo.
set "choice="
set /p "choice=%ESC%[33mВыберите действие (0-2): %ESC%[0m"
if "%choice%"=="1" goto install_service
if "%choice%"=="2" goto uninstall_service
if "%choice%"=="0" goto menu_end
goto menu

REM ============================================================================
REM   Установка службы
REM ============================================================================
:install_service
REM служба требует прав администратора
net session >nul 2>&1
if errorlevel 1 (
    echo   %ESC%[1;31m[ОШИБКА] Установка службы требует прав администратора.%ESC%[0m
    echo   %ESC%[33m  Запустите скрипт от имени администратора и повторите.%ESC%[0m
    pause
    goto menu
)
if not exist "%LLAMA_EXE%" (
    echo   %ESC%[1;31m[ОШИБКА] Llama.cpp не установлен.%ESC%[0m
    echo   %ESC%[33m  Установите его: меню [1] → Llama.cpp.%ESC%[0m
    pause
    goto menu
)
if not exist "%MODELS_DIR%\%MODEL%" (
    echo   %ESC%[1;31m[ОШИБКА] Модель не найдена: %MODEL%%ESC%[0m
    echo   %ESC%[33m  Скачайте её: меню [3] «Загрузка LLM моделей».%ESC%[0m
    pause
    goto menu
)

echo   %ESC%[2m  Исполняемый: %LLAMA_EXE%%ESC%[0m
echo   %ESC%[2m  Модель:      %MODEL%%ESC%[0m
if not "%MMPROJ%"=="" echo   %ESC%[2m  Проектор:    %MMPROJ%%ESC%[0m
echo   %ESC%[2m  Порт:        %LLM_PORT%%ESC%[0m
echo.

REM --- KV-квант + запас токенов + контекст — из справочника моделей (llama_models.py) ---
set "SERVER_FLAGS="
set "MAXCTX=16384"
if exist "%PY%" (
    "%PY%" "%SCRIPTS_DIR%\py\llama_models.py" flags "%MODEL%" > "%TEMP%\llama_server_flags.txt" 2>nul
    set /p SERVER_FLAGS=<"%TEMP%\llama_server_flags.txt"
    "%PY%" "%SCRIPTS_DIR%\py\llama_models.py" maxctx "%MODEL%" > "%TEMP%\llama_maxctx.txt" 2>nul
    set /p MAXCTX=<"%TEMP%\llama_maxctx.txt"
)

REM --- Собираем аргументы llama-server ---
set "SRV_ARGS=-m "%MODELS_DIR%\%MODEL%" --alias llama/%MODEL:~0,-5% -c !MAXCTX! !SERVER_FLAGS! -ngl 999 --flash-attn 1 --parallel 1 --port !LLM_PORT! --host 127.0.0.1"
if not "%MMPROJ%"=="" if exist "%MODELS_DIR%\%MMPROJ%" (
    set "SRV_ARGS=--mmproj "%MODELS_DIR%\%MMPROJ%" !SRV_ARGS!"
)

REM --- nssm install ---
"%NSSM_EXE%" install "%SERVICE_NAME%" "%LLAMA_EXE%" !SRV_ARGS!
if errorlevel 1 (
    echo   %ESC%[1;31m[ОШИБКА] nssm install не удался.%ESC%[0m
    pause
    goto menu
)

"%NSSM_EXE%" set "%SERVICE_NAME%" AppDirectory "%LLAMA_DIR%" >nul 2>&1
"%NSSM_EXE%" set "%SERVICE_NAME%" AppStdout "%TEMP%\llama-service.out.log" >nul 2>&1
"%NSSM_EXE%" set "%SERVICE_NAME%" AppStderr "%TEMP%\llama-service.err.log" >nul 2>&1
"%NSSM_EXE%" set "%SERVICE_NAME%" AppRotateFiles 1 >nul 2>&1
"%NSSM_EXE%" set "%SERVICE_NAME%" AppRotateBytes 10485760 >nul 2>&1
"%NSSM_EXE%" set "%SERVICE_NAME%" Start SERVICE_AUTO_START >nul 2>&1
"%NSSM_EXE%" set "%SERVICE_NAME%" AppExit Default Restart >nul 2>&1

"%NSSM_EXE%" start "%SERVICE_NAME%" >nul 2>&1
if errorlevel 1 (
    echo   %ESC%[1;33m  .   Служба установлена, но не запустилась — проверьте %TEMP%\llama-service.err.log%ESC%[0m
) else (
    echo   %ESC%[1;32m+ %ESC%[0m Служба %SERVICE_NAME% установлена и запущена.
)
echo   %ESC%[2m  API: http://127.0.0.1:!LLM_PORT!/v1%ESC%[0m
echo   %ESC%[2m  В SillyTavern: OpenAI-совместимый API, URL http://127.0.0.1:!LLM_PORT!/v1%ESC%[0m
echo.
pause
goto menu

REM ============================================================================
REM   Удаление службы
REM ============================================================================
:uninstall_service
"%NSSM_EXE%" stop "%SERVICE_NAME%" >nul 2>&1
"%NSSM_EXE%" remove "%SERVICE_NAME%" confirm >nul 2>&1
if errorlevel 1 (
    echo   %ESC%[1;33m  .   Служба не найдена или уже удалена.%ESC%[0m
) else (
    echo   %ESC%[1;32m+ %ESC%[0m Служба %SERVICE_NAME% удалена.
)
pause
goto menu

:menu_end
exit /b 0
