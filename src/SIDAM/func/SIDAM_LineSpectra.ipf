#pragma TextEncoding="UTF-8"
#pragma rtGlobals=3
#pragma ModuleName = SIDAMLineSpectra

#include "SIDAM_Color"
#include "SIDAM_Line"
#include "SIDAM_Range"
#include "SIDAM_Utilities_Bias"
#include "SIDAM_Utilities_Control"
#include "SIDAM_Utilities_Image"
#include "SIDAM_Utilities_misc"
#include "SIDAM_Utilities_Panel"
#include "SIDAM_Utilities_WaveDf"

#ifndef SIDAMshowProc
#pragma hide = 1
#endif

Static StrConstant SUFFIX_X = "X"
Static StrConstant SUFFIX_Y = "Y"

Static StrConstant PNL_W = "LineSpectra"
Static StrConstant PNL_X = "LineSpectraX"
Static StrConstant PNL_Y = "LineSpectraY"
Static StrConstant PNL_C = "LineSpectraC"
Static StrConstant PNL_B1 = "LineSpectra_b"
Static StrConstant PNL_B2 = "LineSpectra_x"
Static StrConstant PNL_T = "LineSpectraT"

Static StrConstant KEY = "SIDAMLineSpectra"

//@
//	Get spectra along a trajectory line.
//
//	## Parameters
//	w : wave
//		The 3D input wave.
//	p1, q1 : variable
//		The position of the starting point (pixel).
//	p2, q2 : variable
//		The position of the ending point (pixel).
//	mode : int {0 -- 2}, default 0
//		How to get spectra.
//		* 0: Take spectra from all the pixels on the trajectory line
//		* 1: Take a value at a pixel in either x or y direction
//			(depending on the angle of the trajectory line) and
//			interpolate in the other direction.
//		* 2: Use ``ImageLineProfile`` of Igor Pro.
//	output : int {0 or !0}, default 0
//		Set !0 to save waves of positions.
//	basename : string, default ""
//		Name of the line profile wave and basename of additional waves
//		(when the output != 0). If this is specified, output waves are
//		save in the data folder where the input wave is.
//
//	## Returns
//	wave
//		Spectra along the trajectory line.
//@
Function/WAVE SIDAMLineSpectra(Wave/Z w, Variable p1, Variable q1,
	Variable p2,	Variable q2, [int mode, int output, String basename])

	STRUCT paramStruct s
	Wave/Z s.w = w
	s.p1 = p1
	s.q1 = q1
	s.p2 = p2
	s.q2 = q2
	s.mode = ParamIsDefault(mode) ? 0 : mode
	s.output = ParamIsDefault(output) ? 0 : output
	s.basename = SelectString(ParamIsDefault(basename), basename, "")
	s.dfr = GetWavesDataFolderDFR(s.w)

	if (validate(s))
		print s.errMsg
		return $""
	endif

	return getLineSpectra(s)
End

Static Function validate(STRUCT paramStruct &s)

	s.errMsg = PRESTR_CAUTION + "SIDAMLineSpectra gave error: "

	if (!WaveExists(s.w))
		s.errMsg += "wave not found."
		return 1
	elseif (WaveDims(s.w) != 3)
		s.errMsg += "the dimension of input wave must be 3."
		return 1
	endif

	if (numtype(s.p1) || numtype(s.q1) || numtype(s.p2) || numtype(s.q2))
		s.errMsg += "coordinate must be a normal number."
		return 1
	endif

	if (s.mode > 2)
		s.errMsg += "the mode must be 0, 1, or 2."
		return 1
	endif

	if (s.output > 1)
		s.errMsg += "The output must be 0 or 1."
		return 1
	endif

	return 0
End

Static Structure paramStruct
	Wave	w
	String	errMsg
	double	p1
	double	q1
	double	p2
	double	q2
	String	basename
	uchar	mode
	uchar	output
	DFREF dfr
	STRUCT WaveParam waves
EndStructure

Static Structure WaveParam
	Wave resw
	Wave pw
	Wave qw
	Wave xw
	Wave yw
endStructure

Static Function menuDo()
	pnl(WinName(0,1))
End


