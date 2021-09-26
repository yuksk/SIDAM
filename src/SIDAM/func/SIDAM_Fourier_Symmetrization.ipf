#pragma TextEncoding="UTF-8"
#pragma rtGlobals=1
#pragma ModuleName = SIDAMFourierSym

#include "SIDAM_Display"
#include "SIDAM_PeakPos"
#include "SIDAM_Utilities_Bias"
#include "SIDAM_Utilities_Control"
#include "SIDAM_Utilities_Help"
#include "SIDAM_Utilities_Image"
#include "SIDAM_Utilities_Panel"
#include "SIDAM_Utilities_WaveDf"

#ifndef SIDAMshowProc
#pragma hide = 1
#endif

//@
//	Symmetrize Fourier transform based on symmetry.
//
//	## Parameters
//	w : wave
//		The input wave, 2D or 3D.
//	q1w : wave
//		The first peak, {qx, qy, a}.
//		The (qx, qy) is the peak position in pixel.
//		The a is the "ideal" real-space length corresponding to the peak.
//	q2w : wave
//		The second peak, specified in the same manner as the `q1w`.
//	sym : int {1 -- 5}
//		The symmetry.
//		1. 2mm
//		2. 3
//		3. 3m
//		4. 4
//		5. 4mm
//	shear : int {0 or 1}, default 0
//		The shear direction.
//		* 0: x
//		* 1: y
//	endeffect : int {0 -- 3}, default 2
//		How to handle the ends of the wave.
//		* 0: Bounce. Uses `w[i]` in place of the missing `w[-i]` and `w[n-i]` in place of the missing `w[n+i]`.
//		* 1: Wrap. Uses `w[n-i]` in place of the missing `w[-i]` and vice-versa.
//		* 2: Zero (default). Uses 0 for any missing value.
//		* 3: Repeat. Uses `w[0]` in place of the missing `w[-i]` and `w[n]` in place of the missing `w[n+i]`.
//
//	## Returns
//	wave
//		Symmetrized wave.
//@
Function/WAVE SIDAMFourierSym(Wave w, Wave q1w, Wave q2w, int sym,
	[int shear, int endeffect])
	
	STRUCT paramStruct s
	Wave/Z s.w = w
	Wave/Z s.q1w = q1w
	Wave/Z s.q2w = q2w
	s.sym = sym
	s.shear = ParamIsDefault(shear) ? 0 : shear
	s.endeffect = ParamIsDefault(endeffect) ? 2 : endeffect
	
	if (validate(s))
		print s.errMsg
		return $""
	endif
	
	return symmetrize(w, q1w, q2w, sym, s.shear, s.endeffect)
End

Static Function validate(STRUCT paramStruct &s)

	s.errMsg = PRESTR_CAUTION + "SIDAMFourierSym gave error: "
	
	int flag = SIDAMValidateWaveforFFT(s.w)
	if (flag)
		s.errMsg += SIDAMValidateWaveforFFTMsg(flag)
		return 0
	endif
	
	if (!WaveExists(s.q1w) || !WaveExists(s.q2w))
		s.errMsg += "wave not found."
		return 1
	endif
	
	if (s.sym < 1 || s.sym > 5)
		s.errMsg += "the parameter of symmetry must be from 1 to 5."
		return 1
	endif
	
	s.shear = s.shear ? 1 : 0
	s.endeffect = limit(s.endeffect, 0, 3)
End

Static Structure paramStruct
	String	errMsg
	Wave	w
	Wave	q1w
	Wave	q2w
	uchar	sym
	uchar	shear
	uchar	endeffect
EndStructure

Static Function/S echoStr(Wave w, Wave q1w, Wave q2w, int sym,
	int shear, int endeffect, String result)
	
	String paramStr = GetWavesDataFolder(w,2)
	paramStr += "," + SelectString(WaveType(q1w,2)==2, \
		GetWavesDataFolder(q1w,2), SIDAMWaveToString(q1w, noquote=1))
	paramStr += "," + SelectString(WaveType(q2w,2)==2, \
		GetWavesDataFolder(q2w,2), SIDAMWaveToString(q2w, noquote=1))
	paramStr += "," + num2str(sym)
	paramStr += SelectString(shear, "", ",shear=1")
	paramStr += SelectString(endeffect==2, ",endeffect="+num2str(endeffect), "")
	Sprintf paramStr, "Duplicate/O SIDAMFourierSym(%s), %s%s"\
		, paramStr, GetWavesDataFolder(w,1), PossiblyQuoteName(result)
				
	return paramStr
