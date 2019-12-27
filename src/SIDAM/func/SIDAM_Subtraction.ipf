#pragma TextEncoding="UTF-8"
#pragma rtGlobals=3
#pragma ModuleName = SIDAMSubtraction

#ifndef SIDAMshowProc
#pragma hide = 1
#endif

Static StrConstant MODE = "Plane;Line;Layer;Phase;Exp;Log;"

//******************************************************************************
///	SIDAMSubtraction
///	@param w
///		A numeric wave, 2D or 3D
///	@param roi [optional, default = {{0,0},{DimSize(w,0)-1,DimSize(w,1)-1}}
///		A 2x2 wave specifying the corners of a rectanglar ROI
///	@param mode [optional, default = 0]
///		0: plane, 1: line, 2: layer, 3: phase, 4: exp, 5: log
///	@param order [optional, default = 1 for mode=0, 0 for mode=1]
///		The order of a subtracted plane/lines
///	@param direction [optional, default = 0]
///		The direction of subtraction for mode=1 (0: row, 1: column), or
///		scan for mode=4 and 5
///	@param method [optional, default = 0]
///		0 or 1. Set 1 to subtract the median from each line instaed of
///		the average for mode=1 (line).
///	@param index [optional, default = 0]
///		The layer index for mode=2 and 3
///	@param history [optional, default = 0]
///		0 or !0. Set !0 to print this command in the history.
///	@param result [optional, default = ""]
///		The name of result wave. When empty, the input wave is overwritten.
///	@return
///		A result wave
//******************************************************************************
Function/WAVE SIDAMSubtraction(Wave/Z w, [Wave roi, int mode, int order,
	int direction, int method, int index, int history, String result])

	STRUCT paramStruct s
	Wave/Z s.w = w
	s.mode = ParamIsDefault(mode) ? 0 : mode
	s.order = ParamIsDefault(order) ? !s.mode : order	//	1 for mode=0(plane)
	s.direction = ParamIsDefault(direction) ? 0 : direction
	s.method = ParamIsDefault(method) ? 0 : method
	s.index = ParamIsDefault(index) ? 0 : index
	s.result = SelectString(ParamIsDefault(result), result, "")
	if (ParamIsDefault(roi))
		Make/B/U/FREE tw = {{0,0},{DimSize(s.w,0)-1,DimSize(s.w,1)-1}}		//	whole area
		Wave s.roi = tw
	else
		Wave/Z s.roi = roi
	endif

	if (validate(s))
		printf "%s%s gave error: %s\r", PRESTR_CAUTION, GetRTStackInfo(1), s.errMsg
		return $""
	endif

	if (!ParamIsDefault(history) && history == 1)
		print PRESTR_CMD + echoStr(s)
	endif

	//	each function returns a free wave
	switch (mode)
		case 0:
			if (s.order < 2)
				Wave resw = subtract_plane(s.w, s.roi, s.order)
			else
				Wave resw = subtract_poly(s.w, s.roi, s.order)
			endif
			break
		case 1:
			if (s.order > 0 && !s.method)
				Wave resw = subtract_line_poly(s.w, s.order, s.direction)
			elseif (!s.order && !s.method)
				Wave resw = subtract_line_constant(s.w, s.direction)
			elseif (!s.order && s.method==1)
				Wave resw = subtract_line_median_constant(s.w, s.direction)
			elseif (s.order==1 && s.method==1)
				Wave resw = subtract_line_median_slope(s.w, s.direction)
			elseif (s.order==2 && s.method==1)
				Wave resw = subtract_line_median_curvature(s.w, s.direction)
			endif
			break
		case 2:
			Wave resw = subtract_layer(s.w, s.index)
			break
		case 3:
			Wave resw = subtract_phase(s.w, s.index)
			break
		case 4:
			Wave resw = KMExpLogSubtraction(s.w, s.order, s.direction)
			break
		case 5:
			Wave resw = KMExpLogSubtraction(s.w, 2, s.direction)
			break
	endswitch

	if (strlen(result))
		DFREF dfr = GetWavesDataFolderDFR(w)
		Duplicate/O resw dfr:$result
		return dfr:$result
	else
		w = resw
		return w
	endif
End

