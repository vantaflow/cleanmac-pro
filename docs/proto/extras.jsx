// extras.jsx — Onboarding, Result screen, Storage Sunburst, Quick Clean FAB

// ═══════════════════════════════════════════════════════════════════════════
// STORAGE SUNBURST — animated donut showing what takes space
// ═══════════════════════════════════════════════════════════════════════════
function StorageSunburst({ size = 240, data, used, total }) {
  const cx = size/2, cy = size/2;
  const rOuter = size/2 - 6;
  const rInner = rOuter * 0.62;
  const total2 = data.reduce((s,d)=>s+d.value,0) || 1;
  let acc = 0;
  const segs = data.map(d => {
    const a0 = (acc / total2) * Math.PI * 2 - Math.PI/2;
    acc += d.value;
    const a1 = (acc / total2) * Math.PI * 2 - Math.PI/2;
    return { ...d, a0, a1 };
  });
  const arc = (a0, a1, r1, r2) => {
    const large = (a1-a0) > Math.PI ? 1 : 0;
    const sp = `M ${cx + r2*Math.cos(a0)} ${cy + r2*Math.sin(a0)}
      A ${r2} ${r2} 0 ${large} 1 ${cx + r2*Math.cos(a1)} ${cy + r2*Math.sin(a1)}
      L ${cx + r1*Math.cos(a1)} ${cy + r1*Math.sin(a1)}
      A ${r1} ${r1} 0 ${large} 0 ${cx + r1*Math.cos(a0)} ${cy + r1*Math.sin(a0)} Z`;
    return sp;
  };
  const [hover, setHover] = React.useState(null);
  const cur = hover ?? data.find(d=>d.key==='clean');
  return (
    <div style={{position:'relative', width:size, height:size}}>
      <svg width={size} height={size} style={{overflow:'visible'}}>
        <defs>
          {segs.map((s, i) => (
            <linearGradient key={i} id={`sg${i}`} x1="0" y1="0" x2="1" y2="1">
              <stop offset="0%" stopColor={s.color} stopOpacity="1"/>
              <stop offset="100%" stopColor={s.color} stopOpacity="0.7"/>
            </linearGradient>
          ))}
        </defs>
        {segs.map((s, i) => {
          const isHover = hover && hover.key === s.key;
          const r2 = isHover ? rOuter + 4 : rOuter;
          return (
            <path key={s.key} d={arc(s.a0+0.012, s.a1-0.012, rInner, r2)}
              fill={`url(#sg${i})`}
              onMouseEnter={()=>setHover(s)} onMouseLeave={()=>setHover(null)}
              style={{cursor:'default', transition:'d 200ms', filter: isHover ? `drop-shadow(0 0 8px ${s.color}80)` : 'none'}}/>
          );
        })}
      </svg>
      <div style={{position:'absolute', inset:0, display:'grid', placeItems:'center', pointerEvents:'none'}}>
        <div style={{textAlign:'center'}}>
          <div style={{fontSize:10.5, fontWeight:600, letterSpacing:'0.08em', color:'var(--text-3)', textTransform:'uppercase'}}>
            {cur ? cur.label : 'Stockage'}
          </div>
          <div style={{fontSize:32, fontWeight:700, letterSpacing:'-0.035em', lineHeight:1.05, marginTop:4}}>
            {cur ? `${cur.value.toFixed(1)} Go` : `${used} Go`}
          </div>
          <div style={{fontSize:11.5, color:'var(--text-2)', marginTop:3}}>
            {cur ? `${(cur.value/total*100).toFixed(1)}% du disque` : `de ${total} Go`}
          </div>
        </div>
      </div>
    </div>
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// WEEKLY TREND — sparkline strip
// ═══════════════════════════════════════════════════════════════════════════
function WeeklyTrend({ data }) {
  // data: array of {day, value}
  const max = Math.max(...data.map(d=>d.value)) || 1;
  const total = data.reduce((s,d)=>s+d.value,0);
  return (
    <GlassPanel style={{padding:'14px 18px'}}>
      <div style={{display:'flex', alignItems:'center', justifyContent:'space-between', marginBottom:12}}>
        <div>
          <div style={{fontSize:11, fontWeight:600, color:'var(--text-3)', textTransform:'uppercase', letterSpacing:'0.06em'}}>Cette semaine</div>
          <div style={{fontSize:20, fontWeight:700, letterSpacing:'-0.02em', marginTop:2}}>
            <span style={{color:'var(--accent)'}}>{total.toFixed(1)} Go</span>
            <span style={{fontSize:13, color:'var(--text-2)', fontWeight:500, marginLeft:8}}>récupérés en 7 jours</span>
          </div>
        </div>
        <StatusPill status="good">+ 38% vs la sem. passée</StatusPill>
      </div>
      <div style={{display:'flex', alignItems:'flex-end', gap:8, height:62}}>
        {data.map((d, i) => {
          const h = (d.value/max) * 100;
          const isToday = i === data.length-1;
          return (
            <div key={i} style={{flex:1, display:'flex', flexDirection:'column', alignItems:'center', gap:4}}>
              <div style={{flex:1, width:'100%', display:'flex', alignItems:'flex-end'}}>
                <div style={{
                  width:'100%', height:`${Math.max(4, h)}%`,
                  background: isToday
                    ? 'linear-gradient(180deg, var(--accent), rgba(0,217,163,0.7))'
                    : 'linear-gradient(180deg, rgba(0,217,163,0.5), rgba(0,217,163,0.15))',
                  borderRadius:'4px 4px 2px 2px',
                  boxShadow: isToday ? '0 0 0 0.5px rgba(0,217,163,0.5)' : 'none',
                  transition:'height 600ms cubic-bezier(.2,.8,.2,1)',
                  transitionDelay: `${i*40}ms`
                }}/>
              </div>
              <div style={{fontSize:10, color: isToday?'var(--text-1)':'var(--text-3)', fontWeight: isToday?700:500}}>{d.day}</div>
            </div>
          );
        })}
      </div>
    </GlassPanel>
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// ONBOARDING — 3-step (welcome → transparency → first scan)
// ═══════════════════════════════════════════════════════════════════════════
function Onboarding({ onClose, onStart }) {
  const [step, setStep] = React.useState(0);
  const next = () => step < 2 ? setStep(s=>s+1) : onStart();

  return (
    <div style={{
      position:'absolute', inset:0, zIndex:40,
      background:'rgba(20,22,30,0.92)',
      backdropFilter:'blur(20px) saturate(140%)',
      WebkitBackdropFilter:'blur(20px) saturate(140%)',
      display:'flex', alignItems:'center', justifyContent:'center',
      color:'#fff', overflow:'hidden',
      animation:'onb-bg 400ms ease-out'
    }}>
      <style>{`
        @keyframes onb-bg{from{opacity:0;backdrop-filter:blur(0px)}to{opacity:1}}
        @keyframes onb-glow{0%,100%{transform:scale(1);opacity:.5}50%{transform:scale(1.15);opacity:.7}}
        @keyframes onb-rise{from{opacity:0;transform:translateY(20px)}to{opacity:1;transform:none}}
      `}</style>

      {/* Background glow */}
      <div style={{
        position:'absolute', width:600, height:600, borderRadius:'50%',
        background:'radial-gradient(circle, rgba(0,217,163,0.25), transparent 60%)',
        animation:'onb-glow 4s ease-in-out infinite',
        pointerEvents:'none'
      }}/>

      <div style={{maxWidth:520, width:'100%', padding:40, position:'relative', textAlign:'center',
        animation:'onb-rise 500ms cubic-bezier(.2,.8,.2,1) both'}} key={step}>
        {step === 0 && <OnbWelcome/>}
        {step === 1 && <OnbTransparency/>}
        {step === 2 && <OnbReady/>}

        {/* Stepper + actions */}
        <div style={{marginTop:42, display:'flex', flexDirection:'column', alignItems:'center', gap:18}}>
          <div style={{display:'flex', gap:8}}>
            {[0,1,2].map(i => (
              <div key={i} style={{
                width: i===step ? 24 : 6, height:6, borderRadius:999,
                background: i<=step ? 'var(--accent)' : 'rgba(255,255,255,0.2)',
                transition:'width 300ms, background 200ms'
              }}/>
            ))}
          </div>
          <div style={{display:'flex', gap:10}}>
            {step > 0 && <Btn kind="ghost" onClick={()=>setStep(s=>s-1)} style={{color:'#fff'}}>Retour</Btn>}
            <Btn kind="primary" size="lg" onClick={next} icon={step===2?'scan':undefined}>
              {step === 0 ? 'Continuer' : step === 1 ? 'C\'est noté' : 'Lancer le premier scan'}
            </Btn>
          </div>
          {step < 2 && (
            <button onClick={onClose} style={{background:'transparent', border:0, color:'rgba(255,255,255,0.4)', fontSize:12, cursor:'default'}}>
              Passer l'intro
            </button>
          )}
        </div>
      </div>
    </div>
  );
}

function OnbWelcome() {
  return (
    <>
      <div style={{display:'inline-block', marginBottom:24}}>
        <div style={{
          width:120, height:120, borderRadius:28,
          background:'linear-gradient(160deg, #0c1f1a, #0a3329)',
          boxShadow:'0 20px 60px rgba(0,217,163,0.4), inset 0 1px 0 rgba(255,255,255,0.12)',
          display:'grid', placeItems:'center', margin:'0 auto'
        }}>
          <CmpMark size={88} hue="mint" animated/>
        </div>
      </div>
      <h1 style={{fontSize:34, fontWeight:700, letterSpacing:'-0.03em', margin:'0 0 12px'}}>
        Salut. Je suis <span style={{color:'var(--accent)'}}>CleanMac Pro</span>.
      </h1>
      <p style={{fontSize:15, color:'rgba(255,255,255,0.7)', lineHeight:1.5, margin:0, maxWidth:380, marginInline:'auto'}}>
        Je libère de l'espace, je tue les apps fantômes et je supprime les traces.
        <br/>Sans pop-ups marketing. Sans paniquer.
      </p>
    </>
  );
}

function OnbTransparency() {
  const items = [
    {ok:true, icon:'check', label:'Caches, logs, anciens .dmg, corbeilles', color:'#34C759'},
    {ok:true, icon:'check', label:'Apps que tu n\'as pas ouvertes depuis 6+ mois', color:'#34C759'},
    {ok:true, icon:'check', label:'Cookies tiers et traceurs publicitaires', color:'#34C759'},
    {ok:false, icon:'close', label:'Tes documents, photos, fichiers iCloud', color:'#FF453A'},
    {ok:false, icon:'close', label:'Tes mots de passe, clés, données chiffrées', color:'#FF453A'},
    {ok:false, icon:'close', label:'Aucune télémétrie. Tout reste local.', color:'#FF453A'},
  ];
  return (
    <>
      <div style={{
        width:80, height:80, borderRadius:20,
        background:'rgba(255,255,255,0.08)',
        display:'grid', placeItems:'center', margin:'0 auto 20px',
        border:'0.5px solid rgba(255,255,255,0.12)'
      }}>
        <Icon name="shield" size={36} color="var(--accent)"/>
      </div>
      <h1 style={{fontSize:30, fontWeight:700, letterSpacing:'-0.025em', margin:'0 0 8px'}}>
        Ce que je touche. Ce que je <span style={{textDecoration:'underline', textDecorationColor:'var(--accent)', textUnderlineOffset:5}}>ne touche jamais</span>.
      </h1>
      <p style={{fontSize:13.5, color:'rgba(255,255,255,0.55)', margin:'0 0 22px'}}>Aucune ambiguïté. Promis.</p>

      <div style={{textAlign:'left', display:'grid', gridTemplateColumns:'1fr 1fr', gap:8}}>
        {items.map((it,i) => (
          <div key={i} style={{
            display:'flex', alignItems:'center', gap:10, padding:'10px 12px',
            borderRadius:10, background: it.ok?'rgba(52,199,89,0.10)':'rgba(255,69,58,0.08)',
            border: `0.5px solid ${it.ok?'rgba(52,199,89,0.25)':'rgba(255,69,58,0.20)'}`
          }}>
            <div style={{width:18, height:18, borderRadius:'50%',
              background:it.ok?'rgba(52,199,89,0.2)':'rgba(255,69,58,0.18)',
              display:'grid', placeItems:'center', flexShrink:0}}>
              <Icon name={it.icon} size={11} color={it.color}/>
            </div>
            <span style={{fontSize:12, lineHeight:1.4}}>{it.label}</span>
          </div>
        ))}
      </div>
    </>
  );
}

function OnbReady() {
  return (
    <>
      <div style={{position:'relative', display:'inline-block', marginBottom:24}}>
        <ScanVisualMini/>
      </div>
      <h1 style={{fontSize:32, fontWeight:700, letterSpacing:'-0.025em', margin:'0 0 12px'}}>
        Premier scan. <span style={{color:'var(--accent)'}}>~30 secondes.</span>
      </h1>
      <p style={{fontSize:14.5, color:'rgba(255,255,255,0.7)', lineHeight:1.5, margin:0, maxWidth:400, marginInline:'auto'}}>
        Je vais regarder partout où macOS et tes apps stockent des trucs temporaires.
        Tu choisis ensuite ce qui part — rien n'est supprimé sans toi.
      </p>
    </>
  );
}

function ScanVisualMini() {
  return (
    <div style={{position:'relative', width:140, height:140, color:'var(--accent)'}}>
      <div style={{position:'absolute', inset:0, borderRadius:'50%', border:'1.5px solid currentColor', opacity:0.2}}/>
      <div style={{position:'absolute', inset:20, borderRadius:'50%', border:'1.5px solid currentColor', opacity:0.35}}/>
      <div style={{position:'absolute', inset:40, borderRadius:'50%', border:'1.5px solid currentColor', opacity:0.5,
        animation:'spin 2s linear infinite', borderTopColor:'transparent'}}/>
      <div style={{position:'absolute', inset:0, display:'grid', placeItems:'center'}}>
        <div style={{width:50, height:50, borderRadius:'50%', background:'var(--accent)',
          boxShadow:'0 0 30px rgba(0,217,163,0.6)'}}/>
      </div>
    </div>
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// RESULT SCREEN — post-cleanup celebration
// ═══════════════════════════════════════════════════════════════════════════
function ScreenResult({ ctx }) {
  const { goTo, runScan } = ctx;
  const recovered = 18.4;
  const items = [
    {label:'Caches & logs',  size:10.8, color:'#FFB020', count:'1 248 fichiers'},
    {label:'3 apps + résidus', size:5.3, color:'#0A84FF', count:'Final Cut, Adobe XD, Skype'},
    {label:'Téléchargements anciens', size:1.8, color:'#BF5AF2', count:'.dmg, .zip'},
    {label:'Corbeilles', size:0.5, color:'#8E8E93', count:'47 éléments'},
  ];

  return (
    <div style={{maxWidth:920, margin:'0 auto', padding:'20px 4px 40px', position:'relative'}}>
      <Confetti/>

      <div style={{textAlign:'center', marginBottom:32}}>
        <div style={{
          display:'inline-flex', alignItems:'center', gap:8, padding:'5px 12px', borderRadius:999,
          background:'rgba(52,199,89,0.14)', color:'#0F8A37', fontSize:12, fontWeight:600, marginBottom:18,
          animation:'rise 600ms cubic-bezier(.2,.8,.2,1) both'
        }}>
          <Icon name="check" size={13} color="#0F8A37"/> Nettoyage terminé en 42 s
        </div>

        <div style={{fontSize:14, fontWeight:600, color:'var(--text-3)', letterSpacing:'0.04em', textTransform:'uppercase', marginBottom:6, animation:'rise 700ms cubic-bezier(.2,.8,.2,1) both', animationDelay:'100ms'}}>Boom.</div>
        <h1 style={{
          fontSize:96, fontWeight:800, letterSpacing:'-0.045em', lineHeight:1, margin:'0 0 10px',
          background:'linear-gradient(135deg, var(--accent), #00A07A 60%, var(--text-1))',
          WebkitBackgroundClip:'text', WebkitTextFillColor:'transparent',
          animation:'rise 800ms cubic-bezier(.2,.8,.2,1) both', animationDelay:'150ms'
        }}>
          <AnimatedNumber value={recovered} format={v=>v.toFixed(1)}/> <span style={{fontSize:56}}>Go</span>
        </h1>
        <p style={{fontSize:18, color:'var(--text-2)', margin:'0 0 6px', animation:'rise 900ms cubic-bezier(.2,.8,.2,1) both', animationDelay:'250ms'}}>
          récupérés. Ton Mac respire.
        </p>
        <p style={{fontSize:13.5, color:'var(--text-3)', margin:0, animation:'rise 1s cubic-bezier(.2,.8,.2,1) both', animationDelay:'300ms'}}>
          Soit ~ 4 200 photos · 8 films 4K · 36 jeux indés
        </p>
      </div>

      <style>{`
        @keyframes rise{from{opacity:0;transform:translateY(16px)}to{opacity:1;transform:none}}
        @keyframes ctop{from{opacity:0;transform:translateY(-20px) rotate(0)}
          80%{opacity:1}to{opacity:0;transform:translateY(80vh) rotate(360deg)}}
      `}</style>

      {/* Breakdown */}
      <GlassPanel style={{padding:'18px 22px', marginBottom:14,
        animation:'rise 1.1s cubic-bezier(.2,.8,.2,1) both', animationDelay:'400ms'}}>
        <div style={{fontSize:11, fontWeight:600, letterSpacing:'0.06em', textTransform:'uppercase', color:'var(--text-3)', marginBottom:14}}>Détail</div>
        {items.map((it,i) => (
          <div key={it.label} style={{display:'flex', alignItems:'center', gap:14, padding:'10px 0',
            borderTop: i>0?'0.5px solid var(--hairline-soft)':'none'}}>
            <div style={{width:32, height:32, borderRadius:8, background:`${it.color}22`, color:it.color,
              display:'grid', placeItems:'center', fontWeight:700, fontSize:11}}>{(it.size).toFixed(1)}</div>
            <div style={{flex:1}}>
              <div style={{fontSize:13.5, fontWeight:600}}>{it.label}</div>
              <div style={{fontSize:11.5, color:'var(--text-3)'}}>{it.count}</div>
            </div>
            <div style={{fontSize:14, fontWeight:700, fontVariantNumeric:'tabular-nums'}}>{it.size.toFixed(1)} Go</div>
          </div>
        ))}
      </GlassPanel>

      {/* What's next */}
      <div style={{display:'grid', gridTemplateColumns:'1fr 1fr', gap:12,
        animation:'rise 1.2s cubic-bezier(.2,.8,.2,1) both', animationDelay:'500ms'}}>
        <GlassPanel style={{padding:'14px 18px'}}>
          <div style={{display:'flex', alignItems:'center', gap:10, marginBottom:6}}>
            <Icon name="sparkle" size={16} color="var(--accent)"/>
            <div style={{fontSize:13.5, fontWeight:700}}>Suggestion IA</div>
          </div>
          <p style={{fontSize:12.5, color:'var(--text-2)', margin:'0 0 12px', lineHeight:1.45}}>
            Tu peux encore gagner <b style={{color:'var(--text-1)'}}>8,2 Go</b> en supprimant 142 doublons de photos dans Photos.app.
          </p>
          <Btn kind="secondary" size="sm" onClick={()=>goTo('files')}>Voir les doublons</Btn>
        </GlassPanel>
        <GlassPanel style={{padding:'14px 18px'}}>
          <div style={{display:'flex', alignItems:'center', gap:10, marginBottom:6}}>
            <Icon name="wrench" size={16} color="#5E5CE6"/>
            <div style={{fontSize:13.5, fontWeight:700}}>Pendant qu'on y est</div>
          </div>
          <p style={{fontSize:12.5, color:'var(--text-2)', margin:'0 0 12px', lineHeight:1.45}}>
            5 tâches de maintenance sont prêtes : RAM, DNS, TRIM SSD, scripts macOS, permissions disque.
          </p>
          <Btn kind="secondary" size="sm" onClick={()=>goTo('maintenance')}>Lancer (12 s)</Btn>
        </GlassPanel>
      </div>

      <div style={{textAlign:'center', marginTop:28, animation:'rise 1.3s cubic-bezier(.2,.8,.2,1) both', animationDelay:'600ms'}}>
        <Btn kind="ghost" onClick={()=>goTo('dashboard')}>Retour à la vue d'ensemble</Btn>
      </div>
    </div>
  );
}

function Confetti() {
  const pieces = React.useMemo(() => Array.from({length:40}, (_,i) => ({
    x: Math.random()*100,
    delay: Math.random() * 800,
    duration: 2000 + Math.random()*2000,
    color: ['#00D9A3','#0A84FF','#BF5AF2','#FFB020','#FF9F0A'][i%5],
    size: 6 + Math.random()*6,
    rotate: Math.random()*360,
  })), []);
  return (
    <div style={{position:'absolute', inset:0, pointerEvents:'none', overflow:'hidden'}}>
      {pieces.map((p,i) => (
        <div key={i} style={{
          position:'absolute', top:0, left:`${p.x}%`, width:p.size, height:p.size*0.4,
          background:p.color, borderRadius:2,
          animation:`ctop ${p.duration}ms ease-out ${p.delay}ms forwards`,
          transform:`rotate(${p.rotate}deg)`
        }}/>
      ))}
    </div>
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// QUICK CLEAN FAB — floating quick action
// ═══════════════════════════════════════════════════════════════════════════
function QuickCleanFAB({ onClick }) {
  const [hover, setHover] = React.useState(false);
  return (
    <button onClick={onClick}
      onMouseEnter={()=>setHover(true)} onMouseLeave={()=>setHover(false)}
      style={{
      position:'absolute', bottom:24, right:24, zIndex:25,
      height:52, padding: hover ? '0 22px 0 18px' : '0 18px',
      borderRadius:26, border:0, cursor:'default',
      background:'linear-gradient(135deg, var(--accent), #00A07A)',
      color:'#062018', display:'flex', alignItems:'center', gap:10,
      boxShadow:'0 12px 36px rgba(0,217,163,0.45), inset 0 1px 0 rgba(255,255,255,0.3)',
      transition:'padding 200ms, transform 200ms', transform: hover?'translateY(-2px)':'none',
      fontFamily:'inherit', fontSize:14, fontWeight:700, letterSpacing:'-0.005em',
    }}>
      <span style={{position:'relative', width:24, height:24, display:'grid', placeItems:'center'}}>
        <span style={{position:'absolute', inset:-4, borderRadius:'50%', border:'1.5px solid rgba(6,32,24,0.4)', animation:'fab-pulse 1.6s ease-out infinite'}}/>
        <Icon name="bolt" size={18} color="#062018" strokeWidth={2.2}/>
      </span>
      <span>Quick Clean</span>
      <span style={{fontSize:11, fontWeight:600, padding:'2px 6px', borderRadius:5, background:'rgba(6,32,24,0.15)', fontFamily:'ui-monospace,monospace'}}>⌘⇧K</span>
      <style>{`@keyframes fab-pulse{0%{transform:scale(.8);opacity:.7}100%{transform:scale(1.5);opacity:0}}`}</style>
    </button>
  );
}

Object.assign(window, { StorageSunburst, WeeklyTrend, Onboarding, ScreenResult, QuickCleanFAB });
