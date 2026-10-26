"""Unity project -> Godot project converter for Below Hell."""
import glob
import json
import math
import os
import re
import shutil
import sys

import uy
import expand

OUT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
GAME_SCRIPTS = os.path.join(OUT, "scripts", "game")
SCRIPT_RENAMES = {}
SCRIPT_DIRS = ("game", "minigame", "net")
U_SCRIPTS = "res://scripts/u"
PPU = 100.0
ASSET_EXT_COPY = {".png", ".jpg", ".jpeg", ".mp3", ".wav", ".ogg", ".ttf", ".otf"}
SKIP_COMPONENTS = {"CanvasRenderer", "GraphicRaycaster", "CanvasScaler", "EventSystem", "StandaloneInputModule",
                   "InputSystemUIInputModule", "SpriteShapeRenderer", "AudioListener",
                   "Transform", "RectTransform", "Canvas", "TMP_SubMeshUI", "Physics2DRaycaster",
                   "UniversalAdditionalCameraData", "Light2D", "Rigidbody2D", "TilemapRenderer", "MeshFilter", "MeshRenderer",
                   "CinemachinePipeline", "CinemachineComposer", "CinemachineTransposer", "CinemachineFramingTransposer",
                   "UnityTransport", "IKManager2D", "LimbSolver2D", "SortingGroup", "ParticleSystemRenderer"}
COLLIDERS = {"BoxCollider2D", "CircleCollider2D", "CapsuleCollider2D", "PolygonCollider2D", "EdgeCollider2D",
             "CompositeCollider2D", "TilemapCollider2D"}
BUILTIN_SCRIPTED = {
    "Button": "UButton", "Toggle": "UToggle", "Slider": "USlider", "Scrollbar": "UScrollbar", "ScrollRect": "UScrollRect",
    "TMP_InputField": "UInputField", "TMP_Dropdown": "UDropdown", "VerticalLayoutGroup": "ULayoutGroup",
    "HorizontalLayoutGroup": "ULayoutGroup", "GridLayoutGroup": "UGridLayout", "ContentSizeFitter": "UContentSizeFitter",
    "LayoutElement": "ULayoutElement", "CanvasGroup": "UCanvasGroup", "Mask": "UMask", "RectMask2D": "UMask",
    "Animator": "UAnimator", "AudioSource": "UAudioSource", "ToggleGroup": "UToggleGroup", "Outline": "UOutline",
    "AspectRatioFitter": "UAspectRatioFitter",
    "SpriteRenderer": "USpriteRenderer", "BoxCollider2D": "UCollider2D", "CircleCollider2D": "UCollider2D",
    "CapsuleCollider2D": "UCollider2D", "PolygonCollider2D": "UCollider2D", "EdgeCollider2D": "UCollider2D",
    "CompositeCollider2D": "UCollider2D", "TilemapCollider2D": "UCollider2D", "Camera": "UCamera",
    "Tilemap": "UTilemap", "Grid": "UGrid", "LineRenderer": "ULineRenderer", "PlatformEffector2D": "UEffector2D",
    "BuoyancyEffector2D": "UEffector2D", "NetworkObject": "UNetworkObject", "NetworkManager": "UNetworkManager",
    "NetworkTransform": "UNetworkTransform", "NetworkRigidbody2D": "UNetworkRigidbody2D",
    "NetworkAnimator": "UNetworkAnimator", "CinemachineVirtualCamera": "UVirtualCamera",
    "CinemachineBrain": "UCinemachineBrain", "EventTrigger": "UEventTrigger", "SpriteSkin": "USpriteSkin",
    "ParticleSystem": "UParticleSystem", "TrailRenderer": "UTrailRenderer",
}
GRAPHIC = {"Image", "RawImage", "TextMeshProUGUI", "Text"}

used_media = set()
TMP_DEFAULT_FONT = "34a4a0c89db9414489be1315c76bc9f1"
sprite_meta = {}
missing_scripts = {}
fonts = {}


def res_path(unity_rel):
    return "res://" + unity_rel


def media_ref(path):
    used_media.add(path)
    return res_path(path)


def font_ref(guid):
    if guid in fonts:
        return fonts[guid]
    p = uy.guid_path(guid)
    out = None
    if p and p.endswith(".asset"):
        try:
            d = uy.load_asset(p)
        except Exception:
            d = None
        if d is not None:
            src = d.get("m_SourceFontFile") or {}
            ttf = uy.guid_path(src.get("guid")) if src.get("guid") else None
            if not ttf and d.get("m_SourceFontFileGUID"):
                ttf = uy.guid_path(str(d.get("m_SourceFontFileGUID")))
            fb = []
            for e in d.get("m_FallbackFontAssetTable") or []:
                if e and e.get("guid"):
                    r = font_ref(e["guid"])
                    if r:
                        fb.append(r["ttf"])
            if ttf:
                out = {"ttf": media_ref(ttf), "fallbacks": fb, "name": os.path.basename(p)}
    elif p and os.path.splitext(p)[1].lower() in (".ttf", ".otf"):
        out = {"ttf": media_ref(p), "fallbacks": [], "name": os.path.basename(p)}
    fonts[guid] = out
    return out


