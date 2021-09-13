#pragma TextEncoding="UTF-8"
#pragma rtGlobals=1
#pragma ModuleName=SIDAMFourierFilter

#include "SIDAM_Display"
#include "SIDAM_FFT"
#include "SIDAM_InfoBar"
#include "SIDAM_Utilities_Control"
#include "SIDAM_Utilities_Help"
#include "SIDAM_Utilities_Image"
#include "SIDAM_Utilities_Panel"
#include "SIDAM_Utilities_WaveDf"

#ifndef SIDAMshowProc
#pragma hide = 1
#endif

Static StrConstant SUFFIX = "_flt"
Static StrConstant MASKNAME = "SIDAM_mask"
Static StrConstant ORIGINALNAME = "SIDAM_original"
Static StrConstant FOURIERNAME = "SIDAM_fourier"
Static StrConstant FILTEREDNAME = "SIDAM_filtered"

//@
//	Apply Fourier filter.
//
//	## Parameters
//	srcw : wave
//		The input wave, 2D or 3D.
//	paramw : wave
//		The filter parameters.
//	invert : int {0 or !0}, default 0
//		* 0 Pass the filter areas
//		* !0 Cut the filter areas
//	endeffect : int {1 -- 3}, default 1
//		How to handle the ends of the wave.
//		* 0: Bounce. Uses `w[i]` in place of the missing `w[-i]` and `w[n-i]` in place of the missing `w[n+i]`.
//		* 1: Wrap. Uses `w[n-i]` in place of the missing `w[-i]` and vice-versa.
//		* 2: Zero (default). Uses 0 for any missing value.
//		* 3: Repeat. Uses `w[0]` in place of the missing `w[-i]` and `w[n]` in place of the missing `w[n+i]`.
//
//	## Returns
//	wave
//		Filtered wave.
//@
Function/WAVE SIDAMFilter(Wave/Z srcw, Wave/Z paramw,
	[int invert, int endeffect])
	
	STRUCT paramStruct s
	Wave/Z s.srcw = srcw
	Wave/Z s.pw = paramw
	s.invert = ParamIsDefault(invert) ? 0 : invert
	s.endeffect = ParamIsDefault(endeffect) ? 1 : endeffect
	
	if (validate(s))
		print s.errMsg
		return $""
	endif
	
	Wave/WAVE ww = applyFilter(srcw, paramw, s.invert, s.endeffect)
	return ww[0]
End

Static Function validate(STRUCT paramStruct &s)
	
	s.errMsg = PRESTR_CAUTION + "SIDAMFilter gave error: "
	
	int flag = SIDAMValidateWaveforFFT(s.srcw)
	if (flag)
		s.errMsg += SIDAMValidateWaveforFFTMsg(flag)
		return 1
	endif
	
	if (!WaveExists(s.pw))
		s.errMsg += "the parameter wave is not found."
		return 1
	elseif (DimSize(s.pw,0) != 7)
		s.errMsg += "the size of parameter wave is incorrect."
		return 1
	endif
	
	WaveStats/Q/M=1 s.pw
	if (V_numNaNs || V_numINFs)
		s.errMsg += "the parameter wave must not contain NaN or INF."
		return 1
	endif
	
	if (validateParameterRange(s.pw, s.srcw))
		s.errMsg += "a parameter(s) is out of range."
		return 1
	endif
	
	s.invert = s.invert ? 1 : 0
	s.endeffect = limit(s.endeffect, 0, 3)
	
	return 0
End

Static Function validateParameterRange(Wave pw, Wave srcw)
	
	Make/N=(DimSize(pw,1))/FREE tw
	Make/N=10/FREE tw2
	tw = pw[0][p] ;	tw2[0] = DimSize(srcw,0)-1-WaveMax(tw) ; 	tw2[1] = WaveMin(tw)
	tw = pw[1][p] ;	tw2[2] = DimSize(srcw,1)-1-WaveMax(tw) ; 	tw2[3] = WaveMin(tw)
	tw = pw[3][p] ;	tw2[4] = DimSize(srcw,0)-1-WaveMax(tw) ; 	tw2[5] = WaveMin(tw)
	tw = pw[4][p] ;	tw2[6] = DimSize(srcw,1)-1-WaveMax(tw) ; 	tw2[7] = WaveMin(tw)
	tw = pw[2][p] ;	tw2[8] = WaveMin(tw)
	tw = pw[5][p] ;	tw2[9] = WaveMin(tw)
	
	return (WaveMin(tw2) < 0)
