@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

REM Обработка параметра autoclose
set "AUTOCLOSE=0"
if "%1"=="1" set "AUTOCLOSE=1"

REM ============================================================================
REM   KoboldCpp Portable — менеджер загрузки LLM моделей
REM ============================================================================

title KoboldCpp Portable — Загрузка моделей
pushd %~dp0..

for /f %%a in ('powershell -Command "Write-Host ([char]27) -NoNewline"') do set "ESC=%%a"

set "PYTHON_DIR=%~dp0..\python-3.11.9"
set "KCPP_DIR=%~dp0..\kobold"
set "KCPP_EXE=%KCPP_DIR%\koboldcpp.exe"
set "MODELS_DIR=%KCPP_DIR%\models"
if not exist "%MODELS_DIR%" mkdir "%MODELS_DIR%"

REM Добавляем Scripts в PATH для доступа к hf.exe
set "PATH=%PYTHON_DIR%;%PYTHON_DIR%\Scripts;%PATH%"

REM ============================================================================
REM   Проверка наличия KoboldCpp
REM ============================================================================
if not exist "%KCPP_EXE%" (
    cls
    echo.
    echo  %ESC%[1;31m################################################################################%ESC%[0m
    echo  %ESC%[1;31m##                                                                            ##%ESC%[0m
    echo  %ESC%[1;31m##%ESC%[0m                %ESC%[1;37mKoboldCpp Portable%ESC%[0m   —   %ESC%[1;33mЗагрузка LLM моделей%ESC%[0m               %ESC%[1;31m##%ESC%[0m
    echo  %ESC%[1;31m##                                                                            ##%ESC%[0m
    echo  %ESC%[1;31m################################################################################%ESC%[0m
    echo.
    echo   %ESC%[1;31m  ✗   KoboldCpp не установлен!%ESC%[0m
    echo   %ESC%[33m      Загрузка моделей невозможна без установленного KoboldCpp.%ESC%[0m
    echo   %ESC%[33m      Сначала установите KoboldCpp через меню установки компонентов.%ESC%[0m
    echo.
    echo   %ESC%[2m      Возврат в главное меню через 5 секунд...%ESC%[0m
    timeout /t 3 /nobreak >nul
    popd
    exit /b 0
)

:menu
cls
echo.
echo  %ESC%[1;36m################################################################################%ESC%[0m
echo  %ESC%[1;36m##                                                                            ##%ESC%[0m
echo  %ESC%[1;36m##%ESC%[0m               %ESC%[1;37mKoboldCpp Portable%ESC%[0m   —   %ESC%[1;33mЗагрузка LLM моделей%ESC%[0m                %ESC%[1;36m##%ESC%[0m
echo  %ESC%[1;36m##                                                                            ##%ESC%[0m
echo  %ESC%[1;36m################################################################################%ESC%[0m
echo.
echo   %ESC%[1;33mМодели будут сохранены в: %MODELS_DIR%%ESC%[0m
echo.
echo   %ESC%[1;33mДоступные модели:%ESC%[0m
echo.
echo     %ESC%[1;37m[1]%ESC%[0m %ESC%[1;32mGemma 4 E4B Heretic%ESC%[0m    %ESC%[2m(5.2 ГБ, Q4_K_M, лёгкая, текстовая)%ESC%[0m
echo     %ESC%[1;37m[2]%ESC%[0m %ESC%[1;33mGemma 4 E4B Heretic%ESC%[0m    %ESC%[2m(8.1 ГБ, Q8_0, средняя, текстовая)%ESC%[0m
echo     %ESC%[1;37m[3]%ESC%[0m %ESC%[1;35mGemma 4 E4B Heretic%ESC%[0m    %ESC%[2m(15.1 ГБ, BF16, тяжёлая, текстовая)%ESC%[0m
echo     %ESC%[1;37m[4]%ESC%[0m %ESC%[1;35mVistral 24B Instruct%ESC%[0m   %ESC%[2m(19 ГБ, Q6_K, тяжёлая, текстовая)%ESC%[0m
echo     %ESC%[1;37m[5]%ESC%[0m %ESC%[1;33mQwen 3.6-27B%ESC%[0m           %ESC%[2m(13.6 ГБ, Q3_K_M, средняя, мультимодальная)%ESC%[0m
echo     %ESC%[1;37m[6]%ESC%[0m %ESC%[1;35mQwen 3.6-27B%ESC%[0m           %ESC%[2m(19.5 ГБ, Q5_K_M, тяжёлая, мультимодальная)%ESC%[0m
echo.
echo     %ESC%[1;37m[8]%ESC%[0m %ESC%[1;37mВвести ID модели и имя файла вручную%ESC%[0m
echo.
echo     %ESC%[1;37m[9]%ESC%[0m %ESC%[1;37mПоказать список загруженных моделей%ESC%[0m
echo.
echo     %ESC%[1;37m[0]%ESC%[0m %ESC%[1mНазад в главное меню%ESC%[0m
echo.
set "choice="
set /p "choice=%ESC%[33mВыберите действие (0-9): %ESC%[0m"

set "choice=!choice: =!"
set "MODEL_ID="
set "MODEL_SIZE="
set "PROJECTOR="

if "!choice!"=="" goto menu
if "!choice!"=="1" set "MODEL_ID=igorls/gemma-4-E4B-it-heretic-GGUF" & set "FILENAME=gemma-4-E4B-it-heretic-Q4_K_M.gguf" & set "MODEL_SIZE=5.2 ГБ" & goto do_download
if "!choice!"=="2" set "MODEL_ID=igorls/gemma-4-E4B-it-heretic-GGUF" & set "FILENAME=gemma-4-E4B-it-heretic-Q8_0.gguf" & set "MODEL_SIZE=8.1 ГБ" & goto do_download
if "!choice!"=="3" set "MODEL_ID=igorls/gemma-4-E4B-it-heretic-GGUF" & set "FILENAME=gemma-4-E4B-it-heretic-BF16.gguf" & set "MODEL_SIZE=15.1 ГБ" & goto do_download
if "!choice!"=="4" set "MODEL_ID=mradermacher/Vistral-24B-Instruct-i1-GGUF" & set "FILENAME=Vistral-24B-Instruct.i1-Q6_K.gguf" & set "MODEL_SIZE=19 ГБ" & goto do_download
if "!choice!"=="5" set "MODEL_ID=unsloth/Qwen3.6-27B-GGUF" & set "FILENAME=Qwen3.6-27B-Q3_K_M.gguf" & set "MODEL_SIZE=13.6 ГБ" & set "PROJECTOR=mmproj-F16.gguf" & goto do_download_qwen
if "!choice!"=="6" set "MODEL_ID=unsloth/Qwen3.6-27B-GGUF" & set "FILENAME=Qwen3.6-27B-Q5_K_M.gguf" & set "MODEL_SIZE=19.5 ГБ" & set "PROJECTOR=mmproj-F16.gguf" & goto do_download_qwen
if "!choice!"=="8" goto manual_download
if "!choice!"=="9" goto list_models
if "!choice!"=="0" goto exit
goto menu

:manual_download
echo.
set /p "MODEL_ID=%ESC%[33mID модели (например: igorls/gemma-4-E4B-it-heretic-GGUF): %ESC%[0m"
if "!MODEL_ID!"=="" goto menu
set /p "FILENAME=%ESC%[33mИмя файла (например: gemma-4-E4B-it-heretic-Q4_K_M.gguf): %ESC%[0m"
if "!FILENAME!"=="" goto menu
set "MODEL_SIZE=неизвестно"
set "PROJECTOR="
goto do_download

:do_download_qwen
echo.
echo   %ESC%[1;33m→%ESC%[0m %ESC%[1mЗагрузка основной модели !FILENAME!%ESC%[0m
echo   %ESC%[2m   Размер: !MODEL_SIZE!%ESC%[0m
echo   %ESC%[2m   Источник: !MODEL_ID!%ESC%[0m
echo   %ESC%[2m   Это может занять длительное время. Пожалуйста, подождите.%ESC%[0m
echo.
hf download "!MODEL_ID!" "!FILENAME!" --local-dir "%MODELS_DIR%"
if !errorlevel! neq 0 (
    echo.
    echo   %ESC%[1;31m^[ОШИБКА^] Не удалось загрузить основную модель.%ESC%[0m
    pause
	
    :: Выходим - выполнялась первая установка
    :: Возвращаем 0 потому как так и задумано
    if "%AUTOCLOSE%"=="1" exit /b 0
    goto menu
)
echo.
echo   %ESC%[1;33m→%ESC%[0m %ESC%[1mЗагрузка проектора !PROJECTOR!%ESC%[0m
echo   %ESC%[2m   Размер: 0.93 ГБ%ESC%[0m
echo   %ESC%[2m   Необходим для работы мультимодальной модели.%ESC%[0m
echo.
hf download "!MODEL_ID!" "!PROJECTOR!" --local-dir "%MODELS_DIR%"
if !errorlevel! neq 0 (
    echo.
    echo   %ESC%[1;31m^[ОШИБКА^] Не удалось загрузить проектор.%ESC%[0m
    echo   %ESC%[33m       Основная модель загружена, проектор можно скачать позже.%ESC%[0m
    pause
	
	:: Сохраняем по крайней мере основную модель
	set "MODEL=!FILENAME!"
	call :save_ini
	
    :: Выходим - выполнялась первая установка
    if "%AUTOCLOSE%"=="1" exit /b 0
    goto menu
)
echo.
echo   %ESC%[1;32m  ✔   Модель и проектор успешно загружены!%ESC%[0m

REM === АВТОУСТАНОВКА В settings.ini ===
set "MODEL=!FILENAME!"
set "MMPROJ=!PROJECTOR!"
call :save_ini
pause

:: Выходим - выполнялась первая установка
if "%AUTOCLOSE%"=="1" exit /b 0
goto menu

:do_download
set "MODEL_PATH=%MODELS_DIR%\!FILENAME!"

if exist "!MODEL_PATH!" (
    echo.
    echo   %ESC%[1;33m⚠   Модель уже существует: !FILENAME!%ESC%[0m
    pause
	
    :: Выходим - выполнялась первая установка
    if "%AUTOCLOSE%"=="1" exit /b 0
    goto menu
)

echo.
echo   %ESC%[1;33m→%ESC%[0m %ESC%[1mЗагрузка модели !FILENAME!%ESC%[0m
echo   %ESC%[2m   Размер: !MODEL_SIZE!%ESC%[0m
echo   %ESC%[2m   Источник: !MODEL_ID!%ESC%[0m
echo   %ESC%[2m   Это может занять длительное время. Пожалуйста, подождите.%ESC%[0m
echo.

hf download "!MODEL_ID!" "!FILENAME!" --local-dir "%MODELS_DIR%"

if !errorlevel! neq 0 (
    echo.
    echo   %ESC%[1;31m^[ОШИБКА^] Не удалось загрузить модель.%ESC%[0m
    echo   %ESC%[33m       Проверьте ID модели и имя файла.%ESC%[0m
    pause
	
    :: Выходим - выполнялась первая установка
    :: Возвращаем 0 потому как так и задумано
    if "%AUTOCLOSE%"=="1" exit /b 0
    goto menu
)

echo.
echo   %ESC%[1;32m  ✔   Модель успешно загружена!%ESC%[0m

REM === АВТОУСТАНОВКА В settings.ini ===
set "MODEL=!FILENAME!"
set "MMPROJ="
call :save_ini
pause

:: Выходим - выполнялась первая установка
if "%AUTOCLOSE%"=="1" exit /b 0
goto menu

:list_models
cls
echo.
echo   %ESC%[1;36m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━%ESC%[0m
echo   %ESC%[1;36m                 Загруженные модели в папке kobold\models\                     %ESC%[0m
echo   %ESC%[1;36m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━%ESC%[0m
echo.
set "COUNT=0"
for %%f in ("%MODELS_DIR%\*.gguf") do (
    set /a "COUNT+=1"
    set "FNAME=%%~nxf"
    for /f "delims=" %%s in ('powershell -Command "[math]::Round((Get-Item '%%f').Length / 1GB, 2)"') do set "FSIZE_GB=%%s"
    echo     %ESC%[1;32m!COUNT!%ESC%[0m. !FNAME! %ESC%[2m(!FSIZE_GB! ГБ^)%ESC%[0m
)
if %COUNT%==0 (
    echo     %ESC%[1;31m✗   Нет загруженных моделей%ESC%[0m
)
echo.
pause
goto menu

:save_ini
REM ============================================================================
REM   Сохранение настроек в settings.ini (с сохранением существующих)
REM ============================================================================
set "CONFIG_FILE=%~dp0settings.ini"

REM Загружаем настройки (если есть)
if exist "%CONFIG_FILE%" (
    for /f "usebackq delims=" %%a in ("%CONFIG_FILE%") do set "%%a"
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
if not defined ENABLE_WHISPER set ENABLE_WHISPER=0
if not defined WHISPER_MODEL set WHISPER_MODEL=

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
    echo ENABLE_WHISPER=!ENABLE_WHISPER!
    echo WHISPER_MODEL=!WHISPER_MODEL!
) > "%CONFIG_FILE%"

REM === Вывод сообщения в зависимости от того, что сохранено ===
if not "!MODEL!"=="" (
    if not "!MMPROJ!"=="" (
        echo   %ESC%[1;33m  →   Модель и проектор сохранены в настройках.%ESC%[0m
    ) else (
        echo   %ESC%[1;33m  →   Модель сохранена в настройках.%ESC%[0m
    )
) else (
    if not "!MMPROJ!"=="" (
        echo   %ESC%[1;33m  →   Проектор сохранён в настройках.%ESC%[0m
    )
)

exit /b 0

:exit
popd
exit /b 0