def sprite_ref(ref):
    sp = uy.sprite_for(ref)
    if not sp:
        return None
    png, sub = sp
    ext = os.path.splitext(png)[1].lower()
    if ext not in (".png", ".jpg", ".jpeg"):
        return None
    key = png + ("#" + sub if sub else "")
    if key not in sprite_meta:
        meta = {"tex": media_ref(png), "name": sub or os.path.splitext(os.path.basename(png))[0]}
        ti = uy.meta(png).get("TextureImporter", {})
        meta["ppu"] = ti.get("spritePixelsToUnits", 100)
        meta["filter"] = (ti.get("textureSettings") or {}).get("filterMode", 1)
        if sub:
            rect, border, pivot = uy.sprite_sheet_rect(png, sub)
            ent = uy.sprite_sheet_entry(png, sub) or {}
            if rect:
                meta["rect"] = [rect["x"], rect["y"], rect["width"], rect["height"]]
            if border:
                meta["border"] = [border.get("x", 0), border.get("y", 0), border.get("z", 0), border.get("w", 0)]
            meta["pivot"] = align_pivot(ent.get("alignment", 0), pivot)
        else:
            b = ti.get("spriteBorder") or {}
            meta["border"] = [b.get("x", 0), b.get("y", 0), b.get("z", 0), b.get("w", 0)]
            meta["pivot"] = align_pivot(ti.get("spriteAlignment", 0), ti.get("spritePivot"))
        sprite_meta[key] = meta
    return {"$spr": key}


ALIGN = {0: (0.5, 0.5), 1: (0, 1), 2: (0.5, 1), 3: (1, 1), 4: (0, 0.5), 5: (1, 0.5), 6: (0, 0), 7: (0.5, 0), 8: (1, 0)}


def align_pivot(alignment, pivot):
    if alignment in ALIGN:
        return list(ALIGN[alignment])
    pivot = pivot or {}
    return [pivot.get("x", 0.5), pivot.get("y", 0.5)]