End

Static Structure paramStruct
	String	errMsg
	Wave	srcw
	Wave	pw
	uchar	invert
	uchar	endeffect
EndStructure

Static Function/S echoStr(Wave srcw, Wave paramw, String result,
		int invert, int endeffect)
	String paramStr = GetWavesDataFolder(srcw,2)
	paramStr += "," + SelectString(WaveType(paramw,2)==2, \
		GetWavesDataFolder(paramw,2), SIDAMWaveToString(paramw, noquote=1))
	paramStr += SelectString(CmpStr(NameOfWave(srcw)+SUFFIX,result), \
		"", ",result=\""+result+"\"")
	paramStr += SelectString(invert, "", ",invert="+num2str(invert))
	paramStr += SelectString(endeffect==1, ",endeffect="+num2str(endeffect), "")
	Sprintf paramStr, "Duplicate/O SIDAMFilter(%s), %s%s", paramStr\
		, GetWavesDataFolder(srcw, 1), PossiblyQuoteName(result)
	return paramStr
End

//	Apply a filter
//	Return both mask and resultant waves so that this function
//	can be used from the panel
Static Function/WAVE applyFilter(Wave srcw, Wave paramw, int invert,
	int endeffect)
	
	int nx = DimSize(srcw,0), ny = DimSize(srcw,1), nz = DimSize(srcw,2)
	int dim = WaveDims(srcw), i
	
	if (endeffect == 1)		//	wrap
		Wave tsrcw = srcw
	else
		Wave tsrcw = SIDAMEndEffect(srcw,endeffect)
	endif
	
	//	modify the parameters dependeing on the end effect
	Duplicate/FREE paramw tparamw
	if (endeffect != 1)
		Variable cp = nx/2-1, cq = floor(ny/2)
		Variable cp2 = nx*3/2-1, cq2 = floor(ny*3/2)
		tparamw[0][] = cp2 + (paramw[0][q]-cp)*3
		tparamw[1][] = cq2 + (paramw[1][q]-cq)*3
		tparamw[3][] = cp2 + (paramw[3][q]-cp)*3
		tparamw[4][] = cq2 + (paramw[4][q]-cq)*3
		tparamw[6][] = paramw[6][q]*3
	endif
	
	Wave maskw = makeMask(tsrcw, tparamw, invert)
	
	//	do filtering
	if (dim == 2)
		MatrixOP/FREE/C flt2Dw = fft(tsrcw,0)*maskw
		IFFT/FREE flt2Dw
		Note flt2Dw, SIDAMWaveToString(paramw, noquote=1)
		CopyScales tsrcw, flt2Dw
	else
		Make/N=(nz)/FREE/WAVE ww
		MultiThread ww = applyFilterHelper(tsrcw, p, maskw)
		Duplicate/FREE tsrcw, flt3Dw
		for (i = 0; i < nz; i++)
			Wave tw = ww[i]
			MultiThread flt3Dw[][][i] = tw[p][q]
		endfor
	endif
	
	//	finalize waves dependeing on the end effect
	if (endeffect == 1)
		if (dim == 2)
			Make/N=2/FREE/WAVE rww = {flt2Dw, maskw}
		else
			Make/N=2/FREE/WAVE rww = {flt3Dw, maskw}
		endif
	else
		if (dim == 2)
			Duplicate/FREE/R=[nx, 2*nx-1][ny, 2*ny-1] flt2Dw, fw
		else
			Duplicate/FREE/R=[nx, 2*nx-1][ny, 2*ny-1][] flt3Dw, fw
		endif
		Duplicate/FREE/R=[,nx/2+1][ny,2*ny-1] maskw mw
		mw = maskw(x*3)(y*3)
		Make/N=2/FREE/WAVE rww = {fw, mw}
	endif
	
	return rww
End

ThreadSafe Static Function/WAVE applyFilterHelper(Wave srcw, Variable index, Wave maskw)
	MatrixOP/FREE/C filteredw = fft(srcw[][][index],0)*maskw
	IFFT/FREE filteredw
	return filteredw
