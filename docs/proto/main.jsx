// app.jsx — CleanMac Pro main shell

const TWEAK_DEFAULTS = /*EDITMODE-BEGIN*/{
  "accent": "mint",
  "dark": false,
  "density": "regular",
  "wallpaper": "aurora",
  "showOnboarding": false
}/*EDITMODE-END*/;

const ACCENT_PRESETS = {
  mint:   { c:'#00D9A3', rgb:'0,217,163',  text:'#062018' },
  blue:   { c:'#0A84FF', rgb:'10,132,255', text:'#02163a' },
  violet: { c:'#BF5AF2', rgb:'191,90,242', text:'#1b0a30' },
  orange: { c:'#FF9F0A', rgb:'255,159,10', text:'#2a1505' },
};
const WALLPAPERS = {
  aurora:   'radial-gradient(ellipse at 30% 10%, #2b3a5f 0%, #14182b 45%, #06080f 100%)',
  graphite: 'radial-gradient(ellipse at 50% 0%, #2a2a2e 0%, #18181b 50%, #0a0a0c 100%)',
  sunset:   'radial-gradient(ellipse at 30% 0%, #5a2a3e 0%, #2a1525 50%, #0c0612 100%)',
  forest:   'radial-gradient(ellipse at 30% 0%, #1d3a30 0%, #0e2018 50%, #04100c 100%)',
};

// ──────────────────────────────────────────────────────────────────────────
// Sidebar
// ──────────────────────────────────────────────────────────────────────────
function Sidebar({ active, goTo, openAI }) {
  const sections = [
    {label:null, items:[
      {id:'dashboard', icon:'dashboard', label:'Vue d\'ensemble'},
      {id:'scan',      icon:'scan',      label:'Smart Scan'},
    ]},
    {label:'Nettoyer', items:[
      {id:'cleanup',     icon:'broom', label:'Fichiers inutiles', badge:'18,4 Go', badgeColor:'#FFB020'},
      {id:'uninstaller', icon:'app',   label:'Désinstalleur', badge:'3', badgeColor:'#0A84FF'},
      {id:'files',       icon:'files', label:'Volumineux & doublons', badge:'247'},
      {id:'spacelens',   icon:'disk',  label:'Space Lens'},
    ]},
    {label:'Protéger', items:[
      {id:'security', icon:'shield', label:'Sécurité', badge:'3', badgeColor:'#FFB020'},
      {id:'privacy',  icon:'eye',    label:'Confidentialité'},
    ]},
    {label:'Optimiser', items:[
      {id:'updates',     icon:'arrow',  label:'Mises à jour', badge:'7', badgeColor:'#FF453A'},
      {id:'optimize',    icon:'bolt',   label:'Performance'},
      {id:'maintenance', icon:'wrench', label:'Maintenance'},
    ]},
  ];

  return (
    <aside style={{
      width:236, flexShrink:0, height:'100%',
      background:'var(--sidebar-bg)',
      backdropFilter:'blur(40px) saturate(180%)',
      WebkitBackdropFilter:'blur(40px) saturate(180%)',
      borderRight:'0.5px solid var(--hairline)',
      display:'flex', flexDirection:'column',
      paddingTop:36 // for traffic lights
    }}>
      {/* Brand */}
      <div style={{padding:'10px 14px 18px', display:'flex', alignItems:'center', gap:9}}>
        <CmpMark size={22} hue="mint"/>
        <div>
          <div style={{fontSize:13.5, fontWeight:700, letterSpacing:'-0.01em'}}>CleanMac</div>
          <div style={{fontSize:10, fontWeight:600, color:'var(--text-3)', letterSpacing:'0.06em', textTransform:'uppercase', marginTop:-2}}>Pro</div>
        </div>
      </div>

      <div style={{flex:1, overflow:'auto', padding:'0 8px'}}>
        {sections.map((s, i) => (
          <div key={i} style={{marginBottom:14}}>
            {s.label && (
              <div style={{fontSize:10, fontWeight:600, color:'var(--text-3)',
                letterSpacing:'0.08em', textTransform:'uppercase', padding:'4px 10px 6px'}}>
                {s.label}
              </div>
            )}
            {s.items.map(it => {
              const sel = active === it.id;
              return (
                <button key={it.id} onClick={()=>goTo(it.id)} style={{
                  width:'100%', display:'flex', alignItems:'center', gap:10,
                  padding:'7px 10px', margin:'1px 0',
                  borderRadius:8, border:0, cursor:'default', textAlign:'left',
                  background: sel ? 'var(--accent)' : 'transparent',
                  color: sel ? ACCENT_PRESETS.mint.text : 'var(--text-1)',
                  transition:'background 120ms',
                  fontFamily:'inherit', fontSize:13,
                }}
                onMouseEnter={e=>{ if(!sel) e.currentTarget.style.background='rgba(0,0,0,0.05)'}}
                onMouseLeave={e=>{ if(!sel) e.currentTarget.style.background='transparent'}}>
                  <Icon name={it.icon} size={16} color={sel ? 'currentColor':'var(--text-2)'}/>
                  <span style={{flex:1, fontWeight: sel ? 600 : 500}}>{it.label}</span>
                  {it.badge && (
                    <span style={{
                      fontSize:10.5, fontWeight:600, padding:'2px 7px', borderRadius:999,
                      background: sel ? 'rgba(0,0,0,0.15)' : (it.badgeColor ? `${it.badgeColor}22` : 'rgba(0,0,0,0.08)'),
                      color: sel ? 'inherit' : (it.badgeColor || 'var(--text-2)')
                    }}>{it.badge}</span>
                  )}
                </button>
              );
            })}
          </div>
        ))}
      </div>

      {/* AI assistant button at bottom */}
      <div style={{padding:10, borderTop:'0.5px solid var(--hairline)'}}>
        <button onClick={openAI} style={{
          width:'100%', display:'flex', alignItems:'center', gap:10,
          padding:'10px 12px', borderRadius:10, border:0, cursor:'default', textAlign:'left',
          background:'linear-gradient(135deg, rgba(0,217,163,0.18), rgba(0,217,163,0.04))',
          color:'var(--text-1)',
          boxShadow:'inset 0 0 0 0.5px rgba(0,217,163,0.4)',
          fontFamily:'inherit'
        }}>
          <div style={{width:28, height:28, borderRadius:7, background:'var(--accent)', display:'grid', placeItems:'center'}}>
            <Icon name="sparkle" size={15} color="#062018"/>
          </div>
          <div style={{flex:1}}>
            <div style={{fontSize:12.5, fontWeight:700}}>Assistant IA</div>
            <div style={{fontSize:10.5, color:'var(--text-2)'}}>Demande, en français</div>
          </div>
          <span style={{
            fontSize:10, fontWeight:600, padding:'2px 6px', borderRadius:4,
            background:'rgba(0,0,0,0.08)', color:'var(--text-2)', fontFamily:'ui-monospace, monospace'
          }}>⌘K</span>
        </button>
      </div>
    </aside>
  );
}