class SceneConv:
    """Converts one expanded Unity file (scene or prefab) into a Godot node tree."""

    def __init__(self, path, is_prefab):
        self.path = path
        self.is_prefab = is_prefab
        self.g = expand.Graph(path)
        self.node_path = {}
        self.comp_path = {}
        self.nodes = []
        self.ext = {}

    def script_res(self, script, builtin=False):
        script = SCRIPT_RENAMES.get(script, script)
        if builtin:
            return f"{U_SCRIPTS}/{script}.gd"
        for sub in SCRIPT_DIRS:
            p = os.path.join(os.path.dirname(GAME_SCRIPTS), sub, script + ".gd")
            if os.path.exists(p):
                return f"res://scripts/{sub}/{script}.gd"
        missing_scripts[script] = missing_scripts.get(script, 0) + 1
        return None

    def ext_id(self, path, type_):
        if path not in self.ext:
            self.ext[path] = (type_, f"{len(self.ext) + 1}")
        return self.ext[path][1]

    @staticmethod
    def clean_name(n, used):
        n = re.sub(r'[.:@/"%]', "_", n or "GameObject").strip() or "GameObject"
        base = n
        i = 2
        while n in used:
            n = f"{base}_{i}"
            i += 1
        used.add(n)
        return n

    def build(self):
        g = self.g
        roots = g.roots()
        if self.is_prefab:
            roots = [r for r in roots if g.parent(r) is None][:1]
        used_root = set()
        self.root_name = os.path.splitext(os.path.basename(self.path))[0]
        self.root_name = re.sub(r'[.:@/"%]', "_", self.root_name)
        tree = []
        if self.is_prefab:
            go = roots[0]
            self._assign(go, ".", None, set())
            tree.append(go)
        else:
            for go in roots:
                canvas = g.comp(go, "Canvas")
                name = self.clean_name(g.name(go), used_root)
                if canvas is not None and self.is_ui(go):
                    self.node_path[go] = f"{name}/{name}"
                    self._assign_children(go, f"{name}/{name}")
                else:
                    self.node_path[go] = name
                    self._assign_children(go, name)
                tree.append(go)
        self.tree_roots = tree

    def _assign(self, go, path, parent_path, used):
        self.node_path[go] = path
        self._assign_children(go, path)

    def _assign_children(self, go, path):
        used = set()
        comps_used = set()
        for name, c in self.g.comps(go):
            if self.comp_kind(name) is None:
                continue
            cn = self.clean_name("C_" + self.comp_kind_name(name), comps_used | used)
            comps_used.add(cn)
            used.add(cn)
            self.comp_path[c.fid] = (path + "/" + cn) if path != "." else cn
        for k in self.kids(go):
            n = self.clean_name(self.g.name(k), used)
            self._assign(k, (path + "/" + n) if path != "." else n, path, set())

    def kids(self, go):
        return [k for k in self.g.kids(go) if not self.skip_go(k)]

    def skip_go(self, go):
        names = {n for n, _ in self.g.comps(go)}
        if "MeshFilter" in names and "MeshRenderer" in names:
            return True
        if "CinemachinePipeline" in names:
            return True
        return False

    def comp_kind(self, name):
        if name in SKIP_COMPONENTS or name in GRAPHIC or name is None:
            return None
        if name.startswith("guid:"):
            return None
        if name in BUILTIN_SCRIPTED:
            return "builtin"
        if name in ("SpriteShapeController",):
            return None
        return "game"

    def comp_kind_name(self, name):
        return name

    def is_ui(self, go):
        t = self.g.go_transform.get(go)
        return t is not None and t.type == "RectTransform"

    # ---------- reference conversion ----------
    def conv_ref(self, ref):
        k = uy.ref_key(ref)
        if not k:
            return None
        fid, guid = k
        if not guid:
            o = self.g.objs.get(fid)
            if o is None:
                return None
            if o.type == "GameObject":
                return {"$n": self.node_path.get(fid)} if fid in self.node_path else None
            if o.type in ("RectTransform", "Transform") or (o.type == "MonoBehaviour" and uy.script_name(o.data.get("m_Script")) in GRAPHIC):
                go = self.g.go_of(fid)
                return {"$n": self.node_path.get(go)} if go in self.node_path else None
            if fid in self.comp_path:
                return {"$n": self.comp_path[fid]}
            go = self.g.go_of(fid)
            if go in self.node_path:
                return {"$n": self.node_path[go], "type": o.type}
            return None
        return conv_asset_ref(ref)

    def conv_value(self, v):
        if isinstance(v, dict):
            if "fileID" in v and set(v.keys()) <= {"fileID", "guid", "type"}:
                return self.conv_ref(v)
            if "m_PersistentCalls" in v:
                return self.conv_event(v)
            if set(v.keys()) == {"r", "g", "b", "a"}:
                return {"$c": [v["r"], v["g"], v["b"], v["a"]]}
            return {k: self.conv_value(x) for k, x in v.items() if k not in ("serializedVersion",)}
        if isinstance(v, list):
            return [self.conv_value(x) for x in v]
        return v

    def conv_event(self, ev):
        calls = []
        for c in (ev.get("m_PersistentCalls") or {}).get("m_Calls") or []:
            tgt = self.conv_ref(c.get("m_Target"))
            if tgt is None:
                continue
            args = c.get("m_Arguments") or {}
            mode = c.get("m_Mode", 1)
            arg = None
            if mode == 2:
                arg = self.conv_ref(args.get("m_ObjectArgument"))
            elif mode == 3:
                arg = args.get("m_IntArgument")
            elif mode == 4:
                arg = args.get("m_FloatArgument")
            elif mode == 5:
                arg = args.get("m_StringArgument")
            elif mode == 6:
                arg = bool(args.get("m_BoolArgument"))
            calls.append({"target": tgt, "method": c.get("m_MethodName"), "mode": mode, "arg": arg,
                          "state": c.get("m_CallState", 2)})
        return {"$event": calls}

    def comp_fields(self, c, builtin=False):
        out = {}
        for k, v in c.data.items():
            if k.startswith("m_"):
                if k in ("m_Script", "m_GameObject", "m_ObjectHideFlags", "m_CorrespondingSourceObject",
                         "m_PrefabInstance", "m_PrefabAsset", "m_EditorHideFlags", "m_Name", "m_EditorClassIdentifier"):
                    continue
            out[k] = self.conv_value(v)
        return out

    # ---------- emit ----------
    def rect_props(self, go):
        t = self.g.go_transform.get(go)
        d = t.data if t else {}
        props = {}
        if not t or t.type != "RectTransform":
            return props, {}
        cv = self.g.comp(go, "Canvas")
        if cv is not None and (self.g.parent(go) is None or not cv.data.get("m_OverrideSorting", 0) and self.g.parent(go) is None):
            props.update({"anchor_left": 0.0, "anchor_top": 0.0, "anchor_right": 1.0, "anchor_bottom": 1.0,
                          "offset_left": 0.0, "offset_top": 0.0, "offset_right": 0.0, "offset_bottom": 0.0})
            return props, {"pivot": [0.5, 0.5]}
        amin = d.get("m_AnchorMin") or {"x": 0.5, "y": 0.5}
        amax = d.get("m_AnchorMax") or {"x": 0.5, "y": 0.5}
        ap = d.get("m_AnchoredPosition") or {"x": 0, "y": 0}
        sd = d.get("m_SizeDelta") or {"x": 0, "y": 0}
        pv = d.get("m_Pivot") or {"x": 0.5, "y": 0.5}
        sc = d.get("m_LocalScale") or {"x": 1, "y": 1, "z": 1}
        rot = d.get("m_LocalRotation") or {"x": 0, "y": 0, "z": 0, "w": 1}
        omin = (ap["x"] - sd["x"] * pv["x"], ap["y"] - sd["y"] * pv["y"])
        omax = (ap["x"] + sd["x"] * (1 - pv["x"]), ap["y"] + sd["y"] * (1 - pv["y"]))
        props["anchor_left"] = amin["x"]
        props["anchor_top"] = 1 - amax["y"]
        props["anchor_right"] = amax["x"]
        props["anchor_bottom"] = 1 - amin["y"]
        props["offset_left"] = omin[0]
        props["offset_top"] = -omax[1]
        props["offset_right"] = omax[0]
        props["offset_bottom"] = -omin[1]
        sx, sy = sc.get("x", 1), sc.get("y", 1)
        if abs(sx - 1) > 1e-6 or abs(sy - 1) > 1e-6:
            props["scale"] = ("Vector2", sx, sy)
        z = 2 * math.atan2(rot.get("z", 0), rot.get("w", 1))
        if abs(z) > 1e-5:
            props["rotation"] = -z
        lp = d.get("m_LocalPosition") or {}
        meta = {"pivot": [pv["x"], pv["y"]]}
        if abs(lp.get("z", 0) or 0) > 1e-3:
            meta["z"] = lp.get("z")
        return props, meta

    def go_blob(self, go):
        blob = {}
        g = self.g
        for name, c in g.comps(go):
            d = c.data
            if name == "Image":
                blob["image"] = {
                    "enabled": bool(d.get("m_Enabled", 1)),
                    "sprite": sprite_ref(d.get("m_Sprite")),
                    "color": col(d.get("m_Color")),
                    "type": d.get("m_Type", 0),
                    "preserveAspect": bool(d.get("m_PreserveAspect", 0)),
                    "fillCenter": bool(d.get("m_FillCenter", 1)),
                    "fillMethod": d.get("m_FillMethod", 4),
                    "fillAmount": d.get("m_FillAmount", 1),
                    "fillClockwise": bool(d.get("m_FillClockwise", 1)),
                    "fillOrigin": d.get("m_FillOrigin", 0),
                    "ppum": d.get("m_PixelsPerUnitMultiplier", 1) or 1,
                    "raycastTarget": bool(d.get("m_RaycastTarget", 1)),
                    "maskable": bool(d.get("m_Maskable", 1)),
                    "raycastPadding": vec4(d.get("m_RaycastPadding")),
                }
            elif name == "RawImage":
                tex = d.get("m_Texture")
                tp = uy.guid_path(tex.get("guid")) if tex and tex.get("guid") else None
                blob["image"] = {
                    "enabled": bool(d.get("m_Enabled", 1)), "raw": True,
                    "texture": media_ref(tp) if tp and os.path.splitext(tp)[1].lower() in (".png", ".jpg") else None,
                    "color": col(d.get("m_Color")), "type": 0, "raycastTarget": bool(d.get("m_RaycastTarget", 1)),
                    "uvRect": d.get("m_UVRect"),
                }
            elif name in ("TextMeshProUGUI", "Text"):
                blob["text"] = self.text_blob(name, d)
            elif name == "SpriteShapeController":
                pts = [[p["position"]["x"], p["position"]["y"]] for p in (d.get("m_Spline") or {}).get("m_ControlPoints") or []]
                blob.setdefault("shape", {})["poly"] = pts
            elif name == "SpriteShapeRenderer":
                blob.setdefault("shape", {})["color"] = col(d.get("m_Color"))
                blob["shape"]["order"] = d.get("m_SortingOrder", 0)
            elif name == "Canvas":
                blob["canvas"] = {"order": d.get("m_SortingOrder", 0), "override": bool(d.get("m_OverrideSorting", 0)),
                                  "mode": d.get("m_RenderMode", 0)}
            elif name == "Rigidbody2D":
                blob["rb"] = self.rb_blob(c)
        return blob

    def vcam_body(self, go):
        for k in self.g.kids(go):
            for n, c in self.g.comps(k):
                if n in ("CinemachineTransposer", "CinemachineFramingTransposer", "CinemachineComposer"):
                    return {kk: self.conv_value(v) for kk, v in c.data.items() if not kk.startswith("m_Object") and kk not in ("m_Script", "m_GameObject", "m_EditorClassIdentifier")} | {"$type": n}
        return None

    def text_blob(self, name, d):
        if name == "Text":
            fd = d.get("m_FontData") or {}
            return {"enabled": bool(d.get("m_Enabled", 1)), "text": d.get("m_Text", ""), "color": col(d.get("m_Color")),
                    "fontSize": fd.get("m_FontSize", 14), "align": legacy_align(fd.get("m_Alignment", 0)),
                    "raycastTarget": bool(d.get("m_RaycastTarget", 1)), "font": None, "wrap": True, "rich": True,
                    "autoSize": bool(fd.get("m_BestFit", 0)), "minSize": fd.get("m_MinSize", 10), "maxSize": fd.get("m_MaxSize", 40)}
        fa = d.get("m_fontAsset") or {}
        font = font_ref(fa.get("guid")) if fa.get("guid") else font_ref(TMP_DEFAULT_FONT)
        m = d.get("m_margin") or {}
        return {
            "enabled": bool(d.get("m_Enabled", 1)),
            "text": d.get("m_text", "") if d.get("m_text") is not None else "",
            "color": col(d.get("m_fontColor") or d.get("m_Color")),
            "vertexColor": col(d.get("m_Color")),
            "fontSize": d.get("m_fontSize", 36),
            "autoSize": bool(d.get("m_enableAutoSizing", 0)),
            "minSize": d.get("m_fontSizeMin", 18), "maxSize": d.get("m_fontSizeMax", 72),
            "style": d.get("m_fontStyle", 0),
            "halign": d.get("m_HorizontalAlignment", 1), "valign": d.get("m_VerticalAlignment", 256),
            "wrap": (d.get("m_TextWrappingMode", d.get("m_enableWordWrapping", 1)) or 0) != 0,
            "overflow": d.get("m_overflowMode", 0),
            "margin": [m.get("x", 0), m.get("y", 0), m.get("z", 0), m.get("w", 0)],
            "lineSpacing": d.get("m_lineSpacing", 0), "charSpacing": d.get("m_characterSpacing", 0),
            "wordSpacing": d.get("m_wordSpacing", 0), "paragraphSpacing": d.get("m_paragraphSpacing", 0),
            "raycastTarget": bool(d.get("m_RaycastTarget", 1)),
            "rich": bool(d.get("m_isRichText", 1)),
            "font": font,
        }

    def node_type_for(self, go):
        names = {n for n, _ in self.g.comps(go)}
        if "TextMeshProUGUI" in names or "Text" in names:
            return "Control", f"{U_SCRIPTS}/UText.gd"
        if not self.is_ui(go):
            if "Tilemap" in names:
                return "Node2D", f"{U_SCRIPTS}/UObj.gd"
            if "Rigidbody2D" in names:
                return "RigidBody2D", f"{U_SCRIPTS}/URigidbody2D.gd"
            cols = [c for n, c in self.g.comps(go) if n in COLLIDERS and n != "TilemapCollider2D"]
            if cols and not self.rb_ancestor(go):
                if any(not c.data.get("m_IsTrigger", 0) for c in cols):
                    return "StaticBody2D", f"{U_SCRIPTS}/UStaticBody.gd"
                return "Area2D", f"{U_SCRIPTS}/UArea.gd"
            return "Node2D", f"{U_SCRIPTS}/UObj.gd"
        return "Control", f"{U_SCRIPTS}/UImage.gd"

    def rb_ancestor(self, go):
        p = self.g.parent(go)
        while p:
            if self.g.comp(p, "Rigidbody2D") is not None:
                return True
            p = self.g.parent(p)
        return False

    def world_props(self, go):
        t = self.g.go_transform.get(go)
        if not t or t.type == "RectTransform":
            return {}
        d = t.data
        lp = d.get("m_LocalPosition") or {}
        rot = d.get("m_LocalRotation") or {}
        sc = d.get("m_LocalScale") or {}
        props = {}
        x, y = float(lp.get("x", 0) or 0) * PPU, -float(lp.get("y", 0) or 0) * PPU
        if abs(x) > 1e-6 or abs(y) > 1e-6:
            props["position"] = ("Vector2", x, y)
        qz, qw = float(rot.get("z", 0) or 0), float(rot.get("w", 1) or 1)
        qx, qy = float(rot.get("x", 0) or 0), float(rot.get("y", 0) or 0)
        z = math.atan2(2 * (qw * qz + qx * qy), 1 - 2 * (qy * qy + qz * qz))
        if abs(z) > 1e-6:
            props["rotation"] = -z
        sx, sy = float(sc.get("x", 1) or 0), float(sc.get("y", 1) or 0)
        flip_y = abs(qx) > 0.7 and abs(qy) < 0.1
        flip_x = abs(qy) > 0.7 and abs(qx) < 0.1
        if flip_x:
            sx = -sx
        if flip_y:
            sy = -sy
        if abs(sx - 1) > 1e-6 or abs(sy - 1) > 1e-6:
            props["scale"] = ("Vector2", sx, sy)
        return props

    def rb_blob(self, c):
        d = c.data
        mat = d.get("m_Material") or {}
        return {"bodyType": d.get("m_BodyType", 0), "simulated": bool(d.get("m_Simulated", 1)),
                "mass": d.get("m_Mass", 1), "drag": d.get("m_LinearDamping", d.get("m_LinearDrag", 0)),
                "angularDrag": d.get("m_AngularDamping", d.get("m_AngularDrag", 0.05)),
                "gravityScale": d.get("m_GravityScale", 1), "constraints": d.get("m_Constraints", 0),
                "interpolate": d.get("m_Interpolate", 0), "collisionDetection": d.get("m_CollisionDetection", 0),
                "material": phys_material(mat), "useFullKinematicContacts": bool(d.get("m_UseFullKinematicContacts", 0))}

    def emit(self):
        out = []

        def emit_node(name, type_, parent, props, meta, script=None):
            hdr = f'[node name="{esc(name)}" type="{type_}"'
            if parent is not None:
                hdr += f' parent="{esc(parent)}"'
            hdr += "]"
            body = [hdr]
            if script:
                body.append(f'script = ExtResource("{self.ext_id(script, "Script")}")')
            for k, v in props.items():
                body.append(f"{k} = {gd(v)}")
            for k, v in meta.items():
                body.append(f"metadata/{k} = {gd(v)}")
            out.append("\n".join(body))

        def parent_of(path):
            return path.rsplit("/", 1)[0] if "/" in path else "."

        def emit_comps(go, path):
            for cname, c in self.g.comps(go):
                kind = self.comp_kind(cname)
                if kind is None or c.fid not in self.comp_path:
                    continue
                cpath = self.comp_path[c.fid]
                fields = self.comp_fields(c, kind == "builtin")
                fields["$type"] = cname
                if kind == "builtin":
                    scr = self.script_res(BUILTIN_SCRIPTED[cname], builtin=True)
                    if cname == "Animator":
                        fields["$anim"] = animator_data(c.data)
                    elif cname == "Tilemap":
                        fields = tilemap_data(c.data, self.g.comp(go, "TilemapRenderer"))
                        fields["$type"] = cname
                    elif cname == "CinemachineVirtualCamera":
                        fields["$body"] = self.vcam_body(go)
                    elif cname in COLLIDERS or cname == "Rigidbody2D":
                        fields["$body"] = "self" if self.node_type_for(go)[0] != "Node2D" else "ancestor"
                else:
                    scr = self.script_res(cname)
                emit_node(cpath.rsplit("/", 1)[-1], "Node", parent_of(cpath), {}, {"u": jdump(fields)}, scr)

        def emit_go(go, path, root=False):
            type_, script = self.node_type_for(go)
            props, meta = self.rect_props(go)
            props.update(self.world_props(go))
            props["visible"] = bool(self.g.active(go))
            blob = self.go_blob(go)
            blob["name"] = self.g.name(go)
            go_obj = self.g.objs.get(go)
            if go_obj is not None:
                blob["tag"] = go_obj.data.get("m_TagString", "Untagged")
                blob["layer"] = go_obj.data.get("m_Layer", 0)
            meta["u"] = jdump(blob)
            if type_ == "Control":
                props["mouse_filter"] = 2
            if root:
                emit_node(self.root_name, type_, None, props, meta, script)
            else:
                emit_node(path.rsplit("/", 1)[-1], type_, parent_of(path), props, meta, script)
            emit_comps(go, path)
            for k in self.kids(go):
                emit_go(k, self.node_path[k])

        if self.is_prefab:
            emit_go(self.tree_roots[0], ".", root=True)
        else:
            emit_node(self.root_name, "Node", None, {}, {}, f"{U_SCRIPTS}/UScene.gd")
            for go in self.tree_roots:
                path = self.node_path[go]
                if "/" in path:
                    layer = path.split("/")[0]
                    cv = self.g.comp(go, "Canvas")
                    order = cv.data.get("m_SortingOrder", 0) if cv else 0
                    emit_node(layer, "CanvasLayer", ".", {"layer": max(-128, min(128, order))}, {"unity_order": order})
                emit_go(go, path)

        head = [f"[gd_scene load_steps={len(self.ext) + 1} format=3]", ""]
        for p, (t, i) in self.ext.items():
            head.append(f'[ext_resource type="{t}" path="{esc(p)}" id="{i}"]')
        return "\n".join(head) + "\n\n" + "\n\n".join(out) + "\n"


