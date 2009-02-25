<?xml version="1.0" encoding="UTF-8"?>

<xsl:stylesheet version="1.0"
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	xmlns="http://www.w3.org/1999/xhtml">

	<xsl:output method="xml" encoding="UTF-8" omit-xml-declaration="no" indent="no"
		doctype-public="-//W3C//DTD XHTML 1.0 Strict//EN"
		doctype-system="http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd"/>

	<xsl:template match="/log">
		<html xml:lang="en" lang="en">
			<head>
				<meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
				<title>Log</title>
				<link rel="stylesheet" href="changelog.css" type="text/css" />
				<script src="../ga.js" type="text/javascript"></script>
			</head>
			<body>
				<ul>
					<xsl:apply-templates select="up" />
				</ul>
			</body>
		</html>
	</xsl:template>

	<xsl:template match="up">
		<li><span class="rev">rev. <xsl:value-of select="@rev"/></span>, <xsl:value-of select="@date"/>&#160;(<xsl:value-of select="@author"/>)
			<ul>
				<xsl:apply-templates select="new" />
				<xsl:apply-templates select="chg" />
				<xsl:apply-templates select="bug" />
			</ul>
		</li>
	</xsl:template>
	
	<xsl:template match="bug|chg|new">
		<li class="{name()}"><span class="{name()}"><xsl:value-of select="translate(name(),'bugchgnew','BUGCHGNEW')"/></span>: <xsl:apply-templates/><xsl:if test="@rev"> (rev. <xsl:value-of select="@rev"/>)</xsl:if></li>
	</xsl:template>
	
	<xsl:template match="sub">
		<ul class="sub"><xsl:apply-templates/></ul>
	</xsl:template>
	
	<xsl:template match="item">
		<li><xsl:apply-templates/><xsl:if test="@rev"> (rev. <xsl:value-of select="@rev"/>)</xsl:if></li>
	</xsl:template>
	
	<xsl:template match="*">
		<xsl:element name="{local-name()}">
			<xsl:for-each select="@*">
				<xsl:attribute name="{name()}">
					<xsl:value-of select="."/>
				</xsl:attribute>
			</xsl:for-each>
			<xsl:apply-templates/>
		</xsl:element>
	</xsl:template>

</xsl:stylesheet>