End

Static Function/WAVE makeMask(
	Wave w,			//	real space wave
	Wave paramw,		//	p0, q0, n0, p1, q1, n1, r
	Variable invert
	)
	
	Variable nx = DimSize(w,0), ny = DimSize(w,1)
	Variable dx = 1 / (DimDelta(w,0)*DimSize(w,0)), dy = 1 / (DimDelta(w,1)*DimSize(w,1))
	Variable ox = (1-DimSize(w,0)/2) / (DimDelta(w,0)*DimSize(w,0)), oy = -1 / (DimDelta(w,1)*2)
	Variable x0, y0, x1, y1, xc, yc, radius
	int n0, n1
	int i, j, n
	
	//	Make a list of center positions
	Make/N=(0,3)/FREE lw
	for (i = 0; i < DimSize(paramw,1); i++)
		radius = paramw[6][i]*sqrt(dx^2+dy^2)
		if (radius <= 0)	
			continue
		endif
		for (n0 = -paramw[2][i]; n0 <= paramw[2][i]; n0++)
			for (n1 = -paramw[5][i]; n1 <= paramw[5][i]; n1++)
				if (!n0 && !n1)
					continue
				endif
				n = DimSize(lw,0)
				Redimension/N=(n+1,-1) lw
				x0 = ox + dx*paramw[0][i]
				y0 = oy + dy*paramw[1][i]
				x1 = ox + dx*paramw[3][i] 
				y1 = oy + dy*paramw[4][i]
				lw[n][0] = x0*n0 + x1*n1
				lw[n][1] = y0*n0 + y1*n1
				lw[n][2] = radius
			endfor
		endfor
	endfor
	
	//	Remove duplicated centers if any
	for (i = DimSize(lw,0)-1; i >= 0; i--)
		for (j = i - 1; j >= 0; j--)
			if (lw[i][0] == lw[j][0] && lw[i][1] == lw[j][1])
				DeletePoints/M=0 i, 1, lw
				break
			endif
		endfor
	endfor
	
	Make/N=(nx/2+1,ny)/FREE maskw=0
	SetScale/P x 0, dx, "", maskw
	SetScale/P y oy, dy, "", maskw
	Make/N=(DimSize(lw,0))/WAVE/FREE ww
	
	//	This is a time-consuming part
	MultiThread ww = makeMaskHelper(maskw, lw, p)
	
	for (i = 0; i < numpnts(ww); i++)
		Wave tw = ww[i]
		FastOP maskw = maskw + tw
	endfor
	
	Variable v = WaveMax(maskw)
	if (invert)
		FastOP maskw = 1 - (1/v) * maskw
	else
		FastOP maskw = (1/v) * maskw
	endif
	
	return maskw
End

ThreadSafe Static Function/WAVE makeMaskHelper(Wave maskw, Wave lw, int index)
	
	Make/N=(DimSize(maskw,0), DimSize(maskw,1))/FREE rtnw
	CopyScales maskw, rtnw
	
	Variable a = lw[index][0], b = lw[index][1], c = -ln(2)/lw[index][2]^2
	rtnw = ((x-a)^2+(y-b)^2)*c
	MatrixOP/O rtnw = exp(rtnw)
	
	return rtnw
End

Static Function menuDo()
	pnl(SIDAMImageWaveRef(WinName(0,1)), WinName(0,1))
End


