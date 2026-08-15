"""Silero TTS - OpenAI-compatible /v1/audio/speech server.

Bundled with SillyTavern Portable by Neurogen as the *fast* Russian TTS
backend. Silero v5_4_ru produces ~10x real-time on CPU, so it pairs well
with SillyTavern's "Narrate by paragraphs" toggle for near-realtime
playback while the LLM is still streaming.

TRANSLATION: Marian NMT local server (port 5003) translates
English words/phrases -> Russian before synthesis. Fallback to
transliteration if Marian is offline or disabled via ENABLE_TRANSLATE.

WHITELIST: no_translate_words.ini (рядом со скриптом) — слова, которые
не переводятся через Marian. Если указано значение — используется оно,
если пусто — автотранслит.

UPGRADED v2.4.1: Fixed code fence flag logic (close before open) + legacy filter + 180s timeout
"""

from __future__ import annotations

import io
import json
import logging
import os
import re
import sys
import time
import urllib.request
from pathlib import Path

import numpy as np
import soundfile as sf
import torch
import uvicorn
from fastapi import FastAPI, HTTPException
from fastapi.responses import Response
from pydantic import BaseModel

# ============================================================================
# Environment Configuration
# ============================================================================
MODEL_ID = os.environ.get("SILERO_MODEL", "v5_4_ru")
LANGUAGE = os.environ.get("SILERO_LANGUAGE", "ru")
SAMPLE_RATE = int(os.environ.get("SILERO_SAMPLE_RATE", "48000"))
DEVICE = os.environ.get("SILERO_DEVICE", "cuda" if torch.cuda.is_available() else "cpu")
HOST = os.environ.get("SILERO_HOST", "127.0.0.1")
PORT = int(os.environ.get("SILERO_PORT", "8881"))

# TTS parameters (from Shurochka)
PUT_ACCENT = os.environ.get("SILERO_PUT_ACCENT", "1").strip() == "1"
PUT_YO = os.environ.get("SILERO_PUT_YO", "1").strip() == "1"
PUT_STRESS_HOMO = os.environ.get("SILERO_PUT_STRESS_HOMO", "1").strip() == "1"
PUT_YO_HOMO = os.environ.get("SILERO_PUT_YO_HOMO", "1").strip() == "1"
INTENSITY = os.environ.get("SILERO_INTENSITY", "3")
INTENSITY = int(INTENSITY) if INTENSITY.strip() else None

# Максимальная длина текста для одного вызова Silero (запас до 1000)
SILERO_MAX_CHARS = int(os.environ.get("SILERO_MAX_CHARS", "900"))

# Marian NMT API endpoint (local offline translator)
MARIAN_URL = os.environ.get("MARIAN_URL", "http://127.0.0.1:5003/translate")

# ENABLE_TRANSLATE: 1 = Marian включен, 0 = Marian выключен (только транслит)
ENABLE_TRANSLATE = os.environ.get("ENABLE_TRANSLATE", "0").strip() == "1"

# DEBUG mode
DEBUG_SILERO = os.environ.get("DEBUG_SILERO", "0").strip() == "1"

# ============================================================================
# ANSI Colors for console output
# ============================================================================
_ANSI_RESET = "\033[0m"
_ANSI_CYAN = "\033[1;36m"
_ANSI_YELLOW = "\033[1;33m"
_ANSI_GREEN = "\033[1;32m"
_ANSI_RED = "\033[1;31m"
_ANSI_MAGENTA = "\033[1;35m"

# ============================================================================
# Logging
# ============================================================================
logging.basicConfig(
    level=logging.INFO,
    format="[%(asctime)s] [%(levelname)s] %(message)s",
    datefmt="%H:%M:%S",
)
logger = logging.getLogger(__name__)

# ============================================================================
# JSON Block Flag Filter (v2.4.1) — глобальное состояние
# ============================================================================
_JSON_BLOCK_ACTIVE = False
_JSON_BLOCK_START_TIME = 0.0
_JSON_BLOCK_TIMEOUT = 180.0  # секунд

