---
title: "SIDAMGetBias"
---
<p class="function_definition">SIDAMGetBias(<span class="function_variables">w, dim</span>)</p>

Return a wave of unevenly-spaced bias values

## Parameters

**w :** ***wave***  
A 3D wave having unevenly-spaced bias info

**dim :** ***int, {1 or 2}***  
1. The returned wave contains unevely spaced biases as they are.
This is used as an x wave to display a trace.
2. The returned wave contains average two neighboring layers.
This is used as an x wave or a y wave to display an image.

## Returns
***wave***  
a 1D wave, or a null wave for any error
