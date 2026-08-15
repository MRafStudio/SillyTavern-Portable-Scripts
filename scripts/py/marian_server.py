"""Marian NMT API Server — offline English to Russian translation.

v1.1: Offline-first loading. Если модель в кэше — не лезем в интернет.
      Если нет модели — пробуем скачать, при таймауте запускаемся с заглушкой.
"""

import json
import os
import re
import sys
from pathlib import Path

from fastapi import FastAPI
from pydantic import BaseModel
import uvicorn

# Кеш рядом со скриптом
cache_dir = Path(__file__).parent / "models_cache"
cache_dir.mkdir(exist_ok=True)
os.environ["HF_HOME"] = str(cache_dir)

# Порт из переменной окружения
PORT = int(os.environ.get("MARIAN_PORT", "5003"))

# Максимальная длина чанка в токенах
MAX_CHUNK_TOKENS = 400

app = FastAPI(title="Marian NMT (Offline)")

MODEL_NAME = "Helsinki-NLP/opus-mt-en-ru"
_model = None
_tokenizer = None
_model_available = False  # Флаг: загружена ли модель


def _check_cache_exists() -> bool:
    """Проверяет, есть ли модель в локальном кэше."""
    # Проверяем наличие ключевых файлов модели в кэше
    model_cache = cache_dir / "models--Helsinki-NLP--opus-mt-en-ru"
    if not model_cache.exists():
        return False
    
    # Проверяем наличие snapshot с файлами модели
    snapshots = list(model_cache.glob("snapshots/*"))
    if not snapshots:
        return False
    
    # Проверяем наличие config.json (минимальный индикатор)
    for snapshot in snapshots:
        if (snapshot / "config.json").exists():
            return True
    
    return False


def load_model():
    global _model, _tokenizer, _model_available
    
    if _model_available:
        return _model, _tokenizer
    
    print(f"[marian] Loading model {MODEL_NAME}...", flush=True)
    
    # === ЭТАП 1: Пробуем загрузить ТОЛЬКО из кэша (offline) ===
    if _check_cache_exists():
        print("[marian] Model found in cache. Loading offline...", flush=True)
        try:
            from transformers import MarianMTModel, MarianTokenizer
            _tokenizer = MarianTokenizer.from_pretrained(
                MODEL_NAME, 
                cache_dir=str(cache_dir),
                local_files_only=True  # <-- НЕ лезем в интернет!
            )
            _model = MarianMTModel.from_pretrained(
                MODEL_NAME, 
                cache_dir=str(cache_dir),
                local_files_only=True
            )
            _model_available = True
            print("[marian] Model loaded from cache! Ready for offline translation.", flush=True)
            return _model, _tokenizer
        except Exception as exc:
            print(f"[marian] Failed to load from cache: {exc}", flush=True)
            # Падаем ниже в этап 2
    
    # === ЭТАП 2: Модели нет в кэше — пробуем скачать ===
    print("[marian] Model not in cache. Trying to download from HuggingFace...", flush=True)
    try:
        from transformers import MarianMTModel, MarianTokenizer
        _tokenizer = MarianTokenizer.from_pretrained(
            MODEL_NAME, 
            cache_dir=str(cache_dir),
            local_files_only=False,
            timeout=30  # Таймаут 30 секунд на скачивание
        )
        _model = MarianMTModel.from_pretrained(
            MODEL_NAME, 
            cache_dir=str(cache_dir),
            local_files_only=False,
            timeout=30
        )
        _model_available = True
        print("[marian] Model downloaded and loaded! Ready for offline translation.", flush=True)
        return _model, _tokenizer
    except Exception as exc:
        print(f"[marian] FAILED to download model: {exc}", flush=True)
        print("[marian] Server will start with DUMMY translator (returns original text).", flush=True)
        _model_available = False
        return None, None


def split_into_sentences(text: str) -> list[str]:
    """Разбивает текст на предложения, сохраняя знаки препинания."""
    sentences = re.split(r'(?<<=[.!?])\s+', text.strip())
    return [s.strip() for s in sentences if s.strip()]


