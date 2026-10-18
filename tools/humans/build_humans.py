#!/usr/bin/env python3
"""
Génère les humains réalistes de Justice Life à partir des données CC0 de MakeHuman / MPFB2.

    git clone --depth 1 https://github.com/makehumancommunity/mpfb2.git
    python3 tools/humans/build_humans.py mpfb2/src/mpfb/data assets/humans

Pour chaque variante (sexe, âge, morphologie, origine) :
  * applique les cibles « macro » de MakeHuman (genre, âge, muscle, poids, origine, taille) ;
  * remet les bras le long du corps (skinning linéaire) ;
  * calcule le squelette « game engine » (53 os) et les poids de peau ;
  * exporte un .glb riggé : corps, collant (base des vêtements), cheveux, yeux, cils,
    dents, langue, jupe, plus des formes « mouth_open », « blink_l », « blink_r » ;
  * cuit des textures partagées : masques du visage (lèvres, paupières, sourcils, barbe)
    et carte de pores tuilable.
"""
import gzip
import json
import math
import os
import struct
import sys

import numpy as np
from PIL import Image

DATA = sys.argv[1] if len(sys.argv) > 1 else "mpfb2/src/mpfb/data"
OUT = sys.argv[2] if len(sys.argv) > 2 else "assets/humans"
os.makedirs(OUT, exist_ok=True)

# ─────────────────────────────────────────────────────────────────────────────
# Variantes : g genre (0 femme → 1 homme), a âge (0.5 = 25 ans, 1 = 90 ans),
# m muscle, w poids, h taille, races {caucasian, african, asian}
VARIANTS = [
    ("m_young", dict(g=1.0, a=0.52, m=0.55, w=0.48, h=0.55, race=dict(caucasian=0.85, african=0.05, asian=0.10))),
    ("m_athletic", dict(g=1.0, a=0.58, m=0.78, w=0.5, h=0.62, race=dict(caucasian=0.6, african=0.3, asian=0.1))),
    ("m_african", dict(g=1.0, a=0.6, m=0.6, w=0.55, h=0.6, race=dict(caucasian=0.1, african=0.9, asian=0.0))),
    ("m_mediter", dict(g=1.0, a=0.64, m=0.5, w=0.42, h=0.45, race=dict(caucasian=0.75, african=0.2, asian=0.05))),
    ("m_heavy", dict(g=1.0, a=0.7, m=0.45, w=0.78, h=0.5, race=dict(caucasian=0.95, african=0.0, asian=0.05))),
    ("m_senior", dict(g=1.0, a=0.78, m=0.4, w=0.6, h=0.48, race=dict(caucasian=1.0, african=0.0, asian=0.0))),
    ("m_asian", dict(g=1.0, a=0.56, m=0.5, w=0.45, h=0.42, race=dict(caucasian=0.1, african=0.0, asian=0.9))),
    ("f_young", dict(g=0.0, a=0.52, m=0.45, w=0.45, h=0.5, race=dict(caucasian=0.85, african=0.05, asian=0.10))),
    ("f_african", dict(g=0.0, a=0.6, m=0.5, w=0.55, h=0.55, race=dict(caucasian=0.1, african=0.9, asian=0.0))),
    ("f_mid", dict(g=0.0, a=0.68, m=0.45, w=0.58, h=0.45, race=dict(caucasian=0.8, african=0.15, asian=0.05))),
    ("f_senior", dict(g=0.0, a=0.78, m=0.35, w=0.62, h=0.42, race=dict(caucasian=1.0, african=0.0, asian=0.0))),
    ("f_asian", dict(g=0.0, a=0.55, m=0.45, w=0.42, h=0.4, race=dict(caucasian=0.1, african=0.0, asian=0.9))),
]

PRIMS = [  # (nom, groupes OBJ)
    ("body", ["body"]),
    ("tights", ["helper-tights"]),
    ("eyes", ["helper-l-eye", "helper-r-eye"]),
    ("lashes", None),  # tous les helper-*-eyelashes-*
    ("teeth", ["helper-upper-teeth", "helper-lower-teeth"]),
    ("tongue", ["helper-tongue"]),
    ("skirt", ["helper-skirt"]),
]
MORPHS = [("mouth_open", ["mouth-open"]), ("blink_l", ["eye-left-closure"]), ("blink_r", ["eye-right-closure"]),
          ("smile", ["mouth-corner-puller"]), ("brows_up", ["eyebrows-left-up", "eyebrows-right-up"])]


