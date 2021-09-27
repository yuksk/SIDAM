---
title: "SIDAMSubtraction"
---
<p class="function_definition">SIDAMSubtraction(<span class="function_variables">w, [roi, mode, degree, direction, method, index]</span>)</p>

Subtract background.

## Parameters

**w :** ***wave***  
The input wave, 2D or 3D.

**roi :** ***wave***  
The roi (region of interest) wave. This has the same number of
rows and columns as the input wave and specifies a region of
interst. Set the pixels to be included in the calculation to 1.
Alternatively, a 2&#215;2 wave specifying the corners of a rectanglar
roi can be also used.

**mode :** ***int {0 -- 3}, default 0***  
The subtract mode.
* 0: plane, subtract a polynomial plane/curve from a wave.
* 1: line, subtract a value / a line from each row or column.
* 2: layer, subtract a layer from a 3D wave.
* 3: phase, subtract phase of a layer from a 3D complex wave.

**degree :** ***int, default = 1 for `mode` = 0, 0 for `mode` = 1***  
The degree of a subtracted plane/lines.

**direction :** ***int {0 or 1}, default 0***  
The direction of subtraction for `mode` = 1. 0 for x and 1 for y.

**method :** ***int {0 or 1}, default 0***  
Specify what to be subtracted from each line for `mode` = 1.
0 for average and 1 for median.

**index :** ***int, default 0***  
The layer index for `mode` = 2 and 3

## Returns
***wave***  
A subtracted wave.