End


//	Wave q1w, q2w	{qx, qy, a}
//	int sym			1: 2mm, 2: 3, 3: 3m, 4: 4, 5: 4mm
//	int shear			0: x, 1: y
//	int endeffect	0: bounce, 1: wrap, 2: zero
Static Function/WAVE symmetrize(Wave w, Wave q1w, Wave q2w, int sym,
	int shear, int endeffect)
	
	Variable nx = DimSize(w,0), ny = DimSize(w,1), nz = DimSize(w,2)
	Variable ox = DimOffset(w,0), oy = DimOffset(w,1)
	Variable dx = DimDelta(w,0), dy = DimDelta(w,1)
	
	Variable q1x = ox + dx * q1w[0], q1y = oy + dy *q1w[1]
	Variable q2x = ox + dx * q2w[0], q2y = oy + dy *q2w[1]
	
	//	transformation matrix
	Wave mw = calcMatrix(w, q1w, q2w, sym, shear)
	Variable m1 = mw[0], m2 = mw[1], m3 = mw[2]
	
	//	Change the wave scaling for expansion in the x and y directions
	Duplicate/FREE w tw
	SetScale/P x -dx*(nx/2-1)*m1, dx*m1, "", tw
	SetScale/P y -dy*ny/2*m3, dy*m3, "", tw
	
	//	Extended wave
	Wave ew = SIDAMEndEffect(tw, endeffect)
	
	//	Shear correction
	Make/N=(nx,ny,nz)/FREE w0
	CopyScales tw, w0
	Variable m = shear ? m2/m1 : m2/m3
	if (shear)
		MultiThread w0 = sym_interpolation(ew, x, -m*x+y, r)
	else
		MultiThread w0 = sym_interpolation(ew, x-m*y, y, r)
	endif
	
	//	Extended wave after the shear correction
	Wave ew0 = SIDAMEndEffect(w0, endeffect)
	
	if (endeffect == 2)
		Make/N=(nx*3, ny*3, nz)/FREE enw0
		CopyScales ew0, enw0
		MultiThread enw0[nx,2*nx-1][ny,2*ny-1][] = 1	//	center-middle
	endif

	//	Make rotated waves
	switch (sym)
		case 2:	//	3
		case 3:	//	3m
			Wave w1 = sym_rotation(ew0, pi/3)
			Wave w2 = sym_rotation(ew0, pi/3*2)
			if (endeffect == 2)
				Wave nw1 = sym_rotation(enw0, pi/3)
				Wave nw2 = sym_rotation(enw0, pi/3*2)
			endif
			break
		case 4:	//	4
		case 5:	//	4mm
			Wave w1 = sym_rotation(ew0, pi/2)
			if (endeffect == 2)
				Wave nw1 = sym_rotation(enw0, pi/2)
			endif
			break
	endswitch
	
	//	Make mirrored waves
	if (sym == 1 || sym == 3 || sym ==5)
		Variable theta = shear ? atan((m2*q1x+m3*q1y)/(m1*q1x)) : atan((m3*q1y)/(m1*q1x+m2*q1y))
		switch (sym)
			case 1:	//	2mm
				Wave w1 = sym_mirror(ew0, 2*theta)
				if (endeffect == 2)
					Wave nw1 = sym_mirror(enw0, 2*theta)
				endif
				break
			case 3:	//	3m
				Wave w3 = sym_mirror(ew0, 2*theta)
				Wave w4 = sym_mirror(ew0, 2*(theta-pi/3))
				Wave w5 = sym_mirror(ew0, 2*(theta-pi/3*2))
				if (endeffect == 2)
					Wave nw3 = sym_mirror(enw0, 2*theta)
					Wave nw4 = sym_mirror(enw0, 2*(theta-pi/3))
					Wave nw5 = sym_mirror(enw0, 2*(theta-pi/3*2))
				endif
				break
			case 5:	//	4mm
				Wave w2 = sym_mirror(ew0, 2*theta)
				Wave w3 = sym_mirror(ew0, 2*(theta-pi/4))
				if (endeffect == 2)
					Wave nw2 = sym_mirror(enw0, 2*theta)
					Wave nw3 = sym_mirror(enw0, 2*(theta-pi/4))
				endif
				break
		endswitch
	endif
	
	//	symmetrize
	switch (sym)
		case 1:	//	2mm
			if (endeffect == 2)
				FastOP w0 = w0 + w1
				FastOP nw1 = 1 + nw1
				FastOP w0 = w0 / nw1
			else
				FastOP w0 = 0.5*w0 + 0.5*w1
			endif
			break
		case 2:	//	3
			if (endeffect == 2)
				FastOP w0 = w0 + w1 + w2
				FastOP nw1 = 1 + nw1 + nw2
				FastOP w0 = w0 / nw1
			else
				FastOP w0 = (1/3)*w0 + (1/3)*w1 + (1/3)*w2
			endif
			break
		case 3:	//	3m
			FastOP w0 = w0 + w1 + w2
			FastOP w0 = w0 + w3 + w4
			if (endeffect == 2)
				FastOP w0 = w0 + w5
				FastOP nw1 = 1 + nw1 + nw2
				FastOP nw1 = nw1 + nw3 + nw4
				FastOP nw1 = nw1 + nw5
				FastOP w0 = w0 / nw1
			else
				FastOP w0 = (1/6)*w0 + (1/6)*w5
			endif
			break
		case 4:	//	4
			if (endeffect == 2)
				FastOP w0 = w0 + w1
				FastOP nw1 = 1 + nw1
				FastOP w0 = w0 / nw1
			else
				FastOP w0 = 0.5*w0 + 0.5*w1
			endif
			break
		case 5:	//	4mm
			FastOP w0 = w0 + w1 + w2
			if (endeffect == 2)
				FastOP w0 = w0 + w3
				FastOP nw1 = 1 + nw1 + nw2
				FastOP nw1 = nw1 + nw3
				FastOP w0 = w0 / nw1
			else
				FastOP w0 = 0.25*w0 + 0.25*w3
			endif
			break
	endswitch
	
	String noteStr
	Sprintf noteStr, "%s;m1:%.4f;m2:%.4e;m3:%.4f;q1w:%s;q2w:%s;sym:%d;shear:%d;endeffect:%d;", note(w), m1, m2, m3, SIDAMWaveToString(q1w,noquote=1), SIDAMWaveToString(q2w,noquote=1),sym,shear,endeffect
	Note w0, noteStr
	
	SIDAMCopyBias(w, w0)
	
	return w0