Static Function/WAVE getLineSpectra(STRUCT paramStruct &s)

	int i
	String noteStr

	Make/N=(DimSize(s.w,2),0)/FREE resw
	Wave s.waves.resw = resw

	Make/N=0/FREE pw, qw, xw, yw
	Wave s.waves.pw = pw, s.waves.qw = qw
	Wave s.waves.xw = xw, s.waves.yw = yw

	switch (s.mode)
		case 0:
			getLineSpectraMode0(s)
			break
		case 1:
			getLineSpectraMode1(s)
			break
		case 2:
			getLineSpectraMode2(s)
			break
		default:
	endswitch

	SetScale/P x DimOffset(s.w,2), DimDelta(s.w,2), WaveUnits(s.w,2), s.waves.resw
	SetScale/I y 0, sqrt(((s.p2-s.p1)*DimDelta(s.w,0))^2+((s.q2-s.q1)*DimDelta(s.w,1))^2), WaveUnits(s.w,0), s.waves.resw
	SetScale d 0, 0, StringByKey("DUNITS", WaveInfo(s.w,0)), s.waves.resw
	Sprintf noteStr, "src@%s;start@p=%.2f,q=%.2f;end@p=%.2f,q=%.2f;"\
		, GetWavesDataFolder(s.w,2), s.p1, s.q1, s.p2, s.q2
	Note s.waves.resw, noteStr
	
	if (strlen(s.basename))
		DFREF dfrSav = GetDataFolderDFR()
		SetDataFolder s.dfr		//	current data folder
		Duplicate/O s.waves.resw $s.basename/WAVE=rtnw

		if (SIDAMisUnevenlySpacedBias(s.w))
			Duplicate/O SIDAMGetBias(s.w,1) $(s.basename+"_b")
			Duplicate/O SIDAMGetBias(s.w,2) $(s.basename+"_x")
		endif

		if (s.output)
			Duplicate/O xw $(s.basename+SUFFIX_X)
			Duplicate/O yw $(s.basename+SUFFIX_Y)
		endif
		SetDataFolder dfrSav
		return rtnw
	else
		return s.waves.resw
	endif

End

//------------------------------------------------------------------------------
//	Take spectra from all the pixels on the trajectory line
//------------------------------------------------------------------------------
Static Function getLineSpectraMode0(STRUCT paramStruct &s)

	if (s.p1 == s.p2 && s.q1 == s.q2)
		Redimension/N=1 s.waves.pw, s.waves.qw
		s.waves.pw = s.p1
		s.waves.qw = s.q1
	else
		//	Change the sign so that the sort used later can be always done
		//	in ascending order
		int revp = (s.p1 > s.p2), revq = (s.q1 > s.q2)
		s.p1 *= revp ? -1 : 1
		s.p2 *= revp ? -1 : 1
		s.q1 *= revq ? -1 : 1
		s.q2 *= revq ? -1 : 1

		Redimension/N=(abs(s.p2-s.p1)+1,abs(s.q2-s.q1)+1) s.waves.pw, s.waves.qw
		Make/N=(abs(s.p2-s.p1)+1,abs(s.q2-s.q1)+1)/FREE xyw
		Make/N=(abs(s.p2-s.p1)+1,abs(s.q2-s.q1)+1)/B/U/FREE inoutw

		Setscale/P x min(s.p1,s.p2), 1, "", s.waves.pw, s.waves.qw, xyw, inoutw
		Setscale/P y min(s.q1,s.q2), 1, "", s.waves.pw, s.waves.qw, xyw, inoutw

		Variable d = 1 / ((s.p2-s.p1)^2 + (s.q2-s.q1)^2)
		xyw = ((x-s.p1)*(s.p2-s.p1)+(y-s.q1)*(s.q2-s.q1)) * d
		s.waves.pw = s.p1 + xyw*(s.p2-s.p1)
		s.waves.qw = s.q1 + xyw*(s.q2-s.q1)

		inoutw = abs(x-s.waves.pw) < 0.5 && abs(y-s.waves.qw) < 0.5

		s.waves.pw = x
		s.waves.qw = y
		Redimension/N=(numpnts(inoutw)) s.waves.pw, s.waves.qw, inoutw

		//	Delete points non on the trajectory lines
		Sort/R inoutw, s.waves.pw, s.waves.qw
		Deletepoints sum(inoutw), numpnts(inoutw)-sum(inoutw), s.waves.pw, s.waves.qw

		//	Sort
		SortColumns keyWaves={s.waves.pw, s.waves.qw}, sortWaves={s.waves.pw, s.waves.qw}

		//	Revert the sign if necessary
		s.waves.pw *= revp ? -1 : 1
		s.waves.qw *= revq ? -1 : 1
		s.p1 *= revp ? -1 : 1
		s.p2 *= revp ? -1 : 1
		s.q1 *= revq ? -1 : 1
		s.q2 *= revq ? -1 : 1
	endif

	//	spectra
	if (WaveType(s.w) & 0x01)	//	complex
		Redimension/N=(-1,numpnts(s.waves.pw))/C s.waves.resw
		Wave/C resw = s.waves.resw
		resw = s.w[s.waves.pw[q]][s.waves.qw[q]][p]
	else
		Redimension/N=(-1,numpnts(s.waves.pw)) s.waves.resw
		s.waves.resw = s.w[s.waves.pw[q]][s.waves.qw[q]][p]
	endif

	//	positions
	Redimension/N=(numpnts(s.waves.pw)) s.waves.xw, s.waves.yw
	s.waves.xw = DimOffset(s.w,0)+DimDelta(s.w,0)*s.waves.pw
	s.waves.yw = DimOffset(s.w,1)+DimDelta(s.w,1)*s.waves.qw
