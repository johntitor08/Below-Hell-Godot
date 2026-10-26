"""Flatten a Unity scene/prefab with nested prefab instances into one object space."""
import copy
import re
import uy

MASK = 0x7FFFFFFFFFFFFFFF
_cache = {}
IDX = re.compile(r"^data\[(\d+)\]$")


class Obj:
    __slots__ = ("type", "data", "fid")

    def __init__(self, type_, data, fid):
        self.type = type_
        self.data = data
        self.fid = fid


def _remap(value, p):
    if isinstance(value, dict):
        if "fileID" in value and len(value) <= 3 and not value.get("guid"):
            fid = int(value["fileID"])
            return {"fileID": (p ^ fid) & MASK if fid else 0}
        return {k: _remap(v, p) for k, v in value.items()}
    if isinstance(value, list):
        return [_remap(v, p) for v in value]
    return value


def _coerce(old, s):
    if isinstance(old, bool):
        return s not in ("0", "false", "False", "")
    if isinstance(old, int):
        try:
            return int(s)
        except (TypeError, ValueError):
            try:
                return float(s)
            except (TypeError, ValueError):
                return s
    if isinstance(old, float):
        try:
            return float(s)
        except (TypeError, ValueError):
            return s
    if old is None and isinstance(s, str):
        try:
            return int(s)
        except ValueError:
            try:
                return float(s)
            except ValueError:
                return s
    return s


def _apply(data, path, value, objref):
    parts = path.split(".")
    cur = data
    i = 0
    while i < len(parts):
        part = parts[i]
        last = i == len(parts) - 1
        if part == "Array":
            nxt = parts[i + 1]
            if not isinstance(cur, list):
                return
            if nxt == "size":
                n = int(value)
                while len(cur) < n:
                    cur.append(copy.deepcopy(cur[-1]) if cur else None)
                del cur[n:]
                return
            m = IDX.match(nxt)
            idx = int(m.group(1))
            while len(cur) <= idx:
                cur.append(None)
            if i + 1 == len(parts) - 1:
                old = cur[idx]
                cur[idx] = _value(old, value, objref)
                return
            if cur[idx] is None:
                cur[idx] = {}
            cur = cur[idx]
            i += 2
            continue
        if last:
            if isinstance(cur, dict):
                cur[part] = _value(cur.get(part), value, objref)
            return
        if not isinstance(cur, dict):
            return
        if part not in cur or cur[part] is None:
            cur[part] = [] if parts[i + 1] == "Array" else {}
        cur = cur[part]
        i += 1


def _value(old, value, objref):
    ref = objref if isinstance(objref, dict) else None
    if ref and int(ref.get("fileID", 0)) != 0:
        return dict(ref)
    if isinstance(old, dict) and "fileID" in old:
        return {"fileID": 0}
    return _coerce(old, value)


def expand(path):
    """Return dict id -> Obj for every object of the file, nested prefabs included."""
    if path in _cache:
        return _cache[path]
    docs = uy.load(path)
    out = {}
    instances = []
    for fid, d in docs.items():
        if d.type == "PrefabInstance":
            instances.append(d)
        elif not d.stripped:
            out[fid] = Obj(d.type, copy.deepcopy(d.data), fid)
    for pi in instances:
        p = pi.fid
        src_ref = pi.data.get("m_SourcePrefab", {})
        src_path = uy.guid_path(src_ref.get("guid"))
        if not src_path:
            continue
        src = expand(src_path)
        mod = pi.data.get("m_Modification", {}) or {}
        removed_comp = {(p ^ int(r["fileID"])) & MASK for r in (mod.get("m_RemovedComponents") or []) if r and r.get("fileID")}
        removed_go = {(p ^ int(r["fileID"])) & MASK for r in (mod.get("m_RemovedGameObjects") or []) if r and r.get("fileID")}
        local = {}
        for sid, o in src.items():
            nid = (p ^ sid) & MASK
            if nid in removed_comp or nid in removed_go:
                continue
            local[nid] = Obj(o.type, _remap(o.data, p), nid)
        if removed_go:
            _drop_removed(local, removed_go)
        for m in mod.get("m_Modifications") or []:
            t = m.get("target") or {}
            tid = (p ^ int(t.get("fileID", 0))) & MASK
            o = local.get(tid)
            if o is None:
                continue
            _apply(o.data, m.get("propertyPath", ""), m.get("value"), m.get("objectReference"))
        parent = mod.get("m_TransformParent") or {}
        pfid = int(parent.get("fileID", 0))
        for o in local.values():
            if o.type in ("Transform", "RectTransform") and int((o.data.get("m_Father") or {}).get("fileID", 0)) == 0:
                o.data["m_Father"] = {"fileID": pfid}
                o.data["_prefabRoot"] = src_path
        out.update(local)
    alias = {}
    for sfid, d in docs.items():
        if d.type == "PrefabInstance" or not d.stripped:
            continue
        pi = int((d.data.get("m_PrefabInstance") or {}).get("fileID", 0) or 0)
        src = int((d.data.get("m_CorrespondingSourceObject") or {}).get("fileID", 0) or 0)
        if pi and src:
            t = (pi ^ src) & MASK
            if t != sfid and t in out:
                alias[sfid] = t
    if alias:
        for o in out.values():
            o.data = _alias(o.data, alias)
    _cache[path] = out
    return out


