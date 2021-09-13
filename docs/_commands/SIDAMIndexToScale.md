---
title: "SIDAMIndexToScale"
---
<p class="function_definition">SIDAMIndexToScale(<span class="function_variables">w, index, dim</span>)</p>

Extension of `IndexToScale()` that includes unevenly-spaced bias

## Parameters

**w :** ***wave***  
The input wave

**index :** ***int***  
An index number

**dim :** ***int {0 -- 3}***  
Specify the dimension.
* 0: Rows
* 1: Columns
* 2: Layers
* 3: Chunks

## Returns
***variable***  
The scaled coordinate value
