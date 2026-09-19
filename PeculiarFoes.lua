--[[
PeculiarFoes v0.1.5 — Monthly Peculiar Foes checklist and route HUD

Purpose:
  * Show all 15 Peculiar Foes in I-XV order.
  * Green = active and still needed this monthly cycle.
  * Grey = complete this monthly cycle.
  * Amber = objective is not active (or its RoE state is not yet available).
  * Keep the route footer on the earliest unfinished foe, even when a later foe
    is completed out of order.

RoE authority:
  * Objective IDs 3789-3803 are Peculiar Foes I-XV.
  * Incoming 0x111 supplies active objective IDs and progress.
  * The incoming 0x112 bitmap is intentionally not used for monthly completion:
    it records lifetime completion and gives false positives for repeatable RoEs.
  * The only outgoing packet is 0x112, the normal read-only RoE log request.

Commands:
  //pfoes                 Show compact status in chat
  //pfoes show|hide|toggle
  //pfoes refresh         Request current RoE state
  //pfoes status          Show compact status in chat
  //pfoes done <I-XV|all> Mark one or more complete for this month
  //pfoes undo <I-XV|all> Mark one or more unfinished for this month
  //pfoes reset           Clear saved monthly state and re-read active RoEs
  //pfoes pos <x> <y>     Move and save the HUD
  //pfoes pos reset       Restore the default HUD position
  //pfoes pos status      Print the current HUD position
  //pfoes help

Install:
  Windower4/addons/PeculiarFoes/PeculiarFoes.lua
  Then: //lua load PeculiarFoes
]]

_addon.name = 'PeculiarFoes'
_addon.author = 'Zaknzt'
_addon.version = '0.1.5'
_addon.commands = {'pfoes', 'peculiarfoes'}
_addon.language = 'english'

local packets = require('packets')
local texts = require('texts')
local config = require('config')

local DEFAULT_X = 20
local DEFAULT_Y = 120
local TARGET_PROGRESS = 1

local COLOR = {
    green = '\\cs(90,255,120)',
    grey = '\\cs(145,145,145)',
    amber = '\\cs(255,205,90)',
    cyan = '\\cs(100,220,255)',
    white = '\\cs(245,245,245)',
    reset = '\\cr',
}