def _alias(value, alias):
    if isinstance(value, dict):
        if "fileID" in value and len(value) <= 3 and not value.get("guid"):
            f = int(value.get("fileID") or 0)
            if f in alias:
                return {"fileID": alias[f]}
            return value
        return {k: _alias(v, alias) for k, v in value.items()}
    if isinstance(value, list):
        return [_alias(v, alias) for v in value]
    return value


def _drop_removed(local, removed_go):
    gone = set(removed_go)
    tf = {}
    for o in local.values():
        if o.type in ("Transform", "RectTransform"):
            tf[fid(o.data.get("m_GameObject"))] = o
    stack = list(gone)
    while stack:
        t = tf.get(stack.pop())
        if not t:
            continue
        for c in t.data.get("m_Children") or []:
            ct = local.get(fid(c))
            if ct:
                g = fid(ct.data.get("m_GameObject"))
                if g not in gone:
                    gone.add(g)
                    stack.append(g)
    dead_t = {tf[g].fid for g in gone if g in tf}
    for k in [k for k, o in local.items() if fid(o.data.get("m_GameObject")) in gone or k in gone]:
        del local[k]
    for o in local.values():
        ch = o.data.get("m_Children")
        if isinstance(ch, list):
            o.data["m_Children"] = [c for c in ch if fid(c) not in dead_t]


def fid(ref):
    if isinstance(ref, dict):
        return int(ref.get("fileID", 0) or 0)
    return 0


class Graph:
    """GameObject hierarchy view over an expanded file."""

    def __init__(self, path):
        self.path = path
        self.objs = expand(path)
        self.go_transform = {}
        self.go_components = {}
        for o in self.objs.values():
            g = fid(o.data.get("m_GameObject"))
            if not g:
                continue
            self.go_components.setdefault(g, []).append(o)
            if o.type in ("Transform", "RectTransform"):
                self.go_transform[g] = o
        self.children = {}
        for g, t in self.go_transform.items():
            f = fid(t.data.get("m_Father"))
            self.children.setdefault(f, []).append(g)
        for f, lst in self.children.items():
            ft = self.objs.get(f)
            order = [fid(c) for c in (ft.data.get("m_Children") or [])] if ft else []
            pos = {tid: i for i, tid in enumerate(order)}
            lst.sort(key=lambda g: (pos.get(self.go_transform[g].fid, 10**9), self.order_hint(g)))

    def order_hint(self, g):
        t = self.go_transform[g]
        return t.data.get("m_RootOrder", 0) or 0

    def roots(self):
        res = []
        for g, t in self.go_transform.items():
            f = fid(t.data.get("m_Father"))
            if f == 0 or f not in self.objs:
                res.append(g)
        roots_doc = [o for o in self.objs.values() if o.type == "SceneRoots"]
        if roots_doc:
            order = [fid(r) for r in roots_doc[0].data.get("m_Roots") or []]
            pos = {tid: i for i, tid in enumerate(order)}
            res.sort(key=lambda g: pos.get(self.go_transform[g].fid, 10**9))
        return res

    def kids(self, g):
        t = self.go_transform.get(g)
        return self.children.get(t.fid, []) if t else []

    def name(self, g):
        o = self.objs.get(g)
        return o.data.get("m_Name", "?") if o else "?"

    def active(self, g):
        o = self.objs.get(g)
        return bool(o.data.get("m_IsActive", 1)) if o else True

    def parent(self, g):
        t = self.go_transform.get(g)
        if not t:
            return None
        f = fid(t.data.get("m_Father"))
        ft = self.objs.get(f)
        return fid(ft.data.get("m_GameObject")) if ft else None

    def go_of(self, oid):
        """Any object id (GO, transform, component) -> owning GameObject id."""
        o = self.objs.get(oid)
        if o is None:
            return None
        if o.type == "GameObject":
            return oid
        return fid(o.data.get("m_GameObject")) or None

    def path_of(self, g):
        names = []
        while g:
            names.append(self.name(g))
            g = self.parent(g)
        return "/".join(reversed(names))

    def comps(self, g, script=None):
        res = []
        for c in self.go_components.get(g, []):
            if c.type == "MonoBehaviour":
                n = uy.script_name(c.data.get("m_Script"))
                if script is None or n == script:
                    res.append((n, c))
            elif script is None or c.type == script:
                res.append((c.type, c))
        return res

    def comp(self, g, script):
        r = self.comps(g, script)
        return r[0][1] if r else None

    def find_script(self, script):
        res = []
        for o in self.objs.values():
            if o.type == "MonoBehaviour" and uy.script_name(o.data.get("m_Script")) == script:
                res.append(o)
        return res
