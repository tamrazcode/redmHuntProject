from regression import runtime

lua=runtime()
lua.execute('''
local effect
for _,e in ipairs(FX.catalog) do if e.kind=='loop' then effect=e.id; break end end
local p=assert(FX.params(effect,{entity=10,attach=true,bones={'SKEL_L_Hand','SKEL_R_Hand','SKEL_L_Foot','SKEL_R_Foot'},lifetime=2},false))
assert(#p.bones==4 and p.bone=='SKEL_L_Hand')
local starts=0
local assetUses=0
local native=Citizen.InvokeNative
Citizen.InvokeNative=function(hash,arg) if hash==0xA10DB07FC234DD12 then assetUses=assetUses+1 end;return native(hash,arg) end
StartParticleFxLoopedOnEntityBone=function() starts=starts+1;return starts end
local id=assert(api.PlayEffect(effect,p))
advance(10)
assert(starts==4)
assert(assetUses==4)
assert(api.StopEffect(id))
''')
print('PASS: four-bone particle group start and cleanup')
