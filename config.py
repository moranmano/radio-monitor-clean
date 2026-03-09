import subprocess
import tempfile
from pathlib import Path


def capture_stream_window(stream_url: str, seconds: int, output_path: str) -> None:
    cmd = [
        'ffmpeg',
        '-y',
        '-i', stream_url,
        '-t', str(seconds),
        '-ac', '1',
        '-ar', '22050',
        '-f', 'wav',
        output_path,
    ]
    subprocess.run(cmd, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def cut_evidence(source_file: str, output_path: str, start_seconds: int = 0, duration_seconds: int = 10) -> None:
    cmd = [
        'ffmpeg',
        '-y',
        '-i', source_file,
        '-ss', str(start_seconds),
        '-t', str(duration_seconds),
        '-acodec', 'mp3',
        output_path,
    ]
    subprocess.run(cmd, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
