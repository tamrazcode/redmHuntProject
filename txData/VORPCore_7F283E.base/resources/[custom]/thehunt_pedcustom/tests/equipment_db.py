"""Execute the real Lua equipment module against an isolated MariaDB schema.
Never reads or writes character/player rows in the live database.
"""
import json,sys,uuid
from pathlib import Path
sys.path.insert(0,r'C:\Users\borch\AppData\Local\Temp\hunt-pedcustom-validation')
import pymysql
from lupa import LuaRuntime,lua_type
root=Path(__file__).resolve().parents[1]
schema='pedcustom_test_'+uuid.uuid4().hex[:12]
connection=pymysql.connect(host='127.0.0.1',user='root',autocommit=True,charset='utf8mb4',cursorclass=pymysql.cursors.DictCursor)
lua=LuaRuntime(unpack_returned_tuples=True)
def py(value):
 if lua_type(value)!='table': return value
 keys=list(value.keys())
 if keys and all(isinstance(k,int) for k in keys) and sorted(keys)==list(range(1,len(keys)+1)):
  return [py(value[i]) for i in range(1,len(keys)+1)]
 return {k:py(v) for k,v in value.items()}
def lt(value): return lua.table_from(value,recursive=True) if isinstance(value,(dict,list)) else value
def sql(query,params=None):
 params=py(params) if params is not None else []
 if isinstance(params,dict):params=[]
 with connection.cursor() as cur:
  # Literal LIKE percent signs must be escaped for PyMySQL interpolation.
  cur.execute(query.replace('%','%%').replace('?','%s'),params)
  return list(cur.fetchall()) if cur.description else cur.rowcount
def query(q,p=None):return lt(sql(q,p))
def single(q,p=None):
 rows=sql(q,p);return lt(rows[0]) if rows else None
inject_failure=False
def transaction(queries):
 global inject_failure
 try:
  connection.begin()
  for index,entry in enumerate(py(queries)):
   sql(entry['query'],entry.get('values',[]))
   if inject_failure and index==3:raise RuntimeError('injected transaction failure')
  connection.commit();return True
 except Exception:
  connection.rollback();return False
 finally:inject_failure=False