def jdump(o):
    return json.dumps(o, ensure_ascii=False, separators=(",", ":"))


def animator_data(d):
    ctrl = d.get("m_Controller") or {}
    p = uy.guid_path(ctrl.get("guid")) if ctrl.get("guid") else None
    if not p:
        return None
    docs = uy.load(p)
    states = {}
    trans = []
    default = None
    params = []
    for o in docs.values():
        if o.type == "AnimatorController":
            for pr in o.data.get("m_AnimatorParameters") or []:
                params.append(pr.get("m_Name"))
        if o.type == "AnimatorStateMachine":
            ds = o.data.get("m_DefaultState") or {}
            default = int(ds.get("fileID", 0))
            for t in o.data.get("m_AnyStateTransitions") or []:
                trans.append(("any", int(t["fileID"])))
    for fid, o in docs.items():
        if o.type == "AnimatorState":
            motion = o.data.get("m_Motion") or {}
            clip = uy.guid_path(motion.get("guid")) if motion.get("guid") else None
            states[fid] = {"name": o.data.get("m_Name"), "clip": clip_data(clip) if clip else None,
                           "transitions": [int(t["fileID"]) for t in o.data.get("m_Transitions") or []]}
    tr_out = {}
    for fid, o in docs.items():
        if o.type == "AnimatorStateTransition":
            dst = int((o.data.get("m_DstState") or {}).get("fileID", 0))
            conds = [c.get("m_ConditionEvent") for c in o.data.get("m_Conditions") or []]
            tr_out[fid] = {"to": states.get(dst, {}).get("name"), "conds": conds,
                           "exit": bool(o.data.get("m_HasExitTime", 0)), "exitTime": o.data.get("m_ExitTime", 1),
                           "duration": o.data.get("m_TransitionDuration", 0)}
    out_states = {}
    for fid, s in states.items():
        out_states[s["name"]] = {"clip": s["clip"], "transitions": [tr_out[t] for t in s["transitions"] if t in tr_out]}
    return {"default": states.get(default, {}).get("name"), "states": out_states,
            "any": [tr_out[t] for _, t in trans if t in tr_out], "params": params}


