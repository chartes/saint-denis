# -*- coding: utf-8 -*-
"""reconstruire_ead.py (2026-11-16) — reconstruit en EAD 2002 l'Inventaire général des chartes de Saint-Denis
(ISD-vol1 à ISD-vol3) à partir des pages HTML que l'application Pleade servait (copie locale faite avant
la fermeture du site). Les EAD d'origine ne sont ni sur le disque ni dans la Wayback Machine.

Principe : Pleade a gardé dans ses classes le nom de l'élément EAD rendu (pl-ead-unitdate, pl-ead-emph +
pl-ead-att-render-super, pl-ead-scopecontent…) ; l'arbre vient de la position que chaque page donne
(synchronizeToc('id','00001.00002.00003','ancêtres')). Ce n'est donc PAS le fichier d'origine : c'est son
contenu, remis dans la structure EAD que ces indices permettent d'établir. Tout choix d'élément qui n'est
pas lu dans une classe est signalé dans l'en-tête (<processinfo>) et dans le rapport.

Usage : python reconstruire_ead.py   → ead/ISD-vol1.xml … ead/ISD-vol3.xml + rapport.md
"""
import collections, os, re, sys
from lxml import etree

sys.stdout.reconfigure(encoding="utf-8")
SRC = r"C:\Users\mpopinea\Downloads\_legacy_avant_fermeture_20260912\saint-denis.enc.sorbonne.fr"
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "ead")
SITE = "http://saint-denis.enc.sorbonne.fr/"
EAD = "urn:isbn:1-931666-22-9"
XLINK = "http://www.w3.org/1999/xlink"
XSI = "http://www.w3.org/2001/XMLSchema-instance"
H = "{http://www.w3.org/1999/xhtml}"
E = "{%s}" % EAD
TYPES_DATE = {"confirmation", "nst", "confirmation nst", "nst confirmation", "enc"}   # libellés qui sont des @type affichés tels quels

stats = collections.Counter()
inconnus = collections.Counter()


def el(tag, parent=None, text=None, **att):
    e = etree.Element(E + tag) if parent is None else etree.SubElement(parent, E + tag)
    for k, v in att.items():
        if v is not None:
            e.set({"href": "{%s}href" % XLINK, "type_": "type"}.get(k, k), v)
    if text is not None:
        e.text = text
    return e


def classes(h):
    return (h.get("class") or "").split()


def norm(s):
    return re.sub(r"\s+", " ", s or "")


def absolu(href):
    """Lien du site (relatif à /inventaire/tomeN/) rendu absolu sur l'ancien domaine."""
    if href.startswith("http"):
        return href
    return SITE + re.sub(r"^(\.\./)+", "", href)


def inline(h, cible):
    """Recopie le contenu mêlé d'un nœud HTML dans l'élément EAD `cible`, en traduisant les classes pl-ead-*."""
    def ajoute_texte(t):
        if not t:
            return
        t = norm(t)
        if len(cible):
            cible[-1].tail = (cible[-1].tail or "") + t
        else:
            cible.text = (cible.text or "") + t
    ajoute_texte(h.text)
    for c in h:
        if not isinstance(c.tag, str):
            ajoute_texte(c.tail); continue
        tag, cl = c.tag.replace(H, ""), classes(c)
        if "pl-ead-emph" in cl:
            # <span class="pl-ead-emph"><sup class="pl-ead-att-render-super">ère</sup></span>
            r = [x for x in c.iter() if any(k.startswith("pl-ead-att-render-") for k in classes(x))]
            render = classes(r[0])[0].replace("pl-ead-att-render-", "") if r else None
            e = el("emph", cible, render=render)
            inline(r[0] if r else c, e); stats["emph"] += 1
        elif "pl-ead-unitdate" in cl:
            inline(c, el("unitdate", cible))
        elif "pl-ead-genreform" in cl:
            inline(c, el("genreform", cible))
        elif tag == "a":
            href = c.get("href") or ""
            if "docsearch-term" in href or href.startswith("javascript"):
                inline(c, cible)                                   # lien de recherche Pleade : le terme seul
            else:
                inline(c, el("extref", cible, href=absolu(href))); stats["extref"] += 1
        elif tag == "br":
            el("lb", cible)
        elif tag == "ul":                                          # « L'édition de l'acte existe déjà sous le(s) numéro(s) : »
            inline(c, el("list", cible))
        elif tag == "li":
            inline(c, el("item", cible))
        elif tag in ("span", "sup", "sub", "i", "u", "b") or "pl-ead-controlaccess-group-content" in cl or "pl-ead-pgd-index" in cl:
            if tag in ("sup", "i", "u", "b") and not cl:
                inline(c, el("emph", cible, render={"sup": "super", "i": "italic", "u": "underline", "b": "bold"}[tag]))
            else:
                inline(c, cible)
        else:
            inconnus["inline:%s.%s" % (tag, ".".join(cl))] += 1
            inline(c, cible)
        ajoute_texte(c.tail)


