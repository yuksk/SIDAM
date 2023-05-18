---
title: "SIDAMSum"
---
<p class="function_definition">SIDAMSum(<span class="function_variables">w, dim</span>)</p>

Sum of wave elements over a given dimension.
The wave scaling and the dimension label in the other dimensions are
inherited in the return wave.

## Parameters

**w :** ***wave***  
The input wave.

**dim :** ***int {0 -- 3}***  
The dimension along which a sum is performed.

## Returns
***wave***  
A free wave containing the sum values.
A null wave is returned when dim >= WaveDims(w)
