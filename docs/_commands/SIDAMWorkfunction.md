---
title: "SIDAMWorkfunction"
---
<p class="function_definition">SIDAMWorkfunction(<span class="function_variables">w, [startp, endp, offset, basename]</span>)</p>

Calculate the work function.

## Parameters

**w :** ***wave***  
The input wave, 1D or 3D.

**startp :** ***int, default 0***  
Range of fitting, start index.

**endp :** ***int, default `numpnts(w)-1` for 1D, `DimSize(w,2)-1` for 3D***  
Range of fitting, end index.

**offset :** ***variable***  
The offset of current. By default, this is a fitting parameter.

**basename :** ***string***  
The basename of output waves. This is used when the input wave is 3D.
If this is specified, output waves are saved in the data folder
where the input wave is.

## Returns
***wave***  
For 1D input wave, a numeric wave is returned.
For 3D input wave, a wave reference wave is returned.
In both cases, the result can be referred as follows.
* work function : `wave[%workfunction]`
* current amplitude : `wave[%amplitude]`
* current offset : `wave[%offset]`
* chi-squared : `wave[%chisq]`
