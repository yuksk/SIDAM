---
title: "SIDAMFourierSym"
---
<p class="function_definition">SIDAMFourierSym(<span class="function_variables">w, q1w, q2w, sym, [shear, endeffect]</span>)</p>

Symmetrize Fourier transform based on symmetry.

## Parameters

**w :** ***wave***  
The input wave, 2D or 3D.

**q1w :** ***wave***  
The first peak, {qx, qy, a}.
The (qx, qy) is the peak position in pixel.
The a is the "ideal" real-space length corresponding to the peak.

**q2w :** ***wave***  
The second peak, specified in the same manner as the `q1w`.

**sym :** ***int {1 -- 5}***  
The symmetry.
1. 2mm
2. 3
3. 3m
4. 4
5. 4mm

**shear :** ***int {0 or 1}, default 0***  
The shear direction.
* 0: x
* 1: y

**endeffect :** ***int {0 -- 3}, default 2***  
How to handle the ends of the wave.
* 0: Bounce. Uses `w[i]` in place of the missing `w[-i]` and `w[n-i]` in place of the missing `w[n+i]`.
* 1: Wrap. Uses `w[n-i]` in place of the missing `w[-i]` and vice-versa.
* 2: Zero (default). Uses 0 for any missing value.
* 3: Repeat. Uses `w[0]` in place of the missing `w[-i]` and `w[n]` in place of the missing `w[n+i]`.

## Returns
***wave***  
Symmetrized wave.
