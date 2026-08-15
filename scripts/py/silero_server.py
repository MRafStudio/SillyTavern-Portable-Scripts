"""Silero TTS - OpenAI-compatible /v1/audio/speech server.

Bundled with SillyTavern Portable by Neurogen as the *fast* Russian TTS
backend. Silero v4_ru produces ~10x real-time on CPU, so it pairs well
with SillyTavern's "Narrate by paragraphs" toggle for near-realtime
playback while the LLM is still streaming.

TRANSLATION: Marian NMT local server (port 5003) translates
English words/phrases -> Russian before synthesis. Fallback to 
transliteration if Marian is offline or disabled via ENABLE_TRANSLATE.

WHITELIST: no_translate_words.ini (рядом со скриптом) — слова, которые
не переводятся через Marian. Если указано значение — используется оно,
если пусто — автотранслит.
"""

import io
import json
import os
import re
import sys
import urllib.request
from pathlib import Path

import numpy as np
import torch
import uvicorn
from fastapi import FastAPI, HTTPException
from fastapi.responses import Response
from pydantic import BaseModel
from pydub import AudioSegment

MODEL_URL = os.environ.get(
    "SILERO_MODEL_URL", "https://models.silero.ai/models/tts/ru/v5_ru.pt"
)
MODEL_PATH = Path(
    os.environ.get(
        "SILERO_MODEL_PATH",
        str(Path(__file__).parent / "silero" / "v5_ru.pt"),
    )
)
SAMPLE_RATE = int(os.environ.get("SILERO_SAMPLE_RATE", "48000"))
DEVICE = os.environ.get("SILERO_DEVICE", "cuda" if torch.cuda.is_available() else "cpu")
HOST = os.environ.get("SILERO_HOST", "127.0.0.1")
PORT = int(os.environ.get("SILERO_PORT", "8881"))

# Максимальная длина текста для одного вызова Silero (запас до 1000)
SILERO_MAX_CHARS = int(os.environ.get("SILERO_MAX_CHARS", "900"))

# Marian NMT API endpoint (local offline translator)
MARIAN_URL = os.environ.get("MARIAN_URL", "http://127.0.0.1:5003/translate")