//******************************************************************************
//	show a panel
//******************************************************************************
Static Function pnl(Wave w, String grfName)
	
	String pnlName = SIDAMNewPanel("Fourier filter ("+NameOfWave(w)+")",\
		680, 370, resizable=1)	//	680=10+320+10+340, 370=40+320+10
	AutoPositionWindow/E/M=0/R=$grfName $pnlName

	String dfTmp = pnlInit(pnlName, w)
	SetWindow $pnlName hook(self)=SIDAMFourierFilter#pnlHook
	SetWindow $pnlName userData(dfTmp)=dfTmp
	SetWindow $pnlName userData(src)=GetWavesDataFolder(w,2), activeChildFrame=0
	
	TabControl mTab pos={1,1}, size={338,368}, proc=SIDAMTabControlProc, win=$pnlName
	TabControl mTab tabLabel(0)="original", tabLabel(1)="filtered", tabLabel(2)="FFT", value=2, win=$pnlName
	
	TitleBox pqT pos={15,24}, frame=0, win=$pnlName
	TitleBox xyT pos={15,24}, frame=0, win=$pnlName
	TitleBox zT pos={15,24}, frame=0, win=$pnlName
	
	DefineGuide/W=$pnlName CTL={FR,-335}, CTT={FB,-220}
	NewPanel/FG=(CTL,FT,FR,CTT)/HOST=$pnlName
	RenameWindow $pnlName#$S_name, table
	ModifyPanel/W=$pnlName#table frameStyle=0
	
	ListBox filL pos={0,18}, size={330,120}, frame=2, mode=5, selRow=-1, win=$pnlName#table
	ListBox filL listWave=$(dfTmp+SIDAM_WAVE_LIST), selWave=$(dfTmp+SIDAM_WAVE_SELECTED), win=$pnlName#table
	
	NewPanel/FG=(CTL,CTT,FR,FB)/HOST=$pnlName
	RenameWindow $pnlName#$S_name, controls
	ModifyPanel/W=$pnlName#controls frameStyle=0
	
	GroupBox filterG title="filter", pos={0,0}, size={190,115}, win=$pnlName#controls
	Button addB title="Add", pos={6,22}, size={60,20}, win=$pnlName#controls
	TitleBox addT title="new filter", pos={76,26}, frame=0, win=$pnlName#controls
	Button deleteB title="Delete", pos={6,53}, size={60,20}, disable=2, win=$pnlName#controls
	TitleBox deleteT title="selected filter", pos={76,57}, frame=0, disable=2, win=$pnlName#controls
	Button applyB title="Apply", pos={6,84}, size={60,20}, disable=2, win=$pnlName#controls
	PopupMenu invertP title="", pos={76,84}, size={70,20}, bodyWidth=70, disable=2, win=$pnlName#controls
	PopupMenu invertP mode=1, value= #"\"pass;stop\"", userData="1", proc=SIDAMFourierFilter#pnlPopup, win=$pnlName#controls
	TitleBox applyT title="filter", pos={156,88}, frame=0, disable=2, win=$pnlName#controls
	
	GroupBox maskG title="mask", pos={200,0}, size={130,115}, disable=2, win=$pnlName#controls
	TitleBox maskT title="color and opacity", pos={210,26}, size={88,12}, frame=0, disable=2, win=$pnlName#controls
	PopupMenu colorP pos={211,53}, size={50,20} ,mode=1, proc=SIDAMFourierFilter#pnlPopup, disable=2, win=$pnlName#controls
	PopupMenu colorP popColor= (65535,65535,65535),value= #"\"*COLORPOP*\"", win=$pnlName#controls
	Slider opacityS pos={211,85}, size={100,19}, limits={0,255,1} ,value=192, vert=0, ticks=0, proc=SIDAMFourierFilter#pnlSlider, disable=2, win=$pnlName#controls
	
	PopupMenu endP title="end effect", pos={20,129}, size={165,20}, bodyWidth=110, disable=2, proc=SIDAMFourierFilter#pnlPopup, win=$pnlName#controls
	PopupMenu endP mode=2, popvalue="wrap", value= #"\"bounce;wrap (none);zero;repeat\"", userData="2", win=$pnlName#controls
	TitleBox endT title="this takes longer time", pos={196,133}, disable=1, frame=0, win=$pnlName#controls
	SetVariable nameV title="output name", pos={8,161}, size={317,16}, bodyWidth=250, proc=SIDAMFourierFilter#pnlSetVar, disable=2, win=$pnlName#controls
	SetVariable nameV value= _STR:(NameOfWave(w)[0,30-strlen(SUFFIX)]+SUFFIX), win=$pnlName#controls
	
	Button saveB title="Save", pos={6,192}, size={60,20}, disable=2, win=$pnlName#controls
	CheckBox displayC title="display", pos={75,195}, disable=2, win=$pnlName#controls
	PopupMenu toP title="To", pos={163,192}, size={60,20}, bodyWidth=60, disable=2, win=$pnlName#controls
	PopupMenu toP value="Cmd Line;Clip", mode=0, proc=SIDAMFourierFilter#pnlPopup, win=$pnlName#controls
	Button helpB title="?", pos={231,192}, size={30,20}, win=$pnlName#controls
	Button closeB title="Close", pos={269,192}, size={60,20}, win=$pnlName#controls
	
	ModifyControlList ControlNameList(pnlName+"#controls",";","*B") proc=SIDAMFourierFilter#pnlButton, win=$pnlName#controls
	ModifyControlList ControlNameList(pnlName+"#controls",";","*") focusRing=0, win=$pnlName#controls
	
	//	image area
	DefineGuide/W=$pnlName IMGL={FL,9}, IMGT={FT,41}, IMGR={FR,-351}, IMGB={FB,-9}
		//	original
	Display/FG=(IMGL, IMGT, IMGR, IMGB)/HOST=$pnlName/HIDE=1
	RenameWindow $pnlName#$S_name, original
	SetWindow $pnlName#original userData(tab)="0"
	AppendImage/W=$pnlName#original $(dfTmp+ORIGINALNAME)
	ModifyGraph/W=$pnlName#original noLabel=2, axThick=0, standoff=0, margin=1
		//	filtered
	Display/FG=(IMGL, IMGT, IMGR, IMGB)/HOST=$pnlName/HIDE=1
	RenameWindow $pnlName#$S_name, filtered
	SetWindow $pnlName#filtered userData(tab)="1"
	AppendImage/W=$pnlName#filtered $(dfTmp+FILTEREDNAME)
	ModifyGraph/W=$pnlName#filtered noLabel=2, axThick=0, standoff=0, margin=1
		//	FFT
	Display/FG=(IMGL, IMGT, IMGR, IMGB)/HOST=$pnlName
	RenameWindow $pnlName#$S_name, fourier
	SetWindow $pnlName#fourier userData(tab)="2"
	AppendImage/W=$pnlName#fourier $(dfTmp+FOURIERNAME)
	AppendImage/W=$pnlName#fourier $(dfTmp+MASKNAME)
	ModifyGraph/W=$pnlName#fourier noLabel=2, axThick=0, standoff=0, margin=1
	ModifyImage/W=$pnlName#fourier $FOURIERNAME ctab= {*,WaveMax($(dfTmp+FOURIERNAME))*0.1,Terrain,0}
	
	SetWindow $pnlName#original hide=0
	SetWindow $pnlName#filtered hide=0
	SetActiveSubWindow $pnlName
	SIDAMInitializeTab(pnlName,"mTab")