# ============================================================================
# Legacy Filter Data (v2.3) — ключи трекера, CSS, HTML
# ============================================================================
_RPG_JSON_KEYS = (
    "userStats", "infoBox", "characters", "stats", "status", "inventory",
    "onPerson", "clothing", "stored", "assets", "quests", "main", "optional",
    "date", "weather", "temperature", "time", "location", "recentEvents",
    "appearance", "demeanor", "relationship", "thoughts", "conditions",
    "mood", "health", "satiety", "energy", "hygiene", "arousal", "value",
    "name", "quantity", "title", "id", "emoji", "forecast", "unit", "start", "end",
    "content", "locked", "true", "false",
)

_CSS_PROPS = (
    "border-left", "padding", "background-color", "border-radius", "margin-bottom",
    "font-family", "color", "rgba", "px", "solid", "display", "position",
    "width", "height", "top", "left", "right", "bottom", "margin", "float",
    "text-align", "font-size", "font-weight", "line-height", "opacity",
    "transform", "transition", "animation", "overflow", "z-index", "flex",
    "grid", "align", "justify", "cursor", "pointer", "hover", "active",
)

_HTML_TAGS_RE = re.compile(r'<[^>]+>')
_CSS_PROP_RE = re.compile(r'\b(?:' + '|'.join(re.escape(p) for p in _CSS_PROPS) + r')\b')
_SYSTEM_INSTRUCTION_RE = re.compile(
    r'At the start of every reply.*?(?=```json|$)',
    re.DOTALL | re.IGNORECASE
)


def _reset_json_block_flag():
    """Сброс флага JSON-блока."""
    global _JSON_BLOCK_ACTIVE, _JSON_BLOCK_START_TIME
    _JSON_BLOCK_ACTIVE = False
    _JSON_BLOCK_START_TIME = 0.0


def _is_inside_json_block() -> bool:
    """Проверяет, активен ли флаг JSON-блока с учётом таймаута."""
    global _JSON_BLOCK_ACTIVE, _JSON_BLOCK_START_TIME
    if not _JSON_BLOCK_ACTIVE:
        return False
    if (time.time() - _JSON_BLOCK_START_TIME) > _JSON_BLOCK_TIMEOUT:
        if DEBUG_SILERO:
            print(f"{_ANSI_YELLOW}[DEBUG_SILERO] ⏰ JSON block flag timed out after {_JSON_BLOCK_TIMEOUT}s, resetting{_ANSI_RESET}", flush=True)
        _reset_json_block_flag()
        return False
    return True


def _legacy_is_rpg_tracker(text: str) -> bool:
    """Legacy filter (v2.3): проверяет по ключам, HTML, CSS, системным инструкциям."""
    stripped = text.strip()
    
    if not stripped:
        return True
    
    # Markdown code block
    if stripped.startswith("```") or stripped.endswith("```"):
        return True
    
    # Чистый JSON
    if stripped.startswith(("{", "[")) and stripped.endswith(("}", "]")):
        return True
    
    # HTML теги
    if _HTML_TAGS_RE.search(stripped):
        return True
    
    # CSS-свойства
    if _CSS_PROP_RE.search(stripped):
        return True
    
    # Ключи трекера
    text_lower = stripped.lower()
    for key in _RPG_JSON_KEYS:
        if key.lower() in text_lower:
            return True
    
    # Системные инструкции
    if _SYSTEM_INSTRUCTION_RE.search(stripped):
        return True
    
    # Только спецсимволы
    if re.match(r'^[\s\]\}\[\{":,.\'\\/`~!@#$%^&*()+=|<>?]+$', stripped):
        return True
    
    return False


