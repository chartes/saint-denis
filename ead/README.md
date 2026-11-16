EAD de l'Inventaire général des chartes de Saint-Denis
===

`ISD-vol1.xml`, `ISD-vol2.xml` et `ISD-vol3.xml` : l'Inventaire général (Archives nationales, LL 1189 à 1191) en
EAD 2002, un fichier par volume, comme dans l'édition d'origine (2008-2010).

**Ce ne sont pas les fichiers d'origine.** Les EAD de l'application Pleade (saint-denis.enc.sorbonne.fr, fermé en
septembre 2026) n'ont été retrouvés ni sur les serveurs ni dans la Wayback Machine. Ils ont été reconstruits le
16 novembre 2026 à partir des pages HTML que Pleade servait (copie faite avant la fermeture) : Pleade gardait dans
ses classes le nom de l'élément EAD rendu, et chaque page donnait sa position dans l'arbre. Les choix de la
reconstruction sont décrits dans chaque fichier (`archdesc/processinfo`) ; ils suivent le guide d'encodage du site
(`data/saint-denis-site.xml`) quand il est explicite (`bibliography/bibref`, `note[@altrender="ms"]`).

Contrôles : valides EAD 2002 (schéma de la Library of Congress) ; 3 307 composants, aucune page manquante ;
aucun mot perdu par rapport aux pages Pleade (`verifier_texte.py`).

Ce dossier n'est pas lu par DoTS. Les TEI servis (`data/ISD-vol*.xml`) en ont été refaits le même jour
(`regenerer_tei.py`) : contenu et balisage repris de l'EAD, charpente DoTS (en-tête, identifiants, `pb`, titres)
gardée ; 3 270 notices sur 3 285, les 15 autres inchangées.

Les scripts lisent des chemins de la machine où ils ont été écrits : ils documentent la reconstruction plus qu'ils
ne se relancent tels quels.