End

//------------------------------------------------------------------------------
//	Pick up a value in either x or y direction (depending on the angle of
//	the trajectory line) and interpolate in the other direction.
//------------------------------------------------------------------------------
Static Function getLineSpectraMode1(STRUCT paramStruct &s)

	int n = max(abs(s.p2-s.p1),abs(s.q2-s.q1))+1
	int isComplex = WaveType(s.w) & 0x01

	Redimension/N=(n) s.waves.pw, s.waves.qw
	s.waves.pw = s.p1 + (s.p2-s.p1)/(n-1)*p
	s.waves.qw = s.q1 + (s.q2-s.q1)/(n-1)*p
	Wave pw = s.waves.pw, qw = s.waves.qw	//	shorthand

	if (isComplex)
		Redimension/N=(-1,n)/C s.waves.resw
		Wave/C resw = s.waves.resw
	else
		Redimension/N=(-1,n) s.waves.resw
	endif

	//	spectra
	if (abs(s.p2-s.p1) > abs(s.q2-s.q1))
		if (isComplex)
			resw = cmplx(floor(qw[q])==ceil(qw[q]),0) ? \
					s.w[pw[q]][qw[q]][p] : \
					s.w[pw[q]][floor(qw[q])][p]*cmplx(ceil(qw[q])-qw[q],0) \
					+ s.w[pw[q]][ceil(qw[q])][p]*cmplx(qw[q]-floor(qw[q]),0)

		else
			s.waves.resw = floor(qw[q]) == ceil(qw[q]) ? \
							s.w[pw[q]][qw[q]][p] : \
							s.w[pw[q]][floor(qw[q])][p]*(ceil(qw[q])-qw[q]) \
							+ s.w[pw[q]][ceil(qw[q])][p]*(qw[q]-floor(qw[q]))
		endif

	elseif (abs(s.p2-s.p1) < abs(s.q2-s.q1))
		if (isComplex)
			resw = cmplx(floor(pw[q])==ceil(pw[q]),0) ? \
					s.w[pw[q]][qw[q]][p] : \
					s.w[floor(pw[q])][qw[q]][p]*cmplx(ceil(pw[q])-pw[q],0) \
					+ s.w[ceil(pw[q])][qw[q]][p]*cmplx(pw[q]-floor(pw[q]),0)

		else
			s.waves.resw = floor(pw[q]) == ceil(pw[q]) ? \
							s.w[pw[q]][qw[q]][p] : \
							s.w[floor(pw[q])][qw[q]][p]*(ceil(pw[q])-pw[q]) \
							+ s.w[ceil(pw[q])][qw[q]][p]*(pw[q]-floor(pw[q]))

		endif

	elseif (n > 1)
		if (isComplex)
			resw = s.w[pw[q]][qw[q]][p]
		else
			s.waves.resw = s.w[pw[q]][qw[q]][p]
		endif

	endif

	//	positions
	Redimension/N=(numpnts(s.waves.pw)) s.waves.xw, s.waves.yw
	s.waves.xw = DimOffset(s.w,0)+DimDelta(s.w,0)*s.waves.pw
	s.waves.yw = DimOffset(s.w,1)+DimDelta(s.w,1)*s.waves.qw