Static Function validate(STRUCT paramStruct &s)

	s.errMsg = ""

	//	about wave
	if (!WaveExists(s.w))
		s.errMsg = "wave not found."
		return 1
	elseif (WaveDims(s.w) != 2 && WaveDims(s.w) != 3)
		s.errMsg = "dimension of input wave must be 2 or 3."
		return 1
	elseif (WaveType(s.w,1) != 1)
		s.errMsg = "input wave must be numeric"
		return 1
	endif

	//	roi
	if (!WaveExists(s.roi))
		s.errMsg = "roi wave not found."
		return 1
	elseif (DimSize(s.roi,0) != 2 || DimSize(s.roi,1) != 2)
		s.errMsg = "roi wave has wrong size"
		return 1
	elseif (s.roi[0][0] < 0 || s.roi[1][0] < 0 \
			|| s.roi[0][1] >= DimSize(s.w,0) || s.roi[1][1] >= DimSize(s.w,1))
		s.errMsg = "roi wave is out of range"
		return 1
	endif

	int isComplex = WaveType(s.w) & 0x01
	int is2D = WaveDims(s.w) == 2
	int is3D = WaveDims(s.w) == 3

	//	mode
	switch (s.mode)
		case 0:	//	plane, poly
			if (isComplex)
				s.errMsg = "mode 0 is available for a real wave."
			endif
			break

		case 1:	//	line
			if (isComplex)
				s.errMsg = "mode 2 is available for a real wave."
			elseif (s.order > 2)
				s.errMsg = "order must be 0-2 for mode 1."
			elseif (s.direction != 0 && s.direction != 1)
				s.errMsg = "direction must be 0 or 1 for mode 1."
			elseif (s.method != 0 && s.method != 1)
				s.errMsg = "method must be 0 or 1."
			endif
			break

		case 2:	//	layer
			if (!is3D)
				s.errMsg = "mode 3 is available for a 3D wave"
			elseif (s.index < 0 || s.index >= DimSize(s.w,2))
				s.errMsg = "index is out of range."
			endif
			break

		case 3:	//	phase
			if (!is3D || !isComplex)
				s.errMsg = "mode 3 is available for a complex 3D wave"
			elseif (s.index < 0 || s.index >= DimSize(s.w,2))
				s.errMsg = "index is out of range."
			endif
			break

		case 4:
			if (!is2D || isComplex)
				s.errMsg = "mode 4 is available for a real 2D wave."
			elseif (s.order != 0 && s.order != 1)
				s.errMsg = "order must be 0 or 1 for mode 4."
			elseif (s.direction<0 || s.direction>7)
				s.errMsg = "direction must be from 0 to 7 for mode 4"
			endif
			break

		case 5:
			if (!is2D || isComplex)
				s.errMsg = "mode 5 is available for a real 2D wave."
			endif
			break

		default:
			s.errMsg = "mode must be an integer between 0 and 5."

	endswitch
	if (strlen(s.errMsg))
		return 1
	endif

	//	result
	if (strlen(s.result) > MAX_OBJ_NAME)
		s.errMsg = "length of name for output wave will exceed the limit (" \
			+ num2istr(MAX_OBJ_NAME) + " characters)."
		return 1
	endif

	return 0
End

Static Structure paramStruct
	Wave	w
	Wave	roi
	String	errMsg
	uchar	mode
	uchar	order
	uchar	direction
	uchar	method
	uint16	index
	String	result
EndStructure

Static Function/S echoStr(STRUCT paramStruct &s)

	String paramStr = GetWavesDataFolder(s.w,2)
	paramStr += SelectString(s.mode, "", ",mode="+num2istr(s.mode))
	switch (s.mode)
		case 0:
			paramStr += SelectString(s.order==1, ",order="+num2istr(s.order), "")
			if (!WaveExists(s.roi))
				break
			endif
			Make/B/U/FREE tw = {{0,0},{DimSize(s.w,0)-1,DimSize(s.w,1)-1}}
			if (!equalWaves(s.roi,tw,1))
				paramStr += ",roi="+SIDAMWaveToString(s.roi)
			endif
			break

		case 1:
			paramStr += SelectString(s.order, "", ",order="+num2istr(s.order))
			paramStr += SelectString(s.direction, "", ",direction="+num2istr(s.direction))
			paramStr += SelectString(s.method, "", ",method="+num2istr(s.method))
			break

		case 2:
		case 3:
			paramStr += SelectString(s.index, "", ",index="+num2istr(s.index))
			break

		case 4:
		case 5:
			paramStr += SelectString(s.order, "", ",order="+num2istr(s.order))
			paramStr += SelectString(s.direction, "", ",direction="+num2istr(s.direction))
			break
	endswitch

	paramStr += SelectString(strlen(s.result) && CmpStr(s.result,NameOfWave(s.w)), "", ",result=\""+s.result+"\"")
	Sprintf paramStr, "SIDAMSubtraction(%s)", paramStr

	return paramStr
