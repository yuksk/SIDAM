---
title: "SIDAMScaleToIndex"
---
<p class="function_definition">SIDAMScaleToIndex(<span class="function_variables">w, value, dim</span>)</p>

Extension of `ScaleToIndex()` that includes unevenly-spaced bias

## Parameters

**w :** ***wave***  
The input wave

**value :** ***int***  
A scaled coordinate value

**dim :** ***int {0 -- 3}***  
Specify the dimension.
* 0: Rows
* 1: Columns
* 2: Layers
* 3: Chunks

## Returns
***variable***  
The index value
