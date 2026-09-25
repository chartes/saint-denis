<?xml version="1.0" encoding="UTF-8"?>
<xsl:transform version="1.1"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns="http://www.w3.org/1999/xhtml"
  xmlns:tei="http://www.tei-c.org/ns/1.0"
  exclude-result-prefixes="tei">

  <xsl:import href="../hteiml/xsl/tei2html.xsl"/>
  <xsl:output indent="no"/><!-- autopilote 2026-09-11 : sinon DoTS-vue colle les mots (condense) -->

  <xsl:template match="tei:summary" priority="20">
    <div class="summary"><xsl:apply-templates/></div>
  </xsl:template>

  <xsl:template match="tei:summary" mode="a" priority="20">
    <span class="summary"><xsl:apply-templates/></span>
  </xsl:template>

  <xsl:template match="tei:msName" priority="20">
    <span class="msName"><xsl:apply-templates/></span>
  </xsl:template>

  <xsl:template match="tei:msName" mode="a" priority="20">
    <span class="msName"><xsl:apply-templates/></span>
  </xsl:template>

  <xsl:template match="tei:am" priority="20">
    <span class="am"><xsl:apply-templates/></span>
  </xsl:template>

  <xsl:template match="tei:am" mode="a" priority="20">
    <span class="am"><xsl:apply-templates/></span>
  </xsl:template>

  <!-- B1f (autopilote 2026-09-11) : en-tête des actes. La générique rend docAuthor, docDate et
       placeName en <span> contigus (« roi de France774, décembrePalais de Samoussy »).
       Ancien site (fragments Pleade) : <h1>titre</h1><p class="tei-docDate">date. — lieu</p>,
       plusieurs dates avec le texte qui les sépare (« ou »), docAuthor non affiché.
       On reprend la ligne de date à l'identique ; docAuthor reste affiché, sur sa propre ligne
       (le masquer comme l'ancien site : décision en attente). -->
  <xsl:template match="tei:front/tei:docAuthor" priority="12">
    <xsl:if test="not(preceding-sibling::tei:docAuthor)">
      <p class="sd-docAuthor">
        <xsl:for-each select="../tei:docAuthor">
          <xsl:if test="position() &gt; 1"><xsl:text> ; </xsl:text></xsl:if>
          <span class="docAuthor"><xsl:apply-templates/></span>
        </xsl:for-each>
      </p>
    </xsl:if>
  </xsl:template>

  <xsl:template match="tei:front/tei:docDate" priority="12">
    <p class="docDate sd-docDate"><xsl:apply-templates/></p>
  </xsl:template>

  <xsl:template match="tei:front/tei:docDate/text()[normalize-space() = '']" priority="12"/>

  <xsl:template match="tei:front/tei:docDate/tei:placeName" priority="12">
    <xsl:text>. — </xsl:text>
    <xsl:apply-imports/>
  </xsl:template>

  <!-- B1h (autopilote 2026-09-11) : apparat critique.
       (1) identifiants : la générique fabrique l'id d'un <app> depuis son @n (« appa ») et le pose deux fois
       (span.app ET appel, « appa_ ») ; un même @n revient dans un acte (22 actes, 41 fois), les appels
       menaient alors à la première note de même lettre. De même, les div sans xml:id d'un fragment
       reçoivent « div1 », « div2 » en front ET en body (ids en double dans les 512 actes).
       On surcharge le modèle nommé « id » : app et div sans xml:id d'un acte → id unique préfixé par
       l'acte ; tout le reste repasse par le modèle d'origine (même corps, match="*" mode="id").
       (2) lemme : <lem><choice><sic/><corr/></choice></lem> + note « sic B pour … » ; l'ancien site
       affichait la leçon du manuscrit (sic), la générique affiche corr et rend la note absurde (25 cas). -->
  <xsl:template name="id">
    <xsl:param name="prefix"/>
    <xsl:param name="suffix"/>
    <xsl:choose>
      <xsl:when test="(self::tei:app or self::tei:div) and not(@xml:id) and ancestor::tei:text[@xml:id]">
        <xsl:value-of select="$prefix"/>
        <xsl:value-of select="ancestor::tei:text[@xml:id][1]/@xml:id"/>
        <xsl:choose>
          <xsl:when test="self::tei:app">
            <xsl:text>-app</xsl:text>
            <xsl:number count="tei:app" level="any" from="tei:text[@xml:id]"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:text>-div</xsl:text>
            <xsl:number count="tei:div" level="any" from="tei:text[@xml:id]"/>
          </xsl:otherwise>
        </xsl:choose>
        <xsl:value-of select="$suffix"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:apply-templates select="." mode="id">
          <xsl:with-param name="prefix" select="$prefix"/>
          <xsl:with-param name="suffix" select="$suffix"/>
        </xsl:apply-templates>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- span.app sans id (l'appel porte déjà « …_ ») ; appel marqué app-ref (contrôle d'apparat). -->
  <xsl:template match="tei:app" priority="12">
    <span class="app">
      <xsl:apply-templates select="tei:lem"/>
      <xsl:call-template name="noteref">
        <xsl:with-param name="class">noteref app-ref</xsl:with-param>
      </xsl:call-template>
    </span>
  </xsl:template>

  <xsl:template match="tei:lem//tei:choice[tei:sic][tei:corr]" priority="12">
    <em class="sic"><xsl:apply-templates select="tei:sic/node()"/></em>
  </xsl:template>

  <!-- B1g (autopilote 2026-09-11) : tradition des actes. La générique rend chaque listWit en <ul>,
       chaque témoin en <li> et, pour un témoin sans <label>, affiche son xml:id comme un sigle
       (« ully<sup>-acte3-indiqué-i-noir</sup> », 1 552 témoins « Indiqué »).
       Ancien site (fragments Pleade) : un paragraphe par liste, libellé tiré du suffixe de l'xml:id
       (« Originaux : », « Copies : », « Éditions : » ; « Indiqué : » en tête de bloc), témoins séparés
       par « — ». Les 3 listes sans xml:id (« Autre tradition », rueil-acte47 « Indiqué ») n'y étaient
       pas affichées : on les rend ici avec leur propre head. -->
  <xsl:template match="tei:div[@type='tradition']/tei:listWit[tei:listWit]" priority="12">
    <div class="sd-tradition"><xsl:apply-templates select="tei:listWit"/></div>
  </xsl:template>

  <xsl:template match="tei:div[@type='tradition']/tei:listWit/tei:listWit" priority="12">
    <xsl:variable name="id" select="concat(@xml:id, '#')"/>
    <xsl:variable name="type">
      <xsl:choose>
        <xsl:when test="contains($id, '-originaux#')">orig</xsl:when>
        <xsl:when test="contains($id, '-copies#')">cop</xsl:when>
        <xsl:when test="contains($id, '-editions#')">edi</xsl:when>
        <xsl:when test="contains($id, '-indiqué#')">ind</xsl:when>
        <xsl:otherwise>autre</xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:variable name="label">
      <xsl:choose>
        <xsl:when test="$type = 'orig'">Originaux</xsl:when>
        <xsl:when test="$type = 'cop'">Copies</xsl:when>
        <xsl:when test="$type = 'edi'">Éditions</xsl:when>
        <xsl:when test="$type = 'ind'">Indiqué</xsl:when>
        <xsl:otherwise><xsl:value-of select="normalize-space(tei:head)"/></xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:variable name="witnesses">
      <xsl:for-each select="tei:witness">
        <xsl:if test="position() &gt; 1"><xsl:text> — </xsl:text></xsl:if>
        <span class="witness">
          <xsl:if test="@xml:id"><xsl:attribute name="id"><xsl:value-of select="@xml:id"/></xsl:attribute></xsl:if>
          <xsl:apply-templates/>
        </span>
      </xsl:for-each>
    </xsl:variable>
    <xsl:choose>
      <xsl:when test="$type = 'ind' or ($type = 'autre' and tei:head)">
        <div class="sd-listWit sd-docs-{$type}">
          <xsl:if test="@xml:id"><xsl:attribute name="id"><xsl:value-of select="@xml:id"/></xsl:attribute></xsl:if>
          <p class="listWit-head"><b><xsl:value-of select="$label"/><xsl:text>&#160;:</xsl:text></b></p>
          <p class="sd-witnesses"><xsl:copy-of select="$witnesses"/></p>
        </div>
      </xsl:when>
      <xsl:otherwise>
        <p class="sd-listWit sd-docs-{$type}">
          <xsl:if test="@xml:id"><xsl:attribute name="id"><xsl:value-of select="@xml:id"/></xsl:attribute></xsl:if>
          <xsl:if test="$label != ''">
            <span class="listWit-head"><b><xsl:value-of select="$label"/><xsl:text>&#160;: </xsl:text></b></span>
          </xsl:if>
          <xsl:copy-of select="$witnesses"/>
        </p>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- ================================================================
       Racine de la ressource : n'afficher que le PREMIER texte.

       Sans `ref`, DoTS Vue demande le document entier
       (`document?resource=beaurain&amp;mediaType=html`) : la generique rend la page
       de garde issue du teiHeader PUIS tout le corps (1,4 Mo de HTML), soit
       l'edition complete empilee sous la page d'accueil.

       Sur ELEC, chaque chapitre du cartulaire s'ouvre sur sa seule introduction ; les
       actes passent par le sommaire.

       On neutralise donc, au seul rendu du document complet, tout ce qui suit
       la premiere unite citable. Les fragments sont servis dans un
       <dts:wrapper> SANS teiHeader ni <text> : les motifs ci-dessous, ancres
       sur `tei:TEI[tei:teiHeader]/tei:text`, ne les atteignent pas.
       Meme correctif que christofle.xsl et chroniqueslatines.xsl.
       ================================================================ -->
  <!-- Ne garder que l'introduction du chapitre : pas les actes. -->
  <xsl:template match="tei:TEI[tei:teiHeader]/tei:text/tei:group" priority="15"/>
  <xsl:template match="tei:TEI[tei:teiHeader]/tei:text/tei:back" priority="15"/>



  <!--
    Saint-Denis : appel et note sont deux elements distincts relies par @target
       appel : <ref type="note" n="2" target="#beaurain-acte1-n-2"/>
       note  : <note xml:id="beaurain-acte1-n-2">…</note>  (sans @target retour)

    La generique emet <a href="#{id-genere-de-l-appel}" id="{id-genere}_"> : le
    lien aller pointe vers l'appel (au lieu de la note) et l'ancre de retour ne
    correspond pas au retour de la note (qui vise #{id-de-la-note}_). Les 767
    appels sont casses dans les deux sens.

    Correctif : href = la cible (@target = la note) ; ancre de l'appel =
    #{id-de-la-note}_ pour recevoir le lien retour de la note.
  -->
  <xsl:template match="tei:ref[@type='note']">
    <xsl:variable name="noteid" select="substring-after(@target, '#')"/>
    <!-- B1h : une même note appelée deux fois (regeste + transcription) : le 1er appel garde « id_ »
         (cible du retour), les suivants « id_2 », « id_3 »… (sinon id en double). -->
    <xsl:variable name="rang" select="count(preceding::tei:ref[@type='note'][@target = current()/@target])"/>
    <a class="noteref" href="#{$noteid}">
      <xsl:attribute name="id">
        <xsl:value-of select="$noteid"/>
        <xsl:text>_</xsl:text>
        <xsl:if test="$rang &gt; 0"><xsl:value-of select="$rang + 1"/></xsl:if>
      </xsl:attribute>
      <sup>
        <xsl:choose>
          <xsl:when test="@n"><xsl:value-of select="@n"/></xsl:when>
          <xsl:otherwise><xsl:call-template name="note-n"/></xsl:otherwise>
        </xsl:choose>
      </sup>
    </a>
  </xsl:template>

  <!--
    Notes SANS xml:id (gloses editoriales inline : « place du marche… », « Sic B
    pour… »). La generique les traite comme des appels de note et emet des
    <a href="#noteN"> orphelins (pierrefitte, tremblay). Ce sont de courtes
    gloses au fil du texte : on les rend inline entre crochets. Les notes
    d'apparat identifiees (xml:id, deportees dans div[@type='notes']) ne sont pas
    concernees.
  -->
  <xsl:template match="tei:note[not(@xml:id) and not(parent::tei:div[@type = 'notes'])]" priority="8">
    <span class="gloss"> [<xsl:apply-templates/>]</span>
  </xsl:template>

  <!--
    Les gloses precedentes restaient collectees par la passe hors flux (mode
    'fn'), qui n'ecarte que les notes filles de div/front/back/app/notesStmt.
    Les notes filles de <quote> etaient donc rendues DEUX fois : en glose inline
    et en note de bas de page, cette derniere avec un lien de retour vers une
    ancre jamais emise (13 cas dans rueil, aucun ailleurs).
  -->
  <xsl:template match="tei:note[not(@xml:id)][parent::tei:quote]" mode="fn" priority="9"/>

  <!--
    Appels dont la note cible est absente du TEI source (7 cas dans beaurain :
    beaurain-acte33-n-5, acte87-n-4, acte87-n-13, acte87-n-14, acte106-n-3).
    Lacune de l'edition d'origine, pas de la migration : on affiche l'appel sans
    lien plutot qu'un lien mort.
  -->
  <xsl:key name="sd-note-by-id" match="tei:note[@xml:id]" use="@xml:id"/>
  <xsl:key name="sd-ref-by-target" match="tei:ref[@type='note'][@target]" use="substring-after(@target, '#')"/>

  <xsl:template match="tei:ref[@type='note'][not(key('sd-note-by-id', substring-after(@target, '#')))]" priority="9">
    <sup class="noteref-orphan">
      <xsl:choose>
        <xsl:when test="@n"><xsl:value-of select="@n"/></xsl:when>
        <xsl:otherwise><xsl:call-template name="note-n"/></xsl:otherwise>
      </xsl:choose>
    </sup>
  </xsl:template>

  <!--
    Les notes editoriales de Saint-Denis sont deja deportees dans un
    <div type="notes">. Ce conteneur ne doit pas etre rendu dans le flux
    principal : sinon la generique transforme une premiere fois chaque <note>
    en appel et l'on obtient le bloc parasite ou toutes les notes valent « 1 ».
    Leur corps est emis une seule fois par la collecte hors flux ci-dessous.
  -->
  <xsl:template match="tei:div[@type = 'notes' or @type = 'footnotes']" priority="30"/>

  <!--
    Les notes deportees n'ont pas toujours @n : reprendre le numero porte par
    l'appel <ref type="note" n="…"> qui pointe vers elles.

    Important : footnotes() de hteiml parcourt le mode fn trois fois
    (author/editor/sans @resp). La surcharge doit donc respecter le parametre
    $resp, sinon chaque note est rendue trois fois.
  -->
  <xsl:template match="tei:div[@type = 'notes' or @type = 'footnotes']//tei:note[@xml:id]" mode="fn" priority="20">
    <xsl:param name="resp"/>
    <xsl:if test="($resp = '' and not(@resp))
                  or (@resp and @resp = $resp)
                  or ($resp = '' and @resp and @resp != 'author' and @resp != 'editor')">
      <aside class="note" id="{@xml:id}">
        <!-- autopilote 2026-09-11 : lien retour seulement si un appel vise la note (lacunes de la source,
             ex. rueil-acte23-n-, ully-acte3-n-1 à 3) ; sinon numéro sans lien. -->
        <xsl:choose>
          <xsl:when test="key('sd-ref-by-target', @xml:id)">
            <a class="noteback" href="#{@xml:id}_">
          <xsl:choose>
            <xsl:when test="key('sd-ref-by-target', @xml:id)[1]/@n">
              <xsl:value-of select="key('sd-ref-by-target', @xml:id)[1]/@n"/>
            </xsl:when>
            <xsl:when test="contains(@xml:id, '-n-')">
              <xsl:value-of select="substring-after(@xml:id, '-n-')"/>
            </xsl:when>
            <xsl:otherwise>
              <xsl:number count="tei:div[@type = 'notes' or @type = 'footnotes']//tei:note[@xml:id]" level="any" from="/"/>
            </xsl:otherwise>
          </xsl:choose>
          <xsl:text>. </xsl:text>
        </a>
          </xsl:when>
          <xsl:otherwise>
            <span class="noteback-orphan">
          <xsl:choose>
            <xsl:when test="key('sd-ref-by-target', @xml:id)[1]/@n">
              <xsl:value-of select="key('sd-ref-by-target', @xml:id)[1]/@n"/>
            </xsl:when>
            <xsl:when test="contains(@xml:id, '-n-')">
              <xsl:value-of select="substring-after(@xml:id, '-n-')"/>
            </xsl:when>
            <xsl:otherwise>
              <xsl:number count="tei:div[@type = 'notes' or @type = 'footnotes']//tei:note[@xml:id]" level="any" from="/"/>
            </xsl:otherwise>
          </xsl:choose>
          <xsl:text>. </xsl:text>
        </span>
          </xsl:otherwise>
        </xsl:choose>
        <xsl:apply-templates/>
      </aside>
    </xsl:if>
  </xsl:template>


  <!-- ================================================================
       Saint-Denis V2 — pages éditoriales historiques + recherche ES
       ================================================================ -->

  <!-- Conteneurs de la ressource saint-denis-site.xml -->
  <xsl:template match="tei:div[@type='rubrique']" priority="12">
    <section class="sd-rubrique">
      <xsl:if test="@xml:id">
        <xsl:attribute name="id"><xsl:value-of select="@xml:id"/></xsl:attribute>
      </xsl:if>
      <h1 class="sd-rubrique-title"><xsl:value-of select="tei:head[1]"/></h1>
      <xsl:apply-templates select="node()[not(self::tei:head[1])]"/>
    </section>
  </xsl:template>

  <xsl:template match="tei:div[@type='part']" priority="12">
    <section class="sd-part">
      <xsl:if test="@xml:id">
        <xsl:attribute name="id"><xsl:value-of select="@xml:id"/></xsl:attribute>
      </xsl:if>
      <h2 class="sd-part-title"><xsl:value-of select="tei:head[1]"/></h2>
      <xsl:apply-templates select="node()[not(self::tei:head[1])]"/>
    </section>
  </xsl:template>

  <xsl:template match="tei:div[@type='subpart']" priority="12">
    <section class="sd-subpart">
      <xsl:if test="@xml:id">
        <xsl:attribute name="id"><xsl:value-of select="@xml:id"/></xsl:attribute>
      </xsl:if>
      <h3 class="sd-subpart-title"><xsl:value-of select="tei:head[1]"/></h3>
      <xsl:apply-templates select="node()[not(self::tei:head[1])]"/>
    </section>
  </xsl:template>

  <xsl:template match="tei:div[@type='page']" priority="12">
    <article class="sd-static-page">
      <xsl:if test="@xml:id">
        <xsl:attribute name="id"><xsl:value-of select="@xml:id"/></xsl:attribute>
      </xsl:if>
      <xsl:if test="@corresp">
        <xsl:attribute name="data-legacy-source"><xsl:value-of select="@corresp"/></xsl:attribute>
      </xsl:if>
      <h1 class="sd-page-title"><xsl:value-of select="tei:head[1]"/></h1>
      <xsl:apply-templates select="node()[not(self::tei:head[1])]"/>
    </article>
  </xsl:template>

  <xsl:template match="tei:p[starts-with(@rend,'heading-h2')]" priority="12">
    <h2 class="sd-legacy-h2"><xsl:apply-templates/></h2>
  </xsl:template>
  <xsl:template match="tei:p[starts-with(@rend,'heading-h3')]" priority="12">
    <h3 class="sd-legacy-h3"><xsl:apply-templates/></h3>
  </xsl:template>
  <xsl:template match="tei:p[starts-with(@rend,'heading-h4')]" priority="12">
    <h4 class="sd-legacy-h4"><xsl:apply-templates/></h4>
  </xsl:template>

  <!-- Page « Recherche » : DoTS-vue compile le fragment comme un template Vue et
       n'exécute pas les <script> ; la recherche plein texte passe par l'index
       dots-cli-es et l'interface de recherche de DoTS-vue, pas par la XSL. -->
  <xsl:template match="tei:div[@type='search']" priority="30">
    <section class="sd-search" id="sd-search">
      <h2>Rechercher dans les chartes éditées</h2>
      <p class="sd-search-help">La recherche plein texte dans les actes du Cartulaire blanc
        (Beaurain, Dugny, Pierrefitte, Rueil, Saint-Martin, Tremblay, Ully) se fait avec le
        moteur de recherche de l’application, alimenté par l’index dots-cli-es.</p>
      <!-- autopilote 2026-09-11 : route DoTS-vue déclarée dans saint-denis.conf.json (customRoutes) -->
      <p class="sd-search-go"><a class="sd-search-link" href="/saint-denis/search">Ouvrir la recherche plein texte</a></p>
    </section>
  </xsl:template>


  <!-- ================================================================
       D21 (2026-09-12) : Inventaire général des chartes de Saint-Denis.
       Il était servi par l'ancien site (497 renvois depuis les TEI de l'édition) et n'existait
       pas dans DoTS. Les trois volumes y sont versés comme ressources ISD-vol1 à 3 : sections
       (« Chartes décrites sous les nos 155-167, Années 901-1000 ») et notices, chacune avec ses
       champs et le texte de son regeste. Le rendu reprend la présentation du site : le numéro et
       le regeste bref en titre, les champs en liste de définitions, puis l'édition du regeste.
       ================================================================ -->
  <xsl:template match="tei:div[@type = 'notice']" priority="14">
    <article class="isd-notice" id="{@xml:id}">
      <h3 class="isd-notice-head"><xsl:apply-templates select="tei:head[1]/node()"/></h3>
      <xsl:apply-templates select="node() except tei:head[1]"/>
    </article>
  </xsl:template>

  <xsl:template match="tei:div[@type = 'section']" priority="14">
    <section class="isd-section" id="{@xml:id}">
      <h2 class="isd-section-head"><xsl:apply-templates select="tei:head[1]/node()"/></h2>
      <xsl:apply-templates select="node() except tei:head[1]"/>
    </section>
  </xsl:template>

  <!-- 2026-09-25 : les rubriques internes d'une notice étaient encodées <head type="section">.
       TEI n'admet un <head> qu'en tête de son <div> (model.divTop) : placé après la liste des
       champs ou après un <p>, il est refusé — d'où 9 333 erreurs contre tei_all dans les trois
       volumes. Arbitrage pris sur la source, encore en ligne (Pleade/EAD,
       saint-denis.enc.sorbonne.fr, relevé le 2026-09-25, trois notices témoins, une par tome) :
       ces rubriques n'y sont pas des titres. Ce sont les <head> EAD de <scopecontent>,
       <bibliography>, <odd> et du bloc éditorial « cart-links », rendus en
       <p class="pl-pgd-head…"> — jamais en <h1>-<h6> — au même titre que les <th> du tableau
       de champs, que nous encodons déjà en <label>. La conversion HTML→TEI a confondu le <head>
       d'EAD (une rubrique) avec celui de TEI (le titre d'une division) : on les rend donc à
       <label type="section">, l'élément TEI des étiquettes, comme les champs courts voisins.
       Le rendu ne bouge pas d'un octet : on reprend ici le modèle générique de tei:head
       (hteiml/xsl/tei2html.xsl, l. 441), niveau de titre calculé de la même façon pour que les
       fragments DoTS gardent le leur, classe « head section notice » et signet inchangés. -->
  <xsl:template match="tei:div[@type = 'notice']/tei:label[@type = 'section']" priority="14">
    <xsl:variable name="level" select="count(ancestor::tei:*) - 2"/>
    <xsl:variable name="name">
      <xsl:choose>
        <xsl:when test="normalize-space(.) = ''"/>
        <xsl:when test="$level &lt; 1">h1</xsl:when>
        <xsl:when test="$level &gt; 7">h6</xsl:when>
        <xsl:otherwise>h<xsl:value-of select="$level"/></xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:if test="$name != ''">
      <xsl:apply-templates select="tei:pb"/>
      <xsl:element name="{$name}" namespace="http://www.w3.org/1999/xhtml">
        <xsl:attribute name="class">head section notice</xsl:attribute>
        <xsl:apply-templates select="node()[local-name() != 'pb']"/>
        <xsl:if test="not(following-sibling::*[1][self::tei:head or self::tei:label])
                      and $format != $epub2 and $format != $epub3">
          <xsl:variable name="bookmark-href"><xsl:for-each select="ancestor::tei:div[1]"><xsl:call-template name="href"/></xsl:for-each></xsl:variable>
          <xsl:if test="normalize-space($bookmark-href) != ''">
            <a class="bookmark" href="{$bookmark-href}"><xsl:text> §</xsl:text></a>
          </xsl:if>
        </xsl:if>
      </xsl:element>
    </xsl:if>
  </xsl:template>

  <!-- Corollaire du point précédent : la table des matières de hteiml (nav/ol.tree, servie par
       l'API avec le document comme avec le fragment) compose l'intitulé d'une unité en
       chaînant TOUS ses <head> enfants (common.xsl, l. 679 : for-each tei:head[not(@type='sub')],
       séparés par « . »). Une notice y figurait donc sous « N° 3196. Édition du regeste.
       Références données par l'Inventaire général… ». Les rubriques n'étant plus des <head>,
       cet intitulé se réduirait au seul titre : ce serait mieux, mais ce serait changer ce qui
       s'affiche, ce que ce chantier s'interdit. On rend donc l'intitulé à l'identique, rubriques
       comprises. Les 9 333 rubriques sont du texte nu, sans balise ni espace final (vérifié),
       d'où le simple normalize-space() là où un <head> passerait par son mode title.
       À rouvrir si l'on veut un jour raccourcir ces intitulés : il suffira de retirer
       tei:label du for-each ci-dessous. -->
  <xsl:template match="tei:div[@type = 'notice']" mode="a" priority="14">
    <xsl:param name="class"/>
    <a>
      <xsl:attribute name="href"><xsl:call-template name="href"/></xsl:attribute>
      <xsl:if test="$class">
        <xsl:attribute name="class"><xsl:value-of select="$class"/></xsl:attribute>
      </xsl:if>
      <xsl:call-template name="isd-intitule"/>
    </a>
  </xsl:template>

  <xsl:template match="tei:div[@type = 'notice']" mode="title" priority="14">
    <xsl:call-template name="isd-intitule"/>
  </xsl:template>

  <xsl:template name="isd-intitule">
    <xsl:for-each select="tei:head[not(@type = 'sub')] | tei:label[@type = 'section']">
      <xsl:choose>
        <xsl:when test="self::tei:head"><xsl:apply-templates select="." mode="title"/></xsl:when>
        <xsl:otherwise><xsl:value-of select="normalize-space(.)"/></xsl:otherwise>
      </xsl:choose>
      <xsl:if test="position() != last()">
        <xsl:variable name="norm" select="normalize-space(.)"/>
        <xsl:variable name="last" select="substring($norm, string-length($norm))"/>
        <xsl:if test="translate($last, '.;:?!»', '') != ''">. </xsl:if>
      </xsl:if>
    </xsl:for-each>
  </xsl:template>

  <!-- Les champs d'une notice : une liste de définitions, comme le tableau du site. -->
  <xsl:template match="tei:list[@type = 'gloss'][ancestor::tei:div[@type = 'notice']]" priority="14">
    <dl class="isd-champs">
      <xsl:for-each select="tei:label">
        <dt><xsl:apply-templates/></dt>
        <dd>
          <xsl:choose>
            <!-- 2026-09-13, décision de l'utilisateur (« url local du coup ») : le champ
                 « URL de cette page » portait le permalien du site qui ferme
                 (`<http://saint-denis.enc.sorbonne.fr/inventaire/tome1/notice155>`). On affiche
                 désormais l'adresse locale de la notice, et cliquable.
                 Le TEI n'est PAS modifié : la donnée d'origine reste dans la base, seule la
                 présentation change — donc réversible, et rien n'est réécrit dans la source.
                 Correspondance vérifiée avant d'écrire : les 3 286 permaliens des trois volumes
                 (1 196 + 2 032 + 58) désignent TOUS un fragment existant, `tomeN` répondant à
                 `ISD-volN` et le reste du chemin à l'identifiant de la notice. En cas de forme
                 inattendue, on retombe sur le texte d'origine plutôt que de perdre l'information. -->
            <xsl:when test="normalize-space(.) = 'URL de cette page'">
              <xsl:call-template name="isd-permalien">
                <xsl:with-param name="brut" select="normalize-space(following-sibling::tei:item[1])"/>
                <xsl:with-param name="secours" select="following-sibling::tei:item[1]/node()"/>
              </xsl:call-template>
            </xsl:when>
            <xsl:otherwise>
              <xsl:apply-templates select="following-sibling::tei:item[1]/node()"/>
            </xsl:otherwise>
          </xsl:choose>
        </dd>
      </xsl:for-each>
    </dl>
  </xsl:template>
  <xsl:template match="tei:list[@type = 'gloss'][ancestor::tei:div[@type = 'notice']]/tei:item" priority="14"/>

  <!-- Le permalien d'une unité de l'Inventaire, ramené sur l'adresse locale.
       Un seul endroit pour les deux formes : le champ d'une NOTICE (`<label>/<item>` d'une liste
       de définitions) et celui d'une SECTION (`<p rend="URL de cette page">`). La section avait
       été oubliée au premier essai — `ISD-vol3_noticeglobale` gardait l'adresse de l'ancien site,
       relevé par d25_permaliens_test.py. -->
  <xsl:template name="isd-permalien">
    <xsl:param name="brut"/>
    <xsl:param name="secours"/>
    <xsl:variable name="chemin"
                  select="substring-before(concat(substring-after($brut, '/inventaire/'), '&gt;'), '&gt;')"/>
    <xsl:variable name="tome" select="substring-before($chemin, '/')"/>
    <xsl:variable name="unite" select="substring-after($chemin, '/')"/>
    <xsl:variable name="vol" select="concat('ISD-vol', substring-after($tome, 'tome'))"/>
    <xsl:choose>
      <xsl:when test="starts-with($tome, 'tome') and $unite != ''">
        <!-- Du TEXTE entre chevrons, et non un lien — pour deux raisons qui vont dans le même
             sens. C'est la présentation de l'ÉLEC (`<http://…/notice155>`), et un permalien se
             copie, il ne se clique pas : il désigne la page où l'on se trouve déjà. Surtout,
             DoTS-vue confie tout lien de même origine à son routeur, et un renvoi vers la route
             courante VIDE le document (mesuré le 2026-09-13 : 13 notices et 25 646 caractères
             avant le clic, 0 après). Le rendre cliquable serait offrir un bouton qui efface la
             page. -->
        <span class="isd-permalien">
          <xsl:text>&lt;</xsl:text>
          <xsl:value-of select="concat('/saint-denis/document/', $vol, '?refId=', $vol, '_', $unite)"/>
          <xsl:text>&gt;</xsl:text>
        </span>
      </xsl:when>
      <!-- Forme inattendue : on garde le texte d'origine plutôt que de perdre l'information. -->
      <xsl:otherwise><xsl:apply-templates select="$secours"/></xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- Les indications de section (numéros des notices, note de l'éditeur…) gardent leur libellé. -->
  <xsl:template match="tei:div[@type = 'section']/tei:p[@rend]" priority="14">
    <p class="isd-section-info"><span class="isd-libelle"><xsl:value-of select="@rend"/><xsl:text> : </xsl:text></span>
      <xsl:choose>
        <xsl:when test="@rend = 'URL de cette page'">
          <xsl:call-template name="isd-permalien">
            <xsl:with-param name="brut" select="normalize-space(.)"/>
            <xsl:with-param name="secours" select="node()"/>
          </xsl:call-template>
        </xsl:when>
        <xsl:otherwise><xsl:apply-templates/></xsl:otherwise>
      </xsl:choose>
    </p>
  </xsl:template>

  <!-- ================================================================
       Images (autopilote 2026-09-11) : servies par DoTS-vue depuis
       public/images/saint-denis/. DoTS-vue route tout <a href> de même origine
       (router.push) : les images sont donc rendues en <img>, jamais en lien.
       ================================================================ -->
  <xsl:variable name="sd-images" select="'/images/saint-denis/'"/>

  <xsl:template match="tei:graphic[starts-with(@url, 'legacy-source/assets/')]" priority="12">
    <img class="sd-graphic" loading="lazy" src="{$sd-images}assets/{substring-after(@url, 'legacy-source/assets/')}" alt="{normalize-space(@n)}"/>
  </xsl:template>

  <!-- 2026-09-12, refondu le 2026-09-25 : les illustrations de chapitre sont rapatriées, pour
       celles qu'on a pu identifier. L'ancien site ne les servait PAS sous le nom du TEI mais comme
       pièces jointes Pleade, sous des noms engendrés
       (`functions/tei/attached/tremblay/tremblay_e0000328.jpg`) : 26 des 37 noms cités ont été
       appariés par le libellé du lien dans les fragments de l'ancien site. Les autres gardent le
       rendu « absente » — mieux vaut le dire que de montrer la mauvaise image.

       La table nom → fichier vivait dans un compagnon lu avec document(). Elle est maintenant
       DANS LE TEI : les 96 renvois qui citent une de ces 26 illustrations portent le chemin servi
       en @facs, la forme que le corpus emploie déjà 1 874 fois pour ses pages. Plus de compagnon,
       plus de document(), et le chemin voyage avec le renvoi qui s'en sert. -->
  <xsl:template match="tei:ref[starts-with(@target, 'illustrations/')] | tei:ptr[starts-with(@target, 'illustrations/')]" priority="12">
    <xsl:variable name="file" select="substring-after(@target, 'illustrations/')"/>
    <xsl:variable name="jointe" select="substring-after(@facs, 'images/saint-denis/illustrations/')"/>
    <xsl:choose>
      <xsl:when test="$jointe">
        <xsl:variable name="src" select="concat($sd-images, 'illustrations/', $jointe)"/>
        <xsl:choose>
          <!-- Une généalogie en PDF ne s'affiche pas : on la sert par l'autre origine locale
               (port 8081), seule façon d'ouvrir un fichier — DoTS-vue détourne les liens de même
               origine vers son routeur (leçon de E1). -->
          <xsl:when test="ends-with(lower-case($file), '.pdf') or ends-with(lower-case(string($jointe)), '.pdf')">
            <a class="sd-illustration-pdf" href="http://127.0.0.1:8081{$src}" target="_blank" rel="noopener">
              <xsl:apply-templates/>
              <xsl:text> (PDF)</xsl:text>
            </a>
          </xsl:when>
          <xsl:otherwise>
            <details class="sd-illustration">
              <summary><span class="sd-illustration-libelle"><xsl:apply-templates/></span></summary>
              <img class="sd-illustration-img" loading="lazy" src="{$src}" alt="{normalize-space(.)}"/>
            </details>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:when>
      <xsl:otherwise>
        <span class="sd-illustration-absente" title="Illustration du site d’origine absente de cette copie ({$file})">
          <xsl:apply-templates/>
        </span>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- Lien du site d'origine qui ne contient qu'une image (vignette vers la visionneuse) : hteiml
       n'applique pas les modèles à un ref sans texte et affiche l'URL. On rend l'image, dans le lien
       d'origine (autre site : DoTS-vue ne le détourne pas). -->
  <xsl:template match="tei:ref[tei:graphic][normalize-space(.) = '']" priority="12">
    <a class="sd-image-link" href="{@target}" target="_blank" rel="noopener">
      <xsl:apply-templates select="tei:graphic"/>
    </a>
  </xsl:template>

  <!-- 2026-09-12 : les images du Cartulaire blanc et de l'Inventaire sont RAPATRIÉES (autorisation
       de l'utilisateur, « 1. ok télécharge »), donc les 831 liens vers la visionneuse de l'ancien
       site deviennent l'image elle-même, dépliable sur place.
       Ce que visaient ces liens : `images/<série>/voir.html?ns=<fichier>.jpg`, c'est-à-dire une
       visionneuse Pleade, pas un fichier. Les fichiers sont maintenant servis par DoTS-vue depuis
       public/images/saint-denis/<série>/<fichier>.
       Un compagnon lu avec document() énumérait les fichiers présents et servait de garde-fou.
       Il a été retiré le 2026-09-25, après mesure : les 839 renvois `ns=` désignent tous un
       fichier recensé, 839 sur 839, et les 1 874 `pb/@facs` de même, 1 874 sur 1 874. Le garde-fou
       ne rejetait donc rien. Le fonds d'images étant clos (il reste local, rien n'y sera
       ajouté), le @target et le @facs pilotent seuls, comme sur christofle.
       (Le cache HTML de DoTS ne se rafraîchit pas tout seul : sa clé ne dépend que de la date de
       CETTE feuille, qu'il faut donc toucher — ou vider le store du corpus.)
       Pourquoi un <details> et non un lien : DoTS-vue confie tout href de même origine à son
       routeur, donc un lien vers /images/… mène à une route morte (leçon de D5 et de E2). -->
  <xsl:template match="tei:ref[contains(@target, 'images/cartulaireblanc/') or contains(@target, 'images/inventaire/')][contains(@target, 'ns=')]" priority="13">
    <xsl:variable name="serie" select="substring-before(substring-after(@target, 'images/'), '/voir.html')"/>
    <xsl:variable name="fichier" select="normalize-space(substring-after(@target, 'ns='))"/>
    <xsl:variable name="libelle" select="if (normalize-space(.) != '') then normalize-space(.) else normalize-space(@n)"/>
    <details class="sd-folio">
      <summary>
        <span class="sd-folio-libelle">
          <!-- Le contenu du renvoi est rendu tel quel : ce peut être un libellé
               (« LL 1157, p. 465 ») ou une vignette (`tei:graphic`), qui devient alors
               l'aperçu cliquable. Un renvoi vide retombe sur le nom du fichier, pour ne
               jamais produire un <summary> muet. -->
          <xsl:apply-templates/>
          <xsl:if test="not(node())"><xsl:value-of select="$fichier"/></xsl:if>
        </span>
      </summary>
      <img class="sd-folio-img" loading="lazy" src="{$sd-images}{$serie}/{$fichier}"
           alt="{if ($libelle != '') then $libelle else $fichier}"/>
    </details>
  </xsl:template>

  <!-- ================================================================
       2026-09-24 — LES FOLIOS ATTACHÉS AU TEXTE PAR <pb facs>.

       Décision du responsable : les images de folios entrent dans le TEI, pas dans une galerie
       d'affichage. 1 874 `tei:pb[@facs]` ont donc été posés dans les sources :
         - 441 en tête de la transcription d'un acte du Cartulaire blanc (7 chapitres), quand la
           table des actes du site ET le témoin B de l'acte donnent la même page de cartulaire ;
         - 1 433 en tête de la première notice de chaque page de l'Inventaire général
           (ISD-vol1/2/3), d'après la mention « Archives nationales, LL 118x page N ».
       Le @facs porte le chemin servi par DoTS-vue, `images/saint-denis/<série>/<fichier>`, comme
       christofle porte `images/sources/…`.

       ATTENTION : hteiml/xsl/tei2html.xsl a un modèle VIDE pour `tei:div/tei:pb` (l. 1149) ; sans
       la surcharge ci-dessous tous ces pb disparaîtraient silencieusement, puisqu'ils sont
       justement enfants directs de div (transcription, notice). La précédence d'import suffit,
       la priorité n'est là que pour être explicite.

       Le rendu est celui, déjà éprouvé et déjà mis en forme, des renvois `details.sd-folio` :
       un intitulé cliquable qui déplie l'image sur place. On ne fabrique pas de lien vers
       /images/… : DoTS-vue confie tout href de même origine à son routeur (leçon de D5 et E2).
       Le @facs fait foi : le compagnon qui vérifiait la présence du fichier a été retiré le
       2026-09-25, ses 4 368 folios couvrant déjà les 1 874 @facs sans en rejeter un seul. -->
  <xsl:template match="tei:pb[@facs]" priority="20">
    <xsl:variable name="rel" select="substring-after(@facs, 'images/saint-denis/')"/>
    <xsl:variable name="fichier" select="tokenize($rel, '/')[last()]"/>
    <xsl:variable name="serie" select="substring-before($rel, concat('/', $fichier))"/>
    <xsl:variable name="tome" select="substring-after($serie, '/')"/>
    <xsl:variable name="ouvrage">
      <xsl:choose>
        <xsl:when test="starts-with($serie, 'cartulaireblanc/')">Cartulaire blanc</xsl:when>
        <xsl:when test="starts-with($serie, 'inventaire/')">Inventaire général</xsl:when>
        <xsl:otherwise/>
      </xsl:choose>
    </xsl:variable>
    <xsl:variable name="cote">
      <xsl:choose>
        <xsl:when test="$serie = 'cartulaireblanc/tome1'">LL 1157</xsl:when>
        <xsl:when test="$serie = 'cartulaireblanc/tome2'">LL 1158</xsl:when>
        <xsl:when test="$serie = 'inventaire/tome1'">LL 1189</xsl:when>
        <xsl:when test="$serie = 'inventaire/tome2'">LL 1190</xsl:when>
        <xsl:when test="$serie = 'inventaire/tome3'">LL 1191</xsl:when>
        <xsl:otherwise/>
      </xsl:choose>
    </xsl:variable>
    <xsl:variable name="libelle">
      <xsl:value-of select="$ouvrage"/>
      <xsl:if test="$tome != ''">
        <xsl:text>, tome </xsl:text>
        <xsl:value-of select="substring-after($tome, 'tome')"/>
      </xsl:if>
      <xsl:if test="$cote != ''">
        <xsl:text> (</xsl:text><xsl:value-of select="$cote"/><xsl:text>)</xsl:text>
      </xsl:if>
      <xsl:if test="normalize-space(@n) != ''">
        <xsl:text>, page </xsl:text>
        <xsl:value-of select="normalize-space(@n)"/>
      </xsl:if>
    </xsl:variable>
    <details class="sd-folio sd-pb">
      <summary>
        <span class="sd-folio-libelle">
          <xsl:value-of select="if (normalize-space($libelle) != '') then $libelle else $fichier"/>
        </span>
      </summary>
      <img class="sd-folio-img" loading="lazy" src="{$sd-images}{$serie}/{$fichier}"
           alt="{if (normalize-space($libelle) != '') then $libelle else $fichier}"/>
    </details>
  </xsl:template>

  <!-- ================================================================
       2026-09-14 (agentsd) — LES CINQ VISIONNEUSES DE SÉRIE.

       Signalé par l'utilisateur depuis `sd-feuilleter-images` : « faudrait changer les liens, ça
       renvoie à l'ÉLEC historique ». Relevé exhaustif sur les onze ressources de la collection
       (ref/ptr vers `voir.html`) : 844 renvois, dont 839 portent `ns=` — donc une image désignée,
       déjà traités juste au-dessus en `details.sd-folio` — et **5 seulement n'en portent pas**.
       (839 = 837 dans `saint-denis-site`, 1 dans `dugny`, 1 dans `saint-martin`.)
       Tous les cinq sont dans `saint-denis-site`, sur la rubrique « Feuilleter les images » :
         images/cartulaireblanc/tome1/voir.html   « Tome 1 (Archives nationales LL 1157) »
         images/cartulaireblanc/tome2/voir.html   « Tome 2 (Archives nationales LL 1158) »
         images/inventaire/tome1/voir.html        « Tome 1 (Archives nationales, LL 1189) »
         images/inventaire/tome2/voir.html        « Tome 2 (Archives nationales, LL 1190) »
         images/inventaire/tome3/voir.html        « Tome 3 (Archives nationales, LL 1191) »
       (Le commentaire précédent en annonçait 2 : il ne comptait que les formes relatives, et le
       modèle qui suit ne filtrait pas `ns=`. Les 2 formes relatives du corpus portent en fait
       toutes les deux `ns=` et partent donc en `sd-folio` ; ce modèle-ci ne garde plus rien.)

       AUCUNE DE CES CINQ ADRESSES N'A D'ÉQUIVALENT LOCAL, et c'est mesuré, pas supposé : ce qui a
       été rapatrié, ce sont des FOLIOS, pas une visionneuse de tome. Il n'existe pas non plus de route de galerie
       côté DoTS-vue — seules `/saint-denis/search` et les routes de document sont déclarées.
       Un lien de série ne désigne aucune image : lui en choisir une (la première du tome, par
       exemple) serait fabriquer une cible que le TEI n'a jamais écrite. On ne le fait pas.

       Ils cessent donc d'être des liens et redeviennent du texte, ce qui répond à la demande sans
       inventer de destination. L'intitulé de survol dit franchement ce qu'on a et ce qu'on n'a pas
       — même parti pris que `sd-recherche-locale` ci-dessous. Le décompte affiché était calculé
       sur le compagnon ; depuis son retrait (2026-09-25) il est LU SUR LE @n DU RENVOI, dans le
       TEI, où une note dit en toutes lettres que ces cinq nombres sont un état arrêté du fonds
       (relevé du 2026-09-24 : 968, 629, 938, 1 029, 804) et non un calcul. Le fonds est clos.
       On les a mis dans la source et non dans la feuille parce qu'ils décrivent le corpus, non
       sa présentation : ils doivent voyager avec le renvoi qu'ils qualifient, être versionnés
       avec lui, et disparaître avec lui.
       Pour le tome 1 du Cartulaire blanc, l'équivalent local existe déjà et fonctionne : la
       sous-liste des sept chapitres, juste au-dessous, est faite de sept `details.sd-folio`.
       ================================================================ -->
  <xsl:template match="tei:ref[contains(@target, 'images/cartulaireblanc/') or contains(@target, 'images/inventaire/')]
                              [contains(@target, '/voir.html')][not(contains(@target, 'ns='))]"
                priority="15">
    <xsl:variable name="serie" select="substring-before(substring-after(@target, 'images/'), '/voir.html')"/>
    <xsl:variable name="n" select="normalize-space(@n)"/>
    <span class="sd-visionneuse-absente">
      <xsl:attribute name="title">
        <xsl:choose>
          <xsl:when test="$n &gt; 0">
            <xsl:text>La visionneuse de l'ancien site n'a pas d'équivalent ici. Sur cette série, </xsl:text>
            <xsl:value-of select="$n"/>
            <xsl:text> pages sont conservées en local : elles se déplient depuis les renvois du corpus qui les désignent.</xsl:text>
          </xsl:when>
          <xsl:otherwise>
            <xsl:text>La visionneuse de l'ancien site n'a pas d'équivalent ici : aucune image de cette série n'a été rapatriée.</xsl:text>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:attribute>
      <xsl:apply-templates/>
      <!-- Garde-fou de sérialisation : la feuille est en method="xml", et un <span/> vide
           avalerait la suite du document. Le renvoi porte toujours son intitulé, mais on ne
           parie pas là-dessus. -->
      <xsl:if test="not(node())"><xsl:value-of select="$serie"/></xsl:if>
    </span>
  </xsl:template>

  <!-- Modèle d'origine, laissé intact par précaution. Il ne reçoit plus rien : les renvois
       relatifs AVEC `ns=` partent en `sd-folio` (priorité 13) et ceux SANS `ns=` sont pris
       par le modèle ci-dessus (priorité 15). -->
  <xsl:template match="tei:ref[starts-with(@target, '../')][contains(@target, 'images/cartulaireblanc/')]" priority="12">
    <a class="sd-legacy-viewer" href="http://saint-denis.enc.sorbonne.fr/images/{substring-after(@target, 'images/')}" target="_blank" rel="noopener">
      <xsl:apply-templates/>
    </a>
  </xsl:template>

  <!-- ================================================================
       2026-09-14 — RENVOIS D'UN ACTE À L'AUTRE LAISSÉS EN TEXTE BRUT.

       Signalé par l'utilisateur depuis `ully-acte93` : « voir aussi acte Moyvillers n° 57 »,
       qu'on lit sans pouvoir le suivre. L'examen a montré que la question dépasse les « voir » :
       le corpus renvoie d'un acte à l'autre partout, tantôt dans un `<ref>` — donc cliquable —
       tantôt en clair. Mesuré sur les sept chapitres (`scripts/d30_renvois_actes.py`) :
       **599 renvois déjà liés, 156 en texte brut, et les 156 ont une cible qui existe.**

       DEUX VÉRIFICATIONS ONT DÉCIDÉ DE LA RÈGLE, et elles valaient la peine.
       1. Le numéro AFFICHÉ est la bonne clé, pas l'ancien `@target`. Le TEI porte
          `<ref target="#rueil-acte127">acte Rueil n° 70</ref>` : la cible est périmée (ancienne
          numérotation, 214 cibles mortes dans le seul Rueil), le libellé est juste. C'est
          exactement ce qu'avait établi D1 le 2026-09-11, dont la table `sd-renvois-corriges`
          corrige ces cibles d'après leur libellé. On relie donc sur le NUMÉRO LU.
       2. Un chapitre cité n'est pas forcément édité. « acte Moyvillers n° 57 » ne peut pas être
          relié : Moyvillers ne fait pas partie des sept chapitres publiés. La règle ne connaît
          que ces sept noms ; tout le reste demeure du texte, ce qui est la bonne réponse.

       CE QUI EST RENDU CLIQUABLE : le NUMÉRO, et non toute la formule. Raison technique, pas
       esthétique : « n° » s'écrit de deux façons dans ce corpus, « n° » dans un seul nœud de
       texte (97 cas) et `n<hi rend="sup">o</hi>` (59 cas), qui traverse une frontière
       d'éléments. XSLT ne peut pas ouvrir un lien dans un nœud et le fermer dans un autre :
       relier la formule entière donnerait deux traitements différents pour une même chose.
       Le numéro, lui, est toujours d'un seul tenant.
       ================================================================ -->

  <xsl:variable name="sd-chap-motif"
                select="'Beaurain|Dugny|Pierrefitte|Rueil|Saint-Martin|Tremblay|Ully'"/>

  <!-- Cas A — « acte Rueil n° 58 », « actes Dugny 32 » : tout dans le même nœud de texte.
       Restreint aux contextes où ces renvois vivent réellement (mesuré : p, note, item,
       witness) et à ce qui n'est pas déjà dans un `<ref>`, pour ne pas relier deux fois. -->
  <xsl:template priority="5"
      match="text()[not(ancestor::tei:ref)]
                   [ancestor::tei:p or ancestor::tei:note or ancestor::tei:item or ancestor::tei:witness]
                   [matches(., concat('actes?[\s&#160;]+(', $sd-chap-motif, ')[\s&#160;]*(n[\s&#160;]*[°o][\s&#160;]*)?\d'))]">
    <xsl:analyze-string select="."
        regex="{concat('(actes?[\s&#160;]+(', $sd-chap-motif, ')[\s&#160;]*(?:n[\s&#160;]*[°o][\s&#160;]*)?)(\d+[a-z]?)')}">
      <xsl:matching-substring>
        <xsl:value-of select="regex-group(1)"/>
        <xsl:call-template name="sd-lien-acte">
          <xsl:with-param name="chapitre" select="regex-group(2)"/>
          <xsl:with-param name="numero" select="regex-group(3)"/>
        </xsl:call-template>
      </xsl:matching-substring>
      <xsl:non-matching-substring><xsl:value-of select="."/></xsl:non-matching-substring>
    </xsl:analyze-string>
  </xsl:template>

  <!-- Cas B — « acte Rueil n<hi rend="sup">o</hi> 51 » : le numéro est dans le nœud de texte
       QUI SUIT l'exposant. On ne l'attrape que si le texte d'avant se termine bien par
       « acte <Chapitre> n », pour ne pas transformer en lien le premier nombre venu. -->
  <xsl:template priority="6"
      match="text()[not(ancestor::tei:ref)]
                   [preceding-sibling::node()[1][self::tei:hi][normalize-space() = 'o']]
                   [matches(., '^\s*\d')]
                   [matches(string(preceding-sibling::node()[2]),
                            concat('actes?\s+(', $sd-chap-motif, ')\s*n\s*$'))]">
    <xsl:variable name="avant" select="string(preceding-sibling::node()[2])"/>
    <!-- Le nom du chapitre est retrouvé en essayant les sept, et NON par `replace()`.
         Cette feuille est déclarée `version="1.1"`, que Saxon traite en compatibilité 1.0 :
         le `replace($avant, '^.*(…)$', '$1')` écrit d'abord faisait échouer TOUTE la
         transformation de pierrefitte — HTTP 500 sur la racine du chapitre, isolé par
         bissection le 2026-09-14. Sept comparaisons valent mieux qu'une expression fragile. -->
    <xsl:variable name="chap">
      <xsl:for-each select="tokenize($sd-chap-motif, '\|')">
        <xsl:if test="matches($avant, concat('actes?\s+', ., '\s*n\s*$'))">
          <xsl:value-of select="."/>
        </xsl:if>
      </xsl:for-each>
    </xsl:variable>
    <xsl:choose>
      <xsl:when test="string($chap) != ''">
        <xsl:analyze-string select="." regex="^(\s*)(\d+[a-z]?)">
          <xsl:matching-substring>
            <xsl:value-of select="regex-group(1)"/>
            <xsl:call-template name="sd-lien-acte">
              <xsl:with-param name="chapitre" select="string($chap)"/>
              <xsl:with-param name="numero" select="regex-group(2)"/>
            </xsl:call-template>
          </xsl:matching-substring>
          <xsl:non-matching-substring><xsl:value-of select="."/></xsl:non-matching-substring>
        </xsl:analyze-string>
      </xsl:when>
      <xsl:otherwise><xsl:value-of select="."/></xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template name="sd-lien-acte">
    <xsl:param name="chapitre"/>
    <xsl:param name="numero"/>
    <xsl:variable name="rid" select="lower-case($chapitre)"/>
    <a class="sd-acte-renvoi" title="Aller à l'acte {$chapitre} n° {$numero}"
       href="/saint-denis/document/{$rid}?refId={$rid}-acte{$numero}">
      <xsl:value-of select="$numero"/>
    </a>
  </xsl:template>

  <!-- ================================================================
       2026-09-14 — les derniers renvois VIVANTS vers le site qui ferme.

       L'audit de cohérence du 2026-09-13 avait conclu qu'il n'en restait aucun : c'était FAUX,
       mon relevé exigeait un attribut `class` à côté du `href`, que ces `<a>` n'ont pas. Le
       balayage exhaustif en a trouvé **16 adresses sur 19 unités**. Deux familles se réparent,
       et l'utilisateur les a demandées toutes les deux (« ok fais le 1 et le 2 »).
       ================================================================ -->

  <!-- (1) Les six archives à télécharger : rapatriées le 2026-09-14 sous
       `dots-vue/public/images/saint-denis/telechargements/` (6,0 Mo, les six vérifiées comme
       ZIP valides après téléchargement — une archive tronquée se télécharge sans erreur).
       Servies par le serveur de fichiers local du port 8081 et NON par une URL de même origine :
       DoTS-vue confie tout href de même origine à son routeur, et un lien vers `/images/…zip`
       mène à une route morte. Même raison et même forme que la branche PDF des illustrations. -->
  <xsl:template match="tei:ref[contains(@target, 'enc.sorbonne.fr')][ends-with(lower-case(@target), '.zip')]"
                priority="16">
    <a class="sd-telechargement"
       href="http://127.0.0.1:8081/images/saint-denis/telechargements/{tokenize(@target, '/')[last()]}"
       target="_blank" rel="noopener">
      <xsl:apply-templates/>
    </a>
  </xsl:template>

  <!-- (2) Les quatre entrées Pleade : deux formulaires de recherche avancée et deux index des
       auteurs d'actes. La recherche a bien un équivalent local (`/saint-denis/search`, route
       déclarée dans la conf, vérifiée en service). L'index des auteurs, LUI, n'en a pas : rien
       dans nos TEI ne liste les auteurs d'actes nommément — l'Inventaire ne porte qu'un « type
       d'auteur d'acte » (« roi de France », « pape »). On mène donc à la recherche locale, mais
       l'intitulé de survol le dit franchement plutôt que de laisser croire à un index repris. -->
  <xsl:template match="tei:ref[contains(@target, 'enc.sorbonne.fr')]
                              [contains(@target, 'navindex.html') or contains(@target, 'recherche-avancee.html')]"
                priority="16">
    <a class="sd-recherche-locale" href="/saint-denis/search">
      <xsl:attribute name="title">
        <xsl:choose>
          <xsl:when test="contains(@target, 'navindex.html')">
            <xsl:text>L'index des auteurs d'actes de l'ancien site n'a pas d'équivalent ici : ce lien mène à la recherche dans la collection.</xsl:text>
          </xsl:when>
          <xsl:otherwise>
            <xsl:text>Recherche dans la collection Saint-Denis.</xsl:text>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:attribute>
      <xsl:apply-templates/>
    </a>
  </xsl:template>

  <!-- B1e (autopilote 2026-09-11) : liens absolus de l'ancien site vers les chapitres et actes du Cartulaire
       blanc -> pages DoTS internes. Seuls les 7 chapitres édités et les actes « acteN » (chiffres, plus une lettre finale éventuelle) sont
       réécrits (y compris « acteNa/b », tous présents dans DoTS) ; Inventaire général et téléchargements restent vers l'ancien site. -->
  <xsl:variable name="sd-chapitres" select="' beaurain dugny pierrefitte rueil saint-martin tremblay ully '"/>

  <!-- D1 (autopilote 2026-09-11) : renvois du TEI vers des actes inexistants (ancienne numérotation, déjà morts
       sur l'ancien site : 0 fragment Pleade pour ces identifiants). Cible corrigée d'après le libellé du lien
       lui-même (« acte Rueil no 70 » → rueil-acte70, « 16a » → rueil-acte16a, « acte Ully no 40 » → ully-acte40).
       Table générée depuis les TEI (30 renvois de l'introduction de Rueil, 1 dans ully-acte13). -->
  <xsl:variable name="sd-renvois-corriges" select="' rueil-acte101=rueil-acte44 rueil-acte103=rueil-acte46 rueil-acte108=rueil-acte51 rueil-acte110=rueil-acte53 rueil-acte111=rueil-acte54 rueil-acte112=rueil-acte55 rueil-acte115=rueil-acte58 rueil-acte117=rueil-acte60 rueil-acte120=rueil-acte63 rueil-acte121=rueil-acte64 rueil-acte122=rueil-acte65 rueil-acte123=rueil-acte66 rueil-acte125=rueil-acte68 rueil-acte127=rueil-acte70 rueil-acte71=rueil-acte16a rueil-acte73=rueil-acte17 rueil-acte76=rueil-acte20 rueil-acte77=rueil-acte21 rueil-acte79=rueil-acte23 rueil-acte84=rueil-acte28a rueil-acte85=rueil-acte28b rueil-acte88=rueil-acte31 rueil-acte90=rueil-acte33 rueil-acte94=rueil-acte37 rueil-acte96=rueil-acte39 rueil-acte97=rueil-acte40 rueil-acte98=rueil-acte41 ully-acte140=ully-acte40 '"/>

  <!-- B1f (2026-09-11) : renvois TEI internes entre actes.
       Exemple :
         <ref target="#ully-acte88b">acte Ully no 88b</ref>
       Dans un fragment DoTS, href="#ully-acte88b" chercherait seulement une ancre
       dans la page courante. On le transforme donc en vraie route DoTS-vue. -->
  <xsl:template
      match="tei:ref[starts-with(@target, '#')][contains(@target, '-acte')][not(@type='note')]"
      priority="12">
    <!-- D1 : cibles obsolètes (ancienne numérotation) corrigées d'après le libellé du lien, voir sd-renvois-corriges -->
    <xsl:variable name="id0" select="substring-after(@target, '#')"/>
    <xsl:variable name="id">
      <xsl:choose>
        <xsl:when test="contains($sd-renvois-corriges, concat(' ', $id0, '='))">
          <xsl:value-of select="substring-before(substring-after($sd-renvois-corriges, concat(' ', $id0, '=')), ' ')"/>
        </xsl:when>
        <xsl:otherwise><xsl:value-of select="$id0"/></xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:variable name="chap" select="substring-before($id, '-acte')"/>
    <xsl:variable name="num" select="substring-after($id, '-acte')"/>
    <xsl:choose>
      <xsl:when test="
        contains($sd-chapitres, concat(' ', $chap, ' '))
        and $num != ''
        and translate(substring($num, 1, 1), '0123456789', '') = ''
        and (
          translate($num, '0123456789', '') = ''
          or (
            string-length(translate($num, '0123456789', '')) = 1
            and translate(
              substring($num, string-length($num)),
              'abcdefghijklmnopqrstuvwxyz',
              ''
            ) = ''
          )
        )
      ">
        <a class="sd-internal" href="/saint-denis/document/{$chap}?refId={$id}">
          <xsl:apply-templates/>
        </a>
      </xsl:when>
      <xsl:otherwise>
        <xsl:apply-imports/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  <!-- D1 (autopilote 2026-09-11) : autres formes de renvois du TEI (noms de fichiers de l'édition d'origine).
       « rueil.xml#rueil-acte7 » (inter-chapitres, 40) → /saint-denis/document/rueil?refId=rueil-acte7 ;
       « tremblay.xml » → /saint-denis/document/tremblay ; « ully-acte77 » sans # (6) → ?refId=ully-acte77 ;
       « ISD-vol1.xml#notice395 » (Inventaire général, absent de DoTS, 20) → notice de l'ancien site, comme les
       495 liens d'inventaire traités en B1e (liste D5) ;
       « #ully-intro3.d », « #tremblay-introduction » : cible absente du fragment affiché (section sans xml:id
       dans le TEI reconstruit ; front hors navigation) → page d'entrée du chapitre, qui est son introduction. -->
  <xsl:template match="tei:ref[not(@type = 'note')][contains(@target, '.xml')][not(contains(@target, ':'))]" priority="12">
    <xsl:variable name="file" select="substring-before(@target, '.xml')"/>
    <xsl:variable name="frag" select="substring-after(@target, '#')"/>
    <xsl:choose>
      <xsl:when test="contains($sd-chapitres, concat(' ', $file, ' ')) and $frag != ''">
        <a class="sd-internal" href="/saint-denis/document/{$file}?refId={$frag}"><xsl:apply-templates/></a>
      </xsl:when>
      <xsl:when test="contains($sd-chapitres, concat(' ', $file, ' '))">
        <a class="sd-internal" href="/saint-denis/document/{$file}"><xsl:apply-templates/></a>
      </xsl:when>
      <!-- 2026-09-12 (D21) : l'Inventaire général est maintenant dans DoTS (ressources ISD-vol1
           à 3, 3 285 notices), le renvoi reste donc dans l'application. L'identifiant d'unité
           est préfixé par le volume, comme dans le TEI produit : ISD-vol1_notice395. -->
      <xsl:when test="starts-with($file, 'ISD-vol') and starts-with($frag, 'notice')">
        <a class="sd-inventaire" href="/saint-denis/document/{$file}?refId={$file}_{$frag}"><xsl:apply-templates/></a>
      </xsl:when>
      <xsl:otherwise><xsl:apply-imports/></xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="tei:ref[not(@type = 'note')][contains(@target, '-acte')][not(contains(@target, '#') or contains(@target, '/') or contains(@target, '.') or contains(@target, ':'))]" priority="12">
    <xsl:variable name="chap" select="substring-before(@target, '-acte')"/>
    <xsl:choose>
      <xsl:when test="contains($sd-chapitres, concat(' ', $chap, ' '))">
        <a class="sd-internal" href="/saint-denis/document/{$chap}?refId={@target}"><xsl:apply-templates/></a>
      </xsl:when>
      <xsl:otherwise><xsl:apply-imports/></xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="tei:ref[not(@type = 'note')][starts-with(@target, '#')][contains(@target, '-intro')][not(key('id', substring-after(@target, '#')))]" priority="13">
    <xsl:variable name="chap" select="substring-before(substring-after(@target, '#'), '-intro')"/>
    <xsl:choose>
      <xsl:when test="contains($sd-chapitres, concat(' ', $chap, ' '))">
        <a class="sd-internal" href="/saint-denis/document/{$chap}"><xsl:apply-templates/></a>
      </xsl:when>
      <xsl:otherwise><xsl:apply-imports/></xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="tei:ref[starts-with(@target, 'http://saint-denis.enc.sorbonne.fr/cartulaire/tome1/')]" priority="11">
    <xsl:variable name="path" select="substring-after(@target, 'http://saint-denis.enc.sorbonne.fr/cartulaire/tome1/')"/>
    <xsl:variable name="chap" select="substring-before(concat($path, '/'), '/')"/>
    <xsl:variable name="rest" select="translate(substring-after($path, '/'), '/', '')"/>
    <xsl:variable name="num" select="substring-after($rest, 'acte')"/>
    <xsl:choose>
      <xsl:when test="contains($sd-chapitres, concat(' ', $chap, ' ')) and $rest = ''">
        <a class="sd-internal" href="/saint-denis/document/{$chap}"><xsl:apply-templates/></a>
      </xsl:when>
      <xsl:when test="contains($sd-chapitres, concat(' ', $chap, ' ')) and starts-with($rest, 'acte') and $num != '' and translate(substring($num, 1, 1), '0123456789', '') = ''
                      and (translate($num, '0123456789', '') = ''
                           or (string-length(translate($num, '0123456789', '')) = 1
                               and translate(substring($num, string-length($num)), 'abcdefghijklmnopqrstuvwxyz', '') = ''))">
        <a class="sd-internal" href="/saint-denis/document/{$chap}?refId={$chap}-{$rest}"><xsl:apply-templates/></a>
      </xsl:when>
      <xsl:otherwise><xsl:apply-imports/></xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- D5-DEBUT (autopilote 2026-09-12) : liens vers les anciens sites ELEC -->
  <!-- hteiml fait un lien de tout tei:idno commencant par « http » (tei2html.xsl l. 1805),
       du tei:title voisin d'un idno[@type='URI'] (l. 1796) et de tei:ref/@target (l. 1456).
       Les anciens sites ELEC ferment : le TEXTE affiche est conserve mot pour mot (c'est
       l'identifiant de la publication d'origine), seule la cible devient la route locale.
       Table et bloc produits par dots-autopilot/scripts/d5_legacy_links_fix.py. -->
  <!-- portail ELEC -->
  <xsl:template match="tei:title[../tei:idno[@type = 'URI'][normalize-space(.) = 'http://elec.enc.sorbonne.fr' or normalize-space(.) = 'http://elec.enc.sorbonne.fr/']]" priority="14">
    <a class="title d5-local" href="/"><xsl:apply-templates/></a>
  </xsl:template>
  <!-- adresse de l'ancien site -->
  <xsl:template match="tei:idno[not(@type = 'URI' and ../tei:title)][normalize-space(.) = 'http://saint-denis.enc.sorbonne.fr/']" priority="14">
    <a class="idno d5-local" href="/saint-denis"><xsl:apply-templates/></a>
  </xsl:template>
  <xsl:template match="tei:idno[not(@type = 'URI' and ../tei:title)][normalize-space(.) = 'http://saint-denis.enc.sorbonne.fr/cartulaire/tome1/beaurain/']" priority="14">
    <a class="idno d5-local" href="/saint-denis/document/beaurain"><xsl:apply-templates/></a>
  </xsl:template>
  <xsl:template match="tei:idno[not(@type = 'URI' and ../tei:title)][normalize-space(.) = 'http://saint-denis.enc.sorbonne.fr/cartulaire/tome1/dugny/']" priority="14">
    <a class="idno d5-local" href="/saint-denis/document/dugny"><xsl:apply-templates/></a>
  </xsl:template>
  <xsl:template match="tei:idno[not(@type = 'URI' and ../tei:title)][normalize-space(.) = 'http://saint-denis.enc.sorbonne.fr/cartulaire/tome1/pierrefitte/']" priority="14">
    <a class="idno d5-local" href="/saint-denis/document/pierrefitte"><xsl:apply-templates/></a>
  </xsl:template>
  <xsl:template match="tei:idno[not(@type = 'URI' and ../tei:title)][normalize-space(.) = 'http://saint-denis.enc.sorbonne.fr/cartulaire/tome1/rueil/']" priority="14">
    <a class="idno d5-local" href="/saint-denis/document/rueil"><xsl:apply-templates/></a>
  </xsl:template>
  <xsl:template match="tei:idno[not(@type = 'URI' and ../tei:title)][normalize-space(.) = 'http://saint-denis.enc.sorbonne.fr/cartulaire/tome1/saint-martin/']" priority="14">
    <a class="idno d5-local" href="/saint-denis/document/saint-martin"><xsl:apply-templates/></a>
  </xsl:template>
  <xsl:template match="tei:idno[not(@type = 'URI' and ../tei:title)][normalize-space(.) = 'http://saint-denis.enc.sorbonne.fr/cartulaire/tome1/tremblay/']" priority="14">
    <a class="idno d5-local" href="/saint-denis/document/tremblay"><xsl:apply-templates/></a>
  </xsl:template>
  <xsl:template match="tei:idno[not(@type = 'URI' and ../tei:title)][normalize-space(.) = 'http://saint-denis.enc.sorbonne.fr/cartulaire/tome1/ully/']" priority="14">
    <a class="idno d5-local" href="/saint-denis/document/ully"><xsl:apply-templates/></a>
  </xsl:template>
  <!-- collection cartulaires servie ici -->
  <xsl:template match="tei:ref[@target = 'http://elec.enc.sorbonne.fr/cartulaires/']" priority="14">
    <a class="ref d5-local" href="/cartulaires"><xsl:apply-templates/></a>
  </xsl:template>
  <!-- page de recherche plein texte locale (cf. B1d) -->
  <xsl:template match="tei:ref[@target = 'http://saint-denis.enc.sorbonne.fr/recherche-avancee.html?document=cartulaire']" priority="14">
    <a class="ref d5-local" href="/saint-denis/search"><xsl:apply-templates/></a>
  </xsl:template>
  <!-- D5-FIN -->

  <!-- ================= D14c (autopilote 2026-09-12) : conformite au rendu de l'ancien site
       (fragments Pleade en cache, legacy-source/fragments) =================

       1. Developpement d'abreviation. Les conventions publiees de l'edition
          (« Le Cartulaire blanc : conventions de presentation », le-projet/aspects-scientifiques/
          cartulaire-blanc/conventions-de-presentation.html) disent : « Lorsque des noms propres
          limites dans le Cartulaire a la seule initiale peuvent etre developpes sans hesitation,
          les lettres restituees figurent entre parentheses : ainsi, par exemple, H- transcrit
          H(ugo). » L'ancien site rendait donc <expan>W<ex>illelmus</ex></expan> en « W(illelmus) »
          (texte simple, sans balise). hteiml (tei2html.xsl l. 2893 et 2899) rend « [W<ins>illelmus</ins>] ».
          On reprend la convention de l'edition. -->
  <xsl:template match="tei:expan" priority="20">
    <xsl:apply-templates/>
  </xsl:template>

  <xsl:template match="tei:expan" mode="a" priority="20">
    <xsl:apply-templates mode="a"/>
  </xsl:template>

  <xsl:template match="tei:ex" priority="20">
    <span class="sd-ex">
      <xsl:text>(</xsl:text>
      <xsl:apply-templates/>
      <xsl:text>)</xsl:text>
    </span>
  </xsl:template>

  <xsl:template match="tei:ex" mode="a" priority="20">
    <xsl:text>(</xsl:text>
    <xsl:apply-templates mode="a"/>
    <xsl:text>)</xsl:text>
  </xsl:template>

  <!-- 2. « Documents annexes ». L'ancien site titrait TOUS les blocs d'annexes
       (p class="annexes-label"). Les listes de tremblay et rueil portent ce titre dans le TEI
       (<head>Documents annexes</head>), celles de dugny non : on l'ajoute alors, avec le meme
       libelle que le TEI des autres chapitres et que l'ancien site. -->
  <xsl:template match="tei:div[@type = 'appendices']/tei:list[not(tei:head)]" priority="12">
    <p class="sd-annexes-label">Documents annexes</p>
    <xsl:apply-imports/>
  </xsl:template>

  <!-- 3. Resume court. L'ancien site n'affichait dans la page d'un acte que
       div[@type='summary'] (511 fragments Pleade sur 511) ; div[@type='short-summary'] servait
       de titre dans les tables et n'etait jamais imprime sous le resume. DoTS l'affichait a la
       suite du resume, donc deux fois le meme contenu. Il reste le titre DTS de l'unite
       (mapping DoTS, non affecte par cette feuille). -->
  <xsl:template match="tei:div[@type = 'short-summary']" priority="12"/>

  <!-- 4. Liens de page a page du site historique dont la cible est HORS du fragment servi.
       Le TEI porte ces renvois en ancre interne (<ref target="#sd-le-projet<2 tirets>mentions-legales">,
       ecrit par B1e). Quand la cible est dans le meme fragment, hteiml produit l'ancre attendue ;
       quand elle est dans une AUTRE rubrique, key('id', ...) ne la trouve pas et hteiml emet un
       <a> SANS href : le lien de l'ancien site devient mort (releve D14c : 8 liens, « Table des
       chapitres », « en images », « mentions legales », « en savoir plus sur les choix
       d'indexation », « section de presentation du contenu de l'Inventaire »).
       DoTS-vue ne sert que des unites de niveau 1 entieres pour cette ressource (editByLevel 1) :
       la forme qui ouvre la bonne page est
       /saint-denis/document/saint-denis-site?refId=<unite de niveau 1>#<unite>  (cf. D8).

       2026-09-24 : le sommaire ne suit plus la navigation de l'ancien site (3 rubriques) mais le
       plan editorial du responsable scientifique : une page d'introduction generale puis quatre
       parties. Le niveau 1 ne se lit donc PLUS dans le prefixe de l'identifiant — les xml:id
       n'ont pas ete renommes, pour ne casser aucun ref/@target ni aucune ancre — et il faut la
       table de correspondance ci-dessous. Les pages ecartees du sommaire (regroupees dans
       div[@xml:id='sd-ecarte'], hors citeStructure) ne sont servies par aucun fragment : on leur
       laisse deliberement $rub vide, elles retombent sur apply-imports et leur intitule redevient
       du texte, au lieu de pointer vers une page que DoTS ne sert plus. -->
  <xsl:template match="tei:ref[not(@type = 'note')][starts-with(@target, '#sd-')][not(key('id', substring-after(@target, '#')))]" priority="14">
    <xsl:variable name="id" select="substring-after(@target, '#')"/>
    <xsl:variable name="rub">
      <xsl:choose>
        <!-- Pages ecartees du sommaire : aucune cible servie. A tester EN PREMIER, avant les
             regles generiques qui les rattraperaient par leur prefixe. -->
        <xsl:when test="$id = 'sd-les-images--accueil'
                     or $id = 'sd-le-projet--feuille-de-route'
                     or $id = 'sd-le-projet--mentions-legales'
                     or $id = 'sd-le-projet--aspects-scientifiques--cartulaire-blanc--etat-d-avancement'
                     or $id = 'sd-le-projet--aspects-informatiques--generalites--caracteristiques-de-l-application'
                     or $id = 'sd-le-projet--aspects-informatiques--generalites--format-d-affichage-des-documents'
                     or $id = 'sd-le-projet--aspects-informatiques--cartulaire-blanc-projet-inf'
                     or $id = 'sd-le-projet--aspects-informatiques--inventaire--encodage-des-enrichissements-editoriaux'"/>
        <!-- Introduction generale : partie a elle seule. -->
        <xsl:when test="$id = 'sd-les-textes--accueil' or starts-with($id, 'sd-les-textes--accueil--')">sd-les-textes--accueil</xsl:when>
        <!-- 1re partie : les actes du haut Moyen Age. -->
        <xsl:when test="$id = 'sd-actes-haut-moyen-age' or starts-with($id, 'sd-les-textes--actes-du-haut-moyen-age')">sd-actes-haut-moyen-age</xsl:when>
        <!-- 2e partie : le Cartulaire blanc (y compris ses images et le descriptif des termes
             d'indexation, remontes depuis « Les images » et « Le projet »). -->
        <xsl:when test="$id = 'sd-cartulaire-blanc'
                     or starts-with($id, 'sd-les-textes--cartulaire-blanc')
                     or starts-with($id, 'sd-recherche-cartulaire')
                     or starts-with($id, 'sd-les-images--images-cb')
                     or starts-with($id, 'sd-le-projet--aspects-scientifiques--auteurs-actes-principales-entrees')">sd-cartulaire-blanc</xsl:when>
        <!-- 3e partie : l'Inventaire general (y compris ses images). -->
        <xsl:when test="$id = 'sd-inventaire-general'
                     or starts-with($id, 'sd-les-textes--inventaire')
                     or starts-with($id, 'sd-les-images--images-ig')">sd-inventaire-general</xsl:when>
        <!-- 4e partie : les pages de description du projet. -->
        <xsl:when test="$id = 'sd-le-projet'
                     or starts-with($id, 'sd-le-projet--')
                     or $id = 'sd-aspects-scientifiques' or $id = 'sd-scientifique-cartulaire' or $id = 'sd-scientifique-inventaire'
                     or $id = 'sd-aspects-informatiques' or $id = 'sd-informatique-generalites' or $id = 'sd-informatique-inventaire'">sd-le-projet</xsl:when>
      </xsl:choose>
    </xsl:variable>
    <xsl:choose>
      <xsl:when test="$rub != '' and $rub != $id">
        <a class="sd-internal sd-site-page" href="/saint-denis/document/saint-denis-site?refId={$rub}#{$id}">
          <xsl:apply-templates/>
        </a>
      </xsl:when>
      <xsl:when test="$rub != ''">
        <a class="sd-internal sd-site-page" href="/saint-denis/document/saint-denis-site?refId={$rub}">
          <xsl:apply-templates/>
        </a>
      </xsl:when>
      <xsl:otherwise><xsl:apply-imports/></xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- 2026-09-12 (D21) : les renvois du TEI du site vers l'Inventaire, sous forme d'URL absolue
       de l'ancien site (474 cas). Même cible que la forme « ISD-volN.xml#noticeNNN ». Le texte
       affiché reste celui du TEI. -->
  <xsl:template match="tei:ref[contains(@target, 'saint-denis.enc.sorbonne.fr/inventaire/tome')]" priority="14">
    <xsl:variable name="apres" select="substring-after(@target, '/inventaire/tome')"/>
    <xsl:variable name="tome" select="substring-before($apres, '/')"/>
    <xsl:variable name="notice" select="substring-after($apres, '/')"/>
    <xsl:choose>
      <xsl:when test="$tome != '' and starts-with($notice, 'notice')">
        <a class="sd-inventaire sd-inventaire-url" href="/saint-denis/document/ISD-vol{$tome}?refId=ISD-vol{$tome}_{$notice}"><xsl:apply-templates/></a>
      </xsl:when>
      <!-- « Le tome I dans son ensemble » : la cible est le volume, pas une notice (3 cas). -->
      <xsl:when test="$tome != '' and normalize-space($notice) = ''">
        <a class="sd-inventaire sd-inventaire-tome" href="/saint-denis/document/ISD-vol{$tome}"><xsl:apply-templates/></a>
      </xsl:when>
      <xsl:otherwise>
        <a class="sd-legacy-inventaire" href="{@target}" target="_blank" rel="noopener"><xsl:apply-templates/></a>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- ================================================================
       D43 (2026-09-24, refondu le 2026-09-25) : les deux index des auteurs d'actes.

       POURQUOI
       ~~~~~~~~
       L'ancien site publiait deux index d'auteurs d'actes, servis par Pleade
       (navindex.html?base=tei&amp;f=fdocAuthor pour le Cartulaire blanc,
       ?base=ead&amp;f=fauteursactes pour l'Inventaire général). Ils n'avaient pas
       d'équivalent ici : les deux liens menaient, faute de mieux, à la recherche
       plein texte, avec un intitulé de survol qui l'avouait.

       Ils ont d'abord été portés par un fichier compagnon lu avec document().
       Ils sont désormais DANS LE TEI, dans saint-denis-site.xml, à la fin des deux
       pages « Parcourir » : plus de compagnon, plus de document(), et une vraie
       donnée versionnée, servie par l'API et cherchable comme le reste du corpus.
       Parité conservée : 66 et 294 termes, 534 et 3 601 renvois.

       OÙ
       ~~
       <div type="index" xml:id="sd-index-auteurs-cartulaire"> et
       <div type="index" xml:id="sd-index-auteurs-inventaire">, derniers enfants des
       pages « Parcourir » — celles-là même qui portaient les liens Pleade, dont le
       lien historique devient une ancre vers la rubrique. Le type « index » n'est
       cité par aucun citeStructure : ces divisions n'entrent pas au sommaire.

       GROUPEMENT PAR INITIALE
       ~~~~~~~~~~~~~~~~~~~~~~~
       La feuille est déclarée version="1.1" : pas de xsl:for-each-group. Le
       compagnon contournait ce manque par un attribut @lettre sur chaque item, hors
       TEI. Le groupement est maintenant porté par la STRUCTURE : une <list
       type="index"> par initiale, son @n donnant l'initiale de classement (« * »
       pour les termes sans initiale) et son <head> le titre du groupe (« Sans
       initiale » dans ce cas). C'est la forme des index de `cartulaires`, elle est
       valide contre tei_all, et la feuille n'a plus qu'à parcourir les listes.
       Même raison pour le libellé court d'un renvoi (@n sur le ptr) :
       « Tremblay 15 », « t. I, n° 956 ».

       LIAGE
       ~~~~~
       Les 534 <docAuthor> des sept chapitres du Cartulaire blanc portent un @ref
       vers l'entrée d'index qui les recense (saint-denis-site.xml#sd-auteur-cb-NNNN).
       Ce @ref n'est pas rendu : il lie la source à son index, il ne change rien à
       l'affichage. L'Inventaire n'a pas de <docAuthor> — ses occurrences sont des
       champs de notice — et n'est donc pas lié de la même façon.
       ================================================================ -->
  <xsl:template match="tei:div[@type = 'index'][starts-with(@xml:id, 'sd-index-auteurs-')]"
                priority="16">
    <xsl:variable name="cle" select="substring-after(@xml:id, 'sd-index-auteurs-')"/>
    <section class="sd-index-auteurs" id="{@xml:id}">
      <h2 class="sd-index-auteurs-titre">
        <xsl:value-of select="tei:head[1]"/>
      </h2>
      <p class="sd-index-auteurs-chapeau">
        <xsl:value-of select="count(tei:list/tei:item)"/>
        <xsl:text> termes, </xsl:text>
        <xsl:value-of select="count(tei:list/tei:item/tei:ptr)"/>
        <xsl:text> renvois. Index reconstitué depuis le texte encodé, en parité avec l’index publié par le site d’origine.</xsl:text>
      </p>
      <nav class="sd-index-lettres" aria-label="Aller à une initiale">
        <xsl:for-each select="tei:list">
          <a class="sd-index-lettre-lien" href="#sd-index-auteurs-{$cle}-{translate(@n, '*', '0')}">
            <xsl:choose>
              <xsl:when test="@n = '*'">&#8226;</xsl:when>
              <xsl:otherwise><xsl:value-of select="@n"/></xsl:otherwise>
            </xsl:choose>
          </a>
        </xsl:for-each>
      </nav>
      <xsl:for-each select="tei:list">
        <div class="sd-index-groupe" id="sd-index-auteurs-{$cle}-{translate(@n, '*', '0')}">
          <h3 class="sd-index-initiale"><xsl:value-of select="tei:head[1]"/></h3>
          <ul class="sd-index-termes">
            <xsl:for-each select="tei:item">
              <li class="sd-index-terme">
                <!-- « details » plutôt qu'une liste déployée : un terme porte jusqu'à
                     647 renvois (« auteurs laïques », Inventaire). Fermé, l'index se lit
                     comme la liste de termes et de comptes que publiait l'ancien site ;
                     ouvert, il donne les renvois. HTML seul, ni script ni composant. -->
                <details class="sd-index-details">
                  <summary class="sd-index-sommaire">
                    <span class="sd-index-libelle"><xsl:value-of select="tei:term"/></span>
                    <span class="sd-index-nb"><xsl:value-of select="@n"/></span>
                  </summary>
                  <div class="sd-index-renvois">
                    <xsl:for-each select="tei:ptr">
                      <xsl:call-template name="sd-index-renvoi"/>
                    </xsl:for-each>
                  </div>
                </details>
              </li>
            </xsl:for-each>
          </ul>
        </div>
      </xsl:for-each>
    </section>
  </xsl:template>

  <!-- L'index ne paraît pas dans la table des matières de hteiml : elle liste les
       divisions enfantes d'une page, et l'index vient d'y entrer. Il est déjà atteint
       par l'ancre du lien historique, en bas de la page qui le porte. -->
  <xsl:template match="tei:div[@type = 'index'][starts-with(@xml:id, 'sd-index-auteurs-')]"
                mode="li" priority="16"/>

  <!-- Un renvoi de l'index. Les cibles ont les deux formes que la feuille résout
       déjà pour les « ref » du TEI : « chapitre.xml#chapitre-acteN » (Cartulaire
       blanc) et « ISD-volN.xml#noticeNNN » (Inventaire général, identifiant d'unité
       préfixé par le volume, cf. D21). -->
  <xsl:template name="sd-index-renvoi">
    <xsl:variable name="file" select="substring-before(@target, '.xml')"/>
    <xsl:variable name="frag" select="substring-after(@target, '#')"/>
    <xsl:choose>
      <xsl:when test="starts-with($file, 'ISD-vol')">
        <a class="sd-inventaire sd-index-renvoi"
           href="/saint-denis/document/{$file}?refId={$file}_{$frag}">
          <xsl:value-of select="@n"/>
        </a>
      </xsl:when>
      <xsl:otherwise>
        <a class="sd-internal sd-index-renvoi"
           href="/saint-denis/document/{$file}?refId={$frag}">
          <xsl:value-of select="@n"/>
        </a>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- Les deux pages « Parcourir » : même rendu que toute page du site
       (div[@type='page'], plus haut), suivi de la rubrique d'index. -->
  <xsl:template match="tei:div[@type = 'page']
                              [@xml:id = 'sd-les-textes--cartulaire-blanc--parcourir'
                               or @xml:id = 'sd-les-textes--inventaire--parcourir']"
                priority="16">
    <article class="sd-static-page sd-page-parcourir" id="{@xml:id}">
      <xsl:if test="@corresp">
        <xsl:attribute name="data-legacy-source"><xsl:value-of select="@corresp"/></xsl:attribute>
      </xsl:if>
      <h1 class="sd-page-title"><xsl:value-of select="tei:head[1]"/></h1>
      <xsl:apply-templates select="node()[not(self::tei:head[1])]"/>
    </article>
  </xsl:template>

  <!-- Le lien Pleade historique. Il n'y en a que deux dans tout le corpus, chacun
       sur la page « Parcourir » qui porte désormais son index : l'ancre est donc
       toujours dans la page servie. Remplace le repli vers la recherche (priorité 16). -->
  <xsl:template match="tei:ref[contains(@target, 'enc.sorbonne.fr')]
                              [contains(@target, 'navindex.html')]"
                priority="18">
    <xsl:variable name="cle">
      <xsl:choose>
        <xsl:when test="contains(@target, 'base=ead')">inventaire</xsl:when>
        <xsl:otherwise>cartulaire</xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <a class="sd-internal sd-index-ancre" href="#sd-index-auteurs-{$cle}"
       title="Index reconstitué depuis le texte encodé, au bas de cette page.">
      <xsl:apply-templates/>
    </a>
  </xsl:template>

</xsl:transform>