End

//-------------------------------------------------------------
//	Menu functions
//-------------------------------------------------------------
Static Function menuDo()
	String grfName = WinName(0,4311,1)
	Wave/Z w = KMGetImageWaveRef(grfName)
	if (WaveExists(w))
		pnl(w, grfName)
	endif
End

Static Function marqueeDo()
	SIDAMSubtraction(KMGetImageWaveRef(WinName(0,1,1)),roi=SIDAMGetMarquee(0),history=1)
End

Static Function/S marqueeMenu()
	Wave/Z w = KMGetImageWaveRef(WinName(0,1,1))
	if (WaveExists(w) && WaveDims(w) == 2)
		return "1st-order plane subtraction about this region"
	else
		return ""
	endif
End


//******************************************************************************
//	Panel
//******************************************************************************
Static Function pnl(Wave w, String grfName)

	NewPanel/EXT=0/HOST=$grfName/W=(0,0,328,195)/N=Subtraction
	String pnlName = grfName+"#Subtraction"

	SetWindow $pnlName userData(src)=GetWavesDataFolder(w,2)
	int isComplex = (WaveType(w) & 0x01)
	int is2D = (WaveDims(w) == 2)
	int nx = DimSize(w,0), ny = DimSize(w,1)

	SetVariable resultV title="output name:", pos={10,10}, size={308,16}, win=$pnlName
	SetVariable resultV value=_STR:NameOfWave(w), bodyWidth=239, disable=2, win=$pnlName
	SetVariable resultV frame=1, proc=SIDAMSubtraction#pnlSetVar, win=$pnlName
	CheckBox owC title="overwrite source", pos={79,36}, value=1, win=$pnlName
	CheckBox owC proc=SIDAMSubtraction#pnlCheck, win=$pnlName

	PopupMenu modeP title="mode:", pos={46,68}, size={114,21}, bodyWidth=80, win=$pnlName
	if (isComplex)
		PopupMenu modeP mode=1, value="Layer;Phase", win=$pnlName
	elseif (is2D)
		PopupMenu modeP mode=1, value="Plane;Line;Exp;Log", win=$pnlName
	else
		PopupMenu modeP mode=1, value="Plane;Line;Layer", win=$pnlName
	endif
	PopupMenu orderP title="order:", pos={193,68}, size={94,20}, bodyWidth=60, win=$pnlName
	PopupMenu orderP mode=2, value="0;1;2;3;4;5;6;7", disable=isComplex, win=$pnlName
	PopupMenu directionP title="direction:", pos={32,99}, size={128,20}, win=$pnlName
	PopupMenu directionP bodyWidth=80, mode=1, value="\u21c4;\u21c5", disable=1, win=$pnlName
	PopupMenu methodP title="method:", pos={180,99},size={137,19}, disable=1, win=$pnlName
	PopupMenu methodP mode=1, value="least squares;median", bodyWidth=90, win=$pnlName

	CheckBox roiC title="roi", pos={80,102}, disable=(!is2D||isComplex), win=$pnlName
	CheckBox roiC value=0, proc=SIDAMSubtraction#pnlCheck, win=$pnlName
	SetVariable p1V title="p1:", pos={129,100}, value=_NUM:0, limits={0,nx-1,1},win=$pnlName
	SetVariable q1V title="q1:", pos={129,122}, value=_NUM:0, limits={0,ny-1,1},win=$pnlName
	SetVariable p2V title="p2:", pos={222,100}, value=_NUM:nx-1, limits={0,nx-1,1},win=$pnlName
	SetVariable q2V title="q2:", pos={222,122}, value=_NUM:ny-1, limits={0,ny-1,1}, win=$pnlName
	ModifyControlList "p1V;q1V;p2V;q2V" size={73,16}, bodyWidth=55, disable=1, win=$pnlName

	SetVariable indexV title="index:", pos={211,68}, size={92,16}, bodyWidth=60, win=$pnlName
	SetVariable indexV disable=!isComplex, proc=SIDAMSubtraction#pnlSetVar, win=$pnlName
	SetVariable indexV value=_NUM:0, limits={0,DimSize(w,2)-1,1}, win=$pnlName
	String titleStr
	sprintf titleStr, "%.2f (%s)", DimOffset(w,2), WaveUnits(w,2)
	TitleBox valueT title=titleStr, pos={211,97}, win=$pnlName
	TitleBox valueT frame=0, disable=!isComplex, win=$pnlName

	PopupMenu expP title="exp:", pos={57,99}, size={103,20}, bodyWidth=80, win=$pnlName
	PopupMenu expP mode=2, value="single;double", disable=1, win=$pnlName
	PopupMenu scanP title="slow scan:", pos={174,68}, size={113,20}, win=$pnlName
	PopupMenu scanP mode=2, value="\u21c4;\u21c5", disable=1, bodyWidth=60, win=$pnlName
	PopupMenu xscanP title="x scan:", pos={188,99}, size={99,20}, mode=1, win=$pnlName
	PopupMenu xscanP value="\u21e8;\u21e6", disable=1, bodyWidth=60, win=$pnlName
	PopupMenu yscanP title="y scan:", pos={188,130}, size={99,20}, mode=1, win=$pnlName
	PopupMenu yscanP value="\u21e7;\u21e9", disable=1, bodyWidth=60, win=$pnlName

	Button doB title="Do It", pos={9,165}, size={60,20}, win=$pnlName
	CheckBox displayC title="display", pos={83,167}, value=0, win=$pnlName
	PopupMenu toP title="To", pos={153,166}, size={50,20}, win=$pnlName
	PopupMenu toP value="Cmd Line;Clip", mode=0, bodyWidth=50, win=$pnlName
	Button helpB title="?", pos={220,165}, size={20,20}, win=$pnlName
	Button cancelB title="Cancel", pos={257,165}, size={60,20}, win=$pnlName

	ModifyControlList "orderP;modeP;toP" proc=SIDAMSubtraction#pnlPopup, win=$pnlName
	ModifyControlList "doB;helpB;cancelB" proc=SIDAMSubtraction#pnlButton, win=$pnlName

	ModifyControlList ControlNameList(pnlName,";","*"), focusRing=0, win=$pnlName
