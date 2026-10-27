# MiniBuddy AI

A floating macOS buddy with chat and AI support.

## Features
- floating draggable buddy UI
- menu bar access
- AI chat panel
- Ollama support
- OpenAI-compatible API support
- automatic DMG build

## Build
Run on a Mac:

```bash
chmod +x build.sh && ./build.sh
```

This creates:
- `build/MiniBuddy AI.app`
- `build/MiniBuddy AI.dmg`

## Use
- Open the DMG and drag MiniBuddy AI to Applications.
- If you use Ollama, start it and type your model name, e.g. `llama3.2`
- If you use OpenAI-compatible services, paste your API key in Settings.

## Notes
- Requires macOS 14+
- Ad hoc signed, free for local use
- Not notarized