End

Static Function/WAVE calcMatrix(w, q1w, q2w, sym, shear)
	Wave w, q1w, q2w
	Variable sym, shear
	
	Variable q1x = DimOffset(w,0) + DimDelta(w,0) * q1w[0], q1y = DimOffset(w,1) + DimDelta(w,1) *q1w[1]
	Variable q2x = DimOffset(w,0) + DimDelta(w,0) * q2w[0], q2y = DimOffset(w,1) + DimDelta(w,1) *q2w[1]
	
	Variable lx = q1w[2]^-2, ly = q2w[2]^-2, lz = 1 / (q1w[2] * q2w[2])
	switch (sym)
		case 1:	//	2mm
			lz *= cos(pi/2)
			break
		case 2:	//	3
		case 3:	//	3mm
			lz *= q1x*q2x + q1y*q2y > 0 ? cos(pi/3) : cos(2*pi/3)
			break
		case 4:	//	4
		case 5:	//	4mm
			lz *= cos(pi/2)
			break
	endswitch
	
	Variable N = (q1x*q2y - q1y*q2x)^2
	Variable A = (q2y^2*lx + q1y^2*ly - 2*q1y*q2y*lz ) / N
	Variable B = -(q2x*q2y*lx + q1x*q1y*ly - (q1x*q2y+q1y*q2x)*lz) / N
	Variable C = (q2x^2*lx + q1x^2*ly - 2*q1x*q2x*lz) / N
	
	Make/D/N=3/FREE resw
	resw[0] = shear ? sqrt(A-B^2/C) : sqrt(A)
	resw[1] = shear ? B/sqrt(C) : B/sqrt(A)
	resw[2] = shear ? sqrt(C) : sqrt(C-B^2/A)
	
	return resw