End

//******************************************************************************
//	Controls
//******************************************************************************
//	Button
Static Function pnlButton(STRUCT WMButtonAction &s)

	if (s.eventCode != 2)
		return 0
	endif

	strswitch (s.ctrlName)
		case "cancelB":
			KillWindow $s.win
			break

		case "doB":
			Wave w = $GetUserData(s.win, "", "src")
			Wave cvw = KMGetCtrlValues(s.win, "orderP;directionP;indexV;owC;displayC;expP;scanP;xscanP;yscanP;roiC;p1V;q1V;p2V;q2V;methodP")
			Wave/T ctw = KMGetCtrlTexts(s.win,"modeP;resultV")
			Variable direction = (cvw[6]-1) + (cvw[7]-1)*2 + (cvw[8]-1)*4
			String result = SelectString(cvw[3], ctw[1], "")
			KillWindow $s.win

			Variable mode = WhichListItem(ctw[0],MODE)
			switch (mode)
				case 0:
					if ((cvw[0] == 2) && (cvw[9] == 1))
						Wave resw = SIDAMSubtraction(w, result=result, \
							roi={{cvw[10],cvw[11]},{cvw[12],cvw[13]}}, history=1)
					else
						Wave resw = SIDAMSubtraction(w, order=cvw[0]-1, \
							result=result, history=1)
					endif
					break

				case 1:
					Wave resw = SIDAMSubtraction(w, mode=1, order=cvw[0]-1, \
						direction=cvw[1]-1, method=cvw[14]-1, result=result, history=1)
					break

				case 4:
					Wave resw = SIDAMSubtraction(w, mode=4, order=cvw[5]-1, \
						direction=direction, result=result, history=1)
					break

				case 5:
					Wave resw = SIDAMSubtraction(w, mode=5, direction=direction, \
						result=result, history=1)
					break

				default:
					Wave resw = SIDAMSubtraction(w, mode=mode, order=cvw[0]-1, \
						direction=cvw[1]-1, index=cvw[2], result=result, history=1)
			endswitch

			if (cvw[4])
				SIDAMDisplay(resw, history=1)
			endif
			break

		case "helpB":
			SIDAMOpenHelpNote("subtraction",s.win,"Subtraction")
			break

	endswitch
End

