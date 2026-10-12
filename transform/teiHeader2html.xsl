<?xml version="1.0" encoding="UTF-8"?>
<!-- Page de titre de Saint-Denis (route /api/dts/cover?id=saint-denis, appliquée à chacun des 11 TEI),
     reprise du modèle de Christofle. Écarts marqués [saint-denis]. -->
<xsl:transform version="2.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns="http://www.w3.org/1999/xhtml"
  xmlns:tei="http://www.tei-c.org/ns/1.0"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  exclude-result-prefixes="tei xs">

  <xsl:output encoding="UTF-8" indent="yes" method="xml" omit-xml-declaration="yes"/>

  <xsl:template match="/">
    <html xmlns="http://www.w3.org/1999/xhtml" lang="fr">
      <div id="aside">to delete</div>
      <div id="center">
        <div id="main">
          <div id="article"><xsl:apply-templates select="//tei:fileDesc/tei:titleStmt"/></div>
        </div>
      </div>
    </html>
  </xsl:template>

  <xsl:template match="tei:titleStmt">
    <!-- [saint-denis] Trois sortes d'éditeurs selon le fichier : <principal> (cartulaire : nom en
         forename/surname ; Dugny : Julien De Nauw), <editor> (pages du site : l'École, en texte),
         ou, pour les tomes de l'Inventaire, seulement les <respStmt> « édition ». On prend la
         première catégorie présente. -->
    <xsl:variable name="editeurs" as="xs:string*"
      select="if (tei:principal) then
                for $p in tei:principal return normalize-space(concat($p/tei:forename[1], ' ', $p/tei:surname[1]))
              else if (tei:author) then
                for $p in tei:author return normalize-space($p)
              else if (tei:editor) then
                for $p in tei:editor return normalize-space($p)
              else
                for $r in tei:respStmt[normalize-space(tei:resp) = 'édition']/tei:name return normalize-space($r)"/>
    <div class="titlestmt">
      <!-- Premier titre uniquement -->
      <h1 class="head">
        <xsl:value-of select="normalize-space(tei:title[1])"/>
      </h1>

      <xsl:if test="exists($editeurs)">
        <p class="editors">
          <span class="editors-label">Édité par </span>
          <xsl:for-each select="$editeurs">
            <span class="editor"><xsl:value-of select="."/></span>
            <xsl:choose>
              <xsl:when test="position() = last() - 1"> et </xsl:when>
              <xsl:when test="position() &lt; last()">, </xsl:when>
            </xsl:choose>
          </xsl:for-each>
        </p>
      </xsl:if>

      <!-- [saint-denis] « Édition électronique » seulement quand le TEI nomme une personne pour la
           modélisation ou la publication électronique (cartulaire : Florence Clavaud). Absent des
           tomes de l'Inventaire et des pages du site : rien n'est affiché. -->
      <xsl:if test="tei:respStmt[contains(tei:resp, 'modélisation') or contains(tei:resp, 'publication')]">
        <p class="editors">
          <span class="editors-label">Édition électronique par </span>
          <xsl:for-each select="tei:respStmt[contains(tei:resp, 'modélisation') or contains(tei:resp, 'publication')]/tei:name">
            <span class="editor"><xsl:value-of select="normalize-space(.)"/></span>
            <xsl:choose>
              <xsl:when test="position() = last() - 1"> et </xsl:when>
              <xsl:when test="position() &lt; last()">, </xsl:when>
            </xsl:choose>
          </xsl:for-each>
        </p>
      </xsl:if>

      <!-- [saint-denis] publicationStmt/date vaut « 2010-.... » ou « 2010 » selon le fichier : on n'affiche que l'année. -->
      <span class="date">
        <xsl:value-of select="replace(normalize-space(../tei:publicationStmt/tei:date[1]), '^\D*(\d{4}).*$', '$1')"/>
      </span>
    </div>
  </xsl:template>

</xsl:transform>
