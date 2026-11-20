"""Records every phrase in phrases.json as an MP3 using the Aria neural voice.
Run: tts-venv\\Scripts\\python.exe -I voice\\record.py   (re-run after editing phrases.json)
"""
import asyncio, json, pathlib, sys
import edge_tts

VOICE = "en-US-AriaNeural"
here = pathlib.Path(__file__).resolve().parent
phrases = json.loads((here / "phrases.json").read_text(encoding="utf-8"))
force = "--force" in sys.argv

async def main():
    for key, text in phrases.items():
        out = here / f"{key}.mp3"
        if out.exists() and not force:
            continue
        await edge_tts.Communicate(text, VOICE, rate="+0%", pitch="+0Hz").save(str(out))
        print("recorded", key)

asyncio.run(main())
