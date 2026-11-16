# -*- coding: utf-8 -*-
"""regenerer_tei_v2.py (2026-11-16, 2e version) — refait les notices de l'Inventaire (data/ISD-vol1..3.xml de
chartes/saint-denis) ENTIÈREMENT depuis l'EAD reconstruit (ead/), qui a été vérifié mot à mot contre les pages Pleade.

La 1re version s'alignait sur le TEI de septembre et en héritait les défauts (date vide qui avale le libellé suivant,
rubriques fusionnées, « Regeste bref » absent du tableau). Ici, du TEI d'origine, on ne garde que :
  le teiHeader (+ un <change>), la refsDecl, les div[@type='section'] (périodes) et, pour chaque notice, ses
  attributs, son <pb> et son <head> (titre du sommaire de dots-vue).
Le corps vient de l'EAD, dans l'ordre de l'ancien site :
  list[@type='gloss'] : unitid, unitdate, unittitle (« Regeste bref »), physdesc, puis les termes d'index
  (auteurs d'actes, types de documents), puis « Édition réalisée d'après », puis « URL de cette page » ;
  rubriques : label[@type='section'] + p, une par bloc EAD (regeste, correspondance, références, autres informations),
  notes à leur appel (note[@type='inventaire'|'editeur'][@n]) ; les 5 notes dont l'appel n'a pas été retrouvé gardent
  la forme de l'ancien site (rubrique + p[@rend='note-editeur'|'note-inventaire']).
Entrée : les TEI d'AVANT le 16/11 (ANCIEN), pas data/ (déjà refait). Sortie : tei/ISD-volN.xml."""
import collections, copy, os, re, sys
from lxml import etree

sys.stdout.reconfigure(encoding="utf-8")
HERE = os.path.dirname(os.path.abspath(__file__))
ANCIEN = r"C:\Users\mpopinea\AppData\Local\Temp\claude\220e61aecd994ae2\01f64b8a-bb5b-4922-9ecb-c395479a2b8a\scratchpad\reingest_isd\ancien"
OUT = os.path.join(HERE, "tei")
T = "{http://www.tei-c.org/ns/1.0}"
E = "{urn:isbn:1-931666-22-9}"
XL = "{http://www.w3.org/1999/xlink}href"
XMLID = "{http://www.w3.org/XML/1998/namespace}id"
RENDER = {"super": "sup", "underline": "underline", "italic": "italic", None: "large"}
NOTES = {"Notes de l’éditeur": "note-editeur", "Notes de l’inventaire manuscrit": "note-inventaire"}
stats = collections.Counter()
ecarts = []


def ln(x):
    return etree.QName(x).localname


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
        tag = ln(c)
        if tag == "emph":
            r = RENDER.get(c.get("render"), c.get("render")); e2t(c, t("hi", dst, rend=r)); stats["hi:" + r] += 1
        elif tag == "extref":
            e2t(c, t("ref", dst, target=c.get(XL))); stats["ref"] += 1
        elif tag == "lb":
            t("lb", dst)
        elif tag == "list":
            e2t(c, t("list", dst))
        elif tag == "item":
            e2t(c, t("item", dst))
        elif tag == "unitdate":
            e2t(c, t("date", dst))
        elif tag == "genreform":
            e2t(c, t("term", dst, type="genreform"))
        elif tag == "note":
            n = t("note", dst, type="inventaire" if c.get("altrender") == "ms" else "editeur", n=c.get("label"))
            for p in c:
                e2t(p, n)
            stats["note:" + n.get("type")] += 1
        elif tag == "p":
            e2t(c, dst)
        else:
            stats["élément EAD inattendu:" + tag] += 1; e2t(c, dst)
        texte(c.tail)


IND = "\n        "


def ligne(gl, label, item):
    lab = t("label", gl, text=label); lab.tail = ""
    gl.append(item); item.tail = IND
    if len(gl) == 2:
        gl.text = IND


def glossaire(comp, vol, cid):
    gl = t("list", type="gloss")
    did = comp.find(E + "did")
    notes_did = []
    for x in did:
        lab = x.get("label") or x.get("datechar") or x.get("type") or ""
        if ln(x) == "note":
            notes_did.append((lab, x)); continue
        it = etree.Element(T + "item")
        if ln(x) == "unitdate" or "date" in lab.lower():
            d = t("date", it); e2t(x, d)
            if not len(d) and not (d.text or "").strip():
                it.remove(d)                                        # date vide (« nst » sans valeur) : item vide
        else:
            e2t(x, it)
        ligne(gl, lab, it); stats["ligne:" + lab] += 1
    for sub in comp.findall(E + "controlaccess/" + E + "controlaccess"):
        lab = " ".join(sub.findtext(E + "head").split())
        it = etree.Element(T + "item")
        termes = [y for y in sub if ln(y) != "head"]
        for i, y in enumerate(termes):
            if i:
                it[-1].tail = " • "
            t("term", it, text=y.text, type="genreform" if ln(y) == "genreform" else "auteur-acte")
        ligne(gl, lab, it); stats["termes"] += len(termes)
    for lab, x in notes_did:
        it = etree.Element(T + "item")
        for p in x:
            e2t(p, it)
        ligne(gl, lab, it)
    unite = cid.split("_", 1)[1]
    ligne(gl, "URL de cette page", t("item", text="<http://saint-denis.enc.sorbonne.fr/inventaire/tome%d/%s>" % (vol, unite)))
    gl[-1].tail = "\n      "
    return gl


