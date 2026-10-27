-- FrioHub v2.0 | Aimbot e Esp | Luau | Roblox client | Android / PC
-- GUI, ESP, camera aim assist and supported Tool activation; no anti-cheat bypass.
local Players = game:GetService('Players')
local RunService = game:GetService('RunService')
local UserInputService = game:GetService('UserInputService')
local Lighting = game:GetService('Lighting')
local HttpService = game:GetService('HttpService')
local Workspace = game:GetService('Workspace')

local LP = Players.LocalPlayer
if not LP then return end
local Camera = Workspace.CurrentCamera
local G = _G
pcall(function() if type(getgenv) == 'function' then G = getgenv() end end)
if type(G.__FrioHubv2_cleanup) == 'function' then pcall(G.__FrioHubv2_cleanup) end

local alive = true
local connections = {}
local function connect(signal, fn)
    local c = signal:Connect(fn)
    table.insert(connections, c)
    return c
end
local UI = {
    bg = Color3.fromRGB(10, 13, 23),
    side = Color3.fromRGB(17, 22, 36),
    card = Color3.fromRGB(25, 32, 51),
    ice = Color3.fromRGB(105, 217, 255),
    purple = Color3.fromRGB(131, 96, 232),
    white = Color3.fromRGB(240, 244, 255),
    dim = Color3.fromRGB(145, 158, 182),
    green = Color3.fromRGB(102, 232, 178),
    red = Color3.fromRGB(255, 116, 141),
}
local default_config = {
    aim = {
        enabled = false, engaged = false, target_lock = false,
        prediction = true, lead = 0.12, dynamic_fov = true,
        fov = 145, smooth_x = 30, smooth_y = 30,
        team_check = true, wall_check = true,
        target_part = 'Head', max_distance = 500,
        trigger = false, trigger_cooldown = 0.22,
    },
    esp = {
        enabled = false, skeleton = false, highlight = false,
        box3d = false, arrows = false, weapon = false,
        team_check = true, max_distance = 450,
        refresh = 0.09,
    },
    visuals = { crosshair = true, fov_circle = true, hit_indicator = true },
    perf = { booster = false, show_stats = true, mode = 'Safe' },
    system = { auto_save = true, mobile_buttons = true },
}
local config = HttpService:JSONDecode(HttpService:JSONEncode(default_config))
local save_path = 'FrioHub_v2_config.json'
local function read_config()
    if type(isfile) ~= 'function' or type(readfile) ~= 'function' then return false, 'Armazenamento não disponível' end
    local ok, raw = pcall(function()
        if isfile(save_path) then return readfile(save_path) end
    end)
    if not ok or not raw then return false, 'Sem configuração salva' end
    local decoded_ok, data = pcall(function() return HttpService:JSONDecode(raw) end)
    if not decoded_ok or type(data) ~= 'table' then return false, 'JSON inválido' end
    for group, values in pairs(default_config) do
        local incoming = data[group]
        if type(incoming) == 'table' then
            for key, fallback in pairs(values) do
                if type(incoming[key]) == type(fallback) then
                    config[group][key] = incoming[key]
                end
            end
        end
    end
    config.aim.engaged = false -- Nunca ativar a mira automaticamente ao executar.
    return true, 'Configuração carregada'
end
read_config()

local log_lines = {}
local log_container
local function emit_log(level, message)
    local row = string.format('[%s] [%s] %s', os.date('%H:%M:%S'), level, message)
    table.insert(log_lines, row)
    if #log_lines > 60 then table.remove(log_lines, 1) end
    if log_container then
        local l = Instance.new('TextLabel')
        l.Name = 'Entry'
        l.BackgroundTransparency = 1
        l.Text = row
        l.TextWrapped = true
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.TextYAlignment = Enum.TextYAlignment.Top
        l.TextColor3 = level == 'ERRO' and UI.red or UI.dim
        l.Font = Enum.Font.Code
        l.TextSize = 11
        l.Size = UDim2.new(1, -8, 0, 35)
        l.LayoutOrder = #log_lines
        l.Parent = log_container
        if #log_container:GetChildren() > 75 then
            for _, child in ipairs(log_container:GetChildren()) do
                if child:IsA('TextLabel') then child:Destroy(); break end
            end
        end
        task.defer(function()
            if alive and log_container then
                log_container.CanvasPosition = Vector2.new(0, math.max(0, log_container.AbsoluteCanvasSize.Y))
            end
        end)
    end
end
local function write_config()
    if type(writefile) ~= 'function' then return false, 'writefile indisponível' end
    local ok, err = pcall(function()
        local output = HttpService:JSONEncode(config)
        writefile(save_path, output)
    end)
    if not ok then return false, tostring(err) end
    return true, 'Configuração salva'
end
local save_revision = 0
local function queue_save()
    if not config.system.auto_save then return end
    save_revision += 1
    local mine = save_revision
    task.delay(1.5, function()
        if alive and mine == save_revision and config.system.auto_save then
            local ok, message = write_config()
            if not ok then emit_log('AVISO', message) end
        end
    end)
end

local function make(class, props, parent)
    local obj = Instance.new(class)
    for key, value in pairs(props or {}) do obj[key] = value end
    obj.Parent = parent
    return obj
end
local function corner(obj, radius)
    make('UICorner', { CornerRadius = UDim.new(0, radius or 10) }, obj)
end
local function outline(obj, color, transparency)
    make('UIStroke', { Color = color or UI.purple, Thickness = 1,
        Transparency = transparency or 0.55 }, obj)
end
local function text(parent, label, size, pos, dim, color, bold)
    return make('TextLabel', {
        BackgroundTransparency = 1, Text = label, Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham,
        TextColor3 = color or UI.white, TextSize = size or 13,
        Position = pos or UDim2.new(), Size = dim or UDim2.new(1, 0, 0, 27),
        TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center,
        TextTruncate = Enum.TextTruncate.AtEnd,
    }, parent)
