-- Services
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local CultivationEvents = ReplicatedStorage:WaitForChild("CultivationEvents", 10)

-------------------------------------------------------------------------
-- CONFIG SAVE & AUTO-LOAD SYSTEM (DISCONNECT RECOVERY)
-------------------------------------------------------------------------
local CONFIG_FILE_NAME = "CultivationHub_SavedConfig.json"

local Config = {
    autoFarmActive = false,
    autoPillActive = false,
    autoBreakthroughActive = false,
    autoQiOrbActive = false,
    autoRealmActive = false,
    autoBodyActive = false,
    autoKillActive = false,
    selectedHerb = "Ginseng",
    selectedPill = "Qi Cultivation Pill",
    selectedQiZone = "Verdant Valley",
    selectedBodyZone = "Dusty Courtyard",
    flySpeed = 60,
    toggleKeyName = "RightShift",
    cu2 = {}
}

local function saveConfig()
    pcall(function()
        if writefile then
            writefile(CONFIG_FILE_NAME, HttpService:JSONEncode(Config))
        end
    end)
end

local function loadConfig()
    pcall(function()
        if isfile and readfile and isfile(CONFIG_FILE_NAME) then
            local decoded = HttpService:JSONDecode(readfile(CONFIG_FILE_NAME))
            if type(decoded) == "table" then
                for k, v in pairs(decoded) do
                    if Config[k] ~= nil and type(Config[k]) == type(v) then
                        Config[k] = v
                    end
                end
            end
        end
    end)
end

loadConfig()

-------------------------------------------------------------------------
-- CENTRALIZED STATE & CONSTANTS (ANTI-REGISTER LIMIT < 35 LOCALS)
-------------------------------------------------------------------------
local State = {
    isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled,
    autoFarmActive = Config.autoFarmActive,
    autoPillActive = Config.autoPillActive,
    autoBreakthroughActive = Config.autoBreakthroughActive,
    autoQiOrbActive = Config.autoQiOrbActive,
    autoRealmActive = Config.autoRealmActive,
    autoBodyActive = Config.autoBodyActive,
    autoKillActive = Config.autoKillActive,
    autoSkillKillActive = true,
    selectedHerb = Config.selectedHerb,
    selectedPill = Config.selectedPill,
    selectedQiZone = Config.selectedQiZone,
    selectedBodyZone = Config.selectedBodyZone,
    selectedTargetPlayerName = "None",
    flySpeed = Config.flySpeed or 60,
    minSpeed = 10,
    maxSpeed = 300,
    waitAtHerb = 0.8,
    blacklistDuration = 30,
    harvestedBlacklist = {},
    uiVisible = true,
    isMinimized = false,
    isTeleportingZone = false,
    activeFarmTween = nil,
    activeFarmVelocity = nil,
    toggleKey = Enum.KeyCode[Config.toggleKeyName] or Enum.KeyCode.RightShift,
    trialNodesData = {},
    lastSkillCycleTime = 0,
    skillIndex = 1,
    -- Pelacak Responsif Auto Realm (M) & Auto Body (P)
    lastQiServerTick = 0,
    lastBodyServerTick = 0,
    lastRealmTrigger = 0,
    lastBodyTrigger = 0,
    forceImmediateCultivate = false,
    activeRecipeSlot = 1,
    isBrewingWaitClaim = false,
    cauldronOrigCFrame = nil
}

local Constants = {
    HERBS_LIST = {"Ginseng", "Azure Lotus", "Golden Fern", "Violet Sage", "Verdant Moss"},
    PILLS_LIST = {"Bloodfury Pill", "Body Cultivation Pill", "Qi Cultivation Pill", "Vitality Pill"},
    QI_ZONES_LIST = {
        "Verdant Valley", "Misty Peaks", "Thunder Sanctum",
        "Celestial Expanse", "Shattered Heavens", "Dao Pinnacle", "Shattered Sky"
    },
    BODY_ZONES_LIST = {
        "Dusty Courtyard", "Iron Fist Dojo", "Stone Peak Arena",
        "Jade Colosseum", "Dragon Spine Ridge", "Heaven's Forge", "Immortal Crucible"
    },
    -- Koordinat Eksak Hasil Scanner Workspace
    EXACT_ZONE_COORDS = {
        -- Qi Zones
        ["Verdant Valley"]    = Vector3.new(-190, 5, 120),
        ["Misty Peaks"]       = Vector3.new(-1100, 112, 250),
        ["Thunder Sanctum"]   = Vector3.new(1274, 162, -395),
        ["Celestial Expanse"] = Vector3.new(640, 151, 1446),
        ["Shattered Heavens"] = Vector3.new(-1520, 182, -650),
        ["Dao Pinnacle"]      = Vector3.new(243, 1002, -785),
        ["Shattered Sky"]     = Vector3.new(-108, 730, -1064),
        -- Body Zones
        ["Dusty Courtyard"]    = Vector3.new(150, 4, 40),
        ["Iron Fist Dojo"]     = Vector3.new(795, 9, 330),
        ["Stone Peak Arena"]   = Vector3.new(1500, 7, 650),
        ["Jade Colosseum"]     = Vector3.new(-700, 39, 1500),
        ["Dragon Spine Ridge"] = Vector3.new(1521, 341, -1090),
        ["Heaven's Forge"]     = Vector3.new(1242, 8, 1449),
        ["Immortal Crucible"]  = Vector3.new(-1480, 90, 1280)
    },
    PILL_RECIPES = {
        ["Bloodfury Pill"] = {"Azure Lotus", "Golden Fern", "Violet Sage"},
        ["Body Cultivation Pill"] = {"Verdant Moss", "Verdant Moss", "Golden Fern"},
        ["Qi Cultivation Pill"] = {"Ginseng", "Ginseng", "Azure Lotus"},
        ["Vitality Pill"] = {"Ginseng", "Verdant Moss", "Violet Sage"}
    },
    HERB_YEAR_PRIORITY = {
        {pattern = "1000", score = 4},
        {pattern = "100",  score = 3},
        {pattern = "10",   score = 2},
        {pattern = "1",    score = 1}
    },
    REALM_MAX_LAYERS = {
        ["mortal body"] = 10, ["qi refining"] = 10, ["body tempering"] = 10,
        ["foundation establishment"] = 10, ["meridian opening"] = 10, ["core formation"] = 10,
        ["nascent soul"] = 10, ["soul transformation"] = 10, ["spirit severing"] = 10,
        ["dao seeking"] = 10, ["dao comprehension"] = 10, ["immortal ascension"] = 10,
        ["celestial"] = 10, ["heavenly refinement"] = 10, ["divine sense"] = 10,
        ["ten thousand laws"] = 10, ["tribulation crossing"] = 10, ["sacred body"] = 10,
        ["void traversal"] = 10, ["eternal spring"] = 10, ["heaven seizing"] = 10,
        ["ten thousand dao"] = 10, ["supreme elder"] = 10,
        ["true immortal"] = 5, ["dao ancestor"] = 5, ["void god"] = 5,
        ["heaven defying"] = 5, ["world piercing"] = 5, ["reality shatterer"] = 5,
        ["absolute sovereign"] = 5
    },
    ROMAN_TO_NUMBER = {
        ["I"] = 1, ["II"] = 2, ["III"] = 3, ["IV"] = 4, ["V"] = 5,
        ["VI"] = 6, ["VII"] = 7, ["VIII"] = 8, ["IX"] = 9, ["X"] = 10
    },
    COMBAT_SKILL_KEYS = {
        Enum.KeyCode.Z, Enum.KeyCode.X, Enum.KeyCode.C, Enum.KeyCode.V,
        Enum.KeyCode.G, Enum.KeyCode.H, Enum.KeyCode.T, Enum.KeyCode.Q
    }
}

local UI = {}

-------------------------------------------------------------------------
-- CU1: LOG DE DIAGNOSTICO (SALVAR TXT / COPIAR) PARA MELHORAR O SCRIPT
-- Tudo numa tabela global (nenhum local novo no topo). Guarda: ambiente (executor, celular ou PC, funcoes do
-- executor), erros com traceback (os loops reiniciam em vez de morrer calados), contadores por funcao, remotes
-- enviados e eventos do servidor recebidos, cliques na tela por metodo, teclas simuladas, toggles e o custo das
-- varreduras da tela. Botoes na aba "Logs".
-------------------------------------------------------------------------
CU_LOG={version="CU2.2",entries={},lastSeen={},errors={},errorOrder={},counts={},countOrder={},
    remotes={},remoteOrder={},toggles={},startedAt=os.clock(),startedStamp=os.date("%Y-%m-%d %H:%M:%S"),
    scans={},autoSave=true,autoSaveEvery=300,lastAutoSave=os.clock()}
function CU_LOG.onError(e) return debug.traceback(tostring(e),2) end
function CU_LOG.clean(text,limit)
    return (tostring(text or ""):gsub("[\r\n]+"," "):sub(1,limit or 300))