// ──────────────────────────────────────────────────────────────────────────
// Window chrome (traffic lights + title)
// ──────────────────────────────────────────────────────────────────────────
function TrafficLights({ onClose }) {
  return (
    <div style={{position:'absolute', top:14, left:14, display:'flex', gap:8, zIndex:10}}>
      <div onClick={onClose} style={{width:13, height:13, borderRadius:'50%', background:'#ff5f57', border:'0.5px solid rgba(0,0,0,0.1)', cursor:'default'}}/>
      <div style={{width:13, height:13, borderRadius:'50%', background:'#febc2e', border:'0.5px solid rgba(0,0,0,0.1)', cursor:'default'}}/>
      <div style={{width:13, height:13, borderRadius:'50%', background:'#28c840', border:'0.5px solid rgba(0,0,0,0.1)', cursor:'default'}}/>
    </div>
  );
}

// ──────────────────────────────────────────────────────────────────────────
// AI Assistant overlay (right-side panel)
// ──────────────────────────────────────────────────────────────────────────
function AIPanel({ open, onClose, ctx }) {
  const [messages, setMessages] = React.useState([
    { role:'ai', text:'Salut. Je connais ton Mac mieux que toi. Demande-moi quoi nettoyer, ou choisis une idée 👇' }
  ]);
  const [input, setInput] = React.useState('');
  const [thinking, setThinking] = React.useState(false);

  const suggestions = [
    'Que puis-je supprimer sans rien casser ?',
    'Pourquoi mon Mac est lent ?',
    'Que prend toute la place ?',
    'Y a-t-il des doublons de photos ?',
  ];

  // Pre-baked AI responses (so it works offline)
  const responses = {
    'que puis-je supprimer': `Boom. Voici ce que je virerais en premier :\n\n• **Caches Xcode** — 3,2 Go (recréés au prochain build)\n• **Anciens .dmg dans Téléchargements** — 11,6 Go (macOS Sonoma, déjà installé)\n• **Final Cut Pro** — 3,4 Go (pas ouvert depuis 9 mois)\n\nTotal récupéré : **18,2 Go**. Aucun document, aucune photo touchée.`,
    'pourquoi mon mac': `Trois suspects en ce moment :\n\n• **Chrome** mange 4,2 Go de RAM (16 onglets ouverts, dont 3 dorment depuis 2 jours)\n• **Spotlight** réindexe — c'est temporaire\n• **Trop d'apps au démarrage** : 11 sont configurées, 6 sont inutiles\n\nVeux-tu que je libère la RAM et nettoie le démarrage ?`,
    'que prend toute la place': `Top 5 sur ton disque :\n\n1. **Photos.app** — 84,2 Go\n2. **Xcode** + DerivedData — 22 Go\n3. **Documents** — 19 Go\n4. **iMovie + projets** — 14 Go\n5. **Téléchargements** — 11 Go (à vider !)\n\nVeux-tu un graphique interactif ?`,
    'doublons de photos': `Trouvé **142 doublons exacts** dans Photos.app (mêmes pixels, mêmes EXIF).\n\nÉconomies : **2,8 Go**. Je peux les marquer pour suppression sans toucher aux originaux.`,
    default: 'Je travaille là-dessus. Donne-moi un détail de plus — par exemple, dans quel dossier, ou quelle app te ralentit ?',
  };

  const findResponse = (q) => {
    const l = q.toLowerCase();
    for (const k of Object.keys(responses)) {
      if (k !== 'default' && l.includes(k)) return responses[k];
    }
    return responses.default;
  };

  const send = (text) => {
    if (!text.trim()) return;
    setMessages(m => [...m, { role:'user', text }]);
    setInput('');
    setThinking(true);
    setTimeout(() => {
      setMessages(m => [...m, { role:'ai', text: findResponse(text) }]);
      setThinking(false);
    }, 900);
  };

  if (!open) return null;
  return (
    <div style={{
      position:'absolute', top:0, right:0, bottom:0, width:380, zIndex:30,
      background:'var(--window-bg)',
      backdropFilter:'blur(40px) saturate(180%)',
      WebkitBackdropFilter:'blur(40px) saturate(180%)',
      borderLeft:'0.5px solid var(--hairline)',
      display:'flex', flexDirection:'column',
      animation:'ai-in 240ms cubic-bezier(.2,.8,.2,1)',
    }}>
      <style>{`@keyframes ai-in{from{transform:translateX(20px);opacity:0}to{transform:none;opacity:1}}`}</style>
      <div style={{padding:'18px 18px 12px', display:'flex', alignItems:'center', gap:10}}>
        <div style={{width:30, height:30, borderRadius:8, background:'var(--accent)', display:'grid', placeItems:'center'}}>
          <Icon name="sparkle" size={16} color="#062018"/>
        </div>
        <div style={{flex:1}}>
          <div style={{fontSize:14, fontWeight:700}}>Assistant CleanMac</div>
          <div style={{fontSize:11, color:'var(--text-3)'}}>Local · Aucune donnée envoyée</div>
        </div>
        <button onClick={onClose} style={{background:'transparent', border:0, padding:6, cursor:'default'}}>
          <Icon name="close" size={16} color="var(--text-2)"/>
        </button>
      </div>

      <div style={{flex:1, overflow:'auto', padding:'8px 18px'}}>
        {messages.map((m, i) => (
          <div key={i} style={{display:'flex', flexDirection: m.role==='user' ? 'row-reverse':'row', marginBottom:12}}>
            <div style={{
              maxWidth:'85%', padding:'10px 14px', borderRadius:14,
              background: m.role==='user' ? 'var(--accent)' : 'rgba(0,0,0,0.05)',
              color: m.role==='user' ? '#062018' : 'var(--text-1)',
              fontSize:13, lineHeight:1.5, whiteSpace:'pre-wrap',
              borderTopRightRadius: m.role==='user'?4:14,
              borderTopLeftRadius: m.role==='user'?14:4,
            }} dangerouslySetInnerHTML={{__html: m.text.replace(/\*\*(.*?)\*\*/g,'<b>$1</b>')}}/>
          </div>
        ))}
        {thinking && (
          <div style={{display:'flex', gap:4, padding:'10px 14px', borderRadius:14,
            background:'rgba(0,0,0,0.05)', width:'fit-content', marginBottom:12}}>
            <div className="td"/>
            <div className="td" style={{animationDelay:'0.15s'}}/>
            <div className="td" style={{animationDelay:'0.3s'}}/>
            <style>{`
              .td{width:6px;height:6px;border-radius:50%;background:var(--text-3);animation:td-b 1s infinite ease-in-out}
              @keyframes td-b{0%,80%,100%{transform:scale(0.6);opacity:.4}40%{transform:scale(1);opacity:1}}
            `}</style>
          </div>
        )}
      </div>

      {messages.length <= 1 && (
        <div style={{padding:'0 18px 8px'}}>
          {suggestions.map(s => (
            <button key={s} onClick={()=>send(s)} style={{
              display:'block', width:'100%', textAlign:'left',
              padding:'8px 12px', margin:'4px 0', borderRadius:10,
              border:'0.5px solid var(--hairline)', background:'rgba(0,0,0,0.02)',
              fontSize:12.5, color:'var(--text-1)', fontFamily:'inherit', cursor:'default'
            }}>
              <span style={{color:'var(--text-3)', marginRight:6}}>›</span>{s}
            </button>
          ))}
        </div>
      )}

      <div style={{padding:'12px 18px 18px', borderTop:'0.5px solid var(--hairline)'}}>
        <div style={{display:'flex', alignItems:'center', gap:8,
          padding:'8px 10px', borderRadius:10, background:'rgba(0,0,0,0.05)',
          border:'0.5px solid var(--hairline)'}}>
          <Icon name="sparkle" size={14} color="var(--text-3)"/>
          <input value={input} onChange={e=>setInput(e.target.value)}
            onKeyDown={e=>{ if (e.key==='Enter') send(input); }}
            placeholder="Demande à CleanMac…" style={{
              flex:1, border:0, background:'transparent', outline:'none',
              fontSize:13, fontFamily:'inherit', color:'var(--text-1)'
            }}/>
          <button onClick={()=>send(input)} style={{
            background:'var(--accent)', color:'#062018', border:0, borderRadius:7,
            padding:'5px 10px', fontSize:11.5, fontWeight:600, cursor:'default'
          }}>↵</button>
        </div>
      </div>
    </div>
  );
}

