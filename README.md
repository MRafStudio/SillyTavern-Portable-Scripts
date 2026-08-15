# SillyTavern Portable

## Описание

SillyTavern Portable — портабельная Windows-сборка [SillyTavern](https://github.com/SillyTavern/SillyTavern) с локальным стеком ИИ-сервисов:

- **Llama.cpp (llama-server)** — локальный LLM-сервер (GGUF-модели, Vision), работает **24/7 как служба Windows** (LlamaCPP-ST)
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
│   ├── InstallOrUpdate-Llama.bat           # Установка / Обновление llama.cpp
│   ├── InstallOrUpdate-Silero.bat          # Установка / Обновление Silero TTS
│   ├── InstallOrUpdate-Marian.bat          # Установка / Обновление Marian NMT
│   ├── Llama-Service.bat                   # Служба LLM (llama.cpp, 24/7)
│   ├── Config.bat                          # Настройка компонентов (settings.ini)
│   ├── Download-Model.bat                  # Загрузка LLM моделей
│   ├── StartSillyTavern.bat                # Запуск SillyTavern (проверяет службу LLM)
│   ├── bin/nssm.exe                        # Менеджер служб (для Llama-Service.bat)
│   └── py/                                 # Справочник моделей + Python-серверы (Silero, Marian)
├── SillyTavern/                            # Движок (устанавливается скриптами: [1])
├── python-3.11.9/                          # Портабельный Python (устанавливается)
├── node-dist/                              # Портабельный Node.js (устанавливается)
├── marian/                                 # Marian NMT (устанавливается)
├── tts-cpu/                                # Silero TTS (устанавливается)
└── data/                                   # Служебные данные (создаются при установке)
    ├── llama/                              # Бинарники llama.cpp
    ├── llm/models/                         # GGUF-модели и проекторы (mmproj)
    └── temp/                               # Временные файлы и логи службы
```

## 📦 Установка

1. Установите **Git for Windows** (если ещё не установлен)
2. Запустите `Start.bat`
3. Выберите пункт **[1] Установка / Обновление компонентов** — установятся Python, SillyTavern, llama.cpp, Silero, Marian
4. Выберите пункт **[3] Загрузка LLM моделей** — скачайте модель и проектор (mmproj)
5. Выберите пункт **[4] Служба LLM** — установите службу `LlamaCPP-ST` (от имени администратора)

Доступные модели (обе мультимодальные):

| Модель | Файл | Размер | Мин. VRAM |
|---|---|---|---|
| Qwen 3.6-35B-A3B | `Qwen3.6-35B-A3B-UD-IQ4_NL.gguf` | 18.0 ГБ | 24 GB |
| Gemma 4-26B-A4B | `gemma-4-26B-A4B-it-UD-IQ4_NL.gguf` | 13.6 ГБ | 20 GB |

## ▶️ Запуск

1. Служба LLM стартует автоматически при загрузке Windows (или вручную через **[4] Служба LLM**)
2. Запустите `Start.bat` и нажмите Enter
3. `StartSillyTavern.bat` проверит готовность LLM (`http://localhost:5001`) и поднимет Marian → Silero → SillyTavern UI
4. Откройте в браузере: `http://localhost:8000`

В SillyTavern подключите LLM как OpenAI-совместимый API: `http://localhost:5001/v1`.

## ⚙️ Требования

- Windows 10/11
- Git for Windows
- Доступ в интернет для загрузки компонентов
- Видеокарта NVIDIA (для LLM-моделей; CPU-режим тоже поддерживается)
