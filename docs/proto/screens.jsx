// screens.jsx — All CleanMac Pro screens

// ── Shared bits ─────────────────────────────────────────────────────────────
function ScreenHeader({ title, subtitle, kicker, right }) {
  return (
    <div style={{display:'flex', alignItems:'flex-end', justifyContent:'space-between', marginBottom:22, gap:24}}>
      <div>
        {kicker && <div style={{fontSize:11, fontWeight:600, letterSpacing:'0.08em', textTransform:'uppercase', color:'var(--text-3)', marginBottom:6}}>{kicker}</div>}
        <h1 style={{margin:0, fontSize:30, fontWeight:700, letterSpacing:'-0.025em'}}>{title}</h1>
        {subtitle && <div style={{marginTop:6, fontSize:14, color:'var(--text-2)', maxWidth:560}}>{subtitle}</div>}
      </div>
      {right}
    </div>
  );
}

function CategoryRow({ icon, label, sub, size, color, checked, partial, onCheck, onClick, expanded, children, accent='var(--accent)' }) {
  return (
    <div onClick={onClick} style={{
      borderRadius:12, padding:'10px 12px', display:'flex', alignItems:'center', gap:12,
      cursor:'default', userSelect:'none',
      background: expanded ? 'rgba(0,0,0,0.04)' : 'transparent',
      transition:'background 120ms'
    }}
    onMouseEnter={e=>{ if(!expanded) e.currentTarget.style.background='rgba(0,0,0,0.025)'}}
    onMouseLeave={e=>{ if(!expanded) e.currentTarget.style.background='transparent'}}>
      <Check checked={checked} partial={partial} onChange={onCheck}/>
      <div style={{width:32, height:32, borderRadius:9, background:`${color}22`, display:'grid', placeItems:'center', color}}>
        <Icon name={icon} size={17} color={color}/>
      </div>
      <div style={{flex:1, minWidth:0}}>
        <div style={{fontSize:13.5, fontWeight:600, color:'var(--text-1)', letterSpacing:'-0.005em'}}>{label}</div>
        {sub && <div style={{fontSize:11.5, color:'var(--text-3)', marginTop:1}}>{sub}</div>}
      </div>
      <div style={{fontSize:13, fontWeight:600, fontVariantNumeric:'tabular-nums', color:'var(--text-1)'}}>{size}</div>
      <Icon name="chevron" size={14} color="var(--text-3)" />
    </div>
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// 1. DASHBOARD
// ═══════════════════════════════════════════════════════════════════════════
function ScreenDashboard({ ctx }) {
  const { stats, goTo, runScan, openAI } = ctx;

  const storageData = [
    {key:'system', label:'Système', value:32, color:'#5E5CE6'},
    {key:'apps', label:'Applications', value:84, color:'#0A84FF'},
    {key:'docs', label:'Documents', value:42, color:'#FFB020'},
    {key:'photos', label:'Photos', value:30.6, color:'#FF9F0A'},
    {key:'clean', label:'À nettoyer', value:18.4, color:'#00D9A3'},
    {key:'free', label:'Libre', value:275, color:'#E4E6EB'},
  ];

  const weekly = [
    {day:'Lu', value:1.2}, {day:'Ma', value:0.4}, {day:'Me', value:2.8},
    {day:'Je', value:0.8}, {day:'Ve', value:3.4}, {day:'Sa', value:0.2},
    {day:'Di', value:5.1},
  ];

  return (
    <div style={{maxWidth: 980, margin:'0 auto', padding:'8px 4px 40px'}}>
      <ScreenHeader
        kicker={`Bonjour — ${new Date().toLocaleDateString('fr-FR',{weekday:'long', day:'numeric', month:'long'})}`}
        title="Ton Mac va bien."
        subtitle="Dernier scan il y a 3 jours. Tu peux récupérer 18,4 Go sans rien casser."
        right={
          <div style={{display:'flex', gap:8}}>
            <Btn kind="secondary" icon="sparkle" onClick={openAI}>Demander à l'IA</Btn>
            <Btn kind="primary" icon="scan" size="lg" onClick={runScan}>Lancer Smart Scan</Btn>
          </div>
        }/>

      {/* Hero: storage sunburst + health ring + key stats */}
      <GlassPanel style={{padding:'24px 26px', marginBottom:14, position:'relative', overflow:'hidden'}}>
        <div style={{position:'absolute', top:-80, right:-80, width:300, height:300, borderRadius:'50%',
          background:'radial-gradient(circle, rgba(0,217,163,0.10), transparent 60%)', pointerEvents:'none'}}/>
        <div style={{display:'grid', gridTemplateColumns:'260px 240px 1fr', gap:32, alignItems:'center', position:'relative'}}>
          {/* Storage Sunburst */}
          <div style={{textAlign:'center'}}>
            <div style={{fontSize:11, fontWeight:600, color:'var(--text-3)', textTransform:'uppercase', letterSpacing:'0.06em', marginBottom:10}}>Stockage · 482 Go</div>
            <StorageSunburst size={220} data={storageData} used={stats.diskUsed} total={stats.diskTotal}/>
          </div>

          {/* Health Ring */}
          <div style={{textAlign:'center'}}>
            <div style={{fontSize:11, fontWeight:600, color:'var(--text-3)', textTransform:'uppercase', letterSpacing:'0.06em', marginBottom:10}}>Santé</div>
            <Ring size={200} stroke={12} value={stats.health} color="var(--accent)">
              <div>
                <div style={{fontSize:56, fontWeight:700, letterSpacing:'-0.04em', lineHeight:1}}>
                  <AnimatedNumber value={stats.health} format={v=>Math.round(v)}/>
                </div>
                <div style={{fontSize:11, color:'var(--text-3)', marginTop:2}}>sur 100</div>
              </div>
            </Ring>
            <div style={{marginTop:10, display:'flex', gap:6, justifyContent:'center', flexWrap:'wrap'}}>
              <StatusPill status="good">CPU</StatusPill>
              <StatusPill status="warn">Disque</StatusPill>
              <StatusPill status="good">Sécurité</StatusPill>
            </div>
          </div>

          {/* Mini stats */}
          <div style={{display:'flex', flexDirection:'column', gap:10}}>
            <MiniStat color="var(--accent)" icon="broom" label="Récupérables maintenant" value="18,4 Go" sub="caches, logs, apps dormantes" onClick={()=>goTo('cleanup')}/>
            <MiniStat color="#5E5CE6" icon="ram" label="Mémoire active" value="14,2 / 16 Go" sub="Chrome, Slack, Xcode" onClick={()=>goTo('maintenance')}/>
            <MiniStat color="#BF5AF2" icon="shield" label="Traceurs identifiés" value="2 348" sub="Safari, Chrome, Firefox" onClick={()=>goTo('privacy')}/>
            <MiniStat color="#FF9F0A" icon="bolt" label="Apps au démarrage" value="11 actives" sub="6 sont superflues" onClick={()=>goTo('maintenance')}/>
          </div>
        </div>
      </GlassPanel>

      {/* Weekly trend */}
      <div style={{display:'grid', gridTemplateColumns:'1.4fr 1fr', gap:12, marginBottom:14}}>
        <WeeklyTrend data={weekly}/>
        <GlassPanel style={{padding:'14px 18px', display:'flex', alignItems:'center', gap:14,
          background:'linear-gradient(135deg, rgba(0,217,163,0.10), rgba(0,217,163,0.02))',
          border:'0.5px solid rgba(0,217,163,0.3)'}}>
          <div style={{width:36, height:36, borderRadius:10, display:'grid', placeItems:'center',
            background:'rgba(0,217,163,0.18)', flexShrink:0}}>
            <Icon name="sparkle" size={18} color="var(--accent)"/>
          </div>
          <div style={{flex:1}}>
            <div style={{fontSize:11, fontWeight:600, letterSpacing:'0.06em', textTransform:'uppercase', color:'var(--text-3)'}}>Insight IA</div>
            <div style={{fontSize:13, marginTop:2, color:'var(--text-1)', lineHeight:1.4}}>
              <b>Boom.</b> 3 apps non ouvertes depuis 6+ mois. <b>4,2 Go</b> récupérables.
            </div>
          </div>
          <Btn kind="ghost" size="sm" onClick={openAI}>Voir</Btn>
        </GlassPanel>
      </div>

      {/* Module cards grid */}
      <div style={{display:'grid', gridTemplateColumns:'repeat(3, 1fr)', gap:12}}>
        <ModuleCard icon="broom" color="#FFB020" title="Fichiers inutiles"
          stat="18,4 Go" sub="Caches, logs, anciens téléchargements"
          onClick={()=>goTo('cleanup')}/>
        <ModuleCard icon="app" color="#0A84FF" title="Désinstalleur"
          stat="3 apps" sub="6+ mois sans ouvrir · 4,2 Go"
          onClick={()=>goTo('uninstaller')}/>
        <ModuleCard icon="disk" color="var(--accent)" title="Space Lens"
          stat="482 Go" sub="Carte interactive du disque"
          onClick={()=>goTo('spacelens')}/>
        <ModuleCard icon="shield" color="#FFB020" title="Sécurité"
          stat="3 anomalies" sub="Adware, traceurs, extension"
          onClick={()=>goTo('security')}/>
        <ModuleCard icon="arrow" color="#FF453A" title="Mises à jour"
          stat="7 apps" sub="1 patch sécurité · 1,2 Go"
          onClick={()=>goTo('updates')}/>
        <ModuleCard icon="bolt" color="#5E5CE6" title="Performance"
          stat="6 inutiles" sub="Éléments de connexion + agents"
          onClick={()=>goTo('optimize')}/>
        <ModuleCard icon="eye" color="#BF5AF2" title="Confidentialité"
          stat="2 348 traceurs" sub="Safari, Chrome, Firefox" onClick={()=>goTo('privacy')}/>
        <ModuleCard icon="files" color="#FF9F0A" title="Volumineux & doublons"
          stat="247 fichiers" sub="Plus de 50 Mo · 12 doublons" onClick={()=>goTo('files')}/>
        <ModuleCard icon="wrench" color="#34C759" title="Maintenance"
          stat="6 tâches" sub="Reindex, scripts, DNS" onClick={()=>goTo('maintenance')}/>
      </div>
    </div>
  );
}

function MiniStat({ icon, color, label, value, sub, onClick }) {
  const [hover, setHover] = React.useState(false);
  return (
    <div onClick={onClick}
      onMouseEnter={()=>setHover(true)} onMouseLeave={()=>setHover(false)}
      style={{
      display:'flex', alignItems:'center', gap:12, padding:'10px 12px', borderRadius:10,
      cursor:'default', transition:'background 120ms',
      background: hover ? 'rgba(0,0,0,0.04)' : 'transparent'
    }}>
      <div style={{width:30, height:30, borderRadius:8, background:`${color}22`, color,
        display:'grid', placeItems:'center', flexShrink:0}}>
        <Icon name={icon} size={15} color={color}/>
      </div>
      <div style={{flex:1, minWidth:0}}>
        <div style={{fontSize:11, color:'var(--text-3)', fontWeight:500}}>{label}</div>
        <div style={{fontSize:15, fontWeight:700, letterSpacing:'-0.015em', marginTop:1}}>{value}</div>
        <div style={{fontSize:11, color:'var(--text-3)'}}>{sub}</div>
      </div>
      <Icon name="chevron" size={13} color={hover?'var(--text-1)':'var(--text-3)'}/>
    </div>
  );
}

function StatCard({ icon, color, label, value, sub, pct, seg, cta, onCta }) {
  return (
    <GlassPanel style={{padding:'14px 16px', display:'flex', flexDirection:'column', justifyContent:'space-between'}}>
      <div style={{display:'flex', alignItems:'center', gap:10, marginBottom:8}}>
        <div style={{width:26, height:26, borderRadius:7, background:`${color}22`, display:'grid', placeItems:'center', color}}>
          <Icon name={icon} size={15} color={color}/>
        </div>
        <div style={{fontSize:12, fontWeight:600, color:'var(--text-2)', letterSpacing:'0.005em'}}>{label}</div>
        <div style={{flex:1}}/>
        {cta && <button onClick={onCta} style={{background:'transparent', border:0, color:'var(--accent)', fontSize:12, fontWeight:600, cursor:'default', padding:0}}>{cta}</button>}
      </div>
      <div style={{fontSize:20, fontWeight:700, letterSpacing:'-0.02em', marginBottom:8}}>{value}</div>
      {seg ? <SegBar segments={seg}/> : <HBar value={pct} color={color}/>}
      {sub && <div style={{fontSize:11.5, color:'var(--text-3)', marginTop:8}}>{sub}</div>}
    </GlassPanel>
  );
}

function ModuleCard({ icon, color, title, stat, sub, onClick }) {
  const [hover, setHover] = React.useState(false);
  return (
    <div onClick={onClick}
      onMouseEnter={()=>setHover(true)} onMouseLeave={()=>setHover(false)}
      style={{
      background:'var(--panel)', borderRadius:14, padding:'16px 18px',
      border:'0.5px solid var(--hairline)',
      boxShadow:'inset 0 1px 0 rgba(255,255,255,0.4)',
      cursor:'default', transition:'transform 160ms, box-shadow 160ms',
      transform: hover ? 'translateY(-2px)' : 'none',
      ...(hover ? {boxShadow:'inset 0 1px 0 rgba(255,255,255,0.4), 0 8px 24px rgba(0,0,0,0.08)'} : {})
    }}>
      <div style={{display:'flex', alignItems:'center', gap:10, marginBottom:14}}>
        <div style={{width:30, height:30, borderRadius:8, background:`${color}22`, display:'grid', placeItems:'center'}}>
          <Icon name={icon} size={17} color={color}/>
        </div>
        <div style={{fontSize:13.5, fontWeight:600}}>{title}</div>
        <div style={{flex:1}}/>
        <Icon name="arrow" size={15} color="var(--text-3)"/>
      </div>
      <div style={{fontSize:24, fontWeight:700, letterSpacing:'-0.02em'}}>{stat}</div>
      <div style={{fontSize:11.5, color:'var(--text-2)', marginTop:4}}>{sub}</div>
    </div>
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// 2. SMART SCAN (animated)
// ═══════════════════════════════════════════════════════════════════════════
function ScreenSmartScan({ ctx }) {
  const { setScanState, scanState, goTo } = ctx;
  const phases = [
    {label:'Caches utilisateur',  color:'#FFB020', icon:'broom',  done:0},
    {label:'Caches système',      color:'#FF9F0A', icon:'chip',   done:0},
    {label:'Logs & rapports',     color:'#FF453A', icon:'files',  done:0},
    {label:'Applications dormantes', color:'#0A84FF', icon:'app', done:0},
    {label:'Volumineux & doublons', color:'#BF5AF2', icon:'folder', done:0},
    {label:'Vie privée',          color:'#5E5CE6', icon:'eye',    done:0},
    {label:'Optimisations',       color:'var(--accent)', icon:'wrench', done:0},
  ];
  const [step, setStep] = React.useState(0);
  const [phaseProgress, setPhaseProgress] = React.useState(0);
  const [found, setFound] = React.useState(0);
  const [paused, setPaused] = React.useState(false);

  // simulated progression
  React.useEffect(() => {
    if (paused || step >= phases.length) return;
    if (phaseProgress >= 100) {
      const next = step + 1;
      setStep(next);
      setPhaseProgress(0);
      if (next >= phases.length) setScanState('done');
      return;
    }
    const id = setTimeout(() => {
      setPhaseProgress(p => Math.min(100, p + (4 + Math.random()*6)));
      setFound(f => f + Math.random() * 0.4);
    }, 70);
    return () => clearTimeout(id);
  }, [phaseProgress, step, paused]);

  const totalPct = ((step) / phases.length + (phaseProgress/100) / phases.length) * 100;
  const done = step >= phases.length;

  return (
    <div style={{display:'grid', gridTemplateColumns:'1fr 360px', gap:24, padding:'16px 4px 40px',
      minHeight:'calc(100vh - 200px)', maxWidth:1100, margin:'0 auto'}}>

      {/* Left: scan visual */}
      <div style={{display:'flex', flexDirection:'column', alignItems:'center', justifyContent:'center', position:'relative', padding:'40px 0'}}>
        <ScanVisual active={!done && !paused} accent={done ? '#34C759' : 'var(--accent)'}/>

        <div style={{marginTop:32, textAlign:'center'}}>
          <div style={{fontSize:12, fontWeight:600, letterSpacing:'0.08em', textTransform:'uppercase', color:'var(--text-3)'}}>
            {done ? 'Scan terminé' : (paused ? 'Pause' : phases[step]?.label || 'Préparation…')}
          </div>
          <div style={{fontSize:64, fontWeight:700, letterSpacing:'-0.035em', lineHeight:1, marginTop:8,
            background:'linear-gradient(135deg, var(--text-1), var(--text-2))', WebkitBackgroundClip:'text', WebkitTextFillColor:'transparent'}}>
            <AnimatedNumber value={found} format={v => `${v.toFixed(1)} Go`} duration={200}/>
          </div>
          <div style={{fontSize:14, color:'var(--text-2)', marginTop:6}}>
            {done
              ? <><b>Boom.</b> Récupérables sans rien casser.</>
              : <>récupérables jusqu'ici · <b>{Math.round(totalPct)}%</b></>}
          </div>
        </div>

        <div style={{marginTop:24, display:'flex', gap:10}}>
          {!done && (
            <Btn kind="secondary" icon={paused?'play':'pause'} onClick={()=>setPaused(p=>!p)}>
              {paused?'Reprendre':'Pause'}
            </Btn>
          )}
          {done ? (
            <>
              <Btn kind="primary" size="lg" icon="broom" onClick={()=>goTo('cleanup')}>Nettoyer maintenant</Btn>
              <Btn kind="ghost" onClick={()=>goTo('dashboard')}>Plus tard</Btn>
            </>
          ) : (
            <Btn kind="ghost" onClick={()=>goTo('dashboard')}>Annuler</Btn>
          )}
        </div>
      </div>

      {/* Right: phase list */}
      <GlassPanel style={{padding:'18px', alignSelf:'stretch'}}>
        <div style={{fontSize:11, fontWeight:600, letterSpacing:'0.08em', textTransform:'uppercase', color:'var(--text-3)', marginBottom:14}}>Catégories</div>
        <div style={{display:'flex', flexDirection:'column', gap:6}}>
          {phases.map((p, i) => {
            const state = i < step ? 'done' : (i === step ? 'active' : 'pending');
            const pct = i < step ? 100 : (i === step ? phaseProgress : 0);
            return (
              <div key={p.label} style={{
                padding:'10px 10px', borderRadius:10, display:'flex', alignItems:'center', gap:10,
                background: state==='active' ? 'rgba(0,217,163,0.08)' : 'transparent',
                transition:'background 200ms'
              }}>
                <div style={{width:26, height:26, borderRadius:7, background:`${p.color}22`, display:'grid', placeItems:'center', position:'relative'}}>
                  {state==='done'
                    ? <Icon name="check" size={15} color="#34C759"/>
                    : <Icon name={p.icon} size={14} color={p.color}/>
                  }
                </div>
                <div style={{flex:1, minWidth:0}}>
                  <div style={{fontSize:13, fontWeight:state==='active'?600:500, color: state==='pending' ? 'var(--text-3)' : 'var(--text-1)'}}>{p.label}</div>
                  <div style={{height:3, background:'var(--hairline-soft)', marginTop:6, borderRadius:999, overflow:'hidden'}}>
                    <div style={{height:'100%', width:`${pct}%`, background:state==='done'?'#34C759':'var(--accent)', borderRadius:999, transition:'width 200ms'}}/>
                  </div>
                </div>
              </div>
            );
          })}
        </div>
      </GlassPanel>
    </div>
  );
}

function ScanVisual({ active, accent }) {
  return (
    <div style={{position:'relative', width:320, height:320}}>
      <style>{`
        @keyframes scan-pulse{0%{transform:scale(0.5);opacity:0.7}100%{transform:scale(1.6);opacity:0}}
        @keyframes scan-rotate{from{transform:rotate(0)}to{transform:rotate(360deg)}}
        @keyframes scan-rotate-r{from{transform:rotate(0)}to{transform:rotate(-360deg)}}
        .scan-ring{position:absolute;inset:0;border-radius:50%;border:1px solid currentColor;opacity:0.15}
        .scan-pulse-1, .scan-pulse-2, .scan-pulse-3{position:absolute;inset:0;border-radius:50%;
          border:1.5px solid currentColor;animation:scan-pulse 2.4s ease-out infinite}
        .scan-pulse-2{animation-delay:.8s}
        .scan-pulse-3{animation-delay:1.6s}
        .scan-arc{position:absolute;inset:0;border-radius:50%;
          border:2px solid transparent;border-top-color:currentColor;
          animation:scan-rotate 2.4s linear infinite}
        .scan-arc-2{position:absolute;inset:32px;border-radius:50%;
          border:1.5px solid transparent;border-top-color:currentColor;border-right-color:currentColor;opacity:0.55;
          animation:scan-rotate-r 3.2s linear infinite}
        .scan-paused{animation-play-state:paused}
      `}</style>
      <div style={{color: accent, position:'absolute', inset:0}}>
        <div className="scan-ring"/>
        <div className="scan-ring" style={{inset:32}}/>
        <div className="scan-ring" style={{inset:64}}/>
        <div className="scan-ring" style={{inset:96}}/>
        {active && <>
          <div className="scan-pulse-1"/>
          <div className="scan-pulse-2"/>
          <div className="scan-pulse-3"/>
          <div className="scan-arc"/>
          <div className="scan-arc-2"/>
        </>}
        {/* core */}
        <div style={{position:'absolute', inset:0, display:'grid', placeItems:'center'}}>
          <div style={{
            width:88, height:88, borderRadius:'50%',
            background:`radial-gradient(circle, ${accent}, ${accent}AA)`,
            boxShadow:`0 0 60px ${accent}80, 0 0 120px ${accent}40`,
            display:'grid', placeItems:'center'
          }}>
            <CmpMark size={56} hue="mint" animated={active}/>
          </div>
        </div>
      </div>
    </div>
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// 3. CLEANUP (System Junk) — split list with detail panel
// ═══════════════════════════════════════════════════════════════════════════
function ScreenCleanup({ ctx }) {
  const cats = React.useMemo(() => ([
    { id:'user-cache',   icon:'broom', color:'#FFB020', label:'Caches utilisateur', size:6.8,
      sub:'Spotify, Slack, Xcode, Photoshop…',
      items:[
        {app:'Xcode', detail:'DerivedData', size:3.2},
        {app:'Spotify', detail:'media-cache', size:1.4},
        {app:'Slack', detail:'Cache + Service Workers', size:0.9},
        {app:'Adobe Photoshop', detail:'Caches d\'historique', size:0.7},
        {app:'Chrome', detail:'GPUCache', size:0.6},
      ]},
    { id:'sys-cache',    icon:'chip', color:'#FF9F0A', label:'Caches système', size:3.1,
      sub:'CoreData, fontes, mises à jour', items:[
        {app:'Mises à jour macOS', detail:'Téléchargements terminés', size:1.8},
        {app:'CoreData', detail:'Bases temporaires', size:0.7},
        {app:'Fontes', detail:'Caches inactifs', size:0.4},
        {app:'iCloud', detail:'Caches de sync', size:0.2},
      ]},
    { id:'logs',         icon:'files', color:'#FF453A', label:'Logs & rapports', size:0.9,
      sub:'Diagnostiques, crashs, install', items:[
        {app:'Rapports de crash', detail:'~/Library/Logs/DiagnosticReports', size:0.42},
        {app:'Logs d\'installation', detail:'install.log', size:0.28},
        {app:'Logs Console', detail:'Activité utilisateur', size:0.20},
      ]},
    { id:'mail',         icon:'files', color:'#5E5CE6', label:'Pièces jointes Mail', size:4.1,
      sub:'Téléchargées, encore sur le serveur', items:[
        {app:'Mail.app', detail:'Pièces jointes 2024', size:2.4},
        {app:'Mail.app', detail:'Pièces jointes 2023', size:1.7},
      ]},
    { id:'trash',        icon:'trash', color:'#8E8E93', label:'Corbeilles', size:2.3,
      sub:'Corbeille principale + corbeilles d\'apps', items:[
        {app:'Corbeille macOS', detail:'47 éléments', size:1.9},
        {app:'Photos.app', detail:'Récemment supprimés', size:0.4},
      ]},
    { id:'downloads',    icon:'folder', color:'#BF5AF2', label:'Téléchargements anciens', size:1.2,
      sub:'.dmg et .zip de plus de 30 jours', items:[
        {app:'~/Downloads', detail:'13 installeurs .dmg', size:0.9},
        {app:'~/Downloads', detail:'4 archives .zip', size:0.3},
      ]},
  ]), []);

  const [selected, setSelected] = React.useState('user-cache');
  const [checks, setChecks] = React.useState(()=> Object.fromEntries(cats.map(c => [c.id, true])));
  const [itemChecks, setItemChecks] = React.useState({});

  const selCat = cats.find(c=>c.id===selected);
  const totalSelected = cats.reduce((s,c) => s + (checks[c.id] ? c.size : 0), 0);

  return (
    <div style={{padding:'8px 4px 40px', maxWidth:1100, margin:'0 auto'}}>
      <ScreenHeader kicker="Nettoyage" title="Fichiers inutiles"
        subtitle="Ce que ton Mac garde dans les coins et que tu peux jeter sans rien casser."
        right={
          <div style={{display:'flex', alignItems:'center', gap:14}}>
            <div style={{textAlign:'right'}}>
              <div style={{fontSize:11, color:'var(--text-3)', textTransform:'uppercase', letterSpacing:'0.06em', fontWeight:600}}>À supprimer</div>
              <div style={{fontSize:22, fontWeight:700, letterSpacing:'-0.02em', color:'var(--accent)'}}>
                <AnimatedNumber value={totalSelected} format={v=>`${v.toFixed(1)} Go`}/>
              </div>
            </div>
            <Btn kind="primary" size="lg" icon="broom" onClick={()=>ctx.goTo('result')}>Nettoyer</Btn>
          </div>
        }/>

      <div style={{display:'grid', gridTemplateColumns:'1fr 1fr', gap:16}}>
        <GlassPanel style={{padding:8}}>
          {cats.map(c => (
            <CategoryRow key={c.id} icon={c.icon} color={c.color} label={c.label}
              sub={c.sub} size={`${c.size.toFixed(1)} Go`}
              checked={!!checks[c.id]} onCheck={v => setChecks(s=>({...s, [c.id]:v}))}
              expanded={selected===c.id} onClick={()=>setSelected(c.id)}/>
          ))}
        </GlassPanel>

        <GlassPanel style={{padding:'18px 20px'}}>
          <div style={{display:'flex', alignItems:'center', gap:10, marginBottom:14}}>
            <div style={{width:34, height:34, borderRadius:9, background:`${selCat.color}22`, display:'grid', placeItems:'center'}}>
              <Icon name={selCat.icon} size={18} color={selCat.color}/>
            </div>
            <div>
              <div style={{fontSize:16, fontWeight:700, letterSpacing:'-0.01em'}}>{selCat.label}</div>
              <div style={{fontSize:12, color:'var(--text-2)'}}>{selCat.sub}</div>
            </div>
            <div style={{flex:1}}/>
            <div style={{textAlign:'right'}}>
              <div style={{fontSize:18, fontWeight:700, letterSpacing:'-0.01em'}}>{selCat.size.toFixed(1)} Go</div>
              <div style={{fontSize:11, color:'var(--text-3)'}}>{selCat.items.length} sous-éléments</div>
            </div>
          </div>

          {/* Transparency note */}
          <div style={{padding:'10px 12px', borderRadius:10, background:'rgba(10,132,255,0.08)',
            border:'0.5px solid rgba(10,132,255,0.18)', marginBottom:14,
            display:'flex', gap:10, alignItems:'flex-start'}}>
            <Icon name="info" size={15} color="#0A84FF"/>
            <div style={{fontSize:12, color:'var(--text-2)', lineHeight:1.5}}>
              <b style={{color:'var(--text-1)'}}>Sans risque.</b> Ces fichiers sont recréés à la demande par macOS et tes apps. CleanMac Pro ne touche jamais aux Documents, à Photos ni à iCloud.
            </div>
          </div>

          <div style={{display:'flex', flexDirection:'column', gap:4}}>
            {selCat.items.map((it, i) => {
              const key = `${selCat.id}-${i}`;
              const cv = itemChecks[key] ?? true;
              return (
                <div key={key} style={{
                  display:'flex', alignItems:'center', gap:10, padding:'9px 8px', borderRadius:8,
                  background: i%2===0 ? 'transparent' : 'rgba(0,0,0,0.02)'
                }}>
                  <Check checked={cv} onChange={v => setItemChecks(s => ({...s, [key]:v}))}/>
                  <div style={{flex:1, minWidth:0}}>
                    <div style={{fontSize:13, fontWeight:600}}>{it.app}</div>
                    <div style={{fontSize:11.5, color:'var(--text-3)', fontFamily:'ui-monospace, "SF Mono", monospace'}}>{it.detail}</div>
                  </div>
                  <div style={{fontSize:13, fontWeight:600, fontVariantNumeric:'tabular-nums'}}>{fmtBytes(it.size)}</div>
                </div>
              );
            })}
          </div>
        </GlassPanel>
      </div>
    </div>
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// 4. UNINSTALLER — grid of apps with selection
// ═══════════════════════════════════════════════════════════════════════════
function ScreenUninstaller({ ctx }) {
  const apps = [
    {name:'Final Cut Pro', glyph:'FC', color:'#FF3B30', size:3.4, lastUsed:'il y a 9 mois', leftovers:'~/Library/Application Support/com.apple.FinalCut', dormant:true},
    {name:'Microsoft Word', glyph:'W', color:'#2B579A', size:2.1, lastUsed:'il y a 7 mois', leftovers:'12 fichiers résiduels — 240 Mo', dormant:true},
    {name:'Adobe XD', glyph:'Xd', color:'#FF61F6', size:1.8, lastUsed:'il y a 1 an', leftovers:'Caches Creative Cloud — 320 Mo', dormant:true},
    {name:'Skype', glyph:'S', color:'#00AFF0', size:0.4, lastUsed:'il y a 2 ans', leftovers:'~/Library/Caches/com.skype', dormant:true},
    {name:'Slack', glyph:'#', color:'#4A154B', size:0.9, lastUsed:'aujourd\'hui', dormant:false},
    {name:'Figma', glyph:'F', color:'#0ACF83', size:0.6, lastUsed:'hier', dormant:false},
    {name:'Visual Studio Code', glyph:'VS', color:'#007ACC', size:0.5, lastUsed:'aujourd\'hui', dormant:false},
    {name:'Spotify', glyph:'♪', color:'#1DB954', size:0.4, lastUsed:'aujourd\'hui', dormant:false},
    {name:'Chrome', glyph:'C', color:'#4285F4', size:0.7, lastUsed:'aujourd\'hui', dormant:false},
    {name:'Notion', glyph:'N', color:'#000', size:0.35, lastUsed:'aujourd\'hui', dormant:false},
    {name:'Discord', glyph:'D', color:'#5865F2', size:0.42, lastUsed:'hier', dormant:false},
    {name:'Zoom', glyph:'Z', color:'#2D8CFF', size:0.5, lastUsed:'il y a 3 jours', dormant:false},
  ];
  const [selected, setSelected] = React.useState(new Set(['Final Cut Pro', 'Adobe XD', 'Skype']));
  const [filter, setFilter] = React.useState('all'); // all | dormant
  const view = apps.filter(a => filter==='all' || a.dormant);
  const sel = view.filter(a => selected.has(a.name));
  const total = sel.reduce((s,a)=>s+a.size, 0);

  return (
    <div style={{padding:'8px 4px 40px', maxWidth:1100, margin:'0 auto'}}>
      <ScreenHeader kicker="Applications" title="Désinstalleur"
        subtitle="Supprime une app et tous ses résidus en une fois. Pas de fichiers fantômes."
        right={
          <div style={{display:'flex', gap:8, alignItems:'center'}}>
            <Btn kind={filter==='all'?'secondary':'ghost'} size="sm" onClick={()=>setFilter('all')}>Toutes</Btn>
            <Btn kind={filter==='dormant'?'secondary':'ghost'} size="sm" onClick={()=>setFilter('dormant')}>Dormantes <span style={{opacity:.55, marginLeft:4}}>{apps.filter(a=>a.dormant).length}</span></Btn>
          </div>
        }/>

      <div style={{display:'grid', gridTemplateColumns:'repeat(4, 1fr)', gap:12, marginBottom:90}}>
        {view.map(app => {
          const isSel = selected.has(app.name);
          return (
            <div key={app.name} onClick={()=>{
              setSelected(s => { const n = new Set(s); if (n.has(app.name)) n.delete(app.name); else n.add(app.name); return n; });
            }} style={{
              background: isSel ? 'rgba(0,217,163,0.10)' : 'var(--panel)',
              border: isSel ? '1px solid var(--accent)' : '0.5px solid var(--hairline)',
              borderRadius:14, padding:'14px 14px', cursor:'default', position:'relative',
              transition:'background 160ms, border-color 160ms, transform 120ms',
              transform: isSel ? 'scale(1.0)' : 'scale(1.0)'
            }}>
              <div style={{display:'flex', alignItems:'center', gap:10, marginBottom:10}}>
                <div style={{width:42, height:42, borderRadius:10, background:app.color,
                  display:'grid', placeItems:'center', color:'#fff', fontWeight:700, fontSize:16,
                  boxShadow:'0 2px 6px rgba(0,0,0,0.12), inset 0 1px 0 rgba(255,255,255,0.2)'}}>
                  {app.glyph}
                </div>
                <div style={{flex:1, minWidth:0}}>
                  <div style={{fontSize:13.5, fontWeight:600, whiteSpace:'nowrap', overflow:'hidden', textOverflow:'ellipsis'}}>{app.name}</div>
                  <div style={{fontSize:11, color:'var(--text-3)'}}>{app.size.toFixed(2)} Go</div>
                </div>
                <Check checked={isSel} onChange={()=>{
                  setSelected(s => { const n = new Set(s); if (n.has(app.name)) n.delete(app.name); else n.add(app.name); return n; });
                }}/>
              </div>
              <div style={{fontSize:11.5, color: app.dormant ? 'var(--warn)':'var(--text-3)'}}>
                {app.dormant ? '⊘ ' : '↻ '}{app.lastUsed}
              </div>
              {app.dormant && app.leftovers && (
                <div style={{fontSize:11, color:'var(--text-3)', marginTop:6, fontFamily:'ui-monospace, "SF Mono", monospace',
                  whiteSpace:'nowrap', overflow:'hidden', textOverflow:'ellipsis'}}>
                  {app.leftovers}
                </div>
              )}
            </div>
          );
        })}
      </div>

      {/* Sticky action bar */}
      {sel.length > 0 && (
        <div style={{
          position:'sticky', bottom:0, marginTop:-70, marginBottom:0,
          background:'rgba(28,28,32,0.92)', color:'#fff', backdropFilter:'blur(20px)',
          borderRadius:14, padding:'12px 16px', display:'flex', alignItems:'center', gap:14,
          boxShadow:'0 12px 40px rgba(0,0,0,0.3)'
        }}>
          <div style={{display:'flex', alignItems:'center', gap:-8}}>
            {sel.slice(0,4).map((a,i) => (
              <div key={a.name} style={{
                width:30, height:30, borderRadius:8, background:a.color, marginLeft:i>0?-8:0,
                border:'2px solid #1c1c20',
                display:'grid', placeItems:'center', color:'#fff', fontWeight:700, fontSize:12
              }}>{a.glyph}</div>
            ))}
            {sel.length > 4 && <div style={{marginLeft:-8, width:30, height:30, borderRadius:8, background:'#48484a',
              border:'2px solid #1c1c20', display:'grid', placeItems:'center', fontSize:11, fontWeight:600}}>+{sel.length-4}</div>}
          </div>
          <div style={{flex:1}}>
            <div style={{fontSize:13, fontWeight:600}}>{sel.length} apps + résidus</div>
            <div style={{fontSize:11.5, opacity:0.6}}>Récupère <b style={{color:'var(--accent)'}}>{total.toFixed(1)} Go</b></div>
          </div>
          <Btn kind="ghost" onClick={()=>setSelected(new Set())} style={{color:'#fff', opacity:.7}}>Annuler</Btn>
          <Btn kind="primary" icon="trash">Désinstaller {sel.length}</Btn>
        </div>
      )}
    </div>
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// 5. LARGE FILES & DUPLICATES
// ═══════════════════════════════════════════════════════════════════════════
function ScreenFiles({ ctx }) {
  const [tab, setTab] = React.useState('large');
  const large = [
    {name:'projet-2024-final.psd', path:'~/Documents/Design', size:2.4, age:'il y a 3 mois', kind:'PSD', color:'#31A8FF'},
    {name:'conference-keynote.mov', path:'~/Movies', size:1.8, age:'il y a 6 mois', kind:'MOV', color:'#FF453A'},
    {name:'IMG_archive_2022.zip', path:'~/Downloads', size:1.2, age:'il y a 1 an', kind:'ZIP', color:'#8E8E93'},
    {name:'macOS-Sonoma.dmg', path:'~/Downloads', size:11.6, age:'il y a 8 mois', kind:'DMG', color:'#34C759'},
    {name:'backup-iphone-2023.ipsw', path:'~/Library/iTunes', size:5.1, age:'il y a 1 an', kind:'IPSW', color:'#0A84FF'},
    {name:'tutoriel-blender.mp4', path:'~/Movies/Cours', size:3.4, age:'il y a 4 mois', kind:'MP4', color:'#FF9F0A'},
    {name:'thesis-draft-v12.indd', path:'~/Documents/Thèse', size:0.9, age:'il y a 2 ans', kind:'INDD', color:'#FF3B30'},
  ];
  const dupes = [
    {name:'IMG_4523.HEIC', count:3, size:0.012*3, paths:['~/Pictures','~/Desktop','~/Downloads'], color:'#BF5AF2'},
    {name:'Capture d\'écran 2024-03-14.png', count:4, size:0.008*4, paths:['~/Desktop','~/Documents','~/Desktop/old','~/Downloads'], color:'#5E5CE6'},
    {name:'CV-claude-2024.pdf', count:5, size:0.4*5, paths:['~/Documents','~/Desktop','~/Downloads','~/Documents/old','iCloud'], color:'#FF453A'},
    {name:'logo.svg', count:2, size:0.0006*2, paths:['~/Projects/site','~/Projects/site/backup'], color:'#0A84FF'},
    {name:'song-final.mp3', count:3, size:0.012*3, paths:['~/Music','~/Music/backup','~/Downloads'], color:'#FFB020'},
  ];
  const [selL, setSelL] = React.useState(new Set([large[3].name, large[4].name]));
  const [selD, setSelD] = React.useState(new Set([dupes[0].name, dupes[1].name, dupes[2].name]));
  const items = tab==='large' ? large : dupes;
  const sel = tab==='large' ? selL : selD;
  const setSel = tab==='large' ? setSelL : setSelD;
  const total = items.filter(it => sel.has(it.name)).reduce((s,it)=>s+it.size,0);

  return (
    <div style={{padding:'8px 4px 40px', maxWidth:1100, margin:'0 auto'}}>
      <ScreenHeader kicker="Stockage" title="Volumineux & doublons"
        subtitle="Les plus gros fichiers que tu n'as pas ouverts depuis longtemps — et les copies multiples qui dorment."
        right={
          <div style={{display:'flex', alignItems:'center', gap:14}}>
            <div style={{textAlign:'right'}}>
              <div style={{fontSize:11, color:'var(--text-3)', textTransform:'uppercase', letterSpacing:'0.06em', fontWeight:600}}>Sélection</div>
              <div style={{fontSize:22, fontWeight:700, letterSpacing:'-0.02em', color:'var(--accent)'}}>
                <AnimatedNumber value={total} format={v=>`${v.toFixed(2)} Go`}/>
              </div>
            </div>
            <Btn kind="primary" size="lg" icon="trash">Supprimer</Btn>
          </div>
        }/>

      <div style={{display:'flex', gap:4, marginBottom:14, padding:3, background:'rgba(0,0,0,0.05)', borderRadius:9, width:'fit-content'}}>
        {[['large','Volumineux', large.length], ['dup','Doublons exacts', dupes.length]].map(([k,l,c]) => (
          <button key={k} onClick={()=>setTab(k)} style={{
            padding:'6px 14px', borderRadius:7, border:0, cursor:'default',
            background: tab===k ? 'var(--window-bg-solid)' : 'transparent',
            boxShadow: tab===k ? '0 1px 2px rgba(0,0,0,0.06)' : 'none',
            fontSize:12.5, fontWeight:600, color:tab===k?'var(--text-1)':'var(--text-2)'
          }}>{l} <span style={{opacity:.55, marginLeft:4}}>{c}</span></button>
        ))}
      </div>

      <GlassPanel style={{padding:0, overflow:'hidden'}}>
        {/* table header */}
        <div style={{display:'grid', gridTemplateColumns:'40px 2fr 1fr 0.6fr 1fr', padding:'10px 16px',
          fontSize:11, fontWeight:600, color:'var(--text-3)', textTransform:'uppercase', letterSpacing:'0.06em',
          borderBottom:'0.5px solid var(--hairline)'}}>
          <div></div>
          <div>Fichier</div>
          <div>{tab==='large'?'Dernier accès':'Emplacements'}</div>
          <div style={{textAlign:'right'}}>Taille</div>
          <div></div>
        </div>
        {items.map((it, i) => {
          const checked = sel.has(it.name);
          return (
            <div key={it.name} style={{
              display:'grid', gridTemplateColumns:'40px 2fr 1fr 0.6fr 1fr',
              padding:'12px 16px', alignItems:'center', gap:12,
              borderTop: i>0?'0.5px solid var(--hairline-soft)':'none',
              background: checked ? 'rgba(0,217,163,0.04)' : 'transparent'
            }}>
              <Check checked={checked} onChange={()=>{
                setSel(s => { const n = new Set(s); if (n.has(it.name)) n.delete(it.name); else n.add(it.name); return n; });
              }}/>
              <div style={{display:'flex', alignItems:'center', gap:12, minWidth:0}}>
                <div style={{width:36, height:36, borderRadius:8, background:`${it.color}22`, color:it.color,
                  display:'grid', placeItems:'center', fontWeight:700, fontSize:10, letterSpacing:'0.02em'}}>
                  {tab==='large' ? it.kind : `×${it.count}`}
                </div>
                <div style={{minWidth:0}}>
                  <div style={{fontSize:13.5, fontWeight:600, whiteSpace:'nowrap', overflow:'hidden', textOverflow:'ellipsis'}}>{it.name}</div>
                  <div style={{fontSize:11, color:'var(--text-3)', fontFamily:'ui-monospace, "SF Mono", monospace',
                    whiteSpace:'nowrap', overflow:'hidden', textOverflow:'ellipsis'}}>{tab==='large'?it.path:it.paths.join(' · ')}</div>
                </div>
              </div>
              <div style={{fontSize:12, color:'var(--text-2)'}}>{tab==='large'?it.age:`${it.count} copies`}</div>
              <div style={{fontSize:13.5, fontWeight:600, fontVariantNumeric:'tabular-nums', textAlign:'right'}}>{fmtBytes(it.size, 2)}</div>
              <div style={{display:'flex', justifyContent:'flex-end', gap:6}}>
                <button style={{background:'transparent', border:0, color:'var(--text-3)', fontSize:11.5, cursor:'default'}}>Aperçu</button>
                <button style={{background:'transparent', border:0, color:'var(--text-3)', fontSize:11.5, cursor:'default'}}>Révéler</button>
              </div>
            </div>
          );
        })}
      </GlassPanel>
    </div>
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// 6. PRIVACY
// ═══════════════════════════════════════════════════════════════════════════
function ScreenPrivacy({ ctx }) {
  const browsers = [
    {name:'Safari', color:'#0FB5EE', glyph:'S', data:{cookies:842, history:1248, autofill:34, downloads:67}},
    {name:'Chrome', color:'#4285F4', glyph:'C', data:{cookies:1304, history:3210, autofill:88, downloads:142}},
    {name:'Firefox', color:'#FF7139', glyph:'F', data:{cookies:202, history:580, autofill:12, downloads:18}},
  ];
  const [bookmarks, setBookmarks] = React.useState({});
  const [cats, setCats] = React.useState(()=> {
    const o = {};
    browsers.forEach(b => { o[b.name] = {cookies:true, history:true, autofill:false, downloads:false} });
    return o;
  });
  const totals = browsers.reduce((acc,b)=>{
    Object.keys(b.data).forEach(k => { if (cats[b.name][k]) acc += b.data[k]; });
    return acc;
  }, 0);

  return (
    <div style={{padding:'8px 4px 40px', maxWidth:1100, margin:'0 auto'}}>
      <ScreenHeader kicker="Confidentialité" title="Efface tes traces"
        subtitle="2 348 traceurs et cookies tiers retrouvés sur 3 navigateurs. CleanMac Pro ne lit jamais le contenu."
        right={
          <div style={{display:'flex', alignItems:'center', gap:14}}>
            <div style={{textAlign:'right'}}>
              <div style={{fontSize:11, color:'var(--text-3)', textTransform:'uppercase', letterSpacing:'0.06em', fontWeight:600}}>À effacer</div>
              <div style={{fontSize:22, fontWeight:700, letterSpacing:'-0.02em', color:'var(--accent)'}}>{totals.toLocaleString('fr-FR')} <span style={{fontSize:13, color:'var(--text-2)', fontWeight:500}}>éléments</span></div>
            </div>
            <Btn kind="primary" size="lg" icon="shield">Effacer</Btn>
          </div>
        }/>

      <div style={{display:'grid', gridTemplateColumns:'repeat(3,1fr)', gap:12}}>
        {browsers.map(b => (
          <GlassPanel key={b.name} style={{padding:'16px 18px'}}>
            <div style={{display:'flex', alignItems:'center', gap:10, marginBottom:14}}>
              <div style={{width:36, height:36, borderRadius:9, background:b.color, color:'#fff',
                display:'grid', placeItems:'center', fontWeight:700, fontSize:15}}>{b.glyph}</div>
              <div style={{fontSize:15, fontWeight:700, letterSpacing:'-0.01em'}}>{b.name}</div>
            </div>
            <div style={{display:'flex', flexDirection:'column', gap:8}}>
              {[
                {k:'cookies', label:'Cookies', icon:'cookie'},
                {k:'history', label:'Historique', icon:'eye'},
                {k:'autofill', label:'Saisie auto', icon:'info'},
                {k:'downloads', label:'Téléchargements', icon:'folder'},
              ].map(row => (
                <div key={row.k} style={{display:'flex', alignItems:'center', gap:10, padding:'4px 0'}}>
                  <Icon name={row.icon} size={15} color="var(--text-2)"/>
                  <div style={{fontSize:13, fontWeight:500, flex:1}}>{row.label}</div>
                  <div style={{fontSize:12, color:'var(--text-3)', fontVariantNumeric:'tabular-nums'}}>{b.data[row.k].toLocaleString('fr-FR')}</div>
                  <Toggle value={cats[b.name][row.k]} onChange={v=>setCats(s=>({...s, [b.name]:{...s[b.name],[row.k]:v}}))}/>
                </div>
              ))}
            </div>
          </GlassPanel>
        ))}
      </div>

      <div style={{marginTop:16, display:'grid', gridTemplateColumns:'1fr 1fr', gap:12}}>
        <GlassPanel style={{padding:'18px 20px'}}>
          <div style={{display:'flex', alignItems:'center', gap:10, marginBottom:14}}>
            <Icon name="shield" size={18} color="#BF5AF2"/>
            <div style={{fontSize:14, fontWeight:700}}>Trackers détectés</div>
            <div style={{flex:1}}/>
            <div style={{fontSize:22, fontWeight:700, color:'#BF5AF2', letterSpacing:'-0.02em'}}>2 348</div>
          </div>
          {[
            {name:'Google Ads', count:842, pct:36},
            {name:'Meta Pixel', count:612, pct:26},
            {name:'TikTok Pixel', count:340, pct:14},
            {name:'Hotjar', count:218, pct:9},
            {name:'Autres (28)', count:336, pct:15},
          ].map(t => (
            <div key={t.name} style={{marginTop:8}}>
              <div style={{display:'flex', justifyContent:'space-between', fontSize:12.5, marginBottom:3}}>
                <span>{t.name}</span>
                <span style={{color:'var(--text-3)'}}>{t.count}</span>
              </div>
              <HBar value={t.pct} color="#BF5AF2"/>
            </div>
          ))}
        </GlassPanel>
        <GlassPanel style={{padding:'18px 20px'}}>
          <div style={{display:'flex', alignItems:'center', gap:10, marginBottom:6}}>
            <Icon name="eye" size={18} color="var(--accent)"/>
            <div style={{fontSize:14, fontWeight:700}}>Activité récente du système</div>
          </div>
          <div style={{fontSize:12, color:'var(--text-2)', marginBottom:12}}>Ce que macOS a indexé sur toi cette semaine.</div>
          {[
            {label:'Documents ouverts', count:142},
            {label:'Apps lancées', count:38},
            {label:'Connexions Wi-Fi', count:7},
            {label:'Permissions caméra', count:'3 apps'},
            {label:'Permissions micro', count:'5 apps'},
          ].map((row,i) => (
            <div key={row.label} style={{display:'flex', alignItems:'center', justifyContent:'space-between',
              padding:'10px 0', borderTop: i>0?'0.5px solid var(--hairline-soft)':'none'}}>
              <span style={{fontSize:13}}>{row.label}</span>
              <span style={{fontSize:13, fontWeight:600, color:'var(--text-2)'}}>{row.count}</span>
            </div>
          ))}
        </GlassPanel>
      </div>
    </div>
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// 7. MAINTENANCE
// ═══════════════════════════════════════════════════════════════════════════
function ScreenMaintenance({ ctx }) {
  const tasks = [
    {id:'scripts', icon:'wrench', color:'#5E5CE6', name:'Scripts de maintenance macOS', desc:'Daily, weekly, monthly — comme cron, mais propre.', danger:'safe', est:'12 s'},
    {id:'ram',     icon:'ram',    color:'#0A84FF', name:'Libérer la RAM inactive', desc:'Force la purge des pages non utilisées.', danger:'safe', est:'4 s'},
    {id:'spot',    icon:'search', color:'#BF5AF2', name:'Réindexer Spotlight', desc:'Pour quand la recherche ne trouve plus rien.', danger:'long', est:'20 min'},
    {id:'dns',     icon:'network',color:'#FFB020', name:'Vider le cache DNS', desc:'Force macOS à re-résoudre les noms de domaine.', danger:'safe', est:'2 s'},
    {id:'mail',    icon:'files',  color:'#FF453A', name:'Reconstruire la boîte Mail', desc:'Répare l\'index des messages quand Mail rame.', danger:'long', est:'5 min'},
    {id:'trim',    icon:'disk',   color:'var(--accent)', name:'TRIM du SSD', desc:'Optimise l\'écriture sur le SSD interne.', danger:'safe', est:'8 s'},
    {id:'verify',  icon:'shield', color:'#34C759', name:'Vérifier les autorisations disque', desc:'Restaure les permissions modifiées par les apps.', danger:'safe', est:'30 s'},
  ];
  const [enabled, setEnabled] = React.useState({scripts:true, ram:true, dns:true, trim:true, verify:true, spot:false, mail:false});
  const [running, setRunning] = React.useState(null);
  const [done, setDone] = React.useState(new Set());

  const runAll = () => {
    const queue = tasks.filter(t => enabled[t.id]).map(t => t.id);
    setDone(new Set());
    let i = 0;
    const next = () => {
      if (i >= queue.length) { setRunning(null); return; }
      setRunning(queue[i]);
      setTimeout(() => {
        setDone(s => new Set([...s, queue[i]]));
        i++;
        next();
      }, 800 + Math.random()*600);
    };
    next();
  };

  const totalEnabled = Object.values(enabled).filter(Boolean).length;

  return (
    <div style={{padding:'8px 4px 40px', maxWidth:980, margin:'0 auto'}}>
      <ScreenHeader kicker="Optimisation" title="Maintenance"
        subtitle="Les petites tâches que macOS oublie de faire. Aucun risque, juste plus de vitesse."
        right={
          <div style={{display:'flex', gap:10, alignItems:'center'}}>
            <div style={{fontSize:13, color:'var(--text-2)'}}>{totalEnabled} tâches</div>
            <Btn kind="primary" size="lg" icon="bolt" disabled={!!running} onClick={runAll}>
              {running ? 'En cours…' : 'Lancer maintenant'}
            </Btn>
          </div>
        }/>

      <GlassPanel style={{padding:8}}>
        {tasks.map((t,i) => {
          const isRun = running===t.id;
          const isDone = done.has(t.id);
          return (
            <div key={t.id} style={{
              display:'flex', alignItems:'center', gap:14, padding:'12px 12px',
              borderTop: i>0?'0.5px solid var(--hairline-soft)':'none',
              opacity: enabled[t.id] ? 1 : 0.55
            }}>
              <div style={{width:36, height:36, borderRadius:9, background:`${t.color}22`, color:t.color,
                display:'grid', placeItems:'center', position:'relative'}}>
                {isDone ? <Icon name="check" size={18} color="#34C759"/> : <Icon name={t.icon} size={17} color={t.color}/>}
                {isRun && <div style={{position:'absolute', inset:-3, borderRadius:12,
                  border:'2px solid var(--accent)', borderTopColor:'transparent', animation:'spin 0.9s linear infinite'}}/>}
              </div>
              <div style={{flex:1, minWidth:0}}>
                <div style={{display:'flex', alignItems:'center', gap:8}}>
                  <span style={{fontSize:13.5, fontWeight:600}}>{t.name}</span>
                  {t.danger==='long' && <StatusPill status="warn">Long</StatusPill>}
                  {isDone && <StatusPill status="good">Fait</StatusPill>}
                </div>
                <div style={{fontSize:12, color:'var(--text-2)', marginTop:2}}>{t.desc}</div>
              </div>
              <div style={{fontSize:12, color:'var(--text-3)', fontVariantNumeric:'tabular-nums'}}>~{t.est}</div>
              <Toggle value={enabled[t.id]} onChange={v=>setEnabled(s=>({...s,[t.id]:v}))}/>
            </div>
          );
        })}
      </GlassPanel>

      <style>{`@keyframes spin{to{transform:rotate(360deg)}}`}</style>
    </div>
  );
}

Object.assign(window, {
  ScreenDashboard, ScreenSmartScan, ScreenCleanup, ScreenUninstaller,
  ScreenFiles, ScreenPrivacy, ScreenMaintenance
});
