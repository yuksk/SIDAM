---
title: "SIDAMRange"
---
<p class="function_definition">SIDAMRange(<span class="function_variables">[grfName, imgList, zmin, zmax, zminmode, zmaxmode]</span>)</p>

Set a range of a color scale used for a image(s).

## Parameters

**grfName :** ***string, default `WinName(0,1,1)`***  
The name of window.

**imgList :** ***string, default `ImageNameList(grfName,";")`***  
The list of images.

**zminmode :** ***int {0 -- 4}, default 1***  
The z mode for min.
* 0: auto
* 1: fix
* 2: sigma
* 3: cut
* 4: logsigma

**zmaxmode :** ***int {0 -- 4}, default 1***  
The z mode for max. The numbers are the same as those for the zminmode.

**zmin :** ***variable***  
The minimum value of the range.
When the zmaxmode is 2 or 3, this is a parameter of the mode.

**zmax :** ***variable***  
The maximum value of the range.
When the zminmode is 2 or 3, this is a parameter of the mode.
