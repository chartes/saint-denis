<?xml version="1.0" encoding="UTF-8"?>
<!-- Page de titre de Saint-Denis (route /api/dts/cover) : modèle commun page-de-titre.xsl.
     Écart : éditeurs : principal, author, editor ou respStmt « édition » ; édition électronique = modélisation/publication. -->
<xsl:transform version="2.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns="http://www.w3.org/1999/xhtml"
  xmlns:tei="http://www.tei-c.org/ns/1.0"
  exclude-result-prefixes="tei">

  <xsl:import href="page-de-titre.xsl"/>

  <xsl:variable name="th-editeurs" select="
    if ($th-ts/tei:principal) then $th-ts/tei:principal
    else if ($th-ts/tei:author) then $th-ts/tei:author
    else if ($th-ts/tei:editor) then $th-ts/tei:editor
    else $th-ts/tei:respStmt[normalize-space(tei:resp) = 'édition']/tei:name"/>
  <xsl:variable name="th-edition-electronique" select="$th-ts/tei:respStmt[contains(tei:resp, 'modélisation') or contains(tei:resp, 'publication')]/tei:name"/>
</xsl:transform>
