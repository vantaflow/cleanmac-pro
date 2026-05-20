// components.jsx — shared UI primitives for CleanMac Pro

// ── Icons (24x24 stroke icons, SF Symbols-ish) ──────────────────────────────
function Icon({ name, size = 18, color = 'currentColor', strokeWidth = 1.7 }) {
  const s = strokeWidth;
  const sw = { fill: 'none', stroke: color, strokeWidth: s, strokeLinecap: 'round', strokeLinejoin: 'round' };
  const paths = {
    dashboard: (<><circle cx="12" cy="12" r="9" {...sw}/><path d="M12 7v5l3 2" {...sw}/></>),
    scan:      (<><circle cx="12" cy="12" r="8" {...sw}/><circle cx="12" cy="12" r="3.5" {...sw}/><circle cx="12" cy="4" r="1.2" fill={color} stroke="none"/></>),
    broom:     (<><path d="M4 20l8-8" {...sw}/><path d="M12 12l4-4 4 4-4 4-4-4z" {...sw}/><path d="M3 21l3-1 0 0" {...sw}/></>),
    app:       (<><rect x="3.5" y="3.5" width="7" height="7" rx="1.5" {...sw}/><rect x="13.5" y="3.5" width="7" height="7" rx="1.5" {...sw}/><rect x="3.5" y="13.5" width="7" height="7" rx="1.5" {...sw}/><rect x="13.5" y="13.5" width="7" height="7" rx="1.5" {...sw}/></>),
    files:     (<><path d="M4 6h6l2 2h8v11a1 1 0 0 1-1 1H4z" {...sw}/></>),
    shield:    (<><path d="M12 3l8 3v6c0 5-3.5 8-8 9-4.5-1-8-4-8-9V6z" {...sw}/></>),
    wrench:    (<><path d="M14 6a4 4 0 0 0-4 4c0 .9.3 1.7.8 2.4L3 20l1 1 7.6-7.8c.7.5 1.5.8 2.4.8a4 4 0 0 0 3.6-5.7l-2.4 2.4-1.7-1.7L16 6.4A4 4 0 0 0 14 6z" {...sw}/></>),
    chip:      (<><rect x="6" y="6" width="12" height="12" rx="2" {...sw}/><path d="M9 3v3M12 3v3M15 3v3M9 18v3M12 18v3M15 18v3M3 9h3M3 12h3M3 15h3M18 9h3M18 12h3M18 15h3" {...sw}/></>),
    sparkle:   (<><path d="M12 3l1.6 4.4L18 9l-4.4 1.6L12 15l-1.6-4.4L6 9l4.4-1.6z" {...sw}/><path d="M19 16l.7 1.8L21.5 18.5l-1.8.7L19 21l-.7-1.8L16.5 18.5l1.8-.7z" {...sw}/></>),
    chevron:   (<><path d="M9 6l6 6-6 6" {...sw}/></>),
    check:     (<><path d="M5 12l5 5L20 7" {...sw} strokeWidth={s+0.3}/></>),
    trash:     (<><path d="M4 7h16M9 7V4h6v3M6 7l1 13h10l1-13" {...sw}/></>),
    play:      (<><path d="M7 5l12 7-12 7z" {...sw} strokeLinejoin="round"/></>),
    pause:     (<><rect x="6" y="5" width="4" height="14" rx="1" {...sw}/><rect x="14" y="5" width="4" height="14" rx="1" {...sw}/></>),
    close:     (<><path d="M6 6l12 12M18 6L6 18" {...sw}/></>),
    search:    (<><circle cx="11" cy="11" r="6" {...sw}/><path d="M16 16l4 4" {...sw}/></>),
    bolt:      (<><path d="M13 3L5 14h6l-1 7 8-11h-6z" {...sw}/></>),
    moon:      (<><path d="M20 14A8 8 0 0 1 10 4a8 8 0 1 0 10 10z" {...sw}/></>),
    info:      (<><circle cx="12" cy="12" r="9" {...sw}/><path d="M12 8v.5M12 11v5" {...sw}/></>),
    arrow:     (<><path d="M5 12h14M13 6l6 6-6 6" {...sw}/></>),
    ram:       (<><rect x="3" y="8" width="18" height="8" rx="1.5" {...sw}/><path d="M7 11v2M11 11v2M15 11v2" {...sw}/></>),
    disk:      (<><circle cx="12" cy="12" r="9" {...sw}/><circle cx="12" cy="12" r="2" {...sw}/></>),
    battery:   (<><rect x="3" y="7" width="16" height="10" rx="2" {...sw}/><path d="M21 10v4" {...sw}/><rect x="5" y="9" width="9" height="6" fill={color} stroke="none" rx="0.5"/></>),
    network:   (<><path d="M5 13a10 10 0 0 1 14 0M8 16a6 6 0 0 1 8 0" {...sw}/><circle cx="12" cy="19" r="1.2" fill={color} stroke="none"/></>),
    eye:       (<><path d="M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7S2 12 2 12z" {...sw}/><circle cx="12" cy="12" r="3" {...sw}/></>),
    cookie:    (<><path d="M12 3a9 9 0 1 0 9 9 4 4 0 0 1-5-5 4 4 0 0 1-4-4z" {...sw}/><circle cx="9" cy="10" r="0.8" fill={color} stroke="none"/><circle cx="13" cy="14" r="0.8" fill={color} stroke="none"/><circle cx="16" cy="11" r="0.8" fill={color} stroke="none"/></>),
    folder:    (<><path d="M3 6h6l2 2h10v11a1 1 0 0 1-1 1H3z" {...sw}/></>),
  };
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" aria-hidden="true">{paths[name] || null}</svg>
  );
}

