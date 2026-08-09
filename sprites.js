/* Galactic Chess Invaders — pixel-art sprite engine (v3, tall & sleek)
 * High-res maps tuned for consistent, elegant proportions and a modern
 * "Recharged" look — taller bodies, slimmer waists, finer detail.
 * '#' = fill, '@' = accent, '.' = transparent.
 *
 * GCISprites.renderPiece(type, side, px) -> <canvas>
 * GCISprites.renderShip(type, px, {flip}) -> <canvas>
 */
(function () {
  function sym(left) {
    return left.map((r) => r + r.split("").reverse().join(""));
  }

  // ------------------------------ chess pieces ------------------------------
  // All share a common visual language: rounded head, slim tapered stem,
  // collar ring, and a two-tier plinth base. Heights kept close for rhythm.
  const MAPS = {
    pawn: sym([
      ".....##",
      "....###",
      "...####",
      "...####",
      "....###",
      ".....##",
      ".....##",
      "....###",
      "....###",
      ".....##",
      ".....##",
      ".....##",
      "....###",
      "....###",
      "...####",
      "...####",
      "..#####",
      "...####",
      "..#####",
      ".######",
      "#######",
      "#######",
      ".######",
    ]),
    bishop: sym([
      ".......#",
      ".......#",
      "......##",
      "......##",
      ".....###",
      ".....###",
      "....####",
      "....####",
      "....####",
      "...#####",
      "...#####",
      "....####",
      ".....###",
      ".....###",
      "......##",
      ".....###",
      "....####",
      "....####",
      "...#####",
      "...#####",
      "..######",
      ".#######",
      "..######",
      ".#######",
      "########",
      "########",
      ".#######",
    ]),
    rook: sym([
      "####...##",
      "####...##",
      "#########",
      "#########",
      ".########",
      "..#######",
      "...######",
      "....#####",
      "....#####",
      "....#####",
      "....#####",
      "....#####",
      "....#####",
      "....#####",
      "....#####",
      "....#####",
      "....#####",
      "....#####",
      "...######",
      "..#######",
      ".########",
      "..#######",
      ".########",
      "#########",
      "#########",
      ".########",
    ]),
    queen: sym([
      "........#",
      ".......##",
      ".......##",
      "........#",
      "....#####",
      "..#######",
      "#########",
      "#########",
      ".########",
      "...######",
      ".....####",
      ".....####",
      "....#####",
      "....#####",
      "...######",
      "...######",
      "...######",
      "..#######",
      "..#######",
      "..#######",
      ".########",
      ".########",
      "..#######",
      ".########",
      "#########",
      "#########",
      ".########",
      "#########",
    ]),
    king: sym([
      "........#",
      "........#",
      "......###",
      "......###",
      "........#",
      "........#",
      ".....####",
      "....#####",
      "....#####",
      "...######",
      "...######",
      "....#####",
      ".....####",
      "......###",
      "......###",
      ".....####",
      ".....####",
      ".....####",
      "....#####",
      "....#####",
      "...######",
      "...######",
      "..#######",
      "..#######",
      ".########",
      "..#######",
      ".########",
      "#########",
      "#########",
      ".########",
    ]),
    // Knight faces RIGHT (player); flipped for the enemy side. Authored full.
    // Refined horse-head: ears, brow, slim arched muzzle, mane, matched base.
    knight: [
      ".....##.##..........",
      ".....######.........",
      "....########........",
      "....##########......",
      "...############.....",
      "...###############..",
      "..#################.",
      "..################..",
      "..################..",
      "..###############...",
      "....#########.......",
      "....##########......",
      ".....##########.....",
      ".....###########....",
      "......##########....",
      "......###########...",
      ".......##########...",
      "......############..",
      ".....##############.",
      "....################",
      "...################.",
      "..##################",
      ".###################",
      "####################",
      ".##################.",
      "####################",
      ".##################.",
    ],
  };

  const SIDE_COLORS = {
    white: { body: "#cfeaff", edge: "#ffffff", accent: "#7fe9ff", glow: "#12e0ff" },
    black: { body: "#7c2e84", edge: "#ff5c8a", accent: "#ff9ec2", glow: "#ff2060" },
  };

  // ------------------------------ ships (Galaxian-flavoured) ------------------------------
  const SHIPS = {
    // player fighter faces UP — pointed nose, cockpit, notched delta wings,
    // twin tail fins, engine glow. (Galaxian-style aggressive arrowhead.)
    player: [
      "...........#...........",
      "...........#...........",
      "..........###..........",
      ".........##@##.........",
      ".........##@##.........",
      ".........#####.........",
      "........#######........",
      "........#######........",
      ".......#########.......",
      "......###########......",
      ".....#############.....",
      "...#################...",
      "..###################..",
      "....###############....",
      ".....####.....####.....",
      "....###.........###....",
      ".......#########.......",
      ".......#@@@@@@@#.......",
      "........@.@.@.@........",
    ],
    // raider scout — saucer with dome windows, wide rim, underbelly lights
    scout: [
      "............#####............",
      "..........#########..........",
      ".........###########.........",
      "........#@@@@@@@@@@@#........",
      ".....#####################...",
      "..#########################..",
      "#############################",
      ".###########################.",
      "...#######################...",
      ".....###################.....",
      ".......###############.......",
      "........@...@...@...@........",
    ],
    // galaxian escort — antennae, wide pointed wings, striped body, nose (DOWN)
    escort: [
      "..#................#..",
      "..#................#..",
      "...##............##...",
      "........######........",
      "...#....######....#...",
      "..###...######...###..",
      "..####..@@@@@@..####..",
      ".####..########..####.",
      "..##...########...##..",
      "........######........",
      ".......##@@@@##.......",
      "........######........",
      ".........####.........",
      ".........####.........",
      "..........##..........",
      "..........##..........",
    ],
    // galaxian flagship — antennae, broad swept wings, gold command core (DOWN)
    flagship: [
      "....##................##....",
      "....##................##....",
      "......##............##......",
      "........############........",
      "......################......",
      "....##@@@@@@@@@@@@@@@@##....",
      "..####@@@@@@@@@@@@@@@@####..",
      "############################",
      ".##########################.",
      "...######################...",
      ".....##################.....",
      ".......##############.......",
      ".........@@@@@@@@@@.........",
      ".........@..@..@..@.........",
    ],
    // ---- Jeff Minter tribute bonus ships (side profile, fly across the top lane, face RIGHT) ----
    // LLAMA (Llamatron / Andes Attack) — leggy: compact body, four long legs, proud neck
    llama: [
      "...............##.##..",
      "...............##.##..",
      "...............######.",
      "...............##@###.",
      "...............######.",
      "..............#####...",
      ".............#####....",
      "...........######.....",
      ".........#######......",
      ".....#############....",
      "...###############....",
      "..################....",
      "...##############.....",
      "....############......",
      "....##..##..##.##.....",
      "....##..##..##.##.....",
      "....##..##..##.##.....",
      "....##..##..##.##.....",
      "....##..##..##.##.....",
    ],
    // CAMEL (Attack of the Mutant Camels) — single hump (dromedary), long neck, striding
    camel: [
      "............................#.#.",
      "...........................#####",
      "............................####",
      "...........................##@##",
      "..........................######",
      "..............####.......#####..",
      ".............######.....#####...",
      "...........#########...#####....",
      ".....#########################..",
      "...#######################......",
      "..#######################.......",
      "..#######################.......",
      "...######################.......",
      "...#.###################........",
      "...#..#################.........",
      ".......###........###...........",
      ".......###........###...........",
      "......###..........###..........",
      "......###..........###..........",
      "......###..........###..........",
      ".....###............###.........",
      ".....####..........####.........",
    ],
  };

  const SHIP_COLORS = {
    player:   { body: "#cfeaff", edge: "#ffffff", accent: "#12e0ff", glow: "#12e0ff" },
    scout:    { body: "#0d4a1e", edge: "#9bff5e", accent: "#e8ff45", glow: "#7dff4d" },
    escort:   { body: "#6e2c00", edge: "#ffa23a", accent: "#19e6ff", glow: "#ff8a1e" },
    flagship: { body: "#0a3566", edge: "#54b0ff", accent: "#ffd24d", glow: "#3aa2ff" },
    llama:    { body: "#3a1a5e", edge: "#d79bff", accent: "#ffe24d", glow: "#a64dff" },
    camel:    { body: "#5e3a0a", edge: "#ffd27a", accent: "#9bff5e", glow: "#ffb01e" },
  };

  // ------------------------------ rendering ------------------------------
  function isFilled(map, x, y) {
    if (y < 0 || y >= map.length) return false;
    const row = map[y];
    if (x < 0 || x >= row.length) return false;
    return row[x] !== ".";
  }
  function isRim(map, x, y) {
    if (!isFilled(map, x, y)) return false;
    return (
      !isFilled(map, x - 1, y) || !isFilled(map, x + 1, y) ||
      !isFilled(map, x, y - 1) || !isFilled(map, x, y + 1)
    );
  }

  function renderMap(map, c, px) {
    const w = Math.max.apply(null, map.map((r) => r.length));
    const h = map.length;
    const canvas = document.createElement("canvas");
    canvas.width = w * px;
    canvas.height = h * px;
    const ctx = canvas.getContext("2d");
    ctx.imageSmoothingEnabled = false;
    for (let y = 0; y < h; y++) {
      for (let x = 0; x < map[y].length; x++) {
        const ch = map[y][x];
        if (ch === ".") continue;
        if (ch === "@") ctx.fillStyle = c.accent || c.edge;
        else ctx.fillStyle = isRim(map, x, y) ? c.edge : c.body;
        ctx.fillRect(x * px, y * px, px, px);
      }
    }
    canvas.dataset.glow = c.glow;
    canvas.style.imageRendering = "pixelated";
    return canvas;
  }

  function renderPiece(type, side, px, opts) {
    opts = opts || {};
    let map = MAPS[type];
    if (!map) throw new Error("Unknown piece: " + type);
    let flip = opts.flip;
    if (type === "knight" && side === "black" && flip === undefined) flip = true;
    if (flip) map = map.map((row) => row.split("").reverse().join(""));
    return renderMap(map, SIDE_COLORS[side] || SIDE_COLORS.white, px);
  }

  function renderShip(type, px, opts) {
    opts = opts || {};
    let map = SHIPS[type];
    if (!map) throw new Error("Unknown ship: " + type);
    if (opts.flip) map = map.map((row) => row.split("").reverse().join(""));
    return renderMap(map, SHIP_COLORS[type], px);
  }

  // ---------- VECTOR rendering (smooth neon outlines, Recharged style) ----------
  const VEC_PIECE = {
    white: { edge: "#e8f7ff", glow: "#1ce4ff", accent: "#7fe9ff" },
    black: { edge: "#ff7aa6", glow: "#ff2a66", accent: "#ff9ec2" },
  };
  const VEC_SHIP = {
    player:   { edge: "#e8f7ff", glow: "#1ce4ff", accent: "#1ce4ff" },
    scout:    { edge: "#a6ff66", glow: "#7dff4d", accent: "#e8ff45" },
    escort:   { edge: "#ffb05a", glow: "#ff8a1e", accent: "#19e6ff" },
    flagship: { edge: "#74b8ff", glow: "#3aa2ff", accent: "#ffd24d" },
    llama:    { edge: "#e0b6ff", glow: "#a64dff", accent: "#ffe24d" },
    camel:    { edge: "#ffdc94", glow: "#ffb01e", accent: "#9bff5e" },
  };

  function hexA(hex, a) {
    const h = hex.replace("#", "");
    const n = parseInt(h.length === 3 ? h.split("").map((c) => c + c).join("") : h, 16);
    return `rgba(${(n >> 16) & 255},${(n >> 8) & 255},${n & 255},${a})`;
  }

  // Marching boundary: emit directed unit edges (interior on the right) and
  // stitch them into closed loops of grid vertices.
  function traceContours(map) {
    const H = map.length;
    const fill = (x, y) => y >= 0 && y < H && x >= 0 && x < map[y].length && map[y][x] !== ".";
    const key = (x, y) => x + "," + y;
    const adj = new Map();
    const push = (ax, ay, bx, by) => { const k = key(ax, ay); if (!adj.has(k)) adj.set(k, []); adj.get(k).push([bx, by]); };
    for (let y = 0; y < H; y++) for (let x = 0; x < map[y].length; x++) {
      if (!fill(x, y)) continue;
      if (!fill(x, y - 1)) push(x, y, x + 1, y);
      if (!fill(x + 1, y)) push(x + 1, y, x + 1, y + 1);
      if (!fill(x, y + 1)) push(x + 1, y + 1, x, y + 1);
      if (!fill(x - 1, y)) push(x, y + 1, x, y);
    }
    const loops = [];
    for (const startK of Array.from(adj.keys())) {
      while (adj.get(startK) && adj.get(startK).length) {
        const loop = []; let k = startK, guard = 0;
        while (guard++ < 200000) {
          const list = adj.get(k);
          if (!list || !list.length) break;
          const nxt = list.shift();
          const p = k.split(",").map(Number);
          loop.push([p[0], p[1]]);
          k = key(nxt[0], nxt[1]);
          if (k === startK) break;
        }
        if (loop.length > 2) loops.push(loop);
      }
    }
    return loops;
  }

  function chaikin(pts, iters) {
    for (let it = 0; it < (iters == null ? 3 : iters); it++) {
      const n = pts.length, out = [];
      for (let i = 0; i < n; i++) {
        const a = pts[i], b = pts[(i + 1) % n];
        out.push([a[0] * 0.75 + b[0] * 0.25, a[1] * 0.75 + b[1] * 0.25]);
        out.push([a[0] * 0.25 + b[0] * 0.75, a[1] * 0.25 + b[1] * 0.75]);
      }
      pts = out;
    }
    return pts;
  }

  function vectorFromMap(map, c, scale, opts) {
    opts = opts || {};
    const W = Math.max.apply(null, map.map((r) => r.length)), H = map.length;
    const loops = traceContours(map).map((l) => chaikin(l, opts.smooth));
    const pad = Math.ceil(scale * 2) + 8;
    const cv = document.createElement("canvas");
    cv.width = W * scale + pad * 2; cv.height = H * scale + pad * 2;
    const ctx = cv.getContext("2d");
    ctx.translate(pad, pad);
    ctx.lineJoin = "round"; ctx.lineCap = "round";

    const dmg = opts.dmg || 0;
    let s = ((opts.seed || 7) >>> 0) || 7;
    const rnd = () => { s = (s * 1664525 + 1013904223) >>> 0; return s / 4294967296; };

    // ragged destruction line (cell coords): the outline below cutAt(x) is OMITTED
    const SEGN = 12, prof = [];
    let baseCut = H + 9;
    if (dmg > 0) {
      baseCut = H * (1 - Math.min(0.82, 0.14 + dmg * 1.0));
      for (let i = 0; i <= SEGN; i++) prof.push((rnd() - 0.5) * H * 0.14);
    }
    const cutAt = (xc) => {
      if (dmg <= 0) return H + 9;
      const t = Math.max(0, Math.min(SEGN, (xc / W) * SEGN)), i = Math.floor(t), f = t - i;
      const a = prof[i] || 0, b = prof[Math.min(SEGN, i + 1)] || 0;
      return baseCut + a + (b - a) * f;
    };
    const gone = (p) => dmg > 0 && p[1] > cutAt(p[0]);

    const closed = () => { ctx.beginPath(); for (const lp of loops) { lp.forEach((p, i) => { const X = p[0] * scale, Y = p[1] * scale; i ? ctx.lineTo(X, Y) : ctx.moveTo(X, Y); }); ctx.closePath(); } };
    // open path that simply SKIPS outline points in the destroyed lower region
    const broken = () => { ctx.beginPath(); for (const lp of loops) { let on = false; for (let i = 0; i <= lp.length; i++) { const p = lp[i % lp.length]; if (gone(p)) { on = false; continue; } const X = p[0] * scale, Y = p[1] * scale; if (!on) { ctx.moveTo(X, Y); on = true; } else ctx.lineTo(X, Y); } } };

    // faint interior fill, then erase the destroyed lower band
    const GB = opts.clean ? 0 : 1;
    closed();
    if (!opts.clean) {
      const g = ctx.createLinearGradient(0, 0, 0, H * scale);
      g.addColorStop(0, hexA(c.glow, 0.05)); g.addColorStop(1, hexA(c.glow, 0.20));
      ctx.fillStyle = g; ctx.fill();
    }
    if (dmg > 0) {
      ctx.save(); ctx.globalCompositeOperation = "destination-out";
      ctx.beginPath(); ctx.moveTo(-pad, H * scale + pad);
      for (let i = 0; i <= 24; i++) { const xc = (W * i) / 24; ctx.lineTo(xc * scale, cutAt(xc) * scale); }
      ctx.lineTo(W * scale + pad, H * scale + pad); ctx.closePath(); ctx.fill();
      ctx.restore();
    }

    // accent detail cells (ship engines/stripes)
    if (opts.accent) {
      ctx.save(); ctx.shadowColor = c.accent; ctx.shadowBlur = scale * 1.6 * GB; ctx.fillStyle = c.accent;
      for (let y = 0; y < H; y++) for (let x = 0; x < map[y].length; x++) if (map[y][x] === "@")
        ctx.fillRect(x * scale + scale * 0.12, y * scale + scale * 0.12, scale * 0.76, scale * 0.76);
      ctx.restore();
    }

    // layered glowing stroke -> bright core (skips the destroyed lower outline)
    const strokePath = dmg > 0 ? broken : closed;
    const sw = Math.max(1.6, scale * 0.72);
    ctx.shadowColor = c.glow; ctx.shadowBlur = scale * 2.6 * GB; ctx.strokeStyle = c.edge; ctx.lineWidth = sw; strokePath(); ctx.stroke();
    ctx.shadowBlur = scale * 1.1 * GB; ctx.lineWidth = sw * 0.7; strokePath(); ctx.stroke();
    ctx.shadowBlur = 0; ctx.strokeStyle = "#ffffff"; ctx.globalAlpha = 0.85; ctx.lineWidth = Math.max(1, sw * 0.32); strokePath(); ctx.stroke(); ctx.globalAlpha = 1;

    // fractures + sparks (only on damaged pieces, clipped to the remaining body)
    if (dmg > 0) {
      ctx.save();
      closed(); ctx.clip();
      ctx.beginPath(); ctx.moveTo(-pad, -pad); ctx.lineTo(W * scale + pad, -pad);
      for (let i = 24; i >= 0; i--) { const xc = (W * i) / 24; ctx.lineTo(xc * scale, cutAt(xc) * scale); }
      ctx.closePath(); ctx.clip(); // keep fractures above the break, inside the silhouette
      const paths = [];
      const nC = Math.round(3 + dmg * 8);
      for (let i = 0; i < nC; i++) {
        let x = W * scale * (0.22 + rnd() * 0.56), y = (H * 0.18 + rnd() * Math.max(1, baseCut - H * 0.18)) * scale, a = rnd() * 7;
        const segs = 4 + Math.floor(rnd() * 4), pts = [[x, y]];
        for (let k = 0; k < segs; k++) { a += (rnd() - 0.5) * 1.2; const l = W * scale * (0.06 + rnd() * 0.13); x += Math.cos(a) * l; y += Math.sin(a) * l; pts.push([x, y]); }
        paths.push(pts);
      }
      const drawC = (st, w, blur, al) => { ctx.save(); ctx.strokeStyle = st; ctx.lineWidth = w; ctx.lineCap = "round"; ctx.shadowColor = c.glow; ctx.shadowBlur = blur * GB; ctx.globalAlpha = al; paths.forEach((p) => { ctx.beginPath(); p.forEach((pt, i) => i ? ctx.lineTo(pt[0], pt[1]) : ctx.moveTo(pt[0], pt[1])); ctx.stroke(); }); ctx.restore(); };
      drawC(c.edge, 2.4, 6, 0.95); drawC("#ffffff", 1.0, 2, 0.9);
      ctx.restore();
      // dash sparks along the broken edge
      ctx.save(); ctx.strokeStyle = c.edge; ctx.lineCap = "round"; ctx.lineWidth = 2.2; ctx.shadowColor = c.glow; ctx.shadowBlur = 7 * GB;
      for (let i = 0; i <= 10; i++) { const xc = W * i / 10, yc = cutAt(xc); if (yc >= H + 8) continue; const x = xc * scale, y = yc * scale, an = -Math.PI / 2 + (rnd() - 0.5) * 1.5, L = 5 + rnd() * 8; ctx.beginPath(); ctx.moveTo(x, y); ctx.lineTo(x + Math.cos(an) * L, y + Math.sin(an) * L); ctx.stroke(); }
      ctx.restore();
    }

    cv.dataset.glow = c.glow;
    cv.style.display = "block";
    return cv;
  }

  function renderPieceVector(type, side, scale, opts) {
    opts = opts || {};
    let map = MAPS[type];
    if (!map) throw new Error("Unknown piece: " + type);
    let flip = opts.flip;
    if (type === "knight" && side === "black" && flip === undefined) flip = true;
    if (flip) map = map.map((row) => row.split("").reverse().join(""));
    return vectorFromMap(map, VEC_PIECE[side] || VEC_PIECE.white, scale, { smooth: opts.smooth, dmg: opts.dmg, seed: opts.seed, clean: opts.clean });
  }
  function renderShipVector(type, scale, opts) {
    opts = opts || {};
    let map = SHIPS[type];
    if (!map) throw new Error("Unknown ship: " + type);
    if (opts.flip) map = map.map((row) => row.split("").reverse().join(""));
    return vectorFromMap(map, VEC_SHIP[type], scale, { smooth: opts.smooth, accent: true, clean: opts.clean });
  }

  function applyGlow(cv, intensity) {
    const g = cv.dataset.glow;
    const r = intensity == null ? 1 : intensity;
    cv.style.filter =
      `drop-shadow(0 0 ${1.5 * r}px ${g}) drop-shadow(0 0 ${4 * r}px ${g}) drop-shadow(0 0 ${9 * r}px ${g})`;
    cv.style.display = "block";
    return cv;
  }

  function spriteEl(type, side, px, intensity) { return applyGlow(renderPiece(type, side, px), intensity); }
  function shipEl(type, px, intensity, opts) { return applyGlow(renderShip(type, px, opts), intensity); }

  // Battle damage: progressively eat away the LOWER outline (base blown off),
  // with prominent shattered-glass fractures and dash sparks. dmg 0..~0.7.
  function applyDamage(cv, dmg, seed) {
    if (!dmg) return cv;
    const ctx = cv.getContext("2d"), W = cv.width, H = cv.height;
    let s = ((seed || 7) >>> 0) || 7;
    const rnd = () => { s = (s * 1664525 + 1013904223) >>> 0; return s / 4294967296; };
    const col = cv.dataset.glow || "#ffffff";

    // 1) build prominent shattered-glass fractures
    const paths = [];
    const nCracks = Math.round(3 + dmg * 9);
    for (let i = 0; i < nCracks; i++) {
      const sx = W * (0.22 + rnd() * 0.56), sy = H * (0.22 + rnd() * 0.5);
      let x = sx, y = sy, a = rnd() * 7; const segs = 4 + Math.floor(rnd() * 4);
      const pts = [[x, y]];
      for (let k = 0; k < segs; k++) { a += (rnd() - 0.5) * 1.2; const l = W * (0.08 + rnd() * 0.16); x += Math.cos(a) * l; y += Math.sin(a) * l; pts.push([x, y]); }
      paths.push(pts);
      if (rnd() < 0.75) { let bx = sx, by = sy, ba = a + (rnd() < 0.5 ? 1.7 : -1.7); const bp = [[bx, by]]; for (let k = 0; k < 3; k++) { ba += (rnd() - 0.5); const l = W * 0.1; bx += Math.cos(ba) * l; by += Math.sin(ba) * l; bp.push([bx, by]); } paths.push(bp); }
    }
    const drawPaths = (stroke, w, blur, alpha) => {
      ctx.save(); ctx.strokeStyle = stroke; ctx.lineWidth = w; ctx.lineCap = "round"; ctx.lineJoin = "round";
      ctx.shadowColor = col; ctx.shadowBlur = blur; ctx.globalAlpha = alpha;
      paths.forEach((p) => { ctx.beginPath(); p.forEach((pt, i) => i ? ctx.lineTo(pt[0], pt[1]) : ctx.moveTo(pt[0], pt[1])); ctx.stroke(); });
      ctx.restore();
    };
    drawPaths(col, 2.6, 7, 0.95);     // bright colored fracture
    drawPaths("#ffffff", 1.1, 2, 0.9); // white-hot core line

    const sparks = [];
    // 2) eat the lower outline away with a ragged top edge (grows with damage)
    const eat = Math.min(0.74, dmg * 1.15);
    if (eat > 0.02) {
      const topY = H * (1 - eat);
      ctx.save(); ctx.globalCompositeOperation = "destination-out";
      ctx.beginPath(); ctx.moveTo(-2, H + 2); ctx.lineTo(-2, topY);
      const steps = 9;
      for (let i = 0; i <= steps; i++) { const x = (W * i) / steps; const j = (rnd() - 0.5) * H * 0.14; const ey = topY + j; ctx.lineTo(x, ey); if (i % 2 === 0) sparks.push([x, ey, -Math.PI / 2 + (rnd() - 0.5)]); }
      ctx.lineTo(W + 2, H + 2); ctx.closePath(); ctx.fill();
      ctx.restore();
    }
    // 3) a few side bites higher up to break the silhouette irregularly
    ctx.save(); ctx.globalCompositeOperation = "destination-out";
    const bites = Math.round(dmg * 4);
    for (let b = 0; b < bites; b++) {
      const ix = rnd() < 0.5 ? W * (0.12 + rnd() * 0.18) : W * (0.7 + rnd() * 0.18);
      const iy = H * (0.3 + rnd() * 0.35);
      const r = (0.12 + rnd() * 0.08 + dmg * 0.1) * W;
      ctx.beginPath(); ctx.arc(ix, iy, r, 0, 7); ctx.fill();
      for (let k = 0; k < 2; k++) { const a = rnd() * 7; sparks.push([ix + Math.cos(a) * r, iy + Math.sin(a) * r, a]); }
    }
    ctx.restore();

    // 4) neon dash sparks at the broken edges
    ctx.save(); ctx.strokeStyle = col; ctx.lineCap = "round"; ctx.lineWidth = 2.2; ctx.shadowColor = col; ctx.shadowBlur = 7;
    sparks.forEach(([x, y, a]) => { const L = 5 + rnd() * 7; ctx.beginPath(); ctx.moveTo(x, y); ctx.lineTo(x + Math.cos(a) * L, y + Math.sin(a) * L); ctx.stroke(); });
    ctx.restore();
    return cv;
  }

  window.GCISprites = {
    MAPS, SHIPS, SIDE_COLORS, SHIP_COLORS, VEC_PIECE, VEC_SHIP,
    renderMap, renderPiece, renderShip, renderPieceVector, renderShipVector, vectorFromMap,
    spriteEl, shipEl, applyGlow, applyDamage, isRim, isFilled,
  };
})();