def clip_data(path):
    docs = uy.load(path)
    for o in docs.values():
        if o.type == "AnimationClip":
            curves = []
            for fc in o.data.get("m_FloatCurves") or []:
                keys = [[k["time"], k["value"], k.get("inSlope", 0), k.get("outSlope", 0)] for k in fc["curve"]["m_Curve"]]
                curves.append({"path": fc.get("path") or "", "attr": fc.get("attribute"), "keys": keys})
            st = o.data.get("m_AnimationClipSettings") or {}
            return {"length": st.get("m_StopTime", 1), "loop": bool(st.get("m_LoopTime", 0)), "curves": curves}
    return None


def phys_material(ref):
    if not ref or not ref.get("guid"):
        return None
    p = uy.guid_path(ref["guid"])
    if not p:
        return None
    try:
        docs = uy.load(p)
    except Exception:
        return None
    for d in docs.values():
        if d.type == "PhysicsMaterial2D":
            return {"friction": d.data.get("friction", 0.4), "bounciness": d.data.get("bounciness", 0)}
    return None


def tile_ref(guid, d):
    c = d.get("m_Color")
    return {"guid": guid, "sprite": sprite_ref(d.get("m_Sprite")), "collider": d.get("m_ColliderType", 1),
            "color": col(c) if c else [1, 1, 1, 1], "name": d.get("m_Name", "")}