// ──────────────────────────────────────────────────────────────────────────
// Toolbar
// ──────────────────────────────────────────────────────────────────────────
function Toolbar({ active, openAI, onMenubarToggle, menubarOpen }) {
  const TITLES = {
    dashboard: 'Vue d\'ensemble',
    scan: 'Smart Scan',
    cleanup: 'Fichiers inutiles',
    uninstaller: 'Désinstalleur',
    files: 'Volumineux & doublons',
    privacy: 'Confidentialité',
    maintenance: 'Maintenance',
    result: 'Nettoyage terminé',
    security: 'Sécurité',
    updates: 'Mises à jour',
    optimize: 'Performance',
    spacelens: 'Space Lens',
  };
  return (
    <div style={{
      height:44, display:'flex', alignItems:'center', gap:10,
      padding:'0 16px 0 16px',
      borderBottom:'0.5px solid var(--hairline-soft)',
      flexShrink:0
    }}>
      <div style={{fontSize:13, fontWeight:600, letterSpacing:'-0.005em', color:'var(--text-1)'}}>{TITLES[active]}</div>
      <div style={{flex:1}}/>
      {/* search */}
      <div style={{display:'flex', alignItems:'center', gap:6, padding:'4px 10px',
        borderRadius:7, background:'rgba(0,0,0,0.05)', border:'0.5px solid var(--hairline)',
        width:200, height:26}}>
        <Icon name="search" size={12} color="var(--text-3)"/>
        <span style={{fontSize:12, color:'var(--text-3)'}}>Rechercher</span>
        <div style={{flex:1}}/>
        <span style={{fontSize:10, fontWeight:600, padding:'1px 5px', borderRadius:4,
          background:'rgba(0,0,0,0.06)', color:'var(--text-3)', fontFamily:'ui-monospace, monospace'}}>⌘F</span>
      </div>
      <button onClick={onMenubarToggle} title="Aperçu menu bar" style={{
        width:26, height:26, borderRadius:6, border:'0.5px solid var(--hairline)',
        background: menubarOpen ? 'var(--accent)' : 'rgba(0,0,0,0.04)',
        display:'grid', placeItems:'center', cursor:'default'
      }}>
        <Icon name="chip" size={14} color={menubarOpen?'#062018':'var(--text-2)'}/>
      </button>
      <button onClick={openAI} title="Assistant IA (⌘K)" style={{
        width:26, height:26, borderRadius:6, border:'0.5px solid var(--hairline)',
        background:'rgba(0,0,0,0.04)', display:'grid', placeItems:'center', cursor:'default'
      }}>
        <Icon name="sparkle" size={14} color="var(--text-2)"/>
      </button>
    </div>
  );
}