End

Static Function/S pnlInit(String pnlName, Wave w)
	DFREF dfrSav = GetDataFolderDFR()
	String dfTmp = SIDAMNewDF(pnlName,"SIDAMFilterPnl")
	SetDataFolder $dfTmp
	
	//	the original wave
	if (WaveDims(w)==2)
		Duplicate w $ORIGINALNAME/WAVE=ow
	else
		Duplicate/R=[][][0] w $ORIGINALNAME/WAVE=ow
		Redimension/N=(-1,-1) ow
	endif
	
	//	the resultant wave after filtering
	Duplicate ow $FILTEREDNAME
	
	//	FFT wave
	SetDataFolder $dfTmp
	Duplicate/O SIDAMFFT(ow,win="Hanning",out=3,subtract=1), $FOURIERNAME
	
	//	wave for the list
	Make/N=(0,7)/T $SIDAM_WAVE_LIST/WAVE=listw
	Make/N=(0,7) $SIDAM_WAVE_SELECTED
	Make/N=7/T/FREE labelw = {"p0","q0","n0","p1","q1","n1","HWHM"}
	int i
	for (i = 0; i < 7; i++)
		SetDimLabel 1, i, $(labelw[i]), listw
	endfor
	
	//	The dependency to pick up a change in the list
	Variable/G dummy
	String str
	Sprintf str, "SIDAMFourierFilter#pnlListChange(%s,\"%s\")", dfTmp+SIDAM_WAVE_LIST, pnlName
	SetFormula dummy, str
	
	//	wave for showing the mask
	Make/B/U/N=(DimSize(w,0),DimSize(w,1),4) $MASKNAME/WAVE=maskw
	maskw[][][,2] = 255
	maskw[][][3] = 0
	CopyScales $FOURIERNAME maskw
	
	SetDataFolder dfrSav
	return dfTmp