def is_rpg_tracker_text(text: str) -> bool:
    """
    ДВОЙНАЯ ЗАЩИТА (v2.4.1):
    1. Флаг JSON-блока (```json ... ```) с таймаутом 180с
    2. Legacy filter (ключи, HTML, CSS, системные инструкции)
    
    ВАЖНО: Закрывающий ``` проверяется ДО открывающего, чтобы флаг правильно выключался!
    """
    global _JSON_BLOCK_ACTIVE, _JSON_BLOCK_START_TIME
    stripped = text.strip()
    
    # Пустой текст
    if not stripped:
        return True
    
    # === ПРОВЕРКА 1: ЗАКРЫВАЮЩИЙ CODE FENCE (должна быть ПЕРВОЙ!) ===
    # Строка равна ``` или заканчивается на ``` — выключаем флаг
    if stripped == "```" or stripped.endswith("```"):
        # Не выключаем флаг, если это открывающий (```json и т.д.) — проверим ниже
        # Но ```json тоже начинается с ``` и заканчивается... нет, ```json не заканчивается на ```
        # ```json — начинается с ```, но не заканчивается на ``` (заканчивается на n)
        # А ``` — заканчивается на ``` (равно)
        was_active = _JSON_BLOCK_ACTIVE
        _reset_json_block_flag()
        if DEBUG_SILERO:
            print(f"{_ANSI_YELLOW}[DEBUG_SILERO] 🏁 JSON block flag DEACTIVATED (was_active={was_active}){_ANSI_RESET}", flush=True)
        return True
    
    # === ПРОВЕРКА 2: ОТКРЫВАЮЩИЙ CODE FENCE ===
    # Начинается с ``` — включаем флаг (```json, ```html, ``` и т.д.)
    if stripped.startswith("```"):
        _JSON_BLOCK_ACTIVE = True
        _JSON_BLOCK_START_TIME = time.time()
        if DEBUG_SILERO:
            print(f"{_ANSI_YELLOW}[DEBUG_SILERO] 🚩 JSON block flag ACTIVATED ({stripped}){_ANSI_RESET}", flush=True)
        return True
    
    # === ПРОВЕРКА 3: ФЛАГ АКТИВЕН? ===
    if _is_inside_json_block():
        return True
    
    # === ПРОВЕРКА 4: LEGACY FILTER ===
    if _legacy_is_rpg_tracker(stripped):
        return True
    
    # === ПРОВЕРКА 5: КОРОТКИЕ JSON-КУСОЧКИ (< 32 символов) ===
    if len(stripped) < 32:
        if stripped.startswith('"') and '":' in stripped:
            return True
        if re.match(r'^[\d\s,\.\[\]\{\}]+$', stripped):
            return True
    
    return False


def debug_dump(text: str, label: str = "RAW INPUT"):
    """Выводит дамп текста в консоль с голубым цветом ANSI."""
    if not DEBUG_SILERO:
        return
        
    print(f"{_ANSI_CYAN}{'='*70}{_ANSI_RESET}", flush=True)
    print(f"{_ANSI_CYAN}[DEBUG_SILERO] {label}:{_ANSI_RESET}", flush=True)
    print(f"{_ANSI_CYAN}  Length: {len(text)} chars{_ANSI_RESET}", flush=True)
    print(f"{_ANSI_CYAN}  Content:{_ANSI_RESET}", flush=True)
    
    if not text.strip():
        print(f"{_ANSI_CYAN}    [EMPTY]{_ANSI_RESET}", flush=True)
    else:
        lines = text.split('\n')
        for i, line in enumerate(lines, 1):
            safe_line = line.replace('\r', '\\r').replace('\t', '\\t')
            if len(safe_line) > 200:
                safe_line = safe_line[:200] + "..."
            print(f"{_ANSI_CYAN}    [{i:03d}] {safe_line}{_ANSI_RESET}", flush=True)
    
    print(f"{_ANSI_CYAN}{'='*70}{_ANSI_RESET}", flush=True)