// ──────────────────────────────────────────────────────────────────────────
// App root
// ──────────────────────────────────────────────────────────────────────────
function App() {
  const [t, setTweak] = useTweaks(TWEAK_DEFAULTS);
  const [active, setActive] = React.useState('dashboard');
  const [aiOpen, setAiOpen] = React.useState(false);
  const [menubarOpen, setMenubarOpen] = React.useState(false);
  const [scanState, setScanState] = React.useState('idle');

  // Apply accent + wallpaper via CSS vars
  React.useEffect(() => {
    const a = ACCENT_PRESETS[t.accent] || ACCENT_PRESETS.mint;
    document.documentElement.style.setProperty('--accent', a.c);
    document.documentElement.style.setProperty('--accent-rgb', a.rgb);
    document.documentElement.style.setProperty('--bg-desktop', WALLPAPERS[t.wallpaper] || WALLPAPERS.aurora);
    document.body.style.background = WALLPAPERS[t.wallpaper] || WALLPAPERS.aurora;
    document.documentElement.classList.toggle('dark', !!t.dark);
    if (t.density === 'compact') document.documentElement.style.fontSize = '13.5px';
    else if (t.density === 'comfy') document.documentElement.style.fontSize = '15px';
    else document.documentElement.style.fontSize = '14px';
  }, [t.accent, t.dark, t.density, t.wallpaper]);

  // ⌘K binding + menubar icon click + ⌘⇧K for quick clean
  React.useEffect(() => {
    const onKey = (e) => {
      if ((e.metaKey || e.ctrlKey) && e.shiftKey && (e.key === 'k' || e.key === 'K')) { e.preventDefault(); setActive('result'); return; }
      if ((e.metaKey || e.ctrlKey) && e.key === 'k') { e.preventDefault(); setAiOpen(o=>!o); }
      if (e.key === 'Escape') { setAiOpen(false); setMenubarOpen(false); }
    };
    const onMenubar = () => setMenubarOpen(o=>!o);
    window.addEventListener('keydown', onKey);
    document.addEventListener('cmp-toggle-menubar', onMenubar);
    return () => {
      window.removeEventListener('keydown', onKey);
      document.removeEventListener('cmp-toggle-menubar', onMenubar);
    };
  }, []);

  const goTo = (id) => { setActive(id); setAiOpen(false); };
  const runScan = () => { setActive('scan'); setScanState('running'); };
  const quickClean = () => { setActive('result'); };

  const stats = {
    health: 84,
    diskUsed: 207,
    diskTotal: 482,
  };

  const ctx = { stats, goTo, runScan, openAI:()=>setAiOpen(true), scanState, setScanState };

  const Screen = {
    dashboard: ScreenDashboard,
    scan: ScreenSmartScan,
    cleanup: ScreenCleanup,
    uninstaller: ScreenUninstaller,
    files: ScreenFiles,
    privacy: ScreenPrivacy,
    maintenance: ScreenMaintenance,
    result: ScreenResult,
    security: ScreenSecurity,
    updates: ScreenUpdates,
    optimize: ScreenOptimize,
    spacelens: ScreenSpaceLens,
  }[active] || ScreenDashboard;

  return (
    <>
      {/* Window */}
      <div style={{
        width: 1280, height: 820, borderRadius: 12,
        background:'var(--window-bg-solid)',
        backdropFilter:'blur(40px)',
        boxShadow:'0 0 0 0.5px rgba(0,0,0,0.3), 0 30px 90px rgba(0,0,0,0.45), 0 8px 24px rgba(0,0,0,0.25)',
        display:'flex', overflow:'hidden', position:'relative',
        fontSize:14,
      }}>
        <TrafficLights/>
        <Sidebar active={active} goTo={goTo} openAI={()=>setAiOpen(true)}/>
        <main style={{flex:1, display:'flex', flexDirection:'column', minWidth:0, position:'relative'}}>
          <Toolbar active={active} openAI={()=>setAiOpen(true)}
            onMenubarToggle={()=>setMenubarOpen(o=>!o)} menubarOpen={menubarOpen}/>
          <div style={{flex:1, overflow:'auto', padding:'20px 28px'}}>
            <Screen ctx={ctx}/>
          </div>
          <AIPanel open={aiOpen} onClose={()=>setAiOpen(false)} ctx={ctx}/>
          {t.showOnboarding && (
            <Onboarding onClose={()=>setTweak('showOnboarding', false)}
              onStart={()=>{ setTweak('showOnboarding', false); runScan(); }}/>
          )}
          {active !== 'scan' && active !== 'result' && !t.showOnboarding && (
            <QuickCleanFAB onClick={quickClean}/>
          )}
        </main>
      </div>

      {/* Menu bar widget that "drops" from the menubar */}
      <MenubarWidget open={menubarOpen} onClose={()=>setMenubarOpen(false)} openApp={goTo}/>

      {/* Tweaks */}
      <TweaksPanel>
        <TweakSection label="Apparence"/>
        <TweakColor label="Accent" value={t.accent}
          options={['mint','blue','violet','orange'].map(k => ACCENT_PRESETS[k].c)}
          onChange={(v) => {
            const k = Object.keys(ACCENT_PRESETS).find(k => ACCENT_PRESETS[k].c === v);
            setTweak('accent', k || 'mint');
          }}/>
        <TweakToggle label="Mode sombre" value={t.dark} onChange={(v)=>setTweak('dark', v)}/>
        <TweakRadio label="Densité" value={t.density}
          options={['compact','regular','comfy']} onChange={(v)=>setTweak('density', v)}/>
        <TweakSelect label="Fond d'écran" value={t.wallpaper}
          options={['aurora','graphite','sunset','forest']} onChange={(v)=>setTweak('wallpaper', v)}/>

        <TweakSection label="Navigation rapide"/>
        <TweakButton label="Vue d'ensemble" onClick={()=>goTo('dashboard')}/>
        <TweakButton label="Lancer Smart Scan" onClick={()=>runScan()}/>
        <TweakButton label="Fichiers inutiles" onClick={()=>goTo('cleanup')}/>
        <TweakButton label="Désinstalleur" onClick={()=>goTo('uninstaller')}/>
        <TweakButton label="Volumineux & doublons" onClick={()=>goTo('files')}/>
        <TweakButton label="Space Lens" onClick={()=>goTo('spacelens')}/>
        <TweakButton label="Sécurité" onClick={()=>goTo('security')}/>
        <TweakButton label="Confidentialité" onClick={()=>goTo('privacy')}/>
        <TweakButton label="Mises à jour" onClick={()=>goTo('updates')}/>
        <TweakButton label="Performance" onClick={()=>goTo('optimize')}/>
        <TweakButton label="Maintenance" onClick={()=>goTo('maintenance')}/>

        <TweakSection label="Extras"/>
        <TweakButton label="Assistant IA (⌘K)" onClick={()=>setAiOpen(o=>!o)}/>
        <TweakButton label="Widget barre menu" onClick={()=>setMenubarOpen(o=>!o)}/>
        <TweakButton label="Rejouer l'onboarding" onClick={()=>setTweak('showOnboarding', true)}/>
        <TweakButton label="Voir l'écran de résultat" onClick={()=>goTo('result')}/>
      </TweaksPanel>
    </>
  );
}

ReactDOM.createRoot(document.getElementById('root')).render(<App/>);

// Bind the menubar app icon
(function(){
  const slot = document.getElementById('cmp-menu-icon');
  if (!slot) return;
  slot.innerHTML = `<svg width="14" height="14" viewBox="0 0 64 64">
    <circle cx="32" cy="32" r="22" fill="none" stroke="#fff" stroke-width="3" stroke-opacity="0.7"/>
    <circle cx="32" cy="32" r="14" fill="none" stroke="#fff" stroke-width="3" stroke-opacity="0.9"/>
    <circle cx="32" cy="32" r="5" fill="#fff"/>
    <circle cx="32" cy="10" r="3" fill="#00F0B5"/>
  </svg>`;
  slot.style.display = 'inline-flex';
  slot.style.alignItems = 'center';
  slot.style.cursor = 'default';
  slot.addEventListener('click', () => {
    window.dispatchEvent(new CustomEvent('toggle-menubar'));
  });
})();
window.addEventListener('toggle-menubar', () => {
  // App listens via state, but expose via a small global hook:
  document.dispatchEvent(new CustomEvent('cmp-toggle-menubar'));
});
