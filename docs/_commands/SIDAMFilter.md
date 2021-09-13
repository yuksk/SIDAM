---
title: "SIDAMFilter"
---
<p class="function_definition">SIDAMFilter(<span class="function_variables">srcw, paramw, [invert, endeffect]</span>)</p>

Apply Fourier filter.

## Parameters

**srcw :** ***wave***  
The input wave, 2D or 3D.

**paramw :** ***wave***  
The filter parameters.

**invert :** ***int {0 or !0}, default 0***  
* 0 Pass the filter areas
* !0 Cut the filter areas

**endeffect :** ***int {1 -- 3}, default 1***  
How to handle the ends of the wave.
* 0: Bounce. Uses `w[i]` in place of the missing `w[-i]` and `w[n-i]` in place of the missing `w[n+i]`.
* 1: Wrap. Uses `w[n-i]` in place of the missing `w[-i]` and vice-versa.
* 2: Zero (default). Uses 0 for any missing value.
* 3: Repeat. Uses `w[0]` in place of the missing `w[-i]` and `w[n]` in place of the missing `w[n+i]`.

## Returns
***wave***  
Filtered wave.
