#!/usr/bin/env python3
"""Experimental offline binding, never used by the live scene. Run from repo root.
Requires numpy, scipy, Pillow. Source is recovered with git show ef7d28d:assets/models/thrall.glb.
"""
import argparse, copy, io, json, struct
from pathlib import Path
import numpy as np
from scipy.spatial import cKDTree
from scipy.sparse import coo_matrix, diags
from PIL import Image


def read_glb(path):
    raw = Path(path).read_bytes()
    length = struct.unpack_from('<I', raw, 12)[0]
    return json.loads(raw[20:20+length]), raw[28+length:]


def accessor(j, b, idx):
    a = j['accessors'][idx]; v = j['bufferViews'][a['bufferView']]
    types = {5121:'u1',5123:'<u2',5125:'<u4',5126:'<f4'}
    width = {'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}[a['type']]
    dtype = np.dtype(types[a['componentType']]); offset = v.get('byteOffset',0)+a.get('byteOffset',0)
    return np.ndarray((a['count'],width),dtype=dtype,buffer=b,offset=offset,strides=(v.get('byteStride',width*dtype.itemsize),dtype.itemsize)).copy()


def build(source, rig, output, smooth=12):
    fox, fb = read_glb(source); base, bb = read_glb(rig)
    p = base['meshes'][0]['primitives'][0]['attributes']
    ref = accessor(base,bb,p['POSITION']); joints = accessor(base,bb,p['JOINTS_0']); weights = accessor(base,bb,p['WEIGHTS_0'])
    tree = cKDTree(ref)
    out = {k:copy.deepcopy(base[k]) for k in ('asset','scene','scenes','nodes','skins') if k in base}
    out.update(meshes=[{'name':'Foxboard experimental','primitives':[]}],materials=copy.deepcopy(fox['materials']),textures=copy.deepcopy(fox['textures']),samplers=copy.deepcopy(fox.get('samplers',[])),images=[],buffers=[],bufferViews=[],accessors=[])
    blob=bytearray()
    def view(data,target=None):
        while len(blob)%4:blob.append(0)
        v={'buffer':0,'byteOffset':len(blob),'byteLength':len(data)}
        if target:v['target']=target
        out['bufferViews'].append(v);blob.extend(data);return len(out['bufferViews'])-1
    def add(a,kind,component,target=None,bounds=False):
        v=view(a.tobytes(),target); rec={'bufferView':v,'componentType':component,'count':len(a),'type':kind}
        if bounds:rec.update(min=a.min(axis=0).tolist(),max=a.max(axis=0).tolist())
        out['accessors'].append(rec);return len(out['accessors'])-1
    ibm=accessor(base,bb,base['skins'][0]['inverseBindMatrices'])
    out['skins'][0]['inverseBindMatrices']=add(ibm,'MAT4',5126)
    for im in fox['images']:
        v=fox['bufferViews'][im['bufferView']]; start=v.get('byteOffset',0)
        tex=Image.open(io.BytesIO(fb[start:start+v['byteLength']])).convert('RGB'); tex.thumbnail((1024,1024)); dest=io.BytesIO();tex.save(dest,'JPEG',quality=85,optimize=True)
        out['images'].append({'name':'Foxboard_albedo','mimeType':'image/jpeg','bufferView':view(dest.getvalue())})
        print('Texture:',tex.size,len(dest.getvalue()),'bytes')
    # A black, unlit material masks the historical visible face; this is an initial test mask,
    # not an approved art revision. Inspect every pose in-engine before accepting.
    out['materials'].append({'name':'faceless test mask','doubleSided':True,'pbrMetallicRoughness':{'baseColorFactor':[0.004,0.004,0.004,1]},'extensions':{'KHR_materials_unlit':{}}})
    out['extensionsUsed']=['KHR_materials_unlit']
    for n in fox['nodes']:
        if 'mesh' not in n:continue
        for prim in fox['meshes'][n['mesh']]['primitives']:
            at=prim['attributes']; pos=accessor(fox,fb,at['POSITION'])+np.array(n.get('translation',[0,0,0]),np.float32)
            pos=pos[:,[2,1,0]]*np.array([-1,1,1],np.float32);pos[:,1]-=0.0004359
            normal=accessor(fox,fb,at['NORMAL'])[:,[2,1,0]]*np.array([-1,1,1],np.float32)
            d,idx=tree.query(pos,k=4); factors=1/np.maximum(d,0.002)**2; factors/=factors.sum(axis=1,keepdims=True)
            allw=np.zeros((len(pos),24),np.float32)
            for ix in range(4):
                for jx in range(4):np.add.at(allw,(np.arange(len(pos)),joints[idx[:,ix],jx]),factors[:,ix]*weights[idx[:,ix],jx])
            # Preserve the rope as a single attached prop instead of transferring leg weights onto it.
            if n['mesh']==1:allw[:]=0;allw[:,0]=1
            else:
                # Smooth on welded positions so UV splits cannot create weight seams.
                _, weld = np.unique(np.round(pos, 5), axis=0, return_inverse=True)
                tri = weld[accessor(fox,fb,prim['indices']).reshape(-1,3)]
                e = np.concatenate([tri[:,[0,1]],tri[:,[1,2]],tri[:,[2,0]]]); e = np.unique(np.concatenate([e,e[:,::-1]]),axis=0)
                size = int(weld.max())+1
                adj = coo_matrix((np.ones(len(e)),(e[:,0],e[:,1])),shape=(size,size)).tocsr()
                adj = diags(1/np.maximum(np.asarray(adj.sum(axis=1)).ravel(),1))@adj
                welded = np.zeros((size,24),np.float32); np.add.at(welded,weld,allw)
                counts = np.bincount(weld); welded/=counts[:,None]
                original = welded.copy()
                for _ in range(smooth):welded=0.2*original+0.8*(adj@welded)
                allw=welded[weld]
            ji=np.argsort(allw,axis=1)[:,-4:][:,::-1].astype('u1');w=np.take_along_axis(allw,ji,axis=1);w/=w.sum(axis=1,keepdims=True)
            assert np.isfinite(w).all() and np.max(np.abs(w.sum(axis=1)-1))<1e-5
            attrs={'POSITION':add(pos.astype('<f4'),'VEC3',5126,34962,True),'NORMAL':add(normal.astype('<f4'),'VEC3',5126,34962),'JOINTS_0':add(ji,'VEC4',5121,34962),'WEIGHTS_0':add(w.astype('<f4'),'VEC4',5126,34962)}
            if 'TEXCOORD_0' in at:attrs['TEXCOORD_0']=add(accessor(fox,fb,at['TEXCOORD_0']),'VEC2',5126,34962)
            triangles=accessor(fox,fb,prim['indices']).reshape(-1,3)
            centers=pos[triangles].mean(axis=1);mask=(centers[:,1]>1.57)&(centers[:,2]>0.10)&(np.abs(centers[:,0])<0.18) if n['mesh']==0 else np.zeros(len(triangles),bool)
            for select,mat in ((~mask,prim['material']),(mask,2)):
                if select.any():out['meshes'][0]['primitives'].append({'attributes':attrs,'indices':add(triangles[select].astype('<u2').reshape(-1,1),'SCALAR',5123,34963),'material':mat})
            print(n['name'],'triangles',len(triangles),'vertices',len(pos),'face mask triangles',int(mask.sum()),'weight sum max error',float(np.max(np.abs(w.sum(axis=1)-1))),'transfer nearest p95 m',float(np.percentile(d[:,0],95)))
    while len(blob)%4:blob.append(0)
    out['buffers']=[{'byteLength':len(blob)}];js=json.dumps(out,separators=(',',':')).encode();js+=b' '*((-len(js))%4)
    data=struct.pack('<III',0x46546c67,2,28+len(js)+len(blob))+struct.pack('<II',len(js),0x4e4f534a)+js+struct.pack('<II',len(blob),0x004e4942)+blob
    Path(output).write_bytes(data);print('Candidate bytes',len(data))

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('source');parser.add_argument('rig');parser.add_argument('output');parser.add_argument('--smooth',type=int,default=12);a=parser.parse_args();build(a.source,a.rig,a.output,a.smooth)
