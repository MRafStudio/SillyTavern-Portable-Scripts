# SillyTavern Portable

## Описание

SillyTavern Portable — портабельная Windows-сборка [SillyTavern](https://github.com/SillyTavern/SillyTavern) с локальным стеком ИИ-сервисов:

- **KoboldCpp** — локальный LLM-сервер (GGUF-модели, Vision + Whisper)
- **Silero TTS v2** — озвучка ответов (CPU)
- **Marian NMT** — переводчик для Silero
- **Портабельные Python 3.11.9 и Node.js** — изолированное окружение без установки в систему

## 🚀 Быстрый старт

1. Склонируйте этот репозиторий, например:
```text
     cd D:/
     git clone https://github.com/MRafStudio/SillyTavern-Portable-Scripts.git SillyTavern-Portable
     cd SillyTavern-Portable
```

2. Запустите `Start.bat`

## 📁 Структура проекта

```
SillyTavern-Portable/
├── Start.bat                               # Главное меню
├── scripts/                                # Скрипты управления (в репозитории)
│   ├── InstallOrUpdate.bat                 # Меню Установка / Обновление компонентов
│   ├── InstallOrUpdate-All.bat             # Установка / Обновление всех компонентов
│   ├── InstallOrUpdate-Python.bat          # Установка / Обновление Python
│   ├── InstallOrUpdate-SillyTavern.bat     # Установка / Обновление SillyTavern
│   ├── InstallOrUpdate-Kobold.bat          # Установка / Обновление KoboldCpp
│   ├── InstallOrUpdate-Silero.bat          # Установка / Обновление Silero TTS
│   ├── InstallOrUpdate-Marian.bat          # Установка / Обновление Marian NMT
│   ├── Config.bat                          # Настройка компонентов (settings.ini)
│   ├── Download-Model.bat                  # Загрузка LLM моделей
│   ├── KoboldSettings.bat                  # Настройка KoboldCpp
│   ├── StartSillyTavern.bat                # Запуск всех сервисов
│   ├── py/                                 # Python-серверы (Silero, Marian)
│   └── data/                               # Шаблоны настроек (default.kcpps)
├── SillyTavern/                            # Движок (устанавливается скриптами: [1])
├── kobold/                                 # KoboldCpp + модели (устанавливается)
├── python-3.11.9/                          # Портабельный Python (устанавливается)
├── node-dist/                              # Портабельный Node.js (устанавливается)
├── marian/                                 # Marian NMT (устанавливается)
├── tts-cpu/                                # Silero TTS (устанавливается)
└── data/                                   # Данные SillyTavern (создаются при запуске)
```

## 📦 Установка

1. Установите **Git for Windows** (если ещё не установлен)
2. Запустите `Start.bat`
3. Выберите пункт **[1] Установка / Обновление компонентов**
4. Дождитесь установки всех компонентов системы
5. Выберите пункт **[2] Настройка компонентов** — укажите модель LLM и порты
6. Выберите пункт **[3] Загрузка LLM моделей** — скачайте модель (GGUF, при необходимости mmproj)

## ▶️ Запуск

1. Запустите `Start.bat`
2. Нажмите Enter (или выберите пункт **[ * ] Запуск SillyTavern**)
3. Запустятся все сервисы: KoboldCpp → Marian NMT → Silero TTS → SillyTavern UI
4. Откройте в браузере: `http://localhost:8000`

## ⚙️ Требования

- Windows 10/11
- Git for Windows
- Доступ в интернет для загрузки компонентов
- Видеокарта NVIDIA (для LLM-моделей в KoboldCpp; CPU-режим тоже поддерживается)