//	SetVariable
Static Function pnlSetVar(STRUCT WMSetVariableAction &s)

	if (s.eventCode == -1)
		return 1
	endif

	strswitch (s.ctrlName)
		case "resultV":
			Variable disable = KMCheckSetVarString(s.win,s.ctrlName,0)*2
			Button doB disable=disable, win=$s.win
			PopupMenu toP disable=disable, win=$s.win
			break

		case "indexV":
			Wave w = $GetUserData(s.win, "", "src")
			SetVariable $s.ctrlName value=_NUM:round(s.dval), win=$s.win
			String titleStr
			sprintf titleStr, "%.2f (%s)", IndexToScale(w,s.dval,2), WaveUnits(w,2)
			TitleBox valueT title=titleStr, win=$s.win
			break

	endswitch
End

//	Popup
Static Function pnlPopup(STRUCT WMPopupAction &s)

	if (s.eventCode != 2)
		return 1
	endif

	strswitch (s.ctrlName)
		case "modeP":
			if (!CmpStr(s.popStr,"Plane"))
				PopupMenu orderP mode=2, value="0;1;2;3;4;5;6;7", win=$s.win
			elseif (!CmpStr(s.popStr,"Line"))
				PopupMenu orderP mode=1, value="0;1;2", win=$s.win
			endif
			//	*** FALLTHROUGH ***

		case "orderP":
			pnlShowHideControls(s.win)
			break

		case "toP":
			Wave cvw = KMGetCtrlValues(s.win, "orderP;directionP;indexV;owC;expP;scanP;xscanP;yscanP;roiC;p1V;q1V;p2V;q2V;methodP")
			Wave/T ctw = KMGetCtrlTexts(s.win,"modeP;resultV")

			STRUCT paramStruct ps
			Wave ps.w = $GetUserData(s.win, "", "src")
			ps.mode = WhichListItem(ctw[0],MODE)
			ps.result = SelectString(cvw[3], ctw[1], "")

			switch (ps.mode)
				case 0:
					ps.order = cvw[0]-1
					ps.direction = cvw[1]-1
					if (cvw[8] == 1)
						Make/B/U/FREE tw = {{cvw[9],cvw[10]},{cvw[11],cvw[12]}}
						Wave ps.roi = tw
					endif
					break
				case 1:
					ps.order = cvw[0]-1
					ps.direction = cvw[1]-1
					ps.method = cvw[13]-1
					break
				case 2:
				case 3:
					ps.index = cvw[2]
					break
				case 4:
					ps.order = cvw[4]-1
					ps.direction = (cvw[5]-1) + (cvw[6]-1)*2 + (cvw[7]-1)*4
					break
				case 5:
					ps.direction = (cvw[5]-1) + (cvw[6]-1)*2 + (cvw[7]-1)*4
					break
			endswitch

			KMPopupTo(s, echoStr(ps))
			break
	endswitch
End

//	CheckBox
Static Function pnlCheck(STRUCT WMCheckboxAction &s)

	if (s.eventCode != 2)
		return 1
	endif

	strswitch (s.ctrlName)
		case "owC":
			SetVariable resultV disable=s.checked*2, win=$s.win
			break
		case "roiC":
			pnlShowHideControls(s.win)
			break
	endswitch
End

//	Show/Hide controls
Static Function pnlShowHideControls(String pnlName)

	ControlInfo/W=$pnlName modeP ;	String modeStr = S_Value
	int forPlane = !CmpStr(modeStr, "Plane")
	int forLine = !CmpStr(modeStr, "Line")
	int forExp = !CmpStr(modeStr, "Exp")
	int forLog = !CmpStr(modeStr, "Log")
	int forComplex = (!CmpStr(modeStr, "Layer") || !CmpStr(modeStr, "Phase"))

	Wave w = $GetUserData(pnlName, "", "src")
	int is2dReal = WaveDims(w)==2 && !(WaveType(w) & 0x01)
	ControlInfo/W=$pnlName orderP
	ControlInfo/W=$pnlName roiC ;		int forRoiNum = forPlane && V_value

	PopupMenu orderP disable=!(forPlane || forLine), win=$pnlName
	PopupMenu directionP disable=!forLine, win=$pnlName
	PopupMenu methodP disable=!forLine, win=$pnlName
	ModifyControlList "indexV;valueT" disable=!forComplex, win=$pnlName
	CheckBox roiC disable=!forPlane, win=$pnlName
	ModifyControlList "p1V;q1V;p2V;q2V" disable=!forRoiNum, win=$pnlName
	PopupMenu expP disable=!forExp, win=$pnlName
	ModifyControlList "scanP;xscanP;yscanP" disable=!(forExp || forLog), win=$pnlName
End