# ── Lecture des données ─────────────────────────────────────────────────────
def load_obj(path):
    vs, vts, faces = [], [], []
    cur = None
    with open(path) as f:
        for line in f:
            if line.startswith("v "):
                vs.append([float(x) for x in line.split()[1:4]])
            elif line.startswith("vt "):
                vts.append([float(x) for x in line.split()[1:3]])
            elif line.startswith("g "):
                cur = line.split(None, 1)[1].strip()
            elif line.startswith("f "):
                idx = []
                for tok in line.split()[1:]:
                    p = tok.split("/")
                    idx.append((int(p[0]) - 1, int(p[1]) - 1 if len(p) > 1 and p[1] else 0))
                faces.append((cur, idx))
    return np.array(vs, dtype=np.float64), np.array(vts, dtype=np.float64), faces


def load_target(name):
    path = os.path.join(DATA, "targets", name + ".target.gz")
    if not os.path.exists(path):
        return None
    idx, d = [], []
    with gzip.open(path, "rt") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            p = line.split()
            idx.append(int(p[0]))
            d.append([float(p[1]), float(p[2]), float(p[3])])
    return np.array(idx, dtype=np.int64), np.array(d, dtype=np.float64).reshape(-1, 3)


_tcache = {}


def target(name):
    if name not in _tcache:
        _tcache[name] = load_target(name)
    return _tcache[name]


def pairs01(v, names):
    """Poids de deux extrémités pour un paramètre dans [0,1] avec point médian."""
    lo, mid, hi = names
    if v < 0.5:
        return {lo: (0.5 - v) * 2.0, mid: v * 2.0}
    return {mid: (1.0 - v) * 2.0, hi: (v - 0.5) * 2.0}


def macro_weights(p):
    gw = {"female": 1.0 - p["g"], "male": p["g"]}
    a = p["a"]
    aw = {"young": (1.0 - a) / 0.5, "old": (a - 0.5) / 0.5} if a >= 0.5 else {"child": (0.5 - a) / 0.3125, "young": 1 - (0.5 - a) / 0.3125}
    mw = pairs01(p["m"], ("minmuscle", "averagemuscle", "maxmuscle"))
    ww = pairs01(p["w"], ("minweight", "averageweight", "maxweight"))
    out = {}
    for g, gv in gw.items():
        for ag, av in aw.items():
            for mu, mv in mw.items():
                for we, wv in ww.items():
                    k = gv * av * mv * wv
                    if k > 1e-4:
                        out["macrodetails/universal-%s-%s-%s-%s" % (g, ag, mu, we)] = k
                        h = p.get("h", 0.5)
                        if abs(h - 0.5) > 1e-3:
                            hn = "maxheight" if h > 0.5 else "minheight"
                            out["macrodetails/height/%s-%s-%s-%s-%s" % (g, ag, mu, we, hn)] = k * abs(h - 0.5) * 2.0
            for race, rv in p["race"].items():
                k = gv * av * rv
                if k > 1e-4:
                    out["macrodetails/%s-%s-%s" % (race, g, ag)] = out.get("macrodetails/%s-%s-%s" % (race, g, ag), 0) + k
    return out


# ── Géométrie ───────────────────────────────────────────────────────────────
def group_vertices(faces):
    g = {}
    for name, idx in faces:
        s = g.setdefault(name, set())
        for vi, _ in idx:
            s.add(vi)
    return {k: np.array(sorted(v)) for k, v in g.items()}


def to_godot(v):
    out = v.copy() * 0.1
    out[:, 0] *= -1.0
    out[:, 2] *= -1.0
    return out


def rot_between(a, b):
    a = a / np.linalg.norm(a)
    b = b / np.linalg.norm(b)
    v = np.cross(a, b)
    c = float(np.dot(a, b))
    s = np.linalg.norm(v)
    if s < 1e-9:
        return np.eye(3)
    k = v / s
    K = np.array([[0, -k[2], k[1]], [k[2], 0, -k[0]], [-k[1], k[0], 0]])
    ang = math.atan2(s, c)
    return np.eye(3) + math.sin(ang) * K + (1 - math.cos(ang)) * K @ K


def affine(R, pivot):
    M = np.eye(4)
    M[:3, :3] = R
    M[:3, 3] = pivot - R @ pivot
    return M


def apply_m(M, p):
    return (M[:3, :3] @ p.T).T + M[:3, 3]


