---
title: "SIDAMScalebar"
---
<p class="function_definition">SIDAMScalebar(<span class="function_variables">[grfName, anchor, size, fgRGBA, bgRGBA, prefix]</span>)</p>

Show a scale bar.

## Parameters

**grfName :** ***string, default `WinName(0,1)`***  
The name of a window.

**anchor :** ***string, {"LB", "LT", "RB", or "RT"}***  
The position of the scale bar. If empty, delete the scale bar.

**size :** ***int***  
The font size (pt).

**fgRGBA :** ***wave***  
The foreground color.

**bgRGBA :** ***wave***  
The background color.

**prefix:** ***int {0 or !0}, default 1***  
Set !0 to use a prefix such as k and m.
