-- Editor transport. Seeking re-emits particles; their native simulation is not seekable.
FXPreview={}
local P=FXPreview
local session=nil
function P.stop()
    session=nil
    FXRuntime.stopOwner('studio')
end
local function render(s)
    FXRuntime.stopOwner('studio')
    s.fired={}
end
function P.control(d)
    if d.command=='stop' then P.stop();return {ok=true} end
    if d.command=='start' then
        local def,err=FX.composition(d.definition)
        if not def then return {ok=false,error=err} end
        if #FX.enabledPhases(def)==0 then return {ok=false,error='Все слои выключены'} end
        local context={coords=FX.vec(d.coords)}
        if d.self then context.entity=PlayerPedId()
        elseif d.targetServerId then context.targetServerId=FX.number(d.targetServerId) end
        P.stop()
        session={definition=def,context=context,cursor=FX.clamp(d.cursor,0,def.duration,0),speed=FX.clamp(d.speed,.25,2,1),loop=d.loop==true,paused=false,fired={},last=GetGameTimer(),deadline=GetGameTimer()+30000}
    elseif session then
        if d.command=='pause' then session.paused=true;FXRuntime.stopOwner('studio')
        elseif d.command=='resume' then session.paused=false;session.last=GetGameTimer();render(session)
        elseif d.command=='seek' then session.cursor=FX.clamp(d.cursor,0,session.definition.duration,0);render(session)
        elseif d.command=='speed' then session.speed=FX.clamp(d.speed,.25,2,1);render(session)
        elseif d.command=='loop' then session.loop=d.loop==true end
    else return {ok=false,error='Сначала запустите предпросмотр'} end
    return {ok=true}
end
function P.tick(now)
    local s=session;if not s then return end
    if now>=s.deadline then P.stop();SendNUIMessage({action='transport',data={state='stopped',cursor=s.cursor}});return end
    if not s.paused then
        s.cursor=s.cursor+math.max(0,now-s.last)/1000*s.speed
        if s.cursor>=s.definition.duration then
            if s.loop then s.cursor=s.cursor%s.definition.duration;render(s)
            else P.stop();SendNUIMessage({action='transport',data={state='stopped',cursor=s.definition.duration}});return end
        end
        for index,phase in ipairs(s.definition.phases) do
            local finish=phase.at+phase.params.lifetime
            if phase.enabled~=false and s.cursor>=phase.at and s.cursor<finish and not s.fired[index] then
                s.fired[index]=true
                local p=FX.copy(phase.params)
                for k,v in pairs(s.context) do p[k]=v end
                p.elapsed=s.cursor-phase.at
                p.lifetime=math.min((finish-s.cursor)/s.speed,(s.deadline-now)/1000)
                p.repeatInterval=math.max(150,p.repeatInterval/s.speed)
                local id,err=FXRuntime.play(phase.effectId,p,'studio')
                if id then FXRuntime.active[id].previewSpeed=s.speed;FXRuntime.active[id].previewLifetime=finish-s.cursor
                else SendNUIMessage({action='status',data={ok=false,text=err}}) end
            end
        end
    end
    s.last=now
    SendNUIMessage({action='transport',data={state=s.paused and 'paused' or 'playing',cursor=s.cursor,speed=s.speed}})
end
CreateThread(function() while true do P.tick(GetGameTimer());Wait(50) end end)