# ── Exportation glTF ────────────────────────────────────────────────────────
class GLB:
    def __init__(self):
        self.bin = bytearray()
        self.views = []
        self.accessors = []

    def _view(self, data: bytes, target=None):
        while len(self.bin) % 4:
            self.bin.append(0)
        off = len(self.bin)
        self.bin += data
        v = {"buffer": 0, "byteOffset": off, "byteLength": len(data)}
        if target:
            v["target"] = target
        self.views.append(v)
        return len(self.views) - 1

    def acc(self, arr, ctype, atype, target=None, minmax=False, normalized=False):
        arr = np.ascontiguousarray(arr)
        view = self._view(arr.tobytes(), target)
        a = {"bufferView": view, "componentType": ctype, "count": int(arr.shape[0]), "type": atype}
        if minmax:
            a["min"] = arr.min(0).tolist()
            a["max"] = arr.max(0).tolist()
        if normalized:
            a["normalized"] = True
        self.accessors.append(a)
        return len(self.accessors) - 1

    def sparse_vec3(self, count, idx, vals):
        if len(idx) == 0:
            idx = np.array([0])
            vals = np.zeros((1, 3))
        iv = self._view(np.ascontiguousarray(idx.astype(np.uint32)).tobytes())
        vv = self._view(np.ascontiguousarray(vals.astype(np.float32)).tobytes())
        a = {"componentType": 5126, "count": int(count), "type": "VEC3",
             "min": np.minimum(vals.min(0), 0).astype(float).tolist(), "max": np.maximum(vals.max(0), 0).astype(float).tolist(),
             "sparse": {"count": int(len(idx)), "indices": {"bufferView": iv, "componentType": 5125},
                        "values": {"bufferView": vv}}}
        self.accessors.append(a)
        return len(self.accessors) - 1

    def write(self, path, gltf):
        gltf["bufferViews"] = self.views
        gltf["accessors"] = self.accessors
        while len(self.bin) % 4:
            self.bin.append(0)
        gltf["buffers"] = [{"byteLength": len(self.bin)}]
        js = json.dumps(gltf, separators=(",", ":")).encode()
        while len(js) % 4:
            js += b" "
        total = 12 + 8 + len(js) + 8 + len(self.bin)
        with open(path, "wb") as f:
            f.write(struct.pack("<III", 0x46546C67, 2, total))
            f.write(struct.pack("<II", len(js), 0x4E4F534A))
            f.write(js)
            f.write(struct.pack("<II", len(self.bin), 0x004E4942))
            f.write(self.bin)


def subdivide(pos, nrm, extra, tris, levels=2, alpha=0.7):
    """Subdivision 1→4 avec « Phong tessellation » (arrondit les surfaces peu denses)."""
    pos = [p for p in pos]
    nrm = [n for n in nrm]
    extra = [[e for e in arr] for arr in extra]
    for _ in range(levels):
        mid = {}
        new_tris = []
        def m(a, b):
            k = (min(a, b), max(a, b))
            if k in mid:
                return mid[k]
            pa, pb = pos[a], pos[b]
            c = (pa + pb) * 0.5
            qa = c - np.dot(c - pa, nrm[a]) * nrm[a]
            qb = c - np.dot(c - pb, nrm[b]) * nrm[b]
            pos.append((1 - alpha) * c + alpha * 0.5 * (qa + qb))
            nn = nrm[a] + nrm[b]
            nrm.append(nn / max(np.linalg.norm(nn), 1e-9))
            for arr in extra:
                arr.append((arr[a] + arr[b]) * 0.5)
            mid[k] = len(pos) - 1
            return mid[k]
        for a, b, c in tris:
            ab, bc, ca = m(a, b), m(b, c), m(c, a)
            new_tris += [(a, ab, ca), (ab, b, bc), (ca, bc, c), (ab, bc, ca)]
        tris = new_tris
    return np.array(pos), np.array(nrm), [np.array(arr) for arr in extra], tris


def smooth_normals(V, tris):
    n = np.zeros_like(V)
    a, b, c = V[tris[:, 0]], V[tris[:, 1]], V[tris[:, 2]]
    fn = np.cross(b - a, c - a)
    for k in range(3):
        np.add.at(n, tris[:, k], fn)
    ln = np.linalg.norm(n, axis=1, keepdims=True)
    ln[ln < 1e-12] = 1.0
    return n / ln


