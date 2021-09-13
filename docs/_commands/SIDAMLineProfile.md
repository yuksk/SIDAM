---
title: "SIDAMLineProfile"
---
<p class="function_definition">SIDAMLineProfile(<span class="function_variables">w, p1, q1, p2, q2, [width, output, basename]</span>)</p>

Get a line profile of a wave along a trajectory line.

## Parameters

**w :** ***wave***  
The input wave, 2D or 3D.

**p1, q1 :** ***variable***  
The position of the starting point (pixel).

**p2, q2 :** ***variable***  
The position of the ending point (pixel).

**width :** ***variable, default 0***  
The width (diameter) of the line profile in pixels.
This is the same as the width parameter of `ImageLineProfile`.

**output :** ***int, default 0***  
Specify waves saved in addition to the profile wave.
- bit 0: save waves of positions.
- bit 1: save wave of standard deviation when the width > 0.

**basename :** ***string, default ""***  
Name of the line profile wave and basename of additional waves
(when the output > 0). If this is specified, output waves are
save in the data folder where the input wave is.

## Returns
***wave***  
Line profile.
