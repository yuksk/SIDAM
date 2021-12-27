#pragma TextEncoding="UTF-8"
#pragma rtGlobals=3

#include "SIDAM_Utilities_Window"

#ifndef SIDAMshowProc
#pragma hide = 1
#endif


//@
//	Extension of `ImageNameToWaveRef()`
//
//	## Parameters
//	grfName : string
//		Name of a window.
//	imgName : string, default `StringFromList(0, ImageNameList(grfName, ";"))`
//		Name of an image. The default is the top image in the window.
//		If this is given, this function works as `ImageNameToWaveRef()`. 
//	displayed : int {0, !0}
//		Set !0 to return a 2D free wave of the displaye area, plane, and imCmplxMode.
//
//	## Returns
//	wave
//		A wave reference to an image in the window, or a free wave which is
//		a part of a wave shown in the window.
//@
Function/WAVE SIDAMImageNameToWaveRef(String grfName, [String imgName, int displayed])
	if (ParamIsDefault(imgName))
		imgName = StringFromList(0, ImageNameList(grfName, ";"))
	endif

	if (!strlen(imgName))
		return $""
	endif

	Wave/Z w = ImageNameToWaveRef(grfName, imgName)
	if (!WaveExists(w))
		return $""
	elseif (ParamIsDefault(displayed) || !displayed)
		return w
	endif

	int isCmplx = WaveType(w) & 0x01
	String infoStr = ImageInfo(grfName, imgName, 0)
	int plane = NumberByKey("plane", infoStr, "=")
	int mode = NumberByKey("imCmplxMode", infoStr, "=")

	if (isCmplx)
		switch (mode)
			case 0:	//	magnitude
				MatrixOP/FREE tw = mag(w[][][plane])
				break
			case 1:	//	real
				MatrixOP/FREE tw = real(w[][][plane])
				break
			case 2:	//	imaginary
				MatrixOP/FREE tw = imag(w[][][plane])
				break
			case 3:	//	phase
				MatrixOP/FREE tw = phase(w[][][plane])
				break
		endswitch
	else
		MatrixOP/FREE tw = w[][][plane]
	endif
	Redimension/N=(DimSize(w,0),DimSize(w,1)) tw	//	always treat as a 2D wave
	CopyScales w tw

	GetAxis/W=$grfName/Q $StringByKey("XAXIS", infoStr)
	Variable xmin = V_min, xmax = V_max
	GetAxis/W=$grfName/Q $StringByKey("YAXIS", infoStr)
	Variable ymin = V_min, ymax = V_max
	Duplicate/R=(xmin,xmax)(ymin,ymax)/FREE tw tw2

	return tw2
end

//******************************************************************************
//	Get the range of displayed axes by giving an image or a trace
//******************************************************************************
Structure SIDAMAxisRange
	double	xmin
	double	xmax
	double	ymin
	double	ymax
	uint32	pmin
	uint32	pmax
	uint32	qmin
	uint32	qmax
	String	xaxis
	String	yaxis
EndStructure

Function SIDAMGetAxis(String grfName, String tName, STRUCT SIDAMAxisRange &s)
	String info = ImageInfo(grfName, tName, 0)
	Variable isImg = strlen(info)
	if (isImg)
		Wave w = ImageNameToWaveRef(grfName, tName)
	else
		info = TraceInfo(grfName, tName, 0)
		Wave w = TraceNameToWaveRef(grfName, tName)
	endif

	s.xaxis = StringByKey("XAXIS", info)
	s.yaxis = StringByKey("YAXIS", info)
	GetAxis/W=$grfName/Q $s.xaxis ;	s.xmin = V_min ;	s.xmax = V_max
	GetAxis/W=$grfName/Q $s.yaxis ;	s.ymin = V_min ;	s.ymax = V_max

	s.pmin = isImg ? round((s.xmin-DimOffset(w,0))/DimDelta(w,0)) : round((s.xmin-leftx(w))/deltax(w))
	s.pmax = isImg ? round((s.xmax-DimOffset(w,0))/DimDelta(w,0)) : round((s.xmax-leftx(w))/deltax(w))
	s.qmin = isImg ? round((s.ymin-DimOffset(w,1))/DimDelta(w,1)) : NaN
	s.qmax = isImg ? round((s.ymax-DimOffset(w,1))/DimDelta(w,1)) : NaN
End


