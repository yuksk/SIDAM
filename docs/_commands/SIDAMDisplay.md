---
title: "SIDAMDisplay"
---
<p class="function_definition">SIDAMDisplay(<span class="function_variables">w, [traces, history]</span>)</p>

Show a trace of 1D wave, an image of 2D wave, and a layer of 3D wave.

## Parameters

**w :** ***wave***  
A numeric wave, or a refrence wave containing references to numeric waves.

**traces :** ***int {0, 1, or 2}, default 0***  
* 0: Normal
* 1: Show a 2D waves as traces.
1st dimension is `x`, and the number of traces is `DimSize(w,1)`.
* 2: Append a 2D wave (2,n) as a trace to a graph.
The dimension labels (`%x` and `%y`, or `%p` and `%q`) must
be appropriately given. Then this works as
`AppendToGraph w[%y][] vs w[%x][]`, or
`AppendToGraph w[%q][] vs w[%p][]`.

**history :** ***int {0 or !0}, default 0***  
Set !0 to print this command in the history.

## Returns
***str***  
The name of window.
