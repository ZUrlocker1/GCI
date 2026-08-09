/* Galactic Chess Invaders — shared rendering layer
 * Layout constants, parallax starfield, and React building blocks.
 * Exports to window: GCI (palette + layout helpers) and the components.
 */
const { useRef, useEffect, useState } = React;

/* ----------------------------- palette + layout ----------------------------- */
const PAL = {
  bg: "#000000",
  white: "#e8f4ff",
  cyan: "#00dfff",
  magenta: "#ff2060",
  green: "#7dff4d",
  orange: "#ff8a1e",
  blue: "#3aa2ff",
  yellow: "#ffd24d",
  dim: "#5a6b78",
};

const FRAME = { w: 900, h: 700 };
const fileX = (f) => 219 + f * 66;            // files a..h -> x (tighter board, lateral room)
const rankY = (r) => 140 + (8 - r) * 64;      // ranks 8..1 -> y (top lane + row gap)
const VEC_SCALE = 2.0;                         // vector render scale for board pieces/ships

// Standard chess opening position as {type, side, file, rank}.
const BACK_RANK = ["rook", "knight", "bishop", "queen", "king", "bishop", "knight", "rook"];
const START_POSITION = (() => {
  const out = [];
  BACK_RANK.forEach((t, f) => {
    out.push({ type: t, side: "black", file: f, rank: 8 });
    out.push({ type: "pawn", side: "black", file: f, rank: 7 });
    out.push({ type: "pawn", side: "white", file: f, rank: 2 });
    out.push({ type: t, side: "white", file: f, rank: 1 });
  });
  return out;
})();

const PX = 2; // pixels-per-cell for board pieces (high-res sprites)