def blocs(comp):
    """(intitulé, [paragraphes TEI], rend) dans l'ordre du composant ; blocs emboîtés et notes restées en liste à part"""
    out = []
    def bloc(x):
        h = x.find(E + "head")
        paras = []
        for p in x:
            if ln(p) in ("p", "bibref"):
                np_ = etree.Element(T + "p"); e2t(p, np_); paras.append(np_)
        out.append((" ".join("".join(h.itertext()).split()) if h is not None else "", paras, None))
        for sub in x:
            if ln(sub) == ln(x):
                bloc(sub)
            elif ln(sub) == "list" and sub.get("type") == "deflist":
                hh = " ".join("".join(sub.find(E + "head").itertext()).split())
                ps = []
                for d in sub.findall(E + "defitem"):
                    np_ = etree.Element(T + "p", rend=NOTES.get(hh, "note-editeur"))
                    lab = (d.findtext(E + "label") or "").strip()
                    np_.text = lab + ". " if lab else ""                 # note sans appel : affichée sans numéro, comme sur l'ancien site
                    e2t(d.find(E + "item"), np_); ps.append(np_)
                out.append((hh, ps, "notes")); stats["notes laissées en rubrique"] += len(ps)
    for x in comp:
        if ln(x) in ("scopecontent", "relatedmaterial", "bibliography", "odd"):
            bloc(x)
    return out


def notice(old, comp, vol, cid):
    new = etree.Element(T + "div", {k: v for k, v in old.attrib.items()})
    new.text = old.text
    for x in old:
        if ln(x) in ("pb", "head"):
            y = copy.deepcopy(x); y.tail = "\n      "; new.append(y)
    new.append(glossaire(comp, vol, cid))
    for titre, paras, _ in blocs(comp):
        if titre:
            lab = t("label", new, text=titre, type="section"); lab.tail = "\n      "
        for p in paras:
            new.append(p); p.tail = "\n      "
    new[-1].tail = old[-1].tail if len(old) else "\n    "
    # contrôles : pb et head présents, rien de vide qui ne l'était pas dans l'EAD
    for tag in ("pb", "head"):
        if len(old.findall(T + tag)) != len(new.findall(T + tag)):
            ecarts.append((cid, "élément perdu", tag))
    a = re.sub(r"\s+", "", "".join(x for x in comp.itertext()))
    b = re.sub(r"\s+", "", "".join(x for y in new if ln(y) not in ("head",) for x in y.itertext()))
    for lab in ("URL de cette page",):
        b = b.replace(re.sub(r"\s+", "", lab), "", 1)
    b = re.sub(r"<http://saint-denis\.enc\.sorbonne\.fr/inventaire/tome\d/[^>]+>", "", b)
    manque = collections.Counter(a) - collections.Counter(b)       # tout caractère de l'EAD doit se retrouver dans le TEI
    if manque:                                                      # (le TEI a en plus les libellés, qui sont des attributs en EAD)
        ecarts.append((cid, "caractères de l'EAD absents du TEI", dict(manque)))
    stats["notice refaite"] += 1
    return new


def volume(v):
    old = etree.parse(os.path.join(ANCIEN, "ISD-vol%d.xml" % v))
    ead = etree.parse(os.path.join(HERE, "ead", "ISD-vol%d.xml" % v))
    comps = {c.get("id"): c for c in ead.iter(E + "c")}
    for d in list(old.iter(T + "div")):
        if d.get("type") == "notice":
            cid = d.get(XMLID)
            if cid not in comps:
                ecarts.append((cid, "absente de l'EAD", "")); continue
            d.getparent().replace(d, notice(d, comps[cid], v, cid))
    rd = old.find(".//" + T + "revisionDesc")
    ch = etree.Element(T + "change", when="2026-11-16")
    ch.text = ("Corps des notices refait à partir de l'EAD 2002 reconstruit de l'ancien site (ead/ du dépôt), dans l'ordre et "
               "avec les libellés de l'ancien site (dont la ligne « Regeste bref ») : mises en forme (hi : exposants, soulignés, "
               "mots latins en gros caractères), liens vers les images, vers les actes édités du Cartulaire blanc et entre "
               "notices (ref), notes à leur appel (note[@type='inventaire'|'editeur']), dates (date), termes d'index (term). "
               "En-tête, sections, identifiants, pb et titres des notices inchangés.")
    if rd is not None:
        ch.tail = rd[0].tail if len(rd) else None
        rd.insert(0, ch)
    os.makedirs(OUT, exist_ok=True)
    txt = etree.tostring(old, encoding="unicode").replace("\r\n", "\n").replace("\n", "\r\n")
    open(os.path.join(OUT, "ISD-vol%d.xml" % v), "w", encoding="utf-8", newline="").write(txt)


if __name__ == "__main__":
    for v in (1, 2, 3):
        volume(v)
    for k, v in sorted(stats.items()):
        if not k.startswith("ligne:") or v > 50:
            print("  %-45s %6d" % (k, v))
    print("écarts :", len(ecarts))
    for e in ecarts[:20]:
        print("  ", e)
    open(os.path.join(HERE, "regeneration_v2.md"), "w", encoding="utf-8").write(
        "# Régénération v2 (16/11/2026)\n\n" + "\n".join("- %s : %d" % kv for kv in sorted(stats.items()))
        + "\n\n## Écarts (%d)\n\n" % len(ecarts) + "\n".join("- %s | %s | %s" % e for e in ecarts) + "\n")