//=====================================================================================================
//	Functions executing subtraction
//=====================================================================================================
//******************************************************************************
//	plane, for real 2D/3D waves
//******************************************************************************
Static Function/WAVE subtract_plane(Wave w, Wave roi, int order)

	Variable nx = DimSize(w,0), ny = DimSize(w,1), i

	//	For 3D waves, apply the 2D code below to each layer
	if (WaveDims(w)==3)
		Duplicate/FREE w, rtn3dw
		for (i = 0; i < DimSize(w,2); i++)
			MatrixOP/FREE slice = layer(w,i)
			Wave tw = subtract_plane(slice,roi,order)
			rtn3dw[][][i] = tw[p][q]
		endfor
		return rtn3dw
	endif

	//	For 2D waves
	Duplicate/FREE/RMD=[roi[0][0],roi[0][1]][roi[1][0],roi[1][1]] w tw

	if (order)
		Wave cw = plane_coef(tw)
		MatrixOP/FREE rtnw = w - (cw[0]*indexRows(w) + cw[1]*indexCols(w))
		ImageStats/Q/M=0/G={roi[0][0],roi[0][1],roi[1][0],roi[1][1]} rtnw
		rtnw -= V_avg
	else
		MatrixOP/FREE rtnw = w - mean(tw)
	endif

	Copyscales w, rtnw
	return rtnw
End

Static Function/WAVE plane_coef(Wave w)

	DFREF dfrSav = GetDataFolderDFR()
	SetDataFolder NewFreeDataFolder()

	//  Equation to get the least-squares solution, Ax = b
	Make/D/N=(3,3) A
	A = sum_poly_series(DimSize(w,0)-1, (p==0)+(q==0)) \
	  * sum_poly_series(DimSize(w,1)-1, (p==1)+(q==1))

	MatrixOP b0 = sum(w * indexRows(w))
	MatrixOP b1 = sum(w * indexCols(w))
	MatrixOP b2 = sum(w)
	Make/D b = {b0, b1, b2}

	MatrixLLS A b
	Wave rtnw = M_B
	Redimension/N=3 rtnw

	SetDataFolder dfrSav

	return rtnw
End

Static Function sum_poly_series(int n, int order)
	switch (order)
		case 0:
			return n+1
		case 1:
			return n*(n+1)/2
		case 2:
			return n*(n+1)*(2*n+1)/6
		default:
			return NaN
	endswitch
End

//******************************************************************************
//	poly, for real 2D/3D waves
//******************************************************************************
Static Function/WAVE subtract_poly(Wave w, Wave roi, int order)

	//	For 3D waves, apply the 2D code below to each layer
	if (WaveDims(w)==3)
		Duplicate/FREE w, rtnw
		Variable i
		for (i = 0; i < DimSize(w,2); i++)
			MatrixOP/FREE slice = layer(w,i)
			Wave tw = subtract_poly(slice,roi,order)
			rtnw[][][i] = tw[p][q]
		endfor
		return rtnw
	endif

	//	For 2D waves
	DFREF dfrSav = GetDataFolderDFR()
	SetDataFolder NewFreeDataFolder()

	Make/B/U/N=(DimSize(w,0),DimSize(w,1)) tw2=0
	tw2[roi[0][0],roi[0][1]][roi[1][0],roi[1][1]] = 1

	ImageRemoveBackground/R=tw2/P=(order) w
	Wave rtnw = M_RemovedBackground

	SetDataFolder dfrSav
	return rtnw
End

//******************************************************************************
//	line, for real 2D/3D waves
//******************************************************************************
Static Function/WAVE subtract_line_constant(Wave w, int direction)

	if (WaveDims(w)==3)
		return subtract_line_3D(w, direction)
	endif

	//	For 2D waves
	if (direction == 0)
		MatrixOP/FREE rtnw = w - rowRepeat(sumCols(w)/numRows(w),numRows(w))
	else
		MatrixOP/FREE rtnw = w - colRepeat(sumRows(w)/numCols(w),numCols(w))
	endif

	Copyscales w, rtnw
	return rtnw
End

Static Function/WAVE subtract_line_poly(Wave w, int order, int direction)

	if (WaveDims(w)==3)
		return subtract_line_3D(w, direction)
	endif

	Duplicate/FREE w, rtnw

	if (direction)
		MatrixTranspose rtnw
	endif

	Make/D/N=(DimSize(rtnw,0),order+1)/FREE matrixA = p^q
	Make/B/U/N=(DimSize(rtnw,1))/FREE dummy
	if (order==1)
		MultiThread dummy = subtract_line_poly_1(rtnw,p,matrixA)
	elseif (order==2)
		MultiThread dummy = subtract_line_poly_2(rtnw,p,matrixA)
	endif

	if (direction)
		MatrixTranspose rtnw
	endif

	return rtnw
