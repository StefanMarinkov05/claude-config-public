# Link system (hard-won: copy it, don't redesign it)

Implemented in `_template/handbook/main.tex` (markers: `% Clickable chapter number.`,
`% ---- "back" trail`, `% ---- same new-tab / back-button behaviour for the table of contents`).

## Findings from real tests in Chrome / Brave PDF viewers

1. A link into the **same file** (internal GoTo, or a URI to the same file with `#page=`) is an
   **in-place jump**: no new tab, **no history entry**, so ← / Alt+← can't return. Ctrl+click too.
2. A **relative** file name in a PDF link (`Handbook.pdf?...`) is treated by Brave as a **web address**
   → "DNS address could not be found". Use **absolute `file:///…` URLs**.
3. Changing only the `#fragment` of an open PDF doesn't move the viewer. A unique query (`?r=N`)
   makes each link a distinct URL.
4. The browser's ← reopens a PDF at the plain address it was first opened with → **page 1**. Only
   links whose URL carries `#page=` restore position.
5. Chrome ignores the PDF's own start zoom (`pdfstartview`). `#zoom=150` in the URL works.

## Design

- Built as **two identical copies that link to each other**: `Handbook.pdf` → `Handbook-2.pdf` and
  back (`main-copy2.tex` sets `\buildcopytwo`, which swaps `\pdfselfname`).
- Every chapter link: `file:///<abs>/<other copy>?r=<unique>#page=<physical page>&zoom=150`.
  Physical page from `\zlabel{ch:N}` + `\zref@extract{ch:N}{abspage}`. Each chapter heading line is
  `\chapter{…}\label{ch:N}\zlabel{ch:N}\nkbackline{N}`; cite with `Ch.~\chref{N}`.
- Contents entries: same scheme with `#nameddest=<hyperref anchor>&zoom=150`, through a custom URI
  annotation start (`\nk@urlstart`). hyperref's `\hyper@linkstart` always emits GoTo, so it can't be reused.
- **Back trail:** every `\chref` leaves a `\zlabel` + aux entry; `\nkbackline{N}` prints
  "← Back to where you came from (page in the other copy that referred here): …" with page-number
  links into the other copy. Numbers are physical pages (= the viewer's page counter).
- Fallback build `main-same-tab.tex` (`\sametabbuild`) uses ordinary internal links.
- `#` and `&` in URLs come from catcode-12 macros `\pdfhash`, `\pdfzoom` (a literal `#`/`&` inside a
  macro definition breaks).
- Never put `\chref` inside `\section{…}` titles (moving argument + `\edef` → error).
- `scripts/open-handbook.sh` opens `Handbook.pdf#page=N&zoom=150` because a plain file open shows 100%.