local FOES = {
    {
        roman='I', id=3789, name='Awoken Hildesvini',
        route='Unity Concord NPC -> Wanted Areas\n-> Wajaom Woodlands (CL135) -> mount\n-> H-13 Peculiar Footprints',
    },
    {
        roman='II', id=3790, name='Awoken Mokkuralfi',
        route='Home Point warp -> Aht Urhgan Whitegate #2\n-> Atmacite Refiner -> Voidwatch teleport\n-> Mount Zhayolm -> LEFT tunnel -> K/L-8\n-> west to J-8 tunnel -> southern coast\n-> I-10 Peculiar Footprints',
    },
    {
        roman='III', id=3791, name='Awoken Vampyr Jarl',
        route='Home Point warp -> Aht Urhgan Whitegate #2\n-> Chamber of Passage -> Runic Portal\n-> Nyzul Isle Staging Point -> Undersea Ruins\n-> WNW to H-8 transporter D\n-> immediately LEFT -> J transporter\n-> run NORTH -> zone to Hediva Isle\n-> mount N/NE -> hidden I-7 vegetation passage\n-> I-6 Peculiar Footprints',
    },
    {
        roman='IV', id=3792, name='Awoken Gorgimera',
        route="Home Point warp -> Fei'Yin #1 -> cast Escape\n-> Beaucedine Glacier -> mount south\n-> K-6 Peculiar Footprints",
    },
    {
        roman='V', id=3793, name='Awoken Ariri Samariri',
        route='Home Point warp -> Palborough Mines #1\n-> keep left on foot -> Map 3, G-10\n-> Peculiar Footprints',
    },
    {
        roman='VI', id=3794, name='Awoken Hrungnir',
        route='Survival Guide warp -> Aydeewa Subterrane\n-> keep left on foot -> Map 2, E-7\n-> Peculiar Footprints',
    },
    {
        roman='VII', id=3795, name='Awoken Morbol Emperor',
        route='Survival Guide warp -> Caedarva Mire\n-> enter Arrapago Reef -> go straight east\n-> Map 3, H-6 Peculiar Footprints',
    },
    {
        roman='VIII', id=3796, name='Awoken Stoorworm',
        route='Dimensional Ring or Crag Dimensional Portal\n-> Reisenjima -> Ethereal Ingress #1\n-> teleport to #9 -> nearby Peculiar Footprints',
    },
    {
        roman='IX', id=3797, name='Awoken Dendainsonne',
        route='Unity Concord NPC -> Wanted Areas\n-> Western Altepa Desert (CL125) -> mount\n-> northwest to I-6 Peculiar Footprints',
    },
    {
        roman='X', id=3798, name='Awoken Freke',
        route='Home Point warp -> Upper Jeuno #1\n-> exit to Batallia Downs -> mount\n-> J-7 Peculiar Footprints',
    },
    {
        roman='XI', id=3799, name='Awoken Tanngrisnir',
        route='Home Point warp -> Qufim Island #1\n-> travel south to G-8 Peculiar Footprints',
    },
    {
        roman='XII', id=3800, name='Awoken Nihhus',
        route="Home Point warp -> Ra'Kaznar Inner Court #1\n-> cast Escape -> Kamihr Drifts\n-> F-8 Peculiar Footprints",
    },
    {
        roman='XIII', id=3801, name='Awoken Hakenmann',
        route='Home Point warp -> Eastern Adoulin #1\n-> west to Rala Waterways entrance F-7\n-> keep left to N-5 Peculiar Footprints',
    },
    {
        roman='XIV', id=3802, name='Awoken Andhrimnir',
        route='Home Point warp -> Newton Movalpolos #1\n-> travel on foot to L-9 Peculiar Footprints',
    },
    {
        roman='XV', id=3803, name='Awoken Angantyr / Hjorvarth / Hrani',
        route='Home Point warp -> Castle Zvahl Keep #1\n-> cast Escape -> Xarcabard\n-> immediately right to D-8 Peculiar Footprints',
    },
}