def chunk_sentences(sentences: list[str], tokenizer, max_tokens: int = MAX_CHUNK_TOKENS) -> list[str]:
    """Собирает предложения в чанки, не превышающие max_tokens токенов."""
    chunks = []
    current_chunk = []
    current_tokens = 0

    for sentence in sentences:
        token_count = len(tokenizer.encode(sentence, add_special_tokens=False))

        if token_count > max_tokens:
            if current_chunk:
                chunks.append(" ".join(current_chunk))
                current_chunk = []
                current_tokens = 0

            words = sentence.split()
            temp_chunk = []
            temp_tokens = 0
            for word in words:
                word_tokens = len(tokenizer.encode(word, add_special_tokens=False))
                if temp_tokens + word_tokens > max_tokens and temp_chunk:
                    chunks.append(" ".join(temp_chunk))
                    temp_chunk = [word]
                    temp_tokens = word_tokens
                else:
                    temp_chunk.append(word)
                    temp_tokens += word_tokens
            if temp_chunk:
                chunks.append(" ".join(temp_chunk))
            continue

        if current_tokens + token_count > max_tokens and current_chunk:
            chunks.append(" ".join(current_chunk))
            current_chunk = [sentence]
            current_tokens = token_count
        else:
            current_chunk.append(sentence)
            current_tokens += token_count

    if current_chunk:
        chunks.append(" ".join(current_chunk))

    return chunks


def translate_chunk(model, tokenizer, text: str) -> str:
    """Переводит один чанк текста."""
    inputs = tokenizer(text, return_tensors="pt", padding=True, truncation=True, max_length=512)
    translated = model.generate(**inputs)
    result = tokenizer.decode(translated[0], skip_special_tokens=True)
    return result


class TranslateRequest(BaseModel):
    q: str
    source: str = "en"
    target: str = "ru"


@app.post("/translate")
@app.get("/translate")
def translate(req: TranslateRequest):
    text = req.q.strip()
    if not text:
        return {"translatedText": ""}
    
    # === Если модель НЕ загружена — возвращаем оригинал с предупреждением ===
    if not _model_available or _model is None or _tokenizer is None:
        print(f"[marian] WARNING: Model not loaded. Returning original text.", flush=True)
        return {"translatedText": text, "warning": "Model not loaded. Translation unavailable."}

    # Если текст короткий — переводим сразу
    total_tokens = len(_tokenizer.encode(text, add_special_tokens=False))
    if total_tokens <= MAX_CHUNK_TOKENS:
        return {"translatedText": translate_chunk(_model, _tokenizer, text)}

    # Длинный текст — чанкинг
    print(f"[marian] Text too long ({total_tokens} tokens), splitting into chunks...", flush=True)
    sentences = split_into_sentences(text)
    chunks = chunk_sentences(sentences, _tokenizer, MAX_CHUNK_TOKENS)

    translated_parts = []
    for i, chunk in enumerate(chunks, 1):
        print(f"[marian] Translating chunk {i}/{len(chunks)} ({len(_tokenizer.encode(chunk, add_special_tokens=False))} tokens)...", flush=True)
        translated_parts.append(translate_chunk(_model, _tokenizer, chunk))

    result = " ".join(translated_parts)
    print(f"[marian] Translation complete: {len(chunks)} chunks -> {len(result)} chars", flush=True)
    return {"translatedText": result}


@app.get("/languages")
def languages():
    return {
        "en": {"name": "English", "targets": ["ru"]},
        "ru": {"name": "Russian", "targets": ["en"]}
    }


@app.get("/")
def health():
    return {
        "status": "ok" if _model_available else "degraded", 
        "model": MODEL_NAME, 
        "offline": True,
        "model_loaded": _model_available
    }


if __name__ == "__main__":
    print("[marian] Pre-loading model before server start...", flush=True)
    load_model()  # Предзагрузка модели ДО запуска uvicorn
    print(f"[marian] Starting server on port {PORT}...", flush=True)
    uvicorn.run(app, host="127.0.0.1", port=PORT, log_level="info")