//@
//	Copy the window to the clipboard with transparent background.
//
//	If an image is included in the window, copy as PNG
//	Otherwise copy as SVG.
//
//	## Parameters
//	grfName : string, default `WinName(0,1)`
//		The name of window
//	size : variable
//		The size of copied image
//@
Function SIDAMExportGraphicsTransparent([String grfName, Variable size])
	grfName = SelectString(ParamIsDefault(grfName),grfName,WinName(0,1))
	if (!SIDAMWindowExists(grfName))
		return 0
	endif

	//	Get the background colors
	STRUCT RGBColor wbRGB
	GetWindow $grfName, wbRGB
	wbRGB.red = V_Red ;	wbRGB.green = V_Green ;	wbRGB.blue = V_Blue
	STRUCT RGBColor gbRGB
	GetWindow $grfName, gbRGB
	gbRGB.red = V_Red ;	gbRGB.green = V_Green ;	gbRGB.blue = V_Blue

	//	Make the background white to export it as transparent
	int isBoth = !CmpStr(LowerStr(SIDAM_WINDOW_EXPORT_TRANSPARENT), "both")
	int isGraph = !CmpStr(LowerStr(SIDAM_WINDOW_EXPORT_TRANSPARENT), "graph")
	int isWindow = !CmpStr(LowerStr(SIDAM_WINDOW_EXPORT_TRANSPARENT), "window")
	if (isBoth || isWindow)
		ModifyGraph/W=$grfName wbRGB=(65535,65535,65535)
	endif
	if (isBoth || isGraph)
		ModifyGraph/W=$grfName gbRGB=(65535,65535,65535)
	endif

	//	Copy the window to the clipboard
	if (strlen(ImageNameList(grfName, ";")))
		if (SIDAM_WINDOW_EXPORT_RESOLUTION > 8)	//	Other DPI
			if (ParamIsDefault(size))
				SavePICT/E=-5/TRAN=1/RES=(SIDAM_WINDOW_EXPORT_RESOLUTION)/WIN=$grfName as "Clipboard"
			else
				SavePICT/E=-5/TRAN=1/RES=(SIDAM_WINDOW_EXPORT_RESOLUTION)/W=(0,0,size,size)/WIN=$grfName as "Clipboard"
			endif
		else
			if (ParamIsDefault(size))
				SavePICT/E=-5/TRAN=1/B=(SIDAM_WINDOW_EXPORT_RESOLUTION)/WIN=$grfName as "Clipboard"
			else
				SavePICT/E=-5/TRAN=1/B=(SIDAM_WINDOW_EXPORT_RESOLUTION)/W=(0,0,size,size)/WIN=$grfName as "Clipboard"
			endif
		endif
	else
		SavePICT/E=-9/WIN=$grfName as "Clipboard"
	endif

	//	Revert the background colors
	ModifyGraph/W=$grfName wbRGB=(wbRGB.red, wbRGB.green, wbRGB.blue)
	ModifyGraph/W=$grfName gbRGB=(gbRGB.red, gbRGB.green, gbRGB.blue)
End


//@
//	Get the index of a 3D wave shown in a window.
//
//	## Parameters
//	grfName : string
//		The name of window
//	w : wave, default wave of the top image
//		The 3D wave to get the index.
//
//	## Returns
//	variable
//		The index of displayed layer. If no 3D wave is shown,
//		nan is returned.
//@
Function SIDAMGetLayerIndex(String grfName, [Wave/Z w])
	if (ParamIsDefault(w))
		Wave/Z w =  SIDAMImageNameToWaveRef(grfName)
	endif
	if (!WaveExists(w) || WaveDims(w) != 3)
		return NaN
	endif
	
	return NumberByKey("plane", ImageInfo(grfName, NameOfWave(w), 0), "=")
End

//@
//	Set the index of a 3D wave shown in a window.
//
//	## Parameters
//	grfName : string
//		The name of window
//	index : int
//		The index of layer
//	w : wave, default wave of the top image
//		The 3D wave to set the index.
//
//	## Returns
//	variable
//		* 0: The index is correctly set.
//		* 1: No 3D wave is shown.
//@
Function SIDAMSetLayerIndex(String grfName, int index, [Wave/Z w])
	if (ParamIsDefault(w))
		Wave/Z w =  SIDAMImageNameToWaveRef(grfName)
	endif
	if (!WaveExists(w) || WaveDims(w) != 3)
		return 1
	endif
	
	ModifyImage/W=$grfName $NameOfWave(w) plane=limit(round(index), 0, DimSize(w,2)-1)
	// Do not insert DoUpdate/W=$grfName here.
	// If inserted, when this function is called from a hook function, the
	// modification event of a hook function, which are expected to be called
	// by a change made by the above ModifyImage, is not called. This problem
	// occurs in Igor 8.
	return 0
End
