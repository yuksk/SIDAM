#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3

#ifndef SIDAMshowProc
#pragma hide = 1
#endif

#include <WMImageInfo>

//  Extension of WMImageInfo

//@
//	Extension of `WM_ColorTableForImage`.
//
//	## Parameters
//	grfName : string
//		The name of window.
//	imgName : string
//		The name of an image.
//
//	## Returns
//	string
//		Name of a color table or absolute path to a color table wave.
//		Empty When the image is not found.
//@
Function/S SIDAM_ColorTableForImage(String grfName, String imgName)
	String str = WM_ColorTableForImage(grfName,imgName)
	if (GetRTError(1) || !strlen(str))
		return ""
	elseif (WhichListItem(str,CTabList()) >= 0)	//	color table
		return str
	else
		return GetWavesDataFolder($str,2)
	endif
End

//@
//	Extension of `WM_GetColorTableMinMax`.
//
//	## Parameters
//	grfName : string
//		The name of window
//	imgName : string
//		The name of an image.
//	zmin, zmax : variable
//		The minimum and maximum values of ctab are returned.
//	allowNaN : int {0 or !0}, default 0
//		When `allowNaN` = 0, `zmin` and `zmax` are always numeric as
//		`WM_GetColorTableMinMax`. When !0, `zmin` and `zmax` are NaN if they
//		are auto.
//
//	## Returns
//	int
//		* 0: Normal exit
//		* 1: Any error
//@
Function SIDAM_GetColorTableMinMax(String grfName, String imgName,
	Variable &zmin, Variable &zmax, [int allowNaN])
	
	String ctabInfo = WM_ImageColorTabInfo(grfName,imgName)
	if (GetRTError(1) || !strlen(ctabInfo))
		return 1
	endif

	Variable flag = WM_GetColorTableMinMax(grfName,imgName,zmin,zmax)
	if (GetRTError(1) || !flag)
		return 1
	endif
	
	allowNaN = ParamIsDefault(allowNaN) ? 0 : allowNaN
	int isMinAuto = !CmpStr(StringFromList(0,ctabInfo,","),"*")
	int isMaxAuto = !CmpStr(StringFromList(1,ctabInfo,","),"*")
	
	if (isMinAuto && allowNaN)
		zmin = NaN
	endif

	if (isMaxAuto && allowNaN)
		zmax = NaN
	endif
	
	return 0
End

Override Function WM_GetColorTableMinMax(graphName, imageName, colorMin, colorMax)
	String graphName, imageName
	Variable &colorMin, &colorMax

	colorMin= NaN
	colorMax= NaN
	
	if( strlen(imageName) == 0 )
		imageName= StringFromList(0,ImageNameList(graphName,";"))
	endif
	Wave/Z image= ImageNameToWaveRef(graphName,imageName)
	String infoStr= ImageInfo(graphName, imageName, 0)
	Variable colorMode= NumberByKey("COLORMODE",infoStr)
	String ctabInfo= WM_ImageColorTabInfo(graphName, imageName)
	if(  ((colorMode == 1) || (colorMode == 6)) && (strlen(ctabInfo) >0) && (WaveExists(image) == 1) )
		String mnStr= StringFromList(0,ctabInfo,",")		// could be *
		String mxStr= StringFromList(1,ctabInfo,",")		// could be *
		colorMin= str2num(mnStr)					// NaN if mnStr is "*"
		colorMax= str2num(mxStr)					// NaN if mxStr is "*"
		if( (CmpStr(mnStr,"*") == 0) || (CmpStr(mxStr,"*") == 0) )
			Variable ctabAutoscale= str2num(WMGetRECREATIONInfoByKey("ctabAutoscale",infoStr)) 
			Variable onlyDisplayedXY= ctabAutoscale & 0x1
			Variable onlyDisplayedPlane= (ctabAutoscale & 0x2) && (DimSize(image,2) > 0)
			Variable displayedPlane= str2num(WMGetRECREATIONInfoByKey("plane",infoStr))
			Variable wType= WaveType(image)
			Variable isComplex=  wType & 0x01
			if( onlyDisplayedPlane )
				Duplicate/FREE/R=[][][displayedPlane] image, image3
				Wave image = image3
			endif
			if( onlyDisplayedXY )
				Variable xmin, xmax, ymin, ymax
				WM_ImageDisplayedAxisRanges(graphName, imageName, xmin, xmax, ymin, ymax)
				Duplicate/FREE/R=(xmin,xmax)(ymin,ymax) image, image4
				Wave image = image4
			endif
			if (isComplex)
				Variable cmplxMode= str2num(WMGetRECREATIONInfoByKey("imCmplxMode",infoStr))
				switch (cmplxMode)
					default:
					case 0:	//	magnitude
						MatrixOP/FREE image2= mag(image)
						break
					case 1:	//	real
						MatrixOP/FREE image2= real(image)
						break
					case 2:	//	imaginary
						MatrixOP/FREE image2= imag(image)
						break
					case 3:	//	phase
						MatrixOP/FREE image2= phase(image)
						break
				endswitch
				CopyScales/P image, image2 // 7.03: MatrixOp doesn't copy the scaling from the source wave.
				WAVE image= image2
			endif
			if( CmpStr(mnStr,"*") == 0 )
				colorMin= WaveMin(image)
			endif
			if( CmpStr(mxStr,"*") == 0 )
				colorMax= WaveMax(image)
			endif
		endif
	endif
	return numtype(colorMin) == 0 && numtype(colorMax) == 0