End

ThreadSafe Static Function subtract_line_poly_1(Wave w, Variable index, Wave Aw)

	MatrixOP/FREE tw = fp64(col(w,index))
	MatrixLLS Aw tw
	Wave bw = M_B
	w[][index] -= bw[0] + bw[1]*p
	return V_flag
End

ThreadSafe Static Function subtract_line_poly_2(Wave w, Variable index, Wave Aw)

	MatrixOP/FREE tw = fp64(col(w,index))
	MatrixLLS Aw tw
	Wave bw = M_B
	w[][index] -= bw[0] + (bw[1]+bw[2]*p)*p
	return V_flag
End

Static Function/WAVE subtract_line_median_constant(Wave w, int direction)

	if (WaveDims(w)==3)
		return subtract_line_3D(w, direction)
	endif

	//	For 2D waves
	//	Use MatrixOP instead of Make for median_ to keep wave data type
	if (direction)
		MatrixOP/FREE median_ = col(w,0)
		MultiThread median_ = subtract_line_median_constant_worker1(w, p)
		MatrixOP/FREE rtnw = w - colRepeat(median_,numCols(w))
	else
		MatrixOP/FREE median_ = row(w,0)
		MultiThread median_ = subtract_line_median_constant_worker0(w, q)
		MatrixOP/FREE rtnw = w - rowRepeat(median_,numRows(w))
	endif

	Copyscales w, rtnw
	return rtnw
End

ThreadSafe Static Function subtract_line_median_constant_worker0(Wave w,
	Variable index)

	MatrixOP/FREE tw = col(w,index)
	return median(tw)
End

ThreadSafe Static Function subtract_line_median_constant_worker1(Wave w,
	Variable index)

	MatrixOP/FREE tw = row(w,index)
	return median(tw)
End

Static Function/WAVE subtract_line_median_slope(Wave w, int direction)

	if (WaveDims(w)==3)
		return subtract_line_3D(w, direction)
	endif

	//	For 2D waves
	//	Use MatrixOP instead of Make for median_ to keep wave data type
	if (direction)
		MatrixOP/FREE median_ = col(w,0)
		MultiThread median_ = subtract_line_median_slope_worker1(w, p)
		MatrixOP/FREE tw = w - colRepeat(median_,numCols(w))*indexCols(w)
		MultiThread median_ = subtract_line_median_constant_worker1(tw, p)
		MatrixOP/FREE rtnw = tw - colRepeat(median_,numCols(w))
	else
		MatrixOP/FREE median_ = row(w,0)
		MultiThread median_ = subtract_line_median_slope_worker0(w, q)
		MatrixOP/FREE tw = w - rowRepeat(median_,numRows(w))*indexRows(w)
		MultiThread median_ = subtract_line_median_constant_worker0(tw, q)
		MatrixOP/FREE rtnw = tw - rowRepeat(median_,numRows(w))
	endif

	Copyscales w, rtnw
	return rtnw
End

ThreadSafe Static Function subtract_line_median_slope_worker0(Wave w,
	Variable index)

	int nx = DimSize(w,0)
	Make/D/N=(nx,nx)/FREE tw = p > q ? (w[p][index]-w[q][index])/(p-q) : Nan
	Redimension/N=(nx*nx) tw
	return median(tw)
End

ThreadSafe Static Function subtract_line_median_slope_worker1(Wave w,
	Variable index)

	int ny = DimSize(w,1)
	Make/D/N=(ny,ny)/FREE tw = p > q ? (w[index][p]-w[index][q])/(p-q) : Nan
	Redimension/N=(ny*ny) tw
	return median(tw)
End

