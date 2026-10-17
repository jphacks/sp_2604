import json,urllib.request,sys
API="https://jphacks-info.notion.site/api/v3/loadCachedPageChunkV2"
seen=set()
def load(pid):
    blocks={};cursor={"stack":[]}
    while True:
        r=urllib.request.Request(API,json.dumps({"page":{"id":pid},"limit":300,"cursor":cursor,"verticalColumns":False}).encode(),{"content-type":"application/json","user-agent":"Mozilla/5.0"})
        d=json.load(urllib.request.urlopen(r))
        for k,v in d["recordMap"].get("block",{}).items():
            v=v.get("value",{}); v=v.get("value",v); blocks[k]=v
        if not d.get("cursors"): break
        cursor=d["cursors"][0] if isinstance(d["cursors"],list) else d["cursors"]
        if not cursor.get("stack"): break
    return blocks
def txt(p):
    out=""
    for seg in p or []:
        s=seg[0]
        for f in (seg[1] if len(seg)>1 else []):
            if f[0]=="a": s=f"[{s}]({f[1]})"
            elif f[0]=="b": s=f"**{s}**"
            elif f[0]=="c": s=f"`{s}`"
        out+=s
    return out
PRE={"header":"# ","sub_header":"## ","sub_sub_header":"### ","bulleted_list":"- ","numbered_list":"1. ","to_do":"- [ ] ","quote":"> ","callout":"> 💡 ","toggle":"- ▸ "}
pages=[]
def render(B,bid,depth,lines):
    b=B.get(bid)
    if not b: return
    t=b.get("type");title=txt(b.get("properties",{}).get("title"))
    ind="  "*depth
    if t=="page" and depth>=0:
        lines.append(f"{ind}- 📄 子ページ: {title}");pages.append(bid);return
    if t=="code": lines.append(ind+"```\n"+title+"\n```")
    elif t=="divider": lines.append("---")
    elif t=="bookmark": lines.append(ind+f"- 🔗 {b.get('properties',{}).get('link',[[ '' ]])[0][0]}")
    elif t=="table_row":
        lines.append(ind+"| "+" | ".join(txt(v) for v in b.get("properties",{}).values())+" |")
    elif title: lines.append(ind+PRE.get(t,"")+title)
    nd=depth+1 if t in("bulleted_list","numbered_list","toggle","to_do") else depth
    for c in b.get("content",[]): render(B,c,nd,lines)
def page(pid,out):
    if pid in seen: return
    seen.add(pid);B=load(pid);root=B[pid]
    lines=[f"# {txt(root['properties'].get('title'))}",""]
    for c in root.get("content",[]): render(B,c,0,lines)
    out.append("\n".join(lines))
out=[];page(sys.argv[1],out)
while pages:
    p=pages.pop(0)
    try: page(p,out)
    except Exception as e: out.append(f"<!-- failed {p}: {e} -->")
print("\n\n---\n\n".join(out))