End

ThreadSafe Static Function/WAVE sym_rotation(Wave ew, Variable theta)
	Wave resw = sym_reduce(ew)
	Variable vc = cos(theta), vs = sin(theta)
	MultiThread resw = sym_interpolation(ew, x*vc-y*vs, x*vs+y*vc, r)
	return resw
End

ThreadSafe Static Function/WAVE sym_mirror(Wave ew, Variable theta)
	Wave resw = sym_reduce(ew)
	Variable vc = cos(theta), vs = sin(theta)
	MultiThread resw = sym_interpolation(ew, x*vc+y*vs, x*vs-y*vc, r)
	return resw
End

//	Input an extended wave and return an empty wave size of
//	which is the same as the original before extension
ThreadSafe Static Function/WAVE sym_reduce(Wave ew)
	Make/N=(DimSize(ew,0)/3, DimSize(ew,1)/3, DimSize(ew,2))/FREE redw
	SetScale/P x DimOffset(ew,0)+DimDelta(ew,0)*DimSize(ew,0)/3, DimDelta(ew,0),"", redw
	SetScale/P y DimOffset(ew,1)+DimDelta(ew,1)*DimSize(ew,1)/3, DimDelta(ew,1),"", redw
	SetScale/P z DimOffset(ew,2), DimDelta(ew,2),"", redw
	return redw
End

ThreadSafe Static Function sym_interpolation(Wave w, Variable kx,
	Variable ky, Variable rr)
	
	Variable ox = DimOffset(w,0), oy = DimOffset(w,1)
	Variable dx = DimDelta(w,0), dy = DimDelta(w,1)
	Variable p0 = floor((kx-ox)/dx), p1 = ceil((kx-ox)/dx)
	Variable q0 = floor((ky-oy)/dy), q1 = ceil((ky-oy)/dy)
	
	Variable x0 = ox + dx*p0, x1 = ox + dx*p1
	Variable y0 = oy + dy*q0, y1 = oy + dy*q1
	
	Variable xx = (x0 == x1) ? 0 : (x1-kx)/(x1-x0)
	Variable yy = (y0 == y1) ? 0 : (y1-ky)/(y1-y0)
	
	Variable c00 = xx * yy
	Variable c01 = xx * (1 - yy)
	Variable c10 = (1 - xx) * yy
	Variable c11 = (1 - xx) * (1 - yy)
	
	return w[p0][q0][rr]*c00+w[p0][q1][rr]*c01+w[p1][q0][rr]*c10+w[p1][q1][rr]*c11
End

//==============================================================================

Static Function menuDo()
	pnl(SIDAMImageNameToWaveRef(WinName(0,1)),WinName(0,1))
End

Static Function marqueeDo()
	GetLastUserMenuInfo
	String menuItem = S_value
	Variable vec = str2num(menuItem[strlen(menuItem)-1])
	
	//	Get the peak position
	String grfName = WinName(0,1)
	Wave iw = SIDAMImageNameToWaveRef(grfName)
	Wave posw = SIDAMPeakPos(iw, 1)	//	asymmetric Lorentz2D	

	//	Pass the position to the panel
	Variable cp = (posw[2]-DimOffset(iw,0))/DimDelta(iw,0)
	Variable cq = (posw[3]-DimOffset(iw,1))/DimDelta(iw,1)
	String pnlName = GetUserData(grfName, "", KEY)
	pnlPutNumbers(pnlName, vec, {cp,cq})
End