/* ----------------------------- starfield ----------------------------- */
// deterministic PRNG
function mulberry32(seed) {
  return function () {
    seed |= 0; seed = (seed + 0x6d2b79f5) | 0;
    let t = Math.imul(seed ^ (seed >>> 15), 1 | seed);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

// Build a box-shadow star list tiled vertically twice for seamless looping.
function starShadows(n, w, h, rnd, colorFn) {
  const parts = [];
  for (let i = 0; i < n; i++) {
    const x = Math.floor(rnd() * w);
    const y = Math.floor(rnd() * h);
    const col = colorFn(rnd());
    parts.push(`${x}px ${y}px 0 0 ${col}`);
    parts.push(`${x}px ${y + h}px 0 0 ${col}`); // tiled copy
  }
  return parts.join(", ");
}

function Starfield({ seed = 7, nebula = true, debris = true }) {
  const layers = useRef(null);
  if (!layers.current) {
    const r0 = mulberry32(seed);
    const r1 = mulberry32(seed + 99);
    layers.current = {
      far: starShadows(150, FRAME.w, FRAME.h, r0, () => "#ffffff"),
      mid: starShadows(60, FRAME.w, FRAME.h, r1, (v) =>
        v > 0.6 ? PAL.cyan : v > 0.3 ? "#9fd8ff" : "#ffffff"
      ),
    };
  }
  const L = layers.current;
  return (
    <div style={{ position: "absolute", inset: 0, overflow: "hidden", background: PAL.bg }}>
      {/* nebula wisps */}
      {nebula && (
        <div
          style={{
            position: "absolute", inset: "-10%",
            background:
              `radial-gradient(40% 30% at 22% 28%, rgba(0,223,255,0.10), transparent 70%),` +
              `radial-gradient(45% 35% at 78% 62%, rgba(255,32,96,0.09), transparent 70%),` +
              `radial-gradient(35% 25% at 60% 15%, rgba(58,162,255,0.07), transparent 70%)`,
            filter: "blur(6px)",
            animation: "gciDrift2 40s linear infinite",
          }}
        />
      )}
      {/* far stars */}
      <div style={{ position: "absolute", left: 0, top: 0, width: FRAME.w, height: FRAME.h * 2, animation: "gciStar 90s linear infinite" }}>
        <div style={{ position: "absolute", width: 1, height: 1, borderRadius: "50%", boxShadow: L.far }} />
      </div>
      {/* mid stars */}
      <div style={{ position: "absolute", left: 0, top: 0, width: FRAME.w, height: FRAME.h * 2, animation: "gciStar 55s linear infinite" }}>
        <div style={{ position: "absolute", width: 2, height: 2, borderRadius: "50%", boxShadow: L.mid }} />
      </div>
      {/* wireframe debris (Asteroids-Recharged style) */}
      {debris && (
        <svg width={FRAME.w} height={FRAME.h} style={{ position: "absolute", inset: 0, animation: "gciDrift 30s linear infinite" }}>
          <g fill="none" stroke="rgba(0,223,255,0.16)" strokeWidth="1.5">
            <polygon points="120,540 150,520 176,540 168,572 132,576" />
            <polygon points="760,120 792,108 812,132 800,160 766,154" />
          </g>
          <g fill="none" stroke="rgba(255,32,96,0.14)" strokeWidth="1.5">
            <polygon points="640,470 664,458 686,476 676,500 648,498" />
          </g>
        </svg>
      )}
    </div>
  );
}

/* ----------------------------- sprite components ----------------------------- */
function spriteCanvas(host, builder) {
  if (!host) return;
  host.innerHTML = "";
  host.appendChild(builder());
}

// Battle-damage a rendered canvas (delegates to the shared engine).
function applyDamage(cv, dmg, seed) {
  return GCISprites.applyDamage(cv, dmg, seed);
}

function Piece({ type, side, file, rank, x, y, px = PX, glow = 1.1, dmg = 0, seed, style, className }) {
  const ref = useRef(null);
  const left = x != null ? x : fileX(file);
  const top = y != null ? y : rankY(rank);
  useEffect(() => {
    spriteCanvas(ref.current, () => {
      const cv = GCISprites.renderPieceVector(type, side, VEC_SCALE, { dmg, seed: seed != null ? seed : (file || 0) * 13 + (rank || 0) * 7 + 3 });
      GCISprites.applyGlow(cv, glow * 0.6);
      return cv;
    });
  }, [type, side, glow, dmg]);
  return (
    <div
      ref={ref}
      className={className}
      style={{ position: "absolute", left, top, transform: "translate(-50%,-50%)", ...style }}
    />
  );
}

function Ship({ type, x, y, px = 4, glow = 1.2, flip = false, style, className }) {
  const ref = useRef(null);
  useEffect(() => {
    spriteCanvas(ref.current, () => {
      const cv = GCISprites.renderShipVector(type, VEC_SCALE, { flip });
      GCISprites.applyGlow(cv, glow * 0.6);
      return cv;
    });
  }, [type, glow, flip]);
  return (
    <div ref={ref} className={className}
      style={{ position: "absolute", left: x, top: y, transform: "translate(-50%,-50%)", ...style }} />
  );
}

/* ----------------------------- HUD ----------------------------- */
function ShipIcon() {
  const ref = useRef(null);
  useEffect(() => { spriteCanvas(ref.current, () => {
    const cv = GCISprites.renderShipVector("player", 1.3);
    GCISprites.applyGlow(cv, 0.5);
    return cv;
  }); }, []);
  return <div ref={ref} style={{ display: "inline-block" }} />;
}

function HelpButton({ label = "INFO", style = "bracket" }) {
  const base = {
    fontFamily: "'Press Start 2P', monospace", cursor: "pointer",
    color: "#cfeffb", letterSpacing: 1, userSelect: "none",
    display: "inline-flex", alignItems: "center", gap: 6, whiteSpace: "nowrap",
  };
  if (style === "bracket") {
    // arcade bracketed text — reads as a control, matches "PRESS FIRE" styling
    return (
      <div style={{ ...base, fontSize: 11, color: PAL.cyan, textShadow: `0 0 8px ${PAL.cyan}` }}>
        <span style={{ opacity: 0.7 }}>[</span>
        <span style={{ color: "#eaf9ff" }}>{label === "INFO" ? "?" : "?"} {label}</span>
        <span style={{ opacity: 0.7 }}>]</span>
      </div>
    );
  }
  if (style === "outline") {
    // bordered chip — most obviously a "button" to a non-gamer
    return (
      <div style={{
        ...base, fontSize: 10, padding: "7px 11px", borderRadius: 6,
        border: `1.5px solid ${PAL.cyan}99`, background: "rgba(0,30,45,0.5)",
        boxShadow: `0 0 8px ${PAL.cyan}44, inset 0 0 6px ${PAL.cyan}22`, color: "#eaf9ff",
      }}>
        <span style={{ color: PAL.cyan, fontSize: 11 }}>?</span> {label}
      </div>
    );
  }
  if (style === "glyph") {
    // compact circled question mark — smallest footprint
    return (
      <div style={{
        ...base, justifyContent: "center", width: 26, height: 26, borderRadius: "50%",
        border: `1.5px solid ${PAL.cyan}99`, background: "rgba(0,30,45,0.5)",
        boxShadow: `0 0 8px ${PAL.cyan}44`, color: PAL.cyan, fontSize: 12,
      }}>?</div>
    );
  }
  return null;
}

function HUD({ score = 0, hi = 0, level = 1, lives = 3, flashHi = false, info = false, infoLabel = "INFO", infoStyle = "bracket" }) {
  const pad = (n, w) => String(n).padStart(w, "0");
  const cell = { display: "flex", alignItems: "center", gap: 8, fontFamily: "'Press Start 2P', monospace" };
  return (
    <div style={{
      position: "absolute", top: 0, left: 0, width: FRAME.w, height: 46,
      display: "flex", alignItems: "center", justifyContent: "space-between",
      padding: "0 22px", boxSizing: "border-box",
      borderBottom: "1px solid rgba(0,223,255,0.18)",
      background: "linear-gradient(180deg, rgba(0,30,45,0.55), rgba(0,0,0,0))",
    }}>
      <div style={{ ...cell, fontSize: 13, color: PAL.white, textShadow: `0 0 8px ${PAL.cyan}` }}>
        <span style={{ color: PAL.dim, fontSize: 11 }}>SCORE</span> {pad(score, 6)}
      </div>
      <div style={{ ...cell, fontSize: 12, color: PAL.yellow, textShadow: `0 0 8px ${PAL.yellow}`, animation: flashHi ? "gciBlink 0.4s steps(1) infinite" : "none" }}>
        <span style={{ opacity: 0.7, fontSize: 10 }}>HI</span> {pad(hi, 6)}
      </div>
      <div style={{ ...cell, fontSize: 12, color: PAL.white, textShadow: `0 0 8px ${PAL.cyan}` }}>
        LEVEL {pad(level, 2)}
      </div>
      <div style={{ display: "flex", alignItems: "center", gap: 14 }}>
        <div style={{ display: "flex", alignItems: "center", gap: 7 }}>
          {Array.from({ length: lives }).map((_, i) => <ShipIcon key={i} />)}
        </div>
        {info && (
          <div style={{ display: "flex", alignItems: "center", gap: 14 }}>
            <div style={{ width: 1, height: 22, background: "rgba(0,223,255,0.22)" }} />
            <HelpButton label={infoLabel} style={infoStyle} />
          </div>
        )}
      </div>
    </div>
  );
}

/* ----------------------------- projectiles + fx ----------------------------- */
// player laser: a luminous line with a white-hot core and an outlined capsule head
function Beam({ x, y1, y2, color = PAL.cyan, width = 3 }) {
  const top = Math.min(y1, y2), h = Math.abs(y2 - y1), headUp = y2 <= y1;
  const cap = width * 1.9;
  return (
    <React.Fragment>
      <div style={{
        position: "absolute", left: x - width / 2, top, width, height: h,
        background: `linear-gradient(${headUp ? 0 : 180}deg, transparent, ${color})`,
        boxShadow: `0 0 6px ${color}, 0 0 14px ${color}`, borderRadius: width,
      }} />
      <div style={{ position: "absolute", left: x - 1, top, width: 2, height: h, background: "#fff", opacity: 0.75, borderRadius: 2 }} />
      <div style={{
        position: "absolute", left: x - cap / 2, top: y2 - cap * 0.9, width: cap, height: cap * 1.8,
        border: `2px solid ${color}`, borderRadius: cap, background: "rgba(0,0,0,0.35)",
        boxShadow: `0 0 10px ${color}, 0 0 18px ${color}`,
      }} />
    </React.Fragment>
  );
}

// projectile: outlined capsule head + a fading line trail behind it.
// dir = travel direction in degrees (90 = down). rot (legacy) offsets from down.
function Bolt({ x, y, color = PAL.magenta, w = 5, rot, dir, len = 30 }) {
  const d = dir != null ? dir : 90 + (rot || 0);
  const cap = w * 1.7;
  return (
    <div style={{ position: "absolute", left: x, top: y, transform: `rotate(${d - 90}deg)`, transformOrigin: "0 0" }}>
      <div style={{
        position: "absolute", left: -w / 2, top: -len, width: w, height: len,
        background: `linear-gradient(180deg, transparent, ${color})`, borderRadius: w,
        boxShadow: `0 0 6px ${color}`,
      }} />
      <div style={{
        position: "absolute", left: -cap / 2, top: -cap * 0.7, width: cap, height: cap * 1.9,
        border: `2px solid ${color}`, borderRadius: cap, background: "rgba(0,0,0,0.4)",
        boxShadow: `0 0 8px ${color}, 0 0 16px ${color}`,
      }} />
    </div>
  );
}

function Reticle({ x, y, size = 22, color = PAL.green }) {
  const s = size;
  return (
    <svg width={s} height={s} style={{ position: "absolute", left: x - s / 2, top: y - s / 2, filter: `drop-shadow(0 0 4px ${color})`, animation: "gciPulse 1.4s ease-in-out infinite" }}>
      <circle cx={s / 2} cy={s / 2} r={s / 2 - 3} fill="none" stroke={color} strokeWidth="2" />
      <line x1={s / 2} y1="1" x2={s / 2} y2={s - 1} stroke={color} strokeWidth="2" />
      <line x1="1" y1={s / 2} x2={s - 1} y2={s / 2} stroke={color} strokeWidth="2" />
    </svg>
  );
}

// Traditional arcade fireball: white-hot core, billowing orange/red flame
// lobes, and debris flying out. Less strict-vector, more "boom".
function Explosion({ x, y, size = 46, color = PAL.orange, core = "#ffffff" }) {
  const lobes = [[0, 0, 1], [-0.26, -0.12, 0.62], [0.27, -0.15, 0.58], [-0.14, 0.25, 0.56], [0.21, 0.24, 0.52], [0.02, -0.3, 0.46]];
  const flame = `radial-gradient(circle, #ffffff 0%, #ffe27a 20%, ${color} 46%, #ff3b1e 72%, rgba(255,59,30,0) 82%)`;
  return (
    <div style={{ position: "absolute", left: x - size / 2, top: y - size / 2, width: size, height: size }}>
      <div style={{ position: "absolute", inset: -size * 0.25, borderRadius: "50%", background: `radial-gradient(circle, ${color}44 0%, transparent 66%)`, filter: "blur(3px)" }} />
      {lobes.map(([dx, dy, sc], i) => (
        <div key={i} style={{
          position: "absolute", left: `${50 + dx * 100}%`, top: `${50 + dy * 100}%`,
          width: size * sc, height: size * sc, transform: "translate(-50%,-50%)", borderRadius: "50%",
          background: flame, mixBlendMode: "screen", opacity: 0.95,
        }} />
      ))}
      <div style={{ position: "absolute", left: "50%", top: "50%", width: size * 0.42, height: size * 0.42, transform: "translate(-50%,-50%)", borderRadius: "50%", background: "radial-gradient(circle,#fff 0%,#ffe9a8 55%,transparent 80%)" }} />
      {Array.from({ length: 9 }).map((_, i) => {
        const a = (i / 9) * Math.PI * 2 + 0.3, r = size * 0.66;
        return <div key={"d" + i} style={{
          position: "absolute", left: size / 2 + Math.cos(a) * r, top: size / 2 + Math.sin(a) * r,
          width: 6, height: 2, background: "#ffd24d", boxShadow: `0 0 5px ${color}`, borderRadius: 2,
          transformOrigin: "0 50%", transform: `rotate(${a}rad)`,
        }} />;
      })}
    </div>
  );
}

// small spark for a non-fatal hit
function Spark({ x, y, color = PAL.cyan }) {
  return (
    <div style={{ position: "absolute", left: x, top: y, width: 4, height: 4 }}>
      {[0, 60, 120, 180, 240, 300].map((a) => (
        <div key={a} style={{
          position: "absolute", left: 0, top: 0, width: 10, height: 2, background: color,
          boxShadow: `0 0 5px ${color}`, transformOrigin: "0 50%",
          transform: `rotate(${a}deg) translateX(2px)`, borderRadius: 2,
        }} />
      ))}
    </div>
  );
}

function TurnTimer({ seconds = 4, max = 5, warn = false }) {
  const color = seconds > max * 0.6 ? PAL.green : seconds > max * 0.3 ? PAL.yellow : PAL.magenta;
  return (
    <div style={{
      position: "absolute", left: 20, bottom: 86,
      display: "flex", alignItems: "center", gap: 10,
      fontFamily: "'Press Start 2P', monospace",
      animation: warn ? "gciPulse 0.5s ease-in-out infinite" : "none",
    }}>
      <span style={{ color, fontSize: 12, textShadow: `0 0 8px ${color}` }}>▼</span>
      <span style={{ color, fontSize: 26, textShadow: `0 0 12px ${color}` }}>{seconds}</span>
      <span style={{ color, fontSize: 12, opacity: 0.8 }}>s</span>
    </div>
  );
}

// faint home-zone bands (atmospheric depth cue, not a grid)
function HomeZones() {
  return (
    <React.Fragment>
      <div style={{ position: "absolute", left: 0, right: 0, top: 104, height: 140, background: "linear-gradient(180deg, rgba(255,32,96,0.06), transparent)" }} />
      <div style={{ position: "absolute", left: 0, right: 0, bottom: 84, height: 150, background: "linear-gradient(0deg, rgba(0,223,255,0.06), transparent)" }} />
    </React.Fragment>
  );
}

/* A reusable game-frame wrapper: fixed 900x700, black, starfield behind. */
function GameFrame({ children, seed = 7, debris = true, nebula = true, style }) {
  return (
    <div style={{ position: "relative", width: FRAME.w, height: FRAME.h, background: PAL.bg, overflow: "hidden", fontFamily: "'Press Start 2P', monospace", ...style }}>
      <Starfield seed={seed} debris={debris} nebula={nebula} />
      {children}
    </div>
  );
}

Object.assign(window, {
  GCI: { PAL, FRAME, fileX, rankY, START_POSITION, BACK_RANK, PX, mulberry32 },
  Starfield, Piece, Ship, ShipIcon, HUD, HelpButton, Beam, Bolt, Reticle, Explosion, Spark, TurnTimer, HomeZones, GameFrame,
});
