#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3
#pragma ModuleName= SIDAMKeyBoardShortcuts

#include "SIDAM_Utilities_Image"

#ifndef SIDAMshowProc
#pragma hide = 1
#endif

//	keyboard shortcuts commonly used in Infobar and SpectrumViewer
Function SIDAMKeyboardShortcuts(STRUCT WMWinHookStruct &s)

	switch (s.keycode)
		case 88: 		//	X (shift + x)
			return changeCmplxMode(s)
		case 97:		//	a
			DoIgorMenu "Graph", "Modify Axis"
			return 1
		case 99:		//	c
			SIDAMExportGraphicsTransparent()
			return 1
		case 103:		//	g
			DoIgorMenu "Graph", "Modify Graph"
			return 1
		case 104:		//	h
			return hideAllTraces(s)
		case 105:		//	i
			DoIgorMenu "Image", "Modify Image Appearance"
			return 1
		case 115:		//	s
			DoIgorMenu "File", "Save Graphics"
			return 1
		case 116:		//	t
			DoIgorMenu "Graph", "Modify Trace Appearance"
			return 1
	endswitch
	return 0
End

Static Function changeCmplxMode(STRUCT WMWinHookStruct &s)
	Wave/Z w = SIDAMImageNameToWaveRef(s.winName)
	int is2D = WaveExists(w) && WaveDims(w)==2
	int is3D = WaveExists(w) && WaveDims(w)==3
	int mode
	if ((is2D || is3D) && SIDAMcontainsComplexWave(s.winName,2))
		mode = NumberByKey("imCmplxMode",ImageInfo(s.winName, "", 0),"=")
	elseif (!is2D && !is3D && SIDAMcontainsComplexWave(s.winName,1))
		mode = NumberByKey("cmplxMode(x)",TraceInfo(s.winName, "", 0),"=")
	else
		return 0
	endif
	SIDAMChangeComplexMode(++mode,!is2D && !is3D)
	return 1
End

Static Function hideAllTraces(STRUCT WMWinHookStruct &s)
	String allTraces = TraceNameList(s.winName, ";", 3)
	int numOfAllTraces = ItemsInList(allTraces)
	if (!numOfAllTraces)
		return 0
	endif
	
	int numOfShownTraces = ItemsInList(TraceNameList(s.winName, ";", 7))
	if (numOfShownTraces)
		ModifyGraph/W=$s.winName hideTrace=2
	else
		ModifyGraph/W=$s.winName hideTrace=0
	endif
	return 1
End