End

//------------------------------------------------------------------------------
//	Use ImageLineProfile
//------------------------------------------------------------------------------
Static Function getLineSpectraMode2(STRUCT paramStruct &s)

	DFREF dfrSav = GetDataFolderDFR()
	SetDataFolder NewFreeDataFolder()

	Make/N=2 pw = {s.p1, s.p2}, qw = {s.q1, s.q2}

	//	spectra
	if (WaveType(s.w) & 0x01)	//	complex
		MatrixOP/FREE realw = real(s.w)
		MatrixOP/FREE imagw = imag(s.w)
		//	real
		SetDataFolder NewFreeDataFolder()
		ImageLineProfile/P=-2 xWave=pw, yWave=qw, srcWave=realw
		Wave rw = M_ImageLineProfile
		MatrixTranspose rw
		//	imaginary
		SetDataFolder NewFreeDataFolder()
		ImageLineProfile/P=-2 xWave=pw, yWave=qw, srcWave=imagw
		Wave iw = M_ImageLineProfile
		MatrixTranspose iw
		//	combine them in complex
		Redimension/N=(DimSize(rw,0),DimSize(rw,1))/C s.waves.resw
		Wave/C resw = s.waves.resw
		resw = cmplx(rw,iw)

	else
		Duplicate s.w tw
		SetScale/P x 0, 1, "", tw
		SetScale/P y 0, 1, "", tw
		ImageLineProfile/P=-2 xWave=pw, yWave=qw, srcWave=tw
		Wave prow = M_ImageLineProfile
		MatrixTranspose prow
		Redimension/N=(DimSize(prow,0),DimSize(prow,1)) s.waves.resw
		s.waves.resw = prow
	endif

	//	positions
	Wave xw = W_LineProfileX, yw = W_LineProfileY
	Redimension/N=(numpnts(xw)) s.waves.pw, s.waves.qw, s.waves.xw, s.waves.yw
	s.waves.pw = xw
	s.waves.qw = yw
	s.waves.xw = DimOffset(s.w,0)+DimDelta(s.w,0)*xw
	s.waves.yw = DimOffset(s.w,1)+DimDelta(s.w,1)*yw

	SetDataFolder dfrSav
End


//******************************************************************************
//	Show the main panel
//******************************************************************************
Static Function pnl(String LVName)
	if (SIDAMWindowExists(GetUserData(LVName,"",KEY)))
		DoWindow/F $GetUserData(LVName,"",KEY)
		return 0
	endif

	Wave w = SIDAMImageWaveRef(LVName)
	int i

	Display/K=1/W=(0,0,315*72/screenresolution,340*72/screenresolution) as NameOfWave(w)
	String pnlName = S_name
	AutoPositionWindow/E/M=0/R=$LVName $pnlName

	DFREF dfrSav = GetDataFolderDFR()
	String dfTmp = SIDAMNewDF(pnlName,"LineSpectra")
	SetDataFolder $dfTmp

	Make/N=(1,1)/O $PNL_W
	Make/N=1/O $PNL_X, $PNL_Y, $PNL_B1, $PNL_B2
	Make/N=(1,3)/O $PNL_C
	Make/T/N=2/O $PNL_T = {"1","2"}

	SetWindow $pnlName hook(self)=SIDAMLine#pnlHook, userData(parent)=LVName
	SetWindow $pnlName userData(src)=GetWavesDataFolder(w,2)
	SetWindow $pnlName userData(grid)="1"
	SetWindow $pnlName userData(dim)="1"
	SetWindow $pnlName userData(highlight)="0"
	SetWindow $pnlName userData(mode)="0"
	SetWindow $pnlName userData(key)=KEY
	SetWindow $pnlName userData(dfTmp)=dfTmp

	SIDAMLine#pnlCtrls(pnlName)
	ModifyControlList "p1V;q1V;p2V;q2V;distanceV;angleV" proc=SIDAMLineSpectra#pnlSetVar, win=$pnlName
	ModifyControlList ControlNameList(pnlName,";","*") focusRing=0, win=$pnlName

	//	Get line profiles for the default values
	pnlUpdateLineSpectra(pnlName)
	pnlUpdateTextmarker(pnlName)

	//	For the waterfall plot
	if (SIDAMisUnevenlySpacedBias(w))
		Newwaterfall/FG=(FL,KMFT,FR,FB)/HOST=$pnlName/N=line $PNL_W vs {$PNL_B1,*}
	else
		Newwaterfall/FG=(FL,KMFT,FR,FB)/HOST=$pnlName/N=line $PNL_W
	endif
	pnlModifyGraph(pnlName+"#line")

	//	For the image plot
	Display/FG=(FL,KMFT,FR,FB)/HOST=$pnlName/N=image/HIDE=1
	if (SIDAMisUnevenlySpacedBias(w))
		AppendImage/W=$pnlName#image $PNL_W vs {$PNL_B2, *}
	else
		AppendImage/W=$pnlName#image $PNL_W
	endif
	pnlModifyGraph(pnlName+"#image")
	SetActiveSubWindow $pnlName

	pnlSetParent(LVName,pnlName)

	SetDataFolder dfrSav