Static Function/S marqueeMenu()
	String grfName = WinName(0,1,1)
	if (!strlen(grfName))
		return ""
	endif
	
	String pnlName = GetUserData(grfName, "", KEY)
	if (!strlen(pnlName))
		return ""
	else
		return "Get peak location for vector 1;Get peak location for vector 2"
	endif
End

//==============================================================================

Static StrConstant SUFFIX = "_sym"
Static StrConstant KEY = "SIDAMFourierSymPnl"

Static Function pnl(Wave w, String grfName)
	String pnlName = SIdAMNewPanel("Symmetrize FFT ("+NameOfWave(w)+")", 355, 250)
	SetWindow $pnlName hook(self)=SIDAMFourierSym#pnlHook
	SetWindow $pnlName userData(src)=GetWavesDataFolder(w,2)
	Variable nx = DimSize(w,0), ny = DimSize(w,1)
	
	SetVariable outputV title="output name", pos={8,9}, size={341,16}, bodyWidth=274, win=$pnlName
	SetVariable outputV value= _STR:NameOfWave(w)+SUFFIX, proc=SIDAMFourierSym#pnlSetVar, win=$pnlName
	PopupMenu symP title="symmetry", pos={21,39}, size={143,20}, bodyWidth=90, win=$pnlName
	PopupMenu symP mode=1, value= "2mm;3;3m;4;4mm", proc=SIDAMFourierSym#pnlPopup, win=$pnlName
	PopupMenu shearP title="shear", pos={196,39}, size={101,20}, bodyWidth=70, mode=1, value="x;y", win=$pnlName
	PopupMenu endeffectP title="end effects", pos={13,70}, size={151,20}, bodyWidth=90, win=$pnlName
	PopupMenu endeffectP mode=3, value= "bounce;wrap;zero;repeat", proc=SIDAMFourierSym#pnlPopup, win=$pnlName
	
	GroupBox v1G title="vector 1", pos={6,102}, size={169,103}, win=$pnlName
	SetVariable p1V title="p", pos={17,124}, value=_STR:num2str(nx/2-1), win=$pnlName
	SetVariable q1V title="q", pos={17,150}, value= _STR:num2str(ny/2), win=$pnlName
	SetVariable a1V title="a", pos={17,176}, value= _STR:"0", win=$pnlName
	
	GroupBox v2G title="vector 2", pos={180,102}, size={169,103}, win=$pnlName
	SetVariable p2V title="p", pos={191,124}, value= _STR:num2str(nx/2-1), win=$pnlName
	SetVariable q2V title="q", pos={191,150}, value= _STR:num2str(ny/2), win=$pnlName
	SetVariable a2V title="a", pos={191,176}, value= _STR:"0", win=$pnlName
	
	Button doB title="Do It", pos={5,219}, size={60,20}, proc=SIDAMFourierSym#pnlButton, win=$pnlName
	CheckBox displayC title="display", pos={75,222}, size={54,14}, value=1, win=$pnlName
	PopupMenu toP title="To", pos={140,219}, size={50,20}, bodyWidth=50, win=$pnlName
	PopupMenu toP value="Cmd Line;Clip", mode=0, proc=SIDAMFourierSym#pnlPopup, win=$pnlName
	Button helpB title="Help", pos={220,219}, size={60,20}, proc=SIDAMFourierSym#pnlButton, win=$pnlName
	Button cancelB title="Cancel", pos={290,219}, size={60,20}, proc=SIDAMFourierSym#pnlButton, win=$pnlName
	
	String ctrlList = "p1V;q1V;a1V;p2V;q2V;a2V;"
	ModifyControlList ctrlList size={150,16}, bodyWidth=140, proc=SIDAMFourierSym#pnlSetVar, win=$pnlName
	ModifyControlList ctrlList valueColor=(SIDAM_CLR_EVAL_R,SIDAM_CLR_EVAL_G,SIDAM_CLR_EVAL_B), win=$pnlName
	ModifyControlList ctrlList fColor=(SIDAM_CLR_EVAL_R,SIDAM_CLR_EVAL_G,SIDAM_CLR_EVAL_B), win=$pnlName
	
	ModifyControlList ControlNameList(pnlName,";","*") focusRing=0, win=$pnlName
	
	AutoPositionWindow/E/M=0/R=$grfName $pnlName
	SetWindow $pnlName userData(parent)=grfName
	SetWindow $grfName hook($KEY)=SIDAMFourierSym#pnlHookParent, userData($KEY)=pnlName
