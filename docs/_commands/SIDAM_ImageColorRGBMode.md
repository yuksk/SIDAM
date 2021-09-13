---
title: "SIDAM_ImageColorRGBMode"
---
<p class="function_definition">SIDAM_ImageColorRGBMode(<span class="function_variables">grfName, imgName, key</span>)</p>

Returns mode of minRGB/maxRGB.

## Parameters

**grfName :** ***string***  
The name of window

**imgName :** ***string***  
The name of an image.

**key :** ***string***  
"minRGB" or "maxRGB"

## Returns
***int***  
* 0: use first/last color
* 1: (r,g,b)
* 2: transparent
* -1: any error
