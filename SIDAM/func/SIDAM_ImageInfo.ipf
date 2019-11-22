#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3

#ifndef SIDAMshowProc
#pragma hide = 1
#endif

#include <WMImageInfo>

//  Extension of WMImageInfo

//******************************************************************************
///Extension of WM_ColorTableForImage
///	@param grfName	Name of a window.
///	@param imgName	Name of an image.
///	@return	Name of a color table or absolute path to a color table wave
///				Empty When the image is not found
//******************************************************************************
Function/S SIDAM_ColorTableForImage(String grfName, String imgName)	//	tested
	String str = WM_ColorTableForImage(grfName,imgName)
	if (GetRTError(1) || !strlen(str))
		return ""
	elseif (WhichListItem(str,CTabList()) >= 0)	//	color table
		return str
	else
		return GetWavesDataFolder($str,2)
	endif
End

//******************************************************************************
///Extension of WM_GetColorTableMinMax
///	@param grfName		Name of a window.
///	@param imgName		Name of an image.
///	@param[out] zmin		minimum value of ctab
///	@param[out] zmax		maximum value of ctab
///	@param allowNaN	0:	zmin and zmax are always numeric as WM_GetColorTableMinMax
///						!0:	zmin and zmax are NaN if they are auto
///							The default value is 0
///	@return	0 for normal exit, 1 for any error
//******************************************************************************
Function SIDAM_GetColorTableMinMax(String grfName, String imgName,
	Variable &zmin, Variable &zmax, [int allowNaN])	//	tested
	
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

//******************************************************************************
///Returns if a logarithmically-spaced color is set.
///	(log version of WM_ColorTableReversed)
///	@param grfName	Name of a window.
///	@param imgName	Name of an image.
///	@return	0: a linearly-spaced color
///				1: a logarithmically-spaced color
///				-1: any error
//******************************************************************************
Function SIDAM_ColorTableLog(String grfName, String imgName)	//	tested
	String info = ImageInfo(grfName, imgName, 0)
	if (GetRTError(1))
		return -1
	endif
	return str2num(TrimString(WMGetRECREATIONInfoByKey("log",info)))
End

//******************************************************************************
///	Returns mode of minRGB/maxRGB
///	@param grfName	Name of a window.
///	@param imgName	Name of an image.
///	@param key		"minRGB" or "maxRGB"
///	@return	0: use first/last color
///				1: (r,g,b)
///				2: transparent
///				-1: any error
//******************************************************************************
Function SIDAM_ImageColorRGBMode(String grfName, String imgName, String key) //	tested
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

//******************************************************************************
///	Returns values of minRGB/maxRGB
///	@param grfName	Name of a window.
///	@param imgName	Name of an image.
///	@param key		"minRGB" or "maxRGB"
///	@param[out] s	rgb color
///	@return	0: no error
///				!0: any error
//******************************************************************************
Function SIDAM_ImageColorRGBValues(String grfName, String imgName, String key,
	STRUCT RGBColor &s) //	tested

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