// ── Glass surfaces & panels ─────────────────────────────────────────────────
function GlassPanel({ style={}, children, radius=14, inset=true, className='' }) {
  return (
    <div className={className} style={{
      background:'var(--panel)',
      backdropFilter:'blur(30px) saturate(160%)',
      WebkitBackdropFilter:'blur(30px) saturate(160%)',
      border:'0.5px solid var(--hairline)',
      borderRadius:radius,
      boxShadow: inset ? 'inset 0 1px 0 rgba(255,255,255,0.4), 0 1px 2px rgba(0,0,0,0.03)' : 'none',
      ...style
    }}>{children}</div>
  );
}

// ── Ring progress ───────────────────────────────────────────────────────────
function Ring({ size=140, stroke=10, value=78, max=100, color='var(--accent)', track='var(--hairline)', children, label }) {
  const r = (size - stroke)/2;
  const C = 2*Math.PI*r;
  const off = C - (value/max)*C;
  return (
    <div style={{position:'relative', width:size, height:size}}>
      <svg width={size} height={size} style={{transform:'rotate(-90deg)'}}>
        <circle cx={size/2} cy={size/2} r={r} fill="none" stroke={track} strokeWidth={stroke}/>
        <circle cx={size/2} cy={size/2} r={r} fill="none" stroke={color} strokeWidth={stroke}
                strokeLinecap="round" strokeDasharray={C} strokeDashoffset={off}
                style={{transition:'stroke-dashoffset 600ms cubic-bezier(.2,.8,.2,1)'}}/>
      </svg>
      <div style={{position:'absolute', inset:0, display:'grid', placeItems:'center', textAlign:'center'}}>
        {children}
      </div>
    </div>
  );
}

// ── Animated number ─────────────────────────────────────────────────────────
function AnimatedNumber({ value, format = (v)=>v.toFixed(1), duration=600 }) {
  const [v, setV] = React.useState(value);
  const fromRef = React.useRef(value);
  const startRef = React.useRef(0);
  React.useEffect(() => {
    fromRef.current = v;
    startRef.current = performance.now();
    let raf;
    const tick = (t) => {
      const p = Math.min(1, (t - startRef.current) / duration);
      const ease = 1 - Math.pow(1-p, 3);
      setV(fromRef.current + (value - fromRef.current) * ease);
      if (p < 1) raf = requestAnimationFrame(tick);
    };
    raf = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(raf);
    // eslint-disable-next-line
  }, [value]);
  return <>{format(v)}</>;
}

// ── Buttons ─────────────────────────────────────────────────────────────────
function Btn({ kind='primary', size='md', onClick, children, icon, disabled=false, style={} }) {
  const SIZES = { sm:{h:28, px:12, fs:12.5, r:7}, md:{h:34, px:16, fs:13.5, r:9}, lg:{h:42, px:22, fs:15, r:11} };
  const s = SIZES[size];
  const base = {
    display:'inline-flex', alignItems:'center', gap:8, height:s.h, padding:`0 ${s.px}px`,
    fontSize:s.fs, fontWeight:600, fontFamily:'inherit', letterSpacing:'-0.005em',
    borderRadius:s.r, border:'0.5px solid transparent', cursor: disabled?'not-allowed':'default',
    userSelect:'none', whiteSpace:'nowrap', transition:'transform 80ms, opacity 120ms',
    opacity: disabled ? 0.5 : 1,
  };
  const variants = {
    primary: { background:'var(--accent)', color:'#062018', boxShadow:'0 1px 0 rgba(255,255,255,0.4) inset, 0 1px 2px rgba(0,0,0,0.06)'},
    secondary: { background:'rgba(0,0,0,0.06)', color:'var(--text-1)', borderColor:'var(--hairline)'},
    ghost: { background:'transparent', color:'var(--text-1)'},
    danger: { background:'rgba(255,69,58,0.12)', color:'#FF453A', borderColor:'rgba(255,69,58,0.25)'},
    dark:  { background:'rgba(0,0,0,0.85)', color:'#fff'},
  };
  return (
    <button onClick={disabled?undefined:onClick}
      onMouseDown={e=>e.currentTarget.style.transform='scale(0.97)'}
      onMouseUp={e=>e.currentTarget.style.transform='scale(1)'}
      onMouseLeave={e=>e.currentTarget.style.transform='scale(1)'}
      style={{...base, ...variants[kind], ...style}}>
      {icon && <Icon name={icon} size={s.fs+2}/>}
      {children}
    </button>
  );
}

