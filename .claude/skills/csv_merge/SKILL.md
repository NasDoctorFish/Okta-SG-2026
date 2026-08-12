---
name: csv_merge
description: Merge/reconcile the 조편성(team-assignment) xlsx grid with the 차무스 명단 CSV/JSON roster files — source-of-truth priority, exact parsing method (incl. merged-cell advisor spans), diffing before writing, output conventions. Use when asked to sync/update data/*.json or data/차무스 명단*.csv from a 조배정 xlsx.
---

# CSV/JSON roster merge (차무스 명단 ↔ 조편성)

## Files involved
- `data/조배정 & 빙고이름*.xlsx` (e.g. `..._최종.xlsx`) — source spreadsheet, sheet `조배정`. **Always read via `openpyxl.load_workbook(path, data_only=True)`, never re-parse pasted whitespace-table text** — see fallback section at the bottom for why.
- `data/싱가포르제외조편성(Aug 11th).json` — the working JSON, one `people` list, columns matching the master CSV: `{S/N, 한글성함, 소속국가/소속지회, 구분, 비고, groups[]}`. `groups` is always an array (advisors can span 3+ groups, e.g. `[1,2,3]` — don't assume pairs of 2, read merged cells, see below). People with `groups: []` and `구분 == "서포터즈"` and `소속국가/소속지회 == "싱가포르/싱가포르"` are the **local Singapore supporters** — they're deliberately outside the xlsx grid (see priority rule 3) and must survive every rebuild untouched.
- `data/차무스 명단_정리.csv` — master/original roster, columns `S/N,한글성함,소속국가/소속지회,구분,비고`. This is the **naming/format authority**, not the group-assignment authority:
  - 참가생 rows: `구분` = `"N조"`.
  - 서포터즈 rows (both 해외 서포터 and local 싱가포르 서포터즈): `구분` = `"서포터즈"` (no group number, even though 해외 서포터 carries a specific paired group in the xlsx/json).
  - 어드바이저/committee rows: `구분` = the person's real committee title text (`"위원장"`, `"부위원장(북미)"`, `"지역대표(대양주)"`, ...) — this is their org role, independent of which groups they're paired to this year. If someone's *pairing role* changes (advisor → overseas supporter) but they still hold that committee title, leave their CSV 구분 alone; only the json `role`/`groups` reflects the new pairing.
  - `소속국가/소속지회` format: `"국가/도시"` (e.g. `베트남/호치민`, `인도/뉴델리`).
- `data/차무스_명단_랜덤순서.csv` — same columns plus leading `순번` (shuffle order). Always fully regenerated, never hand-edited or diffed line-by-line.

## Source-of-truth priority
1. The xlsx `조배정` grid (→ json) is authoritative for **group assignment**: who's paired to which group(s), participant N조, 해외서포터 pairing, advisor spans.
2. `차무스 명단_정리.csv` is authoritative for **name spelling, S/N, 소속국가/소속지회 format, and non-group role/title text**.
3. People who legitimately never appear in the xlsx grid (local Singapore on-site supporters, standalone committee members) are not errors — don't delete or "fix" them into the grid, just preserve their existing CSV/json rows as-is through every rebuild.

## Exact xlsx parsing method
The grid sheet layout: row 4 = group number header, columns C..L (openpyxl col index 3..12) = groups 1..10. Row 5 = 어드바이저, rows 6–7 = 해외 서포터, rows 9–31 = participant rows labeled `"지역 (성별)"` in column B (watch for the literal typo `"프놈펜 ((여)"` with a doubled paren — the region/gender regex must tolerate it).

```python
import openpyxl, re
wb = openpyxl.load_workbook(path, data_only=True)
ws = wb['조배정']

def cells(r):                       # groups 1..10 for row r
    return [ws.cell(row=r, column=c).value for c in range(3, 13)]

def parse_named(val):               # "최혁 (캐나다/토론토)" -> ("최혁", "캐나다/토론토")
    m = re.match(r'^(.*?)\s*\((.*)\)\s*$', val.strip())
    return (m.group(1).strip(), m.group(2).strip()) if m else (val.strip(), None)
```

**Advisor spans are not a fixed "2 groups each" pattern — read them from merged cells.** A cell like `최혁 (캐나다/토론토)` in row 5 can be merged across 2 or 3 group-columns depending on the sheet, and the split point moves between xlsx revisions (confirmed: one version had 5 advisors × 2 groups each; the next `_최종` revision had 4 advisors spanning 3/3/2/2 groups, with one advisor demoted to a plain 해외 서포터 slot). Derive spans programmatically, never hardcode pairs:

```python
adv_spans = []
for mc in ws.merged_cells.ranges:
    if mc.min_row == 5 and mc.max_row == 5:
        adv_spans.append((mc.min_col - 2, mc.max_col - 2))   # -> group numbers
adv_spans.sort()
for g1, g2 in adv_spans:
    name, region = parse_named(ws.cell(row=5, column=g1 + 2).value)
    people.append({"name": name, "role": "어드바이저", "groups": list(range(g1, g2 + 1)), "region": region})
```

For rows 6–7 (해외 서포터) and 9–31 (참가생), each group column is its own cell (no merge) — just iterate `cells(r)` 1:1 against group numbers 1..10.

## Merge procedure
1. Parse the xlsx into a fresh flat `people` list as above.
2. Load the current json and current master CSV, index all three by `한글성함` (name).
3. Diff the new xlsx-parsed list against the current json: `removed` (dropped from the grid), `added` (new to the grid), `changed` (role and/or `groups` differ for the same name). Print/report all three — a name can be in both but have a stale group (e.g. caught CSV `김범준=2조` vs xlsx `7조`; caught `이현영` silently dropped from the grid entirely in a `_최종` revision, replaced by `김경란` moving from advisor into her old 해외서포터 slot).
4. If the user gave an explicit, concrete instruction to sync from a specific named xlsx file, proceed directly (no need to re-ask questions already answered in earlier merges — conventions in this file are already agreed). Still surface the diff results in your final summary so the user can catch a wrong source file. If ambiguity is genuinely new (unrecognized name, conflicting spelling, structural change with no obvious mapping), ask via `AskUserQuestion` before writing — this is a real event roster (nameplates/logistics), a silent wrong guess is costly.
5. Rebuild the json's `people` list: for every xlsx-parsed person, look up their CSV row by name for `S/N`/`소속국가/소속지회`/`비고`, and compute `구분`:
   - `참가생` → `f"{groups[0]}조"`
   - `해외 서포터` → `"서포터즈"`
   - `어드바이저` / anything else → the CSV row's own `구분` (its committee title, untouched)
   Then re-append the preserved local-only people (Singapore supporters etc., `구분=="서포터즈"`, `groups==[]`) unchanged at the end. Recompute `group_counts` (참가생/서포터/합계 per group 1–10) from the new list.
6. Update `차무스 명단_정리.csv` only where something actually changed in a way that CSV encodes: name spelling, `참가생`'s N조, new S/N rows for brand-new people. **Advisor/해외서포터 group-pairing changes alone do not touch this CSV** — it never encoded that pairing number to begin with (advisors show a title, supporters just show "서포터즈"). Append new people with the next sequential `S/N`.
7. Fully rebuild `차무스_명단_랜덤순서.csv`: define the "final roster" (json people minus the preserved local-only role), pull `S/N`/`소속국가`/`구분`/`비고` from the just-updated master CSV by name, shuffle (`random.seed(42)` was used for reproducibility so far, no strong requirement to keep that seed — just don't hand-edit order), renumber `순번` from 1.
8. Verify before declaring done: recompute per-group `참가생`/`서포터`/`합계` and diff against the xlsx's own totals rows (labeled `참가생 인원 수` / `서포터 인원 수\n(어드바이저 제외)` / `인원 총계`, directly below the grid). Exact match is the correctness bar, not eyeballing. Report a summary of what changed (removed/added/changed names) in the final response even when no question was needed.

## Parsing pasted whitespace tables (fallback only, no source file available)
If a table must be parsed from pasted chat text instead of a real xlsx/CSV: gaps between cells are literal multiples of a base unit (commonly 4 spaces) — `step = len(gap) // 4` gives how many columns to advance, so blank cells can be inferred from doubled/tripled gaps. Always cross-validate the resulting per-column counts against any stated totals row before trusting the parse — this method has produced silently-wrong column alignment before. Prefer finding/asking for the real source file over this method whenever one might exist.
