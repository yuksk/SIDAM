---
title: "SIDAMFFT"
---
<p class="function_definition">SIDAMFFT(<span class="function_variables">w, [win, out, subtract]</span>)</p>

Compute the discrite Fourier transform of the input wave.
When the input wave is 3D, the histogram is generated layer by layer.

## Parameters

**w :** ***wave***  
The input wave, 2D or 3D.

**win :** ***string, default "none"***  
An image window function.

**out :** ***int {1 -- 6}, default 3***  
The Output mode of FFT.
1. complex
2. real
3. magnitude
4. magnitude squared
5. phase
6. imaginary

**subtract :** ***int {0 or !0}, default 0***  
Set !0 to subtract the average before FFT. For a 3D wave,
the average of each layer is subtracted.

## Returns
***wave***  
Fourier-transformed wave.