def main():
    print("Lecture du maillage de base…")
    V0, VT, faces = load_obj(os.path.join(DATA, "3dobjs", "base.obj"))
    groups = group_vertices(faces)
    rig = json.load(open(os.path.join(DATA, "rigs", "standard", "rig.game_engine.json")))
    wjs = json.load(open(os.path.join(DATA, "rigs", "standard", "weights.game_engine.json")))["weights"]
    bones = [b for b in rig.keys() if isinstance(rig[b], dict) and "head" in rig[b]]
    # Ordre topologique
    order = []
    def visit(b):
        if b in order:
            return
        p = rig[b].get("parent", "")
        if p:
            visit(p)
        order.append(b)
    for b in bones:
        visit(b)
    bidx = {b: i for i, b in enumerate(order)}
    # Poids (4 influences max)
    nv = V0.shape[0]
    infl = [[] for _ in range(nv)]
    for b, lst in wjs.items():
        if b not in bidx:
            continue
        for vi, w in lst:
            if vi < nv:
                infl[vi].append((w, bidx[b]))
    J = np.zeros((nv, 4), dtype=np.uint16)
    W = np.zeros((nv, 4), dtype=np.float32)
    for vi in range(nv):
        l = sorted(infl[vi], reverse=True)[:4]
        if not l:
            l = [(1.0, bidx["Root"])]
        s = sum(w for w, _ in l)
        for k, (w, bi) in enumerate(l):
            J[vi, k] = bi
            W[vi, k] = w / s

    # Triangles par primitive (avec dédoublement des sommets aux coutures UV)
    prim_faces = {}
    for name, grp in PRIMS:
        if grp is None:
            sel = [f for f in faces if f[0] and "eyelashes" in f[0]]
        else:
            sel = [f for f in faces if f[0] in grp]
        prim_faces[name] = sel

    # Morphs d'expression (deltas en espace OBJ)
    morph_d = []
    for mname, tnames in MORPHS:
        d = np.zeros_like(V0)
        for tn in tnames:
            t = target("expression/units/caucasian/" + tn)
            if t is None:
                print("  (cible absente)", tn)
                continue
            d[t[0]] += t[1]
        morph_d.append(d)

    manifest = []
    for vname, params in VARIANTS:
        print("Variante", vname)
        V = V0.copy()
        for tname, k in macro_weights(params).items():
            t = target(tname)
            if t is None:
                continue
            V[t[0]] += t[1] * k
        G = to_godot(V)
        G[:, 1] -= G[groups["body"], 1].min()

        def joint(cube):
            return G[groups[cube]].mean(0)
        heads = {}
        tails = {}
        for b in order:
            h = rig[b]["head"]
            heads[b] = joint(h["cube_name"]) if h["strategy"] == "CUBE" else G[h["vertex_indices"]].mean(0)
            t = rig[b]["tail"]
            tails[b] = joint(t["cube_name"]) if t["strategy"] == "CUBE" else G[t["vertex_indices"]].mean(0)
        heads["Root"] = np.array([0.0, 0.0, 0.0])

        # Bras le long du corps + jambes plus droites (skinning linéaire)
        M = {b: np.eye(4) for b in order}
        children = {b: [c for c in order if rig[c].get("parent") == b] for b in order}

        def propagate(b, Mb):
            M[b] = Mb
            for c in children[b]:
                propagate(c, Mb)
        for s, side in ((-1.0, "l"), (1.0, "r")):
            # côté gauche du personnage en x négatif (face -Z)
            sh, el = heads["upperarm_" + side], heads["lowerarm_" + side]
            if np.sign(sh[0]) != np.sign(s):
                s = -s
            tgt = np.array([s * math.sin(math.radians(7)), -math.cos(math.radians(7)), 0.0])
            R1 = rot_between(el - sh, tgt)
            M1 = affine(R1, sh)
            propagate("upperarm_" + side, M1)
            el2 = apply_m(M1, el[None])[0]
            hd2 = apply_m(M1, heads["hand_" + side][None])[0]
            tf = np.array([s * math.sin(math.radians(5)) * math.cos(math.radians(12)), -math.cos(math.radians(12)), -math.sin(math.radians(12))])
            R2 = rot_between(hd2 - el2, tf)
            M2 = affine(R2, el2) @ M1
            propagate("lowerarm_" + side, M2)
            # jambes
            hip, kn = heads["thigh_" + side], heads["calf_" + side]
            tl = np.array([s * math.sin(math.radians(2.5)), -math.cos(math.radians(2.5)), 0.0])
            d = kn - hip
            d2 = np.array([d[0], d[1], 0.0])
            R3 = rot_between(d2, tl)
            propagate("thigh_" + side, affine(R3, hip))
        mats = np.stack([M[b] for b in order])
        P = np.zeros_like(G)
        for k in range(4):
            Mv = mats[J[:, k]]
            P += W[:, k:k + 1] * (np.einsum("nij,nj->ni", Mv[:, :3, :3], G) + Mv[:, :3, 3])
        new_heads = {b: apply_m(M[b], heads[b][None])[0] for b in order}
        new_heads["Root"] = np.zeros(3)

        # Morphs : deltas transformés (repère Godot, rotation des bras)
        morphs = []
        for d in morph_d:
            dg = d * 0.1
            dg[:, 0] *= -1.0
            dg[:, 2] *= -1.0
            dd = np.zeros_like(dg)
            for k in range(4):
                Mv = mats[J[:, k]]
                dd += W[:, k:k + 1] * np.einsum("nij,nj->ni", Mv[:, :3, :3], dg)
            morphs.append(dd)

        glb = GLB()
        prims = []
        Vn = smooth_normals(P, np.array([[idx[0][0], idx[i][0], idx[i + 1][0]] for _, idx in faces
                                          if _ in ("body",) for i in range(1, len(idx) - 1)]))
        body_normals = Vn
        for pname, _ in PRIMS:
            fl = prim_faces[pname]
            keymap = {}
            vi_list, ti_list, tris = [], [], []
            for _, idx in fl:
                loc = []
                for vi, ti in idx:
                    key = (vi, ti)
                    if key not in keymap:
                        keymap[key] = len(vi_list)
                        vi_list.append(vi)
                        ti_list.append(ti)
                    loc.append(keymap[key])
                for i in range(1, len(loc) - 1):
                    tris.append((loc[0], loc[i], loc[i + 1]))
            vi_arr = np.array(vi_list)
            pos = P[vi_arr].astype(np.float32)
            tri = np.array(tris, dtype=np.uint32)
            if pname == "body":
                nrm = body_normals[vi_arr]
            else:
                # normales lissées sur la primitive elle-même
                local_tris = np.array([[vi_arr[a], vi_arr[b], vi_arr[c]] for a, b, c in tris])
                nrm = smooth_normals(P, local_tris)[vi_arr]
            nrm = nrm.astype(np.float32)
            uv = VT[np.array(ti_list)].astype(np.float32)
            uv[:, 1] = 1.0 - uv[:, 1]
            # UV2 : coordonnées utiles aux shaders procéduraux
            if pname == "eyes":
                uv2 = np.zeros((len(vi_arr), 2), dtype=np.float32)
                for side in ("l", "r"):
                    sel = np.isin(vi_arr, groups["helper-%s-eye" % side])
                    c = P[groups["helper-%s-eye" % side]].mean(0)
                    rad = np.linalg.norm(P[groups["helper-%s-eye" % side]] - c, axis=1).max()
                    rel = (P[vi_arr[sel]] - c) / rad
                    uv2[sel, 0] = rel[:, 0]
                    uv2[sel, 1] = rel[:, 1]
                    # arrière de l'œil (z positif) : blanc
                    back = sel & (P[vi_arr][:, 2] - c[2] > 0)
                    uv2[back] = 9.0
            else:
                ang = np.arctan2(pos[:, 0], -pos[:, 2])
                rad = np.sqrt(pos[:, 0] ** 2 + pos[:, 2] ** 2)
                uv2 = np.stack([ang * 0.15, pos[:, 1]], 1).astype(np.float32)
            attrs = {
                "POSITION": glb.acc(pos, 5126, "VEC3", 34962, minmax=True),
                "NORMAL": glb.acc(nrm, 5126, "VEC3", 34962),
                "TEXCOORD_0": glb.acc(uv, 5126, "VEC2", 34962),
                "TEXCOORD_1": glb.acc(uv2, 5126, "VEC2", 34962),
                "JOINTS_0": glb.acc(J[vi_arr], 5123, "VEC4", 34962),
                "WEIGHTS_0": glb.acc(W[vi_arr], 5126, "VEC4", 34962),
            }
            if pname in ("tights", "body"):
                # Masques de vêtements : R haut, G avant-bras, B bassin/cuisses, A mollets
                reg = np.zeros((len(vi_arr), 4), dtype=np.float32)
                sets = [("spine_01", "spine_02", "spine_03", "clavicle_l", "clavicle_r", "upperarm_l", "upperarm_r", "neck_01"),
                        ("lowerarm_l", "lowerarm_r", "hand_l", "hand_r"),
                        ("pelvis", "thigh_l", "thigh_r"),
                        ("calf_l", "calf_r", "foot_l", "foot_r", "ball_l", "ball_r")]
                for ch, names in enumerate(sets):
                    ids = [bidx[n] for n in names if n in bidx]
                    for k in range(4):
                        m = np.isin(J[vi_arr, k], ids)
                        reg[m, ch] += W[vi_arr, k][m]
                attrs["COLOR_0"] = glb.acc(np.clip(reg, 0, 1), 5126, "VEC4", 34962)
            targets = []
            for dd in morphs:
                sub = dd[vi_arr]
                nz = np.where(np.abs(sub).sum(1) > 1e-7)[0]
                targets.append({"POSITION": glb.sparse_vec3(len(vi_arr), nz, sub[nz])})
            ind = glb.acc(tri.reshape(-1), 5125, "SCALAR", 34963)
            prims.append({"attributes": attrs, "indices": ind, "material": len(prims), "targets": targets})

        # Calotte (cheveux) et barbe : sous-ensembles du visage, en maillages séparés
        eye_y = (new_heads["head"][1] if False else P[groups["joint-l-eye"]].mean(0)[1])
        eye_z = P[groups["joint-l-eye"]].mean(0)[2]
        lips_uv = None
        extra_meshes = []
        body_faces = [idx for g, idx in faces if g == "body"]
        for hname in ("scalp", "beard"):
            keymap = {}
            vi_list, ti_list, tris, val = [], [], [], []
            for idx in body_faces:
                pts = [P[vi] for vi, _ in idx]
                ok = True
                vals = []
                for (vi, ti), pt in zip(idx, pts):
                    rel_y = pt[1] - eye_y
                    if rel_y < -0.2:
                        ok = False
                        break
                    zc = eye_z + 0.085
                    az = abs(math.atan2(pt[0], -(pt[2] - zc)))
                    if hname == "scalp":
                        hl = 0.062 + (-0.072 - 0.062) * min(max((az - 0.55) / 1.9, 0.0), 1.0)
                        if abs(pt[0]) > 0.062 and -0.035 < rel_y < 0.025 and az > 1.1:
                            hl = 0.025
                        e = (rel_y - hl) / 0.018
                    else:
                        front = (-(pt[2] - zc)) / max(np.hypot(pt[0], pt[2] - zc), 1e-6)
                        e = min((-0.043 - rel_y) / 0.012, (rel_y + 0.15) / 0.02, (front - 0.15) / 0.25)
                        e = max(e, min((-0.046 - rel_y) / 0.004, (rel_y + 0.053) / 0.004, (0.026 - abs(pt[0])) / 0.006) * 1.0)
                    vals.append(e)
                if not ok or max(vals) < 0.0:
                    continue
                loc = []
                for (vi, ti), e in zip(idx, vals):
                    key = (vi, ti)
                    if key not in keymap:
                        keymap[key] = len(vi_list)
                        vi_list.append(vi)
                        ti_list.append(ti)
                        val.append(min(max(e, 0.0), 1.0))
                    loc.append(keymap[key])
                for i in range(1, len(loc) - 1):
                    tris.append((loc[0], loc[i], loc[i + 1]))
            vi_arr = np.array(vi_list)
            pos = P[vi_arr]
            nrm = body_normals[vi_arr]
            uv = VT[np.array(ti_list)].copy()
            uv[:, 1] = 1.0 - uv[:, 1]
            if hname == "scalp":
                pos, nrm, (uv, val_a, jj, ww), tris = subdivide(pos, nrm, [uv, np.array(val), J[vi_arr].astype(np.float64), W[vi_arr].astype(np.float64)], tris, 1)
                val = list(val_a)
                Jl = np.rint(jj).astype(np.uint16)
                Wl = ww.astype(np.float32)
                Wl /= np.maximum(Wl.sum(1, keepdims=True), 1e-6)
            else:
                Jl = J[vi_arr]
                Wl = W[vi_arr]
            pos = pos.astype(np.float32)
            nrm = nrm.astype(np.float32)
            uv = uv.astype(np.float32)
            ang = np.arctan2(pos[:, 0], -(pos[:, 2] - (eye_z + 0.085)))
            uv2 = np.stack([ang * 0.09, pos[:, 1]], 1).astype(np.float32)
            colr = np.zeros((len(pos), 4), dtype=np.float32)
            colr[:, 0] = np.array(val)
            colr[:, 3] = 1.0
            attrs = {
                "POSITION": glb.acc(pos, 5126, "VEC3", 34962, minmax=True),
                "NORMAL": glb.acc(nrm, 5126, "VEC3", 34962),
                "TEXCOORD_0": glb.acc(uv, 5126, "VEC2", 34962),
                "TEXCOORD_1": glb.acc(uv2, 5126, "VEC2", 34962),
                "COLOR_0": glb.acc(colr, 5126, "VEC4", 34962),
                "JOINTS_0": glb.acc(Jl, 5123, "VEC4", 34962),
                "WEIGHTS_0": glb.acc(Wl, 5126, "VEC4", 34962),
            }
            ind = glb.acc(np.array(tris, dtype=np.uint32).reshape(-1), 5125, "SCALAR", 34963)
            extra_meshes.append({"name": hname, "primitives": [{"attributes": attrs, "indices": ind, "material": len(PRIMS) + len(extra_meshes)}]})

        # Squelette
        nodes = [{"name": "Human", "children": [1, 2, 3, 4]}]
        nodes.append({"name": "Corps", "mesh": 0, "skin": 0})
        nodes.append({"name": "Cheveux", "mesh": 1, "skin": 0})
        nodes.append({"name": "Barbe", "mesh": 2, "skin": 0})
        bone_node = {}
        for i, b in enumerate(order):
            bone_node[b] = 4 + i
        for b in order:
            p = rig[b].get("parent", "")
            t = new_heads[b] - (new_heads[p] if p else np.zeros(3))
            n = {"name": b, "translation": [float(x) for x in t]}
            ch = [bone_node[c] for c in children[b]]
            if ch:
                n["children"] = ch
            nodes.append(n)
        ibm = []
        for b in order:
            m = np.eye(4)
            m[:3, 3] = -new_heads[b]
            ibm.append(m.T.reshape(-1))
        ibm_acc = glb.acc(np.array(ibm, dtype=np.float32), 5126, "MAT4")
        gltf = {
            "asset": {"version": "2.0", "generator": "Justice Life build_humans.py (MakeHuman CC0)"},
            "scene": 0, "scenes": [{"nodes": [0]}],
            "nodes": nodes,
            "meshes": [{"name": "Humain", "primitives": prims, "weights": [0.0] * len(MORPHS),
                        "extras": {"targetNames": [m[0] for m in MORPHS]}}] + extra_meshes,
            "skins": [{"joints": [bone_node[b] for b in order], "inverseBindMatrices": ibm_acc, "skeleton": bone_node["Root"]}],
            "materials": [{"name": p[0]} for p in PRIMS] + [{"name": "scalp"}, {"name": "beard"}],
        }
        glb.write(os.path.join(OUT, vname + ".glb"), gltf)
        top = float(P[groups["body"], 1].max())
        manifest.append({"name": vname, "female": params["g"] < 0.5, "age": params["a"], "height": round(top, 3),
                         "african": params["race"].get("african", 0.0), "asian": params["race"].get("asian", 0.0),
                         "heavy": params["w"] > 0.65,
                         "eye_l": [float(x) for x in G[groups["joint-l-eye"]].mean(0)],
                         "eye_r": [float(x) for x in G[groups["joint-r-eye"]].mean(0)]})
    json.dump(manifest, open(os.path.join(OUT, "humans.json"), "w"), indent=1)
    bake_textures(V0, VT, faces, groups)
    print("Terminé :", OUT)


