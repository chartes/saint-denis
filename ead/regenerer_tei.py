# -*- coding: utf-8 -*-
"""regenerer_tei.py (2026-11-16) — refait le contenu des TEI de l'Inventaire général (data/ISD-vol1..3.xml de
chartes/saint-denis) à partir de l'EAD reconstruit (ead/ISD-volN.xml), en gardant la charpente que dots-vue et la
feuille saint-denis.xsl attendent :
  GARDÉ du TEI actuel : teiHeader (+ un <change>), refsDecl/citeStructure, div[@type='section'] (périodes) tels quels,
  div[@type='notice'] avec @xml:id/@n, leur <pb> (1er enfant), leur <head> (titre du sommaire), l'ordre et le texte
  des libellés (list[@type='gloss']/label, label[@type='section']), l'item « URL de cette page ».
  REPRIS de l'EAD : le contenu des items et des rubriques, avec son balisage : hi (sup, underline, italic, large =
  mots latins en gros caractères), ref (images du Cartulaire blanc et de l'Inventaire, actes édités), note à leur
  appel (type inventaire / editeur), date (dates de la notice), term (auteurs d'actes, types de documents).
Contrôle : pour chaque item et chaque rubrique, les mots du nouveau texte doivent égaler ceux de l'ancien (les notes
replacées mises à part) ; sinon l'ancien est gardé et l'écart est listé dans regeneration.md.
Écrit dans tei/ISD-volN.xml (le dépôt n'est pas touché)."""
import collections, copy, os, re, sys
from lxml import etree

sys.stdout.reconfigure(encoding="utf-8")
HERE = os.path.dirname(os.path.abspath(__file__))
DEPOT = r"C:\Users\mpopinea\dubourg-propre\_ref\saint-denis\data"
OUT = os.path.join(HERE, "tei")
TN = "http://www.tei-c.org/ns/1.0"; T = "{%s}" % TN
EN = "urn:isbn:1-931666-22-9"; E = "{%s}" % EN
XL = "{http://www.w3.org/1999/xlink}href"
XMLID = "{http://www.w3.org/XML/1998/namespace}id"
RENDER = {"super": "sup", "underline": "underline", "italic": "italic", None: "large"}
TITRES_NOTES = {"Notes de l’éditeur": "editeur", "Notes de l’inventaire manuscrit": "inventaire"}

stats = collections.Counter()
ecarts = []


def brut(n, notes="appel"):
    """texte d'un nœud TEI, sans aucune espace (comparaison caractère pour caractère) ; une <note> compte pour son
    appel (notes="appel") — c'est ce que l'ancien TEI portait à cet endroit."""
    out = []
    def walk(x):
        if x.tag == T + "note" and notes == "appel":
            out.append(x.get("n") or ""); return
        if x.text: out.append(x.text)
        for c in x:
            walk(c)
            if c.tail: out.append(c.tail)
    walk(n)
    return re.sub(r"\s+", "", "".join(out))


def notes_brut(new):
    """les notes replacées d'une notice, écrites comme l'ancienne rubrique (« a. texte »), sans espaces"""
    return {typ: "".join(re.sub(r"\s+", "", (n.get("n") or "") + "." + "".join(n.itertext()))
                         for n in new.iter(T + "note") if n.get("type") == typ)
            for typ in ("editeur", "inventaire")}


def t(tag, parent=None, text=None, **att):
    e = etree.Element(T + tag) if parent is None else etree.SubElement(parent, T + tag)
    for k, v in att.items():
        if v is not None:
            e.set(k, v)
    if text:
        e.text = text
    return e


def e2t(src, dst):
    """contenu mêlé EAD → TEI"""
    def texte(s):
        if not s:
            return
        if len(dst):
            dst[-1].tail = (dst[-1].tail or "") + s
        else:
            dst.text = (dst.text or "") + s
    texte(src.text)
    for c in src:
        tag = etree.QName(c).localname
        if tag == "emph":
            e2t(c, t("hi", dst, rend=RENDER.get(c.get("render"), c.get("render"))))
            stats["hi:" + RENDER.get(c.get("render"), c.get("render"))] += 1
        elif tag == "extref":
            e2t(c, t("ref", dst, target=c.get(XL))); stats["ref"] += 1
        elif tag == "lb":
            t("lb", dst)
        elif tag == "list":
            e2t(c, t("list", dst))
        elif tag == "item":
            e2t(c, t("item", dst))
        elif tag == "unitdate":
            e2t(c, t("date", dst)); stats["date en ligne"] += 1
        elif tag == "genreform":
            e2t(c, t("term", dst, type="genreform"))
        elif tag == "note":
            n = t("note", dst, type="inventaire" if c.get("altrender") == "ms" else "editeur", n=c.get("label"))
            for p in c:                                            # note/p → contenu en ligne
                e2t(p, n)
            stats["note:" + n.get("type")] += 1
        elif tag == "p":
            e2t(c, dst)
        else:
            stats["élément EAD inattendu:" + tag] += 1
            e2t(c, dst)
        texte(c.tail)


