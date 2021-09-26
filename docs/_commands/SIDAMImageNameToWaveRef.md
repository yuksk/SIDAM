---
title: "SIDAMImageNameToWaveRef"
---
<p class="function_definition">SIDAMImageNameToWaveRef(<span class="function_variables">grfName, [imgName, displayed]</span>)</p>

Extension of `ImageNameToWaveRef()`

## Parameters

**grfName :** ***string***  
Name of a window.

**imgName :** ***string, default `StringFromList(0, ImageNameList(grfName, ";"))`***  
Name of an image. The default is the top image in the window.
If this is given, this function works as `ImageNameToWaveRef()`. 

**displayed :** ***int {0, !0}***  
Set !0 to return a 2D free wave of the displaye area, plane, and imCmplxMode.

## Returns
***wave***  
A wave reference to an image in the window, or a free wave which is
a part of a wave shown in the window.
