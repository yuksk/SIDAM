#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3

#include <DimensionLabelUtilities>

#include "SIDAM_Utilities_Image"

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
	CopyWaveToDimLabels({"p","q","x","y"}, rtnw, 0)
	return rtnw
End

//******************************************************************************
//	Return a wave of the area enclosed by the marquee
//******************************************************************************
Function/WAVE SIDAMGetMarqueeAreaWave(Wave/Z w, String grfName)
	if (!WaveExists(w))
		return $""
	endif

	Wave/Z mw = SIDAMGetMarquee()
	if (!WaveExists(mw))
		return $""
	endif

	if (WaveDims(w)==3)
		//	Use the displayed layer for a 3D wave
		Duplicate/RMD=[mw[%p][0],mw[%p][1]][mw[%q][0],mw[%q][1]][SIDAMGetLayerIndex(grfName)]/FREE w, rtnw
		Redimension/N=(-1,-1) rtnw
	else
		Duplicate/RMD=[mw[%p][0],mw[%p][1]][mw[%q][0],mw[%q][1]]/FREE w, rtnw
	endif
	return rtnw
End
