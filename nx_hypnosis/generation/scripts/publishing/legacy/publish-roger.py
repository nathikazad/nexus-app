import json, pathlib, hashlib, os
from psycopg2.extras import Json
from nexus.shared.db import connect
from nexus.hypnosis import repository as repo
from nexus.http.routes.hypnosis import recording_dir, load_recording
stage=pathlib.Path(__file__).parent
info=json.loads((stage/'upload.json').read_text());user=info['user_id'];token=info['operation'];src=stage/'audio.mp3'
assert hashlib.sha256(src.read_bytes()).hexdigest()==info['sha256']
with connect(user_id=user) as conn:
 with conn.cursor() as cur:
  cur.execute('SELECT pg_advisory_xact_lock(73421,%s)',(user,))
  person,domain=repo.identity(cur,user);assert person==info['person_id']
  repo.require_item(cur,user,'desires',info['desire_id'])
  cur.execute("SELECT id FROM models WHERE user_id=%s AND domain_id=%s AND meta->>'upload_operation'=%s",(user,domain,token));existing=cur.fetchall();assert len(existing)<=1
  if existing:
   mid=existing[0][0]
   tape=repo.require_item(cur,user,'tapes',mid);assert tape['audio']['sha256']==info['sha256']
  else:
   mid=repo.save(cur,user,'tapes',{'title':info['title'],'desire_id':info['desire_id'],'story':info['story'],'prompt':info['prompt']})
   cur.execute("UPDATE models SET meta=COALESCE(meta,'{}'::jsonb)||%s::jsonb WHERE id=%s AND user_id=%s",(Json({'upload_operation':token}),mid,user))
   target=recording_dir()/f"tape-{mid}-{info['sha256'][:16]}.mp3";target.parent.mkdir(parents=True,exist_ok=True)
   if target.exists():assert hashlib.sha256(target.read_bytes()).hexdigest()==info['sha256']
   else:
    tmp=target.with_suffix('.uploading')
    with tmp.open('xb') as f:f.write(src.read_bytes());f.flush();os.fsync(f.fileno())
    tmp.chmod(0o640);os.replace(tmp,target)
   audio={'link':f'/hypnosis/recordings/{mid}','filename':target.name,'sha256':info['sha256'],'size':src.stat().st_size,'format':'mp3','duration_seconds':info['duration_seconds'],'provider':'inworld','model_id':'inworld-tts-2','cast':info['cast'],'speaking_rate':.95,'delivery_mode':'BALANCED','processing':'Explicit pauses and 5ms edge ramps; no EQ or time stretch','script_sha256':info['script_sha256']}
   repo.mutate(cur,user,{'id':mid,'attributes':[{'key':'audio','value':audio}]})
   tape=repo.require_item(cur,user,'tapes',mid)
   for key in ['story','prompt']:
    if tape.get(key)!=info[key]:
     cur.execute('UPDATE attributes a SET value_text=%s,value_json=NULL FROM attribute_definitions ad WHERE ad.id=a.attribute_definition_id AND a.model_id=%s AND ad.key=%s',(info[key],mid,key))
  tape=repo.require_item(cur,user,'tapes',mid)
  assert tape['story']==info['story'] and tape['prompt']==info['prompt'] and tape['title']==info['title'] and tape['desire_id']==str(info['desire_id'])
path=load_recording(user,str(mid));assert path.stat().st_size==info['size'];assert hashlib.sha256(path.read_bytes()).hexdigest()==info['sha256']
print(json.dumps({'tape_id':mid,'title':info['title'],'duration_seconds':info['duration_seconds'],'filename':path.name,'sha256':info['sha256'],'operation':token,'verified':True}))
