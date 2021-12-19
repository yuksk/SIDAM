---
title: "SIDAMLoadData"
---
<p class="function_definition">SIDAMLoadData(<span class="function_variables">pathStr, [noavg, history]</span>)</p>

Load data files.

## Parameters

**pathStr :** ***string***  
Path to a file or a directory. When a path to a directory is given,
files under the directory are loaded recursively.

**noavg :** ***int {0 or !0}, default 0***  
Set !0 to average the forward and backward sweep of spectroscopic
data. If the shift key is pressed when this function is called,
`noavg` is set to 1.

**history :** ***int {0 or !0}, default 0***  
Set !0 to print this command in the history.

## Returns
***wave***  
Loaded wave.
