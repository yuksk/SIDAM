#pragma TextEncoding="UTF-8"
#pragma rtGlobals=3
#pragma ModuleName = SIDAMLineProfile

#include "SIDAM_Color"
#include "SIDAM_Help"
#include "SIDAM_Line"
#include "SIDAM_Range"
#include "SIDAM_Utilities_Bias"
#include "SIDAM_Utilities_Control"
#include "SIDAM_Utilities_Image"
#include "SIDAM_Utilities_Panel"
#include "SIDAM_Utilities_WaveDf"

#ifndef SIDAMshowProc
#pragma hide = 1
#endif

Static StrConstant SUFFIX_X = "X"
Static StrConstant SUFFIX_Y = "Y"
Static StrConstant SUFFIX_SDEV = "Stdv"

Static StrConstant PROF_1D_NAME = "W_ImageLineProfile"
Static StrConstant PROF_X_NAME = "W_LineProfileX"
Static StrConstant PROF_Y_NAME = "W_LineProfileY"
Static StrConstant STDV_1D_NAME = "W_LineProfileStdv"
Static StrConstant PROF_2D_NAME = "M_ImageLineProfile"
Static StrConstant STDV_2D_NAME = "M_LineProfileStdv"

Static StrConstant PNL_W = "W_SIDAMLineProfile"
Static StrConstant PNL_C = "W_SIDAMLineProfileC"
Static StrConstant PNL_B1 = "W_SIDAMLineProfile_b"
Static StrConstant PNL_B2 = "W_SIDAMLineProfile_y"
Static StrConstant PNL_X = "W_SIDAMLineProfileX"
Static StrConstant PNL_Y = "W_SIDAMLineProfileY"
Static StrConstant PNL_T = "W_SIDAMLineProfileT"

Static StrConstant KEY = "SIDAMLineProfile"

//@
//	Get a line profile of a wave along a trajectory line.
//
//	## Parameters
//	w : wave
//		The input wave, 2D or 3D.
//	p1, q1 : variable
//		The position of the starting point (pixel).
//	p2, q2 : variable
//		The position of the ending point (pixel).
//	width : variable, default 0
//		The width (diameter) of the line profile in pixels.
//		This is the same as the width parameter of `ImageLineProfile`.
//	output : int, default 0
//		Specify waves saved in addition to the profile wave.
//		- bit 0: save waves of positions.
//		- bit 1: save wave of standard deviation when the width > 0.
//	basename : string, default ""
//		Name of the line profile wave and basename of additional waves
//		(when the output > 0). If this is specified, output waves are
//		save in the data folder where the input wave is.
//
//	## Returns
//	wave
//		Line profile.
//@
Function/WAVE SIDAMLineProfile(Wave/Z w, Variable p1, Variable q1, Variable p2,
	Variable q2, [Variable width,	 int output, String basename])

	STRUCT paramStruct s
	Wave/Z s.w = w
	s.p1 = p1
	s.q1 = q1
	s.p2 = p2
	s.q2 = q2
	s.basename = SelectString(ParamIsDefault(basename), basename, "")
	s.width = ParamIsDefault(width) ? 0 : width
	s.output = ParamIsDefault(output) ? 0 : output
	s.dfr = GetWavesDataFolderDFR(s.w)

	if (validate(s))
		print s.errMsg
		return $""
	endif

	return getLineProfile(s)
End

Static Function validate(STRUCT paramStruct &s)

	s.errMsg = PRESTR_CAUTION + "SIDAMLineProfile gave error: "

	if (!WaveExists(s.w))
		s.errMsg += "wave not found."
		return 1
	elseif (WaveDims(s.w) != 2 && WaveDims(s.w) != 3)
		s.errMsg += "the dimension of input wave must be 2 or 3."
		return 1
	endif

	if ((WaveDims(s.w) == 2 && strlen(s.basename) > MAX_OBJ_NAME) || \
			(WaveDims(s.w) == 3 && strlen(s.basename) > MAX_OBJ_NAME-3))
		s.errMsg += "length of name for output wave exceeds the limit ("\
			+num2istr(MAX_OBJ_NAME)+" characters)."
		return 1
	endif

	if (numtype(s.p1) || numtype(s.q1) || numtype(s.p2) || numtype(s.q2))
		s.errMsg += "coordinate must be a normal number."
		return 1
	endif

	if (s.width < 0)
		s.errMsg += "width must be positive."
		return 1
	endif

	if (s.output > 3)
		s.errMsg += "output must be an integer between 0 and 3."
		return 1
	endif

	return 0
