# Cut sprites

Artwork for things the game does not have. Kept because it was drawn, not
because anything loads it — nothing here is bundled, and `typecheck.sh` will
say so if that ever changes.

- `ship-escort`, `ship-flagship` — the dive family, cut with §6.1 and §6.3
- `ship-llama` — the Minter homage; the Mutant Camel flies as the Nuke carrier
  instead, so a second tribute ship would repeat the joke
- `ship-scout-*` — five purpose-built special scouts, tried and lost to the
  drawn overlays that replaced them
- `chess-b-pawn-armored` — nothing ever loaded it; armor is a tinted
  `Silhouette` fill over the ordinary pawn

These came out of `assets/GCI.spriteatlas`, which was deleted: the app loads
flat PNGs from `GalacticChessInvaders/Resources/Sprites`, the atlas was never
bundled, and 41 of its 50 images were byte-identical duplicates of files that
are.
