#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3

#include "SIDAM_InfoBar"
#include "SIDAM_Range"
#include "SIDAM_ScaleBar"
#include "SIDAM_Trace"

#ifndef SIDAMshowProc
#pragma hide = 1
#endif

//******************************************************************************
//	deprecated functions, to be removed in future
//******************************************************************************

//	print a list of deprecated functions in the history window
Function/S SIDAMDeprecatedFunctions()
	String fnName, fnList = FunctionList("*", ";", "KIND:2")
	String fileName, deprecatedList = ""
	int i, n

	for (i = 0, n = ItemsInList(fnList); i < n; i++)
		fnName = StringFromList(i,fnList)
		fileName = StringByKey("PROCWIN", FunctionInfo(fnName))
		if (CmpStr(filename, "SIDAM_Compatibility_Old_Functions.ipf"))
			continue
		endif
		deprecatedList += fnName+";"
	endfor
	return deprecatedList
End

//	print caution in the history window
Static Function deprecatedCaution(String newName)
	if (strlen(newName))
		printf "%s%s is deprecated. Use %s.\r", PRESTR_CAUTION, GetRTStackInfo(2), newName
	else
		printf "%s%s is deprecated and will be removed in future.\r", PRESTR_CAUTION, GetRTStackInfo(2)
	endif

	String info = GetRTStackInfo(3)
	Make/T/N=3/FREE tw = StringFromList(p,StringFromList(ItemsInList(info)-3,info),",")
	if (strlen(tw[0]))
		printf "%s(called from \"%s\" in %s (line %s))\r", PRESTR_CAUTION, tw[0], tw[1], tw[2]
	endif
End

Function KMTraceOffset([String grfName, Variable xoffset, Variable yoffset, int fill])
	deprecatedCaution("SIDAMTraceOffset")
	SIDAMTraceOffset(grfName=grfName, xoffset=xoffset, yoffset=yoffset, fill=fill)
End

Function KMTraceColor([String grfName, String clrTab, STRUCT RGBColor &clr])
	deprecatedCaution("SIDAMTraceColor")
	SIDAMTraceColor(grfName=grfName, clrTab=clrTab, clr=clr)
End
	
Function KMFourierPeakGetPos(	Wave w,int fitfn,[int marquee])
	deprecatedCaution("SIDAMPeakPos")
End

Function/WAVE KMLoadData(String pathStr, [int folder, int history])
	deprecatedCaution("SIDAMLoadData")
End

Function KMLayerViewerDo(String grfName, [Wave/Z w, int index, int direction])
	deprecatedCaution("")
End

Function KMInfoBar(String grfName)
	deprecatedCaution("SIDAMInfoBar")
	SIDAMInfoBar(grfName)
End

Function KMRange([String grfName, String imgList, Variable zmin, Variable zmax,
	int zminmode, int zmaxmode, int history])
	deprecatedCaution("SIDAMRange")
	SIDAMRange(grfName=grfName, imgList=imgList, zmin=zmin, zmax=zmax, zminmode=zminmode, zmaxmode=zmaxmode)
End

Function/WAVE KMLineSpectra(Wave/Z w, Variable p1, Variable q1, Variable p2,
	Variable q2, [String result, int mode, int output, int history])
	deprecatedCaution("SIDAMLineSpectra")
End

Function/WAVE KMLineProfile(Wave/Z w,Variable p1,Variable q1,Variable p2,
	Variable q2,[Variable width,int output,int history,String result])
	deprecatedCaution("SIDAMLineProfile")
End
Function/WAVE KMCorrelation(Wave/Z w1,[Wave/Z w2,String result,int subtract,
	int normalize,int origin,int history])
	deprecatedCaution("SIDAMCorrelation")
End

Function KMSubtraction(Wave/Z w, [Wave roi, int mode, int degree, int direction,
	int index, int history, String result])
	deprecatedCaution("SIDAMSubtraction")
End

Function KMFilter(Wave/Z srcw, Wave/Z paramw,
	[String result, int invert, int endeffect, int history])
	deprecatedCaution("SIDAMFilter")
End

Function KMFourierSym(Wave w, Wave q1w, Wave q2w, int sym, [int shear,
	int endeffect, String result, int history])
	deprecatedCaution("SIDAMFourierSym")
End

Function KMFFT(Wave/Z w, [String result, String win, int out,
	int subtract, int history])
	deprecatedCaution("SIDAMFFT")
End

Function KMWorkfunction(Wave/Z w, [String result, int startp, int endp, 
	Variable offset])
	deprecatedCaution("SIDAMWorkfunction")
End

Function KMHistogram(Wave/Z w, [String result, Variable startz, Variable endz,
	Variable deltaz, int bins, int cumulative, int normalize,
	int cmplxmode, int history])
	deprecatedCaution("SIDAMHistogram")
End

Function KMScalebar([String grfName,String anchor,int size,
	Wave fgRGBA,	Wave bgRGBA,int history])
	deprecatedCaution("SIDAMScalebar")
	SIDAMScalebar(grfName=grfName,anchor=anchor,size=size,\
		fgRGBA=fgRGBA,bgRGBA=bgRGBA)	
End