End

Static Structure paramStruct
	Wave	w
	String	errMsg
	double	p1
	double	p2
	double	q1
	double	q2
	double	width
	uchar	output
	String	basename
	DFREF dfr
EndStructure

Static Function menuDo()
	String grfName = WinName(0,1), imgName = StringFromList(0, ImageNameList(grfName, ";"))
	pnl(grfName, imgName)
End


//******************************************************************************
//	Line profile
//******************************************************************************
Static Function/WAVE getLineProfile(STRUCT paramStruct &s)

	int i
	DFREF dfrSav = GetDataFolderDFR(), dfr = s.dfr
	SetDataFolder NewFreeDataFolder()

	Variable ox = DimOffset(s.w,0), oy = DimOffset(s.w,1)
	Variable dx = DimDelta(s.w,0), dy = DimDelta(s.w,1)
	Make/D/N=2 xw = {ox+dx*s.p1, ox+dx*s.p2}, yw = {oy+dy*s.q1, oy+dy*s.q2}

	int isComplex =  WaveType(s.w) & 0x01
	if (isComplex)
		MatrixOP/FREE realw = real(s.w)
		MatrixOP/FREE imagw = imag(s.w)
		Copyscales s.w, realw, imagw
	endif

	//	2D & complex
	if (WaveDims(s.w)==2 && isComplex)
		//	real
		SetDataFolder NewFreeDataFolder()
		ImageLineProfile/S/SC xWave=xw, yWave=yw, srcwave=realw, width=s.width
		Wave linew0 = $PROF_1D_NAME, sdevw0 = $STDV_1D_NAME
		//	imaginary
		SetDataFolder NewFreeDataFolder()
		ImageLineProfile/S/SC xWave=xw, yWave=yw, srcwave=imagw, width=s.width
		Wave linew1 = $PROF_1D_NAME, sdevw1 = $STDV_1D_NAME
		//	combine them in complex
		MatrixOP/C linew = cmplx(linew0,linew1)
		MatrixOP/C sdevw = cmplx(sdevw0,sdevw1)

		scalingLineProfile(s,linew,sdevw)
		if (strlen(s.basename) > 0)
			Duplicate/O linew dfr:$s.basename/WAVE=rtnw
			if (s.output&2)
				Duplicate/O sdevw dfr:$(s.basename+SUFFIX_SDEV)
			endif
		else
			Wave rtnw = linew
		endif

	//	2D & real
	elseif (WaveDims(s.w)==2)
		ImageLineProfile/S/SC xWave=xw, yWave=yw, srcwave=s.w, width=s.width

		scalingLineProfile(s,$PROF_1D_NAME,$STDV_1D_NAME)
		if (strlen(s.basename) > 0)
			Duplicate/O $PROF_1D_NAME dfr:$s.basename/WAVE=rtnw
			if (s.output&2)
				Duplicate/O $STDV_1D_NAME dfr:$(s.basename+SUFFIX_SDEV)
			endif
		else
			Wave rtnw = $PROF_1D_NAME
		endif

	//	3D & complex
	elseif (WaveDims(s.w)==3 && isComplex)
		//	real
		SetDataFolder NewFreeDataFolder()
		ImageLineProfile/S/SC/P=-2 xWave=xw, yWave=yw, srcwave=realw, width=s.width
		Wave linew0 = $PROF_2D_NAME, sdevw0 = $STDV_2D_NAME
		//	imaginary
		SetDataFolder NewFreeDataFolder()
		ImageLineProfile/S/SC/P=-2 xWave=xw, yWave=yw, srcwave=imagw, width=s.width
		Wave linew1 = $PROF_2D_NAME, sdevw1 = $STDV_2D_NAME
		//	combine them in complex
		MatrixOP/C linew = cmplx(linew0,linew1)
		MatrixOP/C sdevw = cmplx(sdevw0,sdevw1)

		scalingLineProfile(s, linew, sdevw)
		Wave rtnw = outputLineProfileWaves(s, linew, sdevw)

	//	3D & real
	elseif (WaveDims(s.w)==3)
		ImageLineProfile/S/SC/P=-2 xWave=xw, yWave=yw, srcwave=s.w, width=s.width
		scalingLineProfile(s, $PROF_2D_NAME, $STDV_2D_NAME)
		Wave rtnw = outputLineProfileWaves(s, $PROF_2D_NAME, $STDV_2D_NAME)
	endif

	//	Save waves for sampling points
	if (s.output&1)
		Wave posxw = $PROF_X_NAME, posyw = $PROF_Y_NAME
		SetScale d 0, 0, StringByKey("DUNITS", WaveInfo(s.w,0)), posxw
		SetScale d 0, 0, StringByKey("DUNITS", WaveInfo(s.w,1)), posyw
		Duplicate/O posxw dfr:$(s.basename+SUFFIX_X)
		Duplicate/O posyw dfr:$(s.basename+SUFFIX_Y)
	endif

	SetDataFolder dfrSav
	return rtnw