# ── Textures ────────────────────────────────────────────────────────────────
def rasterize(res, uvs, vals):
    """Rastérise des triangles (UV dans [0,1]) avec une valeur par sommet. Renvoie (image, couverture)."""
    img = np.zeros((res, res), dtype=np.float32)
    cov = np.zeros((res, res), dtype=np.float32)
    for t in range(uvs.shape[0]):
        p = uvs[t] * res
        x0, y0 = np.floor(p.min(0)).astype(int)
        x1, y1 = np.ceil(p.max(0)).astype(int)
        x0, y0 = max(x0, 0), max(y0, 0)
        x1, y1 = min(x1, res - 1), min(y1, res - 1)
        if x1 < x0 or y1 < y0:
            continue
        xs, ys = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
        a, b, c = p
        den = (b[1] - c[1]) * (a[0] - c[0]) + (c[0] - b[0]) * (a[1] - c[1])
        if abs(den) < 1e-12:
            continue
        l1 = ((b[1] - c[1]) * (xs - c[0]) + (c[0] - b[0]) * (ys - c[1])) / den
        l2 = ((c[1] - a[1]) * (xs - c[0]) + (a[0] - c[0]) * (ys - c[1])) / den
        l3 = 1 - l1 - l2
        m = (l1 >= -0.01) & (l2 >= -0.01) & (l3 >= -0.01)
        v = l1 * vals[t, 0] + l2 * vals[t, 1] + l3 * vals[t, 2]
        img[y0:y1 + 1, x0:x1 + 1][m] = v[m]
        cov[y0:y1 + 1, x0:x1 + 1][m] = 1
    return img, cov