End

//	Make 'prtName' a parent window of 'chdName'
Static Function pnlSetParent(String prtName, String chdName)
	String dfTmp = GetUserData(chdName,"","dfTmp")
	SetWindow $prtName hook($KEY)=SIDAMLineSpectra#pnlHookParent
	SetWindow $prtName userData($KEY)=AddListItem(chdName+"="+dfTmp, GetUserData(prtName,"",KEY))
	SetWindow $chdName userData(parent)=prtName

	String trcName = PNL_Y+prtName
	AppendToGraph/W=$prtName $(dfTmp+PNL_Y)/TN=$trcName vs $(dfTmp+PNL_X)
	ModifyGraph/W=$prtName mode($trcName)=4,msize($trcName)=5
	ModifyGraph/W=$prtName textMarker($trcName)={$(dfTmp+PNL_T),"default",0,0,1,0,0}
End

//	Remove 'prtName' from the list of parent windows of 'chdName'
Static Function pnlResetParent(String prtName, String chdName)
	String newList = RemoveByKey(chdName, GetUserData(prtName, "", KEY), "=")
	SetWindow $prtName userData($KEY)=newList
	if (!ItemsInList(newList))
		SetWindow $prtName hook($KEY)=$""
	endif

	if (SIDAMWindowExists(chdName))
		SetWindow $chdName userData(parent)=""
	endif

	RemoveFromGraph/Z/W=$prtName $(PNL_Y+prtName)
End

Static Function pnlModifyGraph(String pnlName)
	ModifyGraph/W=$pnlName margin(top)=8,margin(right)=8,margin(bottom)=36,margin(left)=44
	ModifyGraph/W=$pnlName tick=0,btlen=5,mirror=0,lblMargin=2, gfSize=10
	ModifyGraph/W=$pnlName rgb=(SIDAM_WINDOW_LINE_R, SIDAM_WINDOW_LINE_G, SIDAM_WINDOW_LINE_B)
	Label/W=$pnlName bottom "\\u"
	Label/W=$pnlName left "\\u"

	if (!CmpStr(StringFromList(1,pnlName,"#"),"line"))
		ModifyWaterfall/W=$pnlName angle=90,axlen=0.5,hidden=0
		ModifyGraph/W=$pnlName noLabel(right)=2,axThick(right)=0
		ModifyGraph/W=$pnlName mode=0,useNegRGB=1,usePlusRGB=1
		GetWindow $pnlName, gbRGB
		ModifyGraph/W=$pnlName negRGB=(V_Red,V_Green,V_Blue),plusRGB=(V_Red,V_Green,V_Blue)
	endif
End

//	Get line spectra
Static Function pnlUpdateLineSpectra(String pnlName)
	STRUCT paramStruct s
	Wave s.w = $GetUserData(pnlName,"","src")
	ControlInfo/W=$pnlName p1V ;	s.p1 = V_Value
	ControlInfo/W=$pnlName q1V ;	s.q1 = V_Value
	ControlInfo/W=$pnlName p2V ;	s.p2 = V_Value
	ControlInfo/W=$pnlName q2V ;	s.q2 = V_Value
	s.output = 1
	s.basename = PNL_W
	s.mode = str2num(GetUserData(pnlName,"","mode"))
	s.dfr = $GetUserData(pnlName,"","dfTmp")
	getLineSpectra(s)

	if (SIDAMisUnevenlySpacedBias(s.w))
		DFREF dfrSav = GetDataFolderDFR()
		SetDataFolder s.dfr
		Duplicate/O SIDAMGetBias(s.w,1) $PNL_B1
		SetDataFolder dfrSav
	endif
