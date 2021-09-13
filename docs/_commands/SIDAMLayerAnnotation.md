---
title: "SIDAMLayerAnnotation"
---
<p class="function_definition">SIDAMLayerAnnotation(<span class="function_variables">legendStr, [grfName, imgName, digit, unit, sign, prefix, style]</span>)</p>

Add an annotation text following the layer value of an image.

## Parameters

**legendStr :** ***string***  
Legend string. If empty, stop updating the layer annotation.

**grfName :** ***string, default `WinName(0,1,1)`***  
The name of window.

**imgName :** ***string, default `StringFromList(0, ImageNameList(grfName, ";"))`***  
The name of image.

**digit :** ***int, default 0***  
The number of digits after the decimal point.

**unit :** ***int {0 or !0}, default 1***  
Set !0 to use the unit of the wave.

**sign :** ***int {0 or !0}, default 1***  
Set !0 to use "+" for positive values.

**prefix:** ***int {0 or !0}, default 1***  
Set !0 to use a prefix such as k and m.

**style:** ***int {0 -- 2}, default 1***  
Apply a style.
* 0: No style
* 1: White background
* 2: Black background

## Returns
***string***  
The name of textbox.
