# -*- coding: utf-8 -*-
"""verifier_texte.py (2026-11-16) — pour chaque page Pleade, compare les mots du contenu affiché (cellules du tableau
d'identification, blocs de texte, intitulés de blocs) avec ceux du composant EAD reconstruit. Les libellés de lignes
(<th>), les boutons, le fil d'ancêtres, la liste des enfants et l'URL de la page sont exclus des deux côtés."""
import collections, os, re, sys
from lxml import etree
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import reconstruire_ead as R

sys.stdout.reconfigure(encoding="utf-8")
H, E = R.H, R.E


def mots(s):
    return collections.Counter(re.findall(r"\w+", s.lower()))


def texte_html(doc):
    bloc = [d for d in doc.iter(H + "div") if "pl-pgd-c" in R.classes(d)][0]
    out = []
    def walk(n):
        if not isinstance(n.tag, str):
            return
        cl = R.classes(n)
        if n.tag in (H + "th", H + "button") or "pl-tbl-refurl" in cl or "pl-pgd-children" in cl or "pl-bttn-sync" in cl:
            return
        if n.text: out.append(n.text)
        for c in n:
            walk(c)
            if c.tail: out.append(c.tail)
    walk(bloc)
    return " ".join(out)


def texte_ead(c):
    out = []
    for n in c.iter():
        if n.tag == E + "c" and n is not c:
            continue
    def walk(n):
        if n.tag in (E + "c", E + "processinfo", E + "dsc") and n is not c:
            return
        if n.tag == E + "controlaccess" and n.getparent() is not None and n.getparent().tag == E + "controlaccess":
            pass
        if n.text: out.append(n.text)
        for x in n:
            walk(x)
            if x.tail: out.append(x.tail)
    walk(c)
    return " ".join(out)


if __name__ == "__main__":
    ecarts, total = [], 0
    for vol in (1, 2, 3):
        ead = etree.parse(os.path.join(R.OUT, "ISD-vol%d.xml" % vol))
        comps = {c.get("id"): c for c in ead.iter(E + "c", E + "archdesc")}
        for f in os.listdir(R.SRC):
            m = re.match(r"ead-fragment\.xsp__c=(ISD-vol%d_[^.]+)\.html$" % vol, f)
            if not m or m.group(1) not in comps:
                continue
            doc = R.lire_page(os.path.join(R.SRC, f))
            a, b = mots(texte_html(doc)), mots(texte_ead(comps[m.group(1)]))
            # les intitulés de groupes d'index (« Type(s) d'auteur d'acte ») sont ajoutés côté EAD : on les retire
            for lab in ("type", "s", "d", "auteur", "acte", "types", "de", "documents"):
                pass
            manque, ajout = a - b, b - a
            total += 1
            if manque or ajout:
                ecarts.append((m.group(1), dict(manque), dict(ajout)))
    print("pages comparées :", total, "; pages avec écart :", len(ecarts))
    perdus = collections.Counter(); ajoutes = collections.Counter()
    for cid, m, a in ecarts:
        perdus.update(m); ajoutes.update(a)
    print("mots perdus (toutes pages) :", perdus.most_common(15))
    print("mots ajoutés (toutes pages) :", ajoutes.most_common(15))
    for e in ecarts[:5]:
        print("  ", e)
