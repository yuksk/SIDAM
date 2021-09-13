---
title: "SIDAMPhaseAdjust"
---
<p class="function_definition">SIDAMPhaseAdjust(<span class="function_variables">xw, yw, [suffix, order]</span>)</p>

Numerically adjust the phase of lock-in x and y signals.

## Parameters

**xw :** ***wave***  
The input wave of x channel, 1D or 3D.

**yw :** ***wave***  
The input wave of y channel, 1D or 3D. The phase is rotated
so that this channel becomes featureless.

**suffix :** ***string***  
The suffix of output waves. If this is given, phase-adjusted
waves are saved in the datafolders where each of x and y wave
is. The suffix is used for the name of saved waves.

**order :** ***int {0 or 1}, default 1***  
When this is 0, the variance of yw is minimized.
When this is 1, the variance of yw-(a*v+b) is minimized.
(v is the bias voltage.)

## Returns
***wave***  
A wave reference wave containing phase-adjusted waves.
* x channel : `returnwave[%x]`
* y channel : `returnwave[%y]`
* angle : `returnwave[%angle]`
