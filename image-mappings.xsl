<?xml version="1.0" encoding="UTF-8"?>
<!--
Transform the image mapping xml to some bash commands
-->
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

  <xsl:output method="text"/>
  <xsl:param name="input-path" select="'.'" />
  <xsl:param name="output-path" select="'out'" />
  <xsl:param name="script-path" />
  <xsl:param name="debug" />

  <xsl:template match="image" mode="mkdir">
    <xsl:text>mkdir</xsl:text>
    <xsl:if test="$debug='true'"><xsl:text> -v</xsl:text></xsl:if>
    <xsl:text> -p &quot;</xsl:text>
    <xsl:value-of select="$output-path" />
    <xsl:text>/wiki/$(dirname &apos;</xsl:text>
    <xsl:value-of select="@path" />
    <xsl:text>&apos;)&quot;&#x0a;</xsl:text>
  </xsl:template>

  <xsl:template match="image" mode="cp">
    <xsl:text>cp</xsl:text>
    <xsl:if test="$debug='true'"><xsl:text> -v</xsl:text></xsl:if>
    <xsl:text> &quot;</xsl:text>
    <xsl:value-of select="$input-path" />
    <xsl:text>/</xsl:text>
    <xsl:value-of select="@attachment" />
    <xsl:text>&quot; &quot;</xsl:text>
    <xsl:value-of select="$output-path" />
    <xsl:text>/wiki/</xsl:text>
    <xsl:value-of select="@path" />
    <xsl:text>&quot;&#x0a;</xsl:text>
  </xsl:template>

  <xsl:template match="/">
    <xsl:for-each select="images/image">
      <xsl:variable name="source" select="@attachment" />
      <xsl:variable name="target" select="@path" />
      <xsl:apply-templates select="." mode="mkdir" />
      <xsl:apply-templates select="." mode="cp" />
    </xsl:for-each>
  </xsl:template>

</xsl:stylesheet>