End

//	scaling and note
Static Function scalingLineProfile(STRUCT paramStruct &s, Wave linew, Wave sdevw)
	
	if (s.p1 == s.p2)
		Setscale/I x IndexToScale(s.w,s.q1,1), IndexToScale(s.w,s.q2,1)\
			, WaveUnits(s.w,1), linew, sdevw
	elseif (s.q1 == s.q2)
		Setscale/I x IndexToScale(s.w,s.p1,0), IndexToScale(s.w,s.p2,0)\
			, WaveUnits(s.w,0), linew, sdevw
	else
		Variable distance = sqrt((s.p1-s.p2)^2*DimDelta(s.w,0)^2+(s.q1-s.q2)^2*DimDelta(s.w,1)^2)
		SetScale/I x 0, distance, WaveUnits(s.w,0), linew, sdevw
	endif
	
	SetScale d 0, 0, StringByKey("DUNITS", WaveInfo(s.w,0)), linew, sdevw
	if (WaveDims(s.w)==3)
		SetScale/P y DimOffset(s.w,2), DimDelta(s.w,2), WaveUnits(s.w,2), linew, sdevw
	endif

	String noteStr
	Sprintf noteStr, "src@%s;start@p=%.2f,q=%.2f;end@p=%.2f,q=%.2f;width=%.2f"\
		, GetWavesDataFolder(s.w, 2), s.p1, s.q1, s.p2, s.q2, s.width
	Note linew, noteStr
	Note sdevw, noteStr
End

Static Function/WAVE outputLineProfileWaves(STRUCT paramStruct &s,
		Wave linew, Wave sdevw)
		
	if (strlen(s.basename) > 0)
		DFREF dfr = s.dfr
		Duplicate/O linew dfr:$s.basename/WAVE=rtnw
		if (SIDAMisUnevenlySpacedBias(s.w))
			Duplicate/O SIDAMGetBias(s.w,1) dfr:$(s.basename+"_b")
			Duplicate/O SIDAMGetBias(s.w,2) dfr:$(s.basename+"_y")
		endif
		if (s.output & 2)
			Duplicate/O $STDV_2D_NAME dfr:$(s.basename+SUFFIX_SDEV)
		endif
		return rtnw
	else
		return linew
	endif
End