End


//@
//	Returns if a logarithmically-spaced color is set.
//	(log version of `WM_ColorTableReversed`)
//
//	## Parameters
//	grfName : string
//		The name of window
//	imgName : string
//		The name of an image.
//
//	## Returns
//	int
//		* 0: a linearly-spaced color.
//		* 1: a logarithmically-spaced color.
//		* -1: any error.
//@
Function SIDAM_ColorTableLog(String grfName, String imgName)
	String info = ImageInfo(grfName, imgName, 0)
	if (GetRTError(1))
		return -1
	endif
	return str2num(TrimString(WMGetRECREATIONInfoByKey("log",info)))
End


//@
//	Returns mode of minRGB/maxRGB.
//
//	## Parameters
//	grfName : string
//		The name of window
//	imgName : string
//		The name of an image.
//	key : string
//		"minRGB" or "maxRGB"
//
//	## Returns
//	int
//		* 0: use first/last color
//		* 1: (r,g,b)
//		* 2: transparent
//		* -1: any error
//@
Function SIDAM_ImageColorRGBMode(String grfName, String imgName, String key)
	String info = ImageInfo(grfName, imgName, 0)
	if (GetRTError(1))
		return -1
	endif
	
	if (CmpStr(key,"minRGB") && CmpStr(key,"maxRGB"))
		return -1
	endif
	
	String str = WMGetRECREATIONInfoByKey(key,info)
	if (!CmpStr(str,"0"))	//	use first/last color
		return 0
	elseif (GrepString(str,"\([0-9]+,[0-9]+,[0-9]+\)"))	//	(r,g,b)
		return 1
	elseif (!CmpStr(LowerStr(str),"nan"))	//	transparent
		return 2
	else
		return -1
	endif
End


//@
//	Returns values of minRGB/maxRGB.
//
//	## Parameters
//	grfName : string
//		The name of window
//	imgName : string
//		The name of an image.
//	key : string
//		"minRGB" or "maxRGB"
//	s : STRUCT RGBColor
//		rgb color is returned.
//
//	## Returns
//	int
//		* 0: No error
//		* !0: Any error
//@
Function SIDAM_ImageColorRGBValues(String grfName, String imgName, String key,
	STRUCT RGBColor &s)

	String info = ImageInfo(grfName, imgName, 0)
	if (GetRTError(1))
		return 1
	elseif (!strlen(info))
		return 2
	endif
	
	String str = WMGetRECREATIONInfoByKey(key,info)
	if (!GrepString(str,"\([0-9]+,[0-9]+,[0-9]+\)"))
		return 3
	endif
	
	str = str[1,strlen(str)-2]
	s.red = str2num(StringFromList(0,str,","))
	s.green = str2num(StringFromList(1,str,","))
	s.blue = str2num(StringFromList(2,str,","))

	return 0
End
