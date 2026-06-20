# GitHub Issue Response Template
## Qidi Q2 Superuser AIO

This document lives at `.claude/github-issue-response.md`. When Claude is asked to draft a GitHub issue response, read this first.

---

## The Pattern (from HelixScreen reference responses)

Every issue response follows this structure. Not all sections are required — use the ones that apply.

### 1. One-line opener that reframes or confirms
Do not say "thanks for the report" and then repeat it back. Acknowledge and immediately add something useful — correct a misdiagnosis, confirm what part of the report is accurate, or flag what's missing.

- ✅ `Thanks for the log — a few things in here don't match a crash, so let me walk through what I'm actually seeing.`
- ✅ `Good news on the version: that 0.99.66 line was a stale-log artifact, not the binary you're running.`
- ❌ `Thanks for the detailed report! I'll look into this right away.`
- ❌ `Sorry to hear you're having trouble with this.`

### 2. `### What the log/output actually shows` *(if the user provided data)*
Lead with evidence, not conclusions. Quote the specific log lines that matter, explain what they mean, and flag what the data *doesn't* show (especially if it contradicts the user's description).

```
**No crash signature.** Both process exits are clean (`code 0`). What felt like a crash
may have been a settings-loss cycle — the error you saw is downstream of this:

​```
[Config] Failed to parse config/settings.json: attempting to parse an empty input
[Config] No valid backup — resetting to defaults
​```
```

- Quote the exact log line, not a paraphrase
- Explain what it means in one sentence
- If the user said "crash" and the logs show a clean exit, say so directly

### 3. `### What I think is happening` *(if you have a hypothesis)*
Clearly label this as a hypothesis. Explain the mechanism, not just the conclusion. If there are two possible explanations, say so and explain which evidence points where.

- ✅ `Empty settings.json after a clean shutdown points to a filesystem-layer issue — the /home/mks/helixscreen/config/ path may be on a flash mount that isn't durably fsync'd.`
- ❌ `This is probably a bug in how settings are saved.`

