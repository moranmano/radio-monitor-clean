import io
import json
import math
import tempfile
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import librosa
import numpy as np
import soundfile as sf


TARGET_SR = 22050


@dataclass
class MatchResult:
    matched: bool
    confidence: float


class AudioMatcher:
    def load_audio(self, raw_bytes: bytes) -> tuple[np.ndarray, int]:
        data, sr = sf.read(io.BytesIO(raw_bytes), dtype='float32', always_2d=False)
        if data.ndim > 1:
            data = np.mean(data, axis=1)
        if sr != TARGET_SR:
            data = librosa.resample(y=data, orig_sr=sr, target_sr=TARGET_SR)
            sr = TARGET_SR
        return data.astype(np.float32), sr

    def load_audio_file(self, file_path: str) -> tuple[np.ndarray, int]:
        data, sr = librosa.load(file_path, sr=TARGET_SR, mono=True)
        return data, sr

    def build_fingerprint(self, raw_bytes: bytes) -> dict[str, Any]:
        y, sr = self.load_audio(raw_bytes)
        return self._fingerprint_from_array(y, sr)

    def build_fingerprint_from_file(self, file_path: str) -> dict[str, Any]:
        y, sr = self.load_audio_file(file_path)
        return self._fingerprint_from_array(y, sr)

    def _fingerprint_from_array(self, y: np.ndarray, sr: int) -> dict[str, Any]:
        duration = float(len(y) / sr)
        chroma = librosa.feature.chroma_stft(y=y, sr=sr, n_fft=4096, hop_length=512)
        mel = librosa.feature.melspectrogram(y=y, sr=sr, n_fft=2048, hop_length=512, n_mels=64)
        mel_db = librosa.power_to_db(mel, ref=np.max)

        chroma_mean = chroma.mean(axis=1)
        mel_mean = mel_db.mean(axis=1)

        chroma_norm = chroma_mean / (np.linalg.norm(chroma_mean) + 1e-9)
        mel_norm = mel_mean / (np.linalg.norm(mel_mean) + 1e-9)

        return {
            "duration_seconds": duration,
            "chroma": chroma_norm.tolist(),
            "mel": mel_norm.tolist(),
            "version": 1,
        }

    def compare_fingerprint_to_window(self, ad_fp: dict[str, Any], window_bytes: bytes) -> MatchResult:
        window_fp = self.build_fingerprint(window_bytes)
        return self.compare_fingerprints(ad_fp, window_fp)

    def compare_fingerprints(self, ad_fp: dict[str, Any], window_fp: dict[str, Any]) -> MatchResult:
        ad_chroma = np.array(ad_fp['chroma'], dtype=np.float32)
        ad_mel = np.array(ad_fp['mel'], dtype=np.float32)
        win_chroma = np.array(window_fp['chroma'], dtype=np.float32)
        win_mel = np.array(window_fp['mel'], dtype=np.float32)

        chroma_sim = self.cosine_similarity(ad_chroma, win_chroma)
        mel_sim = self.cosine_similarity(ad_mel, win_mel)

        ad_duration = float(ad_fp.get('duration_seconds', 0.0))
        win_duration = float(window_fp.get('duration_seconds', 0.0))
        duration_penalty = min(ad_duration, win_duration) / max(ad_duration, win_duration) if max(ad_duration, win_duration) > 0 else 0.0

        confidence = (0.5 * chroma_sim) + (0.35 * mel_sim) + (0.15 * duration_penalty)
        return MatchResult(matched=False, confidence=float(max(0.0, min(1.0, confidence))))

    @staticmethod
    def cosine_similarity(a: np.ndarray, b: np.ndarray) -> float:
        denom = (np.linalg.norm(a) * np.linalg.norm(b)) + 1e-9
        return float(np.dot(a, b) / denom)