//******************************************************************************
//	Show the main panel
//******************************************************************************
Static Function pnl(String grfName, String imgName)
	if (SIDAMWindowExists(GetUserData(grfName,"",KEY)))
		DoWindow/F $GetUserData(grfName,"",KEY)
		return 0
	endif

	DFREF dfrSav = GetDataFolderDFR()
	String dfTmp = SIDAMNewDF(grfName,"LineProfile")
	SetDataFolder $dfTmp

	Make/N=(1,1)/O $PNL_W
	Make/N=(1,3)/O $PNL_C
	Make/T/N=2/O $PNL_T = {"1","2"}

	Wave w = SIDAMImageNameToWaveRef(grfName)
	int i

	NewPanel/K=1/W=(0,0,288,340) as "Line Profile"
	String pnlName = S_name
	AutoPositionWindow/E/M=0/R=$grfName $pnlName

	SetWindow $grfName hook($KEY)=SIDAMLineProfile#pnlHookParent
	SetWindow $grfName userData($KEY)=pnlName+"="+dfTmp
	SetWindow $pnlName hook(self)=SIDAMLine#pnlHook, userData(parent)=grfName
	SetWindow $pnlName userData(src)=GetWavesDataFolder(w,2)
	SetWindow $pnlName userData(grid)="1"
	SetWindow $pnlName userData(key)=KEY
	SetWindow $pnlName userData(dfTmp)=dfTmp
	if (WaveDims(w)==3)
		SetWindow $pnlName userData(dim)="1"
		SetWindow $pnlName userData(highlight)="1"
	endif

	SIDAMLine#pnlCtrls(pnlName, "SIDAMLineProfileMenu")
	SetVariable widthV title="w:", pos={195,4}, size={86,18}, format="%.2f", win=$pnlName
	SetVariable widthV limits={0,inf,0.1}, value=_NUM:0, bodyWidth=70, win=$pnlName
	SIDAMApplyHelpStrings(pnlName, "widthV", "Enter the width in pixels in a direction "\
		+ "perpendicular to the path. See the help of ImageLineProfile for the details.")
	ModifyControlList "p1V;q1V;p2V;q2V;distanceV;angleV;widthV" proc=SIDAMLineProfile#pnlSetVar, win=$pnlName
	ModifyControlList ControlNameList(pnlName,";","*") focusRing=0, win=$pnlName

	//	Get line profiles for the default values
	pnlUpdateLineProfile(pnlName)
	pnlUpdateTextmarker(pnlName)

	//	For the waterfall plot
	if (WaveDims(w)==2)
		Display/FG=(FL,SIDAMFT,FR,FB)/HOST=$pnlName/N=line $PNL_W
	elseif (SIDAMisUnevenlySpacedBias(w))
		Newwaterfall/FG=(FL,SIDAMFT,FR,FB)/HOST=$pnlName/N=line $PNL_W vs {*, $PNL_B1}
	else
		Newwaterfall/FG=(FL,SIDAMFT,FR,FB)/HOST=$pnlName/N=line $PNL_W
	endif
	pnlStyle(pnlName+"#line")
	pnlUpdatePos(pnlName+"#line")
	pnlUpdateColor(pnlName)
	
	//	For the image plot
	if (WaveDims(w)==3)
		Display/FG=(FL,SIDAMFT,FR,FB)/HOST=$pnlName/N=image/HIDE=1
		if (SIDAMisUnevenlySpacedBias(w))
			AppendImage/W=$pnlName#image $PNL_W vs {*, $PNL_B2}
		else
			AppendImage/W=$pnlName#image $PNL_W
		endif
		pnlStyle(pnlName+"#image")
	endif
	SetActiveSubWindow $pnlName

	//	Show a line and text markers on the parent window
	AppendToGraph/W=$grfName $PNL_Y vs $PNL_X
	ModifyGraph/W=$grfName mode($PNL_Y)=4,msize($PNL_Y)=5
	ModifyGraph/W=$grfName textMarker($PNL_Y)={$PNL_T,"default",0,0,1,0,0}

	SetDataFolder dfrSav
End

Static Function pnlStyle(String plotArea)

	ModifyGraph/W=$plotArea margin(top)=10,margin(right)=10,margin(bottom)=40,margin(left)=48
	ModifyGraph/W=$plotArea tick=0,btlen=5,mirror=0,lblMargin=2, gfSize=12
	ModifyGraph/W=$plotArea rgb=(SIDAM_WINDOW_LINE_R, SIDAM_WINDOW_LINE_G, SIDAM_WINDOW_LINE_B)
	Label/W=$plotArea bottom "Scaling Distance (\\u\M)"
	Label/W=$plotArea left "\\u"

	String pnlName = StringFromList(0,plotArea,"#")
	int is3D = WaveDims($GetUserData(pnlName,"","src")) == 3
	if (!CmpStr(StringFromList(1,plotArea,"#"),"line") && is3D)
		ModifyWaterfall/W=$plotArea angle=90,axlen=0.5,hidden=0
		ModifyGraph/W=$plotArea noLabel(right)=2,axThick(right)=0
		ModifyGraph/W=$plotArea mode=0,useNegRGB=1,usePlusRGB=1
		GetWindow $plotArea, gbRGB
		ModifyGraph/W=$plotArea negRGB=(V_Red,V_Green,V_Blue),plusRGB=(V_Red,V_Green,V_Blue)
		//	The default value of the highlight is 1
		Wave/SDFR=$GetUserData(pnlName,"","dfTmp") clrw = $PNL_C
		ModifyGraph/W=$plotArea zColor={clrw,*,*,directRGB,0}
	endif
End

