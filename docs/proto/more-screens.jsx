// more-screens.jsx — Sécurité, Mises à jour, Optimisation, Space Lens

// ═══════════════════════════════════════════════════════════════════════════
// 8. SÉCURITÉ — anti-malware, profils, autorisations suspectes
// ═══════════════════════════════════════════════════════════════════════════
function ScreenSecurity({ ctx }) {
  const [scanning, setScanning] = React.useState(false);
  const [scanProgress, setScanProgress] = React.useState(100); // 100 = done
  const threats = [
    {id:'t1', kind:'adware', name:'GenericAdware.Profile', severity:'high',
      path:'/Library/Managed Preferences/com.adware.config.plist',
      desc:'Profil de configuration tiers injecté sans ton accord.',
      action:'Supprimer le profil'},
    {id:'t2', kind:'tracker', name:'Pixel de suivi persistant', severity:'medium',
      path:'~/Library/Application Support/Microsoft/Edge/Trackers',
      desc:'Maintient un identifiant unique entre les sessions.',
      action:'Bloquer + nettoyer'},
    {id:'t3', kind:'extension', name:'Extension Chrome inconnue', severity:'medium',
      path:'Chrome / "Cashback Helper Pro"',
      desc:'Demande accès à toutes les pages. Éditeur non vérifié.',
      action:'Désactiver'},
  ];

  const checks = [
    {label:'Antivirus signatures', status:'good', sub:'Base à jour il y a 3h'},
    {label:'Pare-feu macOS', status:'good', sub:'Actif · 0 connexion suspecte'},
    {label:'FileVault', status:'good', sub:'Disque chiffré'},
    {label:'Gatekeeper', status:'good', sub:'Apps signées uniquement'},
    {label:'Mode Lockdown', status:'info', sub:'Inactif (mode standard)'},
  ];

  React.useEffect(() => {
    if (!scanning) return;
    setScanProgress(0);
    const id = setInterval(() => {
      setScanProgress(p => {
        const n = p + 3 + Math.random()*4;
        if (n >= 100) { clearInterval(id); setScanning(false); return 100; }
        return n;
      });
    }, 80);
    return () => clearInterval(id);
  }, [scanning]);

  return (
    <div style={{padding:'8px 4px 40px', maxWidth:1100, margin:'0 auto'}}>
      <ScreenHeader kicker="Sécurité" title="Aucune menace active."
        subtitle="3 anomalies détectées au dernier scan. Tout est sous contrôle."
        right={
          <Btn kind="primary" size="lg" icon="shield" disabled={scanning}
            onClick={()=>setScanning(true)}>
            {scanning ? `Scan… ${Math.round(scanProgress)}%` : 'Scanner maintenant'}
          </Btn>
        }/>

      {scanning && (
        <div style={{height:3, background:'var(--hairline-soft)', borderRadius:999, marginBottom:14, overflow:'hidden'}}>
          <div style={{height:'100%', width:`${scanProgress}%`, background:'var(--accent)', transition:'width 150ms'}}/>
        </div>
      )}

      {/* Top: status summary */}
      <div style={{display:'grid', gridTemplateColumns:'1.1fr 1fr', gap:12, marginBottom:14}}>
        <GlassPanel style={{padding:'18px 22px'}}>
          <div style={{display:'flex', alignItems:'center', gap:14}}>
            <div style={{
              width:64, height:64, borderRadius:18,
              background:'linear-gradient(135deg, rgba(52,199,89,0.2), rgba(52,199,89,0.05))',
              border:'0.5px solid rgba(52,199,89,0.3)',
              display:'grid', placeItems:'center'
            }}>
              <Icon name="shield" size={32} color="#34C759"/>
            </div>
            <div style={{flex:1}}>
              <div style={{fontSize:11, fontWeight:600, color:'var(--text-3)', letterSpacing:'0.06em', textTransform:'uppercase'}}>État système</div>
              <div style={{fontSize:22, fontWeight:700, letterSpacing:'-0.02em', marginTop:2}}>Protégé</div>
              <div style={{fontSize:12, color:'var(--text-2)', marginTop:2}}>Dernier scan il y a 6 minutes · base de signatures fraîche</div>
            </div>
          </div>
          <div style={{display:'grid', gridTemplateColumns:'repeat(5, 1fr)', gap:8, marginTop:18}}>
            {checks.map(c => (
              <div key={c.label} style={{padding:'10px 8px', borderRadius:9, background:'rgba(0,0,0,0.03)',
                border:'0.5px solid var(--hairline)', textAlign:'left'}}>
                <div style={{display:'flex', alignItems:'center', gap:5, marginBottom:5}}>
                  <span style={{width:6, height:6, borderRadius:999,
                    background: c.status==='good'?'#34C759':c.status==='info'?'#0A84FF':'#FFB020'}}/>
                  <span style={{fontSize:10, fontWeight:600, color:'var(--text-3)', textTransform:'uppercase', letterSpacing:'0.04em'}}>{c.status==='good'?'OK':c.status==='info'?'Info':'Warn'}</span>
                </div>
                <div style={{fontSize:11.5, fontWeight:600, lineHeight:1.3}}>{c.label}</div>
                <div style={{fontSize:10.5, color:'var(--text-3)', marginTop:2}}>{c.sub}</div>
              </div>
            ))}
          </div>
        </GlassPanel>

        <GlassPanel style={{padding:'18px 22px'}}>
          <div style={{display:'flex', alignItems:'center', gap:10, marginBottom:14}}>
            <Icon name="info" size={18} color="#FFB020"/>
            <div style={{fontSize:13.5, fontWeight:700}}>Activité récente</div>
            <div style={{flex:1}}/>
            <StatusPill status="warn">3 anomalies</StatusPill>
          </div>
          {[
            {t:'il y a 12 min', label:'Tentative de connexion sortante bloquée', val:'tracking-pixel.net'},
            {t:'il y a 2 h', label:'Extension Chrome ajoutée', val:'Cashback Helper Pro'},
            {t:'hier 18h', label:'Profil de configuration installé', val:'com.adware.config'},
            {t:'il y a 3 j', label:'Mise à jour XProtect', val:'macOS · 2173'},
          ].map((e,i) => (
            <div key={i} style={{display:'flex', alignItems:'center', gap:10, padding:'10px 0',
              borderTop:i>0?'0.5px solid var(--hairline-soft)':'none'}}>
              <div style={{width:6, height:6, borderRadius:999, background:'var(--text-3)', flexShrink:0}}/>
              <div style={{flex:1, minWidth:0}}>
                <div style={{fontSize:12.5, fontWeight:500}}>{e.label}</div>
                <div style={{fontSize:11, color:'var(--text-3)', fontFamily:'ui-monospace, "SF Mono", monospace',
                  whiteSpace:'nowrap', overflow:'hidden', textOverflow:'ellipsis'}}>{e.val}</div>
              </div>
              <div style={{fontSize:11, color:'var(--text-3)', whiteSpace:'nowrap'}}>{e.t}</div>
            </div>
          ))}
        </GlassPanel>
      </div>

      {/* Threats list */}
      <div style={{display:'flex', alignItems:'center', justifyContent:'space-between', margin:'18px 4px 10px'}}>
        <h2 style={{fontSize:16, fontWeight:700, letterSpacing:'-0.01em', margin:0}}>Anomalies détectées</h2>
        <span style={{fontSize:12, color:'var(--text-3)'}}>{threats.length} éléments · 0 menace critique</span>
      </div>
      <GlassPanel style={{padding:8}}>
        {threats.map((t, i) => {
          const sevColors = {high:'#FF453A', medium:'#FFB020', low:'#0A84FF'};
          const c = sevColors[t.severity];
          return (
            <div key={t.id} style={{
              display:'flex', alignItems:'center', gap:14, padding:'14px 12px',
              borderTop:i>0?'0.5px solid var(--hairline-soft)':'none'
            }}>
              <div style={{width:38, height:38, borderRadius:10, background:`${c}1c`, color:c,
                display:'grid', placeItems:'center', flexShrink:0}}>
                <Icon name={t.kind==='adware'?'shield':t.kind==='tracker'?'eye':'app'} size={18} color={c}/>
              </div>
              <div style={{flex:1, minWidth:0}}>
                <div style={{display:'flex', alignItems:'center', gap:8, marginBottom:2}}>
                  <span style={{fontSize:13.5, fontWeight:600}}>{t.name}</span>
                  <span style={{fontSize:10.5, fontWeight:600, padding:'1px 6px', borderRadius:4,
                    background:`${c}22`, color:c, textTransform:'uppercase', letterSpacing:'0.04em'}}>
                    {t.severity==='high'?'Élevé':t.severity==='medium'?'Moyen':'Faible'}
                  </span>
                </div>
                <div style={{fontSize:12, color:'var(--text-2)', marginBottom:3}}>{t.desc}</div>
                <div style={{fontSize:11, color:'var(--text-3)', fontFamily:'ui-monospace, "SF Mono", monospace',
                  whiteSpace:'nowrap', overflow:'hidden', textOverflow:'ellipsis'}}>{t.path}</div>
              </div>
              <Btn kind="secondary" size="sm">Ignorer</Btn>
              <Btn kind={t.severity==='high'?'danger':'primary'} size="sm">{t.action}</Btn>
            </div>
          );
        })}
      </GlassPanel>
    </div>
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// 9. MISES À JOUR
// ═══════════════════════════════════════════════════════════════════════════
function ScreenUpdates({ ctx }) {
  const apps = [
    {name:'Visual Studio Code', from:'1.92.1', to:'1.94.0', source:'Direct', glyph:'VS', color:'#007ACC', size:'124 Mo', notes:'Copilot inline · Better Git diff'},
    {name:'Figma', from:'124.1.2', to:'125.3.0', source:'Direct', glyph:'F', color:'#0ACF83', size:'88 Mo', notes:'Variables 2.0, Dev Mode amélioré'},
    {name:'Slack', from:'4.38.121', to:'4.41.97', source:'App Store', glyph:'#', color:'#4A154B', size:'160 Mo', notes:'Corrections de bugs'},
    {name:'1Password', from:'8.10.30', to:'8.10.35', source:'App Store', glyph:'1P', color:'#1A8FE3', size:'42 Mo', notes:'Patch sécurité (recommandé)', security:true},
    {name:'Notion', from:'3.14', to:'3.16', source:'Direct', glyph:'N', color:'#000', size:'196 Mo', notes:'Calendrier intégré'},
    {name:'Homebrew', from:'4.3.0', to:'4.4.2', source:'CLI', glyph:'🍺', color:'#FBB040', size:'—', notes:'+ 142 formules à mettre à jour'},
    {name:'Docker Desktop', from:'4.32.0', to:'4.35.1', source:'Direct', glyph:'🐳', color:'#2496ED', size:'620 Mo', notes:'Nouvelles images officielles'},
  ];

  const [selected, setSelected] = React.useState(new Set([apps[0].name, apps[1].name, apps[3].name]));
  const toggle = (n) => setSelected(s => { const x = new Set(s); x.has(n)?x.delete(n):x.add(n); return x; });

  return (
    <div style={{padding:'8px 4px 40px', maxWidth:1100, margin:'0 auto'}}>
      <ScreenHeader kicker="Mises à jour" title={`${apps.length} apps en retard`}
        subtitle="Inclut un patch de sécurité 1Password. CleanMac télécharge en arrière-plan, tu valides l'install."
        right={
          <div style={{display:'flex', gap:10, alignItems:'center'}}>
            <span style={{fontSize:13, color:'var(--text-2)'}}>{selected.size} sélectionnées</span>
            <Btn kind="primary" size="lg" icon="arrow">Tout mettre à jour</Btn>
          </div>
        }/>

      <GlassPanel style={{padding:8}}>
        {apps.map((a, i) => {
          const isSel = selected.has(a.name);
          return (
            <div key={a.name} style={{
              display:'flex', alignItems:'center', gap:14, padding:'12px 10px',
              borderTop:i>0?'0.5px solid var(--hairline-soft)':'none',
              background: a.security ? 'rgba(255,69,58,0.05)':'transparent'
            }}>
              <Check checked={isSel} onChange={()=>toggle(a.name)}/>
              <div style={{width:40, height:40, borderRadius:10, background:a.color, color:'#fff',
                display:'grid', placeItems:'center', fontWeight:700, fontSize:14, flexShrink:0,
                boxShadow:'0 2px 4px rgba(0,0,0,0.1), inset 0 1px 0 rgba(255,255,255,0.2)'}}>
                {a.glyph}
              </div>
              <div style={{flex:1, minWidth:0}}>
                <div style={{display:'flex', alignItems:'center', gap:8}}>
                  <span style={{fontSize:13.5, fontWeight:600}}>{a.name}</span>
                  {a.security && <StatusPill status="bad">Sécurité</StatusPill>}
                  <span style={{fontSize:10.5, fontWeight:600, padding:'1px 6px', borderRadius:4,
                    background:'rgba(0,0,0,0.05)', color:'var(--text-2)'}}>{a.source}</span>
                </div>
                <div style={{fontSize:12, color:'var(--text-2)', marginTop:3, fontFamily:'ui-monospace,monospace'}}>
                  {a.from} <span style={{opacity:.5}}>→</span> <span style={{color:'var(--accent)', fontWeight:600}}>{a.to}</span>
                </div>
                <div style={{fontSize:11.5, color:'var(--text-3)', marginTop:3}}>{a.notes}</div>
              </div>
              <div style={{fontSize:12, color:'var(--text-3)', textAlign:'right'}}>
                <div>{a.size}</div>
                <button style={{background:'transparent', border:0, color:'var(--accent)', fontSize:11.5, fontWeight:600, marginTop:2, cursor:'default'}}>Notes</button>
              </div>
            </div>
          );
        })}
      </GlassPanel>
    </div>
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// 10. OPTIMISATION — éléments de connexion + launch agents + apps lourdes
// ═══════════════════════════════════════════════════════════════════════════
function ScreenOptimize({ ctx }) {
  const [tab, setTab] = React.useState('login');

  const loginItems = [
    {name:'Magnet', sub:'Gestion des fenêtres', impact:'Léger', color:'#FF3B30', glyph:'M', on:true, needed:true},
    {name:'Rectangle', sub:'Doublon de Magnet', impact:'Léger', color:'#5856D6', glyph:'R', on:true, needed:false},
    {name:'Adobe Creative Cloud', sub:'Synchronisation des polices', impact:'Lourd · 380 Mo RAM', color:'#FF61F6', glyph:'Ac', on:true, needed:false},
    {name:'Microsoft AutoUpdate', sub:'Vérification de mise à jour', impact:'Modéré', color:'#2B579A', glyph:'M', on:true, needed:false},
    {name:'Dropbox', sub:'Démon de synchro', impact:'Lourd', color:'#0061FE', glyph:'D', on:true, needed:true},
    {name:'Zoom Updater', sub:'Démarrage en arrière-plan', impact:'Modéré', color:'#2D8CFF', glyph:'Z', on:true, needed:false},
    {name:'Steam Helper', sub:'Mise à jour des jeux', impact:'Lourd', color:'#171a21', glyph:'S', on:false, needed:false},
  ];

  const launchAgents = [
    {path:'com.adobe.acc.installer.v2.plist', app:'Adobe Creative Cloud', risk:'low'},
    {path:'com.microsoft.update.agent.plist', app:'Microsoft AutoUpdate', risk:'low'},
    {path:'com.spotify.webhelper.plist', app:'Spotify (orphelin)', risk:'medium'},
    {path:'com.google.keystone.agent.plist', app:'Google Keystone', risk:'low'},
    {path:'com.zoom.us.ZoomDaemon.plist', app:'Zoom (helper)', risk:'low'},
    {path:'com.unknown.helper.plist', app:'Source inconnue', risk:'high'},
  ];

  const heavy = [
    {name:'Google Chrome', cpu:38, ram:4.2, glyph:'C', color:'#4285F4', tabs:'27 onglets, 6 sur YouTube'},
    {name:'Slack', cpu:14, ram:2.1, glyph:'#', color:'#4A154B', tabs:'12 workspaces'},
    {name:'Xcode', cpu:22, ram:3.6, glyph:'Xc', color:'#147EFB', tabs:'Compilation arrière-plan'},
    {name:'Docker Desktop', cpu:18, ram:2.8, glyph:'🐳', color:'#2496ED', tabs:'4 conteneurs actifs'},
    {name:'Notion', cpu:6, ram:0.9, glyph:'N', color:'#000', tabs:'3 fenêtres'},
  ];

  const [login, setLogin] = React.useState(()=>Object.fromEntries(loginItems.map(l=>[l.name, l.on])));

  return (
    <div style={{padding:'8px 4px 40px', maxWidth:1100, margin:'0 auto'}}>
      <ScreenHeader kicker="Optimisation" title="Démarrage plus rapide, mémoire plus libre."
        subtitle="11 éléments se lancent avec macOS. 6 ne sont vraiment pas nécessaires."
        right={
          <Btn kind="primary" size="lg" icon="bolt">Tout optimiser (6)</Btn>
        }/>

      <div style={{display:'flex', gap:4, marginBottom:14, padding:3, background:'rgba(0,0,0,0.05)',
        borderRadius:9, width:'fit-content'}}>
        {[['login','Connexion', loginItems.length],
          ['agents','Launch agents', launchAgents.length],
          ['heavy','Apps gourmandes', heavy.length]].map(([k,l,c])=>(
          <button key={k} onClick={()=>setTab(k)} style={{
            padding:'6px 14px', borderRadius:7, border:0, cursor:'default',
            background: tab===k ? 'var(--window-bg-solid)' : 'transparent',
            boxShadow: tab===k ? '0 1px 2px rgba(0,0,0,0.06)' : 'none',
            fontSize:12.5, fontWeight:600, color:tab===k?'var(--text-1)':'var(--text-2)'
          }}>{l} <span style={{opacity:.55, marginLeft:4}}>{c}</span></button>
        ))}
      </div>

      {tab==='login' && (
        <GlassPanel style={{padding:8}}>
          {loginItems.map((it, i) => {
            const on = login[it.name];
            return (
              <div key={it.name} style={{display:'flex', alignItems:'center', gap:14, padding:'12px 10px',
                borderTop:i>0?'0.5px solid var(--hairline-soft)':'none'}}>
                <div style={{width:34, height:34, borderRadius:8, background:it.color, color:'#fff',
                  display:'grid', placeItems:'center', fontWeight:700, fontSize:13, flexShrink:0}}>{it.glyph}</div>
                <div style={{flex:1, minWidth:0}}>
                  <div style={{display:'flex', alignItems:'center', gap:8}}>
                    <span style={{fontSize:13.5, fontWeight:600}}>{it.name}</span>
                    {!it.needed && <StatusPill status="warn">Pas nécessaire</StatusPill>}
                  </div>
                  <div style={{fontSize:11.5, color:'var(--text-3)', marginTop:2}}>{it.sub}</div>
                </div>
                <div style={{fontSize:11.5, color: it.impact.startsWith('Lourd') ? '#FF453A' : 'var(--text-3)', fontWeight: it.impact.startsWith('Lourd')?600:500}}>{it.impact}</div>
                <Toggle value={on} onChange={v=>setLogin(s=>({...s,[it.name]:v}))}/>
              </div>
            );
          })}
        </GlassPanel>
      )}

      {tab==='agents' && (
        <GlassPanel style={{padding:8}}>
          {launchAgents.map((la, i) => {
            const rc = la.risk==='high'?'#FF453A':la.risk==='medium'?'#FFB020':'#34C759';
            const rl = la.risk==='high'?'Risque':la.risk==='medium'?'Inconnu':'Sûr';
            return (
              <div key={la.path} style={{display:'flex', alignItems:'center', gap:14, padding:'12px 10px',
                borderTop:i>0?'0.5px solid var(--hairline-soft)':'none'}}>
                <div style={{width:34, height:34, borderRadius:8, background:`${rc}1c`, color:rc,
                  display:'grid', placeItems:'center', flexShrink:0}}>
                  <Icon name="wrench" size={16} color={rc}/>
                </div>
                <div style={{flex:1, minWidth:0}}>
                  <div style={{display:'flex', alignItems:'center', gap:8}}>
                    <span style={{fontSize:13.5, fontWeight:600}}>{la.app}</span>
                    <span style={{fontSize:10.5, fontWeight:600, padding:'1px 6px', borderRadius:4,
                      background:`${rc}22`, color:rc, textTransform:'uppercase', letterSpacing:'0.04em'}}>{rl}</span>
                  </div>
                  <div style={{fontSize:11.5, color:'var(--text-3)', marginTop:2, fontFamily:'ui-monospace, "SF Mono", monospace'}}>
                    /Library/LaunchAgents/{la.path}
                  </div>
                </div>
                <Btn kind="ghost" size="sm">Révéler</Btn>
                <Btn kind={la.risk==='high'?'danger':'secondary'} size="sm">Désactiver</Btn>
              </div>
            );
          })}
        </GlassPanel>
      )}

      {tab==='heavy' && (
        <GlassPanel style={{padding:8}}>
          {heavy.map((h, i) => (
            <div key={h.name} style={{display:'flex', alignItems:'center', gap:14, padding:'12px 10px',
              borderTop:i>0?'0.5px solid var(--hairline-soft)':'none'}}>
              <div style={{width:36, height:36, borderRadius:9, background:h.color, color:'#fff',
                display:'grid', placeItems:'center', fontWeight:700, fontSize:13, flexShrink:0}}>{h.glyph}</div>
              <div style={{flex:1, minWidth:0}}>
                <div style={{fontSize:13.5, fontWeight:600}}>{h.name}</div>
                <div style={{fontSize:11.5, color:'var(--text-3)', marginTop:2}}>{h.tabs}</div>
              </div>
              <div style={{width:120}}>
                <div style={{display:'flex', justifyContent:'space-between', fontSize:11, color:'var(--text-3)', marginBottom:3}}>
                  <span>CPU</span><span style={{fontWeight:600, color:h.cpu>20?'#FF453A':'var(--text-2)'}}>{h.cpu}%</span>
                </div>
                <HBar value={h.cpu} color={h.cpu>20?'#FF453A':'#0A84FF'}/>
              </div>
              <div style={{width:120}}>
                <div style={{display:'flex', justifyContent:'space-between', fontSize:11, color:'var(--text-3)', marginBottom:3}}>
                  <span>RAM</span><span style={{fontWeight:600}}>{h.ram} Go</span>
                </div>
                <HBar value={h.ram} max={6} color="#BF5AF2"/>
              </div>
              <Btn kind="danger" size="sm">Quitter</Btn>
            </div>
          ))}
        </GlassPanel>
      )}
    </div>
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// 11. SPACE LENS — treemap interactif du disque
// ═══════════════════════════════════════════════════════════════════════════
function ScreenSpaceLens({ ctx }) {
  // Hierarchical tree of disk contents
  const root = {
    name:'Macintosh HD',
    children:[
      { name:'Système', size:32, color:'#5E5CE6', children:[
        {name:'/System', size:18, color:'#7A78EC'},
        {name:'/Library', size:9, color:'#9694EE'},
        {name:'/private', size:5, color:'#B1AFF0'},
      ]},
      { name:'Applications', size:84, color:'#0A84FF', children:[
        {name:'Xcode.app', size:22, color:'#3DA0FF'},
        {name:'Adobe', size:18, color:'#5AB0FF'},
        {name:'Final Cut Pro', size:3.4, color:'#7AC0FF'},
        {name:'Microsoft 365', size:8, color:'#9AD0FF'},
        {name:'Autres apps (108)', size:32.6, color:'#B6DCFF'},
      ]},
      { name:'~/Documents', size:42, color:'#FFB020', children:[
        {name:'Projets', size:18, color:'#FFC04D'},
        {name:'Thèse', size:8, color:'#FFCC70'},
        {name:'Archives', size:11, color:'#FFD894'},
        {name:'Divers', size:5, color:'#FFE4B8'},
      ]},
      { name:'~/Photos', size:30.6, color:'#FF9F0A', children:[
        {name:'Photothèque', size:22, color:'#FFB13A'},
        {name:'Originaux RAW', size:6, color:'#FFC36A'},
        {name:'Caches Photos', size:2.6, color:'#FFD49A'},
      ]},
      { name:'~/Movies', size:14, color:'#FF453A', children:[
        {name:'iMovie projets', size:9, color:'#FF6358'},
        {name:'Captures écran', size:5, color:'#FF8176'},
      ]},
      { name:'~/Downloads', size:11, color:'#BF5AF2', children:[
        {name:'.dmg installeurs', size:8, color:'#CB72F4'},
        {name:'Archives .zip', size:3, color:'#D78AF6'},
      ]},
      { name:'À nettoyer', size:18.4, color:'#00D9A3', children:[
        {name:'Caches', size:9.9, color:'#33E1B7'},
        {name:'Logs', size:0.9, color:'#66EACA'},
        {name:'Mail', size:4.1, color:'#99F2DD'},
        {name:'Corbeilles', size:2.3, color:'#BDF6E7'},
        {name:'Anciens .dmg', size:1.2, color:'#D5F9EF'},
      ]},
    ]
  };

  const [path, setPath] = React.useState([]);  // names of nodes we descended into
  const current = path.reduce((n, name) => n.children?.find(c=>c.name===name) || n, root);
  const items = current.children || [];
  const total = items.reduce((s,n)=>s+n.size,0) || 1;

  // Treemap (squarified-ish, simple row-based)
  const W = 720, H = 420;
  const rects = squarify(items, W, H);

  const [hover, setHover] = React.useState(null);

  return (
    <div style={{padding:'8px 4px 40px', maxWidth:1100, margin:'0 auto'}}>
      <ScreenHeader kicker="Space Lens" title="Où vont tes 482 Go."
        subtitle="Carte du disque en taille réelle. Clique pour plonger, double-clique pour révéler dans le Finder."
        right={
          <Btn kind="secondary" icon="search">Rechercher dans le disque</Btn>
        }/>

      {/* Breadcrumb */}
      <div style={{display:'flex', alignItems:'center', gap:6, marginBottom:12, fontSize:13}}>
        <button onClick={()=>setPath([])}
          style={{background:'transparent', border:0, color:'var(--accent)', fontWeight:600, cursor:'default', padding:0}}>
          {root.name}
        </button>
        {path.map((n, i) => (
          <React.Fragment key={i}>
            <Icon name="chevron" size={12} color="var(--text-3)"/>
            <button onClick={()=>setPath(path.slice(0,i+1))}
              style={{background:'transparent', border:0, color: i===path.length-1?'var(--text-1)':'var(--accent)',
                fontWeight:600, cursor:'default', padding:0}}>
              {n}
            </button>
          </React.Fragment>
        ))}
        <div style={{flex:1}}/>
        <span style={{fontSize:12, color:'var(--text-3)'}}>{items.length} éléments · {total.toFixed(1)} Go</span>
      </div>

      <div style={{display:'grid', gridTemplateColumns:'1fr 280px', gap:12}}>
        <GlassPanel style={{padding:6, overflow:'hidden'}}>
          <svg width="100%" viewBox={`0 0 ${W} ${H}`} style={{display:'block', borderRadius:8, overflow:'visible'}}>
            {rects.map((r, i) => {
              const it = items[i];
              const big = r.w > 80 && r.h > 36;
              const med = r.w > 50 && r.h > 22;
              const canDrill = !!it.children;
              const isH = hover === it.name;
              return (
                <g key={it.name}
                  onMouseEnter={()=>setHover(it.name)} onMouseLeave={()=>setHover(null)}
                  onClick={()=> canDrill && setPath([...path, it.name])}
                  style={{cursor: canDrill ? 'default':'default'}}>
                  <rect x={r.x+1} y={r.y+1} width={Math.max(0, r.w-2)} height={Math.max(0,r.h-2)}
                    fill={it.color} rx={4}
                    style={{transition:'opacity 120ms, filter 120ms',
                      filter: isH ? 'brightness(1.08) saturate(1.1)' : 'none',
                      stroke: isH ? '#fff' : 'transparent', strokeWidth: 1.5}}/>
                  {big && (
                    <>
                      <text x={r.x+10} y={r.y+18} fontSize={12} fontWeight="700" fill="#fff"
                        style={{textShadow:'0 1px 2px rgba(0,0,0,0.4)', pointerEvents:'none'}}>{it.name}</text>
                      <text x={r.x+10} y={r.y+34} fontSize={11} fontWeight="500" fill="rgba(255,255,255,0.85)"
                        style={{textShadow:'0 1px 2px rgba(0,0,0,0.4)', pointerEvents:'none'}}>{it.size.toFixed(1)} Go</text>
                    </>
                  )}
                  {!big && med && (
                    <text x={r.x+r.w/2} y={r.y+r.h/2+4} fontSize={10.5} fontWeight="700" fill="#fff" textAnchor="middle"
                      style={{textShadow:'0 1px 1px rgba(0,0,0,0.4)', pointerEvents:'none'}}>{it.size.toFixed(1)} Go</text>
                  )}
                </g>
              );
            })}
          </svg>
        </GlassPanel>

        <GlassPanel style={{padding:'14px 16px'}}>
          <div style={{fontSize:11, fontWeight:600, color:'var(--text-3)', textTransform:'uppercase', letterSpacing:'0.06em', marginBottom:8}}>Légende</div>
          {items.sort((a,b)=>b.size-a.size).map((it) => (
            <div key={it.name}
              onMouseEnter={()=>setHover(it.name)} onMouseLeave={()=>setHover(null)}
              onClick={()=> it.children && setPath([...path, it.name])}
              style={{display:'flex', alignItems:'center', gap:10, padding:'8px 6px', borderRadius:6,
                background: hover===it.name?'rgba(0,0,0,0.04)':'transparent', cursor:'default',
                transition:'background 100ms'}}>
              <div style={{width:10, height:10, borderRadius:3, background:it.color}}/>
              <div style={{flex:1, minWidth:0}}>
                <div style={{fontSize:12.5, fontWeight:600, whiteSpace:'nowrap', overflow:'hidden', textOverflow:'ellipsis'}}>{it.name}</div>
                <div style={{fontSize:10.5, color:'var(--text-3)'}}>{(it.size/total*100).toFixed(1)}% · {it.size.toFixed(1)} Go</div>
              </div>
              {it.children && <Icon name="chevron" size={11} color="var(--text-3)"/>}
            </div>
          ))}
        </GlassPanel>
      </div>
    </div>
  );
}

// Squarified-ish treemap (row-based, good enough for ~10 children)
function squarify(items, W, H) {
  if (!items.length) return [];
  const total = items.reduce((s,it)=>s+it.size,0);
  const sorted = items.map((it, i) => ({...it, _i: i})).sort((a,b)=>b.size-a.size);
  // simple slice-and-dice with rows
  const result = new Array(items.length);
  let x = 0, y = 0, w = W, h = H;
  let remaining = sorted.slice();
  while (remaining.length) {
    // take top items for one row whose ratio is best-ish
    const horiz = w >= h;
    const len = horiz ? h : w;
    // greedy: take items while average ratio improves
    let row = [];
    let rowSum = 0;
    let prevRatio = Infinity;
    while (remaining.length) {
      const next = remaining[0];
      const sum2 = rowSum + next.size;
      const side = (sum2 / total * W*H) / len;
      // ratio = worst of (side/long, long/side) across row
      const minS = Math.min(...row.map(r=>r.size), next.size);
      const maxS = Math.max(...row.map(r=>r.size), next.size);
      const r1 = (side * (minS/sum2) ) / (len);
      const r2 = (side * (maxS/sum2) ) / (len);
      const ratio = Math.max(r1?1/r1:Infinity, r2?1/r2:Infinity, side/len, len/side);
      if (row.length === 0 || ratio <= prevRatio) {
        row.push(next); rowSum = sum2; prevRatio = ratio; remaining.shift();
      } else break;
    }
    // lay out the row
    const rowSize = rowSum / total * (W*H);
    const rowLen = rowSize / len;
    let off = 0;
    for (const it of row) {
      const seg = (it.size / rowSum) * len;
      if (horiz) {
        result[it._i] = {x: x, y: y + off, w: rowLen, h: seg};
      } else {
        result[it._i] = {x: x + off, y: y, w: seg, h: rowLen};
      }
      off += seg;
    }
    if (horiz) { x += rowLen; w -= rowLen; } else { y += rowLen; h -= rowLen; }
    if (w < 0.5 || h < 0.5) break;
  }
  return result;
}

Object.assign(window, { ScreenSecurity, ScreenUpdates, ScreenOptimize, ScreenSpaceLens });
