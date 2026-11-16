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

Ce dossier n'est pas lu par DoTS. Le corps des notices des TEI servis (`data/ISD-vol*.xml`) en a été refait le même
jour (`regenerer_tei_v2.py`), dans l'ordre et avec les libellés de l'ancien site (dont la ligne « Regeste bref ») ;
l'en-tête, les sections, les identifiants, les `pb` et les titres des notices sont ceux du TEI de septembre. Le rendu
dans dots-vue a été comparé notice par notice aux pages de l'ancien site, pour les trois volumes.

Les scripts lisent des chemins de la machine où ils ont été écrits : ils documentent la reconstruction plus qu'ils
ne se relancent tels quels.
