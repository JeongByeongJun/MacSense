# MacSense

MacSense is a macOS menu bar app that observes repeated click/menu patterns and recommends faster shortcuts or user automation recipes.

## MVP Scope

- Supported apps: Finder, Chrome, Notes
- Event capture: CGEventTap
- UI context extraction: macOS Accessibility API
- Local storage: SQLite
- Recommendation flow:
  - Official shortcut DB match first
  - Groq `openai/gpt-oss-120b` automation recipe fallback
  - Shortcuts app launcher for custom automation

## Build

```bash
./build.sh
```

Output:

```text
build/macsense
```

## Runtime Permissions

Grant `build/macsense` permissions in:

- System Settings -> Privacy & Security -> Accessibility
- System Settings -> Privacy & Security -> Input Monitoring

For AI fallback recommendations:

```bash
export GROQ_API_KEY="gsk_..."
./build/macsense
```