def termes(td):
    """Termes d'index d'une cellule (un <a> par terme dans pl-ead-controlaccess-group-content)."""
    return [norm("".join(a.itertext())).strip() for a in td.iter(H + "a")]


def lire_page(path):
    raw = open(path, encoding="utf-8").read()
    raw = re.sub(r"<!DOCTYPE[^>]*>", "", raw)
    return etree.fromstring(raw.encode("utf-8"), etree.XMLParser(recover=True, huge_tree=True))


def position(doc):
    for b in doc.iter(H + "button"):
        m = re.search(r"synchronizeToc\('([^']+)','([^']*)','([^']*)'\)", b.get("onclick") or "")
        if m:
            return m.group(1), m.group(2), [x for x in m.group(3).split(",") if x]
    return None, None, []


def convertir_composant(doc, cid, niveau, racine=False):
    """Une page Pleade → un <c> (ou le contenu de <archdesc>)."""
    comp = el("archdesc" if racine else "c", level=niveau)
    if not racine:
        comp.set("id", cid)
    did = el("did", comp)
    bloc = [d for d in doc.iter(H + "div") if "pl-pgd-c" in classes(d)][0]
    ctrl = {}
    # 1. tableau d'identification (did)
    for tr in bloc.iter(H + "tr"):
        cl = [k for k in classes(tr) if k.startswith("pl-tbl-lgn-")]
        if not cl:
            continue
        kind = cl[0].replace("pl-tbl-lgn-", "")
        th = tr.find(H + "th"); td = tr.find(H + "td")
        lab = norm("".join(th.itertext())).strip() if th is not None else ""
        if td is None:
            continue
        if kind in ("unitid", "unittitle", "unitdate"):
            # « confirmation », « nst » (nouveau style), « ENC » : valeurs d'attribut que Pleade affichait faute de libellé
            if lab.lower() in TYPES_DATE:
                att = {"datechar": lab} if kind == "unitdate" else {"type_": lab}
            else:
                att = {"label": lab}
            inline(td, el(kind, did, **att))
        elif kind == "physdesc":
            inline(td, el("physdesc", did, label=lab))
        elif kind in ("genreform", "auteursactes"):
            ctrl.setdefault(lab, (kind, []))[1].extend(termes(td))
        elif kind == "odd":
            if "pl-tbl-refurl" in classes(td):
                stats["url_page_omise"] += 1                       # « URL de cette page » : reconstructible depuis @id
                continue
            note = el("note", did, label=lab)
            inline(td, el("p", note))
        else:
            inconnus["ligne:" + kind] += 1
        stats["ligne:" + kind] += 1
    # 2. blocs de texte
    for sec in bloc.iter(H + "div"):
        cl = classes(sec)
        if "pl-pgd-sect" not in cl or sec is bloc:
            continue
        nom = next((k.replace("pl-ead-", "") for k in cl if k.startswith("pl-ead-")), None)
        if nom is None:
            nom = "relatedmaterial" if "cart-links" in cl else "odd"
        if nom not in ("scopecontent", "bibliography", "odd", "relatedmaterial"):
            inconnus["section:" + nom] += 1; continue
        s = el(nom, comp, id=sec.get("id"))
        haut = s
        liste = None
        for p in sec:
            if not isinstance(p.tag, str):
                continue
            pc = classes(p)
            if any(k.startswith("pl-pgd-head") for k in pc) and "pl-ead-p-head" not in pc:
                # un 2e intitulé (« Références ajoutées par l'éditeur ») = bloc emboîté que Pleade a aplati
                if len(haut):
                    s = el(nom, haut); stats["emboite:" + nom] += 1
                inline(p, el("head", s))
            elif "pl-ead-p-head" in pc:                             # « Notes de l'inventaire manuscrit » / « Notes de l'éditeur »
                liste = el("list", s, type_="deflist")
                inline(p, el("head", liste)); stats["listes_notes"] += 1
            elif "pl-ead-p-note" in pc:
                d = el("defitem", liste if liste is not None else el("list", s, type_="deflist"))
                lab = p.find(H + "span")
                el("label", d, text=norm("".join(lab.itertext())).strip() if lab is not None else "")
                if lab is not None:
                    tail = (lab.tail or "").lstrip(". ")
                    lab.getparent().remove(lab); p.text = (p.text or "") + tail
                inline(p, el("item", d)); stats["notes"] += 1
            elif p.tag == H + "p":
                # guide d'encodage du site : « Chacune des références est saisie dans un élément <bibref> »
                inline(p, el("bibref" if nom == "bibliography" else "p", s))
            else:
                inconnus["dans-section:%s" % p.tag.replace(H, "")] += 1
        if nom == "scopecontent":
            placer_notes(haut)
        stats["section:" + nom] += 1
    if ctrl:
        ca = el("controlaccess", comp)
        for lab, (kind, ts) in ctrl.items():
            sub = el("controlaccess", ca)
            el("head", sub, text=lab)
            for t in ts:
                if kind == "genreform":
                    el("genreform", sub, text=t)
                else:
                    el("name", sub, text=t, role="auteur d’acte")
                stats["terme:" + kind] += 1
    # ordre EAD : did, puis controlaccess, scopecontent… (controlaccess remonté juste après did)
    if ctrl:
        comp.remove(ca); comp.insert(1, ca)
    return comp