end
local function btn(parent, label, pos, dim, bg)
    local b = make('TextButton', {
        Text = label, AutoButtonColor = true, TextColor3 = UI.white,
        TextSize = 13, Font = Enum.Font.GothamBold, BackgroundColor3 = bg or UI.card,
        Position = pos or UDim2.new(), Size = dim or UDim2.fromOffset(100, 34),
    }, parent)
    corner(b, 9)
    return b
end
local function lin(parent, color, thickness)
    local f = make('Frame', {
        BorderSizePixel = 0, BackgroundColor3 = color or UI.ice,
        Visible = false, AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 2,
        Size = UDim2.fromOffset(0, thickness or 2),
    }, parent)
    return f
end
local function put_line(frame, a, b, thickness)
    if not a or not b then frame.Visible = false; return end
    local d = b - a
    if d.Magnitude < 1 then frame.Visible = false; return end
    frame.Visible = true
    frame.Position = UDim2.fromOffset((a.X + b.X)/2, (a.Y + b.Y)/2)
    frame.Size = UDim2.fromOffset(d.Magnitude, thickness or 2)
    frame.Rotation = math.deg(math.atan2(d.Y, d.X))
end
local function is_opponent(p)
    if p == LP then return false end
    if config.aim.team_check and LP.Team ~= nil and p.Team == LP.Team then return false end
    return true
end
local function valid_humanoid(p)
    local char = p.Character
    if not char then return end
    local h = char:FindFirstChildOfClass('Humanoid')
    local root = char:FindFirstChild('HumanoidRootPart')
    if h and root and h.Health > 0 then return char, h, root end
end
local function target_part(char)
    if config.aim.target_part == 'Torso' then
        return char:FindFirstChild('UpperTorso') or char:FindFirstChild('Torso') or char:FindFirstChild('HumanoidRootPart')
    end
    return char:FindFirstChild('Head') or char:FindFirstChild('HumanoidRootPart')
end
local function visible_target(char, point)
    local cam = Workspace.CurrentCamera
    if not cam then return false end
    local origin = cam.CFrame.Position
    local delta = point - origin
    if delta.Magnitude < 0.01 then return true end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = LP.Character and {LP.Character, cam} or {cam}
    params.IgnoreWater = true
    local hit = Workspace:Raycast(origin, delta, params)
    return (not hit) or hit.Instance:IsDescendantOf(char)
end
local function screen_pos(p)
    local cam = Workspace.CurrentCamera
    if not cam then return end
    local v, on_screen = cam:WorldToViewportPoint(p)
    return Vector2.new(v.X, v.Y), on_screen, v.Z
end
local function max_aim_fov()
    local cam = Workspace.CurrentCamera
    local base = config.aim.fov
    if cam and config.aim.dynamic_fov then
        return math.clamp(base * (70 / math.max(25, cam.FieldOfView)), 30, 500)
    end
    return base
end

