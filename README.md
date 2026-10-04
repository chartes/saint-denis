Chartes médiévales de l'abbaye de Saint-Denis (VIIe-XIIIe siècle)
===

Édition dirigée par Olivier Guyotjeannin (École nationale des chartes – PSL). Première publication : ÉLEC 3, `http://saint-denis.enc.sorbonne.fr/` (site fermé en septembre 2026).

Deux compilations éditées en parallèle : le **Cartulaire blanc** de l'abbaye (dernier quart du XIIIe siècle), édité chapitre par chapitre, et l'**Inventaire général** du chartrier (compilé de 1680 à 1728), en regestes jusqu'en 1302.

## Les 11 ressources (`data/`)

| Fichier | Contenu | Unités | Origine |
|---|---|---|---|
| `beaurain.xml`, `dugny.xml`, `pierrefitte.xml`, `rueil.xml`, `saint-martin.xml`, `tremblay.xml`, `ully.xml` | Cartulaire blanc, un chapitre par fichier | 113, 65, 38, 73, 72, 56, 102 | TEI d'origine de l'édition (Florence Clavaud, 2008-2015), versé en 2018 |
| `ISD-vol1.xml`, `ISD-vol2.xml`, `ISD-vol3.xml` | Inventaire général, Archives nationales LL 1189 à 1191 | 1 207, 2 040, 58 | notices reprises du site publié avant sa fermeture (12/09/2026) |
| `saint-denis-site.xml` | pages éditoriales du site (présentation, introduction, aides) | 50 | reprises du site historique (10/09/2026) |

Chaque fichier porte son `revisionDesc` : les modifications de la migration (2026) y sont consignées.

## Structure DoTS

```
data/                                les 11 TEI, et data/illustrations/ (2 images d'Ully)
metadata/collection.tsv              métadonnées de la collection
metadata/documents_metadata.tsv      métadonnées des 11 ressources
metadata/dots_metadata_mapping.xml   règles de métadonnées (espace de noms dots-suite)
schema/                              schéma du corpus
transform/saint-denis.xsl            feuille de rendu, au nom de la collection ; importe hteiml
```

## Déploiement

- La feuille vise le serveur de dev : `$elec-base = '/elec'` et import `../../renderers/hteiml/xsl/tei2html.xsl`. La copie servie en local (`dots-clean`) porte `''`, `../hteiml/xsl/tei2html.xsl` et, pour les PDF et ZIP, `http://127.0.0.1:8081`.
- La feuille ne lit aucun fichier compagnon (`document()`) : rien à poser à côté d'elle.
- **Les images ne sont pas dans ce dépôt** : fac-similés du Cartulaire blanc et de l'Inventaire, vignettes, PDF d'illustrations et archives ZIP. La feuille les appelle sous `/images/saint-denis/` et `/elec/images/saint-denis/telechargements/` : à déposer avec l'application avant la mise en ligne, sinon les images et les téléchargements seront cassés.
- Les renvois au Du Cange visent l'édition Du Cange de l'École servie par DoTS (`/ducange/document/ducange_<initiale>?refId=<ENTRÉE>`), plus l'ancien site.