# ============================================================================
# Transliteration (Shurochka-style EN->RU for remaining Latin runs)
# ============================================================================
_EN_RU_DIGRAPHS: tuple[tuple[str, str], ...] = (
    ("sch", "щ"), ("shch", "щ"), ("ch", "ч"), ("sh", "ш"), ("zh", "ж"),
    ("kh", "х"), ("ts", "ц"), ("ya", "я"), ("yu", "ю"), ("yo", "ё"),
    ("th", "т"), ("ph", "ф"), ("ck", "к"), ("qu", "кв"), ("ee", "и"),
    ("oo", "у"), ("ou", "у"), ("ai", "эй"), ("ay", "эй"), ("ey", "эй"),
    ("ie", "и"),
)

_EN_RU_SINGLE: dict[str, str] = {
    "a": "а", "b": "б", "c": "к", "d": "д", "e": "е", "f": "ф",
    "g": "г", "h": "х", "i": "и", "j": "дж", "k": "к", "l": "л",
    "m": "м", "n": "н", "o": "о", "p": "п", "q": "к", "r": "р",
    "s": "с", "t": "т", "u": "у", "v": "в", "w": "в", "x": "кс",
    "y": "й", "z": "з",
}

_LATIN_RUN_RE = re.compile(r"[A-Za-z]+")


def _transliterate_word(word: str) -> str:
    lower = word.lower()
    out: list[str] = []
    i = 0
    n = len(lower)
    while i < n:
        matched = False
        for digraph, cyr in _EN_RU_DIGRAPHS:
            ln = len(digraph)
            if lower[i:i + ln] == digraph:
                out.append(cyr)
                i += ln
                matched = True
                break
        if not matched:
            out.append(_EN_RU_SINGLE.get(lower[i], ""))
            i += 1
    result = "".join(out)
    if word and word[0].isupper() and result:
        result = result[0].upper() + result[1:]
    return result


def _transliterate_latin(text: str) -> str:
    """Replace every Latin-letter run with a Cyrillic phonetic approximation."""
    return _LATIN_RUN_RE.sub(lambda m: _transliterate_word(m.group(0)), text)


