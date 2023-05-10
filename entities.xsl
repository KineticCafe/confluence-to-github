<?xml version="1.0" encoding="UTF-8"?>
<!--
     Transform a Confluence XML format space export to multiple xml pages.
-->
<xsl:stylesheet version="1.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:exsl="http://exslt.org/common"
                extension-element-prefixes="exsl"
  >

  <xsl:output method="xml" standalone="yes" indent="yes"/>

  <xsl:param name="output-path" select="'out/'" />
  <xsl:param name="dtd-path" select="'../..'" />
  <xsl:param name="debug" select="'false'" />

  <xsl:template name="to-lowercase">
    <xsl:param name="input" />
    <xsl:variable name="lower" select="'abcdefghijklmnopqrstuvwxyz'" />
    <xsl:variable name="upper" select="'ABCDEFGHIJKLMNOPQRSTUVWXYZ'" />
    <xsl:value-of select="translate($input, $upper, $lower)" />
  </xsl:template>

  <xsl:template name="clean-filename">
    <xsl:param name="original-name" />
    <xsl:variable name="apos" select='"&apos;"' />
    <xsl:variable name="was" select="concat(' /:*?|&quot;&lt;&gt;`()%,', $apos)" />
    <xsl:variable name="now" select="'--'"/>
    <xsl:call-template name="to-lowercase">
      <xsl:with-param name="input">
        <xsl:value-of select="translate($original-name, $was, $now)" />
      </xsl:with-param>
    </xsl:call-template>
  </xsl:template>

  <xsl:template name="page-filename">
    <xsl:param name="page" />
    <xsl:call-template name="clean-filename">
      <xsl:with-param name="original-name" select="$page/property[@name='lowerTitle']" />
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
        <xsl:value-of select="substring-before($text,$replace)" disable-output-escaping="yes"/>
        <xsl:value-of select="$by" disable-output-escaping="yes"/>
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
    <xsl:value-of select="//object[
        @class='ConfluenceUserImpl' and (id=$input or property[@name='atlassianAccountId']=$input)
      ]/property[@name='lowerName']/text()" />
  </xsl:template>

  <!-- Variables -->

  <xsl:variable name="newline" select="'&#xa;'" />

  <xsl:variable name="space" select="//object[@class='Space']" />
  <xsl:variable name="space-title" select="$space/property[@name='name']" />
  <xsl:variable name="space-path">
    <xsl:call-template name="clean-filename">
      <xsl:with-param name="original-name" select="$space-title" />
    </xsl:call-template>
  </xsl:variable>
  <xsl:variable name="space-key" select="$space/property[@name='key']" />
  <xsl:variable name="space-lower-key" select="$space/property[@name='lowerKey']" />
  <xsl:variable name="space-description" select="//object[
      @class='BodyContent' and
      id=//object[
        @class='SpaceDescription' and
        id=$space/property[@name='description' and @class='SpaceDescription']/id
      ]/id
    ]" />

  <!-- Main execution templates -->

  <xsl:template match="@*|node()" priority="-1">
    <xsl:apply-templates select="@*|node()"/>
  </xsl:template>

  <xsl:template match="text()">
    <xsl:if test="normalize-space(.) != ''">
      <xsl:value-of select="."/>
    </xsl:if>
  </xsl:template>


  <xsl:template match="object[@class='Page']">
    <!--
         bad title characters \ / : * ? " < > |
    -->
    <xsl:variable name="page-filename">
      <xsl:call-template name="page-filename">
        <xsl:with-param name="page" select="." />
      </xsl:call-template>
    </xsl:variable>
    <xsl:if test="$debug='true'">
      <xsl:message>
        <xsl:text>Extracting </xsl:text>
        <xsl:value-of select="property[@name='title']" />
        <xsl:text>&#x0a;</xsl:text>
      </xsl:message>
    </xsl:if>
    <exsl:document href="{$output-path}/page-xml/{$page-filename}.xml" format="xml" standalone="no" indent="yes" doctype-system="{$dtd-path}/page.dtd">
      <page
        xmlns:ac="http://www.atlassian.com/schema/confluence/4/ac/"
        xmlns:ri="http://www.atlassian.com/schema/confluence/4/ri/"
        >
        <space>
          <title><xsl:value-of select="$space-title" /></title>
          <description>
            <xsl:call-template name="string-replace-all">
              <xsl:with-param name="text" select="$space-description/body" />
              <xsl:with-param name="replace" select="']] >'" />
              <xsl:with-param name="by" select="']]>'" />
            </xsl:call-template>
          </description>
          <path><xsl:value-of select="$space-path" /></path>
          <key><xsl:value-of select="$space-key" /></key>
          <lower-key><xsl:value-of select="$space-lower-key" /></lower-key>
        </space>
        <title><xsl:value-of select="property[@name='title']"/></title>
        <lower-title><xsl:value-of select="property[@name='lowerTitle']"/></lower-title>
        <page-filename><xsl:value-of select="$page-filename" /></page-filename>
        <body>
          <!-- fixup nested CDATA closes in body -->
          <xsl:call-template name="string-replace-all">
            <xsl:with-param name="text" select="/hibernate-generic/object[@class='BodyContent' and id=current()/collection[@name='bodyContents']/element[@class='BodyContent']/id]/property[@name='body']" />
            <xsl:with-param name="replace" select="']] >'" />
            <xsl:with-param name="by" select="']]>'" />
          </xsl:call-template>
        </body>
        <category>confluence</category>
        <xsl:apply-templates select="collection[@name='labellings']" />
        <created>
          <by>
            <xsl:call-template name="lookup-confluence-user">
              <xsl:with-param name="input" select="property[@name='creator']/id" />
            </xsl:call-template>
          </by>
          <at><xsl:value-of select="property[@name='creationDate']" /></at>
        </created>
        <xsl:if test="not(property[@name='lastModificationDate']=property[@name='creationDate'])">
          <last-modified>
            <by>
              <xsl:call-template name="lookup-confluence-user">
                <xsl:with-param name="input" select="property[@name='lastModifier']/id" />
              </xsl:call-template>
            </by>
            <at><xsl:value-of select="property[@name = 'lastModificationDate']" /></at>
          </last-modified>
        </xsl:if>
        <xsl:apply-templates select="." mode="parent" />
      </page>
    </exsl:document>
  </xsl:template>

  <xsl:template match="element[@class='Labelling']">
    <xsl:variable name="labelling-id" select="id" />
    <xsl:variable name="label-id" select="//object[@class='Labelling' and id=$labelling-id]/property[@name='label']/id" />
    <xsl:variable name="label" select="//object[@class='Label' and id=$label-id]" />
    <xsl:variable name="label-name" select="$label/property[@name='name']" />
    <xsl:variable name="label-namespace" select="$label/property[@name='namespace']" />
    <xsl:choose>
      <xsl:when test="$label-namespace='my' or starts-with($label-namespace, 'com.atlassian')" />
        <xsl:when test="$label-namespace='global' or $label-namespace='team'">
          <category><xsl:value-of select="$label-name"/></category>
        </xsl:when>
        <xsl:otherwise>
          <category>
            <xsl:value-of select="$label-namespace"/>
            <xsl:text>:</xsl:text>
            <xsl:value-of select="$label-name"/>
          </category>
        </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="object[@class='Page']" mode="parent">
    <xsl:if test="property[@name='parent' and @class='Page']">
      <xsl:variable name="parentId" select="property[@name='parent' and @class='Page']/id"/>
      <xsl:variable name="parentPage" select="//object[@class='Page' and id=$parentId]"/>
      <xsl:apply-templates select="$parentPage" mode="parent"/>
      <parent>
        <title><xsl:value-of select="$parentPage/property[@name='title']"/></title>
        <filename>
          <xsl:call-template name="page-filename">
            <xsl:with-param name="page" select="$parentPage" />
          </xsl:call-template>
        </filename>
      </parent>
    </xsl:if>
  </xsl:template>

  <xsl:template match="id" mode="image">
    <xsl:variable name="attachment-id" select="string(text())"/>
    <xsl:if test="/hibernate-generic/object[
        @class='Attachment' and id=$attachment-id and ''=property[@name='originalVersionId']
      ]">
      <xsl:variable name="attachment" select="/hibernate-generic/object[@class='Attachment' and id=$attachment-id]" />
      <xsl:variable name="owner-id" select="../../../id" />
      <xsl:variable name="attachment-title" select="$attachment/property[@name='title']" />
      <xsl:variable name="attachment-version" select="$attachment/property[@name='version']" />
      <xsl:variable name="attachment-filename">
        <xsl:call-template name="clean-filename">
          <xsl:with-param name="original-name" select="$attachment-title" />
        </xsl:call-template>
      </xsl:variable>
      <image
        attachment="attachments/{$owner-id}/{$attachment-id}/{$attachment-version}"
        path="images/{$space-path}/{$attachment-filename}"
        title="{$attachment-title}"
        />
    </xsl:if>
  </xsl:template>

  <xsl:template match="/">
    <!--
         export will include old versions of current pages and pages that
         have been deleted.

         select only pages with a current version (i.e. historicalVersions
         element present)
    -->
    <xsl:apply-templates select="/hibernate-generic/object[
        @class='Page' and not(property[@name='contentStatus']='draft') and (
          boolean(collection[@name='historicalVersions']) or (
            not(
              id=//hibernate-generic/object[@class='Page']/collection[@name='historicalVersions']/element/id
            )
            and not(
              id = //hibernate-generic/object[
                @class='Page' and not(property[@name='contentStatus']='draft')
              ]/property[@name='originalVersionId']
            )
          )
        )
      ]" />

    <xsl:if test="$debug='true'">
      <xsl:message>
        <xsl:text>Creating the attachment mapping file.
      </xsl:message>
    </xsl:if>

    <!--
         create a mapping document for attachments to wiki images

         attachments/$page-id/$attachment-id/$version - - > images/$space-path/$clean-filename
         attachments/100434301/104595714/1            - - > images/services/intellij_idea_annotation_processors.gif
    -->
    <exsl:document href="{$output-path}/image-mappings.xml" format="xml" standalone="yes" indent="yes">
      <images>
        <xsl:apply-templates select="/hibernate-generic/object[
            @class='Page' and not(property[@name='contentStatus'] = 'draft') and (
              boolean(collection[@name='historicalVersions']) or (
                not(
                  id=//hibernate-generic/object[@class='Page']/collection[@name='historicalVersions']/element/id)
                and not(
                  id=//hibernate-generic/object[
                    @class='Page' and not(property[@name='contentStatus']='draft')
                  ]/property[@name='originalVersionId']
                )
              )
            )
          ]/collection[@name='attachments']/element[@class='Attachment']/id[@name='id']" mode="image"/>

      </images>
    </exsl:document>
  </xsl:template>

</xsl:stylesheet>
