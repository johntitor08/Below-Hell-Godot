import glob
import json
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CS_ROOT = os.path.expanduser("~/Documents/GitHub/Below-Hell/Assets/Script")
SO_DIR = os.path.join(ROOT, "scripts", "so")
GEN_DIR = os.path.join(SO_DIR, "gen")
ENUM_DIR = os.path.join(ROOT, "scripts", "game", "enums")
RESERVED = {"name", "d", "guid", "asset_path", "script", "get", "set", "free", "notification"}

CLASS_RE = re.compile(r"\bclass\s+(\w+)\s*(?::\s*([\w\.]+))?[^{]*\{")
FIELD_RE = re.compile(
    r"^\s*(?:\[[^\]]*\]\s*)*public\s+(?!static|const|event|override|abstract|virtual|readonly|class|enum|struct)"
    r"([\w<>\[\],\.\s]+?)\s+(\w+)\s*(?:=\s*([^;]+))?;",
    re.M,
)
SER_RE = re.compile(r"\[SerializeField\][^;\n]*?private\s+([\w<>\[\],\.]+)\s+(\w+)\s*(?:=\s*([^;]+))?;")


def enum_members():
    out = {}
    for p in glob.glob(os.path.join(ENUM_DIR, "*.gd")):
        txt = open(p).read()
        m = re.search(r"enum\s*\{([^}]*)\}", txt)
        if m:
            out[os.path.basename(p)[:-3]] = {x.strip() for x in m.group(1).split(",") if x.strip()}
    return out


ENUMS = enum_members()


def class_bodies():
    res = {}
    for p in glob.glob(os.path.join(CS_ROOT, "**", "*.cs"), recursive=True):
        txt = open(p, encoding="utf-8-sig", errors="replace").read()
        for m in CLASS_RE.finditer(txt):
            start = m.end()
            depth = 1
            i = start
            while i < len(txt) and depth:
                if txt[i] == "{":
                    depth += 1
                elif txt[i] == "}":
                    depth -= 1
                i += 1
            body = txt[start:i - 1]
            flat = []
            depth = 0
            for ch in body:
                if ch == "{":
                    depth += 1
                elif ch == "}":
                    depth -= 1
                elif depth == 0:
                    flat.append(ch)
            res.setdefault(m.group(1), (m.group(2), "".join(flat)))
    return res


def gd_default(typ, val):
    typ = typ.strip()
    if val is not None:
        v = val.strip()
        if re.fullmatch(r"-?\d+(\.\d+)?f?", v):
            v = v.rstrip("f")
            return v if typ in ("int", "long") or "." in v else (v + ".0" if typ in ("float", "double") else v)
        if v in ("true", "false"):
            return v
        if re.fullmatch(r'"(?:[^"\\]|\\.)*"', v):
            return v
        m = re.fullmatch(r"(\w+)\.(\w+)", v)
        if m and m.group(1) in ENUMS and m.group(2) in ENUMS[m.group(1)]:
            return v
        if m and m.group(1) == "Color":
            return {"white": "Color.WHITE", "black": "Color.BLACK", "clear": "Color(0, 0, 0, 0)", "gray": "Color(0.5, 0.5, 0.5, 1)", "red": "Color.RED"}.get(m.group(2), "null")
        m = re.fullmatch(r"new\s*(?:Color)?\s*\(([^)]*)\)", v)
        if m and typ == "Color":
            parts = [p.strip().rstrip("f") for p in m.group(1).split(",")]
            if len(parts) == 3:
                parts.append("1")
            return "Color(%s)" % ", ".join(parts)
        if m and typ in ("Vector2", "Vector2Int"):
            parts = [p.strip().rstrip("f") for p in m.group(1).split(",")]
            return "Vector2(%s)" % ", ".join(parts)
        if v.startswith("new") and (typ.startswith("List") or typ.endswith("[]") or "HashSet" in typ):
            return "[]"
    if typ == "string":
        return '""'
    if typ in ("int", "long"):
        return "0"
    if typ in ("float", "double"):
        return "0.0"
    if typ == "bool":
        return "false"
    if typ.endswith("[]") or typ.startswith("List"):
        return "[]"
    if typ in ENUMS:
        return "0"
    return "null"


def own_fields(bodies, cls):
    if cls not in bodies:
        return {}
    _, body = bodies[cls]
    out = {}
    for m in FIELD_RE.finditer(body):
        typ, name, val = m.group(1), m.group(2), m.group(3)
        if "(" in typ or "=>" in (val or ""):
            continue
        out[name] = gd_default(typ, val)
    for m in SER_RE.finditer(body):
        out.setdefault(m.group(2), gd_default(m.group(1), m.group(3)))
    return out


def declared_names(gd_text):
    return set(re.findall(r"^(?:static\s+)?(?:var|func|const)\s+(\w+)", gd_text, re.M))


def main():
    bodies = class_bodies()
    data = json.load(open(os.path.join(ROOT, "data", "so.json")))
    keys_by_class = {}
    for e in data.values():
        keys_by_class.setdefault(e["class"], set()).update(e.get("d", {}).keys())
    os.makedirs(GEN_DIR, exist_ok=True)
    for p in sorted(glob.glob(os.path.join(SO_DIR, "*.gd"))):
        cls = os.path.basename(p)[:-3]
        txt = open(p).read()
        m = re.search(r"^extends\s+(\w+)", txt, re.M)
        if not m:
            continue
        parent = m.group(1)
        if parent == cls + "Fields":
            parent = re.search(r"^extends\s+(\w+)", open(os.path.join(GEN_DIR, cls + "Fields.gd")).read(), re.M).group(1)
        anc = set()
        c = bodies.get(cls, (None, ""))[0]
        while c and c in bodies:
            anc |= set(own_fields(bodies, c).keys())
            c = bodies[c][0]
        fields = own_fields(bodies, cls)
        for k in sorted(keys_by_class.get(cls, set())):
            if k not in fields and k not in anc:
                fields[k] = "null"
        skip = declared_names(txt) | RESERVED
        lines = ["class_name %sFields" % cls, "extends %s" % parent, ""]
        for name, dv in fields.items():
            if name in skip or name.startswith("$") or name.startswith("m_"):
                continue
            lines += [
                "var %s:" % name,
                "\tget:",
                "\t\treturn d.get(\"%s\", %s)" % (name, dv),
                "\tset(v):",
                "\t\td[\"%s\"] = v" % name,
                "",
            ]
        open(os.path.join(GEN_DIR, cls + "Fields.gd"), "w").write("\n".join(lines).rstrip() + "\n")
        new_txt = re.sub(r"^extends\s+\w+", "extends %sFields" % cls, txt, count=1, flags=re.M)
        if new_txt != txt:
            open(p, "w").write(new_txt)
        print(cls, parent, len(fields))


main()
