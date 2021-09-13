---
title: "SIDAMCorrelation"
---
<p class="function_definition">SIDAMCorrelation(<span class="function_variables">src, [dest, subtract, normalize]</span>)</p>

Calculate correlation function.

## Parameters

**src :** ***wave***  
The source wave, 2D or 3D.

**dest :** ***wave, default `src`***  
The destination wave that has the same dimension as the source wave.
When the source wave is 3D, a 2D wave that has the same dimension in
the x and y directions is also allowed.

**subtract :** ***int {0 or !0}, default 1***  
Set !0 to subtract the average before the calculation. For a 3D wave,
the average of each layer is subtracted.

**normalize :** ***int {0 or !0}, default 1***  
Set !0 to normalize the result. For a 3D wave, the result is normalized
layer-by-layer.

## Returns
***wave***  
Correlation wave. When the destination wave is the same as the source
wave, this is the auto correlation of the source wave.