### 4. `### To narrow this down, can you:` *(if you need more info)*
Numbered list. Each item is one specific action with:
- The exact command to run (copy-pasteable)
- What you're trying to learn from it (in plain language)
- Whether the command changes anything (say explicitly if it's read-only)

```markdown
1. **Check whether settings persist at all.** Change something benign (language or theme),
   power-cycle the printer, check if it survived. This tells us whether the calibration
   issue is downstream of a broader persistence failure.

2. **Run these on the printer over SSH — none of these change anything:**
   ​```sh
   # Which network stack is running?
   ps aux | grep -E 'wpa_supplicant|NetworkManager' | grep -v grep

   # Where is the control socket, if anywhere?
   ls -la /run/wpa_supplicant /var/run/wpa_supplicant 2>/dev/null
   ​```

3. **Send a debug bundle if it crashes again:**
   ​```sh
   ./scripts/debug-bundle.sh
   ​```
   Share the resulting code — that captures a stack trace if there's a real abort.
```

Rules for the diagnostic ask:
- Maximum 3–4 items. If you need more, you haven't thought hard enough about what's diagnostic
- Always explain what the answer will tell you
- Group related shell commands into one numbered item
- If you already know the answer to one of your questions from the data provided, don't ask it

### 5. `### What I'll do on my end` *(if you have concrete next steps)*
Only include this if you have something specific and real to say. Don't pad with "I'll investigate further."

- ✅ `Look at making needs_touch_calibration() honor a previously-saved valid calibration so the wizard doesn't force-fire on every boot.`
- ✅ `Add fsync(dirfd) after the rename in Config::save() so we don't lose data on flash that doesn't journal directory entries.`
- ❌ `I'll look into this and get back to you.`
- ❌ `This will be fixed in a future update.`

### 6. Label + condition line *(always last if you need more info)*
End with the label you're applying and what will change it.

- `Tagging \`needs-info\` until we hear back on #1 and #2 — those answers decide whether this is one bug or two.`
- `Leaving \`needs-info\` on for the debug bundle. The persistence fix ships in the next release regardless.`

---

## Follow-up Response Structure (when user replies with more data)

When a user responds with logs or diagnostic output, the structure shifts:

1. **Validate what their data confirmed** — acknowledge the parts they got right, briefly
2. **Separate "understood / fixed" from "still need info"** — use headers if there are multiple threads
3. **The unresolved part** — describe the mechanism you're missing, then give one specific ask
4. **End with a concrete next action** — never end on "let me know if you have questions"

Example opening for a follow-up:
```
Your observation matches the log. Each boot shows:

[Config] Settings were corrupted — restored from backup

settings.json keeps coming back empty after a power cycle, but the rolling backup
survives — it lives under a different path that's actually durable on the Q2's flash.
That's why preferences persist: the backup is saving you, and the toast you see every
boot is honest.

Two fixes for this are already merged on main, but not in your version — they'll ship
in the next release. [explain what they fix]

### The "tap once → broken calibration" behavior — I need more data

This part doesn't match what I'd expect from the code. [explain why, then give the
one specific diagnostic ask]
```

---

## Tone Rules

| ✅ Do | ❌ Don't |
|-------|---------|
| Write dev-to-dev, not support-to-user | Apologize for bugs or for making them do work |
| Call out when the user's description doesn't match the data | Validate wrong assumptions to be polite |
| Quote exact log lines as evidence | Paraphrase log output |
| Explain *why* you're asking each diagnostic question | Ask for info without explaining what it'll tell you |
| Say "this is my hypothesis" when it is | State hypotheses as confirmed facts |
| Be direct about what you don't know | Pad with "I'll investigate further" |
| Give one specific next action | Give a list of things to try |
| Reference specific RCs or commits when relevant | Make vague promises about future fixes |

---

## Superuser-Specific Diagnostic Commands

These are the commands most likely to be useful in issue responses for this repo. Adapt as needed.

**Check what's actually installed:**
```sh
# AIO version
grep 'AIO_VERSION' ~/printer_data/config/gcode_macro.cfg 2>/dev/null || echo "not installed"

# Which install path
grep -l 'BOX_PRINT_START\|PRINTER_PARAM' ~/printer_data/config/gcode_macro.cfg 2>/dev/null

# HelixScreen service state
systemctl status helixscreen 2>/dev/null | head -5

# Happy Hare present?
ls ~/Happy-Hare/install.sh 2>/dev/null && echo "present" || echo "not found"
```

**Check for known conflict states (read-only):**
```sh
# Duplicate macro definitions (the most common install failure)
grep -r '\[gcode_macro BED_MESH_CALIBRATE\]' ~/printer_data/config/ 2>/dev/null

# Orphan includes (files included but missing)
grep '\[include' ~/printer_data/config/printer.cfg | \
  awk -F'"' '{print $2}' | \
  while read f; do [ -f ~/printer_data/config/$f ] || echo "MISSING: $f"; done

# box.cfg included while BunnyBox is installed (will crash Klipper)
grep -v '^#\|^$' ~/printer_data/config/printer.cfg | grep 'box.cfg'
```

**Klipper log (last 50 lines):**
```sh
tail -50 ~/printer_data/logs/klippy.log
```

**HelixScreen settings state:**
```sh
# Is settings.json valid?
python3 -m json.tool ~/helixscreen/config/settings.json > /dev/null 2>&1 \
  && echo "valid JSON" || echo "empty or invalid"

# Does the symlink target exist?
ls -la ~/printer_data/config/helixscreen/settings.json 2>/dev/null
```

---

## When Claude Is Drafting a Response

When asked to draft a GitHub issue response, Claude should:

1. **Read the issue and any attached logs/output in full before drafting**
2. **Identify which sections apply** (not every response needs all sections)
3. **Flag if the issue is missing information** that would be needed to diagnose — include the diagnostic ask in the draft
4. **Note the current AIO_VERSION** from `CLAUDE.md` to reference if version context matters
5. **Check `HANDOFF.md` known issues** — if this matches a carry-forward known issue, reference it
6. **Check `LESSONS.md`** — if a known gotcha is relevant, incorporate it into the explanation (don't ask the user to diagnose something already understood)

Claude should present the draft and flag:
- Any assumptions made about what version the user is on
- Whether additional context from the user is needed before the response can be final
- If this looks like a known issue already tracked in HANDOFF.md

---

## Auto-Population Trigger (for LESSONS.md)

If an issue response session involves:
- The same root cause appearing across **2 or more RC versions**
- A non-obvious environment fact (filesystem behavior, symlink handling, tool quirks) that caused a failed diagnosis
- A diagnostic command that turned out to be the key data point

...add an entry to `.claude/LESSONS.md` in the same commit that closes or advances the issue.

Format:
```markdown
## [LXXX] Short description
- **Category:** gotcha | pattern | correction
- **Context:** where this applies
- **Triggered by:** issue #N (or "RC2.XX session")
> One-sentence rule that would have prevented the failed attempt.
> Include the specific command, path, or fact that matters.
```
