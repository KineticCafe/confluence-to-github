<?xml version="1.0" encoding="UTF-8"?>

<!--
     Transform an xml page to github markdown.

     The page is in the format:

     page
     - space
     - - title
     - - description
     - - path
     - - key
     - - lower-key
     - title
     - lower-title
     - body
     - category[]
     - created
     - - by
     - - at
     - last-modified (omitted if created and last-modified timestamps are the same)
     - - by
     - - at
     - parent[] (omitted if a top-level page, in breadcrumb order)
     - - title
     - - filename
-->

<xsl:stylesheet version="1.0"
                xmlns:ac="http://www.atlassian.com/schema/confluence/4/ac/"
                xmlns:ri="http://www.atlassian.com/schema/confluence/4/ri/"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:str="http://exslt.org/strings"
                extension-element-prefixes="str"
  >

  <!-- Markdown output
       # header1
       ## header 2
       ### header 3

       [text here](http://url.goes/here)

       ![alt text here](http://image.url/here)

       **bold**
       _italic_

       `code`

       - dot
       - item
       - list

       1. number
       1. item
       1. list

       > block quoted
  -->

  <xsl:output method="text" />

  <xsl:param name="confluence-url" />
  <xsl:param name="jira-url" select="$confluence-url" />
  <xsl:param name="input-path" select="." />
  <xsl:param name="output-path" select="out" />
  <xsl:param name="script-path" />

  <xsl:variable name="lower" select="'abcdefghijklmnopqrstuvwxyz'" />
  <xsl:variable name="upper" select="'ABCDEFGHIJKLMNOPQRSTUVWXYZ'" />

  <xsl:variable name="newline"><xsl:text>&#x0a;</xsl:text></xsl:variable>
  <xsl:variable name="entities-file" select="concat($input-path, '/entities.xml')" />
  <xsl:variable name="attachments-file" select="concat($output-path, '/image-mappings.xml')" />

  <xsl:template name="to-lowercase">
    <xsl:param name="input" />
    <xsl:value-of select="translate($input, $upper, $lower)" />
  </xsl:template>

  <xsl:template name="clean-filename">
    <xsl:param name="original-name" />
    <xsl:variable name="apos" select='"&apos;"' />
    <xsl:variable name="was" select="concat(' \/:*?\|&quot;&lt;&gt;`()', $apos)" />
    <xsl:variable name="now" select="'--'"/>
    <xsl:call-template name="to-lowercase">
      <xsl:with-param name="input">
        <xsl:value-of select="translate($original-name, $was, $now)" />
      </xsl:with-param>
    </xsl:call-template>
  </xsl:template>

  <xsl:template name="string-replace-all">
    <xsl:param name="text" />
    <xsl:param name="replace" />
    <xsl:param name="by" />
    <xsl:choose>
      <xsl:when test="$text = '' or $replace = ''or not($replace)" >
        <xsl:value-of select="$text" />
      </xsl:when>
      <xsl:when test="contains($text, $replace)">
        <xsl:value-of select="substring-before($text,$replace)" disable-output-escaping="yes" />
        <xsl:value-of select="$by" disable-output-escaping="yes" />
        <xsl:call-template name="string-replace-all">
          <xsl:with-param name="text" select="substring-after($text,$replace)" />
          <xsl:with-param name="replace" select="$replace" />
          <xsl:with-param name="by" select="$by" />
        </xsl:call-template>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="$text" disable-output-escaping="yes" />
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template name="lookup-confluence-user">
    <xsl:param name="input" />
    <xsl:value-of select="document($entities-file)//object[
        @class='ConfluenceUserImpl' and (id=$input or property[@name='atlassianAccountId']=$input)
      ]/property[@name='lowerName']/text()" />
  </xsl:template>

  <xsl:template name="details-block-start">
    <xsl:param name="summary" />
    <xsl:param name="open" select="true()" />
    <xsl:if test="string($summary)">
      <xsl:value-of select="$newline" />
      <xsl:text>&lt;details</xsl:text>
      <xsl:if test="$open"><xsl:text> open</xsl:text></xsl:if>
      <xsl:text>&gt;&lt;summary&gt;&lt;strong&gt;</xsl:text>
      <xsl:value-of select="$summary" />
      <xsl:text>&lt;/strong&gt;&lt;/summary&gt;</xsl:text>
      <xsl:value-of select="$newline" />
      <xsl:value-of select="$newline" />
    </xsl:if>
  </xsl:template>

  <xsl:template name="details-block-stop">
    <xsl:param name="summary" />
    <xsl:if test="string($summary)">
      <xsl:value-of select="$newline" />
      <xsl:text>&lt;/details&gt;</xsl:text>
      <xsl:value-of select="$newline" />
      <xsl:value-of select="$newline" />
    </xsl:if>
  </xsl:template>

  <xsl:template match="*" mode="serialize">
    <xsl:text>&lt;</xsl:text>
    <xsl:value-of select="name()"/>
    <xsl:apply-templates select="@*" mode="serialize" />
    <xsl:choose>
      <xsl:when test="node()">
        <xsl:text>&gt;</xsl:text>
        <xsl:apply-templates mode="serialize" />
        <xsl:text>&lt;/</xsl:text>
        <xsl:value-of select="name()"/>
        <xsl:text>&gt;</xsl:text>
      </xsl:when>
      <xsl:otherwise>
        <xsl:text> /&gt;</xsl:text>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="@*" mode="serialize">
    <xsl:text> </xsl:text>
    <xsl:value-of select="name()"/>
    <xsl:text>="</xsl:text>
    <xsl:value-of select="."/>
    <xsl:text>"</xsl:text>
  </xsl:template>

  <xsl:template match="text()" mode="serialize">
    <xsl:value-of select="."/>
  </xsl:template>

  <xsl:template match="@*|node()" priority="-1">
    <xsl:apply-templates select="@*|node()" />
  </xsl:template>

  <!--
       We should escape all markdown special characters with backslash

       \  backslash
       `  backtick
       *  asterisk
       _  underscore
       {} curly braces
       [] square brackets
       () parentheses
       #  hash mark
       +  plus sign
       -  minus sign (hyphen)
       .  dot
       !  exclamation mark
  -->
  <xsl:template match="text()">
    <xsl:choose>
      <xsl:when test="contains(.,'*')">
        <xsl:call-template name="string-replace-all">
          <xsl:with-param name="text" select="." />
          <xsl:with-param name="replace" select="'*'" />
          <xsl:with-param name="by" select="'\*'" />
        </xsl:call-template>
      </xsl:when>
      <xsl:when test="contains(.,'[')">
        <xsl:call-template name="string-replace-all">
          <xsl:with-param name="text" select="." />
          <xsl:with-param name="replace" select="'['" />
          <xsl:with-param name="by" select="'\['" />
        </xsl:call-template>
      </xsl:when>
      <xsl:when test="normalize-space(.) != ''">
        <xsl:value-of select="." />
      </xsl:when>
    </xsl:choose>
  </xsl:template>

  <!--
       We are intentionally downshifting each level one because we are using h1 for the title.

       HTML generally assumes that there’s *one* h1 and so do most markdown linters.
  -->
  <xsl:template match="h1">
    <xsl:value-of select="$newline" />
    <xsl:text>## </xsl:text>
    <xsl:apply-templates select="node()" />
    <xsl:value-of select="$newline" />
  </xsl:template>

  <xsl:template match="h2">
    <xsl:value-of select="$newline" />
    <xsl:text>### </xsl:text>
    <xsl:apply-templates select="node()" />
    <xsl:value-of select="$newline" />
  </xsl:template>

  <xsl:template match="h3">
    <xsl:value-of select="$newline" />
    <xsl:text>#### </xsl:text>
    <xsl:apply-templates select="node()" />
    <xsl:value-of select="$newline" />
  </xsl:template>

  <xsl:template match="h4">
    <xsl:value-of select="$newline" />
    <xsl:text>##### </xsl:text>
    <xsl:apply-templates select="node()" />
    <xsl:value-of select="$newline" />
  </xsl:template>

  <xsl:template match="h5">
    <xsl:value-of select="$newline" />
    <xsl:text>###### </xsl:text>
    <xsl:apply-templates select="node()" />
    <xsl:value-of select="$newline" />
  </xsl:template>

  <xsl:template match="h6">
    <xsl:value-of select="$newline" />
    <xsl:text>**_</xsl:text>
    <xsl:apply-templates select="node()" />
    <xsl:text>_**</xsl:text>
    <xsl:value-of select="$newline" />
    <xsl:value-of select="$newline" />
  </xsl:template>

  <!-- Deal with some malformed content -->
  <xsl:template match="h1[ac:structured-macro] | h2[ac:structured-macro] | h3[ac:structured-macro]
    | h4[ac:structured-macro] | h5[ac:structured-macro] | h6[ac:structured-macro]
    | h1[ac:macro] | h2[ac:macro] | h3[ac:macro] | h4[ac:macro] | h5[ac:macro] | h6[ac:macro]" priority="5">
    <xsl:apply-templates select="node()" />
  </xsl:template>


  <xsl:template match="p[boolean(../../th) or boolean(../../td)]">
    <xsl:apply-templates select="node()" />
  </xsl:template>

  <xsl:template match="p">
    <xsl:apply-templates select="node()" />
    <xsl:value-of select="$newline" />
    <xsl:value-of select="$newline" />
  </xsl:template>

  <!-- not supported? -->
  <xsl:template match="br[(count(../text()) &gt; 0) and (count(ancestor::table) &gt; 0)]">
    <xsl:text> </xsl:text>
  </xsl:template>

  <xsl:template match="br[(count(../text()) &gt; 0) and (count(ancestor::table) = 0)]">
    <xsl:value-of select="$newline" />
    <xsl:value-of select="$newline" />
    <xsl:if test="count(ancestor::*[local-name() = 'ol' or local-name() = 'ul']) &gt; 0">
      <xsl:text>    </xsl:text>
    </xsl:if>
  </xsl:template>

  <xsl:template match="em[boolean(strong)]|strong[boolean(em)]">
    <xsl:if test="normalize-space(.) != ''"> **_<xsl:value-of select="normalize-space(.)" />_** </xsl:if>
  </xsl:template>

  <xsl:template match="em">
    <xsl:if test="normalize-space(.) != ''"> _<xsl:value-of select="normalize-space(.)" />_ </xsl:if>
  </xsl:template>

  <xsl:template match="strong">
    <xsl:if test="normalize-space(.) != ''"> **<xsl:value-of select="normalize-space(.)" />** </xsl:if>
  </xsl:template>

  <xsl:template match="table[boolean(tbody/tr/th/following-sibling::*[1][self::td])]">
    <xsl:for-each select="tbody/tr/th | tbody/tr/td">
      <xsl:choose>
        <xsl:when test="name() = 'th'">
          <xsl:value-of select="$newline" />
          <xsl:text>- </xsl:text>
          <xsl:apply-templates select="node()" />
          <xsl:text>: </xsl:text>
        </xsl:when>
        <xsl:when test="name() = 'td'">
          <xsl:apply-templates select="node()" />
        </xsl:when>
      </xsl:choose>
    </xsl:for-each>
  </xsl:template>

  <xsl:template match="table[boolean(tbody/tr/th/following-sibling::*[1][self::th])]">
    <xsl:value-of select="$newline" />
    <xsl:apply-templates select="tbody/tr[boolean(th)]" mode="content" />
    <xsl:apply-templates select="tbody/tr[boolean(th)]" mode="dash" />
    <xsl:apply-templates select="tbody/tr[boolean(td)]" mode="content" />
    <xsl:value-of select="$newline" />
    <xsl:value-of select="$newline" />
  </xsl:template>

  <xsl:template match="table[not(tbody/tr/th) and boolean(tbody/tr/td/following-sibling::*[1][self::td])]">
    <xsl:for-each select="tbody/tr">
      <xsl:value-of select="$newline" />
      <xsl:if test="position() = 1">
        <xsl:for-each select="td">
          <xsl:if test="position() = 1"><xsl:text>| </xsl:text></xsl:if>
          <xsl:text> | </xsl:text>
        </xsl:for-each>
        <xsl:value-of select="$newline" />
        <xsl:for-each select="td">
          <xsl:if test="position() = 1">
            <xsl:text>| </xsl:text>
          </xsl:if>
          <xsl:text> --- | </xsl:text>
        </xsl:for-each>
        <xsl:value-of select="$newline" />
      </xsl:if>
      <xsl:text>| </xsl:text>
      <xsl:apply-templates select="td" mode="content" />
    </xsl:for-each>
  </xsl:template>

  <xsl:template match="table[
      boolean(tbody/tr/th/following-sibling::*[1][self::th])
      and boolean(tbody/tr/following-sibling::*[1][self::tr/th])
    ]">
    <xsl:apply-templates select="." mode="serialize" />
    <xsl:value-of select="$newline" />
  </xsl:template>

  <xsl:template match="tr[boolean(th)]" mode="content">
    <xsl:value-of select="$newline" />
    <xsl:text>| </xsl:text>
    <xsl:apply-templates select="th" mode="content" />
  </xsl:template>

  <xsl:template match="tr[boolean(th)]" mode="dash">
    <xsl:value-of select="$newline" />
    <xsl:text>| </xsl:text>
    <xsl:apply-templates select="th" mode="dash" />
  </xsl:template>

  <!--
       <xsl:template match="th|td" mode="content">
       <xsl:value-of select="normalize-space(.)" />
       <xsl:text> | </xsl:text>
       </xsl:template>
  -->

  <xsl:template match="th|td" mode="content">
    <xsl:apply-templates select="." />
    <xsl:text> | </xsl:text>
  </xsl:template>

  <xsl:template match="th" mode="dash">
    <xsl:text> --- | </xsl:text>
  </xsl:template>

  <xsl:template match="tr[boolean(td)]" mode="content">
    <xsl:value-of select="$newline" />
    <xsl:text>| </xsl:text>
    <xsl:apply-templates select="td" mode="content" />
  </xsl:template>

  <xsl:template match="ul[boolean(ancestor::table)]">
    <xsl:text disable-output-escaping="yes">&lt;ul></xsl:text>
    <xsl:apply-templates select="li" mode="html" />
    <xsl:text disable-output-escaping="yes">&lt;/ul></xsl:text>
  </xsl:template>

  <xsl:template match="li" mode="html">
    <xsl:text disable-output-escaping="yes">&lt;li></xsl:text>
    <xsl:apply-templates select="node()" />
    <xsl:text disable-output-escaping="yes">&lt;/li></xsl:text>
  </xsl:template>

  <xsl:template match="ul">
    <xsl:apply-templates select="li" mode="unordered-list" />
    <xsl:value-of select="$newline" />
    <xsl:value-of select="$newline" />
    <xsl:if test="count(ancestor::*[local-name() = 'ol' or local-name() = 'ul']) &gt; 0">
      <xsl:text>    </xsl:text>
    </xsl:if>
  </xsl:template>

  <xsl:template match="ol">
    <xsl:apply-templates select="li" mode="ordered-list" />
    <xsl:value-of select="$newline" />
    <xsl:value-of select="$newline" />
    <xsl:if test="count(ancestor::*[local-name() = 'ol' or local-name() = 'ul']) &gt; 0">
      <xsl:text>    </xsl:text>
    </xsl:if>
  </xsl:template>

  <xsl:template match="li" mode="unordered-list">
    <xsl:value-of select="$newline" />
    <xsl:if test="count(ancestor::*[local-name() = 'ol' or local-name() = 'ul']) &gt; 1">
      <xsl:text>    </xsl:text>
    </xsl:if>
    <xsl:text>- </xsl:text>
    <xsl:apply-templates select="node()" />
  </xsl:template>

  <xsl:template match="li" mode="ordered-list">
    <xsl:value-of select="$newline" />
    <xsl:if test="count(ancestor::*[local-name() = 'ol' or local-name() = 'ul']) &gt; 1">
      <xsl:text>    </xsl:text>
    </xsl:if>
    <xsl:text>1. </xsl:text>
    <xsl:apply-templates select="node()" />
  </xsl:template>

  <xsl:template match="code">
    <xsl:text>`</xsl:text>
    <xsl:apply-templates select="node()" />
    <xsl:text>`</xsl:text>
  </xsl:template>

  <xsl:template match="li/p">
    <xsl:apply-templates select="@*|node()" />
  </xsl:template>

  <!--
       @[lookup(../entities.xml)//object[@class='ConfluenceUserImpl']]
       <ac:link>
       <ri:user ri:account-id="557058:626e8dba-aa41-4ed2-aac4-285e2ff09552" />
       </ac:link
  -->

  <xsl:template match="ac:link[boolean(ri:user)]">
    <xsl:text>@{</xsl:text>
    <xsl:choose>
      <xsl:when test="node()/@ri:account-id">
        <xsl:call-template name="lookup-confluence-user">
          <xsl:with-param name="input" select="node()/@ri:account-id" />
        </xsl:call-template>
      </xsl:when>
      <xsl:when test="node()/@ri:userkey">
        <xsl:call-template name="lookup-confluence-user">
          <xsl:with-param name="input" select="node()/@ri:userkey" />
        </xsl:call-template>
      </xsl:when>
    </xsl:choose>
    <xsl:text>} </xsl:text>
  </xsl:template>

  <!--
       // [text here](http://url.goes/here)  : for external content
       <ac:link>
       <ri:url ri:value="http:///" />
       </ac:link>

       // [[Link Text|WikiLink]]             : for pages
       <ac:link>
       <ri:page ri:space-key="QA" ri:content-title="Public IP Address Reservation" ri:version-at-save="51" />
       </ac:link>
       <ac:link>
       <ri:page ri:space-key="QA" ri:content-title="Public IP Address Reservation" ri:version-at-save="51" />
       <ac:plain-text-link-body><![CDATA[public IP address reservation]]></ac:plain-text-link-body>
       </ac:link>
  -->
  <xsl:template match="ac:link[boolean(ri:url)]">
    <xsl:apply-templates select="ac:link-body | ac:plain-text-link-body | ri:url" mode="title" />
    <xsl:apply-templates select="ri:url" mode="link" />
  </xsl:template>

  <xsl:template match="ac:link[boolean(ri:page)]">
    <xsl:choose>
      <xsl:when test="string($confluence-url)">
        <xsl:text>[</xsl:text>
        <xsl:value-of select="ri:page/@ri:space-key" />
        <xsl:text>: </xsl:text>
        <xsl:choose>
          <xsl:when test="ri:page[not(@ri:space-key=//page/space/key)] and (ac:link-body or ac:plain-text-link-body)">
            <xsl:value-of select="ac:link-body | ac:plain-text-link-body" mode="title" />
          </xsl:when>
          <xsl:otherwise><xsl:value-of select="ri:page/@ri:content-title" /></xsl:otherwise>
        </xsl:choose>
        <xsl:text>](</xsl:text>
        <xsl:value-of select="$confluence-url" />
        <xsl:text>/wiki/search?spaces=</xsl:text>
        <xsl:value-of select="ri:page/@ri:space-key" />
        <xsl:text>&amp;text=</xsl:text>
        <xsl:value-of select="str:encode-uri(ri:page/@ri:content-title, true())" />
        <xsl:text>)</xsl:text>
      </xsl:when>
      <xsl:when test="ac:link-body | ac:plain-text-link-body">
        <xsl:apply-templates select="ac:link-body | ac:plain-text-link-body" mode="title" />
        <xsl:apply-templates select="ri:page" mode="link" />
      </xsl:when>
      <xsl:otherwise>
        <xsl:apply-templates select="ri:page" mode="title" />
        <xsl:apply-templates select="ri:page" mode="link" />
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="ri:url" mode="link">
    <xsl:text>(</xsl:text><xsl:value-of select="@ri:value" /><xsl:text>)</xsl:text>
  </xsl:template>

  <xsl:template match="ri:url" mode="title">
    <xsl:text>[</xsl:text><xsl:value-of select="@ri:value" /><xsl:text>]</xsl:text>
  </xsl:template>

  <xsl:template match="ac:link-body | ac:plain-text-link-body" mode="title">
    <xsl:text>[</xsl:text><xsl:apply-templates select="." /><xsl:text>]</xsl:text>
  </xsl:template>

  <xsl:template match="ri:page[not(//page/space/key=@ri:space-key)]" mode="title">
    <xsl:choose>
      <xsl:when test="string($confluence-url)">
        <xsl:text>[</xsl:text>
        <xsl:value-of select="@ri:space-key" />
        <xsl:text>: </xsl:text>
        <xsl:value-of select="@ri:content-title" />
        <xsl:text>](</xsl:text>
        <xsl:value-of select="$confluence-url" />
        <xsl:text>/wiki/search?spaces=</xsl:text>
        <xsl:value-of select="@ri:space-key" />
        <xsl:text>&amp;text=</xsl:text>
        <xsl:value-of select="str:encode-uri(@ri:content-title, true())" />
        <xsl:text>)</xsl:text>
      </xsl:when>
      <xsl:otherwise>
        <xsl:text>Page &quot;</xsl:text>
        <xsl:value-of select="@ri:content-title" />
        <xsl:text>&quot; in Confluence Space </xsl:text>
        <xsl:value-of select="@ri:space-key" />
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="ri:page[not(@ri:space-key) or //page/space/key=@ri:space-key]" mode="title">
    <xsl:text>[</xsl:text><xsl:value-of select="@ri:content-title" /><xsl:text>]</xsl:text>
  </xsl:template>

  <xsl:template match="ri:page[not(//page/space/key=@ri:space-key)]" mode="link" />

  <xsl:template match="ri:page[not(@ri:space-key) or //page/space/key=@ri:space-key]" mode="link">
    <xsl:text>(</xsl:text>
    <xsl:call-template name="clean-filename">
      <xsl:with-param name="original-name" select="@ri:content-title" />
    </xsl:call-template>
    <xsl:text>.md)</xsl:text>
  </xsl:template>

  <xsl:template match="a[boolean(@href)]">
    <xsl:text>[</xsl:text>
    <xsl:apply-templates select="node()" />
    <xsl:text>](</xsl:text>
    <xsl:value-of select="@href" />
    <xsl:text>)</xsl:text>
  </xsl:template>

  <xsl:template match="ac:task-list">
    <xsl:value-of select="$newline" />
    <xsl:apply-templates select="node()" />
  </xsl:template>

  <xsl:template match="ac:task[not(ac:task-body/ac:placeholder)]">
    <xsl:if test="count(ancestor::*[local-name() = 'ol' or local-name() = 'ul']) &gt; 0">
      <xsl:text>    </xsl:text>
    </xsl:if>
    <xsl:text>- </xsl:text>
    <xsl:apply-templates select="node()" />
    <xsl:value-of select="$newline" />
  </xsl:template>

  <xsl:template match="ac:task-status[not(../ac:task-body/ac:placeholder)]">
    <xsl:choose>
      <xsl:when test="'incomplete'=."><xsl:text>[ ]</xsl:text></xsl:when>
      <xsl:otherwise><xsl:text>[x]</xsl:text></xsl:otherwise>
    </xsl:choose>
    <xsl:text> </xsl:text>
  </xsl:template>

  <xsl:template match="ac:task-id"></xsl:template>
  <xsl:template match="ac:task-status"></xsl:template>

  <xsl:template match="ac:placeholder" />
  <xsl:template match="ac:structured-macro[@ac:name='anchor'] | ac:macro[@ac:name='anchor']" />
  <xsl:template match="ac:structured-macro[@ac:name='details' and ac:parameter[@ac:name='hidden']='true']
    | ac:macro[@ac:name='details' and ac:parameter[@ac:name='hidden']='true']" />

  <xsl:template match="ac:structured-macro[@ac:name='create-from-template'] | ac:macro[@ac:name='create-from-template']">
    <xsl:text>&lt;!-- Create from Template button macro: [</xsl:text>
    <xsl:value-of select="$newline" />
    <xsl:apply-templates select="." mode="serialize" />
    <xsl:value-of select="$newline" />
    <xsl:text>] --&gt;</xsl:text>
    <xsl:value-of select="$newline" />
  </xsl:template>

  <xsl:template match="ac:structured-macro[@ac:name='tasks-report-macro'] | ac:macro[@ac:name='tasks-report-macro']">
    <xsl:text>&lt;!-- Tasks report macro: [</xsl:text>
    <xsl:value-of select="$newline" />
    <xsl:apply-templates select="." mode="serialize" />
    <xsl:value-of select="$newline" />
    <xsl:text>] --&gt;</xsl:text>
    <xsl:value-of select="$newline" />
  </xsl:template>

  <xsl:template match="ac:structured-macro[@ac:name='content-report-table'] | ac:macro[@ac:name='content-report-table']">
    <xsl:text>&lt;!-- Content report macro: [</xsl:text>
    <xsl:value-of select="$newline" />
    <xsl:apply-templates select="." mode="serialize" />
    <xsl:value-of select="$newline" />
    <xsl:text>] --&gt;</xsl:text>
    <xsl:value-of select="$newline" />
  </xsl:template>

  <xsl:template match="ac:structured-macro[@ac:name='children'] | ac:macro[@ac:name='children']">
    <xsl:text>&lt;!-- Children macro: [</xsl:text>
    <xsl:value-of select="$newline" />
    <xsl:apply-templates select="." mode="serialize" />
    <xsl:value-of select="$newline" />
    <xsl:text>] --&gt;</xsl:text>
    <xsl:value-of select="$newline" />
  </xsl:template>

  <xsl:template match="ac:structured-macro[@ac:name='attachments'] | ac:macro[@ac:name='attachments']">
    <xsl:text>&lt;!-- Attachments macro: [</xsl:text>
    <xsl:value-of select="$newline" />
    <xsl:apply-templates select="." mode="serialize" />
    <xsl:value-of select="$newline" />
    <xsl:text>] --&gt;</xsl:text>
    <xsl:value-of select="$newline" />
  </xsl:template>

  <xsl:template match="ac:structured-macro[
      @ac:name='details'
      and boolean(ac:rich-text-body)
      and not(ac:parameter[@ac:name='hidden']='true')
    ] | ac:macro[
      @ac:name='details'
      and boolean(ac:rich-text-body)
      and not(ac:parameter[@ac:name='hidden']='true')
    ]">
    <xsl:apply-templates select="ac:rich-text-body" />
  </xsl:template>

  <xsl:template match="ac:structured-macro[@ac:name='details' and not(ac:rich-text-body)]
    | ac:macro[@ac:name='details' and not(ac:rich-text-body)]">
    <xsl:text>&lt;!-- Details macro: [</xsl:text>
    <xsl:value-of select="$newline" />
    <xsl:apply-templates select="." mode="serialize" />
    <xsl:value-of select="$newline" />
    <xsl:text>] --&gt;</xsl:text>
    <xsl:value-of select="$newline" />
  </xsl:template>

  <xsl:template match="ac:structured-macro[@ac:name='info'] | ac:macro[@ac:name='info']">
    <xsl:text>ℹ</xsl:text>
    <xsl:if test="string(ac:parameter[@ac:name='title'])">
      <xsl:text> **</xsl:text>
      <xsl:value-of select="ac:parameter[@ac:name='title']" />
      <xsl:text>**</xsl:text>
      <xsl:value-of select="$newline" />
    </xsl:if>
    <xsl:value-of select="$newline" />
    <xsl:apply-templates select="ac:rich-text-body" />
  </xsl:template>

  <xsl:template match="ac:structured-macro[@ac:name='detailssummary'] | ac:macro[@ac:name='detailssummary']">
    <xsl:text>&lt;!-- Details Summary macro: [</xsl:text>
    <xsl:value-of select="$newline" />
    <xsl:apply-templates select="." mode="serialize" />
    <xsl:value-of select="$newline" />
    <xsl:text>] --&gt;</xsl:text>
    <xsl:value-of select="$newline" />
  </xsl:template>

  <xsl:template match="ac:structured-macro[@ac:name='pagetree'] | ac:macro[@ac:name='pagetree']">
    <xsl:text>&lt;!-- Page tree macro: [</xsl:text>
    <xsl:value-of select="$newline" />
    <xsl:apply-templates select="." mode="serialize" />
    <xsl:value-of select="$newline" />
    <xsl:text>] --&gt;</xsl:text>
    <xsl:value-of select="$newline" />
  </xsl:template>

  <xsl:template match="ac:structured-macro[@ac:name='recently-updated'] | ac:macro[@ac:name='recently-updated']">
    <xsl:text>&lt;!-- Recently Updated macro: [</xsl:text>
    <xsl:value-of select="$newline" />
    <xsl:apply-templates select="." mode="serialize" />
    <xsl:value-of select="$newline" />
    <xsl:text>] --&gt;</xsl:text>
    <xsl:value-of select="$newline" />
  </xsl:template>

  <xsl:template match="ac:structured-macro[@ac:name='gliffy'] | ac:macro[@ac:name='gliffy']">
    <xsl:text>&lt;!-- Gliffy macro: [</xsl:text>
    <xsl:value-of select="$newline" />
    <xsl:apply-templates select="." mode="serialize" />
    <xsl:value-of select="$newline" />
    <xsl:text>] --&gt;</xsl:text>
    <xsl:value-of select="$newline" />
  </xsl:template>

  <xsl:template match="ac:structured-macro[@ac:name='blog-posts'] | ac:macro[@ac:name='blog-posts']">
    <xsl:text>&lt;!-- Blog Posts macro: [</xsl:text>
    <xsl:value-of select="$newline" />
    <xsl:apply-templates select="." mode="serialize" />
    <xsl:value-of select="$newline" />
    <xsl:text>] --&gt;</xsl:text>
    <xsl:value-of select="$newline" />
  </xsl:template>

  <xsl:template match="ac:structured-macro[@ac:name='contentbylabel'] | ac:macro[@ac:name='contentbylabel']">
    <xsl:text>&lt;!-- Related Content (by label) macro: [</xsl:text>
    <xsl:value-of select="$newline" />
    <xsl:apply-templates select="." mode="serialize" />
    <xsl:value-of select="$newline" />
    <xsl:text>] --&gt;</xsl:text>
    <xsl:value-of select="$newline" />
  </xsl:template>

  <xsl:template match="ac:structured-macro[@ac:name='iframe'] | ac:macro[@ac:name='iframe']">
    <xsl:text>&lt;iframe src=&quot;</xsl:text>
    <xsl:value-of select="ac:parameter[@ac:name='src']/ri:url/@ri:value" />
    <xsl:text>&quot;</xsl:text>
    <xsl:if test="string(ac:parameter[@ac:name='width'])">
      <xsl:text> width=&quot;</xsl:text>
      <xsl:value-of select="ac:parameter[@ac:name='width']" />
      <xsl:text>&quot;</xsl:text>
    </xsl:if>
    <xsl:if test="string(ac:parameter[@ac:name='height'])">
      <xsl:text> height=&quot;</xsl:text>
      <xsl:value-of select="ac:parameter[@ac:name='height']" />
      <xsl:text>&quot;</xsl:text>
    </xsl:if>
    <xsl:text>&gt;&lt;/iframe&gt;</xsl:text>
    <xsl:value-of select="$newline" />
    <xsl:value-of select="$newline" />
    <xsl:text>&lt;!-- iframe macro: [</xsl:text>
    <xsl:value-of select="$newline" />
    <xsl:apply-templates select="." mode="serialize" />
    <xsl:value-of select="$newline" />
    <xsl:text>] --&gt;</xsl:text>
    <xsl:value-of select="$newline" />
  </xsl:template>

  <xsl:template match="ac:structured-macro[@ac:name='status'] | ac:macro[@ac:name='status']">
    <xsl:value-of select="ac:parameter[@ac:name='title']" />
  </xsl:template>

  <!--
       <ac:image ac:width="800"> // ac:height="266" ac:width="634"
       <ri:attachment ri:filename="cluster_modules.png" ri:version-at-save="1" />
       </ac:image>
       TODO: support width/height? {:height="36px" width="36px"}
  -->
  <xsl:template match="ac:image[boolean(ri:url)]">
    <xsl:text>![</xsl:text>
    <xsl:value-of select="@ac:alt" />
    <xsl:text>](</xsl:text>
    <xsl:value-of select="ri:url/@ri:value" />
    <xsl:text>)</xsl:text>
  </xsl:template>

  <xsl:template match="ac:image[boolean(ri:attachment)]">
    <xsl:variable name="title" select="ri:attachment/@ri:filename" />
    <xsl:variable name="attachment" select="document($attachments-file)/images/image[@title=$title]" />
    <xsl:text>![</xsl:text>
    <xsl:choose>
      <xsl:when test="string(@ac:alt)"><xsl:value-of select="@ac:alt" /></xsl:when>
      <xsl:otherwise><xsl:value-of select="$attachment/@title"/></xsl:otherwise>
    </xsl:choose>
    <xsl:text>](</xsl:text>
    <xsl:value-of select="$attachment/@path"/>
    <xsl:text>)</xsl:text>
  </xsl:template>

  <xsl:template match="ac:parameter[(@ac:name='borderColor' or @ac:name='bgColor')]"></xsl:template>

  <!--
       <ac:structured-macro ac:name="code" ac:schema-version="1" ac:macro-id="d4ad3989-bce6-4b8c-b174-fcc0e9bf9a42">
       <ac:parameter ac:name="language">bash</ac:parameter>
       <ac:parameter ac:name="theme">Confluence</ac:parameter>
       <ac:parameter ac:name="linenumbers">true</ac:parameter>
       <ac:plain-text-body><![CDATA[com.eucalyptus.empyrean.registration.map.cluster=clusterservice]]></ac:plain-text-body>
       </ac:structured-macro>
  -->
  <xsl:template match="ac:structured-macro[@ac:name='code'] | ac:macro[@ac:name='code']">
    <xsl:call-template name="details-block-start">
      <xsl:with-param name="summary" select="ac:parameter[@ac:name='title']" />
    </xsl:call-template>
    <xsl:value-of select="$newline" />
    <xsl:text>```</xsl:text>
    <xsl:value-of select="ac:parameter[@ac:name = 'language']" />
    <xsl:value-of select="$newline" />
    <xsl:value-of select="ac:plain-text-body" />
    <xsl:value-of select="$newline" />
    <xsl:text>```</xsl:text>
    <xsl:value-of select="$newline" />
    <xsl:call-template name="details-block-stop">
      <xsl:with-param name="summary" select="ac:parameter[@ac:name='title']" />
    </xsl:call-template>
  </xsl:template>

  <xsl:template match="pre">
    <xsl:value-of select="$newline" />
    <xsl:text>```</xsl:text>
    <xsl:value-of select="$newline" />
    <xsl:apply-templates select="node()" />
    <xsl:value-of select="$newline" />
    <xsl:text>```</xsl:text>
    <xsl:value-of select="$newline" />
  </xsl:template>

  <!--
       <ac:structured-macro ac:name="jira" ac:schema-version="1" ac:macro-id="eb159d99-7736-4a43-829e-3fe7580a453f">
       <ac:parameter ac:name="server">JIRA (eucalyptus.atlassian.net)</ac:parameter>
       <ac:parameter ac:name="serverId">40f6fb44-bbe5-3de3-b0a9-368eb548a761</ac:parameter>
       <ac:parameter ac:name="key">EUCA-13384</ac:parameter>
       </ac:structured-macro>
       https://eucalyptus.atlassian.net/browse/EUCA-13384
  -->
  <xsl:template match="ac:structured-macro[@ac:name='jira'] | ac:macro[@ac:name='jira']">
    <xsl:choose>
      <xsl:when test="string($jira-url)">
        <xsl:text>[JIRA: </xsl:text>
        <xsl:value-of select="ac:parameter[@ac:name='key']" />
        <xsl:text>](</xsl:text>
        <xsl:value-of select="$jira-url" />
        <xsl:text>/browse/</xsl:text>
        <xsl:value-of select="ac:parameter[@ac:name='key']" />
        <xsl:text>) </xsl:text>
      </xsl:when>
      <xsl:otherwise>
        <xsl:text>[</xsl:text>
        <xsl:value-of select="ac:parameter[@ac:name='key']" />
        <xsl:text> </xsl:text>
        <xsl:value-of select="ac:parameter[@ac:name='server']" />
        <xsl:text>](https://</xsl:text>
        <xsl:value-of select="substring-after(substring-before(ac:parameter[@ac:name='server'],')'),'(')" />
        <xsl:text>/browse/</xsl:text>
        <xsl:value-of select="ac:parameter[@ac:name='key']" />
        <xsl:text>) </xsl:text>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!--
       <ac:structured-macro ac:name="toc" ac:schema-version="1" ac:macro-id="6010db53-d32b-4ea9-b8b1-abca61d9a75c">
       <ac:parameter ac:name="minLevel">2</ac:parameter>
       <ac:parameter ac:name="indent">10px</ac:parameter>
       <ac:parameter ac:name="printable">false</ac:parameter>
       </ac:structured-macro>

       * [Scope](#scope)
       * [API](#api)
       * [Long Identifiers](#long-identifiers)
       * [API Details](#api-details)
  -->
  <xsl:template match="ac:structured-macro[@ac:name='toc'] | ac:macro[@ac:name='toc']">
    <!-- TODO flat toc support? -->
    <xsl:variable name="min-level">
      <xsl:choose>
        <xsl:when test="ac:parameter[@ac:name = 'minLevel']">
          <xsl:value-of select="ac:parameter[@ac:name = 'minLevel']" />
        </xsl:when>
        <xsl:otherwise>1</xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:for-each select="/page/body/*[(local-name() = 'h1' or local-name() = 'h2' or local-name() = 'h3') and text()]">
      <xsl:choose>
        <xsl:when test="number(substring-after(local-name(),'h')) - $min-level = 2">
          <xsl:text>    * [</xsl:text>
          <xsl:value-of select="node()" />
          <xsl:text>](#</xsl:text>
          <xsl:value-of select="translate(translate(node(),$upper,$lower),' ','-')" />
          <xsl:text>)</xsl:text>
          <xsl:value-of select="$newline" />
        </xsl:when>
        <xsl:when test="number(substring-after(local-name(),'h')) - $min-level = 1">
          <xsl:text>  * [</xsl:text>
          <xsl:value-of select="node()" />
          <xsl:text>](#</xsl:text>
          <xsl:value-of select="translate(translate(node(),$upper,$lower),' ','-')" />
          <xsl:text>)</xsl:text>
          <xsl:value-of select="$newline" />
        </xsl:when>
        <xsl:when test="number(substring-after(local-name(),'h')) - $min-level = 0">
          <xsl:text>* [</xsl:text>
          <xsl:value-of select="node()" />
          <xsl:text>](#</xsl:text>
          <xsl:value-of select="translate(translate(node(),$upper,$lower),' ','-')" />
          <xsl:text>)</xsl:text>
          <xsl:value-of select="$newline" />
        </xsl:when>
      </xsl:choose>
    </xsl:for-each>
  </xsl:template>

  <xsl:template match="time">
    <xsl:value-of select="@datetime" />
  </xsl:template>

  <xsl:template match="body">
    <xsl:apply-templates select="@*|node()" />
    <xsl:value-of select="$newline" />
  </xsl:template>

  <xsl:template match="category">
    <xsl:text>[[category.</xsl:text>
    <xsl:value-of select="." />
    <xsl:text>]]</xsl:text>
    <xsl:value-of select="$newline" />
  </xsl:template>

  <xsl:template match="category" mode="front-matter">
    <xsl:if test="position() = 1">
      <xsl:text>categories:</xsl:text>
      <xsl:value-of select="$newline" />
    </xsl:if>
    <xsl:text>  - </xsl:text>
    <xsl:value-of select="." />
    <xsl:value-of select="$newline" />
  </xsl:template>

  <xsl:template match="parent" mode="front-matter">
    <xsl:if test="position() = 1">
      <xsl:text>parents:</xsl:text>
      <xsl:value-of select="$newline" />
    </xsl:if>
    <xsl:text>  - title: &quot;</xsl:text>
    <xsl:value-of select="title" />
    <xsl:text>&quot;</xsl:text>
    <xsl:value-of select="$newline" />
    <xsl:text>    filename: &quot;</xsl:text>
    <xsl:value-of select="filename" />
    <xsl:text>&quot;</xsl:text>
    <xsl:value-of select="$newline" />
  </xsl:template>

  <xsl:template match="parent" mode="breadcrumbs">
    <xsl:if test="position() = 1">
      <xsl:text>Breadcrumbs: </xsl:text>
    </xsl:if>
    <xsl:if test="position() > 1">
      <xsl:text> &gt; </xsl:text>
    </xsl:if>
    <xsl:text>[</xsl:text>
    <xsl:value-of select="title" />
    <xsl:text>](</xsl:text>
    <xsl:value-of select="filename" />
    <xsl:text>)</xsl:text>
    <xsl:if test="position() = last()">
      <xsl:value-of select="$newline" />
      <xsl:value-of select="$newline" />
    </xsl:if>
  </xsl:template>

  <xsl:template match="title" mode="front-matter">
    <xsl:text>title: &quot;</xsl:text>
    <xsl:value-of select="." />
    <xsl:text>&quot;</xsl:text>
    <xsl:value-of select="$newline" />
  </xsl:template>

  <xsl:template match="created | last-modified" mode="front-matter">
    <xsl:if test="by">
      <xsl:value-of select="name()" />
      <xsl:text>-by: &quot;</xsl:text>
      <xsl:value-of select="by" />
      <xsl:text>&quot;</xsl:text>
      <xsl:value-of select="$newline" />
    </xsl:if>
    <xsl:value-of select="name()" />
    <xsl:text>-at: &quot;</xsl:text>
    <xsl:value-of select="at" />
    <xsl:text>&quot;</xsl:text>
    <xsl:value-of select="$newline" />
  </xsl:template>

  <xsl:template match="page" mode="front-matter">
    <xsl:value-of select="'---'" />
    <xsl:value-of select="$newline" />
    <xsl:apply-templates select="title" mode="front-matter" />
    <xsl:apply-templates select="created" mode="front-matter" />
    <xsl:apply-templates select="last-modified" mode="front-matter" />
    <xsl:apply-templates select="category" mode="front-matter" />
    <xsl:apply-templates select="parent" mode="front-matter" />
    <xsl:value-of select="'---'" />
    <xsl:value-of select="$newline" />
    <xsl:value-of select="$newline" />
  </xsl:template>

  <xsl:template match="page" mode="title">
    <xsl:text># </xsl:text>
    <xsl:value-of select="title" />
    <xsl:value-of select="$newline" />
    <xsl:value-of select="$newline" />
  </xsl:template>

  <xsl:template match="page">
    <xsl:apply-templates select="." mode="front-matter" />
    <xsl:apply-templates select="." mode="title" />
    <xsl:apply-templates select="parent" mode="breadcrumbs" />
    <xsl:apply-templates select="body" />
    <xsl:text>---</xsl:text>
    <xsl:value-of select="$newline" />
    <xsl:value-of select="$newline" />
    <xsl:apply-templates select="category" />
  </xsl:template>

</xsl:stylesheet>
