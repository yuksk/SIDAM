---
title: "SIDAMRange"
---
<p class="function_definition">SIDAMRange(<span class="function_variables">[grfName, imgList, zmin, zmax, zminmode, zmaxmode]</span>)</p>

Set a range of a color scale used for a image(s).

## Parameters

**grfName :** ***string, default `WinName(0,1,1)`***  
The name of window.

**imgList :** ***string, default `ImageNameList(grfName,";")`***  
The list of images.

**zminmode, zmaxmode :** ***int {0 -- 4}, default 1***  
How to set the minimum and maximum of z range.
* 0: auto. Use the minimum or the maximum of the current area and plane.
This is equivalent to `ModifyImage ctabAutoscale=3`.
* 1: fix. Use a fixed value. The value is given by `zmin` and `zmax`.
* 2: sigma. Use _n_&#963; below (`zminmode`) or above (`zmaxmode`) the average,
where &#963; is the standard deviation. The average and the standard deviation
are calculated for the current area and plane. _n_ is given by `zmin` and `zmax`.
* 3: cut. Use _n_% from the minimum (`zminmode`) or maximum (`zmaxmode`) of
the cumulative histogram which is calculated for the current area and plane.
_n_ is given by `zmin` and `zmax`.
* 4: logsigma. Similar to `sigma`, but use logarithmic values of an image to
calculate the average and the standard deviation. This option is useful when
values in an image span in a wide range over a few orders like an FFT image.

**zmin, zmax :** ***variable***  
The minimum and maximum value of the range.
The meaning of value depends on `zminmode` and `zmaxmode`.
