#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3

#include "SIDAM_Utilities_Image"

#ifndef SIDAMshowProc
#pragma hide = 1
#endif

Structure SIDAMCursorPos
	uchar	isImg
	uint32	p
	uint32	q
	double	x
	double	y
EndStructure

//******************************************************************************
///	SIDAMGetCursor 
///	@param csrName
///		Name of a cursor.
///	@param grfName
///		Name of a window.
///	@param pos
///		A new position where a cursor is moved.
//******************************************************************************
Function SIDAMGetCursor(String csrName, String grfName,
	STRUCT SIDAMCursorPos &pos)

	String infoStr = CsrInfo($csrName, grfName)
	if (!strlen(infoStr))			//	the cursor is not shown
		return 1
	endif

	String tName = StringByKey("TNAME", infoStr)
	Variable posx = NumberByKey("POINT", infoStr)
	Variable posy = NumberByKey("YPOINT", infoStr)

	pos.isImg = (strsearch(StringByKey("RECREATION",infoStr),"/I",0) != -1)
	if (pos.isImg)
		Wave w = ImageNameToWaveRef(grfName, tName)
	else
		Wave w = TraceNameToWaveRef(grfName, tName)
	endif

	Variable ox = DimOffset(w,0), oy = DimOffset(w,1)
	Variable dx = DimDelta(w,0), dy = DimDelta(w,1)
	if (NumberByKey("ISFREE", infoStr))
		//	When the cursor position is "free", posx and posy are between 0 and 1.
		//	Calculate (x,y) from these, then [p,q] from (x,y)
		STRUCT SIDAMAxisRange axis
		SIDAMGetAxis(grfName,tName,axis)
		pos.x = axis.xmin + (axis.xmax - axis.xmin) * posx
		pos.y = axis.ymin + (axis.ymax - axis.ymin) * (1 - posy)
		pos.p = pos.isImg ? round((pos.x-ox)/dy) : NaN
		pos.q = pos.isImg ? round((pos.y-oy)/dy) : NaN
	else
		//	When the cursor position is not "free", posx and posy are p and q,
		//	respectively
		pos.p = posx
		pos.q = posy		//	NaN if a 1D wave is displayed
		pos.x = pos.isImg ? ox+dy*posx : leftx(w)+deltax(w)*posx
		pos.y = pos.isImg ? oy+dy*posy : w[posx]
	endif

	return 0
End

//******************************************************************************
///	SIDAMMoveCursor 
///	@param csrName
///		Name of a cursor.
///	@param grfName
///		Name of a window.
///	@param mode
///		0 or 1. Set 0 to give a new position by p & q, 1 by x & y.
///	@param pos
///		A new position where a cursor is moved.
//******************************************************************************
Function SIDAMMoveCursor(String csrName, String grfName, int mode,
	STRUCT SIDAMCursorPos &pos)

	String infoStr = CsrInfo($csrName, grfName)
	if (!strlen(infoStr))			//	the cursor is not shown
		return 0
	endif
	String tName = StringByKey("TNAME", infoStr)
	int isFree = NumberByKey("ISFREE", infoStr)
	int active = strsearch(infoStr, "/A=0", 0) != -1 ? 0 : 1

	if (pos.isImg)
		if (isFree)
			if (mode)
				Cursor/A=(active)/F/I/W=$grfName $csrName $tName pos.x, pos.y
			else
				STRUCT SIDAMAxisRange axis
				SIDAMGetAxis(grfName,tName,axis)
				Cursor/A=(active)/F/I/P/W=$grfName $csrName $tName (pos.p-axis.pmin)/(axis.pmax-axis.pmin), (pos.q-axis.qmax)/(axis.qmin-axis.qmax)
			endif
		else
			if (mode)
				Cursor/A=(active)/I/W=$grfName $csrName $tName pos.x, pos.y
			else
				Cursor/A=(active)/I/P/W=$grfName $csrName $tName pos.p, pos.q
			endif
		endif
	else
		if (isFree && mode)
			Cursor/A=(active)/F/W=$grfName $csrName $tName pos.x, pos.y
		endif
	endif
End

Function/S SIDAMActiveCursors(String grfName)
	if (WinType(grfName) != 1)
		return ""
	endif
	
	String list = "ABCDEFGHIJ", active = "", info
	int i, n
	for (i = 0, n = strlen(list); i < n; i++)
		info = CsrInfo($(list[i]), grfName)
		if (!strlen(info) || strsearch(info, "A=0", 0)!=-1)
			continue
		endif
		active += list[i]
	endfor
	return active
End