End

Static Function pnlHook(STRUCT WMWinHookStruct &s)
	switch (s.eventCode)
		case 2:	//	kill
			SIDAMKillDataFolder($GetUserData(s.winName, "", "dfTmp"))
			break
		case 4:	//	mousemoved
			if (strlen(ImageNameList(s.winName,";")))		//	only for subwindows showing a graph
				SIDAMInfobarUpdatePos(s, win=StringFromList(0, s.winName, "#"))
			endif
			break
		case 5:	//	mouseup
			if (strlen(ImageNameList(s.winName,";")))		//	only for subwindows showing a graph
				pnlHookMouseup(s)
			endif
			break
		case 6:	//	resize
			Variable tabSize = s.winRect.right-340-2
			TabControl mTab size={tabSize,tabSize+40}, win=$s.winName
			ListBox filL size={330,tabSize+42-250}, win=$s.winName#table
			GetWindow $s.winName wsize
			MoveWindow/W=$s.winName V_left, V_top, V_right, V_top+(tabSize+42)*72/screenresolution
			break
		case 11:	//	keyboard
			if (s.keycode == 27)	//	esc
				SIDAMKillDataFolder($GetUserData(s.winName, "", "dfTmp"))
				KillWindow $s.winName
			endif
			break
	endswitch
	
	return 0
End

//	Behavior when click, put numbers to the list
Static Function pnlHookMouseup(STRUCT WMWinHookStruct &s)
	//	get the position of the mouse cursor
	STRUCT SIDAMMousePos ms
	if (SIDAMGetMousePos(ms, s.winName, s.mouseLoc, grid=1))
		return 1
	endif
	
	String pnlName = StringFromList(0, s.winName, "#")
	SetActiveSubWindow $pnlName
	Wave/SDFR=$GetUserData(pnlName,"","dfTmp") selw = $SIDAM_WAVE_SELECTED
	Wave/SDFR=$GetUserData(pnlName,"","dfTmp")/T listw = $SIDAM_WAVE_LIST
	if (!DimSize(selw,0))
		return 0
	endif
	WaveStats/Q/M=1 selw
	if (!(V_max & 1))	//	no cell is selected
		return 0
	endif
	
	switch(V_maxColLoc)
		case 0:
		case 1:
			listw[V_maxRowLoc][0] = num2str(ms.p)
			listw[V_maxRowLoc][1] = num2str(ms.q)
			break
		case 3:
		case 4:
			listw[V_maxRowLoc][3] = num2str(ms.p)
			listw[V_maxRowLoc][4] = num2str(ms.q)
			break
		default:	//	2, 5, 6
			return 0
	endswitch
	listw[V_maxRowLoc][2] = "1"
	if (!strlen(listw[V_maxRowLoc][6]))
		listw[V_maxRowLoc][6] =  "1"
	endif
	selw[V_maxRowLoc][V_maxColLoc] -= 1	//	unselect
End

//******************************************************************************
//	Controls
//******************************************************************************
//	Popup
Static Function pnlPopup(STRUCT WMPopupAction &s)
	if (s.eventCode != 2)
		return 1
	endif
	
	String pnlName = StringFromList(0,s.win,"#")
	DFREF dfrTmp = $GetUserData(pnlName,"","dfTmp")
	
	strswitch (s.ctrlName)
		case "colorP":
			Variable red, green, blue
			sscanf s.popStr, "(%d,%d,%d)", red, green, blue
			red = round(red/256) ;	green = round(green/256) ;	blue = round(blue/256)
			Wave/SDFR=dfrTmp maskw = $MASKNAME
			MultiThread maskw[][][0] = red
			MultiThread maskw[][][1] = green
			MultiThread maskw[][][2] = blue
			break
			
		case "toP":
			Wave srcw = $GetUserData(pnlName,"","src")
			Wave/T/SDFR=dfrTmp listw = $SIDAM_WAVE_LIST
			Make/N=(7,DimSize(listw,0))/FREE paramw = strlen(listw[q][p]) ? str2num(listw[q][p]) : 0
			ControlInfo/W=$s.win nameV ;		String result = S_Value
			ControlInfo/W=$s.win invertP ;	Variable invert = V_Value==2
			ControlInfo/W=$s.win endP ;		Variable endeffect = V_Value-1
			String paramStr = echoStr(srcw, paramw, result, invert, endeffect)
			SIDAMPopupTo(s, paramStr)
			break
			
		case "endP":
			TitleBox endT disable=(s.popNum == 2), win=$s.win
			//*** FALLTHROUGH ***
		case "invertP":
			if (s.popNum != str2num(GetUserData(s.win, s.ctrlName, "")))
				pnlUpdate(s.win, 1)
				PopupMenu $s.ctrlName userData=num2str(s.popNum), win=$s.win
			endif
			break
	endswitch