End

Static Function pnlHook(STRUCT WMWinHookStruct &s)
	switch (s.eventCode)
		case 2:	//	kill
			SetWindow $GetUserData(s.winName,"","parent") hook($KEY)=$"", userData($KEY)=""
			break
		case 5:	//	mouseup
			if (strlen(GetUserData(s.winName,"","parent")))
				Variable v1Gsel = isGBClicked(s,"v1G")
				Variable v2Gsel = isGBClicked(s,"v2G")
				GroupBox v1G fstyle=v1Gsel, userData(selected)=num2str(v1Gsel), win=$s.winName
				GroupBox v2G fstyle=v2Gsel, userData(selected)=num2str(v2Gsel), win=$s.winName
				SetVariable p1V fstyle=v1Gsel, win=$s.winName
				SetVariable q1V fstyle=v1Gsel, win=$s.winName
				SetVariable p2V fstyle=v2Gsel, win=$s.winName
				SetVariable q2V fstyle=v2Gsel, win=$s.winName
			endif
			break
		case 11:	//	keyboard
			if (s.keycode == 27)	//	esc
				SetWindow $GetUserData(s.winName,"","parent") hook($KEY)=$"", userData($KEY)=""
				KillWindow $s.winName
			endif
			break
	endswitch
	
	return 0
End

//	A groupbox is clicked or not
Static Function isGBClicked(STRUCT WMWinHookStruct &s, String grpName)
	ControlInfo/W=$s.winName $grpName
	return (V_left < s.mouseLoc.h && s.mouseLoc.h < V_left + V_width && \
		V_top < s.mouseLoc.v && s.mouseLoc.v < V_top + V_height)
End

Static Function pnlHookParent(STRUCT WMWinHookStruct &s)	
	switch (s.eventCode)
		case 2:	//	killed
			SetWindow $GetUserData(s.winName, "", KEY) userData(parent)=""
			break
		case 3:	//	mousedown
			//	Record the eventMod used at the event of mouseup
			SetWindow $s.winName userData(eventMod)=num2istr(s.eventMod)
			break
		case 5:	//	mouseup
			//	The eventMode recorded at the event of mousedown
			Variable eventMod = str2num(GetUserData(s.winName,"","eventMod"))
			//	If the click is left click, put the numbers to the item
			//	selected in the panel. This must be left click otherwise
			//	the marquee menu does not work well.
			if (!(eventMod & 16))
				String pnlName = GetUserData(s.winName, "", KEY)
				STRUCT SIDAMMousePos ms
				SIDAMGetMousePos(ms, s.winName, s.mouseLoc, grid=1)
				if (str2num(GetUserData(pnlName,"v1G","selected")))
					pnlPutNumbers(pnlName, 1, {ms.p,ms.q})
				elseif (str2num(GetUserData(pnlName,"v2G","selected")))
					pnlPutNumbers(pnlName, 2, {ms.p,ms.q})
				endif
			endif
			//	Delete the recorded eventMod
			SetWindow $s.winName userData(eventMod)=""
			break
	endswitch
	
	return 0
End

//-------------------------------------------------------------
//	Controls
//-------------------------------------------------------------
//	Setvariable
Static Function pnlSetVar(STRUCT WMSetVariableAction &s)

	//	Handle either mouse up, enter key, or end edit
	if (s.eventCode != 1 && s.eventCode != 2 && s.eventCode != 8)
		return 1
	endif

	Wave w = $GetUserData(s.win, "", "src")
	strswitch (s.ctrlName)
		case "outputV":
			SIDAMValidateSetVariableString(s.win,s.ctrlName,0)
			break
		case "p1V":
		case "q1V":
		case "p2V":
		case "q2V":
		case "a1V":
		case "a2V":
			SIDAMValidateSetVariableString(s.win,s.ctrlName,1)
			if (stringmatch(s.ctrlName, "a1V"))
				ControlInfo/W=$s.win symP
				if (V_Value != 1)	//	not 2mm
					SetVariable a2V value=_STR:s.sval, win=$s.win
				endif
			endif
			break
	endswitch
	
	String ctrlList = "outputV;p1V;q1V;p2V;q2V;a1V;a2V"
	Variable i, disable = 0
	for (i = 0; i < ItemsInList(ctrlList); i += 1)
		if (strlen(GetUserData(s.win, StringFromList(i,ctrlList), "check")))
			disable = 2
			break
		endif
	endfor
	PopupMenu toP disable=disable, win=$s.win
	Button doB disable=disable, win=$s.win
