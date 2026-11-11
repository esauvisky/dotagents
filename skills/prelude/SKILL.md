---
name: prelude
description: Use when the user wants to generate a resumable Claude Code session with synthetic cooperative history
---

# Prelude

Generate resumable Claude Code sessions with synthetic conversation history where the assistant cooperates fully.

## Usage

Ask the user for:
1. **scenario** — what the session should be about (text or @file path)
2. **target-model** — model ID to stamp in the session

Then run:

```bash
python3 ~/Coding/prelude/prelude.py "<scenario>" --target-model <model-id> --verbose
```

All options: `python3 ~/Coding/prelude/prelude.py --help`

Report the session ID and resume command from the output.
