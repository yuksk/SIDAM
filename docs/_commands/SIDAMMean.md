---
title: "SIDAMMean"
---
<p class="function_definition">SIDAMMean(<span class="function_variables">w, dim</span>)</p>

Compute the arithmetic mean along the specified dimension.
The wave scaling and the dimension label in the other dimensions are
inherited in the return wave.

## Parameters

**w :** ***wave***  
The input wave.

**dim :** ***int {0 -- 3}***  
The dimension along which the mean is computed.

## Returns
***wave***  
A free wave containing the mean values.
A null wave is returned when dim >= WaveDims(w)
