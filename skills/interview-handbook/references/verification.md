# Verification protocol (do all of it, then report honestly)

1. **Build:** `scripts/build.sh <folder>`. It fails loudly on LaTeX errors and prints missing glyphs.
2. **Link audit:** `scripts/verify-links.py` (run by build.sh) must print `links OK`: same page count
   in both copies, no same-file links, every self-link points into this folder's other copy, unique
   URLs with `zoom=150`, every `#page=` target is a chapter start or a back-trail page, every
   back-trail page really links to its chapter. It is proven able to fail (stale-path copy → FAIL).
3. **Repo links:** every `\amz{…}`-style path must exist in a fresh clone of the repo.
4. **Code:** extract every Python listing from the `.tex`, execute it with asserts, and recompute every
   number or ordering quoted in comments or text (wrong numbers have shipped before).
5. **Facts about Stefan:** each claim traced to a file (ADR, CONTRIBUTIONS, source). Team work credited
   to its author.
6. **Visual:** contact sheets of every page; fix overlaps.
7. **Real-click test** (Playwright, headed Chromium, `file://` URL):
   - Open the PDF **plainly, without `#page`**. Opening with `#page=N` hides the ← problem (this
     mistake was made before).
   - Use CSS-pixel coordinates (`scale:'css'` screenshots; viewport about 1661×748 CSS px, DPR about 1.16).
     Compute click points from annotation `/Rect`s (page left x≈577, top y≈59, 1.333 px/pt at 100%).
   - The page-number box can't be typed into via automation: reach pages by mouse-wheel scrolling.
   - After each click, read the toolbar's page number and zoom from a screenshot.
8. **Say what wasn't tested** (e.g. Stefan's Brave itself; anything automation couldn't click).
