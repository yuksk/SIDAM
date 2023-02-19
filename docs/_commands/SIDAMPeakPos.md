---
title: "SIDAMPeakPos"
---
<p class="function_definition">SIDAMPeakPos(<span class="function_variables">w, fitfn</span>)</p>

Find a peak position by fitting.

## Parameters

**w :** ***wave***  
The input wave. The whole wave is fit.

**fitfn :** ***int {0 or 1}***  
The fitting function.
* 0: asymmetric gauss2D
* 1: asymmetric lorentz2D

## Returns
***wave***  
A 1D numeric wave is saved in the datafolder where the input wave is, and
the wave reference to the saved wave is returned.
The values of fitting results are given as follows.
- offset : `wave[%offset]`
- amplitude : `wave[%amplitude]`
- peak position : `wave[%xcenter]`, `wave[%ycenter]`
- peak width : `wave[%xwidthpos]`, `wave[%xwidthneg]`, `wave[%ywidthpos]`, `wave[%ywidthneg]`
- peak angle : `wave[%angle]`
