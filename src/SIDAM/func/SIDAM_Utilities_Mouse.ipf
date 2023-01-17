#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3

#include "SIDAM_Utilities_Image"

#ifndef SIDAMshowProc
#pragma hide = 1
#endif

Structure SIDAMMousePos
	String	xaxis
	String	yaxis
	float	x
	float	y
	Variable/C	z
	float	p
	float	q
	Wave	w
EndStructure

//******************************************************************************
//	Get wave reference, wave value, etc. at the position of the mouse cursor
//******************************************************************************
Function SIDAMGetMousePos(
	STRUCT SIDAMMousePos &s,
	String grfName,
	STRUCT Point &ps,		//	e.g., WMWinHookStruct.mouseLoc
	[
		int grid
	])

	grid = ParamIsDefault(grid) ? 1 : grid
	s.xaxis = ""	; s.yaxis = ""
	s.x = NaN ;	s.y = NaN ;	s.z = NaN
	s.p = NaN ;	s.q = NaN ;
	Wave/Z s.w = $""

	getWaveAndValues(s,grfName,ps)
	if (!WaveExists(s.w))	//	the mouse cursor is not on any image
		return 1
	elseif (WaveExists(ImageNameToWaveRef(grfName,PossiblyQuoteName(NameOfWave(s.w)))))
		//	The following is for when s.w is a 2D/3D wave and is displayed as an image,
		//	but even when s.w is 2D/3D, it can be displayed as a trace.
		//	The above if state is to exclude the latter situation.
		//	(WaveDims(s.w) > 1 fails.)
		Variable ox = DimOffset(s.w,0), oy = DimOffset(s.w,1)
		Variable dx = DimDelta(s.w,0), dy = DimDelta(s.w,1)
		Variable tx = limit(s.x, min(ox,ox+dx*(DimSize(s.w,0)-1)), max(ox,ox+dx*(DimSize(s.w,0)-1)))
		Variable ty = limit(s.y, min(oy,oy+dy*(DimSize(s.w,1)-1)), max(oy,oy+dy*(DimSize(s.w,1)-1)))
		Variable tp = (tx-ox)/dx, tq = (ty-oy)/dy
		s.p = grid ? round(tp) : tp
		s.q = grid ? round(tq) : tq
		s.x = grid ? (ox + dx * s.p) : tx
		s.y = grid ? (oy + dy * s.q) : ty
		//	the present layer, 0 for 2D images
		int layer = NumberByKey("plane", ImageInfo(grfName, NameOfWave(s.w), 0), "=")
		s.z = s.w(tx)(ty)[limit(layer,0,DimSize(s.w,2)-1)]
	endif
	return 0
End

Static Function getWaveAndValues(STRUCT SIDAMMousePos &ms, String grfName, STRUCT Point &ps)
	STRUCT SIDAMAxisRange as
	String listStr, itemName
	Variable mousex, mousey
	Variable axis_x_max, axis_x_min, axis_y_max, axis_y_min
	Variable wave_x_max, wave_x_min, wave_y_max, wave_y_min
	Variable ox, dx, oy, dy
	Variable isInRange	//	isInRange has to be variable (not int)
	int swap = strsearch(WinRecreation(grfName,1), "swapXY", 4) != -1
	int i, isImg, nx, ny

	//	Traces are handled only when there is no image.
	listStr = ImageNameList(grfName,";")
	if (!strlen(listStr))
		listStr = TraceNameList(grfName, ";", 1)
	endif

	//	search from the top item
	for (i = ItemsInList(listStr)-1; i >= 0; i--)
		itemName = StringFromList(i,listStr)

		SIDAMGetAxis(grfName,itemName,as)

		//	When the axis is reversed, as.xmin > as.xmax and as.ymin > as.ymax
		axis_x_min = min(as.x.min.value, as.x.max.value)
		axis_x_max = max(as.x.min.value, as.x.max.value)
		axis_y_min = min(as.y.min.value, as.y.max.value)
		axis_y_max = max(as.y.min.value, as.y.max.value)

		mousex = AxisValFromPixel(grfName, as.xaxis, (swap ? ps.v : ps.h))
		mousey = AxisValFromPixel(grfName, as.yaxis, (swap ? ps.h : ps.v))

		Wave/Z w = ImageNameToWaveRef(grfName,itemName)
		isImg = WaveExists(w)

		//	When dx (dy) is negative, min and max are reversed
		if (isImg)
			ox = DimOffset(w,0)
			oy = DimOffset(w,1)
			dx = DimDelta(w,0)
			dy = DimDelta(w,1)
			nx = DimSize(w,0)
			ny = DimSize(w,1)
			wave_x_min = dx>0 ? ox-0.5*dx : ox+dx*(nx-0.5)
			wave_x_max = dx>0 ? ox+dx*(nx-0.5) : ox-0.5*dx
			wave_y_min = dy>0 ? oy-0.5*dy : oy+dy*(ny-0.5)
			wave_y_max = dy>0 ? oy+dy*(ny-0.5) : oy-0.5*dy
		endif

		isInRange = !isImg ? 1 : \
			(mousex >= max(axis_x_min, wave_x_min)) \
			& (mousex <= min(axis_x_max, wave_x_max)) \
			& (mousey >= max(axis_y_min, wave_y_min)) \
			& (mousey <= min(axis_y_max, wave_y_max))
		if (isInRange)
			ms.xaxis = as.xaxis
			ms.yaxis = as.yaxis
			ms.x = mousex
			ms.y = mousey
			if (isImg)
				Wave ms.w = w
			else
				Wave ms.w = TraceNameToWaveRef(grfName,itemName)
			endif
			return 1
		endif
	endfor
	return 0
End