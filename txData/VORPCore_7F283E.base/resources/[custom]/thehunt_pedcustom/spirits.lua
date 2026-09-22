-- Rockstar net_camp.ysc.c: funcs 954, 955, 958, 1221, 1222.
-- These four authored camp spirits use dedicated outfits, not a generic alpha clone.
PedCustomSpirit = {}
local definitions, active = {}, {}
for _, entry in ipairs(json.decode(LoadResourceFile(GetCurrentResourceName(),'data/models.json'))) do
    if entry.spiritHash then definitions[entry.model]=entry end
end
function PedCustomSpirit.Apply(ped, model)
    local entry=assert(definitions[model], 'У модели нет формы духа Rockstar')
    local ticket=Citizen.InvokeNative(0x13154A76CE0CF9AB,joaat(model),entry.spiritHash)
    local deadline=GetGameTimer()+5000
    while not Citizen.InvokeNative(0x610438375E5D1801,ticket) and GetGameTimer()<deadline do Wait(20) end
    if not Citizen.InvokeNative(0x610438375E5D1801,ticket) then
        Citizen.InvokeNative(0x4592B8B9B0EF5F48,ticket);error('Форма духа недоступна в игровом билде')
    end
    Citizen.InvokeNative(0x74F512E29CB717E2,ticket,ped,true,true)
    Citizen.InvokeNative(0x4592B8B9B0EF5F48,ticket)
end
local function stop(ped)
    local record=active[ped]
    if not record then return end
    for _, handle in ipairs(record.handles) do StopParticleFxLooped(handle,false) end
    active[ped]=nil
end
function PedCustomSpirit.Track(ped, model)
    if active[ped] and active[ped].model==model then return end
    stop(ped)
    if not model then return end
    local record={model=model,handles={}};active[ped]=record
    CreateThread(function()
        RequestNamedPtfxAsset('scr_net_camp')
        local deadline=GetGameTimer()+5000
        while not HasNamedPtfxAssetLoaded('scr_net_camp') and GetGameTimer()<deadline do Wait(50) end
        if active[ped]~=record or not DoesEntityExist(ped) or not HasNamedPtfxAssetLoaded('scr_net_camp') then return end
        local body=model:find('boar') and 'scr_net_animal_ghost_boar' or
            (model:find('rabbit') or model:find('possum')) and 'scr_net_animal_ghost_sma' or 'scr_net_animal_ghost'
        local function fx(name,bone)
            UseParticleFxAsset('scr_net_camp')
            record.handles[#record.handles+1]=Citizen.InvokeNative(0xE689C1B1432BB8AF,name,ped,
                0.0,0.0,0.0,0.0,0.0,0.0,bone,1.0,false,false,false)
        end
        fx(body,14411)
        if model:find('buck') then
            fx('scr_net_animal_ghost_head',14285)
            for _, bone in ipairs({43312,33646,54187,55120,45454,53675}) do fx('scr_net_animal_ghost_limb',bone) end
        end
    end)
end
CreateThread(function()
    while true do
        local any=false
        for ped, record in pairs(active) do
            if not DoesEntityExist(ped) or GetEntityModel(ped)~=joaat(record.model) then stop(ped)
            else
                any=true
                SetPedResetFlag(ped,180,true)
                Citizen.InvokeNative(0xC06F2F45A73EABCD,ped)
            end
        end
        Wait(any and 0 or 250)
    end
end)
AddEventHandler('onResourceStop',function(name)
    if name~=GetCurrentResourceName() then return end
    for ped in pairs(active) do stop(ped) end
    RemoveNamedPtfxAsset('scr_net_camp')
end)