def placer_notes(sc):
    """Pleade affichait en fin de regeste les notes que l'EAD portait dans le texte (guide du site : « on a utilisé
    l'élément EAD Note <note>, marqué par un attribut altrender de valeur "ms", afin de distinguer les notes de
    l'Inventaire de celles ajoutées par l'éditeur »). Chaque note revient à la place de son appel (emph[@render='super']
    portant la même lettre / le même chiffre, dans l'ordre) ; sinon la liste reste en fin de regeste."""
    for liste in [l for l in sc.iter(E + "list") if l.get("type") == "deflist"]:
        head = liste.find(E + "head")
        titre = (head.text or "") if head is not None else ""
        ms = "inventaire" in titre.lower()
        items = liste.findall(E + "defitem")
        appels = [x for x in sc.iter(E + "emph") if x.get("render") == "super" and x.getparent().tag != E + "label"
                  and not any(a is liste for a in x.iterancestors())]
        choix, i = [], 0
        for d in items:
            lab = (d.findtext(E + "label") or "").strip()
            while i < len(appels) and (appels[i].text or "").strip() != lab:
                i += 1
            if i == len(appels):
                break
            choix.append((d, appels[i])); i += 1
        if len(choix) != len(items):
            stats["notes_laissees_en_fin (%s)" % ("inventaire" if ms else "éditeur")] += len(items)
            continue
        for d, appel in choix:
            note = etree.Element(E + "note")
            if ms:
                note.set("altrender", "ms")
            note.set("label", (d.findtext(E + "label") or "").strip())   # @n interdit sur note en EAD 2002
            it = d.find(E + "item")
            p = etree.SubElement(note, E + "p"); p.text = it.text
            for x in list(it):
                p.append(x)
            note.tail = appel.tail
            appel.getparent().replace(appel, note)
            stats["notes_replacees (%s)" % ("inventaire" if ms else "éditeur")] += 1
        liste.getparent().remove(liste)