End

//	Slider
Static Function pnlSlider(STRUCT WMSliderAction &s)
	if (s.eventCode == 4)
		Wave/SDFR=$GetUserData(StringFromList(0,s.win,"#"),"","dfTmp") maskw = $MASKNAME
		ImageStats/M=1/P=3 maskw
		Variable v = V_max*s.curval
		MultiThread maskw[][][3] = round(maskw[p][q][3]/v)
	endif
End

//	SetVariable
Static Function pnlSetVar(STRUCT WMSetVariableAction &s)
	//	Handle either enter key or end edit
	if (s.eventCode != 2 && s.eventCode != 8)
		return 1
	endif
	
	Variable disable = SIDAMValidateSetVariableString(s.win,s.ctrlName,0)
	pnlUpdate(s.win, disable)
End

//	Button
Static Function pnlButton(STRUCT WMButtonAction &s)	
	if (s.eventCode != 2)
		return 0
	endif
	
	String pnlName = StringFromList(0,s.win,"#")
	DFREF dfrTmp = $GetUserData(pnlName,"","dfTmp")
	Wave/T/SDFR=dfrTmp listw = $SIDAM_WAVE_LIST
	Wave/SDFR=dfrTmp selw = $SIDAM_WAVE_SELECTED
	int n = DimSize(selw,0)
	
	strswitch(s.ctrlName)
		case "addB":
			Redimension/N=(n+1,-1) listw, selw
			selw[n][] = 2
			selw[n][0] += 1	//	selected
			pnlUpdate(s.win, 1)
			break
		
		case "deleteB":
			WaveStats/Q/M=1 selw
			if (V_max & 1)	//	if there is a selected cell
				if (n > 1)
					//	pnlUpdate() will be called by making this change to selw
					DeletePoints/M=0 V_maxRowLoc, 1, listw, selw
				else
					Redimension/N=(0,-1) listw, selw
					pnlUpdate(s.win, 2)
				endif
			endif
			break
		
		case "applyB":
			pnlButtonApply(s, dfrTmp, listw)
			break
		
		case "saveB":
			pnlButtonSave(s, dfrTmp, listw)
			break
			
		case "helpB":
			SIDAMOpenHelpNote("filter", pnlName, "Fourier Filter")
			break
		
		case "closeB":
			KillWindow $pnlName
			break
	endswitch
End

//******************************************************************************
//	Helper functions for controls
//******************************************************************************
//	for the apply button
Static Function pnlButtonApply(STRUCT WMButtonAction &s, DFREF dfrTmp, Wave/T listw)	
	if (s.eventCode != 2)
		return 0
	endif
	
	if (!DimSize(listw,0))	//	no filter
		return 0
	endif
	
	Wave/SDFR=dfrTmp ow=$ORIGINALNAME, maskw=$MASKNAME
	
	//	Construct a parameter wave from the list
	Make/N=(7,DimSize(listw,0))/FREE paramw = strlen(listw[q][p]) ? str2num(listw[q][p]) : 0
	if (validateParameterRange(paramw, ow))
		DoAlert 0, "a paremeter(s) is out of range"
		return 1
	endif
	
	pnlUpdate(s.win, 3)
	
	ControlInfo/W=$s.win invertP ;	int invert = V_Value==2
	ControlInfo/W=$s.win endP ;		int endeffect = V_Value-1
	Wave/WAVE ww = applyFilter(ow, paramw, invert, endeffect)
	
	//	Create a mask wave for the display
	Wave mw = ww[1]
	Variable nx = DimSize(ow,0), ny = DimSize(ow,1)
	ControlInfo/W=$s.win opacityS
	MultiThread maskw[nx/2-1,][][3] = round((1-mw[p-nx/2+1][q])*V_Value)
	MultiThread maskw[,nx/2-2][][3] = maskw[nx-1-p][ny-1-q]
	
	Duplicate/O ww[0] dfrTmp:$FILTEREDNAME
	
	pnlUpdate(s.win, 0)