End

//	Update the text marker
//	This is called from SIDAMLine#pnlCheck()
Static Function pnlUpdateTextmarker(String pnlName)
	DFREF dfrTmp = $GetUserData(pnlName,"","dfTmp")
	Wave/T/SDFR=dfrTmp tw = $PNL_T

	tw[inf] = ""
	Redimension/N=(DimSize(dfrTmp:$PNL_W,1)) tw
	//	Use !F_flag to put 1 when this is called for the first time
	ControlInfo/W=$pnlName p1C;	tw[0] = SelectString(V_Value|!V_Flag,"","1")
	ControlInfo/W=$pnlName p2C;	tw[inf] = SelectString(V_Value|!V_Flag,"","2")
End

//	Change the color of trace at the cursor
Static Function pnlUpdateColor(String grfName)
	String pnlList = GetUserData(grfName,"",KEY), pnlName
	DFREF dfrTmp
	int i, n, p0, p1

	for (i = 0, n = ItemsInList(pnlList); i < n; i++)
		pnlName = StringFromList(0,StringFromList(i,pnlList),"=")
		if (CmpStr(GetUserData(pnlName,"","highlight"),"1"))
			continue
		endif

		Wave/SDFR=$GetUserData(pnlName,"","dfTmp") w = $PNL_W, clrw = $PNL_C
		Redimension/N=(numpnts(w),3) clrw
		clrw[][0] = SIDAM_WINDOW_LINE_R
		clrw[][1] = SIDAM_WINDOW_LINE_G
		clrw[][2] = SIDAM_WINDOW_LINE_B

		p0 = pcsr(A,grfName)*DimSize(w,0)
		p1 = (pcsr(A,grfName)+1)*DimSize(w,0)-1
		clrw[p0,p1][0] = SIDAM_WINDOW_LINE2_R
		clrw[p0,p1][1] = SIDAM_WINDOW_LINE2_G
		clrw[p0,p1][2] = SIDAM_WINDOW_LINE2_B
	endfor
End


//******************************************************************************
//	Hook functions
//******************************************************************************
//	Hook function for the main panel
Static Function pnlHookArrows(String pnlName)
	pnlUpdateLineSpectra(pnlName)
	pnlUpdateTextmarker(pnlName)
	pnlUpdateColor(GetUserData(pnlName,"","parent"))
End