Static Function/WAVE subtract_line_median_curvature(Wave w, int direction)

	if (WaveDims(w)==3)
		return subtract_line_3D(w, direction)
	endif

	//	For 2D waves
	//	Use MatrixOP instead of Make for median_ to keep wave data type
	if (direction)
		MatrixOP/FREE median_curve = col(w,0)
		Duplicate/FREE median_curve, median_slope, median_const

		//	If the following two MatrixOP are combined to one line,
		//	the resultant wave becomes 64bit float even if w is 32bit float.
		MultiThread median_curve = subtract_line_median_curvature_worker1(w, p)
		MatrixOP/FREE tw0 = colRepeat(median_curve,numCols(w))*indexCols(w)
		MatrixOP/FREE tw0 = w - tw0 * indexCols(w)

		MultiThread median_slope = subtract_line_median_slope_worker1(tw0, p)
		MatrixOP/FREE tw1 = tw0 - colRepeat(median_slope,numCols(w))*indexCols(w)

		MultiThread median_const = subtract_line_median_constant_worker1(tw1, p)
		MatrixOP/FREE rtnw = tw1 - colRepeat(median_const,numCols(w))
	else
		MatrixOP/FREE median_curve = row(w,0)
		Duplicate/FREE median_curve, median_slope, median_const

		//	If the following two MatrixOP are combined to one line,
		//	the resultant wave becomes 64bit float even if w is 32bit float.
		MultiThread median_curve = subtract_line_median_curvature_worker0(w, q)
		MatrixOP/FREE tw0 = rowRepeat(median_curve,numRows(w))*indexRows(w)
		MatrixOP/FREE tw0 = w - tw0 * indexRows(w)

		MultiThread median_slope = subtract_line_median_slope_worker0(tw0, q)
		MatrixOP/FREE tw1 = tw0 - rowRepeat(median_slope,numRows(w))*indexRows(w)

		MultiThread median_const = subtract_line_median_constant_worker0(tw1, q)
		MatrixOP/FREE rtnw = tw1 - rowRepeat(median_const,numRows(w))
	endif

	Copyscales w, rtnw
	return rtnw
End

ThreadSafe Static Function subtract_line_median_curvature_worker0(Wave w,
	Variable index)

	int nx = DimSize(w,0)
	Make/D/N=(nx,nx,nx)/FREE tw = (p > q && q > r) ? \
		((w[p][index]-w[q][index])*r + (w[r][index]-w[p][index])*q + \
		(w[q][index]-w[r][index])*p) / ((p-q)*(q-r)*(r-p)) : NaN
	Redimension/N=(nx*nx*nx) tw
	return median(tw)
End

ThreadSafe Static Function subtract_line_median_curvature_worker1(Wave w,
	Variable index)

	int ny = DimSize(w,1)
	Make/D/N=(ny,ny,ny)/FREE tw = (p > q && q > r) ? \
		((w[index][p]-w[index][q])*r + (w[index][r]-w[index][p])*q + \
		(w[index][q]-w[index][r])*p) 	/ ((p-q)*(q-r)*(r-p)) : NaN
	Redimension/N=(ny*ny*ny) tw
	return median(tw)
End

//	For 3D waves, apply the 2D code to each layer
Static Function/WAVE subtract_line_3D(Wave w, int direction)

	String moduleName = StringByKey("MODULE",FunctionInfo("subtract_line_prototype"))
	FUNCREF subtract_line_prototype fn = $(moduleName+"#"+GetRTStackInfo(2))
	Duplicate/FREE w, rtnw
	Variable i
	for (i = 0; i < DimSize(w,2); i++)
		MatrixOP/FREE slice = layer(w,i)
		Wave tw = fn(slice,direction)
		rtnw[][][i] = tw[p][q]
	endfor
	return rtnw
End

Function/WAVE subtract_line_prototype(Wave w, int n)
End

//******************************************************************************
//	layer, for real/complex 3D waves
//******************************************************************************
Static Function/WAVE subtract_layer(Wave w, Variable index)

	Variable nx = DimSize(w,0), ny = DimSize(w,1), nz = DimSize(w,2)
	MatrixOP/FREE tw0 = colRepeat(layer(w,index),nz)
	Redimension/N=(nx*ny*nz) tw0
	Redimension/N=(nx,ny,nz) tw0
	MatrixOP/FREE tw1 = w - tw0
	Copyscales w, tw1
	return tw1
End

//******************************************************************************
//	phase, for complex 3D waves
//******************************************************************************
Static Function/WAVE subtract_phase(Wave/C w,	 Variable index)

	Variable nx = DimSize(w,0), ny = DimSize(w,1), nz = DimSize(w,2)
	MatrixOP/FREE tw0 = phase(layer(w,index)) * (-1)
	MatrixOP/FREE tw1 = colRepeat(tw0, nz)
	Redimension/N=(nx*ny*nz) tw1
	Redimension/N=(nx,ny,nz) tw1
	MatrixOP/C/FREE tw2 = w * cmplx(cos(tw1), sin(tw1))
	Copyscales w, tw2
	return tw2
End