---
title: "SIDAM_ColorTableLog"
---
<p class="function_definition">SIDAM_ColorTableLog(<span class="function_variables">grfName, imgName</span>)</p>

Returns if a logarithmically-spaced color is set.
(log version of `WM_ColorTableReversed`)

## Parameters

**grfName :** ***string***  
The name of window

**imgName :** ***string***  
The name of an image.

## Returns
***int***  
* 0: a linearly-spaced color.
* 1: a logarithmically-spaced color.
* -1: any error.