Static Function pnlUpdatePos(String pnlName)
	Wave/SDFR=$GetUserData(StringFromList(0,pnlName,"#"),"","dfTmp") w = $PNL_W
	String strL = SelectString(DimDelta(w,0)>0, "pos 2", "pos 1")
	String strR = SelectString(DimDelta(w,0)>0, "pos 1", "pos 2")

	SetDrawLayer/W=$pnlName ProgBack
	DrawAction/L=ProgBack/W=$pnlName getgroup=$KEY, delete
	SetDrawEnv/W=$pnlName gname=$KEY, gstart
	
	SetDrawEnv/W=$pnlName textrgb=(SIDAM_WINDOW_NOTE_R, SIDAM_WINDOW_NOTE_G, SIDAM_WINDOW_NOTE_B)
	SetDrawEnv/W=$pnlName xcoord=rel, ycoord=rel, fstyle=2, fsize=12
	DrawText/W=$pnlName 0.03, 0.99, strL
	
	SetDrawEnv/W=$pnlName textrgb=(SIDAM_WINDOW_NOTE_R, SIDAM_WINDOW_NOTE_G, SIDAM_WINDOW_NOTE_B)
	SetDrawEnv/W=$pnlName xcoord=rel, ycoord=rel, textxjust=2, fstyle=2, fsize=12
	DrawText/W=$pnlName 0.97, 0.99, strR
	
	SetDrawEnv/W=$pnlName gstop
	SetDrawLayer/W=$pnlName UserFront
End

//	Get line profiles
Static Function pnlUpdateLineProfile(String pnlName)
	STRUCT paramStruct s
	Wave s.w = $GetUserData(pnlName,"","src")
	ControlInfo/W=$pnlName p1V ;	s.p1 = V_Value
	ControlInfo/W=$pnlName q1V ;	s.q1 = V_Value
	ControlInfo/W=$pnlName p2V ;	s.p2 = V_Value
	ControlInfo/W=$pnlName q2V ;	s.q2 = V_Value
	ControlInfo/W=$pnlName widthV ;	s.width = V_Value
	s.output = 5
	s.basename = PNL_W
	s.dfr = $GetUserData(pnlName,"","dfTmp")
	getLineProfile(s)
End

//	Update the text marker
//	This is called from SIDAMLine#pnlCheck()
Static Function pnlUpdateTextmarker(String pnlName)
	DFREF dfrTmp = $GetUserData(pnlName,"","dfTmp")
	Wave/T/SDFR=dfrTmp tw = $PNL_T

	tw[inf] = ""
	Redimension/N=(numpnts(dfrTmp:$PNL_X)) tw
	//	Use !F_flag to put 1 when this is called for the first time
	ControlInfo/W=$pnlName p1C;	tw[0] = SelectString(V_Value|!V_Flag,"","1")
	ControlInfo/W=$pnlName p2C;	tw[inf] = SelectString(V_Value|!V_Flag,"","2")
End

//	Change the color of line profile corresponding to the displayed
//	layer when a 3D wave is shown.
Static Function pnlUpdateColor(String pnlName)
	String grfName = StringFromList(0,GetUserData(pnlName,"","parent"))
	if (WaveDims(SIDAMImageNameToWaveRef(grfName))==2)
		return 0
	elseif (CmpStr(GetUserData(pnlName,"","highlight"),"1"))
		return 0
	endif

	Wave/SDFR=$GetUserData(pnlName,"","dfTmp") w = $PNL_W, clrw = $PNL_C
	Redimension/N=(numpnts(w),3) clrw
	clrw[][0] = SIDAM_WINDOW_LINE_R
	clrw[][1] = SIDAM_WINDOW_LINE_G
	clrw[][2] = SIDAM_WINDOW_LINE_B

	int layer = SIDAMGetLayerIndex(grfName)
	int p0 = layer*DimSize(w,0)
	int p1 = (layer+1)*DimSize(w,0)-1
	clrw[p0,p1][0] = SIDAM_WINDOW_LINE2_R
	clrw[p0,p1][1] = SIDAM_WINDOW_LINE2_G
	clrw[p0,p1][2] = SIDAM_WINDOW_LINE2_B
End


//******************************************************************************
//	Hook functions
//******************************************************************************
//	Hook function for the main panel
Static Function pnlHookArrows(String pnlName)
	pnlUpdateLineProfile(pnlName)
	pnlUpdateTextmarker(pnlName)
	pnlUpdateColor(pnlName)
	pnlUpdatePos(pnlName)