def tilemap_data(d, renderer):
    sprites = [sprite_ref((e or {}).get("m_Data")) for e in d.get("m_TileSpriteArray") or []]
    tiles = []
    for e in d.get("m_TileAssetArray") or []:
        ref = (e or {}).get("m_Data") or {}
        t = None
        p = uy.guid_path(ref.get("guid")) if ref.get("guid") else None
        if p and p.endswith(".asset"):
            try:
                a = uy.load_asset(p)
                if a is not None:
                    t = tile_ref(ref.get("guid"), a)
            except Exception:
                pass
        tiles.append({"$tile": t} if t else None)
    mats = []
    for e in d.get("m_TileMatrixArray") or []:
        m = (e or {}).get("m_Data") or {}
        mats.append([m.get("e00", 1), m.get("e01", 0), m.get("e10", 0), m.get("e11", 1)])
    cols = [col((e or {}).get("m_Data")) for e in d.get("m_TileColorArray") or []]
    cells = []
    for t in d.get("m_Tiles") or []:
        f = t.get("first") or {}
        sd = t.get("second") or {}
        cells.append([f.get("x", 0), f.get("y", 0), sd.get("m_TileSpriteIndex", 0), sd.get("m_TileIndex", 0),
                      sd.get("m_TileMatrixIndex", 0), sd.get("m_TileColorIndex", 0)])
    anchor = d.get("m_TileAnchor") or {"x": 0.5, "y": 0.5}
    out = {"m_Enabled": d.get("m_Enabled", 1), "sprites": sprites, "tiles": tiles, "matrices": mats,
           "colors": cols, "cells": cells, "color": col(d.get("m_Color")), "anchor": [anchor.get("x", 0.5), anchor.get("y", 0.5)]}
    if renderer is not None:
        out["sortingLayer"] = renderer.data.get("m_SortingLayerID", 0)
        out["sortingOrder"] = renderer.data.get("m_SortingOrder", 0)
    return out


