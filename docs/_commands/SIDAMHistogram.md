---
title: "SIDAMHistogram"
---
<p class="function_definition">SIDAMHistogram(<span class="function_variables">w, [startz, endz, deltaz, bins, cumulative, normalize, cmplxmode]</span>)</p>

Generate a histogram of the input wave.
When the input wave is 3D, the histogram is generated layer by layer.

## Parameters

**w :** ***wave***  
The input wave, 2D or 3D.

**startz :** ***variable, default `WaveMin(w)`***  
The start value of a histogram.

**endz :** ***variable, default `WaveMax(w)`***  
The end value of a histogram.

**deltaz :** ***variable***  
The width of a bin. Unless given, `endz` is used.

**bins :** ***int, default 64***  
The number of bins.

**cumulative :** ***int {0 or !0}, default 0***  
Set !0 for a cumulative histogram.

**normalize :** ***int {0 or !0}, default 1***  
Set !0 to normalize a histogram.

**cmplxmode :** ***int {0 -- 3}, default 0***  
Select a mode for a complex input wave.
* 0: Amplitude
* 1: Real
* 2: Imaginary
* 3: Phase.

## Returns
***wave***  
Histogram wave.
