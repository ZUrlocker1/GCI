# Third-party notices

Galactic Chess Invaders has no runtime dependencies. This notice covers source
and assets that were adapted or bundled into the project.

---

## ChessKit

`GalacticChessInvaders/Game/Logic/Chess/` is an original implementation that
adapts algorithms and design from
[ChessKit](https://github.com/aperechnev/ChessKit) by Alexander Perechnev: the
bitboard board representation with incrementally maintained per-kind and
per-colour masks, the square indexing scheme, the ray-scan move generation, and
the FEN serialisation. Each file names in its header what it took.

ChessKit is not linked as a dependency. In every released version (1.3.7 and
2.0.0) `FenSerialization` and `Position` have no public initialiser, so an
external consumer cannot construct a `Position` at all.

ChessKit is distributed under the MIT licence, reproduced in full below as that
licence requires.

```
MIT License

Copyright (c) 2020 Alexander Perechnev

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

---

## Bundled assets

- **Press Start 2P** — Google Fonts. SIL Open Font Licence 1.1.
- **Sound effects** — Kenney (`sfx/kenney-digital`, `sfx/kenney-sci-fi`).
  CC0 1.0 Universal, public domain dedication.
- **Sound effects** — 344 Audio, from the GDC bundle (`sfx/gdc-bundle`).
- **Music loop bundles** — Abstraction / Tallbeard Studios. CC0 1.0 Universal.
  Present in `assets/` and not shipped in the app.
- **Soundtrack and stingers** — generated with
  [Zudio](https://www.mzurlocker.com/zudio) and owned by this project's author.