local gui = make('ScreenGui', { Name = 'FrioHub_v2', ResetOnSpawn = false,
    IgnoreGuiInset = true, DisplayOrder = 35, ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, LP:WaitForChild('PlayerGui'))
local overlay = make('Frame', { Name = 'ESP_Layer', BackgroundTransparency = 1, Size = UDim2.fromScale(1,1),
    Active = false, ZIndex = 1 }, gui)
local draw_cross = {lin(overlay, UI.ice, 2), lin(overlay, UI.ice, 2)}
local draw_fov = make('Frame', { Visible = false, BackgroundTransparency = 1,
    AnchorPoint = Vector2.new(.5,.5), ZIndex = 2 }, overlay)
corner(draw_fov, 500)
outline(draw_fov, UI.purple, 0.1)
local hit_marker = text(overlay, '×', 35, UDim2.new(.5, -15, .5, -28), UDim2.fromOffset(32,44), UI.green, true)
hit_marker.TextXAlignment = Enum.TextXAlignment.Center
hit_marker.Visible = false
hit_marker.ZIndex = 4
local stat_badge = text(gui, 'FPS --  |  PING --', 12, UDim2.fromOffset(12, 12), UDim2.fromOffset(210, 28), UI.ice, true)
stat_badge.BackgroundTransparency = .2
stat_badge.BackgroundColor3 = UI.bg
stat_badge.ZIndex = 5
stat_badge.Visible = false
corner(stat_badge, 7)

-- Login gate
local gate = make('Frame', { Name='KeyGate', AnchorPoint=Vector2.new(.5,.5),
    Position=UDim2.fromScale(.5,.5), Size=UDim2.fromOffset(300,200),
    BackgroundColor3=UI.side, ZIndex=30 }, gui)
corner(gate, 15); outline(gate, UI.purple, .15)
text(gate, 'FrioHub', 22, UDim2.fromOffset(18,16), UDim2.new(1,-36,0,32), UI.ice, true)
text(gate, 'Aimbot e Esp  •  KEY', 11, UDim2.fromOffset(18,48), UDim2.new(1,-36,0,22), UI.dim)
local key_input = make('TextBox', { PlaceholderText='Digite sua key', Text='', ClearTextOnFocus=false,
    TextColor3=UI.white, PlaceholderColor3=UI.dim, Font=Enum.Font.Gotham,
    TextSize=14, BackgroundColor3=UI.card, Position=UDim2.fromOffset(18,81),
    Size=UDim2.new(1,-36,0,42), ZIndex=31 }, gate)
corner(key_input,9)
local key_button = btn(gate, 'DESBLOQUEAR', UDim2.fromOffset(18,132), UDim2.new(1,-36,0,35), UI.purple)
key_button.ZIndex = 31
local key_status = text(gate, '', 11, UDim2.fromOffset(18,170), UDim2.new(1,-36,0,24), UI.red)
key_status.ZIndex = 31

-- Main window combines icon rail + dashboard cards.
local window = make('Frame', { Name='Window', BackgroundColor3=UI.bg, Visible=false,
    AnchorPoint=Vector2.new(.5,.5), Position=UDim2.fromScale(.5,.5),
    Size=UDim2.new(.8,0,.79,0), ClipsDescendants=true, ZIndex=12 }, gui)
make('UISizeConstraint', { MinSize=Vector2.new(315,48), MaxSize=Vector2.new(920,620) },window)
corner(window,15); outline(window,UI.purple,.25)
local header = make('Frame',{ BackgroundColor3=UI.side, Size=UDim2.new(1,0,0,48), ZIndex=13 },window)
text(header,'FrioHub',17,UDim2.fromOffset(14,4),UDim2.new(1,-100,0,31),UI.ice,true).ZIndex=14
text(header,'Aimbot e Esp',10,UDim2.fromOffset(15,30),UDim2.new(1,-100,0,14),UI.dim).ZIndex=14
local small = btn(header,'−',UDim2.new(1,-75,0,8),UDim2.fromOffset(30,30),UI.card)
local close = btn(header,'×',UDim2.new(1,-40,0,8),UDim2.fromOffset(30,30),UI.card)
small.ZIndex=14;close.ZIndex=14
local rail = make('Frame',{ BackgroundColor3=UI.side, Position=UDim2.fromOffset(0,48), Size=UDim2.new(0,55,1,-48),ZIndex=13 },window)
local rail_list = make('Frame',{BackgroundTransparency=1,Size=UDim2.new(1,-8,1,-12),Position=UDim2.fromOffset(4,8),ZIndex=14},rail)
make('UIListLayout',{Padding=UDim.new(0,7),SortOrder=Enum.SortOrder.LayoutOrder},rail_list)
local body = make('Frame',{BackgroundTransparency=1,Position=UDim2.fromOffset(66,59),Size=UDim2.new(1,-78,1,-71),ZIndex=13},window)
local pages, nav_buttons, ui_refreshers = {}, {}, {}
local sections = {
    {'Dashboard','⌂'},{'Aimbot','◎'},{'ESP','▣'},{'Visuals','◇'},
    {'Performance','⚡'},{'Config','≡'},{'Logs','☷'}
}
local function new_page(name)
    local page = make('ScrollingFrame',{Name=name,Visible=false,BackgroundTransparency=1,
        BorderSizePixel=0,Size=UDim2.fromScale(1,1),AutomaticCanvasSize=Enum.AutomaticSize.Y,
        CanvasSize=UDim2.new(),ScrollBarThickness=3,ScrollBarImageColor3=UI.purple,ZIndex=13},body)
    make('UIListLayout',{Padding=UDim.new(0,9),SortOrder=Enum.SortOrder.LayoutOrder},page)
    local title = text(page,name,19,UDim2.new(),UDim2.new(1,-6,0,32),UI.ice,true)
    title.LayoutOrder = 0; title.ZIndex=14
    pages[name] = page
    return page
end
local function select_page(which)
    for name, page in pairs(pages) do
        page.Visible=(name==which)
        if nav_buttons[name] then
            nav_buttons[name].BackgroundColor3=(name==which) and UI.purple or UI.card
        end
    end
end
for index, item in ipairs(sections) do
    local name, glyph = item[1], item[2]
    new_page(name)
    local b=btn(rail_list,glyph,UDim2.new(),UDim2.new(1,0,0,39),UI.card)
    b.LayoutOrder=index;b.TextSize=19;b.ZIndex=15
    nav_buttons[name]=b
    connect(b.Activated,function() select_page(name) end)
end
local order_count = {}
local function add_card(page_name, heading, description, height)
    local page=pages[page_name]
    order_count[page_name]=(order_count[page_name] or 0)+1
    local card=make('Frame',{BackgroundColor3=UI.card,Size=UDim2.new(1,-7,0,height or 69),
        ZIndex=14, LayoutOrder=order_count[page_name]},page)
    corner(card,10);outline(card,UI.purple,.73)
    local title=text(card,heading,13,UDim2.fromOffset(12,7),UDim2.new(1,-105,0,25),UI.white,true)
    local desc=text(card,description or '',10,UDim2.fromOffset(12,32),UDim2.new(1,-105,0,26),UI.dim)
    title.ZIndex=15;desc.ZIndex=15
    return card,title,desc
end
local function make_toggle(page,group,key,title,desc)
    local card=add_card(page,title,desc)
    local toggle=btn(card,'',UDim2.new(1,-84,.5,-16),UDim2.fromOffset(71,32),UI.side)
    toggle.ZIndex=16
    local function refresh()
        local value=config[group][key]
        toggle.Text=value and 'ON' or 'OFF'
        toggle.BackgroundColor3=value and UI.purple or UI.side
    end
    table.insert(ui_refreshers,refresh)
    connect(toggle.Activated,function()
        config[group][key]=not config[group][key]
        refresh();queue_save()
        emit_log('INFO',title..': '..(config[group][key] and 'ON' or 'OFF'))
    end)
    refresh()
end
local function make_select(page,group,key,title,desc,values)
    local card=add_card(page,title,desc)
    local b=btn(card,'',UDim2.new(1,-108,.5,-16),UDim2.fromOffset(96,32),UI.side)
    b.ZIndex=16
    local function refresh() b.Text=tostring(config[group][key]) end
    table.insert(ui_refreshers,refresh)
    connect(b.Activated,function()
        local idx=table.find(values,config[group][key]) or 0
        config[group][key]=values[idx % #values + 1]
        refresh();queue_save()
    end)
    refresh()
end
local function make_slider(page,group,key,title,desc,minv,maxv,step,suffix)
    local card,heading=add_card(page,title,desc,91)
    local amount=text(card,'',12,UDim2.new(1,-79,0,10),UDim2.fromOffset(66,20),UI.ice,true)
    amount.ZIndex=16;amount.TextXAlignment=Enum.TextXAlignment.Right
    local bar=make('Frame',{BackgroundColor3=UI.side,BorderSizePixel=0,
        Position=UDim2.new(0,13,1,-21),Size=UDim2.new(1,-26,0,8),ZIndex=15},card)
    corner(bar,8)
    local fill=make('Frame',{BackgroundColor3=UI.purple,BorderSizePixel=0,
        Size=UDim2.fromScale(0,1),ZIndex=16},bar)
    corner(fill,8)
    local handle=make('TextButton',{Text='',BackgroundColor3=UI.ice,
        AnchorPoint=Vector2.new(.5,.5),Size=UDim2.fromOffset(17,17),ZIndex=17},bar)
    corner(handle,20)
    local moving=false
    local function refresh()
        local v=math.clamp(config[group][key],minv,maxv)
        local pct=(v-minv)/(maxv-minv)
        fill.Size=UDim2.fromScale(pct,1)
        handle.Position=UDim2.fromScale(pct,.5)
        amount.Text=tostring(v)..(suffix or '')
    end
    table.insert(ui_refreshers,refresh)
    local function update(x)
        local pct=math.clamp((x-bar.AbsolutePosition.X)/math.max(bar.AbsoluteSize.X,1),0,1)
        local snapped=math.floor((minv+pct*(maxv-minv))/step+0.5)*step
        config[group][key]=math.clamp(snapped,minv,maxv)
        refresh();queue_save()
    end
    for _, surface in ipairs({bar,handle}) do
        connect(surface.InputBegan,function(input)
            if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
                moving=true; update(input.Position.X)
            end
        end)
    end
    connect(UserInputService.InputChanged,function(input)
        if moving and (input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch) then
            update(input.Position.X)
        end
    end)
    connect(UserInputService.InputEnded,function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then moving=false end
    end)
    refresh()
end

-- Dashboard / controls
add_card('Dashboard','FrioHub  •  Aimbot e Esp','Versão 2.0  •  Android e PC',73)
local dash_state=add_card('Dashboard','STATUS DO SISTEMA','Aguardando autenticação',75)
local dash_status=dash_state:FindFirstChildWhichIsA('TextLabel')
make_toggle('Aimbot','aim','enabled','Aim Assist','Ativar ajuste gradual de câmera')
make_toggle('Aimbot','aim','target_lock','Target Lock','Manter o mesmo alvo enquanto estiver válido')
make_toggle('Aimbot','aim','prediction','Prediction','Antecipar deslocamento por velocidade')
make_slider('Aimbot','aim','lead','Prediction Lead','Antecipação em segundos',0,0.35,0.01,'s')
make_toggle('Aimbot','aim','dynamic_fov','Dynamic FOV','Corrige área do FOV pelo zoom da câmera')
make_slider('Aimbot','aim','fov','Aim FOV','Raio de aquisição do alvo (px)',30,450,5,'px')
make_slider('Aimbot','aim','smooth_x','Smooth X','Suavização horizontal (%)',1,100,1,'%')
make_slider('Aimbot','aim','smooth_y','Smooth Y','Suavização vertical (%)',1,100,1,'%')
make_select('Aimbot','aim','target_part','Target Part','Ponto de referência da câmera',{'Head','Torso'})
make_slider('Aimbot','aim','max_distance','Aim Distance','Alcance máximo em studs',50,1500,50,'')
make_toggle('Aimbot','aim','team_check','Team Check','Não selecionar aliados')
make_toggle('Aimbot','aim','wall_check','Wall Check','Exigir visão desobstruída do personagem')
make_toggle('Aimbot','aim','trigger','Triggerbot (Tool)','Usa Tool:Activate() somente com alvo no centro')
make_slider('Aimbot','aim','trigger_cooldown','Trigger Cooldown','Pausa mínima entre ativações',0.10,0.80,0.05,'s')

make_toggle('ESP','esp','enabled','Master ESP','Ativar renderização local de jogadores')
make_toggle('ESP','esp','skeleton','Skeleton ESP','Esqueleto projetado de R6/R15')
make_toggle('ESP','esp','highlight','Highlight ESP','Contorno nativo do Roblox')
make_toggle('ESP','esp','box3d','Box 3D','Arestas projetadas da bounding box')
make_toggle('ESP','esp','arrows','Offscreen Arrows','Direções para jogadores fora da tela')
make_toggle('ESP','esp','weapon','Weapon ESP','Nome do Tool equipado e visível')
make_toggle('ESP','esp','team_check','ESP Team Check','Filtrar jogadores da mesma equipe')
make_slider('ESP','esp','max_distance','ESP Distance','Distância máxima de exibição',50,1500,50,'')
make_slider('ESP','esp','refresh','ESP Refresh','Intervalo entre desenhos',0.05,0.30,0.01,'s')

make_toggle('Visuals','visuals','crosshair','Crosshair','Retículo azul-gelo no centro da tela')
make_toggle('Visuals','visuals','fov_circle','FOV Circle','Exibir círculo da área de aquisição')
make_toggle('Visuals','visuals','hit_indicator','Hit Indicator estimado','Baseado na redução de vida após ativação')
make_toggle('Performance','perf','booster','FPS Booster','Reduz efeitos de iluminação; reversível')
make_toggle('Performance','perf','show_stats','Monitor FPS / Ping','Mostrar contador em tempo real')
make_select('Performance','perf','mode','Modo de execução','Safe: leve • Rage: rápido • Custom: ajustes',{'Safe','Rage','Custom'})
make_toggle('Config','system','auto_save','Auto Save Config','Salvar ajustes em arquivo JSON quando suportado')
make_toggle('Config','system','mobile_buttons','Botões móveis','Mostrar AIM e MENU flutuantes')
add_card('Config','Créditos','Powered by FrioMortal')
local save_card=add_card('Config','Gerenciar configurações','Salvar, recarregar ou redefinir as opções',118)
local save_btn=btn(save_card,'SALVAR',UDim2.new(0,12,1,-43),UDim2.new(.32,-12,0,32),UI.purple)
local load_btn=btn(save_card,'CARREGAR',UDim2.new(.33,0,1,-43),UDim2.new(.33,-7,0,32),UI.side)
local reset_btn=btn(save_card,'RESET',UDim2.new(.66,0,1,-43),UDim2.new(.34,-14,0,32),UI.side)
save_btn.ZIndex=16;load_btn.ZIndex=16;reset_btn.ZIndex=16

local log_page=pages.Logs
local log_box=make('ScrollingFrame',{BackgroundColor3=UI.side,BorderSizePixel=0,
    Size=UDim2.new(1,-7,0,280),AutomaticCanvasSize=Enum.AutomaticSize.Y,
    CanvasSize=UDim2.new(),ScrollBarThickness=3,
    ScrollBarImageColor3=UI.ice,LayoutOrder=1,ZIndex=14},log_page)
corner(log_box,10)
make('UIListLayout',{Padding=UDim.new(0,3),SortOrder=Enum.SortOrder.LayoutOrder},log_box)
log_container=log_box
local clear_box=btn(log_page,'LIMPAR LOGS',UDim2.new(),UDim2.new(1,-7,0,35),UI.card)
clear_box.LayoutOrder=2;clear_box.ZIndex=15
connect(clear_box.Activated,function()
    table.clear(log_lines)
    for _,child in ipairs(log_box:GetChildren()) do
        if child:IsA('TextLabel') then child:Destroy() end
    end
    emit_log('INFO','Logs reiniciados')
end)

local expanded = true
local expanded_size = window.Size
connect(small.Activated,function()
    expanded=not expanded
    rail.Visible=expanded
    body.Visible=expanded
    if expanded then
        window.Size=expanded_size
        small.Text='−'
    else
        expanded_size=window.Size
        window.Size=UDim2.fromOffset(math.max(window.AbsoluteSize.X,315),48)
        small.Text='□'
    end
end)

local drag_active=false
local drag_initial
local window_initial
connect(header.InputBegan,function(input)
    if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
        drag_active=true
        drag_initial=input.Position
        window_initial=window.Position
    end
end)
connect(UserInputService.InputChanged,function(input)
    if drag_active and (input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch) then
        local diff=input.Position-drag_initial
        window.Position=UDim2.new(window_initial.X.Scale,window_initial.X.Offset+diff.X,
            window_initial.Y.Scale,window_initial.Y.Offset+diff.Y)
    end
end)
connect(UserInputService.InputEnded,function(input)
    if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
        drag_active=false
    end
end)

local mobile_aim=btn(gui,'AIM OFF',UDim2.new(1,-106,.60,0),UDim2.fromOffset(94,41),UI.card)
local mobile_menu=btn(gui,'FrioHub',UDim2.new(1,-105,.77,0),UDim2.fromOffset(80,38),UI.purple)
mobile_aim.ZIndex=20;mobile_menu.ZIndex=20
local function refresh_buttons()
    mobile_aim.Visible=config.system.mobile_buttons and gate.Parent == nil
    mobile_menu.Visible=config.system.mobile_buttons and gate.Parent == nil
    mobile_aim.BackgroundColor3=config.aim.engaged and UI.purple or UI.card
    mobile_aim.Text=config.aim.engaged and 'AIM ON' or 'AIM OFF'
end
connect(mobile_aim.Activated,function()
    config.aim.engaged=not config.aim.engaged
    refresh_buttons()
    emit_log('INFO','Botão AIM: '..(config.aim.engaged and 'ativo' or 'inativo'))
end)
connect(mobile_menu.Activated,function() window.Visible=not window.Visible end)
connect(UserInputService.InputBegan,function(input,gpe)
    if not gpe and input.KeyCode==Enum.KeyCode.RightShift then
        window.Visible=not window.Visible
    elseif not gpe and input.KeyCode==Enum.KeyCode.E then
        config.aim.engaged=not config.aim.engaged
        refresh_buttons()
    end
end)

local visual_sets={}
local function new_visual(p)
    local holder={lines={},bones={},name=nil,arrow=nil,highlight=nil,health=nil,last_health=nil,last_trigger=0}
    for i=1,12 do holder.lines[i]=lin(overlay,UI.ice,1) end
    for i=1,15 do holder.bones[i]=lin(overlay,UI.purple,2) end
    holder.name=text(overlay,'',12,UDim2.new(),UDim2.fromOffset(160,20),UI.white,true)
    holder.name.TextXAlignment=Enum.TextXAlignment.Center
    holder.name.ZIndex=3
    holder.name.Visible=false
    holder.arrow=text(overlay,'▲',25,UDim2.new(),UDim2.fromOffset(28,28),UI.ice,true)
    holder.arrow.TextXAlignment=Enum.TextXAlignment.Center
    holder.arrow.Visible=false;holder.arrow.ZIndex=3
    holder.highlight=make('Highlight',{Name='FrioHL_'..p.UserId,Enabled=false,
        DepthMode=Enum.HighlightDepthMode.AlwaysOnTop,
        FillColor=UI.purple,FillTransparency=.83,OutlineColor=UI.ice,
        OutlineTransparency=0},overlay)
    visual_sets[p]=holder
    return holder
end
local function clear_visual(holder, destroy)
    if not holder then return end
    for _,o in ipairs(holder.lines) do o.Visible=false end
    for _,o in ipairs(holder.bones) do o.Visible=false end
    holder.name.Visible=false
    holder.arrow.Visible=false
    holder.highlight.Enabled=false
    if destroy then
        for _,o in ipairs(holder.lines) do o:Destroy() end
        for _,o in ipairs(holder.bones) do o:Destroy() end
        holder.name:Destroy();holder.arrow:Destroy();holder.highlight:Destroy()
    end
end
local function destroy_player_visual(p)
    local holder=visual_sets[p]
    if holder then clear_visual(holder,true);visual_sets[p]=nil end
end
connect(Players.PlayerRemoving,destroy_player_visual)
local r15_bones={
    {'Head','UpperTorso'}, {'UpperTorso','LowerTorso'},
    {'UpperTorso','LeftUpperArm'}, {'LeftUpperArm','LeftLowerArm'}, {'LeftLowerArm','LeftHand'},
    {'UpperTorso','RightUpperArm'}, {'RightUpperArm','RightLowerArm'}, {'RightLowerArm','RightHand'},
    {'LowerTorso','LeftUpperLeg'}, {'LeftUpperLeg','LeftLowerLeg'}, {'LeftLowerLeg','LeftFoot'},
    {'LowerTorso','RightUpperLeg'}, {'RightUpperLeg','RightLowerLeg'}, {'RightLowerLeg','RightFoot'},
}
local r6_bones={
    {'Head','Torso'}, {'Torso','Left Arm'}, {'Torso','Right Arm'},
    {'Torso','Left Leg'}, {'Torso','Right Leg'},
}
local box_edges={{1,2},{2,3},{3,4},{4,1},{5,6},{6,7},{7,8},{8,5},{1,5},{2,6},{3,7},{4,8}}
local function get_box_corners(char)
    local ok, cf, size = pcall(function() return char:GetBoundingBox() end)
    if not ok then return end
    local hx,hy,hz=size.X*.5,size.Y*.5,size.Z*.5
    local offsets={
        Vector3.new(-hx,-hy,-hz),Vector3.new(hx,-hy,-hz),
        Vector3.new(hx,hy,-hz),Vector3.new(-hx,hy,-hz),
        Vector3.new(-hx,-hy,hz),Vector3.new(hx,-hy,hz),
        Vector3.new(hx,hy,hz),Vector3.new(-hx,hy,hz),
    }
    local points={}
    for i,v in ipairs(offsets) do
        local xy,on,depth=screen_pos(cf:PointToWorldSpace(v))
        if not xy or depth<=0 then return end
        points[i]=xy
    end
    return points
end
local function get_equipped_tool(char)
    for _,object in ipairs(char:GetChildren()) do
        if object:IsA('Tool') then return object end
    end
end
local function display_player(p,holder)
    clear_visual(holder,false)
    local char,hum,root=valid_humanoid(p)
    if not char then return end
    if config.esp.team_check and LP.Team and p.Team==LP.Team then return end
    local cam=Workspace.CurrentCamera
    if not cam then return end
    local dist=(root.Position-cam.CFrame.Position).Magnitude
    if dist>config.esp.max_distance then return end
    local xy,inside,depth=screen_pos(root.Position)
    if not xy then return end
    if config.esp.highlight then
        holder.highlight.Adornee=char
        holder.highlight.Enabled=true
    end
    if config.esp.arrows and (not inside or depth<=0) then
        local center=cam.ViewportSize*.5
        local delta=xy-center
        if depth<=0 then delta=-delta end
        if delta.Magnitude<.01 then delta=Vector2.new(0,-1) end
        local unit=delta.Unit
        local margin=35
        local rx=math.max(20,center.X-margin)
        local ry=math.max(20,center.Y-margin)
        local factor=math.min(rx/math.max(math.abs(unit.X),.001),ry/math.max(math.abs(unit.Y),.001))
        local at=center+unit*factor
        holder.arrow.Position=UDim2.fromOffset(at.X-14,at.Y-14)
        holder.arrow.Rotation=math.deg(math.atan2(unit.Y,unit.X))+90
        holder.arrow.Visible=true
    end
    if not inside or depth<=0 then return end
    local head=char:FindFirstChild('Head')
    local head_at=head and select(1,screen_pos(head.Position)) or xy
    local tool=get_equipped_tool(char)
    holder.name.Text=p.DisplayName..'  ['..math.floor(dist)..' studs]'..(config.esp.weapon and tool and ('  •  '..tool.Name) or '')
    holder.name.Position=UDim2.fromOffset(head_at.X-80,head_at.Y-32)
    holder.name.Visible=true
    if config.esp.box3d then
        local points=get_box_corners(char)
        if points then
            for i,edge in ipairs(box_edges) do put_line(holder.lines[i],points[edge[1]],points[edge[2]],1.5) end
        end
    end
    if config.esp.skeleton then
        local mapping=hum.RigType==Enum.HumanoidRigType.R15 and r15_bones or r6_bones
        for i,edge in ipairs(mapping) do
            local a=char:FindFirstChild(edge[1])
            local b=char:FindFirstChild(edge[2])
            if a and b then
                local xy_a,on_a,z_a=screen_pos(a.Position)
                local xy_b,on_b,z_b=screen_pos(b.Position)
                if z_a>0 and z_b>0 then put_line(holder.bones[i],xy_a,xy_b,2) end
            end
        end
    end
end

-- Runtime: target selection, ESP updates, camera aiming, interface telemetry.
local authenticated = false
local current_target = nil
local recent_shot = -100
local hit_until = -100
local last_trigger = -100
local esp_clock = 0
local fps_clock, fps_frames = 0, 0
local health_clock, health_cache = 0, {}
local ping_ms = 0
local last_tool = nil
local tool_connection = nil
local booster_on = false
local original_lighting = {}
local effect_values = {}
local was_esp_on = false

local function track_equipped_tool()
    local char = LP.Character
    local tool = char and get_equipped_tool(char)
    if tool == last_tool then return tool end
    if tool_connection then
        tool_connection:Disconnect()
        tool_connection = nil
    end
    last_tool = tool
    if tool then
        tool_connection = tool.Activated:Connect(function()
            recent_shot = os.clock()
        end)
    end
    return tool
end

local function restore_booster()
    if not booster_on then return end
    booster_on = false
    for property, value in pairs(original_lighting) do
        pcall(function() Lighting[property] = value end)
    end
    for effect, state in pairs(effect_values) do
        if effect and effect.Parent then
            pcall(function() effect.Enabled = state end)
        end
    end
    table.clear(original_lighting)
    table.clear(effect_values)
    emit_log('INFO', 'FPS Booster desativado; iluminação restaurada')
end
local function apply_booster()
    if config.perf.booster == booster_on then return end
    if not config.perf.booster then restore_booster(); return end
    booster_on = true
    for _, property in ipairs({'GlobalShadows','FogEnd'}) do
        pcall(function() original_lighting[property] = Lighting[property] end)
    end
    pcall(function()
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 100000
    end)
    for _, effect in ipairs(Lighting:GetDescendants()) do
        if effect:IsA('PostEffect') then
            effect_values[effect] = effect.Enabled
            pcall(function() effect.Enabled = false end)
        end
    end
    emit_log('INFO','FPS Booster ativado (efeitos locais reduzidos)')
end

local function can_use_target(player)
    if not is_opponent(player) then return end
    local char, hum, root = valid_humanoid(player)
    if not char then return end
    local cam = Workspace.CurrentCamera
    if not cam then return end
    local part = target_part(char)
    if not part then return end
    local dist = (root.Position - cam.CFrame.Position).Magnitude
    if dist > config.aim.max_distance then return end
    local dest = part.Position
    if config.aim.prediction then
        dest += root.AssemblyLinearVelocity * config.aim.lead
    end
    local pt, on_screen, depth = screen_pos(dest)
    if not on_screen or depth <= 0 then return end
    if config.aim.wall_check and not visible_target(char,part.Position) then return end
    return dest, pt, dist
end
local function acquire_target()
    local cam = Workspace.CurrentCamera
    if not cam then return end
    if config.aim.target_lock and current_target then
        local dest = can_use_target(current_target)
        if dest then return current_target,dest end
    end
    local center = cam.ViewportSize * .5
    local best, best_pos, best_score
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP then
            local dest,xy = can_use_target(p)
            if dest and xy then
                local score=(xy-center).Magnitude
                if score <= max_aim_fov() and (not best_score or score < best_score) then
                    best,best_pos,best_score=p,dest,score
                end
            end
        end
    end
    return best,best_pos
end
local function angle_difference(from_angle, to_angle)
    return math.atan2(math.sin(to_angle-from_angle),math.cos(to_angle-from_angle))
end
local function aim_at(target_position,dt)
    local cam = Workspace.CurrentCamera
    if not cam then return end
    local cf=cam.CFrame
    if (target_position-cf.Position).Magnitude < 0.01 then return end
    local desired=CFrame.lookAt(cf.Position,target_position)
    local current_pitch,current_yaw=cf:ToOrientation()
    local target_pitch,target_yaw=desired:ToOrientation()
    local speed_factor=config.perf.mode=='Rage' and 1.7 or (config.perf.mode=='Safe' and .85 or 1)
    local speed_x=(3 + (101-config.aim.smooth_x)*.27) * speed_factor
    local speed_y=(3 + (101-config.aim.smooth_y)*.27) * speed_factor
    local dx=math.clamp(1-math.exp(-dt*speed_x),0,1)
    local dy=math.clamp(1-math.exp(-dt*speed_y),0,1)
    local new_pitch=current_pitch+angle_difference(current_pitch,target_pitch)*dy
    local new_yaw=current_yaw+angle_difference(current_yaw,target_yaw)*dx
    cam.CFrame=CFrame.new(cf.Position)*CFrame.fromOrientation(new_pitch,new_yaw,0)
end
local function attempt_trigger(tool)
    if not config.aim.trigger or not config.aim.engaged or not tool then return end
    local now=os.clock()
    if now-last_trigger < config.aim.trigger_cooldown then return end
    local cam=Workspace.CurrentCamera
    if not cam then return end
    local params=RaycastParams.new()
    params.FilterType=Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances=LP.Character and {LP.Character} or {}
    params.IgnoreWater=true
    local hit=Workspace:Raycast(cam.CFrame.Position,cam.CFrame.LookVector*config.aim.max_distance,params)
    if not hit then return end
    local found_player
    for _,p in ipairs(Players:GetPlayers()) do
        if p~=LP and is_opponent(p) and p.Character and hit.Instance:IsDescendantOf(p.Character) then
            found_player=p
            break
        end
    end
    if not found_player or not valid_humanoid(found_player) then return end
    last_trigger=now
    recent_shot=now
    local ok,err=pcall(function() tool:Activate() end)
    if not ok then emit_log('ERRO','Triggerbot: '..tostring(err)) end
end

local function update_visuals(dt)
    local cam=Workspace.CurrentCamera
    if not cam then return end
    local center=cam.ViewportSize*.5
    if config.visuals.crosshair and authenticated then
        put_line(draw_cross[1],center+Vector2.new(-10,0),center+Vector2.new(10,0),2)
        put_line(draw_cross[2],center+Vector2.new(0,-10),center+Vector2.new(0,10),2)
    else
        draw_cross[1].Visible=false
        draw_cross[2].Visible=false
    end
    draw_fov.Visible=authenticated and config.visuals.fov_circle and config.aim.enabled
    if draw_fov.Visible then
        local diameter=max_aim_fov()*2
        draw_fov.Position=UDim2.fromOffset(center.X,center.Y)
        draw_fov.Size=UDim2.fromOffset(diameter,diameter)
    end
    hit_marker.Visible=authenticated and config.visuals.hit_indicator and os.clock()<hit_until
    if hit_marker.Visible then
        hit_marker.Position=UDim2.fromOffset(center.X-16,center.Y-28)
    end
    stat_badge.Visible=authenticated and config.perf.show_stats
    fps_frames+=1
    fps_clock+=dt
    if fps_clock>=.6 then
        if config.perf.show_stats and authenticated then
            pcall(function() ping_ms=math.floor(LP:GetNetworkPing()*1000+.5) end)
            local fps=math.floor(fps_frames/fps_clock+.5)
            stat_badge.Text=string.format('FPS %d   |   PING %dms',fps,ping_ms)
        end
        fps_frames=0
        fps_clock=0
        apply_booster()
        refresh_buttons()
    end
end
local function scan_hit_feedback(dt)
    if not config.visuals.hit_indicator then return end
    health_clock += dt
    if health_clock < .10 then return end
    health_clock = 0
    local now = os.clock()
    for _,p in ipairs(Players:GetPlayers()) do
        if p ~= LP then
            local char = p.Character
            local h = char and char:FindFirstChildOfClass('Humanoid')
            local last = health_cache[p]
            if h then
                if last and last.humanoid == h and h.Health < last.value and now - recent_shot < .65 then
                    if not current_target or current_target == p then
                        hit_until = now + .28
                    end
                end
                health_cache[p] = {humanoid=h,value=h.Health}
            else
                health_cache[p] = nil
            end
        end
    end
end
local function esp_render(dt)
    if not config.esp.enabled then
        if was_esp_on then
            for _, holder in pairs(visual_sets) do clear_visual(holder,false) end
            was_esp_on=false
        end
        return
    end
    was_esp_on=true
    esp_clock+=dt
    local min_interval=config.perf.mode=='Safe' and math.max(.16,config.esp.refresh)
        or (config.perf.mode=='Rage' and math.min(.06,config.esp.refresh) or config.esp.refresh)
    if esp_clock<min_interval then return end
    esp_clock=0
    for _,p in ipairs(Players:GetPlayers()) do
        if p~=LP then
            local holder=visual_sets[p] or new_visual(p)
            local h=p.Character and p.Character:FindFirstChildOfClass('Humanoid')
            if h then
                if holder.last_health and h.Health<holder.last_health and os.clock()-recent_shot<.65 then
                    if current_target==p or not config.aim.target_lock then
                        hit_until=os.clock()+.28
                    end
                end
                holder.last_health=h.Health
            else
                holder.last_health=nil
            end
            display_player(p,holder)
        end
    end
end
local render_name='FrioHub_v2_Render_'..tostring(LP.UserId)
local function frame_update(dt)
    if not alive or not authenticated then return end
    local tool=track_equipped_tool()
    if config.aim.enabled and config.aim.engaged then
        local chosen,dest=acquire_target()
        current_target=chosen
        if chosen and dest then aim_at(dest,dt) end
    else
        current_target=nil
    end
    attempt_trigger(tool)
    scan_hit_feedback(dt)
    esp_render(dt)
    update_visuals(dt)
end
local function shutdown()
    if not alive then return end
    if config.system.auto_save then pcall(write_config) end
    alive=false
    if tool_connection then tool_connection:Disconnect();tool_connection=nil end
    pcall(function() RunService:UnbindFromRenderStep(render_name) end)
    for _,c in ipairs(connections) do pcall(function() c:Disconnect() end) end
    for p,holder in pairs(visual_sets) do
        clear_visual(holder,true)
        visual_sets[p]=nil
    end
    restore_booster()
    if gui then pcall(function()gui:Destroy()end) end
    if G.__FrioHubv2_cleanup == shutdown then
        G.__FrioHubv2_cleanup=nil
    end
end
G.__FrioHubv2_cleanup=shutdown

connect(close.Activated,shutdown)
connect(key_button.Activated,function()
    if key_input.Text~='FRIO-1023' then
        key_status.Text='Key inválida'
        emit_log('AVISO','Tentativa com key inválida')
        return
    end
    authenticated=true
    gate:Destroy()
    window.Visible=true
    select_page('Dashboard')
    refresh_buttons()
    emit_log('INFO','FrioHub v2.0 iniciado; key aceita')
    emit_log('INFO','Tecla E: ativar/desativar mira; RightShift: menu')
    emit_log('INFO','Hit Indicator estima acertos; não confirma autoria')
end)
connect(key_input.FocusLost,function(enter_pressed)
    if enter_pressed and key_button.Parent then
        if key_input.Text=='FRIO-1023' then
            authenticated=true
            gate:Destroy()
            window.Visible=true
            select_page('Dashboard')
            refresh_buttons()
            emit_log('INFO','FrioHub v2.0 iniciado; key aceita')
        else
            key_status.Text='Key inválida'
        end
    end
end)
connect(save_btn.Activated,function()
    local ok,msg=write_config()
    emit_log(ok and 'INFO' or 'ERRO',msg)
end)
connect(load_btn.Activated,function()
    local ok,msg=read_config()
    if ok then
        for _,refresh in ipairs(ui_refreshers) do refresh() end
        refresh_buttons()
    end
    emit_log(ok and 'INFO' or 'ERRO',msg)
end)
connect(reset_btn.Activated,function()
    for group,values in pairs(default_config) do
        for k,v in pairs(values) do config[group][k]=v end
    end
    for _,refresh in ipairs(ui_refreshers) do refresh() end
    refresh_buttons()
    queue_save()
    emit_log('INFO','Configurações restauradas para os padrões')
end)

-- The binding runs after the stock Roblox camera update.
RunService:BindToRenderStep(render_name,Enum.RenderPriority.Camera.Value+1,function(dt)
    local ok,err=pcall(frame_update,math.max(dt,1/240))
    if not ok then
        local now=os.clock()
        if not G.__FrioHubv2_last_error_at or now-G.__FrioHubv2_last_error_at>2 then
            G.__FrioHubv2_last_error_at=now
            emit_log('ERRO','Render: '..tostring(err))
        end
    end
end)
emit_log('INFO','Interface carregada; aguardando a key')
refresh_buttons()
