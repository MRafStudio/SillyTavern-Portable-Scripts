"""Download Marian NMT model for offline use."""

import sys
import os
from pathlib import Path
from transformers import MarianMTModel, MarianTokenizer

# Кеш рядом со скриптом (portable!)
cache_dir = Path(__file__).parent / "models_cache"
cache_dir.mkdir(exist_ok=True)
os.environ["HF_HOME"] = str(cache_dir)

model_name = 'Helsinki-NLP/opus-mt-en-ru'

print(f'[25%] Loading tokenizer for {model_name}...')
sys.stdout.flush()
tokenizer = MarianTokenizer.from_pretrained(model_name, cache_dir=str(cache_dir))
print('[50%] Tokenizer cached')
sys.stdout.flush()

print(f'[75%] Loading model for {model_name}...')
sys.stdout.flush()
model = MarianMTModel.from_pretrained(model_name, cache_dir=str(cache_dir))
print('[100%] Model cached')
sys.stdout.flush()

print(f'Model saved to: {cache_dir}')