def entete(doc, vol, n_items):
    """eadheader lu dans la page de titre du volume (pl-ead-filedesc, pl-ead-revisiondesc)."""
    h = el("eadheader", langencoding="iso639-2b", countryencoding="iso3166-1", scriptencoding="iso15924",
           dateencoding="iso8601", repositoryencoding="iso15511")
    el("eadid", h, text="ISD-vol%d" % vol, countrycode="FR")
    fd = el("filedesc", h); ts = el("titlestmt", fd)
    f = lambda cls: [x for x in doc.iter() if cls in classes(x)]
    for t in f("pl-ead-titleproper"):
        if t.tag == H + "span":
            inline(t, el("titleproper", ts))
    for a in f("pl-ead-author"):
        inline(a, el("author", ts))
    for e in f("pl-ead-editionstmt"):
        inline(e, el("p", el("editionstmt", fd)))
    ps = el("publicationstmt", fd)
    for p in f("pl-ead-publisher"):
        inline(p, el("publisher", ps)); ps[-1].text = (ps[-1].text or "").strip()
    for a in f("pl-ead-address"):
        ad = el("address", ps)
        for l in a.iter(H + "p"):
            if "pl-ead-addressline" in classes(l):
                inline(l, el("addressline", ad))
    for d in f("pl-ead-date"):
        inline(d, el("date", ps))
    pd = el("profiledesc", h)
    cr = el("creation", pd)
    cr.text = ("Fichier reconstruit le 16 novembre 2026 à partir des %d pages HTML que l'application Pleade "
               "servait pour ce volume (saint-denis.enc.sorbonne.fr, copie locale faite avant la fermeture du site, "
               "septembre 2026) ; l'EAD d'origine n'a pas été retrouvé. " % n_items)
    el("date", cr, text="2026-11-16", normal="20261116")
    lu = el("langusage", pd); el("language", lu, text="français", langcode="fre")
    rd = el("revisiondesc", h)
    for c in f("pl-ead-change"):
        ch = el("change", rd); el("date", ch)
        for it in c.iter(H + "td"):
            inline(it, el("item", ch))
    ch = el("change", rd); el("date", ch, text="16 novembre 2026", normal="20261116")
    el("item", ch, text="Reconstruction en EAD 2002 à partir du rendu HTML de Pleade (voir creation et processinfo).")
    return h


PROCESSINFO = [
    "Éléments lus dans les classes de Pleade (pl-ead-*) : unitid, unittitle, unitdate, physdesc, genreform, emph (@render), "
    "scopecontent, bibliography, odd, titleproper, author, editionstmt, publisher, address, date, change.",
    "Choix de la reconstruction (non lus dans une classe) : les « Types(s) d’auteur d’acte » sont rendus en controlaccess/name"
    "[@role='auteur d’acte'] et les « Types de documents » en controlaccess/genreform, chaque groupe sous son intitulé ; "
    "la ligne « Édition réalisée d’après » en did/note ; les notes que Pleade regroupait en fin de regeste sont remises "
    "à la place de leur appel, en note[@label = l’appel] (note[@altrender='ms'] pour les notes de l’Inventaire, comme le prescrit le "
    "guide d’encodage du site) ; quand l’appel n’a pas été retrouvé, elles restent en fin de regeste en list[@type='deflist'] ; "
    "le tableau de la tradition est en bibliography/bibref (guide d’encodage) ; la « Correspondance avec le cartulaire blanc » en relatedmaterial ; "
    "les « Notes de l’éditeur » des séries en odd ; un second intitulé dans un même bloc (« Références ajoutées par "
    "l’éditeur ») ouvre un bloc emboîté du même nom (bibliography/bibliography), que Pleade affichait à plat.",
    "Les libellés affichés par Pleade sont gardés en @label ; quand Pleade affichait une valeur d’attribut faute de libellé, "
    "elle est remise en @datechar pour les dates (« confirmation », « nst » = nouveau style) et en @type pour les cotes (« ENC »).",
    "Les liens de recherche de Pleade sont réduits à leur terme ; les liens vers les images et les pages du site sont gardés "
    "en extref, sur l’ancien domaine. La ligne « URL de cette page » est omise : elle se déduit de l’identifiant de la notice "
    "(http://saint-denis.enc.sorbonne.fr/inventaire/tomeN/<id sans préfixe>).",
]