def physics_settings():
    root = uy.UNITY_ROOT
    tm = uy.load("ProjectSettings/TagManager.asset")
    tmd = next(iter(tm.values())).data
    layers = [l or "" for l in tmd.get("layers") or []]
    sorting = [{"name": x.get("name"), "id": x.get("uniqueID")} for x in tmd.get("m_SortingLayers") or []]
    tags = list(tmd.get("tags") or [])
    ph = next(iter(uy.load("ProjectSettings/Physics2DSettings.asset").values())).data
    hexm = str(ph.get("m_LayerCollisionMatrix") or "")
    matrix = [int.from_bytes(bytes.fromhex(hexm[i * 8:i * 8 + 8]), "little") if len(hexm) >= i * 8 + 8 else 0xFFFFFFFF for i in range(32)]
    g = ph.get("m_Gravity") or {"x": 0, "y": -9.81}
    return {"layers": layers, "sortingLayers": sorting, "tags": tags, "matrix": matrix,
            "gravity": [g.get("x", 0), g.get("y", -9.81)], "queriesHitTriggers": bool(ph.get("m_QueriesHitTriggers", 1)),
            "callbacksOnDisable": bool(ph.get("m_CallbacksOnDisable", 1))}


def build_scenes():
    out = []
    for line in open(os.path.join(uy.UNITY_ROOT, "ProjectSettings", "EditorBuildSettings.asset")):
        line = line.strip()
        if line.startswith("path:"):
            out.append(line.split("path:", 1)[1].strip())
    return out


def col(c):
    if not c:
        return [1, 1, 1, 1]
    return [c.get("r", 1), c.get("g", 1), c.get("b", 1), c.get("a", 1)]


def vec4(v):
    if not v:
        return [0, 0, 0, 0]
    return [v.get("x", 0), v.get("y", 0), v.get("z", 0), v.get("w", 0)]


def legacy_align(a):
    h = [1, 2, 4][a % 3]
    v = [256, 512, 1024][a // 3]
    return {"halign": h, "valign": v}


def esc(s):
    return str(s).replace("\\", "\\\\").replace('"', '\\"')


def gd(v):
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, int):
        return str(v)
    if isinstance(v, float):
        if v != v or v in (float("inf"), float("-inf")):
            return "0.0"
        r = repr(round(v, 6))
        return r if ("." in r or "e" in r) else r + ".0"
    if isinstance(v, str):
        return '"' + esc(v) + '"'
    if isinstance(v, tuple) and v and v[0] == "Vector2":
        return f"Vector2({gd(float(v[1]))}, {gd(float(v[2]))})"
    if isinstance(v, list):
        return "[" + ", ".join(gd(x) for x in v) + "]"
    if isinstance(v, dict):
        return "{" + ", ".join(f"{gd(str(k))}: {gd(x)}" for k, x in v.items()) + "}"
    if v is None:
        return "null"
    return gd(str(v))


# ---------------- assets ----------------
prefab_targets = {}