//	Hook function for the parent window
Static Function pnlHookParent(STRUCT WMWinHookStruct &s)
	String pnlList, pnlName
	int i, n

	if (SIDAMLine#pnlHookParentCheckChild(s.winName,KEY,pnlResetParent))
		return 0
	endif

	switch (s.eventCode)
		case 2:	//	kill
			pnlList = GetUserData(s.winName,"",KEY)
			for (i = 0, n = ItemsInList(pnlList); i < n; i++)
				KillWindow/Z $StringFromList(0,StringFromList(i,pnlList),"=")
			endfor
			return 0

		case 3:	//	mousedown
		case 4:	//	mousemoved
			pnlList = GetUserData(s.winName,"",KEY)
			for (i = 0, n = ItemsInList(pnlList); i < n; i++)
				pnlName = StringFromList(0,StringFromList(i,pnlList),"=")
				SIDAMLine#pnlHookParentMouse(s, pnlName)
				pnlUpdateLineSpectra(pnlName)
				pnlUpdateTextmarker(pnlName)
				DoUpdate/W=$pnlName
			endfor
			pnlUpdateColor(s.winName)
			DoUpdate/W=$s.winName
			return 0

		case 7:	//	cursor moved
			//	If a change occurred for the cursor A
			if (!CmpStr(s.cursorName, "A"))
				pnlUpdateColor(s.winName)
			endif
			return 0

		case 13:	//	renamed
			SIDAMLine#pnlHookParentRename(s,KEY)
			return 0

		default:
			return 0
	endswitch
End


//******************************************************************************
//	Controls for the main panel
//******************************************************************************
//	SetVariable
Static Function pnlSetVar(STRUCT WMSetVariableAction &s)
	//	Handle either enter key or end edit
	if (s.eventCode != 2 && s.eventCode != 8)
		return 1
	endif

	//	Change values of the controls
	SIDAMLine#pnlSetVarUpdateValues(s)

	//	Update the line spectra
	pnlUpdateLineSpectra(s.win)
	pnlUpdateTextmarker(s.win)
	pnlUpdateColor(GetUserData(s.win,"","parent"))
End


//******************************************************************************
//	Menu for right-clike
//******************************************************************************
Menu "SIDAMLineSpectraMenu", dynamic, contextualmenu
	SubMenu "Positions"
		SIDAMLine#menu(0), SIDAMLineSpectra#panelMenuDo(0)
	End
	SubMenu "Dimension"
		SIDAMLine#menu(1), SIDAMLineSpectra#panelMenuDo(1)
	End
	SubMenu "Complex"
		SIDAMLine#menu(2), SIDAMLineSpectra#panelMenuDo(2)
	End
	SubMenu "Sampling mode"
		SIDAMLineSpectra#panelMenu(), SIDAMLineSpectra#panelMenuDo(5)
	End
	SubMenu "Target window"
		SIDAMLine#menuTarget(), SIDAMLineSpectra#panelMenuDo(6)
	End
	SubMenu "Style"
		SIDAMLine#menu(3), SIDAMLineSpectra#panelMenuDo(3)
		SIDAMLine#menu(4), SIDAMLineSpectra#panelMenuDo(4)
	End
	"Save...", SIDAMLineSpectra#outputPnl(WinName(0,1))
	"-"
	SIDAMLine#menu(7),/Q, SIDAMRange(grfName=WinName(0,1)+"#image")
	SIDAMLine#menu(8),/Q, SIDAMColor(grfName=WinName(0,1)+"#image")
End

Static Function/S panelMenu()
	//	Do nothing unless called from pnlHook() in SIDAM_Line.ipf
	String calling = "pnlHook,SIDAM_Line.ipf"
	if (strsearch(GetRTStackInfo(3),calling,0))
		return ""
	endif

	String pnlName = WinName(0,1)
	int mode = str2num(GetUserData(pnlName,"","mode"))
	return SIDAMAddCheckmark(mode, "Raw data;Interpolate;ImageLineProfile")
End

Static Function panelMenuDo(int kind)
	String pnlName = WinName(0,1)
	String grfName = GetUserData(pnlName,"","parent")
	int grid = str2num(GetUserData(pnlName,"","grid"))

	switch (kind)
		case 0:	//	positions
			//	Change values of p1V etc.
			SIDAMLine#menuPositions(pnlName)
			//	Update the line spectra
			pnlUpdateLineSpectra(pnlName)
			pnlUpdateTextmarker(pnlName)
			pnlUpdateColor(grfName)
			break

		case 1:	//	dim
			int dim = str2num(GetUserData(pnlName,"","dim"))
			GetLastUserMenuInfo
			if (V_value != dim)
				SIDAMLine#pnlChangeDim(pnlName, V_value)
			endif
			break

		case 2:	//	complex
			SIDAMLine#menuComplex(pnlName)
			break

		case 3:	//	Free
			//	Change values of p1V etc.
			SIDAMLine#menuFree(pnlName)
			//	Update the line spectra
			pnlUpdateLineSpectra(pnlName)
			pnlUpdateTextmarker(pnlName)
			pnlUpdateColor(grfName)
			break

		case 4:	//	Highlight
			int highlight = str2num(GetUserData(pnlName,"","highlight"))
			SetWindow $pnlname userData(highlight)=num2istr(!highlight)
			String trcName = PNL_Y+GetUserData(pnlName,"","parent")
			if (highlight)
				//	on -> off
				if(!CmpStr(StringByKey("TNAME",CsrInfo(A,grfName)),trcName))
					Cursor/K/W=$grfName A
				endif
				ModifyGraph/W=$(pnlName+"#line") zColor=0
			else
				//	off -> on
				String cmd
				Sprintf cmd, "Cursor/C=%s/S=1/W=%s A %s 0", StringByKey("rgb(x)",TraceInfo(grfName,trcName,0),"="), grfName, trcName
				Execute cmd
				Wave/SDFR=$GetUserData(pnlName,"","dfTmp") clrw = $PNL_C
				ModifyGraph/W=$(pnlName+"#line") zColor={clrw,*,*,directRGB,0}
			endif
			pnlUpdateColor(grfName)
			break

		case 5:	//	sampling mode
			int mode = str2num(GetUserData(pnlName,"","mode"))
			GetLastUserMenuInfo
			if (V_value-1 != mode)
				//	Change the mode
				SetWindow $pnlName userData(mode)=num2istr(V_value-1)
				//	Update the line spectra
				pnlUpdateLineSpectra(pnlName)
				pnlUpdateTextmarker(pnlName)
				pnlUpdateColor(grfName)
			endif
			break

		case 6:	//	target window
			GetLastUserMenuInfo
			pnlResetParent(grfName,pnlName)
			pnlSetParent(StringFromList(V_value-1,GetUserData(pnlName,"","target")), pnlName)
			break

	endswitch
End


//******************************************************************************
//	Sub panel to save a wave
//******************************************************************************
Static Function outputPnl(String profileGrfName)
	if (SIDAMWindowExists(profileGrfName+"#Save"))
		return 0
	endif

	NewPanel/HOST=$profileGrfName/EXT=2/W=(0,0,315,125)/N=Save
	String pnlName = profileGrfName + "#Save"

	DFREF dfrSav = GetDataFolderDFR()
	Wave srcw = $GetUserData(profileGrfName,"","src")
	SetDataFolder GetWavesDataFolderDFR(srcw)
	SetVariable basenameV title="basename:", pos={10,10}, win=$pnlName
	SetVariable basenameV size={290,15}, bodyWidth=230, frame=1, win=$pnlName
	SetVariable basenameV value=_STR:UniqueName("wave",1,0), win=$pnlName
	SetVariable basenameV proc=SIDAMLineSpectra#outputPnlSetVar, win=$pnlName
	SetDataFolder dfrSav

	CheckBox positionC title="save waves of sampling points", pos={10,40}, size={88,14}, value=0, win=$pnlName

	Button doB title="Do It", pos={10,95}, win=$pnlName
	Button closeB title="Close", pos={235,95}, win=$pnlName
	ModifyControlList "doB;closeB" size={70,20}, proc=SIDAMLineSpectra#outputPnlButton, win=$pnlName

	ModifyControlList ControlNameList(pnlName,";","*") focusRing=0, win=$pnlName
End

//******************************************************************************
//	Controls for the sub panel
//******************************************************************************
//	Button
Static Function outputPnlButton(STRUCT WMButtonAction &s)
	if (s.eventCode != 1)
		return 0
	endif

	strswitch (s.ctrlName)
		case "doB":
			outputPnlDo(s.win)
			//*** FALLTHROUGH ***
		case "closeB":
			KillWindow $s.win
			break
		default:
	endswitch

	return 0
End

//	SetVariable
Static Function outputPnlSetVar(STRUCT WMSetVariableAction &s)
	if (s.eventCode == 2 || s.eventCode == 8)
		int chklen = SIDAMValidateSetVariableString(s.win,s.ctrlName,0,maxlength=MAX_OBJ_NAME-3)
		Button doB disable=chklen*2, win=$s.win
	endif
End

Static Function outputPnlDo(String pnlName)
	STRUCT paramStruct s
	
	String parent = StringFromList(0,pnlName,"#")

	Wave s.w = $GetUserData(parent,"","src")
	Wave cvw = SIDAMGetCtrlValues(parent,"p1V;q1V;p2V;q2V")
	s.p1 = cvw[%p1V]
	s.q1 = cvw[%q1V]
	s.p2 = cvw[%p2V]
	s.q2 = cvw[%q2V]
		
	ControlInfo/W=$pnlName basenameV
	s.basename = S_Value
	s.mode = str2num(GetUserData(parent,"","mode"))
	ControlInfo/W=$pnlName positionC
	s.output = V_value

	echo(s)
	SIDAMLineSpectra(s.w, s.p1, s.q1, s.p2, s.q2, basename=s.basename,\
		mode=s.mode, output=s.output)
End

Static Function echo(STRUCT paramStruct &s)
	String paramStr = GetWavesDataFolder(s.w,2) + ","
	paramStr += num2str(s.p1) + "," + num2str(s.q1) + ","
	paramStr += num2str(s.p2) + "," + num2str(s.q2)
	paramStr += SelectString(strlen(s.basename),"",",basename=\""+s.basename+"\"")
	paramStr += SelectString(s.mode, "",",mode="+num2str(s.mode))
	paramStr += SelectString(s.output, "",",output="+num2str(s.output))
	printf "%sSIDAMLineSpectra(%s)\r", PRESTR_CMD, paramStr
End