local FOE_INDEX = {}
for index, foe in ipairs(FOES) do FOE_INDEX[foe.id] = index end
local ALL_DONE_MASK = (2 ^ #FOES) - 1

local defaults = {
    visible = true,
    progress = {
        cycle_key = '',
        initialized = false,
        done_mask = 0,
    },
    display = {
        pos = {x=DEFAULT_X, y=DEFAULT_Y},
        bg = {alpha=180, red=0, green=0, blue=0, visible=true},
        text = {
            alpha=255, red=245, green=245, blue=245,
            size=10, font='Consolas',
            stroke={alpha=255, red=0, green=0, blue=0, width=1},
        },
        flags={bold=false, italic=false, right=false, bottom=false, draggable=true},
        padding=6,
    },
}

local settings = config.load(defaults)
local display = texts.new('', settings.display, settings)

local state = {
    active = {},
    complete = {},
    active_seen = false,
    snapshot_seen = false,
    last_request_clock = nil,
}

local function chat(message, color)
    windower.add_to_chat(color or 121, '[PeculiarFoes] '..tostring(message or ''))
end

local function current_cycle_key()
    -- Monthly RoE objectives reset on the Japanese calendar boundary.
    local jst = os.date('!*t', os.time() + (9 * 60 * 60))
    return string.format('%04d-%02d', jst.year, jst.month)
end

local function normalize_done_mask(value)
    value = math.floor(tonumber(value) or 0)
    if value < 0 then return 0 end
    if value > ALL_DONE_MASK then return ALL_DONE_MASK end
    return value
end

local function mask_has(mask, index)
    local bit_value = 2 ^ (index - 1)
    return math.floor(mask / bit_value) % 2 == 1
end

local function mask_set(mask, index, value)
    local bit_value = 2 ^ (index - 1)
    local before = mask_has(mask, index)
    if value and not before then return mask + bit_value end
    if not value and before then return mask - bit_value end
    return mask
end

local function ensure_cycle()
    settings.progress = settings.progress or {}
    local save_needed = false

    -- v0.1.2-v0.1.3 used a dynamically keyed table. Windower config can retain
    -- the predefined `initialized` field while dropping those dynamic children,
    -- which produced initialized=true with zero completions after reload. A
    -- predefined numeric mask is stable in the settings schema.
    local done_mask = normalize_done_mask(settings.progress.done_mask)
    if type(settings.progress.done) == 'table' then
        for index, foe in ipairs(FOES) do
            if settings.progress.done[foe.roman] == true then
                done_mask = mask_set(done_mask, index, true)
            end
        end
        settings.progress.done = nil
        save_needed = true
    end
    if settings.progress.done_mask ~= done_mask then save_needed = true end
    settings.progress.done_mask = done_mask

    local key = current_cycle_key()
    if settings.progress.cycle_key ~= key then
        settings.progress.cycle_key = key
        settings.progress.initialized = false
        settings.progress.done_mask = 0
        state.snapshot_seen = false
        save_needed = true
    end

    state.complete = {}
    for index, foe in ipairs(FOES) do
        if mask_has(settings.progress.done_mask, index) then
            state.complete[foe.id] = true
        end
    end
    if save_needed then config.save(settings) end
end

local function store_done(foe, value)
    local index = FOE_INDEX[foe.id]
    local before = mask_has(settings.progress.done_mask, index)
    settings.progress.done_mask = mask_set(settings.progress.done_mask, index, value)
    if value then
        state.complete[foe.id] = true
    else
        state.complete[foe.id] = nil
    end
    return before ~= value
end

local function objective_complete(foe)
    local progress = state.active[foe.id]
    return state.complete[foe.id] == true
        or (type(progress) == 'number' and progress >= TARGET_PROGRESS)
end

local function objective_state(foe)
    if objective_complete(foe) then return 'done' end
    if state.active[foe.id] ~= nil then return 'needed' end
    if state.active_seen then return 'not_active' end
    return 'loading'
end

local function summarize()
    local result = {done=0, needed=0, not_active=0, loading=0, next_foe=nil}
    for _, foe in ipairs(FOES) do
        local status = objective_state(foe)
        result[status] = result[status] + 1
        if not result.next_foe and status ~= 'done' then result.next_foe = foe end
    end
    return result
end

local function status_color(status)
    if status == 'done' then return COLOR.grey end
    if status == 'needed' then return COLOR.green end
    return COLOR.amber
end

local function status_marker(status)
    if status == 'done' then return '[x]' end
    if status == 'needed' then return '[ ]' end
    if status == 'not_active' then return '[!]' end
    return '[?]'
end

local function render()
    local summary = summarize()
    local lines = {}
    lines[#lines+1] = string.format('%sPECULIAR FOES%s   %d/15 complete', COLOR.cyan, COLOR.reset, summary.done)
    lines[#lines+1] = '----------------------------------------------'

    for _, foe in ipairs(FOES) do
        local status = objective_state(foe)
        lines[#lines+1] = string.format('%s%-3s %-4s %s%s', status_color(status),
            status_marker(status), foe.roman, foe.name, COLOR.reset)
    end

    lines[#lines+1] = '----------------------------------------------'
    if not summary.next_foe then
        lines[#lines+1] = COLOR.green..'ALL 15 COMPLETE'..COLOR.reset
        lines[#lines+1] = 'Return to Elijah -> collect monthly Voracious Psyches'
    else
        local next_status = objective_state(summary.next_foe)
        lines[#lines+1] = string.format('%sNEXT %s - %s%s', COLOR.cyan,
            summary.next_foe.roman, summary.next_foe.name, COLOR.reset)
        lines[#lines+1] = summary.next_foe.route
        if next_status == 'not_active' then
            lines[#lines+1] = COLOR.amber..'Activate this RoE objective before fighting.'..COLOR.reset
        elseif next_status == 'loading' then
            lines[#lines+1] = COLOR.amber..'Reading current RoE state...'..COLOR.reset
        end
    end

    display:text(table.concat(lines, '\n'))
    if settings.visible then display:show() else display:hide() end
end

local function parse_active_packet(data)
    local next_active = {}
    local ok = pcall(function()
        for i=1,30 do
            local offset = 5 + ((i - 1) * 4)
            local quest_id, progress = data:unpack('b12b20', offset)
            if quest_id and quest_id > 0 then next_active[quest_id] = progress or 0 end
        end
    end)
    if not ok then
        chat('Could not parse RoE active-objective packet 0x111.', 123)
        return false
    end
    ensure_cycle()
    local tracked_active = 0
    for _, foe in ipairs(FOES) do
        if next_active[foe.id] ~= nil then tracked_active = tracked_active + 1 end
    end

    local changed = false
    if not state.snapshot_seen and tracked_active > 0 then
        -- Reconcile every session's first snapshot, even if an older config says
        -- it was initialized. This self-heals a lost/empty persisted state: the
        -- addon is built around setting I-XV, so missing members of an active
        -- sequence are the objectives already completed this month.
        settings.progress.initialized = true
        changed = true
        for _, foe in ipairs(FOES) do
            local progress = next_active[foe.id]
            if store_done(foe, progress == nil or progress >= TARGET_PROGRESS) then
                changed = true
            end
        end
    elseif settings.progress.initialized then
        for _, foe in ipairs(FOES) do
            local progress = next_active[foe.id]
            if progress ~= nil then
                -- An active zero-progress objective is authoritative evidence
                -- that it is still needed, including after a monthly reset.
                if store_done(foe, progress >= TARGET_PROGRESS) then changed = true end
            elseif state.active[foe.id] ~= nil then
                -- It was active in the previous snapshot and has now vanished:
                -- the objective completed while the addon was running.
                if store_done(foe, true) then changed = true end
            end
        end
    end

    state.active = next_active
    state.active_seen = true
    state.snapshot_seen = true
    if changed then config.save(settings) end
    return true
end

local function hydrate_active_from_cache()
    if not windower.packets or not windower.packets.last_incoming then return false end
    local ok, data = pcall(windower.packets.last_incoming, 0x111)
    if ok and data then return parse_active_packet(data) end
    return false
end

local function request_roe_state(quiet)
    local now = os.clock()
    if state.last_request_clock and now - state.last_request_clock < 1.0 then return end
    state.last_request_clock = now

    local ok, err = pcall(function()
        local request = packets.new('outgoing', 0x112, {['_unknown1']=0})
        packets.inject(request)
    end)
    if not ok then
        chat('RoE refresh request failed: '..tostring(err), 123)
    elseif not quiet then
        chat('Requested current RoE state.', 158)
    end
end

local function schedule_refresh(delay)
    if coroutine and coroutine.schedule then
        coroutine.schedule(function() request_roe_state(true) end, delay or 1.0)
    else
        request_roe_state(true)
    end
end

local function status_report()
    local summary = summarize()
    chat(string.format('v%s | complete %d/15 | needed %d | not active %d | RoE active=%s monthly=%s',
        _addon.version, summary.done, summary.needed, summary.not_active,
        tostring(state.active_seen), tostring(settings.progress.initialized)), 158)
    if summary.next_foe then
        chat(string.format('Next: %s - %s | %s', summary.next_foe.roman,
            summary.next_foe.name, summary.next_foe.route:gsub('\n', ' ')), 121)
    else
        chat('All 15 complete. Return to Elijah for monthly Voracious Psyches.', 121)
    end
end

local function find_foe(token)
    token = tostring(token or ''):upper()
    local number = tonumber(token)
    for _, foe in ipairs(FOES) do
        if token == foe.roman or number == foe.id then return foe end
    end
end

local function command_set_done(args, value)
    ensure_cycle()
    if #args < 2 then
        chat('Usage: //pfoes '..(value and 'done' or 'undo')..' <I-XV|all>', 123)
        return
    end
    local was_initialized = settings.progress.initialized == true
    local changed = false
    if tostring(args[2] or ''):lower() == 'all' then
        for _, foe in ipairs(FOES) do
            if store_done(foe, value) then changed = true end
        end
    else
        for index=2,#args do
            local foe = find_foe(args[index])
            if not foe then
                chat('Unknown objective: '..tostring(args[index])..'. Use I-XV or an objective ID.', 123)
                return
            end
            if store_done(foe, value) then changed = true end
        end
    end
    settings.progress.initialized = true
    if changed or not was_initialized then config.save(settings) end
    render()
end

local function reset_monthly_state()
    settings.progress.cycle_key = current_cycle_key()
    settings.progress.initialized = false
    settings.progress.done_mask = 0
    settings.progress.done = nil
    state.complete = {}
    state.active = {}
    state.active_seen = false
    state.snapshot_seen = false
    state.last_request_clock = nil
    config.save(settings)
    render()
    request_roe_state(false)
end

local function save_position()
    if not display or not display.pos then return end
    local x, y = display:pos()
    x, y = tonumber(x), tonumber(y)
    if not x or not y then return end
    settings.display = settings.display or {}
    settings.display.pos = settings.display.pos or {}
    settings.display.pos.x = math.floor(x)
    settings.display.pos.y = math.floor(y)
end

local function command_position(args)
    local request = tostring(args[2] or 'status'):lower()
    local x, y
    if request == 'reset' then
        x, y = DEFAULT_X, DEFAULT_Y
    elseif request == 'status' then
        local px, py = display:pos()
        px = tonumber(px) or DEFAULT_X
        py = tonumber(py) or DEFAULT_Y
        chat(string.format('HUD position = %d,%d. Reset position = %d,%d.',
            math.floor(px), math.floor(py), DEFAULT_X, DEFAULT_Y), 158)
        return
    else
        x, y = tonumber(args[2]), tonumber(args[3])
        if not x or not y then
            chat('Usage: //pfoes pos <x> <y> | reset | status', 123)
            return
        end
    end

    x, y = math.floor(x), math.floor(y)
    settings.display = settings.display or {}
    settings.display.pos = settings.display.pos or {}
    settings.display.pos.x, settings.display.pos.y = x, y
    display:pos(x, y)
    config.save(settings)
    chat(string.format('HUD position = %d,%d (saved).', x, y), 158)
end

local function usage()
    chat('//pfoes show|hide|toggle|refresh|status|done <I-XV|all>|undo <I-XV|all>|reset|pos <x> <y>|reset|status|help', 207)
end

local function handle_command(...)
    local args = {...}
    local command = tostring(args[1] or 'status'):lower()
    if command == 'show' then
        settings.visible = true
        config.save(settings)
        render()
    elseif command == 'hide' then
        settings.visible = false
        config.save(settings)
        display:hide()
    elseif command == 'toggle' then
        settings.visible = not settings.visible
        config.save(settings)
        render()
    elseif command == 'refresh' then
        state.last_request_clock = nil
        request_roe_state(false)
    elseif command == 'status' then
        status_report()
    elseif command == 'done' then
        command_set_done(args, true)
    elseif command == 'undo' then
        command_set_done(args, false)
    elseif command == 'reset' then
        reset_monthly_state()
    elseif command == 'pos' then
        command_position(args)
    elseif command == 'help' then
        usage()
    else
        usage()
    end
end

local function on_incoming_chunk(id, data, modified, injected, blocked)
    if blocked then return end
    local changed = false
    if id == 0x111 then
        changed = parse_active_packet(data)
    end
    if changed then render() end
end

local function on_load()
    ensure_cycle()
    hydrate_active_from_cache()
    render()
    schedule_refresh(1.0)
    chat('v'.._addon.version..' loaded. Read-only monthly checklist; //pfoes status', 158)
end

local function on_login()
    state.active = {}
    state.active_seen = false
    state.snapshot_seen = false
    state.last_request_clock = nil
    ensure_cycle()
    render()
    schedule_refresh(1.5)
end

local function on_zone_change()
    schedule_refresh(1.0)
end

local function on_unload()
    save_position()
    config.save(settings)
    if display and display.destroy then pcall(function() display:destroy() end) end
end

windower.register_event('load', on_load)
windower.register_event('login', on_login)
windower.register_event('zone change', on_zone_change)
windower.register_event('incoming chunk', on_incoming_chunk)
windower.register_event('addon command', handle_command)
windower.register_event('unload', on_unload)

-- Test-only export. Normal Windower runtime does not create this table.
if rawget(_G, 'PECULIARFOES_TEST_MODE') then
    _G.PeculiarFoes_Test = {
        foes=FOES,
        state=state,
        settings=settings,
        objective_complete=objective_complete,
        objective_state=objective_state,
        summarize=summarize,
        render=render,
        parse_active_packet=parse_active_packet,
        ensure_cycle=ensure_cycle,
        store_done=store_done,
        request_roe_state=request_roe_state,
        display=display,
    }
end
