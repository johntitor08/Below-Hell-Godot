"""Unity YAML reader: GUID map, documents, prefab instance resolution."""
import os
import re
import json
import yaml

UNITY_ROOT = os.path.expanduser("~/Documents/GitHub/Below-Hell")
ASSETS = os.path.join(UNITY_ROOT, "Assets")
CACHE = os.path.join(os.path.dirname(__file__), ".cache")
HEADER = re.compile(r"^--- !u!(\d+) &(-?\d+)( stripped)?\s*$", re.M)

try:
    Loader = yaml.CSafeLoader
except AttributeError:
    Loader = yaml.SafeLoader


def _scan_guids():
    guids = {}
    roots = [ASSETS, os.path.join(UNITY_ROOT, "Packages"), os.path.join(UNITY_ROOT, "Library", "PackageCache")]
    for root, dirs, files in (w for r in roots if os.path.isdir(r) for w in os.walk(r)):
        for f in files:
            if not f.endswith(".meta"):
                continue
            p = os.path.join(root, f)
            with open(p, encoding="utf-8", errors="replace") as fh:
                for line in fh:
                    if line.startswith("guid:"):
                        guids[line.split()[1]] = os.path.relpath(p[:-5], UNITY_ROOT)
                        break
    return guids


_guids = None


def guid_map():
    global _guids
    if _guids is None:
        os.makedirs(CACHE, exist_ok=True)
        cp = os.path.join(CACHE, "guids.json")
        if os.path.exists(cp):
            with open(cp) as fh:
                _guids = json.load(fh)
        else:
            _guids = _scan_guids()
            with open(cp, "w") as fh:
                json.dump(_guids, fh)
    return _guids


def guid_path(guid):
    return guid_map().get(guid)


_path_guid = None


def path_guid(path):
    global _path_guid
    if _path_guid is None:
        _path_guid = {v: k for k, v in guid_map().items()}
    return _path_guid.get(path)


_PLAIN = re.compile(r"^(\s*(?:- )?[A-Za-z_][A-Za-z0-9_]*: )([^\s{\['\"|>&*!%@`].*)$")


def _lenient(body):
    out = []
    for line in body.split("\n"):
        m = _PLAIN.match(line)
        if m and (": " in m.group(2) or " #" in m.group(2)):
            line = m.group(1) + "'" + m.group(2).replace("'", "''") + "'"
        out.append(line)
    return "\n".join(out)


class Doc:
    __slots__ = ("cls", "fid", "stripped", "type", "data")

    def __init__(self, cls, fid, stripped, type_, data):
        self.cls = cls
        self.fid = fid
        self.stripped = stripped
        self.type = type_
        self.data = data

    def __repr__(self):
        return f"<{self.type} {self.fid}>"


_file_cache = {}
INT_ARRAY_KEYS = ("visibleOnBackgrounds", "itemRewardQuantities", "startingItemQty")
SCALAR_TEXT_RE = re.compile(r"^(\s*(?:m_text|m_Name|m_TagString|m_Text|text|placeholderText): )(-?[0-9][0-9.eE+-]*|true|false|null|yes|no|on|off|True|False|Yes|No|On|Off|~)\s*$", re.M)
INT_ARRAY_RE = re.compile(r"^(\s*(?:%s): )([0-9a-fA-F]*)\s*$" % "|".join(INT_ARRAY_KEYS), re.M)


def _decode_int_arrays(v):
    if isinstance(v, dict):
        for k in list(v):
            if k in INT_ARRAY_KEYS and (isinstance(v[k], str) or v[k] is None):
                h = v[k] or ""
                v[k] = [int.from_bytes(bytes.fromhex(h[i:i + 8]), "little", signed=True) for i in range(0, len(h) - len(h) % 8, 8)]
            else:
                _decode_int_arrays(v[k])
    elif isinstance(v, list):
        for x in v:
            _decode_int_arrays(x)


def load(path):
    """Return dict fileID -> Doc for a Unity YAML file (path relative to UNITY_ROOT or absolute)."""
    full = path if os.path.isabs(path) else os.path.join(UNITY_ROOT, path)
    if full in _file_cache:
        return _file_cache[full]
    with open(full, encoding="utf-8") as fh:
        text = fh.read()
    docs = {}
    heads = list(HEADER.finditer(text))
    for i, m in enumerate(heads):
        end = heads[i + 1].start() if i + 1 < len(heads) else len(text)
        body = INT_ARRAY_RE.sub(r'\1"\2"', text[m.end():end])
        body = SCALAR_TEXT_RE.sub(r'\1"\2"', body)
        try:
            data = yaml.load(body, Loader=Loader)
        except yaml.YAMLError:
            try:
                data = yaml.load(_lenient(body), Loader=Loader)
            except yaml.YAMLError as e:
                raise RuntimeError(f"{path} doc {m.group(2)}: {e}")
        if not isinstance(data, dict) or not data:
            continue
        _decode_int_arrays(data)
        type_ = next(iter(data))
        docs[int(m.group(2))] = Doc(int(m.group(1)), int(m.group(2)), bool(m.group(3)), type_, data[type_] or {})
    _file_cache[full] = docs
    return docs


def load_asset(path):
    """Single ScriptableObject asset -> its MonoBehaviour data."""
    for d in load(path).values():
        if d.type == "MonoBehaviour":
            return d.data
    return None


_meta_cache = {}