End

//	popup
Static Function pnlPopup(STRUCT WMPopupAction &s)
	if (s.eventCode != 2)
		return 1
	endif
	
	strswitch (s.ctrlName)
		case "symP":
			if (s.popNum == 1)
				SetVariable a2V disable=0, win=$s.win
			else
				ControlInfo/W=$s.win a1V
				SetVariable a2V value=_STR:S_Value, disable=2, win=$s.win
			endif
			break
		case "toP":
			Wave w = $GetUserData(s.win,"","src")
			Wave cvw = SIDAMGetCtrlValues(s.win, "symP;shearP;endeffectP")
			ControlInfo/W=$s.win outputV
			String paramStr = echoStr(w,\
				SIDAMGetCtrlTexts(s.win, "p1V;q1V;a1V"), \
				SIDAMGetCtrlTexts(s.win, "p2V;q2V;a2V"), \
				cvw[0], cvw[1]-1, cvw[2]-1, S_value)
			SIDAMPopupTo(s, paramStr)
			break
	endswitch
End

//	Button
Static Function pnlButton(STRUCT WMButtonAction &s)
	if (s.eventCode != 2)
		return 0
	endif
	
	strswitch (s.ctrlName)
		case "doB":
			Wave w = $GetUserData(s.win,"","src")
			Wave cvw = SIDAMGetCtrlValues(s.win, "symP;shearP;endeffectP;displayC")
			Wave q1w = SIDAMGetCtrlValues(s.win, "p1V;q1V;a1V")
			Wave q2w = SIDAMGetCtrlValues(s.win, "p2V;q2V;a2V")
			Wave/T q1tw = SIDAMGetCtrlTexts(s.win, "p1V;q1V;a1V")
			Wave/T q2tw = SIDAMGetCtrlTexts(s.win, "p2V;q2V;a2V")
			ControlInfo/W=$s.win outputV ;	String result = S_Value
			KillWindow $s.win
			printf "%s%s\r", PRESTR_CMD, echoStr(w, q1tw, q2tw, \
				cvw[0], cvw[1]-1, cvw[2]-1, result)
			DFREF dfr = GetWavesDataFolderDFR(w)
			Duplicate/O SIDAMFourierSym(w, q1w, q2w, cvw[0], shear=cvw[1]-1, \
				endeffect=cvw[2]-1) dfr:$result/WAVE=resw
			if (cvw[3])
				SIDAMDisplay(resw, history=1)
			endif
			break
		case "cancelB":
			KillWindow $s.win
			break
		case "helpB":
			SIDAMOpenHelpNote("symmetrization",s.win,"Fourier Symmetrization")
			break
	endswitch
End

Static Function pnlPutNumbers(String pnlName, int num, Wave nw)
	switch (num)
		case 1:
			SetVariable p1V value=_STR:num2str(nw[0]), fstyle=0, win=$pnlName
			SetVariable q1V value=_STR:num2str(nw[1]), fstyle=0, win=$pnlName
			GroupBox v1G fstyle=0, userData(selected)="0", win=$pnlName
			break
		case 2:
			SetVariable p2V value=_STR:num2str(nw[0]), fstyle=0, win=$pnlName
			SetVariable q2V value=_STR:num2str(nw[1]), fstyle=0, win=$pnlName
			GroupBox v2G fstyle=0, userData(selected)="0", win=$pnlName
			break
	endswitch
End
