# llama_models.py — справочник моделей Llama.cpp для SillyTavern Portable
# Каждая запись: (id, КОРОТКОЕ имя, ПОЛНОЕ имя с .gguf, размер, мин. VRAM GB,
#                 mmproj_ЛОКАЛЬНОЕ (имя файла в models/), repo, max_ctx,
#                 kv_quant, n_predict)
# ВАЖНО про mmproj (по опыту Hermes):
#   Qwen3.6-35B   -> mmproj-F16.gguf   (из репо)
#   Gemma-4-26B   -> mmproj-BF16.gguf  (только BF16! F16 из репо НЕ грузится:
#                     image_max_pixels < image_min_pixels)
# max_ctx — рекомендуемый контекст для llama-server (KV-кэш должен влезать в VRAM).
# kv_quant — квантование KV-кэша (--cache-type-k/v):
#   q8_0 — лучшее качество длинного контекста, но ест ~2x VRAM (проверено на 32GB);
#   q4_0 — для Qwen-35B при 262k контекста (впритык по VRAM).
# n_predict — запас токенов на вызов (--n-predict): думание + content должны влезать.
# Думание (reasoning) ВСЕГДА ВКЛЮЧЕНО (нативно в llama-server) — флагом не управляется.
#
# CLI:
#   list                  — все записи: id|label|file|size|vram|mmproj|repo|maxctx
#   flags <file>          — KV-квант + n_predict для модели: "--cache-type-k Q --cache-type-v Q --n-predict N"
#   maxctx <file>         — рекомендуемый контекст (число)
#   (файловый обмен с .bat: вывод БЕЗ внешних кавычек — для set /p и nssm)
import os
import sys

MODELS = [
    # (id, короткое имя, полное имя с .gguf, размер, мин. VRAM GB, mmproj_ЛОКАЛЬНОЕ, repo, max_ctx, kv_quant, n_predict)
    # =====================================================================================================================
    # Основная модель для 24+ GB VRAM
    (1, "Qwen 3.6-35B-A3B UD-IQ4_NL", "Qwen3.6-35B-A3B-UD-IQ4_NL.gguf", "18.0 GB", 24,
     "mmproj-F16.gguf", "unsloth/Qwen3.6-35B-A3B-GGUF", 262144, "q4_0", "65536"),
    # 20+ GB VRAM (качество длинного контекста: q8_0 KV)
    (2, "Gemma 4-26B-A4B UD-Q4_K_XL", "gemma-4-26B-A4B-it-UD-Q4_K_XL.gguf", "17.0 GB", 20,
     "mmproj-BF16.gguf", "unsloth/gemma-4-26B-A4B-it-GGUF", 262144, "q8_0", "65536"),
]

ESC = "\x1b"

# индексы полей
I_ID, I_LABEL, I_FILE, I_SIZE, I_VRAM, I_MMPROJ, I_REPO, I_MAXCTX, I_KV, I_NPREDICT = range(10)


def out(s):
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass
    sys.stdout.write(s + "\n")


def find_by_file(fname):
    """имя .gguf → запись или None (без учёта регистра)."""
    if not fname:
        return None
    f = fname.strip()
    for m in MODELS:
        if m[I_FILE].lower() == f.lower():
            return m
    return None


def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else "list"
    if cmd == "list":
        models_dir = sys.argv[2] if len(sys.argv) > 2 else ""
        w = max(len(m[I_LABEL]) for m in MODELS)
        for m in MODELS:
            mark = ""
            if models_dir and os.path.exists(os.path.join(models_dir, m[I_FILE])):
                mark = f"{ESC}[1;32m+{ESC}[0m "
            out(f"{m[I_ID]}. {mark}{m[I_LABEL]:<{w}}  {m[I_SIZE]}  (мин. {m[I_VRAM]} GB VRAM)")
    elif cmd == "flags":
        m = find_by_file(sys.argv[2] if len(sys.argv) > 2 else "")
        if m:
            out(f"--cache-type-k {m[I_KV]} --cache-type-v {m[I_KV]} --n-predict {m[I_NPREDICT]}")
    elif cmd == "maxctx":
        m = find_by_file(sys.argv[2] if len(sys.argv) > 2 else "")
        if m:
            out(str(m[I_MAXCTX]))
    else:
        out("usage: llama_models.py list [models_dir] | flags <file> | maxctx <file>")


if __name__ == "__main__":
    main()
