// logo.jsx — CleanMac Pro brand mark
// Pulse/scan circle: concentric rings + scan bead + protected core dot

function CmpMark({ size = 48, hue = 'mint', animated = false }) {
  // hue presets: mint (brand), blue, violet, orange
  const HUES = {
    mint:   { from:'#00F0B5', to:'#00A07A',  glow:'#00D9A3' },
    blue:   { from:'#5AC8FF', to:'#0066FF',  glow:'#3DA9FF' },
    violet: { from:'#C896FF', to:'#7A3DFF',  glow:'#9C6BFF' },
    orange: { from:'#FFC066', to:'#FF7A1A',  glow:'#FF9A33' },
  };
  const h = HUES[hue] || HUES.mint;
  const id = React.useId().replace(/:/g, '');
  return (
    <svg width={size} height={size} viewBox="0 0 64 64" xmlns="http://www.w3.org/2000/svg" style={{display:'block'}}>
      <defs>
        <linearGradient id={`r${id}`} x1="0" y1="0" x2="1" y2="1">
          <stop offset="0%" stopColor={h.from}/>
          <stop offset="100%" stopColor={h.to}/>
        </linearGradient>
        <radialGradient id={`g${id}`} cx="50%" cy="50%" r="50%">
          <stop offset="0%" stopColor={h.glow} stopOpacity="0.5"/>
          <stop offset="60%" stopColor={h.glow} stopOpacity="0"/>
        </radialGradient>
        {animated && (
          <style>{`
            @keyframes cmp-spin-${id}{from{transform:rotate(0)}to{transform:rotate(360deg)}}
            @keyframes cmp-pulse-${id}{0%,100%{opacity:.7}50%{opacity:1}}
            .cmp-bead-${id}{transform-origin:32px 32px;animation:cmp-spin-${id} 4s linear infinite}
            .cmp-core-${id}{transform-origin:32px 32px;animation:cmp-pulse-${id} 2.4s ease-in-out infinite}
          `}</style>
        )}
      </defs>
      {/* soft glow */}
      <circle cx="32" cy="32" r="30" fill={`url(#g${id})`} />
      {/* outer ring */}
      <circle cx="32" cy="32" r="24" fill="none" stroke={`url(#r${id})`} strokeWidth="2.2" strokeLinecap="round" strokeOpacity="0.55"/>
      {/* mid ring */}
      <circle cx="32" cy="32" r="17" fill="none" stroke={`url(#r${id})`} strokeWidth="2.4" strokeLinecap="round" strokeOpacity="0.85"/>
      {/* scan arc (3/4 ring) */}
      <g className={animated ? `cmp-bead-${id}`:''}>
        <circle cx="32" cy="32" r="24" fill="none" stroke={`url(#r${id})`} strokeWidth="2.4" strokeLinecap="round"
          strokeDasharray="36 200" strokeDashoffset="0"/>
        {/* bead */}
        <circle cx="32" cy="8" r="2.6" fill={h.from}>
          {animated && <animate attributeName="r" values="2.4;3.4;2.4" dur="1.6s" repeatCount="indefinite"/>}
        </circle>
      </g>
      {/* core dot */}
      <circle cx="32" cy="32" r="5" fill={`url(#r${id})`} className={animated ? `cmp-core-${id}`:''}/>
    </svg>
  );
}

// App icon (squircle background + mark) — for menu bar icon, dock, etc.
function CmpAppIcon({ size = 64, hue = 'mint', rounded = true }) {
  const HUES = {
    mint:   { bg1:'#0c1f1a', bg2:'#0a3329', fg:'mint' },
    blue:   { bg1:'#0a1530', bg2:'#0a2750', fg:'blue' },
    violet: { bg1:'#1b0a30', bg2:'#2a1050', fg:'violet' },
    orange: { bg1:'#2b1505', bg2:'#3a1f08', fg:'orange' },
  };
  const h = HUES[hue] || HUES.mint;
  const id = React.useId().replace(/:/g, '');
  const r = rounded ? size * 0.225 : 0;
  return (
    <div style={{
      width: size, height: size, borderRadius: r,
      background: `linear-gradient(160deg, ${h.bg1}, ${h.bg2})`,
      boxShadow: rounded
        ? `inset 0 1px 0 rgba(255,255,255,0.12), 0 ${size*0.04}px ${size*0.12}px rgba(0,0,0,0.4)`
        : 'none',
      display:'grid', placeItems:'center', position:'relative', overflow:'hidden',
    }}>
      {/* subtle top sheen */}
      <div style={{position:'absolute', inset:0, background:
        'radial-gradient(ellipse at 50% -30%, rgba(255,255,255,0.18), transparent 50%)',
        pointerEvents:'none'}}/>
      <CmpMark size={size * 0.78} hue={h.fg}/>
    </div>
  );
}

// Wordmark — "CleanMac Pro" with mark
function CmpWordmark({ size = 14, color = 'currentColor', hue = 'mint' }) {
  return (
    <div style={{display:'inline-flex', alignItems:'center', gap: size*0.45}}>
      <CmpMark size={size * 1.5} hue={hue}/>
      <div style={{fontSize: size, fontWeight: 700, letterSpacing: '-0.01em', color}}>
        CleanMac <span style={{fontWeight: 500, opacity: 0.55}}>Pro</span>
      </div>
    </div>
  );
}

Object.assign(window, { CmpMark, CmpAppIcon, CmpWordmark });