End

//	for the save button
Static Function pnlButtonSave(STRUCT WMButtonAction &s, DFREF dfrTmp, Wave/T listw)
	if (s.eventCode != 2)
		return 0
	endif
	
	String pnlName = StringFromList(0,s.win,"#")
	Wave srcw = $GetUserData(pnlName,"","src")
	
	Make/N=(7,DimSize(listw,0))/FREE paramw = strlen(listw[q][p]) ? str2num(listw[q][p]) : 0
	
	Wave cvw = SIDAMGetCtrlValues(s.win, "invertP;endP;displayC")
	Variable invert = cvw[%invertP]==2, endeffect = cvw[%endP] - 1
	ControlInfo/W=$s.win nameV
	String result = S_Value
	
	printf "%s%s\r", PRESTR_CMD, echoStr(srcw, paramw, result, invert, endeffect)
	if (WaveDims(srcw) == 2)
		//	Recalculation is not necessary for 2D.
		//	Duplicate the existing result and echo the command string.
		DFREF dfr = GetWavesDataFolderDFR(srcw)
		Duplicate/O dfrTmp:$FILTEREDNAME dfr:$result/WAVE=resw
	else
		//	Recalulate the whole range for 3D.
		pnlUpdate(s.win, 3)
		DFREF dfr = GetWavesDataFolderDFR(srcw)
		Duplicate/O SIDAMFilter(srcw, paramw, invert=invert, \
			endeffect=endeffect) dfr:$result/WAVE=resw
		pnlUpdate(s.win, 0)
	endif
	
	if (cvw[%displayC])
		SIDAMDisplay(resw, history=1)
	endif
End

//	A dependency function
Static Function pnlListChange(Wave/T w, String pnlName)
	//	Do nothing at initialization and when the selw is empty by the deleteB
	if (DimSize(w,0))
		pnlUpdate(pnlName+"#controls", 1)
	endif
	return 0
End

//	0: all controls can be selected
//	1: "save" and "display" can not be selected
//	2: "add", "help", "close" can be selected
//	3: no controls can be selected
Static Function pnlUpdate(String pnlName, int state)
	
	GroupBox filterG disable=(state==3)*2, win=$pnlName
	Button addB disable=(state==3)*2, win=$pnlName
	TitleBox addT disable=(state==3)*2, win=$pnlName
	
	Button deleteB disable=(state>=2)*2, win=$pnlName
	TitleBox deleteT disable=(state>=2)*2, win=$pnlName
	Button applyB disable=(state>=2)*2, win=$pnlName
	PopupMenu invertP disable=(state>=2)*2, win=$pnlName
	TitleBox applyT disable=(state>=2)*2, win=$pnlName
	
	GroupBox maskG disable=(state>=2)*2, win=$pnlName
	TitleBox maskT disable=(state>=2)*2, win=$pnlName
	PopupMenu colorP disable=(state>=2)*2, win=$pnlName
	Slider opacityS disable=(state>=2)*2, win=$pnlName
	
	PopupMenu endP disable=(state>=2)*2, win=$pnlName
	SetVariable nameV disable=(state>=2)*2, win=$pnlName
	
	Button saveB disable=(state>=1)*2, win=$pnlName
	CheckBox displayC disable=(state>=1)*2, win=$pnlName
	
	PopupMenu toP disable=(state>=2)*2, win=$pnlName
	Button helpB disable=(state==3)*2, win=$pnlName
	Button closeB disable=(state==3)*2, win=$pnlName
	
	ControlInfo/W=$pnlName endT
	if (V_disable==0)
		TitleBox endT disable=(state>=2)*2, win=$pnlName
	endif
	
	ControlUpdate/A/W=$pnlName
End
