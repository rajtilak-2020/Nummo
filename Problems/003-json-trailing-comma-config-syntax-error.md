# Problem 003: VS Code User Settings JSON Trailing Comma Error

- **Status**: Resolved
- **Date**: 2026-08-27
- **Affects**: `~/.config/Code/User/settings.json`

---

## 💥 Symptoms & Issue
Automated tools and strict JSON parsers failed when parsing `~/.config/Code/User/settings.json` with `Illegal trailing comma before end of object: line 363`.

## 🔍 Root Cause
While VS Code internal JSONC (JSON with Comments) parser tolerates trailing commas, standard Python `json.load()` and standard JSON schema linters fail when encountering trailing commas before closing braces `}` or `]`.

## 🛠️ Solution & Fix
1. Built a regex cleaning step (`re.sub(r',(\s*[}\]])', r'', text)`) to strip invalid trailing commas before deserialization.
2. Re-formatted and normalized `settings.json` cleanly using Python's standard `json.dump(..., indent=4)`.
3. Created an automated backup at `~/.config/Code/User/settings.json.bak`.

---

## 🔗 Related Notes
- **[[Home]]**
- **[[Progress/2026-08-session-log]]**
- **[[Reference/tech-stack-and-versions]]**