def blocs_ead(c):
    """(intitulé, [nœuds EAD paragraphes]) dans l'ordre du composant"""
    out = []
    def bloc(x):
        head = x.find(E + "head")
        paras = [p for p in x if etree.QName(p).localname in ("p", "bibref")]
        out.append((" ".join("".join(head.itertext()).split()) if head is not None else "", paras, x))
        for sub in x:
            ln = etree.QName(sub).localname
            if ln == etree.QName(x).localname:                     # bibliography emboîtée
                bloc(sub)
            elif ln == "list" and sub.get("type") == "deflist":     # notes restées en fin de regeste
                h = sub.find(E + "head")
                items = []
                for d in sub.findall(E + "defitem"):
                    p = etree.Element(E + "p"); p.text = (d.findtext(E + "label") or "") + ". "
                    it = d.find(E + "item"); p.text += it.text or ""
                    for k in it: p.append(copy.deepcopy(k))
                    items.append(p)
                out.append((" ".join("".join(h.itertext()).split()) if h is not None else "", items, sub))
    for x in c:
        if etree.QName(x).localname in ("scopecontent", "relatedmaterial", "bibliography", "odd"):
            bloc(x)
    return out


def champs_ead(c):
    """libellé → [éléments] (did/@label|@datechar|@type, controlaccess/head)"""
    d = collections.defaultdict(list)
    did = c.find(E + "did")
    for x in did:
        lab = x.get("label") or x.get("datechar") or x.get("type")
        if lab:
            d[lab].append(x)
    for sub in c.findall(E + "controlaccess/" + E + "controlaccess"):
        d[" ".join(sub.findtext(E + "head").split())].append(sub)
    return d


def item_depuis(x):
    """un champ EAD → contenu d'un <item>"""
    it = etree.Element(T + "item")
    ln = etree.QName(x).localname
    if ln == "controlaccess":
        termes = [y for y in x if etree.QName(y).localname != "head"]
        for i, y in enumerate(termes):
            if i:
                it[-1].tail = " • "
            t("term", it, text=y.text, type="genreform" if etree.QName(y).localname == "genreform" else "auteur-acte")
        stats["term"] += len(termes)
    elif ln == "unitdate":
        e2t(x, t("date", it)); stats["date"] += 1
    elif ln == "note":
        for p in x:
            e2t(p, it)
    else:
        e2t(x, it)
    return it


def notice(old, comp, cid):
    avant = len(ecarts)
    new = notice_brute(old, comp, cid)
    if len(ecarts) > avant:
        stats["notice gardée telle quelle (écart)"] += 1
        return copy.deepcopy(old)
    stats["notice refaite"] += 1
    return new