# ============================================================================
# Загрузка белого списка из no_translate_words.ini
# ============================================================================
def load_no_translate_dict() -> dict[str, str | None]:
    """
    Загружает словарь из no_translate_words.ini (рядом со скриптом).
    Формат: слово=перевод  (если перевод пустой — будет автотранслит)
    Комментарии начинаются с ; или #
    """
    ini_path = Path(__file__).parent / "no_translate_words.ini"
    result: dict[str, str | None] = {}

    if not ini_path.exists():
        logger.info("no_translate_words.ini not found, using empty whitelist")
        return result

    logger.info("Loading whitelist from %s...", ini_path)
    count = 0

    with open(ini_path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith(";") or line.startswith("#"):
                continue

            if "=" in line:
                key, value = line.split("=", 1)
                key = key.strip().lower()
                value = value.strip()
                result[key] = value if value else None
                count += 1
            else:
                result[line.lower().strip()] = None
                count += 1

    logger.info("Loaded %d whitelist entries", count)
    return result


NO_TRANSLATE_DICT = load_no_translate_dict()

# ============================================================================
# Voice Configuration (v2.2)
# ============================================================================
AVAILABLE_VOICES = ("aidar", "baya", "kseniya", "xenia")
DEFAULT_VOICE = os.environ.get("SILERO_DEFAULT_VOICE", "xenia")

# ============================================================================
# Model Loading (torch.hub — like Shurochka)
# ============================================================================
def load_model():
    logger.info("Loading Silero %s/%s on %s via torch.hub...", LANGUAGE, MODEL_ID, DEVICE)
    t0 = time.time()

    try:
        model, _ = torch.hub.load(
            repo_or_dir="snakers4/silero-models",
            model="silero_tts",
            language=LANGUAGE,
            speaker=MODEL_ID,
            trust_repo=True,
        )
        model.to(torch.device(DEVICE))
    except Exception as exc:
        logger.error("Failed to load Silero %s/%s: %s", LANGUAGE, MODEL_ID, exc)
        raise

    # Validate speaker
    available = getattr(model, "speakers", None)
    if available:
        logger.info("Available speakers: %s", ", ".join(sorted(available)))

    # Detect v5 kwargs support
    import inspect
    apply_params = inspect.signature(model.apply_tts).parameters
    supports_v5 = "intensity" in apply_params

    elapsed = time.time() - t0
    logger.info(
        "Silero loaded in %.1fs (speaker=%s, sr=%d, v5_kwargs=%s)",
        elapsed, DEFAULT_VOICE, SAMPLE_RATE, supports_v5,
    )
    return model, supports_v5


print("[silero] Starting Silero TTS server v2.4.1 (OpenAI-compatible)", flush=True)
print(f"[silero] Model: {MODEL_ID}, Language: {LANGUAGE}, Device: {DEVICE}", flush=True)
print(f"[silero] ENABLE_TRANSLATE={ENABLE_TRANSLATE} (Marian {'enabled' if ENABLE_TRANSLATE else 'disabled'})", flush=True)
print(f"[silero] put_accent={PUT_ACCENT}, put_yo={PUT_YO}, intensity={INTENSITY}", flush=True)
print(f"[silero] DEBUG_SILERO={DEBUG_SILERO} (debug dump {'enabled' if DEBUG_SILERO else 'disabled'})", flush=True)
print(f"[silero] JSON block timeout: {_JSON_BLOCK_TIMEOUT}s", flush=True)

MODEL, SUPPORTS_V5 = load_model()
app = FastAPI(title="Silero TTS v2.4.1")


class SpeechRequest(BaseModel):
    model: str | None = None
    input: str
    voice: str | None = None
    response_format: str | None = "wav"
    speed: float | None = 1.0


# ============================================================================
# Voice Resolution with Fallback (v2.2)
# ============================================================================
def _resolve_voice(raw: str | None) -> tuple[str, bool]:
    """Best-effort map of the OpenAI 'voice' field to a Silero speaker.
    Returns: (voice_name, is_fallback) — is_fallback=True если подменили на дефолтный.
    """
    raw = (raw or "").strip().lower()

    for v in AVAILABLE_VOICES:
        if v in raw:
            return v, False

    # Неподдерживаемый голос — подменяем на aidar
    requested = raw if raw else "не указан"
    logger.warning("Голос '%s' недоступен в v5_4_ru. Доступные: %s. Используется: aidar", 
                   requested, ", ".join(AVAILABLE_VOICES))
    return "aidar", True


# ============================================================================
# Transliteration (preserved from original)
# ============================================================================
def translit_word(word: str) -> str:
    """Транслитерация одного английского слова."""
    table = [
        ('shch', 'щ'), ('sch', 'щ'), ('zh', 'ж'), ('ch', 'ч'), ('sh', 'ш'),
        ('kh', 'х'), ('ts', 'ц'), ('yu', 'ю'), ('ya', 'я'), ('ye', 'е'),
        ('yo', 'ё'), ('yi', 'й'), ('ij', 'ий'), ('ei', 'ей'), ('ie', 'е'),
        ('a', 'а'), ('b', 'б'), ('v', 'в'), ('g', 'г'), ('d', 'д'),
        ('e', 'е'), ('z', 'з'), ('i', 'и'), ('j', 'й'), ('k', 'к'),
        ('l', 'л'), ('m', 'м'), ('n', 'н'), ('o', 'о'), ('p', 'п'),
        ('r', 'р'), ('s', 'с'), ('t', 'т'), ('u', 'у'), ('f', 'ф'),
        ('h', 'х'), ('c', 'ц'), ('y', 'ы'), ("'", 'ь'), ('"', 'ъ'),
        ('w', 'в'), ('x', 'кс'), ('q', 'к'),
    ]

    result = ""
    i = 0
    word_lower = word.lower()

    while i < len(word):
        if re.match(r'[а-яё]', word_lower[i]):
            result += word[i]
            i += 1
            continue

        if re.match(r'[a-z]', word_lower[i]):
            matched = False
            for eng, rus in table:
                if word_lower.startswith(eng, i):
                    result += rus
                    i += len(eng)
                    matched = True
                    break
            if not matched:
                result += word[i]
                i += 1
            continue

        result += word[i]
        i += 1

    return result


def translate_word_marian(word: str) -> str | None:
    """Переводит одно английское слово/фразу через Marian."""
    clean = word.strip().lower()

    if clean in NO_TRANSLATE_DICT:
        return None

    if not clean or len(clean) < 2:
        return None

    payload = json.dumps({"q": word, "source": "en", "target": "ru"}).encode()

    req = urllib.request.Request(
        MARIAN_URL,
        data=payload,
        headers={"Content-Type": "application/json"},
        method="POST"
    )

    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            data = json.loads(resp.read())
            translated = data["translatedText"].strip()
            # Чистим артефакты Marian (например ":: перевод")
            translated = re.sub(r'^::\s*', '', translated)
            if translated and translated.lower() != clean:
                logger.info("Marian word: %r -> %r", word, translated)
                return translated
            return None
    except Exception:
        return None


def process_english_words(text: str) -> str:
    """
    Находит английские слова/фразы в тексте и обрабатывает их:
    - Если слово в NO_TRANSLATE_DICT с значением — используем значение
    - Если слово в NO_TRANSLATE_DICT без значения — автотранслит
    - ENABLE_TRANSLATE=1: остальные перевод через Marian, fallback на транслит
    - ENABLE_TRANSLATE=0: все транслит
    """
    pattern = re.compile(r'[a-zA-Z][a-zA-Z\-]*[a-zA-Z]|[a-zA-Z]{2,}')

    def replace_match(match: re.Match) -> str:
        word = match.group(0)
        clean = word.lower().strip()

        if clean in NO_TRANSLATE_DICT:
            custom = NO_TRANSLATE_DICT[clean]
            if custom is not None:
                logger.info("Whitelist custom: %r -> %r", word, custom)
                return custom
            else:
                transliterated = translit_word(word)
                logger.info("Whitelist translit: %r -> %r", word, transliterated)
                return transliterated

        if ENABLE_TRANSLATE:
            translated = translate_word_marian(word)
            if translated:
                return translated
            transliterated = translit_word(word)
            logger.info("Transliteration fallback: %r -> %r", word, transliterated)
            return transliterated
        else:
            transliterated = translit_word(word)
            logger.info("Transliteration: %r -> %r", word, transliterated)
            return transliterated

    return pattern.sub(replace_match, text)


# ============================================================================
# Preprocessing Pipeline (v2.2: без агрессивной санитизации!)
# ============================================================================
def _convert_numbers_to_words(text: str) -> str:
    """Конвертирует числа в тексте в слова по-русски."""
    from num2words import num2words
    
    def replace_number(match: re.Match) -> str:
        num_str = match.group(0)
        try:
            if '.' in num_str or ',' in num_str:
                num = float(num_str.replace(',', '.'))
                words = num2words(num, lang='ru')
                logger.info("Number converted: %s -> %s", num_str, words)
                return words
            else:
                num = int(num_str)
                words = num2words(num, lang='ru')
                logger.info("Number converted: %s -> %s", num_str, words)
                return words
        except Exception as exc:
            logger.warning("Failed to convert number %s: %s", num_str, exc)
            return num_str
    
    pattern = re.compile(r'\d+(?:[.,]\d+)?')
    return pattern.sub(replace_number, text)


def preprocess_text(text: str) -> str:
    """Full preprocessing pipeline: translit + numbers. Санитизация УДАЛЕНА — обрезала текст!"""
    # Step 1: Convert numbers to words
    text = _convert_numbers_to_words(text)
    
    # Step 2: Process English words (Marian or translit)
    if re.search(r'[a-zA-Z]{2,}', text):
        logger.info("Found English words in text, processing...")
        text = process_english_words(text)

    # Step 3: Transliterate remaining Latin runs (Shurochka-style)
    text = _transliterate_latin(text)

    return text


def split_into_sentences(text: str) -> list[str]:
    """Разбивает текст на предложения, сохраняя знаки препинания."""
    sentences = re.split(r'(?<<=[.!?])\s+', text.strip())
    return [s.strip() for s in sentences if s.strip()]


# ============================================================================
# Synthesis with v5 kwargs
# ============================================================================
def synthesize_single(text: str, voice: str) -> np.ndarray:
    """Синтезирует один кусок текста, возвращает numpy array float32."""
    kwargs: dict = {
        "text": text,
        "speaker": voice,
        "sample_rate": SAMPLE_RATE,
        "put_accent": PUT_ACCENT,
        "put_yo": PUT_YO,
    }

    # v5-only kwargs
    if SUPPORTS_V5:
        kwargs["put_stress_homo"] = PUT_STRESS_HOMO
        kwargs["put_yo_homo"] = PUT_YO_HOMO
        if INTENSITY is not None:
            kwargs["intensity"] = INTENSITY

    logger.debug("apply_tts kwargs: %s", kwargs)
    audio = MODEL.apply_tts(**kwargs)
    return audio.detach().cpu().numpy()


def synthesize_long_text(text: str, voice: str) -> np.ndarray:
    """Синтезирует длинный текст, разбивая на предложения и склеивая аудио."""
    sentences = split_into_sentences(text)
    segments = []
    current_chunk = ""
    current_len = 0

    for sentence in sentences:
        sent_len = len(sentence)

        if sent_len > SILERO_MAX_CHARS:
            if current_chunk:
                segments.append(current_chunk)
                current_chunk = ""
                current_len = 0

            words = sentence.split()
            temp_chunk = ""
            temp_len = 0
            for word in words:
                word_len = len(word) + 1
                if temp_len + word_len > SILERO_MAX_CHARS and temp_chunk:
                    segments.append(temp_chunk.strip())
                    temp_chunk = word + " "
                    temp_len = word_len
                else:
                    temp_chunk += word + " "
                    temp_len += word_len
            if temp_chunk.strip():
                segments.append(temp_chunk.strip())
            continue

        if current_len + sent_len + 1 > SILERO_MAX_CHARS and current_chunk:
            segments.append(current_chunk.strip())
            current_chunk = sentence + " "
            current_len = sent_len + 1
        else:
            current_chunk += sentence + " "
            current_len += sent_len + 1

    if current_chunk.strip():
        segments.append(current_chunk.strip())

    logger.info("Splitting text into %d segments (max %d chars each)...", len(segments), SILERO_MAX_CHARS)

    audio_segments = []
    for i, segment in enumerate(segments, 1):
        seg_len = len(segment)
        logger.info("Synthesizing segment %d/%d (%d chars)...", i, len(segments), seg_len)
        try:
            audio_seg = synthesize_single(segment, voice)
            audio_segments.append(audio_seg)
        except Exception as exc:
            logger.error("Segment %d failed: %s", i, exc)
            continue

    if not audio_segments:
        raise RuntimeError("All segments failed to synthesize")

    # Concatenate
    result = np.concatenate(audio_segments)
    logger.info("Synthesis complete: %d segments -> %.1fs audio", len(segments), len(result) / SAMPLE_RATE)
    return result


# ============================================================================
# API Endpoints
# ============================================================================
@app.get("/v1/models")
def list_models():
    return {
        "object": "list",
        "data": [{"id": "silero", "object": "model"}],
    }


@app.post("/v1/audio/speech")
def synth(req: SpeechRequest):
    # === ТОЧКА ВХОДА: получаем целый текст как есть ===
    raw_text = (req.input or "").strip()
    
    # === DEBUG: дамп целостного входящего текста ===
    debug_dump(raw_text, "RAW INPUT (ENTRY POINT)")
    
    if not raw_text:
        raise HTTPException(400, "empty input text")
    
    # === ФИЛЬТР RPG COMPANION / JSON BLOCK (v2.4.1) ===
    filter_result = is_rpg_tracker_text(raw_text)
    if filter_result:
        filter_reason = "JSON block flag" if _JSON_BLOCK_ACTIVE else "Legacy filter"
        if DEBUG_SILERO:
            print(f"{_ANSI_YELLOW}[DEBUG_SILERO] ⛔ FILTERED ({filter_reason}): RPG/JSON/tracker/system text. Returning silence.{_ANSI_RESET}", flush=True)
        # Возвращаем пустой WAV (0.01 сек тишины — минимум)
        buf = io.BytesIO()
        silence = np.zeros(int(SAMPLE_RATE * 0.01), dtype=np.float32)
        sf.write(buf, silence, SAMPLE_RATE, format="WAV", subtype="PCM_16")
        return Response(buf.getvalue(), media_type="audio/wav")
    # === КОНЕЦ ФИЛЬТРА ===
    
    # === DEBUG: дамп после фильтрации ===
    if DEBUG_SILERO:
        debug_dump(raw_text, "AFTER FILTER (WILL SYNTHESIZE)")
    
    # === КОМАНДЫ SILERO ===
    if raw_text.startswith("!!RNTW!!"):
        global NO_TRANSLATE_DICT
        try:
            NO_TRANSLATE_DICT = load_no_translate_dict()
            logger.info("Whitelist reloaded via command. Entries: %d", len(NO_TRANSLATE_DICT))
            # Возвращаем пустой WAV (0.01 сек тишины)
            buf = io.BytesIO()
            silence = np.zeros(int(SAMPLE_RATE * 0.01), dtype=np.float32)
            sf.write(buf, silence, SAMPLE_RATE, format="WAV", subtype="PCM_16")
            return Response(buf.getvalue(), media_type="audio/wav")
        except Exception as exc:
            logger.error("Failed to reload whitelist: %s", exc)
            raise HTTPException(500, f"Failed to reload whitelist: {exc}")
    # === КОНЕЦ КОМАНД ===

    # Preprocess text
    text = preprocess_text(raw_text)
    if not text:
        raise HTTPException(400, "input contained no synthesizable text after preprocessing")

    voice, is_fallback = _resolve_voice(req.voice)
    fmt = (req.response_format or "wav").lower()
    if fmt not in ("wav", "mp3", "ogg", "flac", "opus"):
        fmt = "wav"

    # Если голос подменён — добавляем предупреждение в начало текста
    if is_fallback:
        warning = "Выбранный голос недоступен для этой модели. Используется айдар. "
        text = warning + text
        logger.info("Добавлено аудио-предупреждение о подмене голоса")

    # Synthesize
    try:
        if len(text) <= SILERO_MAX_CHARS:
            audio = synthesize_single(text, voice)
        else:
            audio = synthesize_long_text(text, voice)
    except Exception as exc:
        logger.error("Synthesis failed: %s", exc)
        raise HTTPException(500, f"silero synthesis failed: {exc}")

    # Export
    buf = io.BytesIO()
    if fmt == "wav":
        # WAV via soundfile (PCM_16) — Shurochka style, maximum quality
        sf.write(buf, audio, SAMPLE_RATE, format="WAV", subtype="PCM_16")
        media_type = "audio/wav"
    else:
        # Fallback: use pydub for MP3/OGG/FLAC/OPUS
        try:
            from pydub import AudioSegment
        except ImportError:
            raise HTTPException(500, "pydub required for non-WAV formats")

        pcm16 = (audio * 32767.0).clip(-32768, 32767).astype(np.int16).tobytes()
        seg = AudioSegment(
            data=pcm16,
            sample_width=2,
            frame_rate=SAMPLE_RATE,
            channels=1,
        )
        seg.export(buf, format=fmt)
        media_types = {
            "mp3": "audio/mpeg",
            "ogg": "audio/ogg",
            "flac": "audio/flac",
            "opus": "audio/opus",
        }
        media_type = media_types[fmt]

    return Response(buf.getvalue(), media_type="audio/wav")


if __name__ == "__main__":
    uvicorn.run(app, host=HOST, port=PORT, log_level="info")