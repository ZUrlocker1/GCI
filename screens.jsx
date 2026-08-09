/* Galactic Chess Invaders — screen compositions
 * Note: PAL, FRAME, fileX, rankY, START_POSITION are already global
 * (declared in gci-shared.jsx) — do not redeclare them here. */

/* ============================ TITLE SCREEN ============================ */
function TitleScreen() {
  const titleLine = (txt, size) => (
    <div style={{
      fontFamily: "'Press Start 2P', monospace", fontSize: size,
      letterSpacing: 4, lineHeight: 1.1, color: PAL.cyan,
      textShadow: `0 0 20px ${PAL.cyan}, 0 0 6px ${PAL.cyan}`,
      animation: "gciCycle 6s linear infinite",
    }}>{txt}</div>
  );

  const HISCORES = [
    ["1", "ZUL", "052300", "L8"],
    ["2", "CPU", "041750", "L7"],
    ["3", "ACE", "033400", "L6"],
    ["4", "AY2", "028900", "L5"],
    ["5", "BOT", "019250", "L4"],
  ];

  return (
    <GameFrame seed={3}>
      {/* title block */}
      <div style={{ position: "absolute", top: 86, left: 0, width: FRAME.w, textAlign: "center", color: PAL.cyan }}>
        {titleLine("GALACTIC", 52)}
        <div style={{ height: 14 }} />
        {titleLine("CHESS", 52)}
        <div style={{ height: 14 }} />
        {titleLine("INVADERS", 52)}
      </div>

      {/* tagline */}
      <div style={{
        position: "absolute", top: 318, left: 0, width: FRAME.w, textAlign: "center",
        fontFamily: "'Press Start 2P', monospace", fontSize: 12, color: PAL.yellow,
        textShadow: `0 0 8px ${PAL.yellow}`, letterSpacing: 2,
      }}>
        ★ 40 YEARS IN THE MAKING ★
      </div>

      {/* fleet teaser — invaders sliding across the lower third */}
      <div style={{ position: "absolute", top: 392, left: 0, width: FRAME.w, height: 70 }}>
        <div style={{ position: "absolute", left: "50%", top: 0, transform: "translateX(-50%)" }}>
          <div style={{ display: "flex", gap: 18, animation: "gciSlide 5s ease-in-out infinite" }}>
            {GCI.BACK_RANK.map((t, i) => (
              <div key={i} style={{ position: "relative", width: 56, height: 64 }}>
                <Piece type={t} side="black" x={28} y={32} glow={1} />
              </div>
            ))}
          </div>
        </div>
      </div>

      {/* press any key */}
      <div style={{
        position: "absolute", top: 486, left: 0, width: FRAME.w, textAlign: "center",
        fontFamily: "'Press Start 2P', monospace", fontSize: 16, color: PAL.white,
        textShadow: `0 0 10px ${PAL.cyan}`, animation: "gciBlink 1s steps(1) infinite",
      }}>
        PRESS ANY KEY TO START
      </div>

      {/* high score table */}
      <div style={{ position: "absolute", top: 540, left: "50%", transform: "translateX(-50%)", textAlign: "center" }}>
        <div style={{ fontFamily: "'Press Start 2P', monospace", fontSize: 12, color: PAL.magenta, textShadow: `0 0 8px ${PAL.magenta}`, marginBottom: 16, letterSpacing: 2 }}>
          HIGH SCORES
        </div>
        <table style={{ fontFamily: "'Press Start 2P', monospace", fontSize: 12, color: PAL.white, borderCollapse: "separate", borderSpacing: "26px 9px" }}>
          <tbody>
            {HISCORES.map((r) => (
              <tr key={r[0]}>
                <td style={{ color: PAL.dim }}>{r[0]}</td>
                <td style={{ color: PAL.cyan, textShadow: `0 0 6px ${PAL.cyan}` }}>{r[1]}</td>
                <td>{r[2]}</td>
                <td style={{ color: PAL.yellow }}>{r[3]}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </GameFrame>
  );
}

/* ============================ GAMEPLAY — LEVEL 1 START ============================ */
function GameplayStart() {
  return (
    <GameFrame seed={11}>
      <HomeZones />
      {START_POSITION.map((p, i) => (
        <Piece key={i} type={p.type} side={p.side} file={p.file} rank={p.rank} />
      ))}

      {/* a lone Raider Scout cruising the top lane (classic mystery-ship flyover) */}
      <Ship type="scout" x={566} y={80} px={2} glow={1.3} />
      <Bolt x={566} y={120} color={PAL.green} w={5} h={14} />

      {/* turn timer (fresh, green, full 5s) */}
      <TurnTimer seconds={5} max={5} />

      {/* player ship, centered in its strip */}
      <Ship type="player" x={450} y={658} px={2} glow={1.3} />

      <HUD score={0} hi={12300} level={1} lives={3} info={true} infoLabel="INFO" infoStyle="outline" />
    </GameFrame>
  );
}

/* ============================ GAMEPLAY — PIECE SELECTED ============================ */
function GameplaySelected() {
  // Position: white has played e2-e4, black answered e7-e5. The light-square
  // bishop on f1 is selected; reticles climb the a6-f1 diagonal.
  const pieces = START_POSITION
    .filter((p) => !(p.side === "white" && p.file === 4 && p.rank === 2)) // e2 pawn moved
    .filter((p) => !(p.side === "black" && p.file === 4 && p.rank === 7)) // e7 pawn moved
    .concat([
      { type: "pawn", side: "white", file: 4, rank: 4 }, // e4
      { type: "pawn", side: "black", file: 4, rank: 5 }, // e5
    ]);

  const bishop = { file: 5, rank: 1 }; // f1
  const bx = fileX(bishop.file), by = rankY(bishop.rank);
  const reticles = [
    [4, 2], [3, 3], [2, 4], [1, 5], [0, 6], // e2 d3 c4 b5 a6
  ];

  return (
    <GameFrame seed={5}>
      <HomeZones />

      {/* last-move trail on the e4 pawn (orange streak from e2) */}
      <div style={{
        position: "absolute", left: fileX(4) - 3, top: rankY(4), width: 6, height: rankY(2) - rankY(4),
        background: `linear-gradient(180deg, ${PAL.orange}, transparent)`,
        boxShadow: `0 0 8px ${PAL.orange}`, opacity: 0.5, borderRadius: 4,
      }} />

      {pieces.map((p, i) => (
        <Piece key={i} type={p.type} side={p.side} file={p.file} rank={p.rank} />
      ))}

      {/* selected-piece halo */}
      <div style={{
        position: "absolute", left: bx, top: by, width: 64, height: 64,
        transform: "translate(-50%,-50%)", borderRadius: "50%",
        border: `2px solid ${PAL.cyan}`, boxShadow: `0 0 16px ${PAL.cyan}, inset 0 0 12px ${PAL.cyan}`,
        animation: "gciHalo 1.3s ease-in-out infinite",
      }} />

      {/* legal-move reticles */}
      {reticles.map(([f, r], i) => (
        <Reticle key={i} x={fileX(f)} y={rankY(r)} />
      ))}

      {/* timer in the warning state (red, pulsing) */}
      <TurnTimer seconds={1} max={5} warn={true} />

      <Ship type="player" x={486} y={658} px={2} glow={1.3} />
      <HUD score={1250} hi={12300} level={2} lives={3} info={true} infoLabel="INFO" infoStyle="outline" />
    </GameFrame>
  );
}

/* ============================ GAMEPLAY — MID-COMBAT CHAOS ============================ */
function GameplayCombat() {
  const OFF = 30; // fleet lateral shift
  const fb = (f, r) => fileX(f) + OFF; // shifted black x
  // descended, thinned black fleet
  const black = [
    { type: "king", f: 4, r: 6 },
    { type: "queen", f: 2, r: 6, dmg: 0.18 },
    { type: "rook", f: 6, r: 5, dmg: 0.3 },
    { type: "bishop", f: 1, r: 5 },
    { type: "knight", f: 5, r: 6, dmg: 0.45 },
    { type: "pawn", f: 0, r: 4, dmg: 0.5 },
    { type: "pawn", f: 3, r: 5 },
    { type: "pawn", f: 6, r: 4, dmg: 0.5 },
  ];
  // white defenders, battle-worn
  const white = [
    { type: "king", f: 4, r: 1 },
    { type: "rook", f: 0, r: 1, dmg: 0.12 },
    { type: "rook", f: 7, r: 1 },
    { type: "bishop", f: 2, r: 1 },
    { type: "queen", f: 3, r: 3 },        // developed
    { type: "knight", f: 5, r: 3, dmg: 0.2 }, // f3
    { type: "pawn", f: 1, r: 2 },
    { type: "pawn", f: 2, r: 2, dmg: 0.5 },
    { type: "pawn", f: 5, r: 2 },
    { type: "pawn", f: 6, r: 2, dmg: 0.5 },
    { type: "pawn", f: 7, r: 2 },
  ];

  const shipX = 506;

  return (
    <GameFrame seed={23}>
      <HomeZones />

      {/* black fleet */}
      {black.map((p, i) => (
        <Piece key={"b" + i} type={p.type} side="black" x={fb(p.f, p.r)} y={rankY(p.r)} dmg={p.dmg || 0} seed={i * 5 + 1} />
      ))}
      {/* white defenders */}
      {white.map((p, i) => (
        <Piece key={"w" + i} type={p.type} side="white" x={fileX(p.f)} y={rankY(p.r)} dmg={p.dmg || 0} seed={i * 9 + 2} />
      ))}

      {/* enemy fire — magenta bolts, incl. one diagonal (Level 3) */}
      <Bolt x={fileX(6) + OFF} y={rankY(3) + 6} color={PAL.magenta} />
      <Bolt x={fileX(1) + OFF} y={rankY(2) + 30} color={PAL.magenta} />
      <Bolt x={fileX(3) + OFF + 10} y={rankY(4)} color="#b14dff" rot={40} />

      {/* raider scout streaking across the top lane */}
      <Ship type="scout" x={300} y={78} px={2} glow={1.3} />

      {/* diving Galaxian Escort + its orange comet-tail shot */}
      <Ship type="escort" x={250} y={rankY(4) + 18} px={2} glow={1.4} />
      <div style={{
        position: "absolute", left: 250 - 3, top: rankY(4) + 40, width: 6, height: 60,
        background: `linear-gradient(180deg, ${PAL.orange}, transparent)`, boxShadow: `0 0 8px ${PAL.orange}`, borderRadius: 4,
      }} />
      <Bolt x={250} y={rankY(4) + 96} color={PAL.orange} w={6} h={18} />

      {/* player laser beam striking a low-advancing black pawn, with explosion */}
      <Piece type="pawn" side="black" x={shipX} y={rankY(4)} dmg={0.55} seed={42} />
      <Beam x={shipX} y1={648} y2={rankY(4) + 8} color={PAL.cyan} width={3} />
      <Explosion x={shipX} y={rankY(4) - 4} size={42} color={PAL.orange} />

      {/* a white pawn taking a hit (spark) and the c2 pawn breaking apart */}
      <Spark x={fileX(2)} y={rankY(2)} color={PAL.magenta} />

      {/* Shield power-up drifting down */}
      <ShieldPickup x={690} y={520} />

      {/* timer pinned at the floor, red */}
      <TurnTimer seconds={1} max={4} warn={true} />

      {/* player ship, firing */}
      <Ship type="player" x={shipX} y={658} px={2} glow={1.5} />

      <HUD score={47250} hi={52300} level={3} lives={2} info={true} infoLabel="INFO" infoStyle="outline" />
    </GameFrame>
  );
}

/* shield bubble pickup: cyan hexagon inside a glowing rotating diamond */
function ShieldPickup({ x, y }) {
  return (
    <div style={{ position: "absolute", left: x, top: y, transform: "translate(-50%,-50%)" }}>
      <div style={{ animation: "gciFloat 2.4s ease-in-out infinite" }}>
        <svg width="34" height="34" viewBox="0 0 34 34" style={{ filter: `drop-shadow(0 0 6px ${PAL.cyan})`, display: "block" }}>
          <rect x="17" y="2" width="21" height="21" transform="rotate(45 17 17)" fill="none" stroke={PAL.cyan} strokeWidth="1.5" opacity="0.7" />
          <polygon points="17,7 25,12 25,22 17,27 9,22 9,12" fill="none" stroke={PAL.cyan} strokeWidth="2" />
        </svg>
      </div>
    </div>
  );
}

/* inline (flowing) mini sprite for help/scoring lists */
function InlineMini({ type, side = "black", scale = 1.4, isShip = false }) {
  const ref = useRef(null);
  useEffect(() => {
    if (!ref.current) return;
    ref.current.innerHTML = "";
    const cv = isShip ? GCISprites.renderShipVector(type, scale) : GCISprites.renderPieceVector(type, side, scale);
    GCISprites.applyGlow(cv, 0.5);
    cv.style.verticalAlign = "middle";
    ref.current.appendChild(cv);
  }, [type, side, scale, isShip]);
  return <span ref={ref} style={{ display: "inline-block" }} />;
}

/* ============================ GAME OVER ============================ */
function GameOverScreen() {
  const mono = "ui-monospace, 'SF Mono', Menlo, monospace";
  const stat = (label, value, color) => (
    <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 9 }}>
      <span style={{ fontFamily: mono, fontSize: 12, color: PAL.dim, letterSpacing: 2 }}>{label}</span>
      <span style={{ fontFamily: "'Press Start 2P', monospace", fontSize: 22, color: color || PAL.white, textShadow: `0 0 10px ${color || PAL.cyan}` }}>{value}</span>
    </div>
  );
  return (
    <GameFrame seed={31} debris={true}>
      {/* the ship's final explosion + drifting debris near the bottom */}
      <Explosion x={450} y={566} size={120} color="#ff4d3d" />
      {[[360, 600, 40], [540, 590, -30], [470, 628, 70], [410, 560, 200]].map(([dx, dy, a], i) => (
        <div key={i} style={{ position: "absolute", left: dx, top: dy, width: 12, height: 2, background: PAL.cyan, boxShadow: `0 0 6px ${PAL.cyan}`, borderRadius: 2, transform: `rotate(${a}deg)`, opacity: 0.7 }} />
      ))}

      <div style={{ position: "absolute", top: 132, left: 0, width: FRAME.w, textAlign: "center" }}>
        <div style={{ fontFamily: "'Press Start 2P', monospace", fontSize: 60, color: PAL.magenta, letterSpacing: 3, textShadow: `0 0 24px ${PAL.magenta}, 0 0 6px ${PAL.magenta}`, animation: "gciPulse 2s ease-in-out infinite" }}>
          GAME<br /><div style={{ height: 16 }} />OVER
        </div>
      </div>

      <div style={{ position: "absolute", top: 350, left: 0, width: FRAME.w, display: "flex", justifyContent: "center", gap: 70 }}>
        {stat("FINAL SCORE", "047250", PAL.white)}
        {stat("HI-SCORE", "052300", PAL.yellow)}
        {stat("LEVEL REACHED", "03", PAL.cyan)}
      </div>

      <div style={{ position: "absolute", top: 452, left: 0, width: FRAME.w, textAlign: "center" }}>
        <div style={{ fontFamily: "'Press Start 2P', monospace", fontSize: 15, color: PAL.white, textShadow: `0 0 10px ${PAL.cyan}`, animation: "gciBlink 1s steps(1) infinite" }}>
          PRESS FIRE TO PLAY AGAIN
        </div>
        <div style={{ fontFamily: mono, fontSize: 12, color: PAL.dim, letterSpacing: 2, marginTop: 16 }}>ESC — MAIN MENU</div>
      </div>
    </GameFrame>
  );
}

/* ============================ HELP / HOW TO PLAY ============================ */
function HelpScreen() {
  const mono = "ui-monospace, 'SF Mono', Menlo, monospace";
  const Head = ({ children, color = PAL.cyan }) => (
    <div style={{ fontFamily: "'Press Start 2P', monospace", fontSize: 13, color, textShadow: `0 0 8px ${color}`, letterSpacing: 1, margin: "0 0 13px" }}>{children}</div>
  );
  const P = ({ children }) => <div style={{ fontFamily: mono, fontSize: 13, lineHeight: 1.7, color: "#bcd3e0", margin: "0 0 15px" }}>{children}</div>;
  const Key = ({ children }) => <span style={{ display: "inline-block", fontFamily: "'Press Start 2P', monospace", fontSize: 9, color: "#eaf6ff", border: `1px solid ${PAL.cyan}66`, borderRadius: 4, padding: "5px 7px", marginRight: 6, boxShadow: `0 0 6px ${PAL.cyan}33`, background: "rgba(0,30,45,0.4)" }}>{children}</span>;
  const ctrl = (keys, label) => (
    <div style={{ display: "flex", alignItems: "center", gap: 12, marginBottom: 13 }}>
      <div style={{ minWidth: 132 }}>{keys}</div>
      <div style={{ fontFamily: mono, fontSize: 12, color: "#bcd3e0" }}>{label}</div>
    </div>
  );
  const score = (node, pts) => (
    <div style={{ display: "flex", alignItems: "center", gap: 8, fontFamily: "'Press Start 2P', monospace", fontSize: 11, color: PAL.white }}>
      {node}<span style={{ color: PAL.yellow, textShadow: `0 0 6px ${PAL.yellow}` }}>{pts}</span>
    </div>
  );
  return (
    <GameFrame seed={17} debris={true}>
      <div style={{ position: "absolute", inset: 0, padding: "36px 56px 26px", display: "flex", flexDirection: "column", boxSizing: "border-box" }}>
        <div style={{
          position: "absolute", top: 30, right: 30, zIndex: 5,
          fontFamily: "'Press Start 2P', monospace", fontSize: 10, color: "#eaf9ff",
          display: "inline-flex", alignItems: "center", gap: 7, padding: "8px 12px", borderRadius: 6,
          border: `1.5px solid ${PAL.cyan}99`, background: "rgba(0,30,45,0.5)",
          boxShadow: `0 0 8px ${PAL.cyan}44, inset 0 0 6px ${PAL.cyan}22`, cursor: "pointer", letterSpacing: 1,
        }}>
          <span style={{ color: PAL.cyan, fontSize: 11 }}>◄</span> BACK
        </div>
        <div style={{ textAlign: "center", marginBottom: 22 }}>
          <div style={{ fontFamily: "'Press Start 2P', monospace", fontSize: 28, color: "#fff", textShadow: `0 0 16px ${PAL.cyan}`, letterSpacing: 1 }}>HOW TO PLAY</div>
          <div style={{ fontFamily: mono, fontSize: 11, color: PAL.dim, marginTop: 11, letterSpacing: 3 }}>GALACTIC CHESS INVADERS</div>
        </div>

        <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 40 }}>
          <div>
            <Head>THE TWIST</Head>
            <P>A real chess game plays out&nbsp;— but Black's army is also a Space Invaders fleet. It slides sideways, drops down, and fires at you. You command White's moves <b style={{ color: "#eaf6ff" }}>and</b> a laser ship at the bottom of the screen.</P>
            <Head>CONTROLS</Head>
            {ctrl(<span><Key>◄</Key><Key>►</Key><span style={{ fontFamily: mono, fontSize: 11, color: PAL.dim }}>/</span> <Key>A</Key><Key>D</Key></span>, "Move your ship")}
            {ctrl(<Key>SPACE</Key>, "Fire laser")}
            {ctrl(<Key>CLICK</Key>, "Pick a piece, click a square to move")}
            {ctrl(<Key>▼ 5s</Key>, "Turn timer — stall and the CPU moves")}
          </div>
          <div>
            <Head>HOW TO WIN</Head>
            <P>Clear the board: destroy every black piece by shooting it or capturing it in chess. Landing a shot on the black King ends the wave with a huge bonus.</P>
            <Head color={PAL.magenta}>STAY ALIVE</Head>
            <P>Guard your White King and your ship. You have 3 lives — lose one if a shot hits your ship or an invader reaches the bottom row.</P>
            <Head color={PAL.yellow}>SCORING</Head>
            <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: "12px 18px" }}>
              {score(<InlineMini type="king" scale={1.3} />, "500")}
              {score(<InlineMini type="queen" scale={1.3} />, "150")}
              {score(<InlineMini type="rook" scale={1.3} />, "75")}
              {score(<InlineMini type="knight" scale={1.3} />, "50")}
              {score(<InlineMini type="bishop" scale={1.3} />, "50")}
              {score(<InlineMini type="pawn" scale={1.3} />, "25")}
            </div>
          </div>
        </div>

        <div style={{ marginTop: 18 }}>
          <Head color={PAL.yellow}>HISTORY</Head>
          <div style={{ fontFamily: mono, fontSize: 13, lineHeight: 1.7, color: "#bcd3e0" }}>
            Galactic Chess Invaders began as a demo prototype in 1983 on the Apple&nbsp;II,
            written in TASC compiled BASIC. Now, with the help of Claude, you can experience
            a modern, recharged version.
          </div>
        </div>

        <div style={{ borderTop: `1px solid ${PAL.cyan}22`, paddingTop: 14, marginTop: "auto", display: "flex", justifyContent: "space-between", alignItems: "center" }}>
          <div style={{ fontFamily: mono, fontSize: 11, color: PAL.dim, letterSpacing: 1, whiteSpace: "nowrap" }}><span style={{ color: PAL.cyan }}>ESC</span> OR <span style={{ color: PAL.cyan }}>◄ BACK</span> TO RETURN</div>
          <div style={{ display: "flex", gap: 18, fontFamily: mono, fontSize: 11 }}>
            <span style={{ color: PAL.cyan }}>● YOU · WHITE</span>
            <span style={{ color: PAL.magenta }}>● ENEMY · BLACK</span>
          </div>
        </div>
      </div>
    </GameFrame>
  );
}

Object.assign(window, { TitleScreen, GameplayStart, GameplaySelected, GameplayCombat, ShieldPickup, GameOverScreen, HelpScreen, InlineMini });
