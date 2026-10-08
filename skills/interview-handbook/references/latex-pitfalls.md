# LaTeX pitfalls (all hit before)

- **Engine:** Tectonic (XeTeX; downloads packages on demand; no sudo). If missing: download the musl
  binary `tectonic-<ver>-x86_64-unknown-linux-musl.tar.gz` from GitHub releases into `~/.local/bin`.
  Build: `tectonic -X compile main.tex` (reruns until references settle). Use `scripts/build.sh`.
- **Fonts:** keep fontspec's default Latin Modern. `\setmainfont{Latin Modern Roman}` fails in Tectonic.
- **Missing glyphs in code:** box-drawing characters (├──) and ≈ ≠ are absent from the mono font,
  even with `literate` mappings inside comments. Use ASCII.
- **pgfplots:** `symbolic y coords` can't contain parentheses. `ytick=data` takes labels only from the
  first `\addplot`, so give an explicit `ytick={...}` list plus `bar shift=0pt` for multi-colour bars.
- **No floats inside boxes:** a `figure` inside tcolorbox/optional → "Not in outer par mode". Use
  `center` + `\captionof{figure}{…}` (`caption` package).
- **TikZ `\foreach`:** don't name loop variables `\c`, `\d`, `\t` (accent macros); braces protect
  values containing `/` or `,`.
- **Headers:** long chapter names collide with the right header. Header = `\nouppercase{\leftmark}`,
  book title in the footer.
- **Section titles with links:** never `\chref` in `\section{}`. For "(optional)" use
  `\section[Title (optional)]{Title\texorpdfstring{\optmark}{}}`.
- **Inserted chapters:** `\bchapterinput{N}{file}` gives "Nb" numbering (and a unique `\theHchapter`
  so hyperref anchors don't collide).
- **Diagram layout:** edge labels with white fill cover nodes, legends cover bars, long labels overflow
  circles. Lay out dense graphs with explicit coordinates and always check the rendered page.
- **Visual QA:** `pdftoppm -r 50 -png` every page, assemble contact sheets with a small PIL script,
  zoom (`-r 80`) into each diagram.
