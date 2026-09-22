from pathlib import Path
from lupa import LuaRuntime

root = Path(__file__).resolve().parents[2]
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute('exports = function(...) end')
for file in ['shared/insulation.lua', 'shared/items.lua']:
    lua.execute((root/'thehunt_items'/file).read_text(encoding='utf-8-sig'))
lua.execute('''
function IsClothing(d) return d and d.clothing end
function IsItemContainer(d) return d and (d.isContainer or d.containerStorage) end
function ClothingContainer(id) return 'clothing:'..id end
function ItemContainer(id) return 'container:'..id end
function GetPlayerIdentifiersVORP() return 'owner', 1 end
function SafeDecodeMeta(m) return m or {} end
function IsRotatedValue(v) return v == true or v == 1 end
function IsInventoryStorageAccessible() return true end
function StorageAreaFits(s,x,y,w,h) return x>=0 and y>=0 and x+w<=s.cols and y+h<=s.rows end
function TriggerClientEvent(...) end
function SyncEquippedClothing(...) unequipped = true end
ActivePlayerPlacedContainers = {}
MySQL = { query = {}, update = {} }
function MySQL.query.await(sql, args)
    if sql:find('WHERE container IN',1,true) then
        checks=checks+1
        return (occupied or (lateChild and checks>1)) and {{id=9}} or {}
    end
    if sql:find('id <>',1,true) then return {} end
    if args[1] == 1 then return {{item_name='clothing_coat', metadata=meta, container='equipment',slot_x=6,slot_y=0}} end
    if args[1] == 2 then return {{item_name=parentName,container='equipment'}} end
    error('Unexpected query: '..sql)
end
function MySQL.update.await(sql,args) writes=writes+1; return 1 end
''')
source = (root/'thehunt_items/server/main.lua').read_text(encoding='utf-8-sig')
helper = source[source.index('local function CanPackGarment'):source.index('-- 2. Сохранение')]
process = source[source.index('local function ProcessItemPlacement'):source.index('local function RunNextPlacement')]
lua.execute(helper + process + '\nRunPacking = ProcessItemPlacement')
lua.execute('''
local bag = {containerStorage={cols=4,rows=4}}
local coat = Items.Get('clothing_coat')
assert(Items.CanPackClothing(coat,bag,{},false))
assert(not Items.CanPackClothing(coat,bag,{clothing_contents={{item_name='apple'}}},false))
assert(not Items.CanPackClothing(coat,bag,{container_contents='invalid'},false))
assert(not Items.CanPackClothing(coat,Items.Get('clothing_pant'),{},false))
assert(not Items.CanPackClothing(coat,{containerStorage={keyOnly=true}}, {},false))
Items.Register('test_bag',bag)
local function run(parent, target, full, saved, late, expected)
    parentName,occupied,meta,lateChild=parent,full,saved,late
    writes,checks,unequipped=0,0,false
    local done=false
    RunPacking(1,{dbId=1,container=target,x=0,y=0},function() done=true end)
    assert(done)
    assert(writes==expected, parent..' / '..target..' writes='..writes)
    if expected==1 then assert(unequipped) end
end
run('clothing_satchels','clothing:2',false,{},false,1)
run('test_bag','container:2',false,{},false,1)
run('test_bag','container:2',true,{},false,0)
run('clothing_satchels','clothing:2',true,{},false,0)
run('test_bag','container:2',false,{clothing_contents={{item_name='apple'}}},false,0)
run('test_bag','container:2',false,{},true,0)
run('clothing_pant','clothing:2',false,{},false,0)
run('test_bag','container:1',false,{},false,0)
''')
print('Packing: actual placement handler passed empty/full/serialized/late-child/self/ordinary-pocket cases; unequip sync passed')