def conv_asset_ref(ref):
    k = uy.ref_key(ref)
    if not k or not k[1]:
        return None
    fid, guid = k
    p = uy.guid_path(guid)
    if not p:
        return None
    ext = os.path.splitext(p)[1].lower()
    if ext in (".png", ".jpg", ".jpeg"):
        if fid == 2800000:
            return {"$tex": media_ref(p)}
        return sprite_ref(ref)
    if ext in (".mp3", ".wav", ".ogg"):
        return {"$audio": media_ref(p)}
    if ext in (".ttf", ".otf"):
        return {"$font": font_ref(guid)}
    if ext == ".prefab":
        sc = prefab_convs.get(p)
        node = None
        if sc is not None:
            if fid in sc.comp_path:
                node = sc.comp_path[fid]
            else:
                go = sc.g.go_of(fid)
                node = sc.node_path.get(go)
        return {"$prefab": "res://prefabs/" + prefab_out_name(p), "node": node}
    if ext == ".asset":
        try:
            d = uy.load_asset(p)
        except Exception:
            return None
        if d is None:
            return None
        sn = uy.script_name(d.get("m_Script"))
        if sn in ("TMP_FontAsset",) or (d.get("m_SourceFontFile") is not None):
            return {"$font": font_ref(guid)}
        if "m_ColliderType" in d and "m_Sprite" in d:
            return {"$tile": tile_ref(guid, d)}
        return {"$so": guid}
    if ext == ".asset" or ext == ".mat":
        return None
    return None


def prefab_out_name(p):
    rel = os.path.relpath(p, "Assets")
    rel = rel.replace(os.sep, "__").replace(" ", "_")
    return os.path.splitext(rel)[0] + ".tscn"


SO_SKIP_FIELDS = {"m_ObjectHideFlags", "m_CorrespondingSourceObject", "m_PrefabInstance", "m_PrefabAsset",
                  "m_GameObject", "m_Enabled", "m_EditorHideFlags", "m_Script", "m_EditorClassIdentifier"}


def conv_so_value(v):
    if isinstance(v, dict):
        if "fileID" in v and set(v.keys()) <= {"fileID", "guid", "type"}:
            return conv_asset_ref(v)
        if "m_PersistentCalls" in v:
            return {"$event": []}
        if set(v.keys()) == {"r", "g", "b", "a"}:
            return {"$c": [v["r"], v["g"], v["b"], v["a"]]}
        return {k: conv_so_value(x) for k, x in v.items() if k != "serializedVersion"}
    if isinstance(v, list):
        return [conv_so_value(x) for x in v]
    return v


def convert_scriptable_objects():
    db = {}
    for p in glob.glob(os.path.join(uy.ASSETS, "**", "*.asset"), recursive=True):
        rel = os.path.relpath(p, uy.UNITY_ROOT)
        if "/TextMesh Pro/" in rel or "/Asset Store/" in rel:
            continue
        try:
            docs = uy.load(rel)
        except Exception as e:
            print("skip", rel, e)
            continue
        mbs = [d for d in docs.values() if d.type == "MonoBehaviour"]
        if not mbs:
            continue
        d = mbs[0].data
        sp = uy.guid_path((d.get("m_Script") or {}).get("guid"))
        if not sp or not sp.startswith("Assets/Script/"):
            continue
        cls = os.path.splitext(os.path.basename(sp))[0]
        guid = uy.path_guid(rel)
        fields = {k: conv_so_value(v) for k, v in d.items() if k not in SO_SKIP_FIELDS}
        fields["name"] = d.get("m_Name")
        fields.pop("m_Name", None)
        db[guid] = {"class": cls, "path": rel, "d": fields}
    return db


def copy_media():
    n = 0
    for rel in sorted(used_media):
        src = os.path.join(uy.UNITY_ROOT, rel)
        dst = os.path.join(OUT, rel)
        if not os.path.exists(src):
            continue
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        if not os.path.exists(dst) or os.path.getmtime(dst) < os.path.getmtime(src) or os.path.getsize(dst) != os.path.getsize(src):
            shutil.copy2(src, dst)
            n += 1
    return n


def main():
    for d in ("data", "scenes", "prefabs"):
        os.makedirs(os.path.join(OUT, d), exist_ok=True)
    allp = sorted(os.path.relpath(p, uy.UNITY_ROOT) for d in ("Prefab", "Resources", "Network Prefabs List", "Script")
                  for p in glob.glob(os.path.join(uy.ASSETS, d, "**", "*.prefab"), recursive=True))
    for p in allp:
        sc = SceneConv(p, True)
        sc.build()
        prefab_convs[p] = sc
    for p, sc in prefab_convs.items():
        with open(os.path.join(OUT, "prefabs", prefab_out_name(p)), "w") as fh:
            fh.write(sc.emit())
    for s in build_scenes():
        sc = SceneConv(s, False)
        sc.build()
        with open(os.path.join(OUT, "scenes", os.path.splitext(os.path.basename(s))[0] + ".tscn"), "w") as fh:
            fh.write(sc.emit())
    with open(os.path.join(OUT, "data", "physics.json"), "w") as fh:
        json.dump(physics_settings(), fh, ensure_ascii=False, separators=(",", ":"))
    db = convert_scriptable_objects()
    with open(os.path.join(OUT, "data", "so.json"), "w") as fh:
        json.dump(db, fh, ensure_ascii=False, separators=(",", ":"))
    with open(os.path.join(OUT, "data", "sprites.json"), "w") as fh:
        json.dump(sprite_meta, fh, ensure_ascii=False, separators=(",", ":"))
    n = copy_media()
    print("so", len(db), "sprites", len(sprite_meta), "media", len(used_media), "copied", n)
    print("missing scripts:", ", ".join(f"{k}({v})" for k, v in sorted(missing_scripts.items(), key=lambda x: -x[1])))


prefab_convs = {}


if __name__ == "__main__":
    main()
