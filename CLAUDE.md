# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Event materials for **2026 아세안 차세대 글로벌 창업무역스쿨 (Global Startup Trade School), Singapore**, 2026-08-13 ~ 2026-08-15 (2026-08-16 is individual departure only, no session). The main deliverable is a single-file HTML/JS slide deck used live by the MC/emcee at the event:

- `Okta 싱가폴 통무스 2026.html` — the deck. No framework, no build step: plain `<style>`/`<script>` embedded directly in the HTML file.
- `assets/`, `logo/`, `soundeffects/` — images/photos/logos/audio referenced by the deck via relative paths (not all inlined as base64 — some images are embedded inline, most are loaded from these folders).
- `IMPORTANT.md`, `UPDATE.md` — original event-planning source notes (hotel logistics checklist, Shark Tank judge mic setup, bingo game origin, etc.) that informed the deck's content. Treat these as background reference, not something to keep in sync.
- Large/generated files are intentionally excluded from git — see `.gitignore` (raw video/audio folders, the original planning zip, the legacy pptx sample, and any `Okta 싱가폴 통무스 2026.backup-*.html` snapshot).

There is no `package.json`, no build tool, no linter, and no automated test suite — this is a static file meant to be opened directly in a browser.

## Working on the deck

**No build/lint/test commands exist.** To "run" the deck, open the HTML file directly in a browser (`file://` works fine — it does not need a server). To verify a change actually works, don't just eyeball the code:

- Use a headless browser (Playwright/Chromium) to load the file, jump to the relevant slide via the `#counter` `<select>` (dispatch a `change` event after setting `.value`), and screenshot it. This project has caught real bugs this way that pure code review missed (e.g., a `width:0` flex child whose long Korean text wrapped and inflated the container to 1500px tall, pushing content off-screen — invisible in a code diff, obvious in a screenshot).
- Sanity-check the embedded JS syntax with `node --check` after extracting the `<script>` block, before doing a full visual pass.
- Deck navigation for manual testing: **←/→** prev/next slide, **Space** = next, **F** = fullscreen, **R** = reset the currently-visible ladder draw, **S** = stop any playing sound effect, **1–6** = short stinger sound effects, **J/K/L/N/U/M/W/T/D/G** = mood-tagged background music cues (see `SFX_FILES`).

## Architecture

Everything lives in one HTML file, structured top to bottom as:

1. **`<style>`** — CSS custom properties for theme colors/fonts at the top (`:root`, with a `prefers-color-scheme: dark` override), then component styles per widget/slide-type.
2. **Data arrays** (`TEAMS`, `LOCATIONS`, `SPEAKERS`/`SPEAKER_DETAILS`, `JUDGES`, `MIXER_GROUPS`, `NETWORKING_FIELDS`, `BINGO_GRID`, `SPONSORS`, `SFX_FILES`) — all deck content is data-driven from these constants, not hand-written per-slide markup.
3. **Slide renderer helpers** (`timeline()`, `speakerGrid()`, `locationGrid()`, `speakerSlide()`, `breakSlide()`, `dayDivider()`, `teamSlide()`, `mcCard()`) — small template functions that turn the data arrays into slide HTML fragments. `mcCard()` renders the shared "read before they come up" intro card (photo slot + name + role) used by both the judges-intro and congratulatory-remarks slides.
4. **`const SLIDES = [...]`** — the single source of truth for deck content and order. Each entry is `{ tag?, stub?, title?, body }`; `body` is a template-literal HTML string built from the helpers above. Reordering/adding/removing slides means editing this array, not scattered DOM.
5. **Rendering & navigation** — `SLIDES` is mapped into `.slide` sections once at load, `go(i)` drives the horizontal `translateX` carousel, and the `#counter` `<select>` + prev/next buttons + keyboard handler all call into `go()`.
6. **Interactive widgets**, each self-initializing via `document.querySelectorAll('[data-x]').forEach(...)` at the bottom of the script — they only need their expected `data-*` container present in a slide's `body` to work:
   - **사다리 (ladder) draw** — Canvas-based, per-team click-to-reveal-one or "reveal all" random column assignment (`buildLadderData`/`buildLadderPath`/`renderLadder`), no location-balancing by design.
   - **스핀 휠 (spin wheel)** — Canvas-drawn wheel for drawing presentation order one team at a time; layout is a collapsed-width left "cumulative order list" that animates open next to the wheel on the first draw, plus a single "latest result" callout box below the wheel that's replaced (not accumulated) each draw.
   - **Global Mixer** — CSS animated orbit/spin reveal that regroups into a fixed 2-row×3-column results grid, with the wheel sliding aside via an animated `gap`/`width` transition (not `flex-direction` toggling, which can't be animated).
   - **빙고 (bingo)** — click-to-mark grid; a line completes (and fires the BINGO toast) on any of the 5 rows, 5 columns, or 2 diagonals.
   - Sound effects (`SFX_FILES`) are wired to keyboard shortcuts (digits = short stingers, letters = background music cues) and play/stop via a single shared `Audio` instance (`currentSfxAudio`), not per-widget audio.

### A recurring layout trap to know about

Several widgets hide/reveal a sibling panel by animating its `width` from `0` to a target value (to get a smooth "slide over" effect, since `flex-direction` and most layout-mode properties can't be transitioned). If that width-`0` element's own content (not a separate inner wrapper) is what's laid out with wrapping text, the near-zero width forces extreme text-wrapping and the element's *height* explodes instead of just clipping — visually this looks like "the wheel disappeared" because everything gets pushed off-screen. The fix pattern used throughout: give the collapsing element a fixed-width **inner** wrapper for the actual content, and only animate `width`/`overflow:hidden` on the **outer** clipping element. Follow this pattern for any new collapse/reveal widget.

## Content language

**Deck-facing text must always be Korean.** If any user-visible deck content is generated in English, translate it back to Korean immediately and fix it — this is a hard requirement, not a style preference.

## Editing workflow (mandatory)

This project mixes real event logistics (schedules, sponsor recognition, judge intros an MC reads live) with genuinely ambiguous/missing information — guessing wrong and shipping it costs far more than an extra round of questions. The following is a hard requirement, not a style preference:

- **Any time the user posts a brief/simple planning description for a content or layout change** (a short instruction like "make X bigger and move Y left"), **always** open a detailed clarification questionnaire before writing a plan or touching any code — do not treat a short prompt as license to fill in the details yourself. Use the `AskUserQuestion` tool for concrete, answerable decision points (sizes, timing/animation choices, what happens on retry/reset, layout on edge cases, design options — ideally with previews for visual choices).
- **Never assume an ambiguous or unclear detail and auto-execute.** If something could reasonably go two ways (a schedule conflict, a cropped reference screenshot, an unconfirmed name/number, a responsive breakpoint that wasn't discussed, what an existing UI implies), ask — don't pick the option that seems more likely and proceed silently.
- Once the open questions from a round are answered, write out the concrete implementation plan (what changes, where) and it's fine to proceed with it — this rule is about not *skipping* the questions/plan step, not about looping indefinitely re-asking already-answered points.
- For pure bugfixes (something is broken and there's one clear correct fix), this heavier flow isn't required — but if the fix itself has more than one reasonable approach, that choice should still be surfaced, not assumed.