# ENABLE_TRANSLATE: 1 = Marian включен, 0 = Marian выключен (только транслит)
ENABLE_TRANSLATE = os.environ.get("ENABLE_TRANSLATE", "0").strip() == "1"

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
        print(f"[silero] no_translate_words.ini not found, using empty whitelist", flush=True)
        return result
    
    print(f"[silero] Loading whitelist from {ini_path}...", flush=True)
    count = 0
    
    with open(ini_path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            # Пропускаем пустые строки и комментарии
            if not line or line.startswith(";") or line.startswith("#"):
                continue
            
            # Разделяем по первому =
            if "=" in line:
                key, value = line.split("=", 1)
                key = key.strip().lower()
                value = value.strip()
                
                # Если значение пустое — None (будет автотранслит)
                result[key] = value if value else None
                count += 1
            else:
                # Если нет = — просто слово, автотранслит
                result[line.lower().strip()] = None
                count += 1
    
    print(f"[silero] Loaded {count} whitelist entries", flush=True)
    return result


NO_TRANSLATE_DICT = load_no_translate_dict()

VOICES = ("kseniya", "baya", "xenia", "aidar", "eugene", "random")
DEFAULT_VOICE = os.environ.get("SILERO_DEFAULT_VOICE", "kseniya")


def ensure_model() -> Path:
    if MODEL_PATH.exists():
        return MODEL_PATH
    print(
        f"[silero] First-run: downloading model from {MODEL_URL}",
        flush=True,
    )
    print(f"[silero] -> {MODEL_PATH}", flush=True)
    MODEL_PATH.parent.mkdir(parents=True, exist_ok=True)
    tmp = MODEL_PATH.with_suffix(".pt.part")
    urllib.request.urlretrieve(MODEL_URL, tmp)
    tmp.replace(MODEL_PATH)
    size_mb = MODEL_PATH.stat().st_size / 1e6
    print(f"[silero] Model downloaded ({size_mb:.1f} MB)", flush=True)
    return MODEL_PATH


def load_model():
    path = ensure_model()
    print(f"[silero] Loading {path} on device={DEVICE} ...", flush=True)
    model = torch.package.PackageImporter(str(path)).load_pickle(
        "tts_models", "model"
    )
    model.to(DEVICE)
    print(
        f"[silero] Model loaded. Voices: {', '.join(VOICES)}",
        flush=True,
    )
    return model


print("[silero] Starting Silero TTS server (OpenAI-compatible)", flush=True)
print(f"[silero] ENABLE_TRANSLATE={ENABLE_TRANSLATE} (Marian {'enabled' if ENABLE_TRANSLATE else 'disabled'})", flush=True)
MODEL = load_model()
app = FastAPI(title="Silero TTS")


class SpeechRequest(BaseModel):
    model: str | None = None
    input: str
    voice: str | None = None
    response_format: str | None = "mp3"
    speed: float | None = 1.0


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
    
    # Проверяем белый список
    if clean in NO_TRANSLATE_DICT:
        return None  # Будет обработано в process_english_words
    
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
            if translated and translated.lower() != clean:
                print(f"[silero] Marian word: {word!r} -> {translated!r}", flush=True)
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
        
        # Проверяем белый список
        if clean in NO_TRANSLATE_DICT:
            custom = NO_TRANSLATE_DICT[clean]
            if custom is not None:
                # Есть кастомный перевод
                print(f"[silero] Whitelist custom: {word!r} -> {custom!r}", flush=True)
                return custom
            else:
                # Автотранслит
                transliterated = translit_word(word)
                print(f"[silero] Whitelist translit: {word!r} -> {transliterated!r}", flush=True)
                return transliterated
        
        if ENABLE_TRANSLATE:
            translated = translate_word_marian(word)
            if translated:
                return translated
            transliterated = translit_word(word)
            print(f"[silero] Transliteration fallback: {word!r} -> {transliterated!r}", flush=True)
            return transliterated
        else:
            transliterated = translit_word(word)
            print(f"[silero] Transliteration: {word!r} -> {transliterated!r}", flush=True)
            return transliterated

    return pattern.sub(replace_match, text)


def _resolve_voice(raw: str | None) -> str:
    """Best-effort map of the OpenAI 'voice' field to a Silero speaker."""
    raw = (raw or "").strip().lower()
    for v in VOICES:
        if v in raw:
            return v
    return DEFAULT_VOICE


def split_into_sentences(text: str) -> list[str]:
    """Разбивает текст на предложения, сохраняя знаки препинания."""
    sentences = re.split(r'(?<=<<=[.!?])\s+', text.strip())
    return [s.strip() for s in sentences if s.strip()]


def synthesize_single(text: str, voice: str) -> AudioSegment:
    """Синтезирует один кусок текста в AudioSegment."""
    audio = MODEL.apply_tts(
        text=text, speaker=voice, sample_rate=SAMPLE_RATE
    )
    pcm16 = (
        (audio.numpy() * 32767.0)
        .clip(-32768, 32767)
        .astype(np.int16)
        .tobytes()
    )
    return AudioSegment(
        data=pcm16,
        sample_width=2,
        frame_rate=SAMPLE_RATE,
        channels=1,
    )


def synthesize_long_text(text: str, voice: str) -> AudioSegment:
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

    print(f"[silero] Splitting text into {len(segments)} segments (max {SILERO_MAX_CHARS} chars each)...", flush=True)
    audio_segments = []
    for i, segment in enumerate(segments, 1):
        seg_len = len(segment)
        print(f"[silero] Synthesizing segment {i}/{len(segments)} ({seg_len} chars)...", flush=True)
        try:
            audio_seg = synthesize_single(segment, voice)
            audio_segments.append(audio_seg)
        except Exception as exc:
            print(f"[silero] Segment {i} failed: {exc}", flush=True)
            continue

    if not audio_segments:
        raise RuntimeError("All segments failed to synthesize")

    result = audio_segments[0]
    for seg in audio_segments[1:]:
        result += seg

    print(f"[silero] Synthesis complete: {len(segments)} segments -> {len(result) / 1000:.1f}s audio", flush=True)
    return result


@app.get("/v1/models")
def list_models():
    return {
        "object": "list",
        "data": [{"id": "silero", "object": "model"}],
    }


@app.post("/v1/audio/speech")
def synth(req: SpeechRequest):
    text = (req.input or "").strip()
    if not text:
        raise HTTPException(400, "empty input text")

    # Проверяем, есть ли английские слова в тексте
    if re.search(r'[a-zA-Z]{2,}', text):
        print(f"[silero] Found English words in text, processing (ENABLE_TRANSLATE={ENABLE_TRANSLATE})...", flush=True)
        text = process_english_words(text)
        print(f"[silero] Result: {text[:100]!r}...", flush=True)

    voice = _resolve_voice(req.voice)

    if len(text) <= SILERO_MAX_CHARS:
        try:
            audio_seg = synthesize_single(text, voice)
        except Exception as exc:
            raise HTTPException(500, f"silero synthesis failed: {exc}")
    else:
        try:
            audio_seg = synthesize_long_text(text, voice)
        except Exception as exc:
            raise HTTPException(500, f"silero synthesis failed: {exc}")

    fmt = (req.response_format or "mp3").lower()
    if fmt not in ("mp3", "wav", "ogg", "flac", "opus"):
        fmt = "mp3"
    buf = io.BytesIO()
    audio_seg.export(buf, format=fmt)
    media = {
        "mp3": "audio/mpeg",
        "wav": "audio/wav",
        "ogg": "audio/ogg",
        "flac": "audio/flac",
        "opus": "audio/opus",
    }[fmt]
    return Response(buf.getvalue(), media_type=media)


if __name__ == "__main__":
    uvicorn.run(app, host=HOST, port=PORT, log_level="info")