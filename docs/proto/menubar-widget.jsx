// menubar-widget.jsx — the small panel that drops from the menubar icon

function MenubarWidget({ open, onClose, openApp }) {
  if (!open) return null;
  return (
    <div style={{
      position:'fixed', top:32, right:48, zIndex:60, width:320,
      animation:'mb-in 200ms cubic-bezier(.2,.8,.2,1)',
    }}>
      <style>{`
        @keyframes mb-in{from{opacity:0;transform:translateY(-8px) scale(0.97)}to{opacity:1;transform:none}}
        @keyframes mb-bar{0%{transform:scaleY(.3)}100%{transform:scaleY(1)}}
      `}</style>
      <div style={{
        background:'rgba(28,28,32,0.88)',
        backdropFilter:'blur(40px) saturate(180%)',
        WebkitBackdropFilter:'blur(40px) saturate(180%)',
        borderRadius:14, padding:'12px 12px 10px',
        border:'0.5px solid rgba(255,255,255,0.12)',
        boxShadow:'0 12px 40px rgba(0,0,0,0.4)',
        color:'#fff', fontSize:12.5
      }}>
        {/* Header */}
        <div style={{display:'flex', alignItems:'center', gap:8, padding:'4px 6px 12px'}}>
          <CmpMark size={22} hue="mint" animated/>
          <div style={{flex:1}}>
            <div style={{fontSize:12.5, fontWeight:600}}>CleanMac Pro</div>
            <div style={{fontSize:10.5, opacity:0.55}}>Veille active · 18,4 Go récupérables</div>
          </div>
          <button onClick={onClose} style={{background:'transparent', border:0, color:'rgba(255,255,255,0.5)', cursor:'default', padding:4}}>
            <Icon name="close" size={14} color="rgba(255,255,255,0.5)"/>
          </button>
        </div>

        {/* Live meters */}
        <div style={{display:'grid', gridTemplateColumns:'repeat(3, 1fr)', gap:8, marginBottom:12}}>
          <Meter label="CPU" value={32} max={100} color="#0A84FF" unit="%"/>
          <Meter label="RAM" value={14.2} max={16} color="#BF5AF2" unit="Go"/>
          <Meter label="Disque" value={207} max={482} color="var(--accent)" unit="Go"/>
        </div>

        {/* Live activity sparkline */}
        <div style={{padding:'10px 12px', borderRadius:10, background:'rgba(255,255,255,0.04)', marginBottom:10}}>
          <div style={{display:'flex', justifyContent:'space-between', marginBottom:6}}>
            <span style={{fontSize:11, fontWeight:600, opacity:0.7}}>Activité réseau</span>
            <span style={{fontSize:11, opacity:0.5, fontVariantNumeric:'tabular-nums'}}>↑ 2,1 Mo/s · ↓ 14,8 Mo/s</span>
          </div>
          <Spark/>
        </div>

        {/* Quick actions */}
        <div style={{display:'flex', flexDirection:'column', gap:2}}>
          <QuickAction icon="scan" label="Lancer Smart Scan" sub="Dernier · il y a 3 jours" accent onClick={()=>openApp('scan')}/>
          <QuickAction icon="ram"  label="Libérer la RAM" sub="14,2 / 16 Go utilisés" onClick={()=>openApp('maintenance')}/>
          <QuickAction icon="trash" label="Vider la corbeille" sub="2,3 Go" onClick={()=>openApp('cleanup')}/>
          <QuickAction icon="moon" label="Mode focus silencieux" sub="Désactive les notifs CleanMac" toggle/>
        </div>

        <div style={{borderTop:'0.5px solid rgba(255,255,255,0.1)', marginTop:8, paddingTop:8,
          display:'flex', justifyContent:'space-between', alignItems:'center'}}>
          <button onClick={()=>openApp('dashboard')} style={{background:'transparent', border:0, color:'var(--accent)', fontSize:12, fontWeight:600, cursor:'default'}}>
            Ouvrir CleanMac Pro →
          </button>
          <span style={{fontSize:10.5, opacity:0.4}}>v 1.0.0</span>
        </div>
      </div>
    </div>
  );
}

function Meter({ label, value, max, color, unit }) {
  const pct = value/max*100;
  return (
    <div style={{padding:'8px 10px', borderRadius:9, background:'rgba(255,255,255,0.04)'}}>
      <div style={{fontSize:10.5, opacity:0.55, fontWeight:600, letterSpacing:'0.04em', textTransform:'uppercase'}}>{label}</div>
      <div style={{display:'flex', alignItems:'baseline', gap:2, margin:'2px 0 5px'}}>
        <span style={{fontSize:16, fontWeight:700, letterSpacing:'-0.02em', fontVariantNumeric:'tabular-nums'}}>
          {Number.isInteger(value) ? value : value.toFixed(1)}
        </span>
        <span style={{fontSize:10, opacity:0.5}}>{unit==='%' ? '%' : `/${max} ${unit}`}</span>
      </div>
      <div style={{height:3, background:'rgba(255,255,255,0.08)', borderRadius:999, overflow:'hidden'}}>
        <div style={{height:'100%', width:`${pct}%`, background:color, borderRadius:999}}/>
      </div>
    </div>
  );
}

function Spark() {
  // simple SVG bars (random but stable)
  const bars = React.useMemo(()=> Array.from({length:32}, (_,i)=> {
    const seed = Math.sin(i*1.3) * 0.5 + 0.5;
    return seed * 0.7 + 0.2 + (i>22 ? 0.15 : 0);
  }), []);
  return (
    <svg width="100%" height="28" viewBox="0 0 320 28" preserveAspectRatio="none">
      {bars.map((v, i) => (
        <rect key={i} x={i * 9} y={28 - v * 28} width="6" height={v*28} rx="1.5"
          fill="var(--accent)" opacity={0.4 + v*0.5}>
          <animate attributeName="height" values={`${v*28};${v*28*0.6};${v*28}`} dur={`${1.5+i*0.04}s`} repeatCount="indefinite"/>
          <animate attributeName="y" values={`${28-v*28};${28-v*28*0.6};${28-v*28}`} dur={`${1.5+i*0.04}s`} repeatCount="indefinite"/>
        </rect>
      ))}
    </svg>
  );
}

function QuickAction({ icon, label, sub, accent, onClick, toggle }) {
  const [on, setOn] = React.useState(false);
  return (
    <div onClick={()=>{ if (toggle) setOn(o=>!o); else onClick?.(); }}
      onMouseEnter={e=>e.currentTarget.style.background='rgba(255,255,255,0.06)'}
      onMouseLeave={e=>e.currentTarget.style.background='transparent'}
      style={{
      display:'flex', alignItems:'center', gap:10, padding:'8px 10px', borderRadius:9,
      cursor:'default', transition:'background 120ms'
    }}>
      <div style={{width:28, height:28, borderRadius:7,
        background: accent?'rgba(0,217,163,0.16)':'rgba(255,255,255,0.06)',
        display:'grid', placeItems:'center'}}>
        <Icon name={icon} size={15} color={accent?'var(--accent)':'#fff'}/>
      </div>
      <div style={{flex:1, minWidth:0}}>
        <div style={{fontSize:12.5, fontWeight:600}}>{label}</div>
        <div style={{fontSize:10.5, opacity:0.55, marginTop:1}}>{sub}</div>
      </div>
      {toggle && <Toggle value={on} onChange={setOn}/>}
      {!toggle && <Icon name="chevron" size={12} color="rgba(255,255,255,0.4)"/>}
    </div>
  );
}

Object.assign(window, { MenubarWidget });