End

//	Hook function for the parent window
Static Function pnlHookParent(STRUCT WMWinHookStruct &s)
	if (SIDAMLine#pnlHookParentCheckChild(s.winName,KEY,pnlResetParent))
		return 0
	endif

	String pnlName = StringFromList(0,GetUserData(s.winName,"",KEY),"=")
	switch (s.eventCode)
		case 2:	//	kill
			KillWindow/Z $pnlName
			return 0

		case 3:	//	mousedown
		case 4:	//	mousemoved
			SIDAMLine#pnlHookParentMouse(s, pnlName)
			if (!strlen(GetUserData(pnlName,"","clicked")))
				return 0
			endif
			//*** FALLTHROUGH ***
		case 8:	//	modified
			pnlUpdateLineProfile(pnlName)
			pnlUpdateTextmarker(pnlName)
			pnlUpdateColor(pnlName)
			pnlUpdatePos(pnlName)
			DoUpdate/W=$pnlName
			DoUpdate/W=$s.winName
			return 0

		case 13:	//	renamed
			SIDAMLine#pnlHookParentRename(s,KEY)
			return 0

		default:
			return 0
	endswitch
End

Static Function pnlResetParent(String grfName, String dummy)
	SetWindow $grfName hook($KEY)=$"",userdata($KEY)=""
End

//******************************************************************************
//	Controls for the main panel
//******************************************************************************
//	SetVariable
Static Function pnlSetVar(STRUCT WMSetVariableAction &s)
	//	Handle either mouse up or enter key
	if (s.eventCode != 1 && s.eventCode != 2)
		return 1
	endif

	//	Change values of the controls
	SIDAMLine#pnlSetVarUpdateValues(s)

	//	Update the line profiles
	pnlUpdateLineProfile(s.win)
	pnlUpdateTextmarker(s.win)
	pnlUpdateColor(s.win)
	pnlUpdatePos(s.win)
End


//******************************************************************************
//	Menu
//******************************************************************************
Menu "SIDAMLineProfileMenu", dynamic, contextualmenu
	SubMenu "Positions"
		SIDAMLine#menu(0), SIDAMLineProfile#panelMenuDo(0)
	End
	SubMenu "Dimension"
		SIDAMLine#menu(1), SIDAMLineProfile#panelMenuDo(1)
	End
	SubMenu "Complex"
		SIDAMLine#menu(2), SIDAMLineProfile#panelMenuDo(2)
	End
	SubMenu "Style"
		SIDAMLine#menu(3), SIDAMLineProfile#panelMenuDo(3)
		SIDAMLine#menu(4), SIDAMLineProfile#panelMenuDo(4)
	End
	"Save...", SIDAMLineProfile#outputPnl(WinName(0,64))
	"-"
	SIDAMLine#menu(7),/Q, SIDAMRange(grfName=WinName(0,64)+"#image")
	SIDAMLine#menu(8),/Q, SIDAMColor(grfName=WinName(0,64)+"#image")
End

Static Function panelMenuDo(int mode)
	String pnlName = WinName(0,64)
	int grid = str2num(GetUserData(pnlName,"","grid"))

	switch (mode)
		case 0:	//	positions
			//	Change values of p1V etc.
			SIDAMLine#menuPositions(pnlName)
			//	Update the line profiles
			pnlUpdateLineProfile(pnlName)
			pnlUpdateTextmarker(pnlName)
			pnlUpdateColor(pnlName)
			pnlUpdatePos(pnlName)
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
			//	Update the line profiles
			pnlUpdateLineProfile(pnlName)
			pnlUpdateTextmarker(pnlName)
			pnlUpdateColor(pnlName)
			pnlUpdatePos(pnlName)
			break

		case 4:	//	Highlight
			int highlight = str2num(GetUserData(pnlName,"","highlight"))
			SetWindow $pnlname userData(highlight)=num2istr(!highlight)

			if (highlight)
				//	on -> off
				ModifyGraph/W=$(pnlName+"#line") zColor=0
			else
				//	off -> on
				Wave/SDFR=$GetUserData(pnlName,"","dfTmp") clrw = $PNL_C
				ModifyGraph/W=$(pnlName+"#line") zColor={clrw,*,*,directRGB,0}
				pnlUpdateColor(pnlName)
			endif
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

	ControlInfo/W=$profileGrfName widthV
	Variable width = V_Value

	NewPanel/HOST=$profileGrfName/EXT=2/W=(0,0,315,125)/N=Save
	String pnlName = profileGrfName + "#Save"

	DFREF dfrSav = GetDataFolderDFR()
	Wave srcw = $GetUserData(profileGrfName,"","src")
	SetDataFolder GetWavesDataFolderDFR(srcw)
	SetVariable basenameV title="basename:", pos={10,10}, win=$pnlName
	SetVariable basenameV size={290,15}, bodyWidth=230, frame=1, win=$pnlName
	SetVariable basenameV value=_STR:UniqueName("wave",1,0), win=$pnlName
	SetVariable basenameV proc=SIDAMLineProfile#outputPnlSetVar, win=$pnlName
	SetDataFolder dfrSav

	CheckBox positionC title="save waves of sampling points", win=$pnlName
	CheckBox positionC pos={10,40}, size={88,14}, value=0, win=$pnlName
	//	sdevC can not be selected if width is 0
	CheckBox sdevC title="save wave of standard deviation", win=$pnlName
	CheckBox sdevC pos={10,64}, size={300,14}, value=0, disable=(!width)*2, win=$pnlName

	Button doB title="Do It", pos={10,95}, win=$pnlName
	Button closeB title="Close", pos={235,95}, win=$pnlName
	ModifyControlList "doB;closeB" size={70,20}, proc=SIDAMLineProfile#outputPnlButton, win=$pnlName

	ModifyControlList ControlNameList(pnlName,";","*") focusRing=0, win=$pnlName
End

//******************************************************************************
//	Controls for the sub panel
//******************************************************************************
//	Button
Static Function outputPnlButton(STRUCT WMButtonAction &s)
	if (s.eventCode != 2)
		return 0
	endif

	strswitch (s.ctrlName)
		case "doB":
			outputPnlDo(s.win)
			//*** FALLTHROUGH ***
		case "closeB":
			KillWindow $(s.win)
			break
		default:
	endswitch

	return 0
End

//	SetVariable
Static Function outputPnlSetVar(STRUCT WMSetVariableAction &s)
	//	Handle either enter key or end edit
	if (s.eventCode != 2 && s.eventCode != 8)
		return 1
	endif

	String grfName = GetUserData(StringFromList(0, s.win, "#"),"","parent")
	Wave w = SIDAMImageNameToWaveRef(grfName)
	int maxlength = (WaveDims(w)==3) ? MAX_OBJ_NAME-3 : MAX_OBJ_NAME
	int isProperLength = !SIDAMValidateSetVariableString(s.win,s.ctrlName,0,maxlength=maxlength)
	Button doB disable=(!isProperLength)*2, win=$s.win
End

Static Function outputPnlDo(String pnlName)
	STRUCT paramStruct s

	String prtName = StringFromList(0, pnlName, "#")
	Wave cvw0 = SIDAMGetCtrlValues(pnlName,"positionC;sdevC")
	s.output = cvw0[%positionC]+cvw0[%sdevC]*2
	ControlInfo/W=$pnlName basenameV
	s.basename = S_Value

	Wave cvw1 = SIDAMGetCtrlValues(prtName,"p1V;q1V;p2V;q2V;widthV")
	Wave s.w = $GetUserData(prtName,"","src")
	s.p1 = cvw1[%p1V]
	s.q1 = cvw1[%q1V]
	s.p2 = cvw1[%p2V]
	s.q2 = cvw1[%q2V]
	s.width = cvw1[%widthV]

	echo(s)
	SIDAMLineProfile(s.w, s.p1, s.q1, s.p2, s.q2, basename=s.basename,\
		width=s.width, output=s.output)
End

Static Function echo(STRUCT paramStruct &s)
	String paramStr = GetWavesDataFolder(s.w,2) + ","
	paramStr += num2str(s.p1) + "," + num2str(s.q1) + ","
	paramStr += num2str(s.p2) + "," + num2str(s.q2)
	paramStr += SelectString(strlen(s.basename),"",",basename=\""+s.basename+"\"")
	paramStr += SelectString(s.width, "",",width="+num2str(s.width))
	paramStr += SelectString(s.output, "",",output="+num2str(s.output))
	printf "%sSIDAMLineProfile(%s)\r", PRESTR_CMD, paramStr
End