def meta(path):
    full = (path if os.path.isabs(path) else os.path.join(UNITY_ROOT, path)) + ".meta"
    if full not in _meta_cache:
        with open(full, encoding="utf-8") as fh:
            _meta_cache[full] = yaml.load(fh.read(), Loader=Loader)
    return _meta_cache[full]


def script_name(ref):
    """m_Script reference -> class name (file stem) or built-in UI class."""
    if not ref or not ref.get("guid"):
        return None
    p = guid_path(ref["guid"])
    if p:
        return os.path.splitext(os.path.basename(p))[0]
    return BUILTIN_SCRIPTS.get(ref["guid"], "guid:" + ref["guid"])


BUILTIN_SCRIPTS = {
    "fe87c0e1cc204ed48ad3b37840f39efc": "Image",
    "1344c3c82d62a2a41a3576d8abb8e3ea": "RawImage",
    "4e29b1a8efbd4b44bb3f3716e73f07ff": "Button",
    "5f7201a12d95ffc409449d95f23cf332": "Text",
    "f4688fdb7df04437aeb418b961361dc5": "TextMeshProUGUI",
    "9541d86e2fd84c1d9990edf0852d74ab": "TextMeshPro",
    "2a4db7a114972834c8e4117be1d82ba3": "Scrollbar",
    "2da0c512f12947e489f739169773d7ca": "TMP_InputField",
    "56666c5a40171f54783dd416a44f42bf": "Physics2DRaycaster",
    "a79441f348de89743a2939f4d699eac1": "UniversalAdditionalCameraData",
    "073797afb82c5a1438f328866b10b3f0": "Light2D",
    "7b743370ac3e4ec2a1668f5455a8ef8a": "TMP_Dropdown",
    "59f8146938fff824cb5fd77236b75775": "VerticalLayoutGroup",
    "30649d3a9faa99c48a7b1166b86bf2a0": "HorizontalLayoutGroup",
    "8a8695521f0d02e499659fee002a26c2": "GridLayoutGroup",
    "3245ec927659c4140ac4f8d17403cc18": "ContentSizeFitter",
    "306cc8c2b49d7114eaa3623786fc2126": "LayoutElement",
    "1aa08ab6e0800fa44ae55d278d1423e3": "ScrollRect",
    "31a19414c41e5ae4aae2af33fee712f6": "Mask",
    "3312d7739989d2b4e91e6319e9a96d76": "RectMask2D",
    "0cd44c1031e13a943bb63640046fad76": "CanvasScaler",
    "dc42784cf147c0c48a680349fa168899": "GraphicRaycaster",
    "67db9e8f0e2ae9c40bc1e2b64352a6b4": "Slider",
    "2a4db7a114972834c8e4117be1d82ba3x": "InputField",
    "9085046f02f69544eb97fd06b6048fe2": "Toggle",
    "2fafe2cfe61f6974895a912c3755e8f1": "ToggleGroup",
    "e19747de3f5aca642ab2be37e372fb86": "Outline",
    "cfabb0440166ab443bba8876756fdfa9": "Shadow",
    "f70555f144d8491a825f0804e09c671c": "TMP_SubMeshUI",
    "4f231c4fb786f3946a6b90b886c48677": "EventSystem",
    "76c392e42b5098c458856cdf6ecaaaa1": "EventSystem",
    "01614664b831546d2ae94a42149d80ac": "InputSystemUIInputModule",
    "8233d90336aea43098adf6dbabd606a2": "CanvasGroupX",
    "90539df1cd5704abcb25fec9f3f5f84b": "SpriteShapeController",
}


def ref_key(ref):
    """Normalize an object reference dict -> (fileID, guid|None) or None."""
    if not isinstance(ref, dict) or "fileID" not in ref:
        return None
    fid = int(ref["fileID"])
    if fid == 0:
        return None
    return fid, ref.get("guid")


def sprite_for(ref):
    """Sprite/Texture reference -> (png path, sprite name or None)."""
    k = ref_key(ref)
    if not k or not k[1]:
        return None
    p = guid_path(k[1])
    if not p:
        return None
    ext = os.path.splitext(p)[1].lower()
    if ext not in (".png", ".jpg", ".jpeg", ".psd", ".tga"):
        return (p, None)
    if k[0] in (21300000, 2800000):
        return (p, None)
    m = meta(p)
    ti = m.get("TextureImporter", {})
    for e in (ti.get("spriteSheet", {}) or {}).get("sprites", []) or []:
        if int(e.get("internalID", 0)) == k[0]:
            return (p, e.get("name"))
    table = ti.get("internalIDToNameTable") or []
    for e in table:
        first = e.get("first", {})
        if int(next(iter(first.values()), 0)) == k[0]:
            return (p, e.get("second"))
    nft = ti.get("nameFileIdTable") or {}
    for name, fid in nft.items():
        if int(fid) == k[0]:
            return (p, name)
    return (p, None)


def sprite_sheet_rect(png, name):
    m = meta(png)
    ti = m.get("TextureImporter", {})
    for e in (ti.get("spriteSheet", {}) or {}).get("sprites", []) or []:
        if e.get("name") == name:
            return e.get("rect"), e.get("border"), e.get("pivot")
    return None, None, None


def sprite_border(png):
    ti = meta(png).get("TextureImporter", {})
    b = (ti.get("spriteBorder") or {})
    return [b.get("x", 0), b.get("y", 0), b.get("z", 0), b.get("w", 0)]


def sprite_ppu(png):
    ti = meta(png).get("TextureImporter", {})
    return ti.get("spritePixelsToUnits", 100)