// ── Status pill (health states) ─────────────────────────────────────────────
function StatusPill({ status='good', children }) {
  const colors = {
    good: { bg:'rgba(52,199,89,0.14)', fg:'#0F8A37', dot:'#34C759' },
    warn: { bg:'rgba(255,176,32,0.16)', fg:'#A6680A', dot:'#FFB020' },
    bad:  { bg:'rgba(255,69,58,0.14)',  fg:'#C5251D', dot:'#FF453A' },
    info: { bg:'rgba(0,122,255,0.12)',  fg:'#0656B5', dot:'#0A84FF' },
  };
  const c = colors[status] || colors.good;
  return (
    <span style={{
      display:'inline-flex', alignItems:'center', gap:6,
      padding:'3px 9px', borderRadius:999, background:c.bg, color:c.fg,
      fontSize:11.5, fontWeight:600, letterSpacing:'0.005em'
    }}>
      <span style={{width:6, height:6, borderRadius:999, background:c.dot}}/>
      {children}
    </span>
  );
}

// ── File-size meter (segmented bar) ─────────────────────────────────────────
function SegBar({ segments, height=10 }) {
  const total = segments.reduce((s, x)=>s+x.value, 0) || 1;
  return (
    <div style={{display:'flex', height, borderRadius:999, overflow:'hidden', background:'var(--hairline-soft)'}}>
      {segments.map((s, i) => (
        <div key={i} title={`${s.label}: ${s.value}`} style={{
          width: `${s.value/total*100}%`, background:s.color, position:'relative',
          borderRight: i<segments.length-1 ? '1px solid var(--window-bg-solid)' : 'none'
        }}/>
      ))}
    </div>
  );
}

// ── Row checkbox ────────────────────────────────────────────────────────────
function Check({ checked, onChange, partial=false }) {
  return (
    <button onClick={(e)=>{e.stopPropagation(); onChange?.(!checked)}}
      style={{
        width:18, height:18, borderRadius:5, border:'1px solid',
        borderColor: (checked||partial) ? 'var(--accent)' : 'rgba(0,0,0,0.25)',
        background: (checked||partial) ? 'var(--accent)' : 'transparent',
        display:'grid', placeItems:'center', cursor:'default', padding:0,
        transition:'background 120ms, border-color 120ms'
      }}>
      {checked && <svg width="11" height="11" viewBox="0 0 24 24"><path d="M5 12l5 5L20 7" fill="none" stroke="#062018" strokeWidth="3" strokeLinecap="round" strokeLinejoin="round"/></svg>}
      {partial && !checked && <div style={{width:8, height:2, background:'#062018', borderRadius:1}}/>}
    </button>
  );
}

// ── Toggle ──────────────────────────────────────────────────────────────────
function Toggle({ value, onChange }) {
  return (
    <button onClick={()=>onChange(!value)} style={{
      width:34, height:20, borderRadius:999, border:0,
      background: value ? 'var(--accent)' : 'rgba(0,0,0,0.18)',
      position:'relative', cursor:'default', padding:0, transition:'background 160ms'
    }}>
      <span style={{
        position:'absolute', top:2, left: value? 16 : 2, width:16, height:16, borderRadius:999, background:'#fff',
        boxShadow:'0 1px 3px rgba(0,0,0,0.18)', transition:'left 180ms cubic-bezier(.4,.2,.2,1.2)'
      }}/>
    </button>
  );
}

// ── Animated bar ────────────────────────────────────────────────────────────
function HBar({ value, max=100, color='var(--accent)', height=6 }) {
  return (
    <div style={{height, borderRadius:999, background:'var(--hairline-soft)', overflow:'hidden'}}>
      <div style={{height:'100%', width:`${Math.min(100, value/max*100)}%`, background:color, borderRadius:999,
        transition:'width 600ms cubic-bezier(.2,.8,.2,1)'}}/>
    </div>
  );
}

// ── Utilities ───────────────────────────────────────────────────────────────
function fmtBytes(gb, frac=1) {
  if (gb >= 1) return `${gb.toFixed(frac)} Go`;
  return `${(gb*1000).toFixed(0)} Mo`;
}

Object.assign(window, {
  Icon, GlassPanel, Ring, AnimatedNumber, Btn, StatusPill, SegBar, Check, Toggle, HBar, fmtBytes
});
