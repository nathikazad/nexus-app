import json,pathlib,hashlib,os
from nexus.shared.db import connect
from nexus.hypnosis import repository as repo
from nexus.http.routes.hypnosis import recording_dir,load_recording
p=pathlib.Path(__file__).parent;i=json.loads((p/'upload.json').read_text());src=p/'audio.mp3';user=i['user_id'];mid=i['tape_id'];assert hashlib.sha256(src.read_bytes()).hexdigest()==i['sha256']
with connect(user_id=user) as c:
 with c.cursor() as cur:
  cur.execute('SELECT pg_advisory_xact_lock(73421,%s)',(user,));assert repo.identity(cur,user)==(1,1)
  old=repo.require_item(cur,user,'tapes',mid);assert old['audio']['sha256'] in [i['expected_sha256'],i['sha256']], 'Concurrent audio change'
  target=recording_dir()/f"tape-{mid}-{i['sha256'][:16]}.mp3"
  if target.exists():assert hashlib.sha256(target.read_bytes()).hexdigest()==i['sha256']
  else:
   tmp=target.with_suffix('.uploading')
   with tmp.open('xb') as f:f.write(src.read_bytes());f.flush();os.fsync(f.fileno())
   tmp.chmod(0o640);os.replace(tmp,target)
  audio={k:i[k] for k in ['sha256','size','duration_seconds','cast','script_sha256']};audio.update(link=f'/hypnosis/recordings/{mid}',filename=target.name,format='mp3',provider='inworld',model_id='inworld-tts-2',speaking_rate=.95,delivery_mode='BALANCED',processing='Explicit pauses and 5ms edge ramps; no EQ or time stretch')
  repo.mutate(cur,user,{'id':mid,'attributes':[{'key':'audio','value':audio},{'key':'story','value':i['story']},{'key':'prompt','value':i['prompt']}]})
  for key in ['story','prompt']:
   cur.execute('UPDATE attributes a SET value_text=%s,value_json=NULL FROM attribute_definitions ad WHERE ad.id=a.attribute_definition_id AND a.model_id=%s AND ad.key=%s',(i[key],mid,key))
  t=repo.require_item(cur,user,'tapes',mid);assert t['title']==old['title'] and t['desire_id']==old['desire_id'] and t['story']==i['story'] and t['prompt']==i['prompt']
path=load_recording(user,str(mid));assert hashlib.sha256(path.read_bytes()).hexdigest()==i['sha256'] and path.stat().st_size==i['size']
print(json.dumps({'tape_id':mid,'title':t['title'],'duration_seconds':i['duration_seconds'],'sha256':i['sha256'],'verified':True}))
