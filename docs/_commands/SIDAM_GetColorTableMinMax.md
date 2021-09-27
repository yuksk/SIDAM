---
title: "SIDAM_GetColorTableMinMax"
---
<p class="function_definition">SIDAM_GetColorTableMinMax(<span class="function_variables">grfName, imgName, &zmin, &zmax, [allowNaN]</span>)</p>

Extension of `WM_GetColorTableMinMax`.

## Parameters

**grfName :** ***string***  
The name of window

**imgName :** ***string***  
The name of an image.

**zmin, zmax :** ***variable***  
The minimum and maximum values of ctab are returned.

**allowNaN :** ***int {0 or !0}, default 0***  
When `allowNaN` = 0, `zmin` and `zmax` are always numeric as
`WM_GetColorTableMinMax`. When !0, `zmin` and `zmax` are NaN if they
are auto.

## Returns
***int***  
* 0: Normal exit
* 1: Any error
