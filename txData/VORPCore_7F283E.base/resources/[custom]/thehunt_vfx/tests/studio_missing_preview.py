from regression import runtime, ROOT

c=runtime()
c.execute('''
nui={}
function RegisterCommand() end
function RegisterKeyMapping() end
function RegisterNUICallback(n,f) nui[n]=f end
function SendNUIMessage() end
function SetNuiFocus() end
function SetNuiFocusKeepInput() end
''')
c.execute((ROOT/'client/studio.lua').read_text(encoding='utf-8'))
c.execute('''
function invoke(name,data)
 local result
 nui[name](data or {},function(r) result=r end)
 return result
end
source=65535;events['thehunt_vfx:studio']({},true)
assert(FXPreview==nil)
assert(invoke('preview',{effectId='light|point',params={}}).ok)
assert(invoke('stopPreview').ok)
assert(invoke('transport',{command='start'}).ok==false)
assert(invoke('close').ok,'missing transport blocked closing')
source=65535;events['thehunt_vfx:studio']({},true)
local stops=0
FXPreview={stop=function() stops=stops+1 end,control=function() return {ok=true} end}
assert(invoke('transport').ok)
assert(invoke('close').ok and stops==1)
''')
print('PASS: missing preview module does not break effect test, stop or close; transport reports actionable error; loaded transport still used')