g=lua.globals();g.pyquery=query;g.pysingle=single;g.pytransaction=transaction
g.encode=lambda v:json.dumps(py(v),ensure_ascii=False,separators=(',',':'),sort_keys=True)
g.decode=lambda v:lt(json.loads(v))
try:
 sql('CREATE DATABASE '+schema);sql('USE '+schema)
 sql('''CREATE TABLE thehunt_inventories(id INT AUTO_INCREMENT PRIMARY KEY,identifier VARCHAR(64) NOT NULL,
 charidentifier INT NOT NULL,container VARCHAR(32) NOT NULL,slot_x INT NOT NULL DEFAULT 0,slot_y INT NOT NULL DEFAULT 0,
 is_rotated TINYINT NOT NULL DEFAULT 0,item_name VARCHAR(64) NOT NULL,count INT NOT NULL DEFAULT 1,metadata LONGTEXT,
 INDEX owner_idx(identifier,charidentifier)) ENGINE=InnoDB''')
 lua.execute('''
 handlers={};timers={};clock=1;locked=false
 json={encode=encode,decode=decode}
 MySQL={query={await=pyquery},single={await=pysingle},transaction={await=pytransaction},ready=function(f)f()end}
 local defs={clothing_shirt={clothing=true,clothingSlot='Shirt'},clothing_pant={clothing=true,clothingSlot='Pant'},
 backpack_test={clothing=true,clothingSlot='Satchels',isBackpack=true}}
 exports=setmetatable({thehunt_core={GetPlayerIdentifier=function()return 'test-owner' end,GetCharacterId=function()return 77 end},
 thehunt_items={GetItemData=function(_,name)return defs[name]end}},{__call=function()end})
 function GetGameTimer()clock=clock+1;return clock end
 function SetTimeout(_,fn)timers[#timers+1]=fn end
 function Player()return {state={set=function(_,_,value)locked=value end}}end
 function TriggerClientEvent()end
 function TriggerEvent()end
 function AddEventHandler(name,fn)handlers[name]=fn end
 function GetCurrentResourceName()return 'thehunt_pedcustom'end
 ''')
 lua.execute((root/'equipment.lua').read_text(encoding='utf-8'))
 def add(item,container='main',metadata=None,count=1,owner='test-owner',char=77):
  sql('INSERT INTO thehunt_inventories(identifier,charidentifier,container,item_name,count,metadata) VALUES(?,?,?,?,?,?)',
      [owner,char,container,item,count,json.dumps(metadata or {})]);return sql('SELECT LAST_INSERT_ID() id')[0]['id']
 original_shirt=add('clothing_shirt','equipment',{'component':11,'gender':'Male'})
 original_bag=add('backpack_test','equipment',{'backpackFit':{'x':0.1},'clothing_contents':[{'item_name':'cash','count':4}]})
 original_child=add('bag','clothing:'+str(original_bag))
 original_nested=add('ammo','container:'+str(original_child),count=12)
 main=add('medkit',count=2)
 foreign=add('ammo','main',count=3,owner='another-owner',char=88)
 original_rows=sql('SELECT * FROM thehunt_inventories ORDER BY id')
 data=lt({'model':'mp_female','appearance':{'gender':'Female','skin':{'Head':123},'comps':{'Shirt':22},'compTints':{}},
   'equipment':[{'item':'backpack_test','metadata':{'backpackFit':{'x':0.2},'container_contents':[{'item_name':'cash','count':999}], 'id':999}}]})
 eq=g.PedEquipment
 blueprint=py(eq.Blueprint(data))
 assert len(blueprint)==2 and all('container_contents' not in x['metadata'] and 'id' not in x['metadata'] for x in blueprint)
 plan=eq.Plan(7,data,False);assert plan['first'] and plan['count']==0 and g.locked
 eq.Cancel(7);assert sql('SELECT * FROM thehunt_inventories ORDER BY id')==original_rows and not g.locked
 plan=eq.Plan(7,data,False);eq.Replace(7,data,plan['token'],False)
 assert len(sql("SELECT * FROM thehunt_inventories WHERE identifier='pedcustom:77'"))==4
 assert len(sql("SELECT * FROM thehunt_inventories WHERE identifier='test-owner' AND container='equipment'"))==2
 assert len(py(eq.Capture(77)))==2 and len(py(eq.Capture(77,True)))==2
 equipped=sql("SELECT id FROM thehunt_inventories WHERE identifier='test-owner' AND item_name='backpack_test'")[0]['id']
 child=add('pouch','clothing:'+str(equipped));add('ammo','container:'+str(child),count=5)
 plan=eq.Plan(7,data,False);assert plan['count']==6
 eq.Cancel(7);assert len(sql('SELECT id FROM thehunt_inventories WHERE id=?',[child]))==1
 # A mutation between warning and confirmation must reject, without replacing anything.
 plan=eq.Plan(7,data,False);add('food',count=1)
 before=sql('SELECT * FROM thehunt_inventories ORDER BY id')
 ok,_=lua.eval('function(eq,d,t)local ok,e=pcall(eq.Replace,7,d,t,false);return ok,e end')(eq,data,plan['token'])
 assert not ok and sql('SELECT * FROM thehunt_inventories ORDER BY id')==before
 eq.Cancel(7)
 plan=eq.Plan(7,data,False);inject_failure=True
 ok,_=lua.eval('function(eq,d,t)local ok,e=pcall(eq.Replace,7,d,t,false);return ok,e end')(eq,data,plan['token'])
 assert not ok and sql('SELECT * FROM thehunt_inventories ORDER BY id')==before and not g.locked
 # Confirmed animal form removes temporary garments + contents, leaves main and escrow alone.
 animal=lt({'model':'a_c_wolf'})
 plan=eq.Plan(7,animal,False);eq.Replace(7,animal,plan['token'],False)
 assert not sql("SELECT id FROM thehunt_inventories WHERE identifier='test-owner' AND container='equipment'")
 assert not sql('SELECT id FROM thehunt_inventories WHERE id=?',[child])
 # Simulate resource restart: recovery must depend on persistent escrow, not process-local memory.
 lua.execute('PedEquipment=nil');lua.execute((root/'equipment.lua').read_text(encoding='utf-8'));eq=g.PedEquipment
 plan=eq.Plan(7,None,True);eq.Replace(7,None,plan['token'],True)
 for row in original_rows:assert sql('SELECT * FROM thehunt_inventories WHERE id=?',[row['id']])[0]==row
 assert not sql('SELECT * FROM thehunt_pedcustom_equipment')
 print('Equipment DB OK: real Lua + MariaDB; empty copies, nested escrow, cancel, stale confirmation, SQL rollback, animal clearing, restart recovery, original IDs/content, foreign/main preservation.')
finally:
 sql('DROP DATABASE IF EXISTS '+schema);connection.close()
