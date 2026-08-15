call "%~dp0InstallOrUpdate-SillyTavern.bat" 1
if errorlevel 1 (
    echo   %ESC%[1;31m[ОШИБКА] Python не установился. Остановка.%ESC%[0m
    pause
    popd
    exit /b 1
)

pause