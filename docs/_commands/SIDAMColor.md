---
title: "SIDAMColor"
---
<p class="function_definition">SIDAMColor(<span class="function_variables">[grfName, imgList, ctable, rev, log, minRGB, maxRGB, history]</span>)</p>

Set a color table to a image or a list of images.

## Parameters

**grfName :** ***string, default `WinName(0,1,1)`***  
The name of a window.

**imgList :** ***string, default `ImageNameList(WinName(0,1,1),";")`***  
The list of images. A single image is also accepted.

**ctable :** ***string***  
The name of a color table or path to a color table wave.
Unless specified, the present value is used.

**rev :** ***int {0 or !0}***  
Set !0 to reverse the order of colors in the color table.
Unless specified, the present value is used.

**log :** ***int {0 or !0}***  
Set !0 to use logarithmically-spaced colors.
Unless specified, the present value is used.

**minRGB, maxRGB :** ***wave***  
Set the color for values less than the minimum/maximum value of the range.
Unless specified, the present value is used.
- {0} : use the color for the minimum/maximum value of the range.
- {NaN} : transparent.
- {r,g,b} : specify the color.

**history :** ***int {0 or !0}, default 0***  
Set !0 to print this command in the history.

## Returns
***variable***  
* 0: Normal exit
* !0: Any error in input parameters