def dilate(img, cov, it=6):
    for _ in range(it):
        acc = np.zeros_like(img)
        cnt = np.zeros_like(img)
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            acc += np.roll(np.roll(img * cov, dx, 1), dy, 0)
            cnt += np.roll(np.roll(cov, dx, 1), dy, 0)
        fill = (cov == 0) & (cnt > 0)
        img[fill] = acc[fill] / cnt[fill]
        cov = np.maximum(cov, fill.astype(np.float32))
    return img


def bake_textures(V0, VT, faces, groups):
    print("Textures du visage…")
    res = 2048
    G = to_godot(V0)
    G[:, 1] -= G[groups["body"], 1].min()
    eye_l = G[groups["joint-l-eye"]].mean(0)
    eye_r = G[groups["joint-r-eye"]].mean(0)
    head = G[groups["joint-head"]].mean(0)
    # triangles de la tête uniquement
    tri_v, tri_t = [], []
    for name, idx in faces:
        if name != "body":
            continue
        for i in range(1, len(idx) - 1):
            tri_v.append((idx[0][0], idx[i][0], idx[i + 1][0]))
            tri_t.append((idx[0][1], idx[i][1], idx[i + 1][1]))
    tri_v = np.array(tri_v)
    tri_t = np.array(tri_t)
    cen = G[tri_v].mean(1)
    sel = cen[:, 1] > head[1] - 0.12
    tri_v, tri_t = tri_v[sel], tri_t[sel]
    uvs = VT[tri_t].copy()
    uvs[..., 1] = 1.0 - uvs[..., 1]
    P = G[tri_v]

    def brow(p):
        out = np.zeros(p.shape[0])
        for e in (eye_l, eye_r):
            s = 1.0 if e[0] > 0 else -1.0
            rel = p - e
            u = rel[:, 0] * s  # vers l'extérieur
            t = np.clip((u + 0.016) / 0.05, 0, 1)
            yc = 0.016 + 0.007 * np.sin(t * math.pi * 0.9) - 0.004 * t
            th = 0.0045 * (1 - t) + 0.0022
            d = np.abs(rel[:, 1] - yc)
            inside = (u > -0.02) & (u < 0.04) & (rel[:, 2] < 0.02)
            v = np.clip(1 - (d - th) / 0.0025, 0, 1) * inside
            v *= np.clip(1 - (u - 0.03) / 0.012, 0, 1)
            out = np.maximum(out, v)
        return out

    mouth_y = eye_l[1] - 0.075
    def beard(p):
        rel = p - np.array([0, 0, 0]) - np.array([head[0], 0, 0])
        front = np.clip((-(p[:, 2] - head[2]) - 0.01) / 0.03, 0, 1)
        below = np.clip((eye_l[1] - 0.045 - p[:, 1]) / 0.01, 0, 1)
        neck = np.clip((p[:, 1] - (eye_l[1] - 0.16)) / 0.02, 0, 1)
        return front * below * neck

    brow_v = np.stack([brow(P[:, k]) for k in range(3)], 1)
    beard_v = np.stack([beard(P[:, k]) for k in range(3)], 1)
    b_img, cov = rasterize(res, uvs, brow_v)
    b_img = dilate(b_img, cov.copy())
    s_img, cov2 = rasterize(res, uvs, beard_v)
    s_img = dilate(s_img, cov2.copy())

    def mask(n):
        p = os.path.join(DATA, "textures", "mpfb_%s.jpg" % n)
        return np.asarray(Image.open(p).convert("L").resize((res, res)), dtype=np.float32) / 255.0
    lips = mask("lips")
    lids = mask("eyelids")
    nails = np.maximum(mask("fingernails"), mask("toenails"))
    # bruit de poils pour les sourcils
    rng = np.random.default_rng(7)
    strands = rng.random((res, res)).astype(np.float32)
    strands = (strands + np.roll(strands, 1, 0) + np.roll(strands, 2, 0) + np.roll(strands, 1, 1) * 0.5) / 3.5
    b_img = np.clip(b_img * (0.55 + 0.6 * strands), 0, 1)
    beard_img = np.clip(s_img * (1 - lips * 1.5), 0, 1)
    rgb = np.stack([lips, np.clip(lids, 0, 1), b_img], -1)
    Image.fromarray((rgb * 255).astype(np.uint8), "RGB").save(os.path.join(OUT, "skin_masks.png"))
    Image.fromarray((beard_img * 255).astype(np.uint8), "L").save(os.path.join(OUT, "skin_beard.png"))
    Image.fromarray((nails * 255).astype(np.uint8), "L").save(os.path.join(OUT, "nails_mask.png"))

    # Carte de pores tuilable (hauteur → normales)
    print("Pores…")
    n = 1024
    h = np.zeros((n, n), dtype=np.float32)
    for k, amp in ((128, 0.5), (256, 0.3), (512, 0.2)):
        r = rng.random((k, k)).astype(np.float32)
        r = np.asarray(Image.fromarray((r * 255).astype(np.uint8)).resize((n, n), Image.BICUBIC), dtype=np.float32) / 255.0
        h += r * amp
    pores = (rng.random((n, n)) > 0.985).astype(np.float32)
    for _ in range(2):
        pores = (pores + np.roll(pores, 1, 0) + np.roll(pores, -1, 0) + np.roll(pores, 1, 1) + np.roll(pores, -1, 1)) / 5
    h -= pores * 2.0
    dx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * 2.0
    dy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * 2.0
    nz = np.ones_like(h)
    ln = np.sqrt(dx * dx + dy * dy + nz)
    nm = np.stack([(-dx / ln) * 0.5 + 0.5, (-dy / ln) * 0.5 + 0.5, (nz / ln) * 0.5 + 0.5], -1)
    Image.fromarray((nm * 255).astype(np.uint8), "RGB").save(os.path.join(OUT, "skin_pores_n.png"))
    var = (h - h.min()) / (h.max() - h.min())
    Image.fromarray((var * 255).astype(np.uint8), "L").save(os.path.join(OUT, "skin_variation.png"))


if __name__ == "__main__":
    main()
