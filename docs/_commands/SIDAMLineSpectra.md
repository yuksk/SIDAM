---
title: "SIDAMLineSpectra"
---
<p class="function_definition">SIDAMLineSpectra(<span class="function_variables">w, p1, q1, p2, q2, [mode, output, basename]</span>)</p>

Get spectra along a trajectory line.

## Parameters

**w :** ***wave***  
The 3D input wave.

**p1, q1 :** ***variable***  
The position of the starting point (pixel).

**p2, q2 :** ***variable***  
The position of the ending point (pixel).

**mode :** ***int {0 -- 2}, default 0***  
How to get spectra.
* 0: Take spectra from all the pixels on the trajectory line
* 1: Take a value at a pixel in either x or y direction
(depending on the angle of the trajectory line) and
interpolate in the other direction.
* 2: Use ``ImageLineProfile`` of Igor Pro.

**output :** ***int {0 or !0}, default 0***  
Set !0 to save waves of positions.

**basename :** ***string, default ""***  
Name of the line profile wave and basename of additional waves
(when the output != 0). If this is specified, output waves are
save in the data folder where the input wave is.

## Returns
***wave***  
Spectra along the trajectory line.