def notice_brute(old, comp, cid):
    new = etree.Element(T + "div", {k: v for k, v in old.attrib.items()})
    new.text = old.text
    champs = champs_ead(comp)
    vus = collections.Counter()
    retirees = {"editeur": "", "inventaire": ""}
    enfants = list(old)
    i = 0
    blocs = blocs_ead(comp)
    bi = 0
    while i < len(enfants):
        x = enfants[i]
        ln = etree.QName(x).localname
        if ln in ("pb", "head"):
            new.append(copy.deepcopy(x)); i += 1; continue
        if ln == "list" and x.get("type") == "gloss":
            gl = copy.deepcopy(x); new.append(gl)
            labs = [l for l in gl if l.tag == T + "label"]
            for lab in labs:
                item = lab.getnext()
                L = " ".join("".join(lab.itertext()).split())
                k = vus[L]; vus[L] += 1
                if L == "URL de cette page":
                    continue
                if item is None or item.tag != T + "item":                # libellé sans valeur (date « nst » vide…)
                    stats["libellé sans valeur gardé"] += 1; continue
                cand = champs.get(L, [])
                if k >= len(cand):
                    ecarts.append((cid, "champ sans équivalent EAD", L)); continue
                nit = item_depuis(cand[k]); nit.tail = item.tail
                if brut(nit) != brut(item):
                    ecarts.append((cid, "champ différent : " + L, " ".join("".join(item.itertext()).split())[:80] + " ≠ " + " ".join("".join(nit.itertext()).split())[:80]))
                    continue
                gl.replace(item, nit); stats["champ repris"] += 1
            i += 1; continue
        if ln == "label" and x.get("type") == "section":
            L = " ".join("".join(x.itertext()).split())
            paras = []
            j = i + 1
            while j < len(enfants) and etree.QName(enfants[j]).localname == "p":
                paras.append(enfants[j]); j += 1
            # bloc EAD de même intitulé, dans l'ordre
            k = bi
            while k < len(blocs) and blocs[k][0] != L:
                k += 1
            if L in TITRES_NOTES and k == len(blocs):
                retirees[TITRES_NOTES[L]] += "".join(brut(p) for p in paras)     # contrôlé plus bas contre les notes replacées
                stats["rubrique de notes retirée (notes replacées)"] += 1
                i = j; continue
            if k == len(blocs) or len(blocs[k][1]) != len(paras):
                ecarts.append((cid, "rubrique non retrouvée ou nombre de paragraphes différent", L))
                for y in enfants[i:j]:
                    new.append(copy.deepcopy(y))
                i = j; continue
            bi = k + 1
            new.append(copy.deepcopy(x))
            for op, ep in zip(paras, blocs[k][1]):
                np_ = etree.SubElement(new, T + "p", {a: v for a, v in op.attrib.items()})
                e2t(ep, np_)
                np_.tail = op.tail
                if brut(np_) != brut(op):
                    a, b = brut(op), brut(np_)
                    d = next((q for q in range(min(len(a), len(b))) if a[q] != b[q]), min(len(a), len(b)))
                    ecarts.append((cid, "paragraphe différent : " + L, "ancien …%s… / nouveau …%s…" % (a[max(0, d - 25):d + 25], b[max(0, d - 25):d + 25])))
                    new.replace(np_, copy.deepcopy(op))
                else:
                    stats["paragraphe repris"] += 1
            i = j; continue
        new.append(copy.deepcopy(x)); stats["enfant gardé tel quel:" + ln] += 1; i += 1
    if len(new):
        new[-1].tail = old[-1].tail if len(old) else None
    # contrôle : les notes replacées disent exactement ce que disaient les rubriques de notes retirées
    nb = notes_brut(new)
    for typ in ("editeur", "inventaire"):
        if nb[typ] != retirees[typ]:
            ecarts.append((cid, "notes %s différentes de la rubrique retirée" % typ, "%s / %s" % (retirees[typ][:60], nb[typ][:60])))
    # contrôle : rien d'oublié — même nombre de pb, head, list, label de rubrique gardés ou retirés
    for tag in ("pb", "head", "list"):
        if len(old.findall(T + tag)) != len(new.findall(T + tag)):
            ecarts.append((cid, "élément perdu", tag))
    return new


def volume(v):
    old = etree.parse(os.path.join(DEPOT, "ISD-vol%d.xml" % v))
    ead = etree.parse(os.path.join(HERE, "ead", "ISD-vol%d.xml" % v))
    comps = {c.get("id"): c for c in ead.iter(E + "c")}
    n = 0
    for d in list(old.iter(T + "div")):
        if d.get("type") != "notice":
            continue
        cid = d.get(XMLID)
        if cid not in comps:
            ecarts.append((cid, "notice absente de l'EAD", "")); continue
        d.getparent().replace(d, notice(d, comps[cid], cid)); n += 1
    rd = old.find(".//" + T + "revisionDesc")
    ch = etree.Element(T + "change", when="2026-11-16")
    ch.text = ("Contenu des notices refait à partir de l'EAD 2002 reconstruit du site (dots-autopilot/work/saint-denis-ead) : "
               "mises en forme (hi : exposants, soulignés, mots latins en gros caractères), liens vers les images du Cartulaire blanc "
               "et vers les actes édités (ref), notes replacées à leur appel (note[@type='inventaire'|'editeur']), dates (date) et "
               "termes d'index (term). En-tête, structure, identifiants, pb, titres et libellés inchangés ; texte contrôlé mot à mot.")
    if rd is not None:
        if len(rd) and rd[0].tail:
            ch.tail = rd[0].tail
        rd.insert(0, ch)
    os.makedirs(OUT, exist_ok=True)
    # même forme de fichier que le dépôt : pas de déclaration XML, fins de ligne CRLF
    txt = etree.tostring(old, encoding="unicode").replace("\r\n", "\n").replace("\n", "\r\n")
    open(os.path.join(OUT, "ISD-vol%d.xml" % v), "w", encoding="utf-8", newline="").write(txt)
    return n


if __name__ == "__main__":
    for v in (1, 2, 3):
        print("ISD-vol%d : %d notices" % (v, volume(v)))
    lignes = ["# Régénération des TEI de l'Inventaire depuis l'EAD (16/11/2026)", "", "## Compteurs", ""]
    lignes += ["- %s : %d" % kv for kv in sorted(stats.items())]
    lignes += ["", "## Écarts (%d) — la notice entière est gardée telle quelle" % len(ecarts), ""]
    lignes += ["- %s | %s | %s" % e for e in ecarts]
    open(os.path.join(HERE, "regeneration.md"), "w", encoding="utf-8").write("\n".join(lignes) + "\n")
    for k, v in sorted(stats.items()):
        print("  %-48s %6d" % (k, v))
    print("écarts :", len(ecarts), collections.Counter(e[1].split(" : ")[0] for e in ecarts).most_common())