def volume(vol):
    pages = {}
    for f in os.listdir(SRC):
        m = re.match(r"ead-fragment\.xsp__c=(ISD-vol%d_[^.]+)\.html$" % vol, f)
        if m:
            pages[m.group(1)] = os.path.join(SRC, f)
    info, enfants_attendus, tete = {}, {}, None
    for cid, p in pages.items():
        doc = lire_page(p)
        if any("pl-ead-filedesc" in classes(x) for x in doc.iter()):
            tete = doc; continue
        i, pos, anc = position(doc)
        bloc = [d for d in doc.iter(H + "div") if "pl-pgd-c" in classes(d)]
        if not bloc or not pos:
            inconnus["page sans position:" + cid] += 1; continue
        niv = next((k.replace("pl-ead-att-level-", "") for k in classes(bloc[0]) if k.startswith("pl-ead-att-level-")), "otherlevel")
        info[cid] = (pos, anc, niv, doc)
        kids = []
        for d in doc.iter(H + "div"):
            if "pl-pgd-children" in classes(d):
                kids = [re.search(r"loadContent\('([^']+)'", a.get("onclick") or "").group(1) for a in d.iter(H + "a") if "loadContent" in (a.get("onclick") or "")]
        enfants_attendus[cid] = kids
    racine = [c for c, v in info.items() if not v[1]]
    assert len(racine) == 1, racine
    racine = racine[0]
    ead = etree.Element(E + "ead", nsmap={None: EAD, "xlink": XLINK, "xsi": XSI})
    ead.set("{%s}schemaLocation" % XSI, EAD + " http://www.loc.gov/ead/ead.xsd")
    ead.append(entete(tete, vol, len(info)))
    pos, anc, niv, doc = info[racine]
    arch = convertir_composant(doc, racine, niv, racine=True)
    arch.set("id", racine)
    ead.append(arch)
    dsc = el("dsc", arch)
    noeud = {racine: dsc}
    for cid in sorted((c for c in info if c != racine), key=lambda c: info[c][0]):
        pos, anc, niv, doc = info[cid]
        parent = noeud[anc[-1]]
        comp = convertir_composant(doc, cid, niv)
        parent.append(comp)
        noeud[cid] = comp
        stats["c:" + niv] += 1
    manquants = [k for c, ks in enfants_attendus.items() for k in ks if k not in info]
    # ordre réel des enfants = celui des listes de Pleade (contrôle)
    desordre = 0
    for c, ks in enfants_attendus.items():
        vus = [x.get("id") for x in (noeud[c] if c != racine else dsc) if x.tag == E + "c"]
        if [k for k in ks if k in info] != vus:
            desordre += 1
    ead_pi = el("processinfo", arch)
    el("head", ead_pi, text="Reconstruction")
    for t in PROCESSINFO:
        el("p", ead_pi, text=t)
    if manquants:
        el("p", ead_pi, text="Notices citées dans le sommaire de Pleade mais absentes de la copie, donc absentes de ce fichier : "
           + ", ".join(m.split("_", 1)[1] for m in manquants) + ".")
    arch.remove(ead_pi); arch.insert(list(arch).index(dsc), ead_pi)
    os.makedirs(OUT, exist_ok=True)
    etree.ElementTree(ead).write(os.path.join(OUT, "ISD-vol%d.xml" % vol), encoding="UTF-8", xml_declaration=True, pretty_print=True)
    return len(info), manquants, desordre


if __name__ == "__main__":
    lignes = ["# Reconstruction EAD de l'Inventaire général de Saint-Denis (16/11/2026)", ""]
    for v in (1, 2, 3):
        n, manq, des = volume(v)
        lignes.append("- ISD-vol%d : %d composants ; manquants : %s ; listes d'enfants dans un autre ordre : %d" % (v, n, ", ".join(manq) or "aucun", des))
        print(lignes[-1])
    lignes += ["", "## Compteurs", ""] + ["- %s : %d" % kv for kv in sorted(stats.items())]
    lignes += ["", "## Structures non reconnues", ""] + (["- %s : %d" % kv for kv in inconnus.most_common()] or ["- aucune"])
    open(os.path.join(HERE, "rapport.md"), "w", encoding="utf-8").write("\n".join(lignes) + "\n")
    print("non reconnus :", dict(inconnus) or "aucun")