end
function CU_LOG.secs(s)
    s=math.max(0,math.floor((tonumber(s) or 0)+0.5))
    if s>=60 then return string.format("%dm%02ds",s//60,s%60) end
    return s.."s"
end
function CU_LOG.ago(t,now)
    if not t or t<=0 then return "zerado" end
    return string.format("%.1fs",(now or tick())-t)
end
function CU_LOG.add(level,area,message,minInterval,key)
    local msg=CU_LOG.clean(message,700)
    local k=tostring(level).."|"..tostring(area).."|"..tostring(key or msg)
    local now=os.clock()
    if now-(CU_LOG.lastSeen[k] or -1e9)<(minInterval or 0) then return end
    CU_LOG.lastSeen[k]=now
    local list=CU_LOG.entries
    list[#list+1]=string.format("[%s] [%s] [%s] %s",os.date("%H:%M:%S"),tostring(level),tostring(area),msg)
    if #list>6000 then table.remove(list,1) end
end
function CU_LOG.count(name,n)
    local c=CU_LOG.counts
    if c[name]==nil then c[name]=0;CU_LOG.countOrder[#CU_LOG.countOrder+1]=name end
    c[name]+=(n or 1)
end
function CU_LOG.error(area,message)
    local text=tostring(message or "")
    local key=tostring(area).."|"..(text:match("^[^\n]*") or ""):sub(1,140)
    local e=CU_LOG.errors[key]
    if not e then
        e={area=tostring(area),text=CU_LOG.clean(text,900),count=0,first=os.date("%H:%M:%S")}
        CU_LOG.errors[key]=e
        CU_LOG.errorOrder[#CU_LOG.errorOrder+1]=key
    end
    e.count+=1
    e.last=os.date("%H:%M:%S")
    CU_LOG.add("ERRO",area,text,10,"erro-"..key)
end
function CU_LOG.try(area,fn,...)
    local ok,err=xpcall(fn,CU_LOG.onError,...)
    if not ok then CU_LOG.error(area,err) end
    return ok,err
end
-- Loop de uma funcao: um erro vai para [ERROS] e o loop recomeca em 1s (antes a tarefa morria calada).
function CU_LOG.spawnLoop(name,body)
    return task.spawn(function()
        while true do
            local ok,err=xpcall(body,CU_LOG.onError)
            if ok then return end
            CU_LOG.error(name,err)
            CU_LOG.count(name..": reinicios por erro")
            task.wait(1)
        end
    end)
end
function CU_LOG.sent(remote)
    CU_LOG.count("Servidor (enviados): "..tostring(remote))
end
function CU_LOG.toggle(label,state)
    local text=tostring(label)
    CU_LOG.toggles[#CU_LOG.toggles+1]=string.format("[%s] %s = %s",os.date("%H:%M:%S"),text,state and "ON" or "OFF")
    if #CU_LOG.toggles>200 then table.remove(CU_LOG.toggles,1) end
    CU_LOG.add("TOGGLE",text,state and "ON" or "OFF")
end
function CU_LOG.click(method,btn,physical)
    local label=method and (physical and (method.." + mouse VIM") or method)
        or (physical and "mouse VIM" or "nenhum metodo (botao invisivel, menu aberto ou caixa de texto)")
    CU_LOG.count("Cliques na tela: "..label)
    local name="?"
    pcall(function()
        name=btn.Name
        if btn:IsA("TextButton") or btn:IsA("TextLabel") then name=name.." '"..CU_LOG.clean(btn.Text,30).."'" end
    end)
    CU_LOG.add("CLIQUE",label,name,5,"clique-"..label.."-"..name)
end
function CU_LOG.key(char,ok,err)
    CU_LOG.count("Teclas simuladas: "..tostring(char))
    if not ok then
        CU_LOG.count("Teclas simuladas: ERRO")
        CU_LOG.error("Tecla VIM "..tostring(char),err)
    end
end
function CU_LOG.herb(target,root,selected)
    if not target then
        CU_LOG.count("Ervas: nenhuma com prompt ativo (espera 1s)")
        CU_LOG.add("ERVA","busca","nenhuma '"..tostring(selected).."' com prompt ativo (coletadas, fora do stream ou nome diferente)",15)
        return
    end
    CU_LOG.count("Ervas: alvo escolhido")
    local p=target.Prompt
    CU_LOG.add("ERVA","alvo",string.format("%s | prompt '%s' / '%s' | %.0f studs",tostring(target.Object.Name),
        p and tostring(p.ObjectText) or "?",p and tostring(p.ActionText) or "?",(root.Position-target.Part.Position).Magnitude),3)
end
function CU_LOG.hud(h)
    if not h then return end
    CU_LOG.count("Breakthrough: leituras da tela")
    local key=string.format("%s|%s|%s|%s",tostring(h.realmName),tostring(h.currentLayer),tostring(h.trialMinigameActive),tostring(h.trialReadyBanner))
    local line=string.format("reino=%s camada=%s/%s Qi=%s%% minijogo=%s banner_pronto=%s botao=%s",tostring(h.realmName),
        tostring(h.currentLayer),tostring(h.maxLayers),tostring(h.qiPercent),tostring(h.trialMinigameActive),
        tostring(h.trialReadyBanner),tostring(h.breakthroughBtn~=nil))
    if key~=CU_LOG.hudLast then
        CU_LOG.hudLast=key
        CU_LOG.add("HUD","Breakthrough",line,0)
    else
        CU_LOG.add("HUD","Breakthrough",line,30,"hud-periodico")
    end
    if h.trialMinigameActive and not CU_LOG.trialAt then
        CU_LOG.trialAt=os.clock()
        CU_LOG.count("Breakthrough: minijogo aberto")
    elseif not h.trialMinigameActive and CU_LOG.trialAt then
        CU_LOG.add("TRIAL","fim",string.format("minijogo durou %.1fs",os.clock()-CU_LOG.trialAt),0)
        CU_LOG.trialAt=nil
    end
end
function CU_LOG.argText(...)
    local n=select("#",...)
    local parts={}
    for i=1,math.min(n,6) do
        local v=select(i,...)
        local t=typeof(v)
        if t=="Instance" then
            parts[#parts+1]=v.ClassName..":"..v.Name
        elseif t=="table" then
            local kv={}
            for k,val in pairs(v) do
                kv[#kv+1]=tostring(k).."="..CU_LOG.clean(tostring(val),24)
                if #kv>=6 then break end
            end
            parts[#parts+1]="{"..table.concat(kv,",").."}"
        else
            parts[#parts+1]=CU_LOG.clean(tostring(v),40)
        end
    end
    if n>6 then parts[#parts+1]="...+"..(n-6) end
    return CU_LOG.clean(table.concat(parts,", "),220)
end
-- Espiao passivo: cada RemoteEvent de CultivationEvents recebido do servidor (quantas vezes, quando, argumentos).
function CU_LOG.watchRemotes(folder)
    if not folder then
        CU_LOG.add("AVISO","Servidor","ReplicatedStorage.CultivationEvents nao apareceu em 10s: as funcoes que usam remotes nao vao funcionar")
        return
    end
    local names={}
    for _,r in ipairs(folder:GetDescendants()) do
        if r:IsA("RemoteEvent") then
            names[#names+1]=r.Name
            r.OnClientEvent:Connect(function(...)
                local rec=CU_LOG.remotes[r.Name]
                if not rec then
                    rec={count=0}
                    CU_LOG.remotes[r.Name]=rec
                    CU_LOG.remoteOrder[#CU_LOG.remoteOrder+1]=r.Name
                end
                rec.count+=1
                rec.last=os.date("%H:%M:%S")
                local ok,args=pcall(CU_LOG.argText,...)
                rec.args=ok and args or "?"
                if rec.count<=3 then CU_LOG.add("SERVIDOR",r.Name,"recebido #"..rec.count..": "..rec.args) end
            end)
        elseif r:IsA("RemoteFunction") then
            names[#names+1]=r.Name.."(funcao)"
        end
    end
    table.sort(names)
    CU_LOG.remoteList=names
    CU_LOG.add("INFO","Servidor",#names.." remotes em CultivationEvents: "..table.concat(names,", "))
end
function CU_LOG.env()
    local caps={}
    local function has(name,v) caps[#caps+1]=name.."="..((v~=nil and v~=false) and "sim" or "NAO") end
    local okE,ename,ever=pcall(function() if identifyexecutor then return identifyexecutor() end end)
    caps[#caps+1]="executor="..((okE and ename) and (tostring(ename)..(ever and (" "..tostring(ever)) or "")) or "desconhecido")
    has("getconnections",getconnections)
    has("firesignal",firesignal)
    has("fireproximityprompt",fireproximityprompt)
    has("firetouchinterest",firetouchinterest)
    has("writefile",writefile)
    has("readfile",readfile)
    has("isfile",isfile)
    has("delfile",delfile)
    has("setclipboard",setclipboard or toclipboard)
    has("gethui",gethui)
    has("syn.protect_gui",syn and syn.protect_gui)
    local vp=Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize
    local plat=string.format("toque=%s teclado=%s mouse=%s | isMobile do script=%s (janela %s) | tela=%s",
        tostring(UserInputService.TouchEnabled),tostring(UserInputService.KeyboardEnabled),tostring(UserInputService.MouseEnabled),
        tostring(State.isMobile),State.isMobile and "440x340" or "540x470",vp and string.format("%dx%d",vp.X,vp.Y) or "?")
    return table.concat(caps," | "),plat
end
function CU_LOG.activeList()
    local out={}
    for _,p in ipairs({{"autoFarmActive","Ervas"},{"autoPillActive","Pilulas"},{"autoRealmActive","Auto Realm"},
        {"autoBodyActive","Auto Body"},{"autoBreakthroughActive","Breakthrough"},{"autoQiOrbActive","Qi Orb"},{"autoKillActive","Auto Kill"}}) do
        if State[p[1]] then out[#out+1]=p[2] end
    end
    if CU2 then for _,n in ipairs(CU2.activeNames()) do out[#out+1]=n end end
    return #out>0 and table.concat(out,", ") or "nenhuma"
end
function CU_LOG.summary()
    local groups,order={},{}
    for _,name in ipairs(CU_LOG.countOrder) do
        local g,item=name:match("^(.-):%s*(.+)$")
        g=g or "Outros"
        item=item or name
        if not groups[g] then groups[g]={};order[#order+1]=g end
        local list=groups[g]
        list[#list+1]=item.." "..CU_LOG.counts[name]
    end
    local out={"[RESUMO POR FUNCAO: contadores desde o carregamento]"}
    if #order==0 then out[#out+1]="(nada contado ainda)" end
    for _,g in ipairs(order) do out[#out+1]=g..": "..table.concat(groups[g],", ") end
    return table.concat(out,"\n").."\n\n"
end
function CU_LOG.errorDump()
    if #CU_LOG.errorOrder==0 then return "[ERROS: nenhum erro do script registrado nesta sessao]\n\n" end
    local out={string.format("[ERROS: %d tipo(s); a funcao com erro pode ter parado ou reiniciado. Mande este TXT.]",#CU_LOG.errorOrder)}
    for _,key in ipairs(CU_LOG.errorOrder) do
        local e=CU_LOG.errors[key]
        out[#out+1]=string.format("[%s..%s] x%d %s: %s",e.first,e.last or e.first,e.count,e.area,e.text)
    end
    return table.concat(out,"\n").."\n\n"
end
function CU_LOG.remoteDump()
    if #CU_LOG.remoteOrder==0 then return "[EVENTOS DO SERVIDOR RECEBIDOS: nenhum ainda]\n\n" end
    local out={"[EVENTOS DO SERVIDOR RECEBIDOS: quantas vezes, ultimo horario e ultimos argumentos]"}
    for _,name in ipairs(CU_LOG.remoteOrder) do
        local r=CU_LOG.remotes[name]
        out[#out+1]=string.format("%s x%d (ultimo %s): %s",name,r.count,r.last or "?",r.args or "")
    end
    return table.concat(out,"\n").."\n\n"
end
function CU_LOG.scanText()
    local s=CU_LOG.scans
    if #s==0 then return "varredura da tela: ainda nao medida" end
    local last,total,maxMs=s[#s],0,0
    for _,x in ipairs(s) do
        total+=x.ms
        if x.ms>maxMs then maxMs=x.ms end
    end
    return string.format("varredura da tela: %d objetos, %d textos visiveis; uma varredura leva %.0f ms (media %.0f, maior %.0f, %d medicoes). Rotinas que varrem: Realm/Body a cada 0,15s, Pilulas 0,28s (varias buscas), Breakthrough 0,25s e a cada frame no minijogo, Qi Orb 0,12s",
        last.objects,last.texts,last.ms,total/#s,maxMs,#s)
end
function CU_LOG.dump(compact)
    local envCaps,envPlat=CU_LOG.env()
    local header=string.format("Hub | Diagnostico %s | %s\nCarregado em %s (%s de sessao) | Funcoes ligadas: %s\nSelecionados: erva=%s, pilula=%s, zona Qi=%s, zona corpo=%s, alvo=%s, velocidade de voo=%s\n[AMBIENTE] %s\n[AMBIENTE] %s\n[AMBIENTE] %s\n[AMBIENTE] remotes: %s\n\n",
        CU_LOG.version,os.date("%Y-%m-%d %H:%M:%S"),CU_LOG.startedStamp,CU_LOG.secs(os.clock()-CU_LOG.startedAt),CU_LOG.activeList(),
        tostring(State.selectedHerb),tostring(State.selectedPill),tostring(State.selectedQiZone),tostring(State.selectedBodyZone),
        tostring(State.selectedTargetPlayerName),tostring(State.flySpeed),
        envCaps,envPlat,CU_LOG.scanText(),CU_LOG.remoteList and table.concat(CU_LOG.remoteList,", ") or "?")
    local toggles=#CU_LOG.toggles>0 and ("[TOGGLES: liga/desliga em ordem]\n"..table.concat(CU_LOG.toggles,"\n").."\n\n") or ""
    local body=header..CU_LOG.errorDump()..(CU2 and CU2.safeSections() or "")..CU_LOG.summary()..CU_LOG.remoteDump()..toggles
    local list=CU_LOG.entries
    if not compact then
        return body.."[EVENTOS: "..#list.." linhas]\n"..table.concat(list,"\n")
    end
    local budget=math.max(2000,15000-#body)
    local recent,used={},0
    for i=#list,1,-1 do
        if used+#list[i]+1>budget then break end
        table.insert(recent,1,list[i])
        used+=#list[i]+1
    end
    return body.."[ULTIMOS EVENTOS: "..#recent.."/"..#list.."; o TXT tem todos]\n"..table.concat(recent,"\n")
end
function CU_LOG.save(name)
    if not writefile then return false,"este executor nao tem writefile" end
    local file=name or ("CultivationHub_log_"..os.date("%Y%m%d_%H%M%S")..".txt")
    local ok,err=pcall(writefile,file,CU_LOG.dump(false))
    if not ok then
        CU_LOG.error("Salvar TXT",err)
        return false,tostring(err)
    end
    CU_LOG.add("INFO","Log","TXT salvo: "..file,0)
    return true,file
end
function CU_LOG.copy()
    local clip=setclipboard or toclipboard
    if not clip then return false,"este executor nao tem setclipboard" end
    local text=CU_LOG.dump(true)
    local ok,err=pcall(clip,text)
    if not ok then
        CU_LOG.error("Copiar log",err)
        return false,tostring(err)
    end
    return true,#text
end
CU_LOG.add("INFO","Inicio","Cultivation Hub carregado com o log "..CU_LOG.version)

-------------------------------------------------------------------------
-- CU2: TUDO DO SCRIPT DO TOP76 ("Murim Hub V24") DENTRO DO NOSSO HUB
-- O jeito dele: mandar os comandos direto para o servidor (CombatHit, UseSkill, CauldronStartBrew,
-- BreakthroughMinigameResult...), sem tecla e sem clique na tela, por isso funciona no celular.
-- Tudo na tabela global CU2 (nenhum local novo no topo: limite de 200 registradores).
-- Aqui: configuracao salva, estado e as funcoes de calculo (testadas no validador). As abas "Combate" e
-- "Extra", os ouvintes do servidor e os loops ficam no fim do arquivo ("CU2: ABAS, OUVINTES E LOOPS").
-------------------------------------------------------------------------
CU2={version="CU2",s={},stopped=false,running={},conns={},tabs={},ui={labels={},setters={},mobRows={}},
    fights={},deaths={},events={},sentArgs={},expanded={},
    blacklist=setmetatable({},{__mode="k"}),herbCooldown=setmetatable({},{__mode="k"}),
    herbCounts={},herbCountsText="",tribs={},trib=nil,serverMsgs={},serverMsgOrder={},cauldronStatus="?",lastHerbPickAt=0,lastBrewNote="ainda nao tentou",
    mob=nil,mobBusy=false,targetPart=nil,event=nil,
    stats={hitAccepted=nil,trialSkips=0,trialClosed=0,trialOpen=0,soulTrips=0,soulCatches=0,soulGone=0,soulHerbs=0,
        brewsStarted=0,brewsDone=0,herbsOk=0,herbsMaybe=0,herbsFail=0,clashEvents=0,clashHits=0,afk=0},
    NO_DAMAGE_SECS=8,
    defaults={mobFarm=false,turbo=true,aoe=true,skills=false,offset=3,sectClash=false,
        skipTrial=true,blindBreak=false,bodyBreak=false,tribulation=true,soul=false,orbTouch=false,
        herb2=false,herbFilter=1,streamer=false,brew=false,brewRecipe=1,brewYear=1,
        dailyAuto=false,antiAfk=true,selectedMobs={}},
    LABEL_ORDER={"mobFarm","skills","sectClash","blindBreak","bodyBreak","tribulation","soul","orbTouch","herb2","streamer","brew","dailyAuto"},
    LABELS={mobFarm="Farm monstros",skills="Skills servidor",sectClash="Sect Clash",blindBreak="Breakthrough as cegas",
        bodyBreak="Body Breakthrough servidor",tribulation="Tribulation",soul="Soul Projection",orbTouch="Orbs servidor",
        herb2="Ervas mapa todo",streamer="Streamer",brew="Pilulas servidor",dailyAuto="Daily auto"},
    EXCLUSIVE={herb2=true,brew=true},
    MOB_CONTAINERS={"BanditCamp","CultivatorCamps","WorldBoss","BlockingDummy","TrainingDummy"},
    SKILL_KEYS={"Z","X","C","V"},
    HERB_NAMES={"Ginseng","Azure Lotus","Verdant Moss","Golden Fern","Violet Sage"},
    HERB_FILTERS={"Todas (1000 anos primeiro)","So 1000 anos","So a erva da aba Auto"},
    BREW_RECIPES={"Pilula da aba Auto","Qualquer erva (3 iguais)"},
    BREW_YEARS={0,10,100,1000},
    TOP76_REMOTES={"CombatHit","UseSkill","MapEvent","CollectHerb","HerbInventoryUpdate","CauldronStartBrew","CauldronClaim",
        "CauldronStoke","CauldronStateUpdate","Breakthrough","BreakthroughMinigameResult","StartBreakthroughMinigame",
        "BodyBreakthrough","BodyBreakthroughCutsceneDone","Tribulation","SoulProjection","SpiritWorld","CultivationOrbClicked",
        "ZoneChanged","ClaimReward","StartMeditate","StartPushup","CultivateResumed"},
    TRIB_LEAD=0.015,
    OFFSETS={
        {"Embaixo da terra, bem fundo (-12)",Vector3.new(0,-12,0)},
        {"Embaixo da terra, fundo (-8)",Vector3.new(0,-8,0)},
        {"Embaixo da terra, medio (-5)",Vector3.new(0,-5,0)},
        {"Embaixo da terra, raso (-3)",Vector3.new(0,-3,0)},
        {"Em cima, baixo (+4)",Vector3.new(0,4,0)},
        {"Em cima, medio (+6)",Vector3.new(0,6,0)},
        {"Em cima, alto (+10)",Vector3.new(0,10,0)},
        {"Atras, perto (3)",Vector3.new(0,0,3)},
        {"Atras, longe (5)",Vector3.new(0,0,5)},
        {"No meio do monstro (0)",Vector3.new(0,0,0)}},
    FALLBACK_POINTS={Vector3.new(0,120,0),Vector3.new(-350,140,2200),Vector3.new(900,130,2100),
        Vector3.new(-2800,150,-2100),Vector3.new(2500,1500,1000)}}
CU2.HERB_IDS={}
for i,name in ipairs(CU2.HERB_NAMES) do
    CU2.HERB_IDS[name]=i
    CU2.HERB_IDS[(name:lower():gsub("[%s_%-]",""))]=i
end

-- Configuracao: Config.cu2 (salva no mesmo JSON do hub). Valor salvo so vale se tiver o mesmo tipo do padrao.
function CU2.loadSettings(saved)
    local s={}
    for k,v in pairs(CU2.defaults) do
        local value=nil
        if type(saved)=="table" then value=saved[k] end
        if value~=nil and type(value)==type(v) then s[k]=value else s[k]=v end
    end
    if type(s.selectedMobs)~="table" or s.selectedMobs==CU2.defaults.selectedMobs then s.selectedMobs={} end
    for _,p in ipairs({{"offset",#CU2.OFFSETS},{"herbFilter",#CU2.HERB_FILTERS},{"brewRecipe",#CU2.BREW_RECIPES},{"brewYear",#CU2.BREW_YEARS}}) do
        s[p[1]]=math.clamp(math.floor(tonumber(s[p[1]]) or 1),1,p[2])
    end
    CU2.s=s
    Config.cu2=s
    return s
end
CU2.loadSettings(Config.cu2)

function CU2.on(key) return (not CU2.stopped) and CU2.s[key]==true end
function CU2.save()
    Config.cu2=CU2.s
    saveConfig()
end
function CU2.track(conn)
    CU2.conns[#CU2.conns+1]=conn
    return conn
end
function CU2.isV3(v) return typeof(v)=="Vector3" end

-- Texto curto de qualquer valor (tabelas ate 2 niveis), para o TXT mostrar exatamente o que foi enviado/recebido.
function CU2.describe(v,depth)
    local t=typeof(v)
    if t=="Instance" then return v.ClassName..":"..v.Name end
    if t=="Vector3" then return string.format("(%.0f, %.0f, %.0f)",v.X,v.Y,v.Z) end
    if t=="table" then
        depth=depth or 0
        if depth>=2 then return "{...}" end
        local parts,n={},0
        for k,val in pairs(v) do
            n+=1
            if n>10 then parts[#parts+1]="..." break end
            parts[#parts+1]=tostring(k).."="..CU2.describe(val,depth+1)
        end
        return "{"..table.concat(parts,",").."}"
    end
    if t=="number" then return (v==math.floor(v)) and tostring(v) or string.format("%.4f",v) end
    return CU_LOG.clean(tostring(v),60)
end
function CU2.describeArgs(...)
    local out={}
    for i=1,select("#",...) do out[#out+1]=CU2.describe((select(i,...))) end
    return CU_LOG.clean(table.concat(out,", "),400)
end

-- Remotes: todo envio passa aqui (conta no [RESUMO], mostra os 3 primeiros envios com os argumentos, erro vai para [ERROS]).
function CU2.remote(name)
    return CultivationEvents and CultivationEvents:FindFirstChild(name)
end
function CU2.fire(name,...)
    local r=CU2.remote(name)
    if not r then
        CU_LOG.count("Servidor (remote nao existe): "..name)
        CU_LOG.add("AVISO","CU2","o remote "..name.." nao existe em CultivationEvents (o jogo mudou o nome?)",60)
        return false
    end
    CU_LOG.sent(name)
    local n=(CU2.sentArgs[name] or 0)+1
    CU2.sentArgs[name]=n
    if n<=3 then CU_LOG.add("ENVIADO",name,"#"..n..": "..CU2.describeArgs(...)) end
    local ok,err=pcall(r.FireServer,r,...)
    if not ok then CU_LOG.error("Enviar "..name,err) end
    return ok
end
function CU2.remoteCheck()
    local out={}
    for _,name in ipairs(CU2.TOP76_REMOTES) do out[#out+1]=name.."="..(CU2.remote(name) and "sim" or "NAO") end
    return table.concat(out,", ")
end

function CU2.char()
    local char=LocalPlayer.Character
    if not char then return nil end
    local hrp=char:FindFirstChild("HumanoidRootPart")
    local hum=char:FindFirstChildOfClass("Humanoid")
    if hrp and hum then return char,hrp,hum end
    return nil
end

-- Quem esta movendo o personagem agora. Auto Realm/Body e o farm de ervas da aba Auto esperam enquanto isso.
function CU2.busy()
    if CU2.stopped then return nil end
    if CU2.event and CU2.on("sectClash") then return "Sect Clash" end
    if CU2.mobBusy then return "farm de monstros" end
    if CU2.on("herb2") then return "ervas mapa todo" end
    if LocalPlayer:GetAttribute("SoulProjecting")==true then return "Soul Projection" end
    return nil
end
function CU2.herbBlocked()
    if CU2.stopped then return nil end
    local r=(CU2.event and CU2.on("sectClash") and "Sect Clash") or (CU2.mobBusy and "farm de monstros")
        or (LocalPlayer:GetAttribute("SoulProjecting")==true and "Soul Projection") or nil
    if r and State.autoFarmActive then CU_LOG.count("Ervas: pausado ("..r..")") end
    return r
end
function CU2.activeNames()
    local out={}
    for _,k in ipairs(CU2.LABEL_ORDER) do
        if CU2.on(k) then out[#out+1]=CU2.LABELS[k] end
    end
    return out
end
function CU2.offsetText() return CU2.OFFSETS[CU2.s.offset][1] end
function CU2.offsetVec() return CU2.OFFSETS[CU2.s.offset][2] end
function CU2.herbName(id) return CU2.HERB_NAMES[id] or tostring(id) end
function CU2.countKeys(t)
    local n=0
    for _ in pairs(t or {}) do n+=1 end
    return n
end

-- Uma funcao nossa e a do Top76 que fazem a mesma coisa nao rodam juntas.
function CU2.setToggle(key,val)
    CU2.s[key]=val
    CU2.save()
    local setter=CU2.ui.setters[key]
    if setter then setter(val) end
end
function CU2.exclusive(kind)
    if kind=="herb2" and State.autoFarmActive then
        State.autoFarmActive=false
        Config.autoFarmActive=false
        if UI.SetHerbSwitch then UI.SetHerbSwitch(false) end
        CU2.cancelHerbTween()
        saveConfig()
        CU_LOG.add("INFO","CU2","'autofarm herb' (aba Auto) desligado porque 'Auto Ervas mapa todo' ligou",0)
    elseif kind=="brew" and State.autoPillActive then
        State.autoPillActive=false
        Config.autoPillActive=false
        if UI.SetPillSwitch then UI.SetPillSwitch(false) end
        saveConfig()
        CU_LOG.add("INFO","CU2","'Autocreate pills' (aba Auto) desligado porque 'Auto Pilulas pelo servidor' ligou",0)
    elseif kind=="herb" and CU2.s.herb2 then
        CU2.setToggle("herb2",false)
        CU_LOG.add("INFO","CU2","'Auto Ervas mapa todo' desligado porque 'autofarm herb' (aba Auto) ligou",0)
    elseif kind=="pill" and CU2.s.brew then
        CU2.setToggle("brew",false)
        CU_LOG.add("INFO","CU2","'Auto Pilulas pelo servidor' desligado porque 'Autocreate pills' (aba Auto) ligou",0)
    end
end
function CU2.cancelHerbTween()
    if State.activeFarmTween then
        CU_LOG.try("CU2 cancelar voo da erva",function() State.activeFarmTween:Cancel() end)
        State.activeFarmTween=nil
    end
    if State.activeFarmVelocity then
        CU_LOG.try("CU2 remover BodyVelocity da erva",function() State.activeFarmVelocity:Destroy() end)
        State.activeFarmVelocity=nil
    end
end

-- Ervas: chave do inventario do servidor "tipo_ano" (ex.: "1_1000" ou "Ginseng_1000").
-- Devolve o ID da erva (1 Ginseng, 2 Azure Lotus, 3 Verdant Moss, 4 Golden Fern, 5 Violet Sage), o ano e o valor
-- de herbType que o servidor espera de volta (o mesmo texto/numero da chave, como o Top76 manda).
function CU2.parseHerbKey(key)
    local rawType,yr=string.match(tostring(key),"^(.+)_(%d+)$")
    if not rawType then return nil end
    local num=tonumber(rawType)
    local id=num or CU2.HERB_IDS[rawType] or CU2.HERB_IDS[(rawType:lower():gsub("[%s_%-]",""))] or rawType
    return id,tonumber(yr) or 0,num or rawType
end
function CU2.herbEntries(counts,minYear)
    local list={}
    if type(counts)~="table" then return list end
    for key,count in pairs(counts) do
        local id,yr,sendType=CU2.parseHerbKey(key)
        local c=tonumber(count) or 0
        if id~=nil and c>0 and yr>=(minYear or 0) then
            list[#list+1]={id=id,year=yr,send=sendType,count=c,key=tostring(key)}
        end
    end
    -- Ano mais baixo primeiro: guarda as ervas raras (para pilula melhor, suba o "ano minimo").
    table.sort(list,function(a,b)
        if a.year~=b.year then return a.year<b.year end
        return a.key<b.key
    end)
    return list
end
function CU2.herbCountText()
    local list=CU2.herbEntries(CU2.herbCounts,0)
    if #list==0 then
        return next(CU2.herbCounts)==nil and "(o servidor ainda nao mandou)" or ("formato desconhecido: "..CU2.describe(CU2.herbCounts))
    end
    local out={}
    for _,e in ipairs(list) do out[#out+1]=string.format("%s %da x%d",CU2.herbName(e.id),math.floor(e.year),math.floor(e.count)) end
    return table.concat(out,", ")
end
function CU2.setHerbCounts(data,source)
    CU2.herbCounts=data
    local text=CU2.herbCountText()
    if text~=CU2.herbCountsText then
        CU2.herbCountsText=text
        CU_LOG.add("ERVAS","inventario",source..": "..text,20,"inventario")
    end
end
-- Monta o pedido do CauldronStartBrew: {{herbType=..., year=...} x3}. Devolve nil e o motivo quando nao da.
function CU2.buildBrew(counts,recipeIdx,minYear,pillName)
    minYear=minYear or 0
    if type(counts)~="table" or next(counts)==nil then
        return nil,"o inventario de ervas ainda nao chegou do servidor (colete 1 erva ou abra o caldeirao uma vez)"
    end
    local entries=CU2.herbEntries(counts,minYear)
    if recipeIdx==2 then
        for _,e in ipairs(entries) do
            if e.count>=3 then
                return {{herbType=e.send,year=e.year},{herbType=e.send,year=e.year},{herbType=e.send,year=e.year}},
                    string.format("3x %s %d anos",CU2.herbName(e.id),math.floor(e.year))
            end
        end
        return nil,string.format("nenhuma erva com 3 ou mais (ano >= %d)",math.floor(minYear))
    end
    local recipe=Constants.PILL_RECIPES[pillName]
    if not recipe then return nil,"receita desconhecida: "..tostring(pillName) end
    local need,order={},{}
    for _,name in ipairs(recipe) do
        local id=CU2.HERB_IDS[name]
        if not id then return nil,"erva sem ID: "..tostring(name) end
        if not need[id] then
            need[id]=0
            order[#order+1]=id
        end
        need[id]+=1
    end
    local payload,parts={},{}
    for _,id in ipairs(order) do
        local want,got=need[id],0
        for _,e in ipairs(entries) do
            if e.id==id and got<want then
                local take=math.min(e.count,want-got)
                for _=1,take do payload[#payload+1]={herbType=e.send,year=e.year} end
                parts[#parts+1]=string.format("%dx %s %d anos",math.floor(take),CU2.herbName(id),math.floor(e.year))
                got+=take
            end
        end
        if got<want then
            return nil,string.format("falta %s para %s: precisa %d, tem %d com ano >= %d",CU2.herbName(id),tostring(pillName),want,math.floor(got),math.floor(minYear))
        end
    end
    return payload,table.concat(parts,", ")
end
function CU2.setCauldronStatus(st)
    local old=CU2.cauldronStatus
    if st==old then return end
    CU2.cauldronStatus=st
    CU_LOG.add("CALDEIRAO","status",tostring(old).." -> "..st,0)
    CU_LOG.count("Caldeirao: status "..st)
    if old=="brewing" then CU2.stats.brewsDone+=1 end
end

-- Ano da erva: atributo HerbYear/Year (Top76) ou o numero antes de "Year"/"Yr" no nome ou no texto do prompt.
function CU2.herbYear(part,prompt)
    local y=part:GetAttribute("HerbYear") or part:GetAttribute("Year")
    if type(y)=="number" then return y end
    local texts={part.Name,part.Parent and part.Parent.Name or "",prompt and prompt.ObjectText or "",prompt and prompt.ActionText or ""}
    for _,t in ipairs(texts) do
        local n=tostring(t):match("(%d+)%s*%-?%s*[Yy]")
        if n then return tonumber(n) end
    end
    return 1
end
function CU2.herbIsSelected(part,prompt,herbName)
    local want=tostring(herbName or ""):lower()
    if want=="" then return false end
    local ht=part:GetAttribute("HerbType")
    if ht~=nil and (ht==CU2.HERB_IDS[herbName] or tostring(ht):lower()==want) then return true end
    for _,t in ipairs({part.Name,part.Parent and part.Parent.Name or "",prompt and prompt.ObjectText or ""}) do
        if tostring(t):lower():find(want,1,true) then return true end
    end
    return false
end

-- Luta: "sem dano" quando o HP do alvo nao cai por NO_DAMAGE_SECS (cura do monstro nao engana: compara com a leitura anterior).
function CU2.fightCheck(f,hp,now)
    if hp<(f.prevHp or hp)-0.01 then
        if not f.firstDropAt then
            f.firstDropAt=now
            f.hitsAtFirstDrop=f.hits or 0
        end
        f.lastDropAt=now
    end
    f.prevHp=hp
    if hp<(f.minHp or hp) then f.minHp=hp end
    if now-(f.lastDropAt or now)>=CU2.NO_DAMAGE_SECS then return "sem dano" end
    return nil
end

function CU2.onMapEvent(action,payload)
    CU_LOG.add("SECT","MapEvent",tostring(action)..": "..CU2.describe(payload),0)
    if action=="start" and type(payload)=="table" and CU2.isV3(payload.centre) then
        CU2.event={name=tostring(payload.name or "Sect Clash"),centre=payload.centre,
            endsAt=tonumber(payload.endsAt) or (Workspace:GetServerTimeNow()+300),
            teams=type(payload.teams)=="table" and payload.teams or {},
            order=type(payload.order)=="table" and payload.order or {"Alliance","Cult"},
            side=type(payload.side)=="string" and payload.side or nil,startedAt=os.clock(),hits=0}
        CU2.stats.clashEvents+=1
        CU2.events[#CU2.events+1]=string.format("%s comecou: %s, centro %s, lado %s, times %s",os.date("%H:%M:%S"),
            CU2.event.name,CU2.describe(payload.centre),tostring(CU2.event.side),CU2.describe(CU2.event.teams))
    elseif action=="side" and type(payload)=="string" and CU2.event then
        CU2.event.side=payload
        CU2.events[#CU2.events+1]=os.date("%H:%M:%S").." entrou no lado "..payload
    elseif action=="end" or action=="cancel" then
        if CU2.event then
            CU2.events[#CU2.events+1]=string.format("%s %s: durou %s, %d golpes enviados",os.date("%H:%M:%S"),tostring(action),
                CU_LOG.secs(os.clock()-CU2.event.startedAt),CU2.event.hits)
        end
        CU2.event=nil
    end
    if #CU2.events>40 then table.remove(CU2.events,1) end
end
function CU2.enemyFighter(ev)
    local order=ev.order or {}
    local enemySide=(ev.side==order[1]) and order[2] or order[1]
    local info=ev.teams and ev.teams[enemySide]
    return type(info)=="table" and info.fighter or nil,enemySide
end

function CU2.onDeath(char)
    local root=char and char:FindFirstChild("HumanoidRootPart")
    local f=CU2.mob
    local line=string.format("%s morreu | ligado: %s | alvo: %s | Sect Clash: %s | posicao %s",
        os.date("%H:%M:%S"),CU_LOG.activeList(),
        f and string.format("%s HP %d/%d (%d golpes)",f.name,math.floor(f.prevHp or 0),math.floor(f.maxHp or 0),f.hits or 0) or "nenhum",
        CU2.event and CU2.event.name or "nao",root and CU2.describe(root.Position) or "?")
    CU2.deaths[#CU2.deaths+1]=line
    if #CU2.deaths>20 then table.remove(CU2.deaths,1) end
    CU_LOG.count("Mortes: personagem morreu")
    CU_LOG.add("MORTE","personagem",line,0)
end

-- Tribulacao: o servidor manda "gather" (comeca), um "bolt" por raio (numero do raio, horario exato do raio no relogio
-- do servidor, tipo, janela), "strike" (resultado do raio: miss/...) e "end" (sucesso, numero). O Top76 mandava sempre
-- ("absorb", 14, -0.0143): raio 14 num tempo fixo, por isso todo raio dava miss. Aqui cada raio e respondido com o
-- numero dele, TRIB_LEAD segundos antes do horario, com a diferenca real de tempo (como o -0.0143 dele).
function CU2.newTrib(kind,tier)
    CU2.trib={startStamp=os.date("%H:%M:%S"),startAt=os.clock(),kind=tostring(kind or "?"),tier=tostring(tier or "?"),
        bolts={},order={},hits=0,misses=0,answered=0}
    return CU2.trib
end
function CU2.onTribulation(action,player,...)
    if player~=LocalPlayer then return nil end
    action=tostring(action)
    CU_LOG.count("Tribulacao: evento "..action)
    CU_LOG.add("TRIBULACAO",action,CU2.describeArgs(...),0)
    if action=="gather" then
        local _,tier,kind=...
        CU2.newTrib(kind,tier)
    elseif action=="bolt" then
        local idx,hitTime,kind,window=...
        local t=CU2.trib or CU2.newTrib("?","?")
        local ht=tonumber(hitTime)
        local b={idx=idx,hitTime=ht,kind=tostring(kind),window=window,lead=ht and (ht-Workspace:GetServerTimeNow()) or nil}
        t.bolts[idx]=b
        t.order[#t.order+1]=idx
        return b
    elseif action=="strike" then
        local idx,result=...
        result=tostring(result)
        CU_LOG.count("Tribulacao: raio "..result)
        local t=CU2.trib
        if t then
            local b=t.bolts[idx]
            if b then b.result=result end
            if result=="miss" then t.misses+=1 else t.hits+=1 end
        end
    elseif action=="end" then
        local success,value=...
        local t=CU2.trib or CU2.newTrib("?","?")
        local per={}
        for _,i in ipairs(t.order) do
            local b=t.bolts[i]
            per[#per+1]=string.format("%s:%s(%s%s)",tostring(i),b.result or "?",b.answer or "nao respondido",
                b.offset and string.format(" %+.3fs",b.offset) or "")
        end
        local line=string.format("%s %s nivel %s: %d raios, %d respondidos, %d acertos, %d erros | fim: %s (%s) em %.0fs | por raio: %s",
            t.startStamp,t.kind,t.tier,#t.order,t.answered,t.hits,t.misses,success==true and "PASSOU" or "FALHOU",tostring(value),
            os.clock()-t.startAt,#per>0 and table.concat(per,", ") or "-")
        CU2.tribs[#CU2.tribs+1]=line
        if #CU2.tribs>10 then table.remove(CU2.tribs,1) end
        CU_LOG.count(success==true and "Tribulacao: passou" or "Tribulacao: falhou")
        CU_LOG.add("TRIBULACAO","fim",line,0)
        CU2.trib=nil
    end
    return nil
end
function CU2.answerBolt(b)
    local t=CU2.trib
    if not CU2.on("tribulation") then
        b.answer=CU2.stopped and "janela fechada (X)" or "Auto Tribulation desligado"
        CU_LOG.add("TRIBULACAO","raio "..tostring(b.idx),"NAO respondido: "..b.answer,0)
        return false
    end
    if not b.hitTime then
        b.answer="sem horario no evento"
        CU_LOG.add("TRIBULACAO","raio "..tostring(b.idx),"NAO respondido: o evento bolt veio sem horario",0)
        return false
    end
    local target=b.hitTime-CU2.TRIB_LEAD
    local t0=os.clock()
    while Workspace:GetServerTimeNow()<target and os.clock()-t0<10 do task.wait() end
    local offset=Workspace:GetServerTimeNow()-b.hitTime
    CU2.fire("Tribulation","absorb",b.idx,offset)
    b.offset=offset
    b.answer="absorb"
    if t then t.answered+=1 end
    CU_LOG.count("Tribulacao: absorb enviado no horario do raio")
    CU_LOG.add("TRIBULACAO","raio "..tostring(b.idx),string.format("absorb enviado com %+.3fs do horario (o evento chegou %.2fs antes; tipo %s, janela %s)",
        offset,b.lead or -1,b.kind,tostring(b.window)),0)
    return true
end
function CU2.onDeathCause(cause)
    local line=string.format("%s causa da morte (servidor): %s%s | ligado: %s",os.date("%H:%M:%S"),tostring(cause),
        CU2.trib and string.format(" | tribulacao em andamento: %d raios, %d acertos, %d erros",#CU2.trib.order,CU2.trib.hits,CU2.trib.misses) or "",
        CU_LOG.activeList())
    CU2.deaths[#CU2.deaths+1]=line
    if #CU2.deaths>20 then table.remove(CU2.deaths,1) end
    CU_LOG.count("Mortes: causa "..tostring(cause))
    CU_LOG.add("MORTE","causa",line,0)
end
-- Mensagens do servidor (GlobalMessage): agrupadas com os numeros trocados por #, com um exemplo e quantas vezes.
function CU2.onServerMessage(text)
    text=CU_LOG.clean(tostring(text),200)
    local key=text:gsub("%d+","#")
    local m=CU2.serverMsgs[key]
    if not m then
        m={count=0}
        CU2.serverMsgs[key]=m
        CU2.serverMsgOrder[#CU2.serverMsgOrder+1]=key
        CU_LOG.add("SERVIDOR","mensagem",text,0)
    end
    m.count+=1
    m.last=os.date("%H:%M:%S")
    m.example=text
end

-- Plataforma invisivel embaixo do personagem (Top76): segura o personagem nas posicoes embaixo da terra.
function CU2.getPlatform()
    local p=CU2.platform
    if p and p.Parent then return p end
    p=Instance.new("Part")
    p.Name="CU2Plataforma"
    p.Size=Vector3.new(8,1,8)
    p.Anchored=true
    p.Transparency=1
    p.CanCollide=true
    p.CFrame=CFrame.new(0,9999,0)
    p.Parent=Workspace
    CU2.platform=p
    return p
end
function CU2.parkPlatformIfIdle()
    if CU2.platform and not CU2.mobBusy and not CU2.on("herb2") and not (CU2.event and CU2.on("sectClash")) then
        CU2.platform.CFrame=CFrame.new(0,9999,0)
    end
end
-- Teleporte do Top76: ate 38 studs vai direto; mais longe, passos de 36 studs a cada 0,1s (~360 studs/s), abaixo dos
-- limites do anti-cheat do jogo citados por ele (MovementGuardRules: SLACK 40, MAX_FLAT_SPEED 400).
-- Correcao: carrega a area com LocalPlayer:RequestStreamAroundAsync (ele chamava no workspace, que nao tem esse metodo).
function CU2.safeTeleport(hrp,targetCFrame,lookPart,abortFn,platformDrop)
    if not hrp or not targetCFrame then return false end
    local targetPos=targetCFrame.Position
    if targetPos.Magnitude<5 then return false end
    local platform=CU2.getPlatform()
    local drop=platformDrop or -1
    local startPos=hrp.Position
    local flat=Vector2.new(targetPos.X-startPos.X,targetPos.Z-startPos.Z).Magnitude
    if flat>300 then
        local ok,err=pcall(function() LocalPlayer:RequestStreamAroundAsync(targetPos,2) end)
        if not ok then CU_LOG.error("Carregar area (RequestStreamAroundAsync)",err) end
    end
    local function apply(cf)
        platform.CFrame=cf*CFrame.new(0,drop,0)
        hrp.AssemblyLinearVelocity=Vector3.zero
        hrp.AssemblyAngularVelocity=Vector3.zero
        if lookPart and lookPart.Parent then
            hrp.CFrame=CFrame.new(cf.Position,lookPart.Position+Vector3.new(0.01,0,0.01))
        else
            hrp.CFrame=cf
        end
    end
    if flat<=38 then
        apply(targetCFrame)
        return true
    end
    local steps=math.ceil(flat/36)
    local rot=targetCFrame-targetCFrame.Position
    CU_LOG.count("Movimento: viagens em passos de 36 studs")
    CU_LOG.add("MOVIMENTO","passos",string.format("%.0f studs em %d passos (~%.1fs)",flat,steps,steps*0.1),5)
    for i=1,steps do
        if not hrp.Parent then return false end
        if abortFn and abortFn() then return false end
        apply(CFrame.new(startPos:Lerp(targetPos,i/steps))*rot)
        task.wait(0.10)
    end
    return true
end

-- Monstros: modelos com Humanoid dentro dos containers do Top76 (ate 3 niveis de pastas).
function CU2.collectMobModels(obj,depth,out)
    if obj:IsA("Model") and obj:FindFirstChildOfClass("Humanoid") then
        out[#out+1]=obj
        return
    end
    if depth>=3 then return end
    for _,ch in ipairs(obj:GetChildren()) do
        if ch:IsA("Model") or ch:IsA("Folder") then CU2.collectMobModels(ch,depth+1,out) end
    end
end
function CU2.scanMobs(onlySelected)
    local list,names,seen,ctext={},{},{},{}
    local now=os.clock()
    for _,cname in ipairs(CU2.MOB_CONTAINERS) do
        local c=Workspace:FindFirstChild(cname)
        local alive=0
        if c then
            local models={}
            CU2.collectMobModels(c,0,models)
            for _,model in ipairs(models) do
                if model~=LocalPlayer.Character and not Players:GetPlayerFromCharacter(model) then
                    local hum=model:FindFirstChildOfClass("Humanoid")
                    local hrp=model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart or model:FindFirstChild("Head")
                    if hum and hum.Health>0 and hrp and hrp:IsA("BasePart") then
                        alive+=1
                        if not seen[model.Name] then
                            seen[model.Name]=true
                            names[#names+1]=model.Name
                        end
                        local sel=CU2.s.selectedMobs[model.Name]
                        if sel==nil then
                            sel=true
                            CU2.s.selectedMobs[model.Name]=true
                        end
                        if (not onlySelected or sel==true) and not ((CU2.blacklist[model] or 0)>now) then
                            list[#list+1]={model=model,hrp=hrp,hum=hum}
                        end
                    end
                end
            end
        end
        ctext[#ctext+1]=cname.."="..(c and (alive.." vivos") or "NAO existe")
    end
    CU2.containerText=table.concat(ctext,", ")
    table.sort(names)
    CU2.mobNames=names
    return list
end
-- Quando nao acha monstro: pastas do mapa que tem Humanoid (para o proximo TXT dizer onde os monstros estao).
function CU2.findMobFolders()
    local out={}
    for _,child in ipairs(Workspace:GetChildren()) do
        if (child:IsA("Folder") or child:IsA("Model")) and not Players:GetPlayerFromCharacter(child) then
            local n=0
            for _,d in ipairs(child:GetDescendants()) do
                if d:IsA("Humanoid") then n+=1 end
            end
            if n>0 then out[#out+1]=child.Name.."("..n..")" end
        end
    end
    return #out>0 and table.concat(out,", ") or "nenhuma"
end
function CU2.validMob(m)
    return m and m.model and m.model.Parent and CU2.s.selectedMobs[m.model.Name]==true
        and m.hum and m.hum.Parent and m.hum.Health>0 and m.hrp and m.hrp.Parent
end
function CU2.expand(hrp)
    if not CU2.expanded[hrp] then CU2.expanded[hrp]=hrp.Size end
    CU_LOG.try("Combate: aumentar hitbox",function()
        hrp.Size=Vector3.new(25,25,25)
        hrp.CanCollide=false
    end)
end
function CU2.resetHitboxes()
    for part,size in pairs(CU2.expanded) do
        if part and part.Parent then
            CU_LOG.try("Combate: voltar hitbox",function()
                part.Size=size
                part.Transparency=1
            end)
        end
    end
    CU2.expanded={}
end
function CU2.touch(a,b)
    if not firetouchinterest then
        CU_LOG.add("AVISO","CU2","o executor nao tem firetouchinterest: orbs e espiritos so pelo teleporte e pelo remote",300)
        return false
    end
    local ok,err=pcall(function()
        firetouchinterest(a,b,0)
        firetouchinterest(a,b,1)
    end)
    if not ok then CU_LOG.error("firetouchinterest",err) end
    return ok
end
function CU2.setLabel(key,text)
    local l=CU2.ui.labels[key]
    if l and l.Parent and l.Text~=text then l.Text=text end
end

function CU2.statusLine()
    local c=CU_LOG.counts
    return string.format("CU2: lutas %d, mortos %d, sem dano %d | CombatHit tira HP: %s | minijogos pulados %d | Brew %d | ervas mapa todo %d",
        c["Combate: lutas"] or 0,c["Combate: monstro morto"] or 0,c["Combate: sem dano (pulado 30s)"] or 0,
        CU2.stats.hitAccepted and "sim" or "?",CU2.stats.trialSkips,CU2.stats.brewsStarted,CU2.stats.herbsOk+CU2.stats.herbsMaybe)
end
function CU2.sections()
    local st=CU2.stats
    local c=CU_LOG.counts
    local function n(k) return c[k] or 0 end
    local act=CU2.activeNames()
    local fights=n("Combate: lutas")
    local out={"[CU2: FUNCOES DO TOP76 PELO SERVIDOR (sem tecla)]",
        "Ligadas: "..(#act>0 and table.concat(act,", ") or "nenhuma").." | posicao do farm: "..CU2.offsetText()
            .." | turbo="..tostring(CU2.s.turbo).." grupo="..tostring(CU2.s.aoe),
        string.format("Combate: %d lutas, %d mortos, %d sem dano (pulados 30s), %d com o personagem morto | CombatHit tira HP? %s",
            fights,n("Combate: monstro morto"),n("Combate: sem dano (pulado 30s)"),n("Combate: personagem morreu na luta"),
            st.hitAccepted and ("SIM ("..st.hitAccepted..")") or (fights>0 and "NAO confirmado" or "sem lutas ainda")),
        "Containers de monstros: "..(CU2.containerText or "ainda nao escaneado"),
        string.format("Breakthrough pelo servidor: %d minijogos com (true) enviado; fechou %d, continuou aberto %d",st.trialSkips,st.trialClosed,st.trialOpen),
        string.format("Soul: %d viagens, %d catch enviados (%d espiritos sumiram depois), %d ervas do Spirit World",st.soulTrips,st.soulCatches,st.soulGone,st.soulHerbs),
        string.format("Pilulas pelo servidor: %d Brew enviados, %d terminaram | caldeirao agora: %s | ultimo: %s",st.brewsStarted,st.brewsDone,tostring(CU2.cauldronStatus),CU2.lastBrewNote),
        "Ervas no inventario (servidor): "..CU2.herbCountText(),
        string.format("Ervas mapa todo: %d com confirmacao do servidor, %d o prompt sumiu, %d nao coletou",st.herbsOk,st.herbsMaybe,st.herbsFail),
        string.format("Sect Clash: %d eventos, %d golpes | Anti-AFK: %d",st.clashEvents,st.clashHits,st.afk),
        "Remotes do Top76 neste jogo: "..CU2.remoteCheck()}
    if CU2.mobFolders then out[#out+1]="Pastas do mapa com Humanoid (quando nao achou monstro): "..CU2.mobFolders end
    local text=table.concat(out,"\n").."\n\n"
    if #CU2.fights>0 then text=text.."[LUTAS: ultimas "..#CU2.fights.."]\n"..table.concat(CU2.fights,"\n").."\n\n" end
    if #CU2.deaths>0 then text=text.."[MORTES: "..#CU2.deaths.."]\n"..table.concat(CU2.deaths,"\n").."\n\n" end
    if #CU2.events>0 then text=text.."[SECT CLASH]\n"..table.concat(CU2.events,"\n").."\n\n" end
    if #CU2.tribs>0 or CU2.trib then
        local cur=CU2.trib and string.format("\nem andamento desde %s: %d raios, %d acertos, %d erros",CU2.trib.startStamp,#CU2.trib.order,CU2.trib.hits,CU2.trib.misses) or ""
        text=text.."[TRIBULACAO: Auto Tribulation "..(CU2.on("tribulation") and "ligado" or "DESLIGADO").."]\n"..table.concat(CU2.tribs,"\n")..cur.."\n\n"
    end
    if #CU2.serverMsgOrder>0 then
        local keys={}
        for _,k in ipairs(CU2.serverMsgOrder) do keys[#keys+1]=k end
        table.sort(keys,function(a,b) return CU2.serverMsgs[a].count>CU2.serverMsgs[b].count end)
        local out2={}
        for i=1,math.min(12,#keys) do
            local m=CU2.serverMsgs[keys[i]]
            out2[#out2+1]=string.format("x%d (ultima %s): %s",m.count,m.last,m.example)
        end
        text=text.."[MENSAGENS DO SERVIDOR: GlobalMessage, mais frequentes]\n"..table.concat(out2,"\n").."\n\n"
    end
    return text
end
function CU2.safeSections()
    local ok,res=xpcall(CU2.sections,CU_LOG.onError)
    if ok then return res end
    CU_LOG.error("CU2 resumo do TXT",res)
    return "[CU2: erro ao montar o resumo, veja ERROS]\n\n"
end
function CU2.stopAll()
    if CU2.stopped then return end
    CU2.stopped=true
    CU2.mobBusy=false
    for _,c in ipairs(CU2.conns) do c:Disconnect() end
    CU2.conns={}
    CU2.resetHitboxes()
    if CU2.platform then
        CU2.platform:Destroy()
        CU2.platform=nil
    end
    CU_LOG.add("INFO","CU2","janela fechada: todas as funcoes do CU2 pararam",0)
end
-- Auto Kill (aba Auto): golpe e skill pelo servidor alem do clique/tecla VIM (que nao funcionam no celular).
function CU2.killHit(char)
    if not char then return end
    CU2.fire("CombatHit",char,1)
    CU_LOG.count("Kill: CombatHit pelo servidor")
    local hum=char:FindFirstChildOfClass("Humanoid")
    if hum then CU_LOG.add("KILL","alvo",string.format("%s HP %d/%d",char.Name,math.floor(hum.Health),math.floor(hum.MaxHealth)),10,"kill-hp") end
end
function CU2.killSkill(keyName,char)
    local _,hrp=CU2.char()
    local root=char and char:FindFirstChild("HumanoidRootPart")
    if not hrp or not root then return end
    local d=root.Position-hrp.Position
    CU2.fire("UseSkill",keyName,d.Magnitude>0.1 and d.Unit or hrp.CFrame.LookVector,root.Position)
    CU_LOG.count("Kill: UseSkill pelo servidor "..keyName)
end

-------------------------------------------------------------------------
-- UI & INPUT HELPER FUNCTIONS
-------------------------------------------------------------------------
local function addCorner(parent, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or 6)
    c.Parent = parent
    return c
end

local function addStroke(parent, color, thickness)
    local s = Instance.new("UIStroke")
    s.Color = color
    s.Thickness = thickness or 1
    s.Parent = parent
    return s
end

local function makeDraggable(dragTrigger, targetFrame)
    local dragging = false
    local dragInput, dragStart, startPos

    dragTrigger.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = targetFrame.Position

            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    dragTrigger.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            targetFrame.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)
end

local function createToggleRow(parent, posY, labelText, initialState, activeColor, onToggle)
    local container = Instance.new("Frame")
    container.Size = UDim2.new(0.96, 0, 0, 38)
    container.Position = UDim2.new(0, 0, 0, posY)
    container.BackgroundColor3 = Color3.fromRGB(32, 26, 38)
    container.Parent = parent
    addCorner(container, 6)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0.65, 0, 1, 0)
    lbl.Position = UDim2.new(0, 10, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = labelText
    lbl.TextColor3 = Color3.fromRGB(200, 200, 200)
    lbl.TextSize = 12
    lbl.Font = Enum.Font.Gotham
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = container

    local switchBg = Instance.new("Frame")
    switchBg.Size = UDim2.new(0, 44, 0, 22)
    switchBg.Position = UDim2.new(1, -54, 0.5, -11)
    switchBg.Parent = container
    local c1 = Instance.new("UICorner")
    c1.CornerRadius = UDim.new(1, 0)
    c1.Parent = switchBg

    local switchCircle = Instance.new("Frame")
    switchCircle.Size = UDim2.new(0, 18, 0, 18)
    switchCircle.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
    switchCircle.Parent = switchBg
    local c2 = Instance.new("UICorner")
    c2.CornerRadius = UDim.new(1, 0)
    c2.Parent = switchCircle

    local onCol = activeColor or Color3.fromRGB(60, 180, 80)
    local offCol = Color3.fromRGB(60, 50, 65)

    local currentState = initialState
    local function setVisual(st)
        currentState = st
        TweenService:Create(switchBg, TweenInfo.new(0.2), {BackgroundColor3 = st and onCol or offCol}):Play()
        TweenService:Create(switchCircle, TweenInfo.new(0.2), {Position = st and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9)}):Play()
    end

    switchBg.BackgroundColor3 = initialState and onCol or offCol
    switchCircle.Position = initialState and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9)

    local trigger = Instance.new("TextButton")
    trigger.Size = UDim2.new(1, 0, 1, 0)
    trigger.BackgroundTransparency = 1
    trigger.Text = ""
    trigger.ZIndex = 2
    trigger.Parent = container

    trigger.Activated:Connect(function()
        setVisual(not currentState)
        CU_LOG.toggle(labelText, currentState)
        if onToggle then
            CU_LOG.try("Toggle " .. tostring(labelText), onToggle, currentState)
        end
    end)

    return container, setVisual
end

local function trimText(str)
    return (str or ""):match("^%s*(.-)%s*$"):lower()
end

local function normalizeName(str)
    return (str or ""):lower():gsub("[%s%p_]+", "")
end

local function isUserTypingOrInMenu()
    return (UserInputService:GetFocusedTextBox() ~= nil) or GuiService.MenuIsOpen
end

local function isActuallyVisible(guiObj)
    if not guiObj or not guiObj:IsA("GuiObject") then return false end
    if guiObj.AbsoluteSize.X <= 2 or guiObj.AbsoluteSize.Y <= 2 then return false end
    local curr = guiObj
    while curr and curr ~= LocalPlayer.PlayerGui do
        if curr:IsA("GuiObject") and not curr.Visible then
            return false
        elseif curr:IsA("ScreenGui") and not curr.Enabled then
            return false
        end
        curr = curr.Parent
    end
    return true
end

-- Klik GUI Bersih (1x Eksekusi Tanpa Spam Ganda)
local function triggerGuiClick(element, instantRelease, allowPhysicalFallback)
    if not element then return end
    local btn = element:IsA("GuiButton") and element
        or element:FindFirstAncestorWhichIsA("GuiButton")
        or element:FindFirstChildWhichIsA("GuiButton", true)
        or element

    local signalHandled = false

    pcall(function()
        if getconnections and btn:IsA("GuiButton") then
            local c1 = getconnections(btn.MouseButton1Click)
            if c1 and #c1 > 0 then
                for _, conn in ipairs(c1) do
                    conn:Fire()
                    signalHandled = true
                end
            end
            if not signalHandled then
                local c2 = getconnections(btn.Activated)
                if c2 and #c2 > 0 then
                    for _, conn in ipairs(c2) do
                        conn:Fire()
                        signalHandled = true
                    end
                end
            end
        end
    end)

    local cuViaConnections = signalHandled
    if not signalHandled then
        pcall(function()
            if firesignal and btn:IsA("GuiButton") then
                firesignal(btn.MouseButton1Click)
                signalHandled = true
            end
        end)
    end

    -- Jika executor tidak mengeksekusi firesignal/getconnections, gunakan 1x klik koordinat tombol
    local cuPhysical = false
    if (not signalHandled or allowPhysicalFallback) and not isUserTypingOrInMenu() and isActuallyVisible(btn) then
        cuPhysical = true
        pcall(function()
            local inset = GuiService:GetGuiInset()
            local pos = btn.AbsolutePosition
            local size = btn.AbsoluteSize
            local centerX = pos.X + (size.X / 2)
            local centerY = pos.Y + (size.Y / 2) + inset.Y

            VirtualInputManager:SendMouseButtonEvent(centerX, centerY, 0, true, game, 1)
            if not instantRelease then task.wait(0.02) end
            VirtualInputManager:SendMouseButtonEvent(centerX, centerY, 0, false, game, 1)
        end)
    end
    CU_LOG.click(cuViaConnections and "getconnections" or (signalHandled and "firesignal" or nil), btn, cuPhysical)
end

local function triggerKeyPress(charStr)
    if isUserTypingOrInMenu() then return end
    local upperChar = charStr:upper():match("^[A-Z]$")
    if not upperChar then return end
    local keyCode = Enum.KeyCode[upperChar]
    if not keyCode then return end

    local okKey, errKey = pcall(function()
        VirtualInputManager:SendKeyEvent(true, keyCode, false, game)
        task.wait(0.03)
        VirtualInputManager:SendKeyEvent(false, keyCode, false, game)
    end)
    CU_LOG.key(upperChar, okKey, errKey)
end

-------------------------------------------------------------------------
-- BUILD MAIN WINDOW & SIDEBAR
-------------------------------------------------------------------------
do
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "CultivationHubGui"
    screenGui.ResetOnSpawn = false
    screenGui.IgnoreGuiInset = false

    if syn and syn.protect_gui then
        syn.protect_gui(screenGui)
        screenGui.Parent = game:GetService("CoreGui")
    elseif gethui then
        screenGui.Parent = gethui()
    else
        screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    end
    UI.ScreenGui = screenGui

    local floatingBtn = Instance.new("TextButton")
    floatingBtn.Name = "MobileToggleBtn"
    floatingBtn.Size = UDim2.new(0, 48, 0, 48)
    floatingBtn.Position = UDim2.new(0.02, 0, 0.45, 0)
    floatingBtn.BackgroundColor3 = Color3.fromRGB(45, 32, 58)
    floatingBtn.Text = "HUB"
    floatingBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    floatingBtn.TextSize = 13
    floatingBtn.Font = Enum.Font.GothamBold
    floatingBtn.ZIndex = 50
    floatingBtn.Parent = screenGui
    local fc = Instance.new("UICorner")
    fc.CornerRadius = UDim.new(1, 0)
    fc.Parent = floatingBtn
    addStroke(floatingBtn, Color3.fromRGB(210, 50, 70), 2)
    makeDraggable(floatingBtn, floatingBtn)

    local frameW = State.isMobile and 440 or 540
    local frameH = State.isMobile and 340 or 470

    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.new(0, frameW, 0, frameH)
    mainFrame.Position = UDim2.new(0.5, -(frameW / 2), 0.5, -(frameH / 2))
    mainFrame.BackgroundColor3 = Color3.fromRGB(22, 18, 26)
    mainFrame.BorderSizePixel = 0
    mainFrame.Active = true
    mainFrame.Parent = screenGui
    addCorner(mainFrame, 8)
    UI.MainFrame = mainFrame

    local uiScale = Instance.new("UIScale")
    local vp = Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
    uiScale.Scale = (vp.Y < 500) and 0.78 or ((vp.Y < 720 and State.isMobile) and 0.88 or 1.0)
    uiScale.Parent = mainFrame

    local topBar = Instance.new("Frame")
    topBar.Size = UDim2.new(1, 0, 0, 36)
    topBar.BackgroundColor3 = Color3.fromRGB(18, 14, 22)
    topBar.BorderSizePixel = 0
    topBar.Parent = mainFrame
    addCorner(topBar, 8)
    makeDraggable(topBar, mainFrame)

    local titleText = Instance.new("TextLabel")
    titleText.Size = UDim2.new(1, -100, 1, 0)
    titleText.Position = UDim2.new(0, 15, 0, 0)
    titleText.BackgroundTransparency = 1
    titleText.Text = "Cultivation Hub | CU2.2 (Top76 + log)"
    titleText.TextColor3 = Color3.fromRGB(220, 220, 220)
    titleText.TextSize = 14
    titleText.Font = Enum.Font.GothamBold
    titleText.TextXAlignment = Enum.TextXAlignment.Left
    titleText.Parent = topBar

    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 26, 0, 26)
    closeBtn.Position = UDim2.new(1, -32, 0.5, -13)
    closeBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
    closeBtn.Text = "X"
    closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeBtn.TextSize = 12
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.Parent = topBar
    addCorner(closeBtn, 4)

    local minimizeBtn = Instance.new("TextButton")
    minimizeBtn.Size = UDim2.new(0, 26, 0, 26)
    minimizeBtn.Position = UDim2.new(1, -64, 0.5, -13)
    minimizeBtn.BackgroundColor3 = Color3.fromRGB(50, 40, 60)
    minimizeBtn.Text = "-"
    minimizeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    minimizeBtn.TextSize = 14
    minimizeBtn.Font = Enum.Font.GothamBold
    minimizeBtn.Parent = topBar
    addCorner(minimizeBtn, 4)

    local sidebarW = State.isMobile and 110 or 135
    local sidebar = Instance.new("Frame")
    sidebar.Size = UDim2.new(0, sidebarW, 1, -36)
    sidebar.Position = UDim2.new(0, 0, 0, 36)
    sidebar.BackgroundColor3 = Color3.fromRGB(28, 22, 34)
    sidebar.BorderSizePixel = 0
    sidebar.Parent = mainFrame
    addCorner(sidebar, 6)

    local contentArea = Instance.new("Frame")
    contentArea.Size = UDim2.new(1, -(sidebarW + 10), 1, -46)
    contentArea.Position = UDim2.new(0, sidebarW + 5, 0, 41)
    contentArea.BackgroundTransparency = 1
    contentArea.Parent = mainFrame

    local autoPage = Instance.new("ScrollingFrame")
    autoPage.Size = UDim2.new(1, 0, 1, 0)
    autoPage.BackgroundTransparency = 1
    autoPage.CanvasSize = UDim2.new(0, 0, 0, 840)
    autoPage.ScrollBarThickness = 5
    autoPage.ScrollingDirection = Enum.ScrollingDirection.Y
    autoPage.Visible = true
    autoPage.Parent = contentArea
    UI.AutoPage = autoPage

    local locationPage = Instance.new("ScrollingFrame")
    locationPage.Size = UDim2.new(1, 0, 1, 0)
    locationPage.BackgroundTransparency = 1
    locationPage.CanvasSize = UDim2.new(0, 0, 0, 360)
    locationPage.ScrollBarThickness = 5
    locationPage.ScrollingDirection = Enum.ScrollingDirection.Y
    locationPage.Visible = false
    locationPage.Parent = contentArea
    UI.LocationPage = locationPage

    local settingPage = Instance.new("Frame")
    settingPage.Size = UDim2.new(1, 0, 1, 0)
    settingPage.BackgroundTransparency = 1
    settingPage.Visible = false
    settingPage.Parent = contentArea
    UI.SettingPage = settingPage

    local function makeTabBtn(text, posY, isDefault)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(0.9, 0, 0, 32)
        b.Position = UDim2.new(0.05, 0, 0, posY)
        b.BackgroundColor3 = isDefault and Color3.fromRGB(45, 32, 58) or Color3.fromRGB(28, 22, 34)
        b.Text = text
        b.TextColor3 = isDefault and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(160, 160, 160)
        b.TextSize = 13
        b.Font = Enum.Font.GothamMedium
        b.Parent = sidebar
        addCorner(b, 4)
        return b
    end

    local autoTabBtn = makeTabBtn("Auto", 10, true)
    local locationTabBtn = makeTabBtn("Location", 124, false)
    local settingTabBtn = makeTabBtn("Setting", 162, false)
    local logsTabBtn = makeTabBtn("Logs", 200, false)
    local logsPage = Instance.new("ScrollingFrame")
    logsPage.Size = UDim2.new(1, 0, 1, 0)
    logsPage.BackgroundTransparency = 1
    logsPage.CanvasSize = UDim2.new(0, 0, 0, 400)
    logsPage.ScrollBarThickness = 5
    logsPage.ScrollingDirection = Enum.ScrollingDirection.Y
    logsPage.Visible = false
    logsPage.Parent = contentArea
    UI.LogsPage = logsPage
    -- CU2: abas Combate e Extra (o conteudo e montado no fim do arquivo).
    for cuIndex, cuName in ipairs({"Combate", "Extra"}) do
        local cuPage = Instance.new("ScrollingFrame")
        cuPage.Size = UDim2.new(1, 0, 1, 0)
        cuPage.BackgroundTransparency = 1
        cuPage.CanvasSize = UDim2.new(0, 0, 0, 400)
        cuPage.ScrollBarThickness = 5
        cuPage.ScrollingDirection = Enum.ScrollingDirection.Y
        cuPage.Visible = false
        cuPage.Parent = contentArea
        CU2.tabs[cuName] = {page = cuPage, btn = makeTabBtn(cuName, 10 + cuIndex * 38, false)}
    end

    local function switchTab(tabName)
        autoPage.Visible = (tabName == "Auto")
        locationPage.Visible = (tabName == "Location")
        settingPage.Visible = (tabName == "Setting")

        autoTabBtn.BackgroundColor3 = (tabName == "Auto") and Color3.fromRGB(45, 32, 58) or Color3.fromRGB(28, 22, 34)
        autoTabBtn.TextColor3 = (tabName == "Auto") and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(160, 160, 160)

        locationTabBtn.BackgroundColor3 = (tabName == "Location") and Color3.fromRGB(45, 32, 58) or Color3.fromRGB(28, 22, 34)
        locationTabBtn.TextColor3 = (tabName == "Location") and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(160, 160, 160)

        settingTabBtn.BackgroundColor3 = (tabName == "Setting") and Color3.fromRGB(45, 32, 58) or Color3.fromRGB(28, 22, 34)
        settingTabBtn.TextColor3 = (tabName == "Setting") and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(160, 160, 160)

        logsPage.Visible = (tabName == "Logs")
        logsTabBtn.BackgroundColor3 = (tabName == "Logs") and Color3.fromRGB(45, 32, 58) or Color3.fromRGB(28, 22, 34)
        logsTabBtn.TextColor3 = (tabName == "Logs") and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(160, 160, 160)
        for cuName, cuTab in pairs(CU2.tabs) do
            cuTab.page.Visible = (tabName == cuName)
            cuTab.btn.BackgroundColor3 = (tabName == cuName) and Color3.fromRGB(45, 32, 58) or Color3.fromRGB(28, 22, 34)
            cuTab.btn.TextColor3 = (tabName == cuName) and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(160, 160, 160)
        end
    end

    autoTabBtn.Activated:Connect(function() switchTab("Auto") end)
    locationTabBtn.Activated:Connect(function() switchTab("Location") end)
    settingTabBtn.Activated:Connect(function() switchTab("Setting") end)
    logsTabBtn.Activated:Connect(function() switchTab("Logs") end)
    for cuName, cuTab in pairs(CU2.tabs) do
        cuTab.btn.Activated:Connect(function() switchTab(cuName) end)
    end

    floatingBtn.Activated:Connect(function()
        State.uiVisible = not State.uiVisible
        mainFrame.Visible = State.uiVisible
    end)

    closeBtn.Activated:Connect(function()
        State.autoFarmActive = false
        State.autoPillActive = false
        State.autoBreakthroughActive = false
        State.autoQiOrbActive = false
        State.autoRealmActive = false
        State.autoBodyActive = false
        State.autoKillActive = false
        CU2.stopAll()
        screenGui:Destroy()
    end)

    minimizeBtn.Activated:Connect(function()
        State.isMinimized = not State.isMinimized
        sidebar.Visible = not State.isMinimized
        contentArea.Visible = not State.isMinimized
        mainFrame.Size = State.isMinimized and UDim2.new(0, frameW, 0, 36) or UDim2.new(0, frameW, 0, frameH)
        minimizeBtn.Text = State.isMinimized and "+" or "-"
    end)
end

-------------------------------------------------------------------------
-- BUILD PAGE 1: AUTO CATALOG
-------------------------------------------------------------------------
do
    local page = UI.AutoPage

    local function addSectionHeader(text, posY, color)
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, 0, 0, 20)
        lbl.Position = UDim2.new(0, 0, 0, posY)
        lbl.BackgroundTransparency = 1
        lbl.Text = text
        lbl.TextColor3 = color or Color3.fromRGB(180, 180, 180)
        lbl.TextSize = 12
        lbl.Font = Enum.Font.GothamBold
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = page
    end

    -- 1. FARM HERBS
    addSectionHeader("Farm Herbs (Priority: 1000Yr > 100Yr > 10Yr > 1Yr)", 0)

    local herbDropContainer = Instance.new("Frame")
    herbDropContainer.Size = UDim2.new(0.96, 0, 0, 38)
    herbDropContainer.Position = UDim2.new(0, 0, 0, 25)
    herbDropContainer.BackgroundColor3 = Color3.fromRGB(32, 26, 38)
    herbDropContainer.ZIndex = 6
    herbDropContainer.Parent = page
    addCorner(herbDropContainer, 6)

    local herbDropLabel = Instance.new("TextLabel")
    herbDropLabel.Size = UDim2.new(0.48, 0, 1, 0)
    herbDropLabel.Position = UDim2.new(0, 10, 0, 0)
    herbDropLabel.BackgroundTransparency = 1
    herbDropLabel.Text = "Select Herb"
    herbDropLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    herbDropLabel.TextSize = 12
    herbDropLabel.Font = Enum.Font.Gotham
    herbDropLabel.TextXAlignment = Enum.TextXAlignment.Left
    herbDropLabel.ZIndex = 6
    herbDropLabel.Parent = herbDropContainer

    local herbDropBtn = Instance.new("TextButton")
    herbDropBtn.Size = UDim2.new(0.46, 0, 0.72, 0)
    herbDropBtn.Position = UDim2.new(0.51, 0, 0.14, 0)
    herbDropBtn.BackgroundColor3 = Color3.fromRGB(50, 40, 60)
    herbDropBtn.Text = State.selectedHerb .. " ▾"
    herbDropBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    herbDropBtn.TextSize = 11
    herbDropBtn.Font = Enum.Font.GothamBold
    herbDropBtn.ZIndex = 7
    herbDropBtn.Parent = herbDropContainer
    addCorner(herbDropBtn, 4)

    local herbDropList = Instance.new("ScrollingFrame")
    herbDropList.Size = UDim2.new(1, 0, 0, 110)
    herbDropList.Position = UDim2.new(0, 0, 1, 4)
    herbDropList.BackgroundColor3 = Color3.fromRGB(40, 32, 48)
    herbDropList.Visible = false
    herbDropList.ZIndex = 20
    herbDropList.CanvasSize = UDim2.new(0, 0, 0, 155)
    herbDropList.ScrollBarThickness = 4
    herbDropList.Parent = herbDropBtn
    addCorner(herbDropList, 4)

    for i, herbName in ipairs(Constants.HERBS_LIST) do
        local optBtn = Instance.new("TextButton")
        optBtn.Size = UDim2.new(1, -5, 0, 28)
        optBtn.Position = UDim2.new(0, 0, 0, (i - 1) * 30)
        optBtn.BackgroundTransparency = 1
        optBtn.Text = herbName
        optBtn.TextColor3 = Color3.fromRGB(220, 220, 220)
        optBtn.TextSize = 11
        optBtn.Font = Enum.Font.Gotham
        optBtn.ZIndex = 21
        optBtn.Parent = herbDropList

        optBtn.Activated:Connect(function()
            State.selectedHerb = herbName
            Config.selectedHerb = herbName
            herbDropBtn.Text = herbName .. " ▾"
            herbDropList.Visible = false
            saveConfig()
        end)
    end

    UI.HerbRow, UI.SetHerbSwitch = createToggleRow(page, 70, "autofarm herb", State.autoFarmActive, nil, function(val)
        State.autoFarmActive = val
        if val then CU2.exclusive("herb") end
        Config.autoFarmActive = val
        if not val and State.activeFarmTween then
            pcall(function() State.activeFarmTween:Cancel() end)
        end
        saveConfig()
    end)

    -- Speed Slider
    local sliderContainer = Instance.new("Frame")
    sliderContainer.Size = UDim2.new(0.96, 0, 0, 54)
    sliderContainer.Position = UDim2.new(0, 0, 0, 115)
    sliderContainer.BackgroundColor3 = Color3.fromRGB(32, 26, 38)
    sliderContainer.Parent = page
    addCorner(sliderContainer, 6)

    local sliderLabel = Instance.new("TextLabel")
    sliderLabel.Size = UDim2.new(0.6, 0, 0, 25)
    sliderLabel.Position = UDim2.new(0, 10, 0, 4)
    sliderLabel.BackgroundTransparency = 1
    sliderLabel.Text = "Fly Speed"
    sliderLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    sliderLabel.TextSize = 12
    sliderLabel.Font = Enum.Font.Gotham
    sliderLabel.TextXAlignment = Enum.TextXAlignment.Left
    sliderLabel.Parent = sliderContainer

    local speedInputBox = Instance.new("TextBox")
    speedInputBox.Size = UDim2.new(0, 48, 0, 22)
    speedInputBox.Position = UDim2.new(1, -58, 0, 5)
    speedInputBox.BackgroundColor3 = Color3.fromRGB(45, 36, 54)
    speedInputBox.Text = tostring(State.flySpeed)
    speedInputBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    speedInputBox.TextSize = 12
    speedInputBox.Font = Enum.Font.GothamBold
    speedInputBox.Parent = sliderContainer
    addCorner(speedInputBox, 4)

    local sliderBar = Instance.new("Frame")
    sliderBar.Size = UDim2.new(0.9, 0, 0, 8)
    sliderBar.Position = UDim2.new(0.05, 0, 0, 36)
    sliderBar.BackgroundColor3 = Color3.fromRGB(20, 16, 24)
    sliderBar.BorderSizePixel = 0
    sliderBar.Parent = sliderContainer
    addCorner(sliderBar, 8)

    local sliderFill = Instance.new("Frame")
    sliderFill.Size = UDim2.new((State.flySpeed - State.minSpeed) / (State.maxSpeed - State.minSpeed), 0, 1, 0)
    sliderFill.BackgroundColor3 = Color3.fromRGB(210, 50, 70)
    sliderFill.BorderSizePixel = 0
    sliderFill.Parent = sliderBar
    addCorner(sliderFill, 8)

    local sliderBtn = Instance.new("TextButton")
    sliderBtn.Size = UDim2.new(1, 16, 1, 20)
    sliderBtn.Position = UDim2.new(0, -8, 0, -10)
    sliderBtn.BackgroundTransparency = 1
    sliderBtn.Text = ""
    sliderBtn.Parent = sliderBar

    local function updateSpeed(val)
        State.flySpeed = math.clamp(math.round(val), State.minSpeed, State.maxSpeed)
        Config.flySpeed = State.flySpeed
        speedInputBox.Text = tostring(State.flySpeed)
        sliderFill.Size = UDim2.new((State.flySpeed - State.minSpeed) / (State.maxSpeed - State.minSpeed), 0, 1, 0)
        saveConfig()
    end

    local draggingSlider = false
    sliderBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            draggingSlider = true
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            draggingSlider = false
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if draggingSlider and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local pct = math.clamp((input.Position.X - sliderBar.AbsolutePosition.X) / sliderBar.AbsoluteSize.X, 0, 1)
            updateSpeed(State.minSpeed + (pct * (State.maxSpeed - State.minSpeed)))
        end
    end)
    speedInputBox.FocusLost:Connect(function()
        local num = tonumber(speedInputBox.Text)
        if num then updateSpeed(num) else speedInputBox.Text = tostring(State.flySpeed) end
    end)

    -- 2. AUTOCREATE PILLS (ZERO-LAG + EXACT 3-COLUMN SLOT + INSTANT CLAIM)
    addSectionHeader("Auto Create Pills (Zero-Lag + Anywhere + Instant Claim)", 180)

    local pillDropContainer = Instance.new("Frame")
    pillDropContainer.Size = UDim2.new(0.96, 0, 0, 38)
    pillDropContainer.Position = UDim2.new(0, 0, 0, 205)
    pillDropContainer.BackgroundColor3 = Color3.fromRGB(32, 26, 38)
    pillDropContainer.ZIndex = 4
    pillDropContainer.Parent = page
    addCorner(pillDropContainer, 6)

    local pillDropLabel = Instance.new("TextLabel")
    pillDropLabel.Size = UDim2.new(0.45, 0, 1, 0)
    pillDropLabel.Position = UDim2.new(0, 10, 0, 0)
    pillDropLabel.BackgroundTransparency = 1
    pillDropLabel.Text = "Select Pill Recipe"
    pillDropLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    pillDropLabel.TextSize = 12
    pillDropLabel.Font = Enum.Font.Gotham
    pillDropLabel.TextXAlignment = Enum.TextXAlignment.Left
    pillDropLabel.ZIndex = 4
    pillDropLabel.Parent = pillDropContainer

    local pillDropBtn = Instance.new("TextButton")
    pillDropBtn.Size = UDim2.new(0.5, 0, 0.72, 0)
    pillDropBtn.Position = UDim2.new(0.47, 0, 0.14, 0)
    pillDropBtn.BackgroundColor3 = Color3.fromRGB(50, 40, 60)
    pillDropBtn.Text = State.selectedPill .. " ▾"
    pillDropBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    pillDropBtn.TextSize = 10
    pillDropBtn.Font = Enum.Font.GothamBold
    pillDropBtn.ZIndex = 5
    pillDropBtn.Parent = pillDropContainer
    addCorner(pillDropBtn, 4)

    local pillDropList = Instance.new("Frame")
    pillDropList.Size = UDim2.new(1, 0, 0, 112)
    pillDropList.Position = UDim2.new(0, 0, 1, 4)
    pillDropList.BackgroundColor3 = Color3.fromRGB(40, 32, 48)
    pillDropList.Visible = false
    pillDropList.ZIndex = 18
    pillDropList.Parent = pillDropBtn
    addCorner(pillDropList, 4)

    for i, pillName in ipairs(Constants.PILLS_LIST) do
        local optBtn = Instance.new("TextButton")
        optBtn.Size = UDim2.new(1, -5, 0, 26)
        optBtn.Position = UDim2.new(0, 0, 0, (i - 1) * 27)
        optBtn.BackgroundTransparency = 1
        optBtn.Text = pillName
        optBtn.TextColor3 = Color3.fromRGB(220, 220, 220)
        optBtn.TextSize = 10
        optBtn.Font = Enum.Font.Gotham
        optBtn.ZIndex = 19
        optBtn.Parent = pillDropList

        optBtn.Activated:Connect(function()
            State.selectedPill = pillName
            Config.selectedPill = pillName
            pillDropBtn.Text = pillName .. " ▾"
            pillDropList.Visible = false
            saveConfig()
        end)
    end

    UI.PillRow, UI.SetPillSwitch = createToggleRow(page, 250, "Autocreate pills (Anywhere)", State.autoPillActive, nil, function(val)
        State.autoPillActive = val
        if val then CU2.exclusive("pill") end
        Config.autoPillActive = val
        saveConfig()
    end)

    -- 3. CULTIVATION (INSTANT AUTO REALM M & AUTO BODY P) & BREAKTHROUGH
    addSectionHeader("Cultivation (Instant Auto Realm & Body) & Breakthrough", 298)

    local setRealmSwitch, setBodySwitch

    _, setRealmSwitch = createToggleRow(page, 323, "Auto Realm (Instant Resume - Key M)", State.autoRealmActive, nil, function(val)
        State.autoRealmActive = val
        Config.autoRealmActive = val
        State.lastRealmTrigger = 0
        State.lastQiServerTick = 0
        State.forceImmediateCultivate = val
        if val and State.autoBodyActive then
            State.autoBodyActive = false
            Config.autoBodyActive = false
            if setBodySwitch then setBodySwitch(false) end
            pcall(function()
                if CultivationEvents and CultivationEvents:FindFirstChild("StopPushup") then
                    CU_LOG.sent("StopPushup"); CultivationEvents.StopPushup:FireServer()
                end
            end)
        end
        saveConfig()
    end)

    _, setBodySwitch = createToggleRow(page, 368, "Auto Body (Instant Resume - Key P)", State.autoBodyActive, nil, function(val)
        State.autoBodyActive = val
        Config.autoBodyActive = val
        State.lastBodyTrigger = 0
        State.lastBodyServerTick = 0
        State.forceImmediateCultivate = val
        if val and State.autoRealmActive then
            State.autoRealmActive = false
            Config.autoRealmActive = false
            if setRealmSwitch then setRealmSwitch(false) end
            pcall(function()
                if CultivationEvents and CultivationEvents:FindFirstChild("StopMeditate") then
                    CU_LOG.sent("StopMeditate"); CultivationEvents.StopMeditate:FireServer()
                end
            end)
        end
        saveConfig()
    end)

    createToggleRow(page, 413, "Auto Breakthrough (All Realms)", State.autoBreakthroughActive, nil, function(val)
        State.autoBreakthroughActive = val
        Config.autoBreakthroughActive = val
        if not val and UI.RealmStatusLabel then
            UI.RealmStatusLabel.Text = "Status: Auto Breakthrough Nonaktif"
        end
        saveConfig()
    end)

    local realmStatusLabel = Instance.new("TextLabel")
    realmStatusLabel.Size = UDim2.new(0.96, 0, 0, 20)
    realmStatusLabel.Position = UDim2.new(0, 4, 0, 454)
    realmStatusLabel.BackgroundTransparency = 1
    realmStatusLabel.Text = State.autoBreakthroughActive and "Status: Memantau Realm & Qi..." or "Status: Auto Breakthrough Nonaktif"
    realmStatusLabel.TextColor3 = Color3.fromRGB(160, 210, 170)
    realmStatusLabel.TextSize = 11
    realmStatusLabel.Font = Enum.Font.GothamMedium
    realmStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
    realmStatusLabel.Parent = page
    UI.RealmStatusLabel = realmStatusLabel

    createToggleRow(page, 478, "Auto Click Qi Orb (Instant Network + UI)", State.autoQiOrbActive, nil, function(val)
        State.autoQiOrbActive = val
        Config.autoQiOrbActive = val
        saveConfig()
    end)

    -- 4. AUTO KILL PLAYER
    addSectionHeader("Auto Kill Player (Target Lock & Skills)", 528, Color3.fromRGB(220, 120, 130))

    local playerDropContainer = Instance.new("Frame")
    playerDropContainer.Size = UDim2.new(0.96, 0, 0, 38)
    playerDropContainer.Position = UDim2.new(0, 0, 0, 553)
    playerDropContainer.BackgroundColor3 = Color3.fromRGB(32, 26, 38)
    playerDropContainer.ZIndex = 3
    playerDropContainer.Parent = page
    addCorner(playerDropContainer, 6)

    local playerDropLabel = Instance.new("TextLabel")
    playerDropLabel.Size = UDim2.new(0.42, 0, 1, 0)
    playerDropLabel.Position = UDim2.new(0, 10, 0, 0)
    playerDropLabel.BackgroundTransparency = 1
    playerDropLabel.Text = "Select Player"
    playerDropLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    playerDropLabel.TextSize = 12
    playerDropLabel.Font = Enum.Font.Gotham
    playerDropLabel.TextXAlignment = Enum.TextXAlignment.Left
    playerDropLabel.ZIndex = 3
    playerDropLabel.Parent = playerDropContainer

    local playerDropBtn = Instance.new("TextButton")
    playerDropBtn.Size = UDim2.new(0.52, 0, 0.72, 0)
    playerDropBtn.Position = UDim2.new(0.45, 0, 0.14, 0)
    playerDropBtn.BackgroundColor3 = Color3.fromRGB(50, 40, 60)
    playerDropBtn.Text = "Pilih Target ▾"
    playerDropBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    playerDropBtn.TextSize = 10
    playerDropBtn.Font = Enum.Font.GothamBold
    playerDropBtn.ZIndex = 4
    playerDropBtn.Parent = playerDropContainer
    addCorner(playerDropBtn, 4)

    local playerDropList = Instance.new("ScrollingFrame")
    playerDropList.Size = UDim2.new(1, 0, 0, 120)
    playerDropList.Position = UDim2.new(0, 0, 1, 4)
    playerDropList.BackgroundColor3 = Color3.fromRGB(40, 32, 48)
    playerDropList.Visible = false
    playerDropList.ZIndex = 25
    playerDropList.CanvasSize = UDim2.new(0, 0, 0, 120)
    playerDropList.ScrollBarThickness = 4
    playerDropList.Parent = playerDropBtn
    addCorner(playerDropList, 4)

    local function refreshPlayerDropdown()
        for _, ch in pairs(playerDropList:GetChildren()) do
            if ch:IsA("TextButton") then ch:Destroy() end
        end
        local idx = 0
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer then
                idx = idx + 1
                local pBtn = Instance.new("TextButton")
                pBtn.Size = UDim2.new(1, -5, 0, 26)
                pBtn.Position = UDim2.new(0, 0, 0, (idx - 1) * 28)
                pBtn.BackgroundTransparency = 1
                pBtn.Text = plr.DisplayName .. " (@" .. plr.Name .. ")"
                pBtn.TextColor3 = Color3.fromRGB(220, 220, 220)
                pBtn.TextSize = 10
                pBtn.Font = Enum.Font.Gotham
                pBtn.ZIndex = 26
                pBtn.Parent = playerDropList

                pBtn.Activated:Connect(function()
                    State.selectedTargetPlayerName = plr.Name
                    CU_LOG.add("KILL", "alvo", "escolhido: " .. plr.Name, 0)
                    playerDropBtn.Text = plr.Name .. " ▾"
                    playerDropList.Visible = false
                end)
            end
        end
        playerDropList.CanvasSize = UDim2.new(0, 0, 0, math.max(120, idx * 28))
    end

    refreshPlayerDropdown()
    Players.PlayerAdded:Connect(refreshPlayerDropdown)
    Players.PlayerRemoving:Connect(function(plr)
        if plr.Name == State.selectedTargetPlayerName then
            State.selectedTargetPlayerName = "None"
            playerDropBtn.Text = "Pilih Target ▾"
        end
        refreshPlayerDropdown()
    end)

    herbDropBtn.Activated:Connect(function()
        herbDropList.Visible = not herbDropList.Visible
        pillDropList.Visible = false
        playerDropList.Visible = false
    end)
    pillDropBtn.Activated:Connect(function()
        pillDropList.Visible = not pillDropList.Visible
        herbDropList.Visible = false
        playerDropList.Visible = false
    end)
    playerDropBtn.Activated:Connect(function()
        refreshPlayerDropdown()
        playerDropList.Visible = not playerDropList.Visible
        herbDropList.Visible = false
        pillDropList.Visible = false
    end)

    createToggleRow(page, 598, "Auto Kill (Lock + Sword & Skills)", State.autoKillActive, Color3.fromRGB(210, 50, 70), function(val)
        State.autoKillActive = val
        Config.autoKillActive = val
        saveConfig()
    end)
end

-------------------------------------------------------------------------
-- BUILD PAGE 2: LOCATION CATALOG
-------------------------------------------------------------------------
local instantTeleportToZone

do
    local locPage = UI.LocationPage

    local function createZoneSection(headerTitle, posY, zonesList, initialZone, zIndexBase, onSelectZone, onTeleportClick)
        local hdr = Instance.new("TextLabel")
        hdr.Size = UDim2.new(1, 0, 0, 22)
        hdr.Position = UDim2.new(0, 0, 0, posY)
        hdr.BackgroundTransparency = 1
        hdr.Text = headerTitle
        hdr.TextColor3 = Color3.fromRGB(195, 190, 175)
        hdr.TextSize = 14
        hdr.Font = Enum.Font.GothamBold
        hdr.TextXAlignment = Enum.TextXAlignment.Left
        hdr.Parent = locPage

        local dropContainer = Instance.new("Frame")
        dropContainer.Size = UDim2.new(0.96, 0, 0, 40)
        dropContainer.Position = UDim2.new(0, 0, 0, posY + 25)
        dropContainer.BackgroundColor3 = Color3.fromRGB(36, 33, 24)
        dropContainer.ZIndex = zIndexBase
        dropContainer.Parent = locPage
        addCorner(dropContainer, 6)
        addStroke(dropContainer, Color3.fromRGB(85, 78, 52), 1)

        local dropLabel = Instance.new("TextLabel")
        dropLabel.Size = UDim2.new(0.42, 0, 1, 0)
        dropLabel.Position = UDim2.new(0, 12, 0, 0)
        dropLabel.BackgroundTransparency = 1
        dropLabel.Text = "Select " .. headerTitle
        dropLabel.TextColor3 = Color3.fromRGB(220, 215, 200)
        dropLabel.TextSize = 12
        dropLabel.Font = Enum.Font.GothamMedium
        dropLabel.TextXAlignment = Enum.TextXAlignment.Left
        dropLabel.ZIndex = zIndexBase
        dropLabel.Parent = dropContainer

        local dropBtn = Instance.new("TextButton")
        dropBtn.Size = UDim2.new(0.52, 0, 0.72, 0)
        dropBtn.Position = UDim2.new(0.45, 0, 0.14, 0)
        dropBtn.BackgroundColor3 = Color3.fromRGB(52, 47, 34)
        dropBtn.Text = initialZone .. " ▾"
        dropBtn.TextColor3 = Color3.fromRGB(255, 245, 215)
        dropBtn.TextSize = 11
        dropBtn.Font = Enum.Font.GothamBold
        dropBtn.ZIndex = zIndexBase + 1
        dropBtn.Parent = dropContainer
        addCorner(dropBtn, 4)

        local dropList = Instance.new("ScrollingFrame")
        dropList.Size = UDim2.new(1, 0, 0, 135)
        dropList.Position = UDim2.new(0, 0, 1, 4)
        dropList.BackgroundColor3 = Color3.fromRGB(42, 38, 28)
        dropList.Visible = false
        dropList.ZIndex = zIndexBase + 15
        dropList.CanvasSize = UDim2.new(0, 0, 0, #zonesList * 28)
        dropList.ScrollBarThickness = 4
        dropList.Parent = dropBtn
        addCorner(dropList, 4)

        local tpBox = Instance.new("TextButton")
        tpBox.Size = UDim2.new(0.96, 0, 0, 42)
        tpBox.Position = UDim2.new(0, 0, 0, posY + 73)
        tpBox.BackgroundColor3 = Color3.fromRGB(43, 39, 27)
        tpBox.Text = ""
        tpBox.AutoButtonColor = true
        tpBox.ZIndex = 2
        tpBox.Parent = locPage
        addCorner(tpBox, 6)
        addStroke(tpBox, Color3.fromRGB(98, 88, 56), 1.2)

        local tpText = Instance.new("TextLabel")
        tpText.Size = UDim2.new(1, -50, 1, 0)
        tpText.Position = UDim2.new(0, 14, 0, 0)
        tpText.BackgroundTransparency = 1
        tpText.Text = "Teleport To " .. initialZone
        tpText.TextColor3 = Color3.fromRGB(240, 238, 230)
        tpText.TextSize = 13
        tpText.Font = Enum.Font.GothamBold
        tpText.TextXAlignment = Enum.TextXAlignment.Left
        tpText.ZIndex = 3
        tpText.Parent = tpBox

        local tpIcon = Instance.new("TextLabel")
        tpIcon.Size = UDim2.new(0, 32, 0, 32)
        tpIcon.Position = UDim2.new(1, -38, 0.5, -16)
        tpIcon.BackgroundTransparency = 1
        tpIcon.Text = "✵"
        tpIcon.TextColor3 = Color3.fromRGB(245, 240, 225)
        tpIcon.TextSize = 19
        tpIcon.Font = Enum.Font.GothamBold
        tpIcon.ZIndex = 3
        tpIcon.Parent = tpBox

        for i, zName in ipairs(zonesList) do
            local zBtn = Instance.new("TextButton")
            zBtn.Size = UDim2.new(1, -5, 0, 26)
            zBtn.Position = UDim2.new(0, 0, 0, (i - 1) * 28)
            zBtn.BackgroundTransparency = 1
            zBtn.Text = zName
            zBtn.TextColor3 = Color3.fromRGB(235, 230, 215)
            zBtn.TextSize = 11
            zBtn.Font = Enum.Font.Gotham
            zBtn.ZIndex = zIndexBase + 16
            zBtn.Parent = dropList

            zBtn.Activated:Connect(function()
                dropBtn.Text = zName .. " ▾"
                tpText.Text = "Teleport To " .. zName
                dropList.Visible = false
                onSelectZone(zName)
            end)
        end

        dropBtn.Activated:Connect(function()
            dropList.Visible = not dropList.Visible
        end)

        tpBox.Activated:Connect(onTeleportClick)
    end

    createZoneSection("Qi Zone", 5, Constants.QI_ZONES_LIST, State.selectedQiZone, 8, function(zName)
        State.selectedQiZone = zName
        Config.selectedQiZone = zName
        saveConfig()
    end, function()
        if instantTeleportToZone then
            task.spawn(function() instantTeleportToZone(State.selectedQiZone) end)
        end
    end)

    createZoneSection("Body Zone", 140, Constants.BODY_ZONES_LIST, State.selectedBodyZone, 5, function(zName)
        State.selectedBodyZone = zName
        Config.selectedBodyZone = zName
        saveConfig()
    end, function()
        if instantTeleportToZone then
            task.spawn(function() instantTeleportToZone(State.selectedBodyZone) end)
        end
    end)

    local zoneStatusLabel = Instance.new("TextLabel")
    zoneStatusLabel.Size = UDim2.new(0.96, 0, 0, 32)
    zoneStatusLabel.Position = UDim2.new(0, 4, 0, 265)
    zoneStatusLabel.BackgroundTransparency = 1
    zoneStatusLabel.TextWrapped = true
    zoneStatusLabel.Text = "Status Location: Siap Teleport kapan saja (Saat kultivasi/terbang otomatis di-handle)."
    zoneStatusLabel.TextColor3 = Color3.fromRGB(180, 210, 160)
    zoneStatusLabel.TextSize = 11
    zoneStatusLabel.Font = Enum.Font.GothamMedium
    zoneStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
    zoneStatusLabel.Parent = locPage
    UI.ZoneStatusLabel = zoneStatusLabel
end

-------------------------------------------------------------------------
-- BUILD PAGE 3: SETTING CATALOG
-------------------------------------------------------------------------
do
    local setPage = UI.SettingPage

    local settingTitle = Instance.new("TextLabel")
    settingTitle.Size = UDim2.new(1, 0, 0, 20)
    settingTitle.BackgroundTransparency = 1
    settingTitle.Text = "UI Keybind & Auto-Save Config"
    settingTitle.TextColor3 = Color3.fromRGB(180, 180, 180)
    settingTitle.TextSize = 13
    settingTitle.Font = Enum.Font.GothamBold
    settingTitle.TextXAlignment = Enum.TextXAlignment.Left
    settingTitle.Parent = setPage

    local keybindContainer = Instance.new("Frame")
    keybindContainer.Size = UDim2.new(0.96, 0, 0, 38)
    keybindContainer.Position = UDim2.new(0, 0, 0, 25)
    keybindContainer.BackgroundColor3 = Color3.fromRGB(32, 26, 38)
    keybindContainer.Parent = setPage
    addCorner(keybindContainer, 6)

    local keyLabel = Instance.new("TextLabel")
    keyLabel.Size = UDim2.new(0.6, 0, 1, 0)
    keyLabel.Position = UDim2.new(0, 10, 0, 0)
    keyLabel.BackgroundTransparency = 1
    keyLabel.Text = "PC Toggle Key"
    keyLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    keyLabel.TextSize = 12
    keyLabel.Font = Enum.Font.Gotham
    keyLabel.TextXAlignment = Enum.TextXAlignment.Left
    keyLabel.Parent = keybindContainer

    local keyInputBox = Instance.new("TextBox")
    keyInputBox.Size = UDim2.new(0, 95, 0, 24)
    keyInputBox.Position = UDim2.new(1, -105, 0.5, -12)
    keyInputBox.BackgroundColor3 = Color3.fromRGB(45, 36, 54)
    keyInputBox.Text = State.toggleKey.Name
    keyInputBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    keyInputBox.TextSize = 11
    keyInputBox.Font = Enum.Font.GothamBold
    keyInputBox.Parent = keybindContainer
    addCorner(keyInputBox, 4)

    keyInputBox.Focused:Connect(function()
        keyInputBox.Text = "..."
    end)

    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if keyInputBox:IsFocused() and input.UserInputType == Enum.UserInputType.Keyboard then
            State.toggleKey = input.KeyCode
            Config.toggleKeyName = State.toggleKey.Name
            keyInputBox.Text = State.toggleKey.Name
            keyInputBox:ReleaseFocus()
            saveConfig()
        elseif not gameProcessed and input.KeyCode == State.toggleKey then
            State.uiVisible = not State.uiVisible
            UI.MainFrame.Visible = State.uiVisible
        end
    end)

    local resetConfigBtn = Instance.new("TextButton")
    resetConfigBtn.Size = UDim2.new(0.96, 0, 0, 36)
    resetConfigBtn.Position = UDim2.new(0, 0, 0, 72)
    resetConfigBtn.BackgroundColor3 = Color3.fromRGB(140, 45, 55)
    resetConfigBtn.Text = "Reset Saved Config to Default"
    resetConfigBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    resetConfigBtn.TextSize = 12
    resetConfigBtn.Font = Enum.Font.GothamBold
    resetConfigBtn.Parent = setPage
    addCorner(resetConfigBtn, 6)

    resetConfigBtn.Activated:Connect(function()
        pcall(function()
            if delfile and isfile and isfile(CONFIG_FILE_NAME) then
                delfile(CONFIG_FILE_NAME)
            end
        end)
        resetConfigBtn.Text = "Config Berhasil Direset!"
        task.wait(1.5)
        resetConfigBtn.Text = "Reset Saved Config to Default"
    end)

    local infoBox = Instance.new("TextLabel")
    infoBox.Size = UDim2.new(0.96, 0, 0, 140)
    infoBox.Position = UDim2.new(0, 0, 0, 118)
    infoBox.BackgroundTransparency = 1
    infoBox.TextWrapped = true
    infoBox.Text = "• Auto Create Pills: Zero-Lag (Tanpa pindah Cauldron berulang) + Deteksi 3 Kolom Slot Presisi + Instant Claim.\n• Auto Realm & Body: Deteksi Animasi & Event (<0.2s langsung aktif saat berhenti).\n• Teleportasi: Otomatis melepas kunci terbang/kultivasi sebelum pindah & lanjut kultivasi di tempat baru."
    infoBox.TextColor3 = Color3.fromRGB(160, 160, 160)
    infoBox.TextSize = 11
    infoBox.Font = Enum.Font.Gotham
    infoBox.TextXAlignment = Enum.TextXAlignment.Left
    infoBox.TextYAlignment = Enum.TextYAlignment.Top
    infoBox.Parent = setPage
end


-------------------------------------------------------------------------
-- CU1: ABA LOGS (SALVAR TXT / COPIAR / TXT AUTOMATICO)
-------------------------------------------------------------------------
do
    local page = UI.LogsPage

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 20)
    title.BackgroundTransparency = 1
    title.Text = "Log de diagnostico (" .. CU_LOG.version .. ")"
    title.TextColor3 = Color3.fromRGB(180, 180, 180)
    title.TextSize = 13
    title.Font = Enum.Font.GothamBold
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = page

    local status = Instance.new("TextLabel")
    status.Size = UDim2.new(0.96, 0, 0, 34)
    status.Position = UDim2.new(0, 0, 0, 152)
    status.BackgroundTransparency = 1
    status.TextWrapped = true
    status.Text = "Depois de testar, salve o TXT e mande para analise."
    status.TextColor3 = Color3.fromRGB(200, 200, 120)
    status.TextSize = 11
    status.Font = Enum.Font.Gotham
    status.TextXAlignment = Enum.TextXAlignment.Left
    status.TextYAlignment = Enum.TextYAlignment.Top
    status.Parent = page

    local function makeButton(text, posY, color, onClick)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(0.96, 0, 0, 36)
        b.Position = UDim2.new(0, 0, 0, posY)
        b.BackgroundColor3 = color
        b.Text = text
        b.TextColor3 = Color3.fromRGB(255, 255, 255)
        b.TextSize = 12
        b.Font = Enum.Font.GothamBold
        b.Parent = page
        addCorner(b, 6)
        b.Activated:Connect(function() CU_LOG.try("Botao " .. text, onClick) end)
        return b
    end

    makeButton("Salvar TXT do log", 25, Color3.fromRGB(45, 110, 70), function()
        local ok, info = CU_LOG.save()
        status.Text = ok and ("TXT salvo na pasta do executor: " .. tostring(info)) or ("Nao salvou: " .. tostring(info))
    end)
    makeButton("Copiar log (resumo + ultimos eventos)", 67, Color3.fromRGB(45, 70, 120), function()
        local ok, info = CU_LOG.copy()
        status.Text = ok and ("Copiado: " .. tostring(info) .. " caracteres") or ("Nao copiou: " .. tostring(info))
    end)
    createToggleRow(page, 109, "TXT automatico a cada 5 min", CU_LOG.autoSave, nil, function(val)
        CU_LOG.autoSave = val
    end)

    local summary = Instance.new("TextLabel")
    summary.Size = UDim2.new(0.96, 0, 0, 190)
    summary.Position = UDim2.new(0, 0, 0, 190)
    summary.BackgroundTransparency = 1
    summary.TextWrapped = true
    summary.Text = ""
    summary.TextColor3 = Color3.fromRGB(160, 160, 160)
    summary.TextSize = 11
    summary.Font = Enum.Font.Gotham
    summary.TextXAlignment = Enum.TextXAlignment.Left
    summary.TextYAlignment = Enum.TextYAlignment.Top
    summary.Parent = page

    CU_LOG.spawnLoop("Aba Logs", function()
        while UI.ScreenGui and UI.ScreenGui.Parent do
            if page.Visible then
                local c = CU_LOG.counts
                local function n(k) return c[k] or 0 end
                summary.Text = string.format("Erros: %d tipo(s)\nCliques na tela: getconnections %d, firesignal %d, mouse VIM %d, sem metodo %d\nTeclas simuladas com erro: %d\nEventos do servidor recebidos: %d tipos\nFuncoes ligadas: %s\nEventos no log: %d",
                    #CU_LOG.errorOrder, n("Cliques na tela: getconnections"), n("Cliques na tela: firesignal"),
                    n("Cliques na tela: mouse VIM"), n("Cliques na tela: nenhum metodo (botao invisivel, menu aberto ou caixa de texto)"),
                    n("Teclas simuladas: ERRO"), #CU_LOG.remoteOrder, CU_LOG.activeList(), #CU_LOG.entries)
                summary.Text = summary.Text .. "\n" .. CU2.statusLine()
            end
            task.wait(2)
        end
    end)
end

-------------------------------------------------------------------------
-- TELEPORTASI PRESISI (BISA SAAT KULTIVASI, LATIHAN TUBUH, ATAU TERBANG)
-------------------------------------------------------------------------
do
    local function refineFloorInsideZone(basePos, zoneName)
        local normTarget = normalizeName(zoneName)

        -- 1. Cek part zona spesifik di CultivationZones / BodyCultivationZones / MapAnchors jika sudah ter-stream
        for _, folderName in ipairs({"CultivationZones", "BodyCultivationZones", "MapAnchors"}) do
            local folder = Workspace:FindFirstChild(folderName)
            if folder then
                for _, ch in pairs(folder:GetChildren()) do
                    if normalizeName(ch.Name):find(normTarget, 1, true) and ch:IsA("BasePart") then
                        basePos = ch.Position
                        break
                    end
                end
            end
        end

        -- 2. Cek halaman/yard di Landmarks jika sudah ter-stream
        local mapModel = Workspace:FindFirstChild("Map_sacred-mountain")
        local landmarks = mapModel and mapModel:FindFirstChild("Landmarks")
        if landmarks then
            local lmFolder = landmarks:FindFirstChild(zoneName)
            if lmFolder then
                for _, d in pairs(lmFolder:GetDescendants()) do
                    if d:IsA("BasePart") then
                        local pLow = d.Name:lower()
                        local mLow = d.Parent and d.Parent.Name:lower() or ""
                        if pLow:find("zone") or pLow:find("yard") or pLow:find("ring") or pLow:find("arena") or pLow:find("floor")
                            or mLow:find("yard") or mLow:find("ring") or mLow:find("crucible") or mLow:find("colosseum") or mLow:find("forge") then
                            basePos = d.Position
                            break
                        end
                    end
                end
            end
        end

        -- 3. Raycast ke permukaan lantai agar tidak melayang atau menembus tanah
        local rayParams = RaycastParams.new()
        rayParams.FilterType = Enum.RaycastFilterType.Exclude
        rayParams.FilterDescendantsInstances = {LocalPlayer.Character}

        local rayResult = Workspace:Raycast(Vector3.new(basePos.X, basePos.Y + 25, basePos.Z), Vector3.new(0, -150, 0), rayParams)
        if rayResult then
            return rayResult.Position + Vector3.new(0, 3.0, 0)
        end
        return basePos + Vector3.new(0, 3.0, 0)
    end

    -- Membersihkan semua pengunci gerak (kultivasi, pushup, tween autofarm, sword flight) sebelum teleport
    local function releaseAllMovementLocks(char, root, hum)
        -- 1. Hentikan Tween Autofarm Herb yang sedang berjalan agar tidak menarik balik karakter
        if State.activeFarmTween then
            pcall(function() State.activeFarmTween:Cancel() end)
            State.activeFarmTween = nil
        end
        if State.activeFarmVelocity then
            pcall(function() State.activeFarmVelocity:Destroy() end)
            State.activeFarmVelocity = nil
        end

        -- 2. Hapus semua BodyMover / Constraint terbang pada karakter
        if char then
            for _, desc in pairs(char:GetDescendants()) do
                if desc:IsA("BodyMover") or desc:IsA("LinearVelocity") or desc:IsA("AlignPosition") or desc:IsA("AlignOrientation") then
                    pcall(function() desc:Destroy() end)
                end
            end
        end

        -- 3. Lepaskan kunci MovementGuardRules server/client dari Meditasi, Pushup, atau SwordFlight
        pcall(function()
            local stopMedBind = ReplicatedStorage:FindFirstChild("LocalStopMeditate")
            if stopMedBind and stopMedBind:IsA("BindableEvent") then stopMedBind:Fire() end

            local stopPushBind = ReplicatedStorage:FindFirstChild("LocalStopPushup")
            if stopPushBind and stopPushBind:IsA("BindableEvent") then stopPushBind:Fire() end

            if CultivationEvents then
                if CultivationEvents:FindFirstChild("StopMeditate") then
                    CU_LOG.sent("StopMeditate"); CultivationEvents.StopMeditate:FireServer()
                end
                if CultivationEvents:FindFirstChild("StopPushup") then
                    CU_LOG.sent("StopPushup"); CultivationEvents.StopPushup:FireServer()
                end
                if CultivationEvents:FindFirstChild("SwordFlight") then
                    CU_LOG.sent("SwordFlight"); CultivationEvents.SwordFlight:FireServer(false)
                end
            end
        end)

        -- 4. Reset state Humanoid & RootPart
        if root then
            root.Anchored = false
            root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
            root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
        end
        if hum then
            hum.Sit = false
            hum.PlatformStand = false
            pcall(function()
                hum:ChangeState(Enum.HumanoidStateType.GettingUp)
                hum:ChangeState(Enum.HumanoidStateType.Running)
            end)
            local animator = hum:FindFirstChildWhichIsA("Animator")
            if animator then
                for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
                    local anim = track.Animation
                    local animateFolder = char:FindFirstChild("Animate")
                    if not (anim and animateFolder and anim:IsDescendantOf(animateFolder)) then
                        pcall(function() track:Stop(0) end)
                    end
                end
            end
        end
    end

    instantTeleportToZone = function(zoneName)
        if State.isTeleportingZone then return end
        State.isTeleportingZone = true

        local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
        local root = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChildWhichIsA("Humanoid")

        if not root then
            UI.ZoneStatusLabel.Text = "Status: Karakter belum siap!"
            State.isTeleportingZone = false
            return
        end

        local targetCoord = Constants.EXACT_ZONE_COORDS[zoneName]
        if not targetCoord then
            UI.ZoneStatusLabel.Text = "Koordinat zona tidak ditemukan!"
            State.isTeleportingZone = false
            return
        end

        UI.ZoneStatusLabel.Text = "Melepas kunci gerak/terbang & menyiapkan Teleport ke " .. zoneName .. "..."
        local cuTp = os.clock()
        CU_LOG.add("TELEPORTE", zoneName, string.format("inicio em (%d, %d, %d)", math.round(root.Position.X), math.round(root.Position.Y), math.round(root.Position.Z)), 0)

        -- Langkah 1: Lepaskan semua pengunci kultivasi / pushup / terbang terlebih dahulu
        releaseAllMovementLocks(char, root, hum)
        task.wait(0.16)

        -- Langkah 2: Minta server men-stream area tujuan
        pcall(function()
            LocalPlayer:RequestStreamAroundAsync(targetCoord, 2.5)
        end)

        UI.ZoneStatusLabel.Text = "Teleportasi Instan ke " .. zoneName .. "..."

        -- Langkah 3: Pindahkan karakter secara instan ke koordinat zona
        for _ = 1, 8 do
            root.Anchored = false
            root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
            root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
            char:PivotTo(CFrame.new(targetCoord + Vector3.new(0, 4, 0)))
            root.CFrame = CFrame.new(targetCoord + Vector3.new(0, 4, 0))
            RunService.Heartbeat:Wait()
        end

        task.wait(0.18)

        -- Langkah 4: Presisikan tepat di lantai tengah buff zone setelah objek sekitar ter-render
        local finalBuffPos = refineFloorInsideZone(targetCoord, zoneName)
        for _ = 1, 10 do
            root.Anchored = false
            root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
            root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
            char:PivotTo(CFrame.new(finalBuffPos))
            root.CFrame = CFrame.new(finalBuffPos)
            RunService.Heartbeat:Wait()
        end

        -- Langkah 5: Aktifkan kembali Auto Realm atau Auto Body secara instan di zona baru!
        State.lastQiServerTick = 0
        State.lastBodyServerTick = 0
        State.lastRealmTrigger = 0
        State.lastBodyTrigger = 0
        State.forceImmediateCultivate = true

        UI.ZoneStatusLabel.Text = string.format("Berhasil Teleport ke %s! (%d, %d, %d)", zoneName, math.round(finalBuffPos.X), math.round(finalBuffPos.Y), math.round(finalBuffPos.Z))
        CU_LOG.count("Teleporte: zonas")
        CU_LOG.add("TELEPORTE", zoneName, string.format("chegou em %.1fs; alvo (%d, %d, %d), posicao final (%d, %d, %d)", os.clock() - cuTp, math.round(finalBuffPos.X), math.round(finalBuffPos.Y), math.round(finalBuffPos.Z), math.round(root.Position.X), math.round(root.Position.Y), math.round(root.Position.Z)), 0)
        State.isTeleportingZone = false
    end
end

-------------------------------------------------------------------------
-- AUTO REALM (StartMeditate / M) & AUTO BODY (StartPushup / P) - INSTANT RESUME
-------------------------------------------------------------------------
do
    -- 1. Dengarkan detak server dan event berhenti untuk responsivitas instan (<0.2s)
    if CultivationEvents then
        local updateClientRem = CultivationEvents:FindFirstChild("UpdateClient")
        if updateClientRem and updateClientRem:IsA("RemoteEvent") then
            updateClientRem.OnClientEvent:Connect(function()
                State.lastQiServerTick = tick()
            end)
        end

        local updateBodyRem = CultivationEvents:FindFirstChild("UpdateBodyClient")
        if updateBodyRem and updateBodyRem:IsA("RemoteEvent") then
            updateBodyRem.OnClientEvent:Connect(function()
                State.lastBodyServerTick = tick()
            end)
        end

        -- Jika server mengirim sinyal berhenti/selesai breakthrough, langsung picu resume instan!
        for _, evName in ipairs({
            "StopMeditate", "StopPushup", "BreakthroughEffect",
            "BodyBreakthroughCutsceneDone", "CultivateResumed", "BreakthroughMinigameResult"
        }) do
            local ev = CultivationEvents:FindFirstChild(evName)
            if ev and ev:IsA("RemoteEvent") then
                ev.OnClientEvent:Connect(function()
                    State.lastQiServerTick = 0
                    State.lastBodyServerTick = 0
                    State.lastRealmTrigger = 0
                    State.lastBodyTrigger = 0
                    State.forceImmediateCultivate = true
                end)
            end
        end
    end

    for _, bindName in ipairs({"LocalStopMeditate", "LocalStopPushup", "RealmBreakthroughNotify"}) do
        local bEv = ReplicatedStorage:FindFirstChild(bindName)
        if bEv and bEv:IsA("BindableEvent") then
            bEv.Event:Connect(function()
                State.lastQiServerTick = 0
                State.lastBodyServerTick = 0
                State.lastRealmTrigger = 0
                State.lastBodyTrigger = 0
                State.forceImmediateCultivate = true
            end)
        end
    end

    -- 2. Fungsi pengecek apakah karakter sedang memainkan animasi Meditasi / Pushup (Non-Idle)
    local function hasActiveCultivationAnimation(char)
        if not char then return false end
        local hum = char:FindFirstChildWhichIsA("Humanoid")
        local animator = hum and hum:FindFirstChildWhichIsA("Animator")
        if not animator then return false end

        local animateFolder = char:FindFirstChild("Animate")
        for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
            if track.IsPlaying and track.WeightCurrent > 0.05 then
                local anim = track.Animation
                local isDefault = false
                if anim and animateFolder and anim:IsDescendantOf(animateFolder) then
                    isDefault = true
                end
                local tName = (track.Name or ""):lower()
                if tName == "animation1" or tName == "animation2" or tName == "idle" or tName == "walk"
                    or tName == "run" or tName == "jump" or tName == "fall" or tName == "toolnone" then
                    isDefault = true
                end
                if not isDefault then
                    return true
                end
            end
        end
        return false
    end

    -- 3. Loop Responsif (Mengecek setiap 0.15 detik, langsung aktif begitu karakter berhenti)
    CU_LOG.spawnLoop("Realm/Body", function()
        while true do
            local cu2Busy = (State.autoRealmActive or State.autoBodyActive) and CU2.busy()
            if cu2Busy then CU_LOG.count("Realm/Body: pausado (" .. cu2Busy .. ")") end
            if (State.autoRealmActive or State.autoBodyActive) and not isUserTypingOrInMenu() and not State.isTeleportingZone and not State.autoFarmActive and not State.autoKillActive and not cu2Busy then
                local char = LocalPlayer.Character
                local hum = char and char:FindFirstChildWhichIsA("Humanoid")
                local root = char and char:FindFirstChild("HumanoidRootPart")
                local isMoving = hum and (hum.MoveDirection.Magnitude > 0.05 or (root and root.AssemblyLinearVelocity.Magnitude > 4))

                if isMoving then
                    CU_LOG.count("Realm/Body: personagem andando (reinicia ao parar)")
                    State.lastQiServerTick = 0
                    State.lastBodyServerTick = 0
                    State.lastRealmTrigger = 0
                    State.lastBodyTrigger = 0
                    State.forceImmediateCultivate = true
                else
                    -- Jangan tekan M/P hanya jika sedang di tengah minigame Breakthrough Trial
                    local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
                    local inTrial = false
                    if playerGui then
                        for _, obj in pairs(playerGui:GetDescendants()) do
                            if (obj:IsA("TextLabel") or obj:IsA("TextButton")) and isActuallyVisible(obj) then
                                local t = trimText(obj.Text)
                                if t:find("breakthrough trial", 1, true) or t:find("ring turns gold", 1, true) then
                                    inTrial = true
                                    break
                                end
                            end
                        end
                    end

                    if inTrial then CU_LOG.count("Realm/Body: minijogo de breakthrough aberto (espera)") end
                    if not inTrial then
                        local now = tick()
                        local animPlaying = hasActiveCultivationAnimation(char)
                        CU_LOG.add("STATUS", "Realm/Body", string.format("animacao de cultivo=%s | UpdateClient ha %s | UpdateBodyClient ha %s",
                            tostring(animPlaying), CU_LOG.ago(State.lastQiServerTick, now), CU_LOG.ago(State.lastBodyServerTick, now)), 30, "realm-status")

                        if State.autoRealmActive then
                            local serverActive = (now - State.lastQiServerTick) < 1.35
                            local isCultivating = animPlaying and serverActive
                            local cooldown = State.forceImmediateCultivate and 0.25 or 1.35

                            if (not isCultivating or State.forceImmediateCultivate) and (now - State.lastRealmTrigger) >= cooldown then
                                State.lastRealmTrigger = now
                                State.forceImmediateCultivate = false
                                pcall(function()
                                    if CultivationEvents and CultivationEvents:FindFirstChild("StartMeditate") then
                                        CU_LOG.sent("StartMeditate"); CultivationEvents.StartMeditate:FireServer()
                                    end
                                end)
                                if not animPlaying then
                                    triggerKeyPress("M")
                                end
                            end
                        elseif State.autoBodyActive then
                            local serverActive = (now - State.lastBodyServerTick) < 1.35
                            local isTraining = animPlaying and serverActive
                            local cooldown = State.forceImmediateCultivate and 0.25 or 1.35

                            if (not isTraining or State.forceImmediateCultivate) and (now - State.lastBodyTrigger) >= cooldown then
                                State.lastBodyTrigger = now
                                State.forceImmediateCultivate = false
                                pcall(function()
                                    if CultivationEvents and CultivationEvents:FindFirstChild("StartPushup") then
                                        CU_LOG.sent("StartPushup"); CultivationEvents.StartPushup:FireServer()
                                    end
                                end)
                                if not animPlaying then
                                    triggerKeyPress("P")
                                end
                            end
                        end
                    end
                end
            end
            task.wait(0.15)
        end
    end)
end

-------------------------------------------------------------------------
-- 1. FARMING LOGIC (HERBS - PRIORITY 1000YR > 100YR > 10YR > 1YR)
-------------------------------------------------------------------------
CU_LOG.spawnLoop("Ervas", function()
    local function cleanBlacklist()
        local now = tick()
        for obj, timeAdded in pairs(State.harvestedBlacklist) do
            if now - timeAdded > State.blacklistDuration then
                State.harvestedBlacklist[obj] = nil
            end
        end
    end

    local function getValidPrompt(object)
        local prompt = object:FindFirstChildWhichIsA("ProximityPrompt", true)
        if prompt and prompt.Enabled and prompt.Parent then return prompt end
        if object.Parent then
            local parentPrompt = object.Parent:FindFirstChildWhichIsA("ProximityPrompt", true)
            if parentPrompt and parentPrompt.Enabled then return parentPrompt end
        end
        return nil
    end

    local function getHerbLevelScore(obj, prompt)
        local score = 1
        local texts = {obj.Name}
        if obj.Parent and obj.Parent ~= Workspace then table.insert(texts, obj.Parent.Name) end
        if prompt then
            table.insert(texts, prompt.ObjectText or "")
            table.insert(texts, prompt.ActionText or "")
        end
        pcall(function()
            for k, v in pairs(obj:GetAttributes()) do
                table.insert(texts, tostring(k) .. " " .. tostring(v))
            end
        end)
        for _, desc in pairs(obj:GetDescendants()) do
            if desc:IsA("TextLabel") then table.insert(texts, desc.Text) end
        end
        local combined = table.concat(texts, " "):lower()
        for _, yrData in ipairs(Constants.HERB_YEAR_PRIORITY) do
            if combined:find(yrData.pattern, 1, true) then
                score = math.max(score, yrData.score)
                break
            end
        end
        return score
    end

    local function getBestAndClosestHerb(root)
        cleanBlacklist()
        local bestHerb = nil
        local highestScore = -1
        local shortestDistance = math.huge

        local searchRoot = Workspace:FindFirstChild("HerbSpots") or Workspace
        for _, obj in pairs(searchRoot:GetDescendants()) do
            if not State.harvestedBlacklist[obj] and (obj:IsA("BasePart") or obj:IsA("Model")) then
                if obj.Name:lower():find(State.selectedHerb:lower()) then
                    local partToTarget = obj:IsA("Model") and (obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")) or obj
                    if partToTarget then
                        local prompt = getValidPrompt(obj)
                        if prompt then
                            local levelScore = getHerbLevelScore(obj, prompt)
                            local distance = (root.Position - partToTarget.Position).Magnitude
                            if (levelScore > highestScore) or (levelScore == highestScore and distance < shortestDistance) then
                                highestScore = levelScore
                                shortestDistance = distance
                                bestHerb = {Object = obj, Part = partToTarget, Prompt = prompt}
                            end
                        else
                            State.harvestedBlacklist[obj] = tick()
                        end
                    end
                end
            end
        end
        return bestHerb
    end

    local function flyToTarget(root, targetPart)
        local distance = (root.Position - targetPart.Position).Magnitude
        local duration = distance / State.flySpeed
        local tween = TweenService:Create(
            root,
            TweenInfo.new(duration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out),
            {CFrame = targetPart.CFrame * CFrame.new(0, 3, 0)}
        )
        State.activeFarmTween = tween

        local bodyVelocity = Instance.new("BodyVelocity")
        bodyVelocity.Velocity = Vector3.new(0, 0, 0)
        bodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        bodyVelocity.Parent = root
        State.activeFarmVelocity = bodyVelocity

        tween:Play()
        local completed = false
        local conn = tween.Completed:Connect(function() completed = true end)
        while not completed and State.autoFarmActive and not State.isTeleportingZone and not CU2.mobBusy and not (CU2.event and CU2.on("sectClash")) do
            task.wait(0.08)
        end
        if not completed then
            pcall(function() tween:Cancel() end)
        end
        if conn then conn:Disconnect() end
        pcall(function() bodyVelocity:Destroy() end)
        State.activeFarmTween = nil
        State.activeFarmVelocity = nil
    end

    while true do
        if State.autoFarmActive and not State.isTeleportingZone and not CU2.herbBlocked() then
            local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
            local root = char:FindFirstChild("HumanoidRootPart")
            if root then
                local targetData = getBestAndClosestHerb(root)
                CU_LOG.herb(targetData, root, State.selectedHerb)
                if targetData and State.autoFarmActive and not State.isTeleportingZone then
                    if targetData.Prompt and targetData.Prompt.Enabled then
                        local cuFly = os.clock()
                        flyToTarget(root, targetData.Part)
                        CU_LOG.count("Ervas: voos")
                        CU_LOG.add("ERVA", "voo", string.format("%.1fs ate %s; ficou a %.0f studs", os.clock() - cuFly, tostring(targetData.Object.Name), (root.Position - targetData.Part.Position).Magnitude), 2)
                        if State.autoFarmActive and not State.isTeleportingZone and not CU2.mobBusy and targetData.Prompt and targetData.Prompt.Enabled then
                            if fireproximityprompt then
                                CU_LOG.count("Ervas: coleta via fireproximityprompt")
                                fireproximityprompt(targetData.Prompt)
                            else
                                CU_LOG.count("Ervas: coleta via InputHold (sem fireproximityprompt)")
                                targetData.Prompt:InputHoldBegin()
                                task.wait(targetData.Prompt.HoldDuration or 0.5)
                                targetData.Prompt:InputHoldEnd()
                            end
                            State.harvestedBlacklist[targetData.Object] = tick()
                            task.wait(State.waitAtHerb)
                        end
                    else
                        State.harvestedBlacklist[targetData.Object] = tick()
                    end
                else
                    task.wait(1.0)
                end
            else
                task.wait(1.0)
            end
        else
            task.wait(0.4)
        end
    end
end)

-------------------------------------------------------------------------
-- 2. AUTOCREATE PILLS (ZERO-LAG ANYWHERE + 3-COLUMN SLOT + INSTANT CLAIM)
-------------------------------------------------------------------------
do
    -- Instant Claim Listener saat server mengirim sinyal selesai masak
    if CultivationEvents then
        local brewCompleteRem = CultivationEvents:FindFirstChild("CauldronBrewComplete")
        if brewCompleteRem and brewCompleteRem:IsA("RemoteEvent") then
            brewCompleteRem.OnClientEvent:Connect(function()
                if State.autoPillActive then
                    pcall(function() CU_LOG.sent("CauldronClaim"); CultivationEvents.CauldronClaim:FireServer() end)
                end
            end)
        end

        local stokeResRem = CultivationEvents:FindFirstChild("CauldronStokeResult")
        if stokeResRem and stokeResRem:IsA("RemoteEvent") then
            stokeResRem.OnClientEvent:Connect(function()
                if State.autoPillActive then
                    State.isBrewingWaitClaim = true
                    task.spawn(function()
                        for _ = 1, 15 do
                            if not State.autoPillActive then break end
                            pcall(function() CU_LOG.sent("CauldronClaim"); CultivationEvents.CauldronClaim:FireServer() end)
                            task.wait(0.25)
                        end
                    end)
                end
            end)
        end
    end

    CU_LOG.spawnLoop("Pilulas", function()
        local lastCauldronOpenAttempt = 0

        local function findVisibleTextElement(targetStr, exactMatch)
            local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
            if not playerGui then return nil end
            local targetLower = trimText(targetStr)

            for _, obj in pairs(playerGui:GetDescendants()) do
                if obj ~= UI.ScreenGui and not obj:IsDescendantOf(UI.ScreenGui) then
                    if (obj:IsA("TextLabel") or obj:IsA("TextButton")) and isActuallyVisible(obj) then
                        local textLower = trimText(obj.Text)
                        if (exactMatch and textLower == targetLower) or (not exactMatch and textLower:find(targetLower, 1, true)) then
                            return obj
                        end
                    end
                end
            end
            return nil
        end

        -- Membuka Cauldron dari mana saja TANPA memindahkan Cauldron setiap frame (Bebas Patah-Patah / Lag!)
        local function openCauldronZeroLag()
            local isOpen = findVisibleTextElement("alchemy cauldron", false)
                or findVisibleTextElement("choose a herb", false)
                or findVisibleTextElement("stoke", true)

            if isOpen then return true end
            if tick() - lastCauldronOpenAttempt < 2.2 then return false end
            lastCauldronOpenAttempt = tick()

            local cauldronMesh = Workspace:FindFirstChild("CauldronForBrewing")
            if not cauldronMesh then CU_LOG.count("Pilulas: CauldronForBrewing nao encontrado no Workspace") end
            if cauldronMesh and cauldronMesh:IsA("BasePart") then
                if not State.cauldronOrigCFrame then
                    State.cauldronOrigCFrame = cauldronMesh.CFrame
                end

                local prompt = cauldronMesh:FindFirstChildWhichIsA("ProximityPrompt", true)
                local char = LocalPlayer.Character
                local root = char and char:FindFirstChild("HumanoidRootPart")

                if prompt and root then
                    pcall(function()
                        prompt.MaxActivationDistance = 100000
                        prompt.RequiresLineOfSight = false
                        prompt.HoldDuration = 0

                        -- Pindahkan ke bawah tanah (-12 studs) hanya selama 0.08 detik untuk memicu prompt tanpa menabrak karakter!
                        cauldronMesh.CanCollide = false
                        cauldronMesh.Anchored = true
                        cauldronMesh.CFrame = root.CFrame * CFrame.new(0, -12, 0)
                        CU_LOG.count("Pilulas: caldeirao puxado para baixo do personagem para abrir")
                    end)
                    task.wait(0.06)
                    pcall(function()
                        if fireproximityprompt then
                            fireproximityprompt(prompt)
                        else
                            prompt:InputHoldBegin()
                            task.wait(0.05)
                            prompt:InputHoldEnd()
                        end
                    end)
                end
            end
            return false
        end

        -- Membaca 3 Kolom Slot Cauldron berdasarkan koordinat X relatif terhadap jendela ALCHEMY CAULDRON
        local function getThreeColumnSlots(brewBtnObj)
            local cauldronWin = brewBtnObj.Parent
            while cauldronWin and cauldronWin ~= LocalPlayer.PlayerGui and cauldronWin.AbsoluteSize.Y < 220 do
                cauldronWin = cauldronWin.Parent
            end
            if not cauldronWin then return nil end

            local winX = cauldronWin.AbsolutePosition.X
            local winW = math.max(cauldronWin.AbsoluteSize.X, 1)
            local winY = cauldronWin.AbsolutePosition.Y
            local brewY = brewBtnObj.AbsolutePosition.Y

            local cols = {
                [1] = {AddBtn = nil, RemoveBtn = nil, FilledHerb = nil, IsEmpty = false},
                [2] = {AddBtn = nil, RemoveBtn = nil, FilledHerb = nil, IsEmpty = false},
                [3] = {AddBtn = nil, RemoveBtn = nil, FilledHerb = nil, IsEmpty = false}
            }

            for _, obj in pairs(cauldronWin:GetDescendants()) do
                if not obj:IsDescendantOf(UI.ScreenGui) and (obj:IsA("TextLabel") or obj:IsA("TextButton")) and isActuallyVisible(obj) then
                    local posY = obj.AbsolutePosition.Y
                    -- Hanya pindai elemen di area kotak slot (di bawah judul Cauldron dan di atas tombol Brew)
                    if posY > (winY + 35) and posY < (brewY - 8) then
                        local centerX = obj.AbsolutePosition.X + (obj.AbsoluteSize.X / 2)
                        local relX = (centerX - winX) / winW

                        local colIdx = 1
                        if relX < 0.37 then
                            colIdx = 1
                        elseif relX <= 0.63 then
                            colIdx = 2
                        else
                            colIdx = 3
                        end

                        local t = trimText(obj.Text)
                        local clickTarget = obj:IsA("GuiButton") and obj or obj:FindFirstAncestorWhichIsA("GuiButton") or obj

                        if t:find("add herb", 1, true) then
                            cols[colIdx].IsEmpty = true
                            cols[colIdx].AddBtn = clickTarget
                        elseif t:find("remove", 1, true) then
                            cols[colIdx].RemoveBtn = clickTarget
                        else
                            for _, hName in ipairs(Constants.HERBS_LIST) do
                                if t == hName:lower() or t:find("^" .. hName:lower() .. "%s") then
                                    cols[colIdx].FilledHerb = hName
                                    if not cols[colIdx].RemoveBtn then
                                        cols[colIdx].RemoveBtn = clickTarget
                                    end
                                    break
                                end
                            end
                        end
                    end
                end
            end

            return cols
        end

        -- Memilih Herb dari jendela "Choose a herb" berdasarkan kesamaan baris horizontal (Y-Alignment)
        local function selectHerbFromChooseModal(targetHerbName)
            local modalHeader = findVisibleTextElement("choose a herb", false)
            if not modalHeader then return false end

            local modalWin = modalHeader.Parent
            while modalWin and modalWin ~= LocalPlayer.PlayerGui and modalWin.AbsoluteSize.Y < 200 do
                modalWin = modalWin.Parent
            end
            if not modalWin then modalWin = LocalPlayer.PlayerGui end

            local targetLower = trimText(targetHerbName)
            local scrollFrame = modalWin:FindFirstChildWhichIsA("ScrollingFrame", true)

            local function findInCurrentView()
                local candidates = {}
                local visibleLabels = {}

                for _, obj in pairs(modalWin:GetDescendants()) do
                    if not obj:IsDescendantOf(UI.ScreenGui) and (obj:IsA("TextLabel") or obj:IsA("TextButton")) and isActuallyVisible(obj) then
                        table.insert(visibleLabels, obj)
                    end
                end

                for _, obj in ipairs(visibleLabels) do
                    if trimText(obj.Text) == "choose" then
                        local chooseBtn = obj:IsA("GuiButton") and obj or obj:FindFirstAncestorWhichIsA("GuiButton") or obj
                        local cY = chooseBtn.AbsolutePosition.Y + (chooseBtn.AbsoluteSize.Y / 2)

                        local lineTexts = {}
                        for _, other in ipairs(visibleLabels) do
                            if other ~= obj then
                                local oY = other.AbsolutePosition.Y + (other.AbsoluteSize.Y / 2)
                                if math.abs(oY - cY) < 30 then
                                    table.insert(lineTexts, trimText(other.Text))
                                end
                            end
                        end

                        local combinedLine = table.concat(lineTexts, " ")
                        local matchedRightHerb = false

                        for _, hName in ipairs(Constants.HERBS_LIST) do
                            local hLow = hName:lower()
                            if combinedLine:find(hLow, 1, true) then
                                if hLow == targetLower then
                                    matchedRightHerb = true
                                else
                                    matchedRightHerb = false
                                    break
                                end
                            end
                        end

                        if matchedRightHerb then
                            local yearScore = 1
                            if combinedLine:find("1000", 1, true) then yearScore = 4
                            elseif combinedLine:find("100", 1, true) then yearScore = 3
                            elseif combinedLine:find("10", 1, true) then yearScore = 2 end

                            local qty = 1
                            local qMatch = combinedLine:match("x(%d+)")
                            if qMatch then qty = tonumber(qMatch) or 1 end

                            if qty > 0 then
                                table.insert(candidates, {
                                    ChooseBtn = chooseBtn,
                                    Score = yearScore
                                })
                            end
                        end
                    end
                end

                table.sort(candidates, function(a, b) return a.Score > b.Score end)
                return candidates[1]
            end

            if scrollFrame then
                scrollFrame.CanvasPosition = Vector2.new(0, 0)
                task.wait(0.12)
            end

            local best = findInCurrentView()

            if not best and scrollFrame then
                for step = 1, 4 do
                    scrollFrame.CanvasPosition = Vector2.new(0, step * 150)
                    task.wait(0.15)
                    best = findInCurrentView()
                    if best then break end
                end
            end

            if best and best.ChooseBtn then
                triggerGuiClick(best.ChooseBtn, false, false)
                return true
            end
            return false
        end

        local function handleStokeMinigame(stokeBtnObj)
            local modalContainer = stokeBtnObj.Parent
            while modalContainer and modalContainer ~= LocalPlayer.PlayerGui and modalContainer.AbsoluteSize.Y < 130 do
                modalContainer = modalContainer.Parent
            end
            if not modalContainer then return end

            local stokeY = stokeBtnObj.AbsolutePosition.Y
            local initialX = {}
            for _, obj in pairs(modalContainer:GetDescendants()) do
                if obj:IsA("GuiObject") and isActuallyVisible(obj) and obj.AbsolutePosition.Y < stokeY then
                    if obj.AbsoluteSize.X < 180 and obj.AbsoluteSize.Y <= 60 then
                        initialX[obj] = obj.AbsolutePosition.X
                    end
                end
            end

            RunService.RenderStepped:Wait()
            RunService.RenderStepped:Wait()
            RunService.RenderStepped:Wait()

            local cursorObj = nil
            local maxDelta = 0
            for obj, oldX in pairs(initialX) do
                if obj and obj.Parent then
                    local dX = math.abs(obj.AbsolutePosition.X - oldX)
                    if dX > 0.4 and dX > maxDelta then
                        maxDelta = dX
                        cursorObj = obj
                    end
                end
            end

            local targetZoneObj = nil
            local barTrackObj = nil
            local refY = cursorObj and (cursorObj.AbsolutePosition.Y + cursorObj.AbsoluteSize.Y / 2) or (stokeY - 45)

            for _, obj in pairs(modalContainer:GetDescendants()) do
                if obj:IsA("GuiObject") and isActuallyVisible(obj) and obj ~= cursorObj and (not cursorObj or not obj:IsDescendantOf(cursorObj)) then
                    local centerY = obj.AbsolutePosition.Y + (obj.AbsoluteSize.Y / 2)
                    if math.abs(centerY - refY) < 35 then
                        if obj.AbsoluteSize.X >= 180 and obj.AbsoluteSize.Y <= 50 then
                            if not barTrackObj or obj.AbsoluteSize.X > barTrackObj.AbsoluteSize.X then barTrackObj = obj end
                        elseif obj.AbsoluteSize.X >= 6 and obj.AbsoluteSize.X <= 90 and obj.AbsoluteSize.Y <= 45 then
                            local dX = initialX[obj] and math.abs(obj.AbsolutePosition.X - initialX[obj]) or 0
                            if dX < 0.2 and (not targetZoneObj or obj.AbsoluteSize.X < targetZoneObj.AbsoluteSize.X) then
                                targetZoneObj = obj
                            end
                        end
                    end
                end
            end

            CU_LOG.add("PILULA", "Stoke", string.format("cursor=%s faixa=%s barra=%s", tostring(cursorObj and cursorObj.Name), tostring(targetZoneObj and targetZoneObj.Name), tostring(barTrackObj and barTrackObj.Name)), 2)
            local startTime = tick()
            local prevX = cursorObj and (cursorObj.AbsolutePosition.X + cursorObj.AbsoluteSize.X / 2) or nil

            while State.autoPillActive and isActuallyVisible(stokeBtnObj) and (tick() - startTime < 4.0) do
                if cursorObj then
                    local curCenter = cursorObj.AbsolutePosition.X + (cursorObj.AbsoluteSize.X / 2)
                    local velX = prevX and (curCenter - prevX) or 0
                    prevX = curCenter
                    local predictedX = curCenter + (velX * 1.15)

                    local zMin, zMax
                    if targetZoneObj then
                        local zPos = targetZoneObj.AbsolutePosition.X
                        local zSize = targetZoneObj.AbsoluteSize.X
                        local pad = math.min(zSize * 0.2, 6)
                        zMin = zPos + pad
                        zMax = (zPos + zSize) - pad
                    elseif barTrackObj then
                        local bPos = barTrackObj.AbsolutePosition.X
                        local bSize = barTrackObj.AbsoluteSize.X
                        zMin = bPos + (bSize * 0.46)
                        zMax = bPos + (bSize * 0.54)
                    end

                    if zMin and zMax and ((predictedX >= zMin and predictedX <= zMax) or (curCenter >= zMin and curCenter <= zMax)) then
                        CU_LOG.count("Pilulas: Stoke apertado na faixa")
                        triggerGuiClick(stokeBtnObj, true, false)
                        pcall(function()
                            if CultivationEvents and CultivationEvents:FindFirstChild("CauldronStoke") then
                                CU_LOG.sent("CauldronStoke"); CultivationEvents.CauldronStoke:FireServer(true)
                            end
                        end)
                        break
                    end
                end
                RunService.RenderStepped:Wait()
            end

            State.isBrewingWaitClaim = true
        end

        while true do
            if State.autoPillActive and not isUserTypingOrInMenu() and not State.isTeleportingZone then
                openCauldronZeroLag()

                -- STATE 1: Jika tombol Claim pil terlihat di layar
                local visibleClaim = findVisibleTextElement("claim", true)
                if visibleClaim then
                    CU_LOG.count("Pilulas: botao Claim na tela")
                    State.isBrewingWaitClaim = false
                    pcall(function()
                        if CultivationEvents and CultivationEvents:FindFirstChild("CauldronClaim") then
                            CU_LOG.sent("CauldronClaim"); CultivationEvents.CauldronClaim:FireServer()
                        end
                    end)
                    triggerGuiClick(visibleClaim, false, false)
                    task.wait(0.45)

                -- STATE 2: Jika minigame Stoke sedang muncul
                else
                    local stokeObj = findVisibleTextElement("stoke", true)
                    if stokeObj then
                        CU_LOG.count("Pilulas: minijogo Stoke")
                        handleStokeMinigame(stokeObj)
                        task.wait(0.4)

                    -- STATE 3: Jika jendela "Choose a herb" sedang terbuka
                    elseif findVisibleTextElement("choose a herb", false) then
                        local recipe = Constants.PILL_RECIPES[State.selectedPill]
                        local slotIdx = math.clamp(State.activeRecipeSlot or 1, 1, 3)
                        local requiredHerb = recipe and recipe[slotIdx] or "Ginseng"

                        local chosen = selectHerbFromChooseModal(requiredHerb)
                        CU_LOG.count(chosen and "Pilulas: erva escolhida na lista" or "Pilulas: erva da receita nao achada na lista (Back)")
                        CU_LOG.add("PILULA", "escolher erva", string.format("coluna %d: %s -> %s", slotIdx, tostring(requiredHerb), chosen and "escolhida" or "nao achada"), 3)
                        if chosen then
                            task.wait(0.55)
                        else
                            local backBtn = findVisibleTextElement("back", true)
                            if backBtn then
                                triggerGuiClick(backBtn, false, false)
                            end
                            task.wait(0.55)
                        end

                    -- STATE 4: Menu utama ALCHEMY CAULDRON
                    else
                        local brewBtn = findVisibleTextElement("brew", true)
                        if brewBtn then
                            local recipe = Constants.PILL_RECIPES[State.selectedPill]
                            local cols = getThreeColumnSlots(brewBtn)

                            if recipe and cols then
                                local actionTaken = false

                                for i = 1, 3 do
                                    local c = cols[i]
                                    local expectedHerb = recipe[i]

                                    -- Jika kolom ke-i berisi herb yang SALAH, klik "Click to remove" pada kolom tersebut!
                                    if c.FilledHerb and c.FilledHerb:lower() ~= expectedHerb:lower() and c.RemoveBtn then
                                        State.activeRecipeSlot = i
                                        CU_LOG.count("Pilulas: tirar erva errada")
                                        CU_LOG.add("PILULA", "coluna " .. i, "tem " .. tostring(c.FilledHerb) .. ", a receita pede " .. tostring(expectedHerb), 3)
                                        triggerGuiClick(c.RemoveBtn, false, false)
                                        actionTaken = true
                                        task.wait(0.5)
                                        break
                                    -- Jika kolom ke-i masih kosong ("Add herb"), klik "Add herb" pada kolom tersebut!
                                    elseif c.IsEmpty and c.AddBtn then
                                        State.activeRecipeSlot = i
                                        CU_LOG.count("Pilulas: adicionar erva")
                                        triggerGuiClick(c.AddBtn, false, false)
                                        actionTaken = true
                                        task.wait(0.5)
                                        break
                                    end
                                end

                                -- Jika ketiga kolom sudah berisi bahan yang 100% sesuai resep, klik Brew!
                                if not actionTaken and cols[1].FilledHerb and cols[2].FilledHerb and cols[3].FilledHerb then
                                    State.isBrewingWaitClaim = true
                                    CU_LOG.count("Pilulas: Brew")
                                    CU_LOG.add("PILULA", "Brew", tostring(State.selectedPill) .. ": " .. table.concat(recipe, ", "), 0)
                                    triggerGuiClick(brewBtn, false, false)
                                    task.wait(0.6)
                                end
                            end
                        elseif State.isBrewingWaitClaim then
                            -- STATE 5: Menunggu Brewing selesai -> kirim sinyal CauldronClaim di background tanpa lag
                            pcall(function()
                                if CultivationEvents and CultivationEvents:FindFirstChild("CauldronClaim") then
                                    CU_LOG.sent("CauldronClaim"); CultivationEvents.CauldronClaim:FireServer()
                                end
                            end)
                            task.wait(0.35)
                        end
                    end
                end
            end
            task.wait(0.28)
        end
    end)
end

-------------------------------------------------------------------------
-- 3. AUTO BREAKTHROUGH (ISOLATED SHRINKING RING TRACKER + REMOTE SYNC)
-------------------------------------------------------------------------
CU_LOG.spawnLoop("Breakthrough", function()
    local function isGoldColor(col)
        return (col.R > 0.75 and col.G > 0.55 and col.B < 0.42)
    end

    local function countSingleLetterLabels(container)
        local count = 0
        for _, d in pairs(container:GetDescendants()) do
            if (d:IsA("TextLabel") or d:IsA("TextButton")) and isActuallyVisible(d) and d.Text:match("^%s*[A-Z]%s*$") then
                count = count + 1
            end
        end
        return count
    end

    local function getIsolatedCircleContainer(letterObj)
        local curr = letterObj.Parent
        if not curr or not curr:IsA("GuiObject") then return letterObj end
        if curr.Parent and curr.Parent:IsA("GuiObject") and curr.Parent.AbsoluteSize.X <= 260 then
            if countSingleLetterLabels(curr.Parent) <= 1 then
                curr = curr.Parent
            end
        end
        return curr
    end

    local function getCultivationHudState()
        local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
        if not playerGui then return nil end

        local st = {
            realmName = nil, currentLayer = nil, maxLayers = 10,
            qiPercent = nil, trialReadyBanner = false,
            trialMinigameActive = false, breakthroughBtn = nil
        }

        for _, obj in pairs(playerGui:GetDescendants()) do
            if obj ~= UI.ScreenGui and not obj:IsDescendantOf(UI.ScreenGui) and (obj:IsA("TextLabel") or obj:IsA("TextButton")) and isActuallyVisible(obj) then
                local rawText = obj.Text or ""
                local cleanLower = trimText(rawText)

                if cleanLower:find("breakthrough trial", 1, true) or cleanLower:find("ring turns gold", 1, true) then
                    st.trialMinigameActive = true
                end
                if cleanLower:find("realm trial ready", 1, true) then
                    st.trialReadyBanner = true
                end
                if cleanLower == "breakthrough" then
                    st.breakthroughBtn = obj
                end

                local pctMatch = rawText:match("^%s*(%d+)%%%s*$")
                if pctMatch then st.qiPercent = tonumber(pctMatch) end

                if rawText:find("Qi") and (rawText:find("·") or rawText:find("-")) then
                    local afterPrefix = rawText:match("Qi%s*[·%-]%s*(.+)$")
                    if afterPrefix then
                        local realmPart, romanPart = afterPrefix:match("^(.+)%s+([IVX]+)%s*$")
                        if realmPart and romanPart and Constants.ROMAN_TO_NUMBER[romanPart] then
                            st.realmName = realmPart
                            st.currentLayer = Constants.ROMAN_TO_NUMBER[romanPart]
                            st.maxLayers = Constants.REALM_MAX_LAYERS[trimText(realmPart)] or 10
                        end
                    end
                end
            end
        end
        return st
    end

    while true do
        if State.autoBreakthroughActive then
            local hud = getCultivationHudState()
            CU_LOG.hud(hud)
            if hud then
                if hud.trialMinigameActive then
                    UI.RealmStatusLabel.Text = "Status: Trial Aktif (Menunggu Cincin Mengecil & Emas)"
                elseif hud.realmName and hud.currentLayer then
                    UI.RealmStatusLabel.Text = string.format(
                        "Status: %s (Layer %d/%d) | Qi: %s%%",
                        hud.realmName, hud.currentLayer, hud.maxLayers, tostring(hud.qiPercent or 0)
                    )
                end

                if hud.trialMinigameActive then
                    local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
                    local camViewport = Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)

                    if playerGui then
                        for _, obj in pairs(playerGui:GetDescendants()) do
                            if obj ~= UI.ScreenGui and not obj:IsDescendantOf(UI.ScreenGui) and (obj:IsA("TextLabel") or obj:IsA("TextButton")) and isActuallyVisible(obj) then
                                local posY, posX = obj.AbsolutePosition.Y, obj.AbsolutePosition.X
                                local inTrialArea = (posY > camViewport.Y * 0.12 and posY < camViewport.Y * 0.74)
                                    and (posX > camViewport.X * 0.14 and posX < camViewport.X * 0.86)

                                if inTrialArea then
                                    local cleanChar = obj.Text:match("^%s*([A-Z])%s*$")
                                    if cleanChar and obj.AbsoluteSize.X >= 16 and obj.AbsoluteSize.X <= 130 then
                                        local nodeContainer = getIsolatedCircleContainer(obj)

                                        if not State.trialNodesData[nodeContainer] or State.trialNodesData[nodeContainer].char ~= cleanChar then
                                            State.trialNodesData[nodeContainer] = {
                                                char = cleanChar, spawnTime = tick(),
                                                maxOuterSize = 0, triggered = false
                                            }
                                        end

                                        local nData = State.trialNodesData[nodeContainer]
                                        local age = tick() - nData.spawnTime
                                        local currentOuterSize = 0
                                        local innerCircleSize = obj.Parent and obj.Parent.AbsoluteSize.X or obj.AbsoluteSize.X

                                        for _, desc in pairs(nodeContainer:GetDescendants()) do
                                            if desc:IsA("GuiObject") and desc ~= obj and isActuallyVisible(desc) then
                                                local sz = desc.AbsoluteSize.X
                                                if sz >= 30 and sz < innerCircleSize then innerCircleSize = sz end
                                                if sz > currentOuterSize then currentOuterSize = sz end
                                            end
                                        end

                                        if currentOuterSize > nData.maxOuterSize then
                                            nData.maxOuterSize = currentOuterSize
                                        end

                                        if not nData.triggered and age >= 0.22 then
                                            local hasShrunk = (nData.maxOuterSize > 0 and currentOuterSize < (nData.maxOuterSize * 0.82))
                                            local isRingGoldNow = false

                                            for _, desc in pairs(nodeContainer:GetDescendants()) do
                                                if not desc:IsDescendantOf(obj) and desc ~= obj then
                                                    if desc:IsA("UIStroke") and isGoldColor(desc.Color) then
                                                        isRingGoldNow = true
                                                        break
                                                    elseif (desc:IsA("ImageLabel") or desc:IsA("ImageButton")) and isActuallyVisible(desc) and isGoldColor(desc.ImageColor3) then
                                                        isRingGoldNow = true
                                                        break
                                                    elseif desc:IsA("Frame") and isActuallyVisible(desc) and desc.BackgroundTransparency < 0.85 and isGoldColor(desc.BackgroundColor3) then
                                                        isRingGoldNow = true
                                                        break
                                                    end
                                                end
                                            end

                                            local inSweetSpotSize = (nData.maxOuterSize > innerCircleSize * 1.15)
                                                and (currentOuterSize <= innerCircleSize * 1.24)
                                                and (currentOuterSize >= innerCircleSize * 0.88)

                                            if (isRingGoldNow and (hasShrunk or age >= 0.35)) or inSweetSpotSize then
                                                nData.triggered = true
                                                CU_LOG.count("Breakthrough: letra do minijogo acionada")
                                                CU_LOG.add("TRIAL", cleanChar, string.format("idade %.2fs | anel %.0f (maior %.0f, interno %.0f) | encolheu=%s dourado=%s ponto_certo=%s", age, currentOuterSize, nData.maxOuterSize, innerCircleSize, tostring(hasShrunk), tostring(isRingGoldNow), tostring(inSweetSpotSize)), 0)
                                                triggerKeyPress(cleanChar)
                                                triggerGuiClick(obj, true, true)
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                    RunService.RenderStepped:Wait()
                else
                    table.clear(State.trialNodesData)
                    local isReady = (hud.qiPercent and hud.qiPercent >= 100) or hud.trialReadyBanner
                    if isReady and not isUserTypingOrInMenu() then
                        CU_LOG.count("Breakthrough: pronto (Qi 100% ou banner)")
                        if hud.breakthroughBtn then
                            CU_LOG.count("Breakthrough: botao Breakthrough clicado")
                            triggerGuiClick(hud.breakthroughBtn, false, false)
                        end
                        pcall(function()
                            if CultivationEvents then
                                if State.autoBodyActive and CultivationEvents:FindFirstChild("BodyBreakthrough") then
                                    CU_LOG.sent("BodyBreakthrough"); CultivationEvents.BodyBreakthrough:FireServer()
                                elseif CultivationEvents:FindFirstChild("Breakthrough") then
                                    CU_LOG.sent("Breakthrough"); CultivationEvents.Breakthrough:FireServer()
                                end
                            end
                        end)
                        task.wait(0.7)
                    else
                        task.wait(0.25)
                    end
                end
            else
                task.wait(0.3)
            end
        else
            task.wait(0.4)
        end
    end
end)

-------------------------------------------------------------------------
-- 4. AUTO CLICK BONUS QI ORB (DIRECT REMOTE + SILENT UI CLICK)
-------------------------------------------------------------------------
do
    if CultivationEvents then
        local spawnOrbRem = CultivationEvents:FindFirstChild("SpawnCultivationOrb")
        local clickOrbRem = CultivationEvents:FindFirstChild("CultivationOrbClicked")
        if spawnOrbRem and clickOrbRem and spawnOrbRem:IsA("RemoteEvent") and clickOrbRem:IsA("RemoteEvent") then
            spawnOrbRem.OnClientEvent:Connect(function(...)
                if State.autoQiOrbActive then
                    local args = {...}
                    task.wait(0.08)
                    pcall(function()
                        CU_LOG.sent("CultivationOrbClicked (args do SpawnCultivationOrb)")
                        clickOrbRem:FireServer(table.unpack(args))
                        clickOrbRem:FireServer()
                    end)
                end
            end)
        end
    end

    CU_LOG.spawnLoop("Qi Orb", function()
        local function isInsideExcludedWindow(guiObj)
            local curr = guiObj
            while curr and curr ~= LocalPlayer.PlayerGui do
                local n = curr.Name:lower()
                if n:find("realm") or n:find("cauldron") or n:find("alchemy") or n:find("quest")
                    or n:find("inventory") or n:find("shop") or n:find("skill") or n:find("setting")
                    or n:find("sect") or n:find("party") or n:find("cultivator") or n:find("pack")
                    or n:find("chat") or n:find("leaderboard") or n:find("hotbar") then
                    return true
                end
                curr = curr.Parent
            end
            return false
        end

        while true do
            if State.autoQiOrbActive and not isUserTypingOrInMenu() then
                local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
                local camViewport = Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)

                if playerGui then
                    for _, obj in pairs(playerGui:GetDescendants()) do
                        if obj ~= UI.ScreenGui and not obj:IsDescendantOf(UI.ScreenGui) and obj:IsA("GuiObject") and isActuallyVisible(obj) then
                            if not isInsideExcludedWindow(obj) then
                                local nameLow = obj.Name:lower()
                                local parentNameLow = obj.Parent and obj.Parent.Name:lower() or ""
                                local sizeX, sizeY = obj.AbsoluteSize.X, obj.AbsoluteSize.Y
                                local posX, posY = obj.AbsolutePosition.X, obj.AbsolutePosition.Y

                                local inOrbZone = (posX > camViewport.X * 0.14 and posX < camViewport.X * 0.82)
                                    and (posY > camViewport.Y * 0.10 and posY < camViewport.Y * 0.72)
                                local isSquareOrbSize = (sizeX >= 36 and sizeX <= 160) and (math.abs(sizeX - sizeY) <= 18)

                                if inOrbZone and isSquareOrbSize then
                                    local isQiOrb = false
                                    if nameLow:find("orb") or nameLow:find("bonus") or nameLow:find("burst") or nameLow:find("yinyang") or parentNameLow:find("orb") then
                                        isQiOrb = true
                                    elseif (obj:IsA("ImageButton") or obj:IsA("TextButton")) then
                                        local txt = obj:IsA("TextButton") and trimText(obj.Text) or ""
                                        if txt == "" then isQiOrb = true end
                                    end

                                    if isQiOrb then
                                        pcall(function()
                                            if CultivationEvents and CultivationEvents:FindFirstChild("CultivationOrbClicked") then
                                                CU_LOG.sent("CultivationOrbClicked"); CultivationEvents.CultivationOrbClicked:FireServer()
                                            end
                                        end)
                                        CU_LOG.count("Qi Orb: orb clicado na tela")
                                        CU_LOG.add("ORB", "tela", obj:GetFullName(), 5)
                                        triggerGuiClick(obj, false, false)
                                        task.wait(0.16)
                                    end
                                end
                            end
                        end
                    end
                end
            end
            task.wait(0.12)
        end
    end)
end

-------------------------------------------------------------------------
-- 5. AUTO KILL PLAYER (TARGET LOCK + AUTO SWORD + AUTO SKILLS)
-------------------------------------------------------------------------
do
    RunService.RenderStepped:Connect(function()
        if State.autoKillActive and State.selectedTargetPlayerName ~= "None" and not State.isTeleportingZone then
            local targetPlr = Players:FindFirstChild(State.selectedTargetPlayerName)
            if targetPlr and targetPlr.Character then
                local targetRoot = targetPlr.Character:FindFirstChild("HumanoidRootPart")
                local targetHum = targetPlr.Character:FindFirstChildWhichIsA("Humanoid")
                local myChar = LocalPlayer.Character
                local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")

                if targetRoot and myRoot and (not targetHum or targetHum.Health > 0) then
                    local lockPos = (targetRoot.CFrame * CFrame.new(0, 0, 3.5)).Position
                    myRoot.CFrame = CFrame.new(lockPos, targetRoot.Position)
                    myRoot.Velocity = Vector3.new(0, 0, 0)
                end
            end
        end
    end)

    CU_LOG.spawnLoop("Auto Kill", function()
        while true do
            if State.autoKillActive and State.selectedTargetPlayerName ~= "None" and not isUserTypingOrInMenu() and not State.isTeleportingZone then
                local targetPlr = Players:FindFirstChild(State.selectedTargetPlayerName)
                if targetPlr and targetPlr.Character then
                    local targetHum = targetPlr.Character:FindFirstChildWhichIsA("Humanoid")
                    if not targetHum or targetHum.Health > 0 then
                        local char = LocalPlayer.Character
                        if char then
                            local hum = char:FindFirstChildWhichIsA("Humanoid")
                            local backpack = LocalPlayer:FindFirstChild("Backpack")
                            local equippedTool = char:FindFirstChildWhichIsA("Tool")
                            if not equippedTool and backpack and hum then
                                for _, item in pairs(backpack:GetChildren()) do
                                    if item:IsA("Tool") then
                                        CU_LOG.count("Kill: equipou " .. item.Name)
                                        hum:EquipTool(item)
                                        equippedTool = item
                                        break
                                    end
                                end
                            end
                            if equippedTool then CU_LOG.count("Kill: tool:Activate"); pcall(function() equippedTool:Activate() end) end
                            local okMouse, errMouse = pcall(function()
                                VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 1)
                                VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 1)
                            end)
                            CU_LOG.count(okMouse and "Kill: clique mouse VIM em (0,0)" or "Kill: clique mouse VIM ERRO")
                            if not okMouse then CU_LOG.error("Kill mouse VIM", errMouse) end
                            CU2.killHit(targetPlr.Character)
                        end

                        if State.autoSkillKillActive and (tick() - State.lastSkillCycleTime >= 0.35) then
                            State.lastSkillCycleTime = tick()
                            local keyToPress = Constants.COMBAT_SKILL_KEYS[State.skillIndex]
                            State.skillIndex = (State.skillIndex % #Constants.COMBAT_SKILL_KEYS) + 1
                            local okSkill, errSkill = pcall(function()
                                VirtualInputManager:SendKeyEvent(true, keyToPress, false, game)
                                task.wait(0.02)
                                VirtualInputManager:SendKeyEvent(false, keyToPress, false, game)
                            end)
                            CU_LOG.key("skill " .. keyToPress.Name, okSkill, errSkill)
                            CU2.killSkill(keyToPress.Name, targetPlr.Character)
                        end
                    end
                end
                task.wait(0.12)
            else
                task.wait(0.35)
            end
        end
    end)
end


-------------------------------------------------------------------------
-- CU1: AMBIENTE, ESPIAO DE REMOTES, CUSTO DA VARREDURA DA TELA, STATUS E TXT AUTOMATICO
-------------------------------------------------------------------------
do
    local caps, plat = CU_LOG.env()
    CU_LOG.add("INFO", "Ambiente", caps)
    CU_LOG.add("INFO", "Ambiente", plat)
    CU_LOG.try("Espiao de remotes", CU_LOG.watchRemotes, CultivationEvents)
    -- Mede quanto custa UMA varredura da tela igual as que o script faz varias vezes por segundo.
    local function measureScan()
        local pg = LocalPlayer:FindFirstChild("PlayerGui")
        if not pg then return end
        local t0 = os.clock()
        local all = pg:GetDescendants()
        local texts = 0
        for _, obj in ipairs(all) do
            if (obj:IsA("TextLabel") or obj:IsA("TextButton")) and isActuallyVisible(obj) then texts += 1 end
        end
        local ms = (os.clock() - t0) * 1000
        local s = CU_LOG.scans
        s[#s + 1] = {objects = #all, texts = texts, ms = ms}
        if #s > 120 then table.remove(s, 1) end
        CU_LOG.add("DESEMPENHO", "Varredura", string.format("%d objetos, %d textos visiveis, %.0f ms", #all, texts, ms), 60)
    end
    CU_LOG.spawnLoop("Log (medicao e TXT automatico)", function()
        task.wait(5)
        while true do
            CU_LOG.try("Medicao da varredura", measureScan)
            CU_LOG.add("STATUS", "Funcoes", CU_LOG.activeList(), 60)
            if CU_LOG.autoSave and writefile and os.clock() - CU_LOG.lastAutoSave >= CU_LOG.autoSaveEvery then
                CU_LOG.lastAutoSave = os.clock()
                CU_LOG.save("CultivationHub_log_auto.txt")
            end
            task.wait(30)
        end
    end)
end


-------------------------------------------------------------------------
-- CU2: ABAS, OUVINTES E LOOPS (FUNCOES DO TOP76 + MELHORIAS)
-- Cada loop so roda com a sua chave ligada, para sozinho ao desligar ou ao fechar a janela (X), e conta/registra
-- no TXT o que mandou e o que o servidor respondeu.
-------------------------------------------------------------------------

function CU2.trialVisible()
    local pg=LocalPlayer:FindFirstChild("PlayerGui")
    if not pg then return false end
    for _,obj in ipairs(pg:GetDescendants()) do
        if (obj:IsA("TextLabel") or obj:IsA("TextButton")) and isActuallyVisible(obj) then
            local t=trimText(obj.Text)
            if t:find("breakthrough trial",1,true) or t:find("ring turns gold",1,true) then return true end
        end
    end
    return false
end

-- ===== COMBATE: FARM DE MONSTROS (Top76) =====
function CU2.mobPauseReason()
    if CU2.event and CU2.on("sectClash") then return "Sect Clash" end
    if State.autoKillActive then return "Auto Kill ligado" end
    if State.isTeleportingZone then return "teleporte de zona" end
    return nil
end
function CU2.noMobsFound()
    CU2.setLabel("target","Nenhum monstro marcado vivo nos acampamentos")
    CU_LOG.count("Combate: nenhum monstro marcado vivo")
    local now=os.clock()
    if not CU2.mobFoldersAt or now-CU2.mobFoldersAt>=60 then
        CU2.mobFoldersAt=now
        local ok,res=pcall(CU2.findMobFolders)
        CU2.mobFolders=ok and res or ("erro: "..tostring(res))
        CU_LOG.add("COMBATE","nenhum monstro",string.format("nenhum monstro marcado vivo. Containers: %s | pastas do mapa com Humanoid: %s",
            tostring(CU2.containerText),CU2.mobFolders),0)
    end
end
function CU2.swing(char,hum)
    local backpack=LocalPlayer:FindFirstChildOfClass("Backpack")
    local tool=char:FindFirstChildOfClass("Tool") or (backpack and backpack:FindFirstChildOfClass("Tool"))
    if tool and tool.Parent~=char then
        CU_LOG.count("Combate: equipou "..tool.Name)
        hum:EquipTool(tool)
    end
    if tool then
        local okT,errT=pcall(function() tool:Activate() end)
        if not okT then CU_LOG.error("Combate: tool:Activate",errT) end
    end
    local okV,errV=pcall(function()
        local vu=game:GetService("VirtualUser")
        vu:CaptureController()
        vu:ClickButton1(Vector2.new(0,0))
    end)
    if not okV then
        CU_LOG.count("Combate: clique VirtualUser ERRO")
        CU_LOG.error("Combate: clique VirtualUser",errV)
    end
    return tool
end
function CU2.groupAround(center)
    local group={}
    for _,m in ipairs(CU2.scanMobs(true)) do
        if (m.hrp.Position-center).Magnitude<=38 then
            group[#group+1]=m
            if CU2.s.aoe then CU2.expand(m.hrp) end
        end
    end
    return group
end
function CU2.endFight(f,result,anchor)
    local now=os.clock()
    local endHp=(anchor.hum and anchor.hum.Parent) and anchor.hum.Health or 0
    local line=string.format("%s %s: HP %d->%d de %d em %.1fs | %d golpes (+%d em grupo) | posicao %s | arma %s | distancia inicial %.0f | menor vida do jogador %d%% | fim: %s",
        f.startStamp,f.name,math.floor(f.startHp),math.floor(endHp),math.floor(f.maxHp),now-f.startAt,f.hits,f.aoe,CU2.offsetText(),
        f.tool and f.tool.Name or "nenhuma",f.dist or 0,math.floor(f.playerMin*100),result)
    CU2.fights[#CU2.fights+1]=line
    if #CU2.fights>25 then table.remove(CU2.fights,1) end
    CU_LOG.add("LUTA",f.name,line,0)
    CU_LOG.count("Combate: lutas")
    if result=="morto" or result:find("sumiu",1,true) then CU_LOG.count("Combate: monstro morto") end
    if result=="personagem morreu" then CU_LOG.count("Combate: personagem morreu na luta") end
    if result=="sem dano" then
        CU_LOG.count("Combate: sem dano (pulado 30s)")
        local _,hrp=CU2.char()
        CU_LOG.add("COMBATE","sem dano",string.format("%s nao perdeu HP em %ds com %d golpes: distancia agora %.0f studs, posicao %s, arma %s. Se repetir em todos os monstros, o servidor recusa o CombatHit ou a posicao esta longe: troque a posicao.",
            f.name,CU2.NO_DAMAGE_SECS,f.hits,(hrp and anchor.hrp.Parent) and (hrp.Position-anchor.hrp.Position).Magnitude or -1,CU2.offsetText(),
            f.tool and f.tool.Name or "nenhuma"),0)
    end
    if f.firstDropAt and not CU2.stats.hitAccepted then
        CU2.stats.hitAccepted=string.format("%s em %s, %d golpes ate o primeiro dano",os.date("%H:%M:%S"),f.name,f.hitsAtFirstDrop or 0)
        CU_LOG.add("COMBATE","CombatHit","ACEITO: o HP do monstro caiu ("..CU2.stats.hitAccepted..")",0)
    end
    CU2.mob=nil
    CU2.targetPart=nil
end
function CU2.fight(anchor)
    local hp0=anchor.hum.Health
    local f={name=anchor.model.Name,startHp=hp0,prevHp=hp0,minHp=hp0,maxHp=anchor.hum.MaxHealth,hits=0,aoe=0,playerMin=1,
        startAt=os.clock(),startStamp=os.date("%H:%M:%S")}
    CU2.mob=f
    CU2.cancelHerbTween()
    local _,hrp0=CU2.char()
    if hrp0 then
        f.dist=(anchor.hrp.Position-hrp0.Position).Magnitude
        CU2.safeTeleport(hrp0,anchor.hrp.CFrame*CFrame.new(CU2.offsetVec()),anchor.hrp,function() return not CU2.on("mobFarm") end)
    end
    f.lastDropAt=os.clock()
    local cluster,nextCluster,cursor,nextTool,nextLabel={},0,1,0,0
    local result="?"
    while true do
        if not CU2.on("mobFarm") then result="farm desligado" break end
        local pause=CU2.mobPauseReason()
        if pause then result="pausado: "..pause break end
        local char,hrp,hum=CU2.char()
        if not hrp or hum.Health<=0 then result="personagem morreu" break end
        if not anchor.model.Parent then result="monstro sumiu (morreu ou despawn)" break end
        if anchor.hum.Health<=0 then result="morto" break end
        if CU2.s.selectedMobs[anchor.model.Name]~=true then result="desmarcado" break end
        local now=os.clock()
        f.playerMin=math.min(f.playerMin,hum.Health/math.max(hum.MaxHealth,1))
        if CU2.fightCheck(f,anchor.hum.Health,now) then
            result="sem dano"
            CU2.blacklist[anchor.model]=now+30
            break
        end
        if now>=nextCluster then
            cluster=CU2.groupAround(anchor.hrp.Position)
            nextCluster=now+0.4
        end
        local target=anchor
        if CU2.s.aoe and #cluster>1 then
            if cursor>#cluster then cursor=1 end
            target=cluster[cursor]
            cursor+=1
            if not CU2.validMob(target) then target=anchor end
        elseif not CU2.s.aoe then
            CU2.resetHitboxes()
        end
        CU2.targetPart=target.hrp
        if now>=nextLabel then
            nextLabel=now+0.15
            CU2.setLabel("target",string.format("Alvo: %s %d/%d%s",target.model.Name,math.floor(target.hum.Health),math.floor(target.hum.MaxHealth),
                CU2.s.aoe and (" | grupo "..#cluster) or ""))
        end
        CU2.safeTeleport(hrp,target.hrp.CFrame*CFrame.new(CU2.offsetVec()),target.hrp)
        if CU2.validMob(target) then
            if CU2.fire("CombatHit",target.model,1) then f.hits+=1 end
            if CU2.s.turbo and CU2.fire("CombatHit",target.model,1) then f.hits+=1 end
            if CU2.s.aoe then
                for _,o in ipairs(cluster) do
                    if o.model~=target.model and CU2.validMob(o) and CU2.fire("CombatHit",o.model,1) then f.aoe+=1 end
                end
            end
        end
        now=os.clock()
        if now>=nextTool then
            nextTool=now+(CU2.s.turbo and 0.10 or 0.20)
            f.tool=CU2.swing(char,hum)
        end
        task.wait(CU2.s.turbo and 0.06 or 0.12)
    end
    CU2.endFight(f,result,anchor)
end
function CU2.mobFarmLoop()
    CU_LOG.add("COMBATE","farm",string.format("ligado: posicao %s, turbo=%s, grupo=%s",CU2.offsetText(),tostring(CU2.s.turbo),tostring(CU2.s.aoe)),0)
    while CU2.on("mobFarm") do
        local pause=CU2.mobPauseReason()
        if pause then
            CU2.mobBusy=false
            CU2.resetHitboxes()
            CU_LOG.count("Combate: pausado ("..pause..")")
            CU2.setLabel("target","Farm pausado: "..pause)
            task.wait(0.5)
        else
            local _,hrp,hum=CU2.char()
            if not hrp or hum.Health<=0 then
                CU2.mobBusy=false
                CU2.setLabel("target","Esperando o personagem renascer...")
                task.wait(0.5)
            else
                local mobs=CU2.scanMobs(true)
                if #mobs==0 then
                    CU2.mobBusy=false
                    CU2.resetHitboxes()
                    CU2.noMobsFound()
                    CU2.parkPlatformIfIdle()
                    task.wait(0.8)
                else
                    table.sort(mobs,function(a,b)
                        return (a.hrp.Position-hrp.Position).Magnitude<(b.hrp.Position-hrp.Position).Magnitude
                    end)
                    CU2.mobBusy=true
                    CU2.fight(mobs[1])
                end
            end
        end
    end
    CU2.mobBusy=false
    CU2.mob=nil
    CU2.resetHitboxes()
    CU2.parkPlatformIfIdle()
    CU2.setLabel("target","Alvo: farm desligado")
    CU_LOG.add("COMBATE","farm","desligado",0)
end

-- ===== SKILLS PELO SERVIDOR (Top76: UseSkill(tecla, direcao, posicao)); mira no alvo do farm/Sect Clash =====
function CU2.aim(hrp)
    local target=CU2.targetPart
    if target and target.Parent then
        local d=target.Position-hrp.Position
        if d.Magnitude>0.1 then return d.Unit,target.Position end
    end
    local look=hrp.CFrame.LookVector
    return look,hrp.Position+look*15
end
function CU2.skillsLoop()
    while CU2.on("skills") do
        local _,hrp,hum=CU2.char()
        if hrp and hum.Health>0 then
            for _,key in ipairs(CU2.SKILL_KEYS) do
                if not CU2.on("skills") then break end
                local look,pos=CU2.aim(hrp)
                CU2.fire("UseSkill",key,look,pos)
                CU_LOG.count("Skills servidor: "..key)
                task.wait(0.15)
            end
        end
        task.wait(0.5)
    end
end

-- ===== SECT CLASH (Top76: MapEvent start/side/end) =====
function CU2.findEventEnemy(ev,enemyName)
    local cache=CU2.clashCache
    if cache and cache.name==enemyName and cache.model.Parent and cache.hum.Health>0 then return cache end
    local now=os.clock()
    if CU2.clashScanAt and now<CU2.clashScanAt then return nil end
    CU2.clashScanAt=now+1
    CU2.clashCache=nil
    if not enemyName then return nil end
    local best,bestDist=nil,1e9
    for _,obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("Model") and obj.Name==enemyName and obj~=LocalPlayer.Character then
            local hum=obj:FindFirstChildOfClass("Humanoid")
            local hrp=obj:FindFirstChild("HumanoidRootPart") or obj.PrimaryPart
            if hum and hum.Health>0 and hrp then
                local d=(hrp.Position-ev.centre).Magnitude
                if d<=150 and d<bestDist then
                    bestDist=d
                    best={model=obj,hrp=hrp,hum=hum,name=enemyName}
                end
            end
        end
    end
    CU2.clashCache=best
    return best
end
function CU2.clashLoop()
    while CU2.on("sectClash") do
        local ev=CU2.event
        if ev and Workspace:GetServerTimeNow()>ev.endsAt+10 then
            CU2.events[#CU2.events+1]=os.date("%H:%M:%S").." acabou pelo horario (o servidor nao mandou 'end')"
            CU2.event=nil
            ev=nil
        end
        if not ev then
            CU2.targetPart=nil
            CU2.setLabel("clash","Sect Clash: esperando o evento comecar (MapEvent)")
            task.wait(1)
        else
            local _,hrp,hum=CU2.char()
            if hrp and hum.Health>0 then
                local distC=(hrp.Position-ev.centre).Magnitude
                if not ev.side or distC>145 then
                    CU2.setLabel("clash","Sect Clash: indo para "..ev.name)
                    CU_LOG.add("SECT","entrar",string.format("indo ao centro (%.0f studs), lado=%s",distC,tostring(ev.side)),10)
                    CU2.safeTeleport(hrp,CFrame.new(ev.centre+Vector3.new(0,3,0)),nil,function() return not CU2.on("sectClash") end)
                    task.wait(0.3)
                else
                    local enemyName,enemySide=CU2.enemyFighter(ev)
                    local enemy=CU2.findEventEnemy(ev,enemyName)
                    CU2.setLabel("clash",string.format("Sect Clash: lado %s | inimigo %s",tostring(ev.side),
                        enemy and string.format("%s %d/%d",enemy.model.Name,math.floor(enemy.hum.Health),math.floor(enemy.hum.MaxHealth)) or "nao achado"))
                    if enemy then
                        CU2.targetPart=enemy.hrp
                        CU2.safeTeleport(hrp,enemy.hrp.CFrame*CFrame.new(CU2.offsetVec()),enemy.hrp)
                        if CU2.fire("CombatHit",enemy.model,1) then
                            ev.hits+=1
                            CU2.stats.clashHits+=1
                        end
                        if CU2.s.turbo and CU2.fire("CombatHit",enemy.model,1) then
                            ev.hits+=1
                            CU2.stats.clashHits+=1
                        end
                        CU_LOG.add("SECT","luta",string.format("%s HP %d/%d, %d golpes no evento",enemy.model.Name,math.floor(enemy.hum.Health),
                            math.floor(enemy.hum.MaxHealth),ev.hits),10,"sect-luta")
                    else
                        CU2.targetPart=nil
                        CU_LOG.add("SECT","inimigo",string.format("nenhum '%s' (lado %s) vivo a 150 studs do centro; times: %s",tostring(enemyName),
                            tostring(enemySide),CU2.describe(ev.teams)),15,"sect-sem-inimigo")
                        CU2.safeTeleport(hrp,CFrame.new(ev.centre+Vector3.new(0,5,0)))
                    end
                end
            end
            task.wait(0.12)
        end
    end
    CU2.targetPart=nil
    CU2.setLabel("clash","Sect Clash: desligado")
end

-- ===== SOUL PROJECTION + ESPIRITOS (Top76) =====
function CU2.bodyPosition()
    local bodies=Workspace:FindFirstChild("SoulBodies")
    local body=bodies and (bodies:FindFirstChild(LocalPlayer.Name) or bodies:FindFirstChild(tostring(LocalPlayer.UserId)))
    if not body then return nil end
    if body:IsA("Model") then
        local pp=body.PrimaryPart or body:FindFirstChildWhichIsA("BasePart")
        return pp and pp.Position
    end
    if body:IsA("BasePart") then return body.Position end
    return nil
end
function CU2.soulLoop()
    local caught=setmetatable({},{__mode="k"})
    local sessionStart,tripCatches=0,0
    while CU2.on("soul") do
        local char,hrp,hum=CU2.char()
        local other=(CU2.mobBusy and "farm de monstros") or (CU2.on("herb2") and "ervas mapa todo")
            or ((CU2.event and CU2.on("sectClash")) and "Sect Clash") or nil
        if not hrp or hum.Health<=0 then
            task.wait(0.5)
        elseif LocalPlayer:GetAttribute("SoulProjecting")~=true then
            if sessionStart>0 then
                CU_LOG.add("SOUL","fim",string.format("voltou ao corpo depois de %.0fs; %d catch nesta viagem",os.clock()-sessionStart,tripCatches),0)
            end
            caught=setmetatable({},{__mode="k"})
            sessionStart,tripCatches=0,0
            if other then
                CU2.setLabel("soul","Soul: esperando ("..other.." move o personagem)")
            elseif LocalPlayer:GetAttribute("SoulProjectionLearned")~=true then
                CU2.setLabel("soul","Soul: o personagem ainda nao aprendeu Soul Projection")
                CU_LOG.add("SOUL","espera","atributo SoulProjectionLearned nao e true (ainda nao aprendeu)",60)
            else
                local med=char:FindFirstChild("IsMeditating")
                local push=char:FindFirstChild("IsPushingUp")
                local cultivating=(med and med:IsA("ValueBase") and med.Value==true) or (push and push:IsA("ValueBase") and push.Value==true)
                local cd=(tonumber(LocalPlayer:GetAttribute("SoulCooldownUntil")) or 0)-Workspace:GetServerTimeNow()
                if not cultivating then
                    CU2.setLabel("soul","Soul: precisa estar meditando ou na flexao (ligue Auto Realm ou Auto Body)")
                    CU_LOG.add("SOUL","espera","nao esta cultivando (IsMeditating/IsPushingUp falso): ligue Auto Realm ou Auto Body",60)
                elseif cd>0 then
                    CU2.setLabel("soul",string.format("Soul: recarga %ds",math.ceil(cd)))
                else
                    CU2.setLabel("soul","Soul: saindo do corpo")
                    CU2.fire("SoulProjection","start")
                    CU2.stats.soulTrips+=1
                    CU_LOG.add("SOUL","inicio","SoulProjection('start') enviado",0)
                    task.wait(2.1)
                    sessionStart=os.clock()
                end
            end
        elseif LocalPlayer:GetAttribute("SoulForming")~=true then
            if sessionStart==0 then sessionStart=os.clock() end
            local bodyPos=CU2.bodyPosition() or hrp.Position
            local found=false
            local sw=Workspace:FindFirstChild("SpiritWorld")
            if sw and CU2.remote("SpiritWorld") then
                local spirits=sw:FindFirstChild("Spirits")
                if spirits then
                    for _,spirit in ipairs(spirits:GetChildren()) do
                        if not CU2.on("soul") or LocalPlayer:GetAttribute("SoulProjecting")~=true then break end
                        if spirit:IsA("BasePart") and spirit.Parent and not caught[spirit] and (spirit.Position-bodyPos).Magnitude<=465 then
                            found=true
                            hrp.CFrame=spirit.CFrame
                            hrp.AssemblyLinearVelocity=Vector3.zero
                            CU2.touch(hrp,spirit)
                            task.wait(0.08)
                            if spirit.Parent then
                                hrp.CFrame=spirit.CFrame
                                CU2.fire("SpiritWorld","catch",spirit)
                                CU2.stats.soulCatches+=1
                                tripCatches+=1
                            end
                            caught[spirit]=true
                            task.wait(0.1)
                            if not spirit.Parent then
                                CU2.stats.soulGone+=1
                                CU_LOG.count("Soul: espirito sumiu depois do catch (pego)")
                            else
                                CU_LOG.count("Soul: espirito continuou depois do catch")
                            end
                        end
                    end
                end
                local herbs=sw:FindFirstChild("Herbs")
                if herbs then
                    for _,herb in ipairs(herbs:GetChildren()) do
                        if not CU2.on("soul") or LocalPlayer:GetAttribute("SoulProjecting")~=true then break end
                        if herb:IsA("BasePart") and herb:GetAttribute("Picked")~=true then
                            local prompt=herb:FindFirstChildOfClass("ProximityPrompt")
                            if prompt and (herb.Position-bodyPos).Magnitude<=465 then
                                found=true
                                hrp.CFrame=herb.CFrame*CFrame.new(0,1.5,0)
                                hrp.AssemblyLinearVelocity=Vector3.zero
                                CU2.touch(hrp,herb)
                                task.wait(0.08)
                                if fireproximityprompt then
                                    local okP,errP=pcall(fireproximityprompt,prompt)
                                    if not okP then CU_LOG.error("Soul: fireproximityprompt",errP) end
                                end
                                CU2.fire("CollectHerb",herb)
                                CU2.stats.soulHerbs+=1
                                CU_LOG.count("Soul: ervas do Spirit World")
                                task.wait(0.1)
                            end
                        end
                    end
                end
            else
                CU_LOG.add("SOUL","mapa","workspace.SpiritWorld ou o remote SpiritWorld nao existe",30)
            end
            if not found then
                hrp.CFrame=CFrame.new(bodyPos+Vector3.new(0,15,0))
                hrp.AssemblyLinearVelocity=Vector3.zero
            end
            CU2.setLabel("soul",string.format("Soul: fora do corpo ha %.0fs, %d catch",os.clock()-sessionStart,tripCatches))
            if os.clock()-sessionStart>=18 then
                hrp.CFrame=CFrame.new(bodyPos+Vector3.new(0,1.5,0))
                hrp.AssemblyLinearVelocity=Vector3.zero
                task.wait(0.15)
                if LocalPlayer:GetAttribute("SoulProjecting")==true then
                    CU2.fire("SoulProjection","return")
                    task.wait(1.5)
                end
            end
        end
        task.wait(0.35)
    end
    CU2.setLabel("soul","Soul: desligado")
end

-- ===== CULTIVO PELO SERVIDOR (Top76) =====
function CU2.bodyBreakLoop()
    while CU2.on("bodyBreak") do
        local _,_,hum=CU2.char()
        if hum and hum.Health>hum.MaxHealth*0.3 then
            CU2.fire("BodyBreakthrough")
            CU2.fire("BodyBreakthroughCutsceneDone",true)
            CU_LOG.count("Body Breakthrough servidor: enviado")
        end
        task.wait(3)
    end
end
function CU2.blindBreakLoop()
    while CU2.on("blindBreak") do
        local _,_,hum=CU2.char()
        if hum and hum.Health>hum.MaxHealth*0.3 then
            CU2.fire("Breakthrough")
            CU2.fire("BreakthroughMinigameResult",true)
            CU_LOG.count("Breakthrough as cegas: enviado")
        end
        task.wait(2)
    end
end

-- ===== ORBS (Top76: CultivationOrbClicked a cada 0,5s + tocar nos orbs a 40 studs) =====
-- Melhoria: so guarda pecas com "orb" no nome (o Top76 guardava todas as pecas do mapa e varria tudo a cada 0,5s).
function CU2.initOrbCache()
    if CU2.orbParts then return end
    CU2.orbParts=setmetatable({},{__mode="k"})
    local function reg(obj)
        if obj:IsA("BasePart") and obj.Name:lower():find("orb",1,true) then CU2.orbParts[obj]=true end
    end
    for _,obj in ipairs(Workspace:GetDescendants()) do reg(obj) end
    CU2.track(Workspace.DescendantAdded:Connect(reg))
    CU2.track(Workspace.DescendantRemoving:Connect(function(obj) CU2.orbParts[obj]=nil end))
    CU_LOG.add("ORB","cache",CU2.countKeys(CU2.orbParts).." pecas com 'orb' no nome no mapa carregado",0)
end
function CU2.orbLoop()
    CU2.initOrbCache()
    while CU2.on("orbTouch") do
        local _,hrp=CU2.char()
        local touched=0
        if hrp then
            for part in pairs(CU2.orbParts) do
                if part.Parent and (hrp.Position-part.Position).Magnitude<40 and CU2.touch(hrp,part) then touched+=1 end
            end
        end
        CU2.fire("CultivationOrbClicked")
        if touched>0 then
            CU_LOG.count("Orbs servidor: orbs tocados",touched)
            CU_LOG.add("ORB","perto",touched.." orb(s) a menos de 40 studs tocados",10)
        end
        task.wait(0.5)
    end
end

-- ===== ERVAS NO MAPA TODO (Top76) =====
-- Melhorias: filtro pela erva da aba Auto, prompt dentro de Attachment/Model, erva que nao coleta espera 10s
-- (o Top76 tentava a mesma erva sem parar), e o TXT diz se o servidor confirmou cada coleta.
function CU2.promptPart(prompt)
    local p=prompt.Parent
    if p and p:IsA("Attachment") then p=p.Parent end
    if p and p:IsA("Model") then p=p.PrimaryPart or p:FindFirstChildWhichIsA("BasePart") end
    if p and p:IsA("BasePart") then return p end
    return nil
end
function CU2.initHerbCache()
    if CU2.herbPrompts then return end
    CU2.herbPrompts=setmetatable({},{__mode="k"})
    local function reg(obj)
        if obj:IsA("ProximityPrompt") then
            local spots=Workspace:FindFirstChild("HerbSpots")
            if obj.Name=="CollectHerbPrompt" or obj.Name:lower():find("herb",1,true) or (spots and obj:IsDescendantOf(spots)) then
                CU2.herbPrompts[obj]=true
            end
        end
    end
    for _,obj in ipairs(Workspace:GetDescendants()) do reg(obj) end
    CU2.track(Workspace.DescendantAdded:Connect(reg))
    CU2.track(Workspace.DescendantRemoving:Connect(function(obj) CU2.herbPrompts[obj]=nil end))
    CU_LOG.add("ERVA2","cache",CU2.countKeys(CU2.herbPrompts).." prompts de erva no mapa carregado",0)
end
function CU2.bestHerb(fromPos)
    CU2.initHerbCache()
    local sw=Workspace:FindFirstChild("SpiritWorld")
    local now=os.clock()
    local mode=CU2.s.herbFilter
    local best=nil
    local cands=0
    for prompt in pairs(CU2.herbPrompts) do
        local part=prompt.Parent and CU2.promptPart(prompt)
        if not prompt.Parent then
            CU2.herbPrompts[prompt]=nil
        elseif part and prompt.Enabled and not (sw and part:IsDescendantOf(sw)) and now>=(CU2.herbCooldown[part] or 0) then
            local year=CU2.herbYear(part,prompt)
            if mode==1 or (mode==2 and year>=1000) or (mode==3 and CU2.herbIsSelected(part,prompt,State.selectedHerb)) then
                cands+=1
                local dist=(part.Position-fromPos).Magnitude
                local rank=(year>=1000 and 2) or (year>=100 and 1) or 0
                if not best or rank>best.rank or (rank==best.rank and dist<best.dist) then
                    best={part=part,prompt=prompt,dist=dist,year=year,rank=rank}
                end
            end
        end
    end
    CU2.herbCandidates=cands
    return best
end
function CU2.streamPoints()
    local now=os.clock()
    if CU2.pointsCache and now<(CU2.pointsCacheAt or 0) then return CU2.pointsCache end
    local points,seen={},{}
    local function add(pos)
        if typeof(pos)~="Vector3" then return end
        local key=math.floor(pos.X/150).."_"..math.floor(pos.Z/150)
        if not seen[key] then
            seen[key]=true
            points[#points+1]=pos
        end
    end
    local anchors=Workspace:FindFirstChild("MapAnchors")
    if anchors then
        for _,ch in ipairs(anchors:GetDescendants()) do
            if ch:IsA("BasePart") then add(ch.Position) end
        end
    end
    for _,mapName in ipairs({"Map_sacred-mountain","Map_withered-valley"}) do
        local m=Workspace:FindFirstChild(mapName)
        local sp=m and m:FindFirstChild("Spawns")
        if sp then
            for _,p in ipairs(sp:GetChildren()) do
                if p:IsA("BasePart") then add(p.Position) end
            end
        end
    end
    -- Melhoria: as 14 zonas do nosso teleporte tambem viram pontos de patrulha.
    for _,list in ipairs({Constants.QI_ZONES_LIST,Constants.BODY_ZONES_LIST}) do
        for _,zone in ipairs(list) do add(Constants.EXACT_ZONE_COORDS[zone]) end
    end
    for _,pos in ipairs(CU2.FALLBACK_POINTS) do add(pos) end
    CU2.pointsCache=points
    CU2.pointsCacheAt=now+15
    return points
end
function CU2.collectHerb(hrp,h)
    local part,prompt=h.part,h.prompt
    CU2.setLabel("herb2",string.format("Ervas: indo para %s (%d anos, %.0f studs)",part.Name,math.floor(h.year),h.dist))
    CU_LOG.add("ERVA2","alvo",string.format("%s | %d anos | %.0f studs | prompt '%s' / '%s'",part:GetFullName(),math.floor(h.year),h.dist,
        tostring(prompt.ObjectText),tostring(prompt.ActionText)),3)
    local stand=part.CFrame*CFrame.new(0,1.5,1.8)
    CU2.safeTeleport(hrp,stand,part,function() return not CU2.on("herb2") or CU2.mobBusy end,-3.2)
    if not CU2.on("herb2") or CU2.mobBusy then return end
    if not part.Parent or not prompt.Parent or not prompt.Enabled then
        CU_LOG.count("Ervas mapa todo: sumiu antes de chegar")
        return
    end
    local before=CU2.lastHerbPickAt
    if fireproximityprompt then
        local okP,errP=pcall(fireproximityprompt,prompt)
        if not okP then CU_LOG.error("Ervas mapa todo: fireproximityprompt",errP) end
    else
        local okH,errH=pcall(function()
            prompt:InputHoldBegin()
            task.wait(prompt.HoldDuration or 0.3)
            prompt:InputHoldEnd()
        end)
        if not okH then CU_LOG.error("Ervas mapa todo: InputHold",errH) end
    end
    CU2.fire("CollectHerb",part)
    local t0=os.clock()
    while CU2.on("herb2") and part.Parent and prompt.Enabled and CU2.lastHerbPickAt==before and os.clock()-t0<0.5 do task.wait(0.03) end
    local dist=(hrp.Position-part.Position).Magnitude
    if CU2.lastHerbPickAt>before then
        CU2.stats.herbsOk+=1
        CU2.herbCooldown[part]=os.clock()+30
        CU_LOG.count("Ervas mapa todo: coletada (servidor confirmou)")
    elseif not part.Parent or not prompt.Enabled then
        CU2.stats.herbsMaybe+=1
        CU2.herbCooldown[part]=os.clock()+30
        CU_LOG.count("Ervas mapa todo: prompt sumiu (provavelmente coletada)")
    else
        CU2.stats.herbsFail+=1
        CU2.herbCooldown[part]=os.clock()+10
        CU_LOG.count("Ervas mapa todo: nao coletou (tenta de novo em 10s)")
        CU_LOG.add("ERVA2","falhou",string.format("%s nao foi coletada: personagem a %.1f studs, prompt ainda ativo, servidor nao confirmou",part.Name,dist),5)
    end
end
function CU2.patrolStep(hrp,zoneIdx,angle)
    local points=CU2.streamPoints()
    if zoneIdx>#points then zoneIdx=1 end
    local center=points[zoneIdx] or Vector3.new(0,120,0)
    angle+=math.pi/3
    if angle>=math.pi*2 then
        angle=0
        zoneIdx=(zoneIdx%math.max(1,#points))+1
    end
    local nextPos=Vector3.new(center.X+math.cos(angle)*450,center.Y+25,center.Z+math.sin(angle)*450)
    CU2.setLabel("herb2",string.format("Ervas: nenhuma a vista (%d no filtro), patrulhando ponto %d/%d",CU2.herbCandidates or 0,zoneIdx,#points))
    CU_LOG.count("Ervas mapa todo: patrulha")
    CU_LOG.add("ERVA2","patrulha",string.format("nenhuma erva valida (%d prompts conhecidos, filtro %s); indo para (%.0f, %.0f, %.0f), ponto %d/%d",
        CU2.countKeys(CU2.herbPrompts),CU2.HERB_FILTERS[CU2.s.herbFilter],nextPos.X,nextPos.Y,nextPos.Z,zoneIdx,#points),20,"patrulha")
    local ok,err=pcall(function() LocalPlayer:RequestStreamAroundAsync(nextPos,2) end)
    if not ok then CU_LOG.error("Ervas mapa todo: RequestStreamAroundAsync",err) end
    local platform=CU2.getPlatform()
    local startPos=hrp.Position
    local steps=math.max(1,math.ceil((nextPos-startPos).Magnitude/36))
    for i=1,steps do
        if not CU2.on("herb2") or CU2.mobBusy or (CU2.event and CU2.on("sectClash")) or not hrp.Parent then break end
        if i%3==0 and CU2.bestHerb(hrp.Position) then break end
        local cf=CFrame.new(startPos:Lerp(nextPos,i/steps))
        platform.CFrame=cf*CFrame.new(0,-3.2,0)
        hrp.AssemblyLinearVelocity=Vector3.zero
        hrp.CFrame=cf
        task.wait(0.10)
    end
    return zoneIdx,angle
end
function CU2.herb2Loop()
    CU2.initHerbCache()
    CU_LOG.add("ERVA2","inicio","ligado: filtro "..CU2.HERB_FILTERS[CU2.s.herbFilter]..", "..CU2.countKeys(CU2.herbPrompts).." prompts de erva conhecidos",0)
    local zoneIdx,angle=1,0
    while CU2.on("herb2") do
        local pause=((CU2.event and CU2.on("sectClash")) and "Sect Clash") or (CU2.mobBusy and "farm de monstros")
            or (State.isTeleportingZone and "teleporte de zona") or (State.autoKillActive and "Auto Kill") or nil
        if pause then
            CU2.setLabel("herb2","Ervas: pausado ("..pause..")")
            CU_LOG.count("Ervas mapa todo: pausado ("..pause..")")
            task.wait(0.5)
        else
            local _,hrp,hum=CU2.char()
            if not hrp or hum.Health<=0 then
                task.wait(0.3)
            else
                local h=CU2.bestHerb(hrp.Position)
                if h then
                    CU2.collectHerb(hrp,h)
                elseif CU2.on("streamer") and CU2.s.herbFilter==2 then
                    CU2.setLabel("herb2","Ervas: esperando o streamer carregar uma erva de 1000 anos")
                    task.wait(0.3)
                else
                    zoneIdx,angle=CU2.patrolStep(hrp,zoneIdx,angle)
                end
            end
            task.wait(0.03)
        end
    end
    CU2.parkPlatformIfIdle()
    CU2.setLabel("herb2","Ervas: desligado")
end
-- Streamer do Top76 corrigido: LocalPlayer:RequestStreamAroundAsync (no workspace o metodo nao existe e o dele nao fazia nada).
function CU2.streamerLoop()
    local idx=1
    while CU2.on("streamer") do
        local points=CU2.streamPoints()
        if #points>0 then
            if idx>#points then idx=1 end
            local pos=points[idx]
            idx+=1
            local ok,err=pcall(function() LocalPlayer:RequestStreamAroundAsync(pos,2) end)
            if ok then
                CU_LOG.count("Streamer: areas carregadas")
            else
                CU_LOG.count("Streamer: erro")
                CU_LOG.error("Streamer",err)
            end
        end
        task.wait(0.8)
    end
end

-- ===== PILULAS PELO SERVIDOR (Top76: CauldronStartBrew / CauldronStoke(0.4) / CauldronClaim) =====
function CU2.brewRecipeText()
    return CU2.s.brewRecipe==1 and ("Pilula da aba Auto ("..tostring(State.selectedPill)..")") or CU2.BREW_RECIPES[2]
end
function CU2.brewLoop()
    CU_LOG.add("CALDEIRAO","inicio",string.format("Auto Pilulas pelo servidor ligado: %s | ano minimo %d | ervas: %s",CU2.brewRecipeText(),
        CU2.BREW_YEARS[CU2.s.brewYear],CU2.herbCountText()),0)
    while CU2.on("brew") do
        CU2.fire("CauldronClaim")
        task.wait(0.3)
        if CU2.cauldronStatus=="brewing" then
            CU2.fire("CauldronStoke",0.4)
            CU_LOG.count("Pilulas servidor: Stoke(0.4)")
            task.wait(0.8)
        else
            local payload,note=CU2.buildBrew(CU2.herbCounts,CU2.s.brewRecipe,CU2.BREW_YEARS[CU2.s.brewYear],State.selectedPill)
            if payload then
                local statusBefore=CU2.cauldronStatus
                CU2.fire("CauldronStartBrew",payload)
                CU2.stats.brewsStarted+=1
                CU_LOG.count("Pilulas servidor: Brew enviado")
                CU_LOG.add("CALDEIRAO","Brew",CU2.brewRecipeText()..": "..note.." (status antes: "..tostring(statusBefore)..")",0)
                local t0=os.clock()
                while CU2.on("brew") and CU2.cauldronStatus==statusBefore and os.clock()-t0<3 do task.wait(0.1) end
                if CU2.cauldronStatus==statusBefore then
                    CU2.lastBrewNote=os.date("%H:%M:%S").." Brew enviado ("..note.."), mas o servidor nao mudou o status em 3s"
                    CU_LOG.count("Pilulas servidor: Brew sem resposta do servidor (espera 5s)")
                    CU_LOG.add("CALDEIRAO","sem resposta","o servidor nao mandou CauldronStateUpdate em 3s depois do Brew (recusou ou o nome do status e outro); espera 5s",0)
                    task.wait(5)
                else
                    CU2.lastBrewNote=os.date("%H:%M:%S").." Brew: "..note.." -> status "..tostring(CU2.cauldronStatus)
                end
            else
                CU2.lastBrewNote=os.date("%H:%M:%S").." sem Brew: "..note
                CU_LOG.count("Pilulas servidor: sem ervas para a receita")
                CU_LOG.add("CALDEIRAO","sem Brew",note,30,"sem-brew")
            end
            task.wait(1.5)
        end
    end
end

-- ===== DAILY (Top76: ClaimReward("daily") + CauldronClaim) =====
function CU2.claimDaily(why)
    CU2.fire("ClaimReward","daily")
    CU2.fire("CauldronClaim")
    CU_LOG.count("Daily: pedidos ("..why..")")
    CU_LOG.add("DAILY",why,"ClaimReward('daily') e CauldronClaim enviados; a resposta aparece em EVENTOS DO SERVIDOR RECEBIDOS",0)
end
function CU2.dailyLoop()
    while CU2.on("dailyAuto") do
        CU2.claimDaily("automatico")
        local t0=os.clock()
        while CU2.on("dailyAuto") and os.clock()-t0<900 do task.wait(5) end
    end
end

CU2.LOOPS={
    mobFarm={"Combate: farm de monstros",CU2.mobFarmLoop},
    skills={"Combate: skills pelo servidor",CU2.skillsLoop},
    sectClash={"Sect Clash",CU2.clashLoop},
    blindBreak={"Breakthrough as cegas",CU2.blindBreakLoop},
    bodyBreak={"Body Breakthrough servidor",CU2.bodyBreakLoop},
    soul={"Soul Projection",CU2.soulLoop},
    orbTouch={"Orbs servidor",CU2.orbLoop},
    herb2={"Ervas mapa todo",CU2.herb2Loop},
    streamer={"Streamer",CU2.streamerLoop},
    brew={"Pilulas servidor",CU2.brewLoop},
    dailyAuto={"Daily automatico",CU2.dailyLoop}}
-- Um loop por chave: ligar de novo enquanto o anterior ainda roda nao cria outro.
function CU2.start(key)
    local def=CU2.LOOPS[key]
    if not def or CU2.running[key] or not CU2.on(key) then return end
    CU2.running[key]=true
    CU_LOG.spawnLoop(def[1],function()
        def[2]()
        CU2.running[key]=nil
    end)
end

-- ===== OUVINTES DO SERVIDOR (sempre ligados; cada um so age com a sua funcao ligada) =====
do
    local function listen(name,fn)
        local r=CU2.remote(name)
        if r and r:IsA("RemoteEvent") then
            CU2.track(r.OnClientEvent:Connect(function(...)
                CU_LOG.try("Ouvinte "..name,fn,...)
            end))
            return
        end
        CU_LOG.add("AVISO","CU2","ouvinte "..name.." nao ligado: o remote nao existe",0)
    end
    listen("HerbInventoryUpdate",function(data,picked)
        if type(data)=="table" then CU2.setHerbCounts(data,"HerbInventoryUpdate") end
        if picked then
            CU2.lastHerbPickAt=os.clock()
            CU_LOG.count("Ervas: servidor confirmou coleta (HerbInventoryUpdate)")
        end
    end)
    listen("CauldronStateUpdate",function(data)
        if type(data)~="table" then return end
        if type(data.herbCounts)=="table" then CU2.setHerbCounts(data.herbCounts,"CauldronStateUpdate") end
        if data.status~=nil then CU2.setCauldronStatus(tostring(data.status)) end
    end)
    listen("CauldronBrewComplete",function()
        if CU2.on("brew") then
            CU_LOG.count("Pilulas servidor: CauldronBrewComplete -> Claim")
            CU2.fire("CauldronClaim")
        end
    end)
    -- Pula o minijogo do Breakthrough (Top76). Se o minijogo continuar aberto, o nosso leitor da tela joga como antes.
    listen("StartBreakthroughMinigame",function()
        CU_LOG.count("Breakthrough: servidor abriu o minijogo (StartBreakthroughMinigame)")
        if not (State.autoBreakthroughActive and CU2.on("skipTrial")) then return end
        task.wait(0.2)
        CU2.fire("BreakthroughMinigameResult",true)
        CU2.stats.trialSkips+=1
        CU_LOG.add("TRIAL","servidor","minijogo aberto: BreakthroughMinigameResult(true) enviado para pular",0)
        task.wait(2.5)
        if CU2.trialVisible() then
            CU2.stats.trialOpen+=1
            CU_LOG.add("TRIAL","servidor","o minijogo CONTINUOU aberto 2,7s depois do (true): o servidor nao aceitou; o script joga pela tela",0)
        else
            CU2.stats.trialClosed+=1
            CU_LOG.add("TRIAL","servidor","o minijogo fechou depois do (true)",0)
        end
    end)
    listen("MapEvent",function(action,payload) CU2.onMapEvent(action,payload) end)
    -- Tribulacao, causa da morte e mensagens do servidor: continuam gravando mesmo com a janela fechada (so o log).
    local function watch(name,fn)
        local r=CU2.remote(name)
        if r and r:IsA("RemoteEvent") then
            r.OnClientEvent:Connect(function(...) CU_LOG.try("Ouvinte "..name,fn,...) end)
        else
            CU_LOG.add("AVISO","CU2","ouvinte "..name.." nao ligado: o remote nao existe",0)
        end
    end
    watch("Tribulation",function(...)
        local bolt=CU2.onTribulation(...)
        if bolt then CU2.answerBolt(bolt) end
    end)
    watch("DeathCause",function(...) CU2.onDeathCause(...) end)
    watch("GlobalMessage",function(text) CU2.onServerMessage(text) end)
end

-- ===== ABAS "COMBATE" E "EXTRA" =====
function CU2.refreshMobRows()
    local rows=CU2.ui.mobRows
    if next(rows)==nil then return end
    local _,hrp=CU2.char()
    local info={}
    for _,m in ipairs(CU2.scanMobs(false)) do
        local i=info[m.model.Name]
        if not i then
            i={n=0}
            info[m.model.Name]=i
        end
        i.n+=1
        local d=hrp and (m.hrp.Position-hrp.Position).Magnitude or 0
        if not i.d or d<i.d then
            i.d=d
            i.hp=m.hum.Health
            i.max=m.hum.MaxHealth
        end
    end
    for name,btn in pairs(rows) do
        if btn.Parent then
            local on=CU2.s.selectedMobs[name]==true
            local i=info[name]
            local text=(on and "[x] " or "[  ] ")..name..(i and string.format(" (%d) %d/%d, %.0f studs",i.n,math.floor(i.hp),math.floor(i.max),i.d) or " (nenhum vivo)")
            if btn.Text~=text then btn.Text=text end
            btn.BackgroundColor3=on and Color3.fromRGB(45,110,70) or Color3.fromRGB(60,55,70)
        end
    end
end
function CU2.tpToMob(name)
    local _,hrp=CU2.char()
    if not hrp then return end
    local best,bd=nil,1e9
    for _,m in ipairs(CU2.scanMobs(false)) do
        if m.model.Name==name then
            local d=(m.hrp.Position-hrp.Position).Magnitude
            if d<bd then best,bd=m,d end
        end
    end
    if not best then
        CU_LOG.add("COMBATE","TP","nenhum "..name.." vivo",0)
        return
    end
    CU_LOG.add("COMBATE","TP",string.format("%s a %.0f studs",name,bd),0)
    CU2.safeTeleport(hrp,best.hrp.CFrame*CFrame.new(CU2.offsetVec()),best.hrp)
end
function CU2.rebuildMobList()
    local list=CU2.ui.mobList
    if not list then return end
    for _,ch in ipairs(list:GetChildren()) do
        if ch:IsA("GuiObject") then ch:Destroy() end
    end
    CU2.ui.mobRows={}
    CU2.scanMobs(false)
    local names=CU2.mobNames or {}
    CU_LOG.add("COMBATE","lista",string.format("%d tipos de monstro: %s | %s",#names,table.concat(names,", "),tostring(CU2.containerText)),0)
    if #names==0 then
        local l=Instance.new("TextLabel")
        l.Size=UDim2.new(1,0,0,40)
        l.BackgroundTransparency=1
        l.TextWrapped=true
        l.Text="Nenhum monstro nos acampamentos (BanditCamp, CultivatorCamps, WorldBoss, bonecos). Chegue perto de um e toque em Escanear."
        l.TextColor3=Color3.fromRGB(170,170,170)
        l.TextSize=10
        l.Font=Enum.Font.Gotham
        l.TextXAlignment=Enum.TextXAlignment.Left
        l.Parent=list
        CU2.noMobsFound()
        return
    end
    local all=Instance.new("TextButton")
    all.Size=UDim2.new(1,0,0,26)
    all.BackgroundColor3=Color3.fromRGB(50,90,70)
    all.Text="Marcar / desmarcar todos"
    all.TextColor3=Color3.fromRGB(255,255,255)
    all.TextSize=11
    all.Font=Enum.Font.GothamBold
    all.LayoutOrder=0
    all.Parent=list
    addCorner(all,4)
    all.Activated:Connect(function()
        CU_LOG.try("Marcar todos os monstros",function()
            local allOn=true
            for _,n in ipairs(names) do
                if CU2.s.selectedMobs[n]~=true then allOn=false end
            end
            for _,n in ipairs(names) do CU2.s.selectedMobs[n]=not allOn end
            CU2.save()
            CU_LOG.add("TOGGLE","Monstros",(not allOn) and "todos marcados" or "todos desmarcados",0)
            CU2.refreshMobRows()
        end)
    end)
    for i,name in ipairs(names) do
        local row=Instance.new("Frame")
        row.Size=UDim2.new(1,0,0,28)
        row.BackgroundTransparency=1
        row.LayoutOrder=i
        row.Parent=list
        local t=Instance.new("TextButton")
        t.Size=UDim2.new(1,-54,1,0)
        t.BackgroundColor3=Color3.fromRGB(60,55,70)
        t.Text=name
        t.TextColor3=Color3.fromRGB(255,255,255)
        t.TextSize=10
        t.TextWrapped=true
        t.Font=Enum.Font.GothamBold
        t.TextXAlignment=Enum.TextXAlignment.Left
        t.Parent=row
        addCorner(t,4)
        local tp=Instance.new("TextButton")
        tp.Size=UDim2.new(0,50,1,0)
        tp.Position=UDim2.new(1,-50,0,0)
        tp.BackgroundColor3=Color3.fromRGB(60,100,160)
        tp.Text="TP"
        tp.TextColor3=Color3.fromRGB(255,255,255)
        tp.TextSize=11
        tp.Font=Enum.Font.GothamBold
        tp.Parent=row
        addCorner(tp,4)
        t.Activated:Connect(function()
            CU_LOG.try("Monstro "..name,function()
                CU2.s.selectedMobs[name]=not (CU2.s.selectedMobs[name]==true)
                CU2.save()
                CU_LOG.add("TOGGLE","Monstro "..name,CU2.s.selectedMobs[name] and "marcado" or "desmarcado",0)
                CU2.refreshMobRows()
            end)
        end)
        tp.Activated:Connect(function() CU_LOG.try("TP monstro "..name,CU2.tpToMob,name) end)
        CU2.ui.mobRows[name]=t
    end
    CU2.refreshMobRows()
end

do
    local order=0
    local function nextOrder()
        order+=1
        return order
    end
    local function setupPage(p)
        local layout=Instance.new("UIListLayout")
        layout.SortOrder=Enum.SortOrder.LayoutOrder
        layout.Padding=UDim.new(0,5)
        layout.Parent=p
        layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            p.CanvasSize=UDim2.new(0,0,0,layout.AbsoluteContentSize.Y+24)
        end)
    end
    local function header(p,text,color)
        local l=Instance.new("TextLabel")
        l.Size=UDim2.new(0.96,0,0,30)
        l.BackgroundTransparency=1
        l.TextWrapped=true
        l.Text=text
        l.TextColor3=color or Color3.fromRGB(180,180,180)
        l.TextSize=12
        l.Font=Enum.Font.GothamBold
        l.TextXAlignment=Enum.TextXAlignment.Left
        l.TextYAlignment=Enum.TextYAlignment.Bottom
        l.LayoutOrder=nextOrder()
        l.Parent=p
        return l
    end
    local function label(p,text,key,height)
        local l=Instance.new("TextLabel")
        l.Size=UDim2.new(0.96,0,0,height or 24)
        l.BackgroundColor3=Color3.fromRGB(26,21,31)
        l.TextWrapped=true
        l.Text=text
        l.TextColor3=Color3.fromRGB(200,200,140)
        l.TextSize=11
        l.Font=Enum.Font.GothamMedium
        l.TextXAlignment=Enum.TextXAlignment.Left
        l.TextYAlignment=Enum.TextYAlignment.Top
        l.LayoutOrder=nextOrder()
        l.Parent=p
        addCorner(l,5)
        local pad=Instance.new("UIPadding")
        pad.PaddingLeft=UDim.new(0,6)
        pad.PaddingTop=UDim.new(0,3)
        pad.Parent=l
        if key then CU2.ui.labels[key]=l end
        return l
    end
    local function button(p,text,color,onClick)
        local b=Instance.new("TextButton")
        b.Size=UDim2.new(0.96,0,0,32)
        b.BackgroundColor3=color or Color3.fromRGB(50,40,60)
        b.Text=text
        b.TextWrapped=true
        b.TextColor3=Color3.fromRGB(255,255,255)
        b.TextSize=11
        b.Font=Enum.Font.GothamBold
        b.LayoutOrder=nextOrder()
        b.Parent=p
        addCorner(b,6)
        b.Activated:Connect(function() CU_LOG.try("Botao "..text,onClick,b) end)
        return b
    end
    local function toggle(p,text,key,color,after)
        local row,setter=createToggleRow(p,0,text,CU2.s[key],color,function(val)
            CU2.s[key]=val
            CU2.save()
            if val and CU2.EXCLUSIVE[key] then CU2.exclusive(key) end
            if after then after(val) end
            if val then CU2.start(key) end
        end)
        row.LayoutOrder=nextOrder()
        local lbl=row:FindFirstChildWhichIsA("TextLabel")
        if lbl then
            lbl.TextWrapped=true
            lbl.TextSize=11
        end
        CU2.ui.setters[key]=setter
        return row
    end

    local c=CU2.tabs.Combate and CU2.tabs.Combate.page
    if c then
        setupPage(c)
        header(c,"Farm de monstros pelo servidor (CombatHit: sem tecla, funciona no celular)",Color3.fromRGB(220,120,130))
        toggle(c,"Auto Farm Monstros","mobFarm",Color3.fromRGB(210,50,70))
        toggle(c,"Turbo (2 golpes por ciclo)","turbo")
        toggle(c,"Ataque em grupo (raio 38 studs)","aoe",nil,function(val)
            if not val then CU2.resetHitboxes() end
        end)
        toggle(c,"Skills Z X C V pelo servidor","skills")
        button(c,"Posicao: "..CU2.offsetText(),Color3.fromRGB(70,60,110),function(b)
            CU2.s.offset=(CU2.s.offset%#CU2.OFFSETS)+1
            CU2.save()
            b.Text="Posicao: "..CU2.offsetText()
            CU_LOG.add("TOGGLE","Posicao do farm",CU2.offsetText(),0)
        end)
        label(c,"Alvo: farm desligado","target",24)
        button(c,"Escanear monstros do mapa",Color3.fromRGB(40,90,140),function() CU2.rebuildMobList() end)
        local list=Instance.new("Frame")
        list.Size=UDim2.new(0.96,0,0,0)
        list.BackgroundTransparency=1
        list.LayoutOrder=nextOrder()
        list.Parent=c
        local ll=Instance.new("UIListLayout")
        ll.SortOrder=Enum.SortOrder.LayoutOrder
        ll.Padding=UDim.new(0,3)
        ll.Parent=list
        ll:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            list.Size=UDim2.new(0.96,0,0,ll.AbsoluteContentSize.Y)
        end)
        CU2.ui.mobList=list
        header(c,"Sect Clash (evento de guerra entre seitas)",Color3.fromRGB(220,120,130))
        toggle(c,"Auto Sect Clash","sectClash")
        label(c,"Sect Clash: desligado","clash",34)
    end

    local e=CU2.tabs.Extra and CU2.tabs.Extra.page
    if e then
        setupPage(e)
        header(e,"Cultivo pelo servidor (pular o minijogo precisa do Auto Breakthrough da aba Auto)")
        toggle(e,"Pular minijogo do Breakthrough","skipTrial")
        toggle(e,"Breakthrough as cegas (a cada 2s)","blindBreak")
        toggle(e,"Auto Body Breakthrough (servidor)","bodyBreak")
        toggle(e,"Auto Tribulation (acerta cada raio)","tribulation")
        toggle(e,"Soul Projection + pegar espiritos","soul")
        label(e,"Soul: desligado","soul",34)
        toggle(e,"Orbs de Qi pelo servidor","orbTouch")
        header(e,"Ervas no mapa todo (teleporte rapido)")
        toggle(e,"Auto Ervas mapa todo","herb2")
        button(e,"Filtro: "..CU2.HERB_FILTERS[CU2.s.herbFilter],Color3.fromRGB(110,90,40),function(b)
            CU2.s.herbFilter=(CU2.s.herbFilter%#CU2.HERB_FILTERS)+1
            CU2.save()
            b.Text="Filtro: "..CU2.HERB_FILTERS[CU2.s.herbFilter]
            CU_LOG.add("TOGGLE","Filtro de ervas",CU2.HERB_FILTERS[CU2.s.herbFilter],0)
        end)
        toggle(e,"Carregar partes distantes do mapa","streamer")
        label(e,"Ervas: desligado","herb2",34)
        header(e,"Pilulas pelo servidor (sem abrir o caldeirao)")
        CU2.ui.recipeBtn=button(e,"Receita: "..CU2.brewRecipeText(),Color3.fromRGB(70,100,150),function(b)
            CU2.s.brewRecipe=(CU2.s.brewRecipe%#CU2.BREW_RECIPES)+1
            CU2.save()
            b.Text="Receita: "..CU2.brewRecipeText()
            CU_LOG.add("TOGGLE","Receita (servidor)",CU2.brewRecipeText(),0)
        end)
        local function yearText()
            local y=CU2.BREW_YEARS[CU2.s.brewYear]
            return y==0 and "Ano minimo da erva: qualquer" or ("Ano minimo da erva: "..y.."+")
        end
        button(e,yearText(),Color3.fromRGB(70,70,110),function(b)
            CU2.s.brewYear=(CU2.s.brewYear%#CU2.BREW_YEARS)+1
            CU2.save()
            b.Text=yearText()
            CU_LOG.add("TOGGLE","Ano minimo (servidor)",yearText(),0)
        end)
        toggle(e,"Auto Pilulas pelo servidor","brew")
        label(e,"Caldeirao: ?","brew",60)
        header(e,"Outros")
        button(e,"Pegar Daily + Caldeirao agora",Color3.fromRGB(50,140,140),function() CU2.claimDaily("botao") end)
        toggle(e,"Daily automatico (a cada 15 min)","dailyAuto")
        CU2.ui.zoneBtn=button(e,"Avisar zona ao servidor: "..tostring(State.selectedQiZone),Color3.fromRGB(80,60,140),function(b)
            CU2.fire("ZoneChanged",State.selectedQiZone)
            CU_LOG.add("ZONA","ZoneChanged","enviado: "..tostring(State.selectedQiZone).." (zona Qi escolhida na aba Location)",0)
            b.Text="Avisar zona ao servidor: "..tostring(State.selectedQiZone)
        end)
        toggle(e,"Anti-AFK","antiAfk")
    end

    -- Atualiza a lista de monstros e o caldeirao so com a aba aberta (no celular, varrer a toa pesa).
    CU_LOG.spawnLoop("CU2 telas",function()
        while not CU2.stopped and UI.ScreenGui and UI.ScreenGui.Parent do
            if UI.MainFrame and UI.MainFrame.Visible then
                local ct=CU2.tabs.Combate
                if ct and ct.page.Visible then CU2.refreshMobRows() end
                local et=CU2.tabs.Extra
                if et and et.page.Visible then
                    CU2.setLabel("brew",string.format("Caldeirao: %s | Brew enviados %d, terminados %d\nErvas: %s\nUltimo: %s",tostring(CU2.cauldronStatus),
                        CU2.stats.brewsStarted,CU2.stats.brewsDone,CU2.herbCountText(),CU2.lastBrewNote))
                    if CU2.ui.recipeBtn then CU2.ui.recipeBtn.Text="Receita: "..CU2.brewRecipeText() end
                    if CU2.ui.zoneBtn then CU2.ui.zoneBtn.Text="Avisar zona ao servidor: "..tostring(State.selectedQiZone) end
                end
            end
            task.wait(0.7)
        end
    end)
end

-- ===== INICIO: mortes, anti-AFK, religa o que estava ligado =====
do
    CU_LOG.add("INFO","CU2","remotes do Top76 neste jogo: "..CU2.remoteCheck(),0)
    local saved={}
    for _,k in ipairs(CU2.LABEL_ORDER) do
        if CU2.s[k] then saved[#saved+1]=CU2.LABELS[k] end
    end
    CU_LOG.add("INFO","CU2","funcoes CU2 salvas como ligadas (religam agora): "..(#saved>0 and table.concat(saved,", ") or "nenhuma"),0)
    local function hookChar(char)
        local hum=char:WaitForChild("Humanoid",10)
        if not hum then
            CU_LOG.add("AVISO","CU2","personagem sem Humanoid em 10s: a morte desta vida nao sera registrada",0)
            return
        end
        CU2.track(hum.Died:Connect(function() CU_LOG.try("CU2 morte",CU2.onDeath,char) end))
    end
    if LocalPlayer.Character then
        task.spawn(function() CU_LOG.try("CU2 personagem",hookChar,LocalPlayer.Character) end)
    end
    CU2.track(LocalPlayer.CharacterAdded:Connect(function(char) CU_LOG.try("CU2 personagem",hookChar,char) end))
    CU2.track(LocalPlayer.Idled:Connect(function()
        if not CU2.on("antiAfk") then return end
        local ok,err=pcall(function()
            local vu=game:GetService("VirtualUser")
            vu:CaptureController()
            vu:ClickButton2(Vector2.new(0,0))
        end)
        CU2.stats.afk+=1
        if ok then
            CU_LOG.add("INFO","Anti-AFK","o Roblox avisou que ficou parado; clique do VirtualUser enviado",0)
        else
            CU_LOG.error("Anti-AFK",err)
        end
    end))
    for _,key in ipairs(CU2.LABEL_ORDER) do
        if CU2.on(key) then CU2.start(key) end
    end
    task.spawn(function() CU_LOG.try("CU2 lista de monstros",CU2.rebuildMobList) end)
end
