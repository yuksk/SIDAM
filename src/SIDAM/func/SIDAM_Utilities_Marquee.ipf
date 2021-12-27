#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3

#ifndef SIDAMshowProc
#pragma hide = 1
#endif

//******************************************************************************
//	Return the marquee position as a wave
//******************************************************************************
Function/WAVE SIDAMGetMarquee()
	String grfName = WinName(0,1)
	String imgName = StringFromList(0,ImageNameList(grfName,";"))
	Wave/Z w = ImageNameToWaveRef(grfName, imgName)
	if (!strlen(grfName) || !strlen(imgName) || !WaveExists(w))
		return $""
	endif

	String info = ImageInfo(grfName, imgName, 0)
	GetMarquee/W=$grfName $StringByKey("YAXIS", info), $StringByKey("XAXIS", info)
	if (!V_flag)
		return $""
	endif

	Variable ox = DimOffset(w,0), oy = DimOffset(w,1)
	Variable dx = DimDelta(w,0), dy = DimDelta(w,1)
	Make/D/N=(4,2)/FREE rtnw 
	rtnw[][0] = {round((V_left-ox)/dx), round((V_bottom-oy)/dy), V_left,V_bottom}
	rtnw[][1] = {round((V_right-ox)/dx), round((V_top-oy)/dy), V_right,V_top}
	SetDimLabel 0, 0, p, rtnw
	SetDimLabel 0, 1, q, rtnw
	SetDimLabel 0, 2, x, rtnw
	SetDimLabel 0, 3, y, rtnw
	return rtnw
End