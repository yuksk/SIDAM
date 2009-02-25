#pragma TextEncoding="UTF-8"
#pragma rtGlobals=3
#pragma ModuleName= KMSubtraction

#ifndef KMshowProcedures
#pragma hide = 1
#endif

Static StrConstant ks_mode = "Plane;Line;Layer;Phase;Exp;Log;y-poly;"


//******************************************************************************
//	KMSubtraction
//		KMPlaneSubtraction, KMLineSubtraction, KMLayerSubtraction, KMExpLogSubtraction の統合インターフェース
//		パラメータに応じてどれかを呼び出します
//******************************************************************************
Function/WAVE KMSubtraction(
	Wave/Z w,				//	対象となる2D/3Dウエーブ
	[
		Wave roi,
		int mode,			//	0: plane, 1: line, 2: layer, 3: phase, 4: exp, 5: log, 省略時は0
		int order,		//	mode=0, 1のときは差し引く平面または直線の次元, 省略時は、mode=0なら1, mode=1なら0
		int direction,	//	mode=1のときは、0:row, 1:column, 省略時は0
		int index,		//	mode=2, 3のときに有効, layer/phase subtractionを実行する際の差し引くレイヤーのインデックス, 省略時は0
		int history,		//	履歴欄にコマンドを出力する(1), しない(0), 省略時は0
		String result	//	結果ウエーブの名前, 省略時は入力ウエーブを上書き
	])
	
	//	パラメータチェック
	STRUCT paramStruct s
	Wave/Z s.w = w
	s.mode = ParamIsDefault(mode) ? 0 : mode
	s.order = ParamIsDefault(order) ? !s.mode : order	//	mode=0(plane)のときが1, mode=1(Line)またはmode=4(Exp)のときが0
	s.direction = ParamIsDefault(direction) ? 0 : direction
	s.index = ParamIsDefault(index) ? 0 : index
	s.result = SelectString(ParamIsDefault(result), result, "")
	s.roiDefault = ParamIsDefault(roi)
	if (s.roiDefault)
		Make/FREE tw = {{0,0},{DimSize(s.w,0)-1,DimSize(s.w,1)-1}}	//	全領域
		Wave s.roi = tw
	else
		Wave/Z s.roi = roi
	endif
	
	//	各種チェック
	if (!isValidArguments(s))
		print s.errMsg
		return $""
	endif
	
	//  履歴欄出力
	if (!ParamIsDefault(history) && history == 1)
		print PRESTR_CMD + echoStr(w,s.mode,s.order,s.direction,s.index,s.roi,s.result)
	endif
	
	//	実行, 各実行関数はフリーウエーブを返す
	switch (mode)
		case 0:
			if (ParamIsDefault(roi) || (!ParamIsDefault(roi) && isWholeArea(w, s.roi)))
				Wave resw = KMPlaneSubtraction(s.w, s.order)
			else
				Wave resw = KMPlaneSubtraction(s.w, 1, roi=roi)
			endif
			break
		case 1:
			Wave resw = KMLineSubtraction(s.w, s.order, s.direction)
			break
		case 2:
			Wave resw = KMLayerSubtraction(s.w, s.index)
			break
		case 3:
			Wave resw = KMPhaseSubtraction(s.w, s.index)
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
//-------------------------------------------------------------
//	isValidArguments : チェック用関数
//-------------------------------------------------------------
Static Function isValidArguments(STRUCT paramStruct &s)
	
	s.errMsg = PRESTR_CAUTION + "KMSubtraction gave error: "
	
	//	w
	if (!WaveExists(s.w))
		s.errMsg += "wave not found."
		return 0
	elseif (WaveDims(s.w) != 2 && WaveDims(s.w) != 3)
		s.errMsg += "dimension of the input wave must be 2 or 3."
		return 0
	endif
	
	//	roi
	if (!s.roiDefault)
		if (!WaveExists(s.roi))
			s.errMsg += "roi wave not found."
			return 0
		elseif (DimSize(s.roi,0) != 2 || DimSize(s.roi,1) != 2)
			s.errMsg += "roi wave has wrong size"
			return 0
		endif
	endif
	
	Variable isComplex = (WaveType(s.w) & 0x01)
	
	//	mode
	if (s.mode < 0 || s.mode > 5)
		s.errMsg += "the mode must be an integer between 0 and 5."
		return 0
	elseif (s.mode != 2 && s.mode != 3 && isComplex)
		s.errMsg += "the mode "+num2str(s.mode)+" is available for a real wave."
		return 0
	elseif ((s.mode == 2 || s.mode == 3) && WaveDims(s.w) != 3)
		s.errMsg += "the mode "+num2str(s.mode)+" is available for a 3D wave."
		return 0
	elseif (s.mode == 3 && !isComplex)
		s.errMsg += "the mode 3 is available for a 3D complex wave."
		return 0
	elseif ((s.mode == 4 || s.mode == 5) && WaveDims(s.w) != 2)
		s.errMsg += "the mode "+num2str(s.mode)+" is available for a 2D wave."
		return 0
	endif
	
	//	order
	if (s.mode == 1 && s.order > 2)
		s.errMsg += "order must be less than 3 when mode is 1."
		return 0
	elseif (s.mode == 4 && s.order > 1)
		s.errMsg += "order must be 0 or 1 when mode is 4."
		return 0
	endif
	
	//	direction
	if (s.mode == 1 && s.direction != 0 && s.direction != 1)
		s.errMsg += "direction must be 0 or 1."
		return 0
	elseif (s.mode == 4 && (s.direction<0 || s.direction>7))
		s.errMsg += "direction must be from 0 to 7."
		return 0
	endif
	
	//	index
	if ((s.index < 0 || s.index >= DimSize(s.w,2)) && (s.mode == 2 || s.mode == 3))
		s.errMsg += "the index is out of range."
		return 0
	endif
	
	//	result
	if (strlen(s.result) > MAX_OBJ_NAME)
		s.errMsg += "length of name for output wave will exceed the limit (" + num2istr(MAX_OBJ_NAME) + " characters)."
		return 0
	endif
	
	return 1
End

Static Structure paramStruct
	Wave	w
	Wave	roi
	String	errMsg
	uchar	mode
	uchar	order
	uchar	direction
	uint16	index
	uchar	roiDefault
	String	result
EndStructure

//-------------------------------------------------------------
//	ROIが全領域なら1を返す
//-------------------------------------------------------------
Static Function isWholeArea(Wave w, Wave roi)
	Make/FREE tw = {{0,0},{DimSize(w,0)-1,DimSize(w,1)-1}}
	return WaveExists(roi) && WaveDims(roi) == 2 && equalWaves(roi,tw,1)	//	前2つの条件はKMSubtractionEchoでの使用のため
End

//-------------------------------------------------------------
//	履歴欄出力用文字列作成
//-------------------------------------------------------------
Static Function/S echoStr(
	Wave w,
	int mode, int order, int direction, int index,
	Wave roi,
	String result
	)
	
	String paramStr = GetWavesDataFolder(w,4)
	paramStr += SelectString(mode, "", ",mode="+num2str(mode))
	switch (mode)
		case 0:
			paramStr += SelectString(order==1, ",order="+num2str(order), "")
			paramStr += SelectString(isWholeArea(w, roi),",roi="+KMWaveToString(roi),"")
			break
		case 1:
			paramStr += SelectString(order, "", ",order="+num2str(order))
			paramStr += SelectString(direction, "", ",direction="+num2str(direction))
			break
		case 2:
		case 3:
			paramStr += SelectString(index, "", ",index="+num2str(index))
			break
		case 4:
		case 5:
			paramStr += SelectString(order, "", ",order="+num2str(order))
			paramStr += SelectString(direction, "", ",direction="+num2str(direction))
			break
	endswitch
	
	paramStr += SelectString(strlen(result) && CmpStr(result,NameOfWave(w)), "", ",result=\""+result+"\"")
	Sprintf paramStr, "KMSubtraction(%s)", paramStr
	
	return paramStr
End


//-------------------------------------------------------------
//	右クリックメニューから実行される関数
//-------------------------------------------------------------
Static Function rightclickDo()
	String grfName = WinName(0,4311,1)
	Wave/Z w = KMGetImageWaveRef(grfName)
	if (WaveExists(w))
		pnl(w, grfName=grfName)
	endif
End
//-------------------------------------------------------------
//	マーキーメニュー実行用
//-------------------------------------------------------------
Static Function marqueeDo()
	KMSubtraction(KMGetImageWaveRef(WinName(0,1,1)),roi=KMGetMarquee(0),history=1)
End
//-------------------------------------------------------------
//	マーキーメニュー表示用
//-------------------------------------------------------------
Static Function/S marqueeMenu()
	Wave/Z w = KMGetImageWaveRef(WinName(0,1,1))
	if (WaveExists(w) && WaveDims(w) == 2)
		return "1st-order plane subtraction about this region"
	else
		return ""
	endif
End


//******************************************************************************
//	パネル表示
//******************************************************************************
Static Function pnl(Wave w,[String grfName])
	
	//  パネル表示・初期設定
	String pnlName = KMNewPanel("Subtraction ("+NameOfWave(w)+")", 360, 200)
	SetWindow $pnlName hook(self)=KMClosePnl
	SetWindow $pnlName userData(src)=GetWavesDataFolder(w,2)
	int isComplex = (WaveType(w) & 0x01)
	
	//  コントロール項目
	SetVariable resultV title="output name:", pos={10,10}, size={340,16}, frame=1, bodyWidth=271, win=$pnlName
	SetVariable resultV value=_STR:NameOfWave(w), disable=2, proc=KMSubtraction#pnlSetVar, win=$pnlName
	Checkbox owC title="overwrite source", pos={79,36}, value=1, proc=KMSubtraction#pnlCheck, win=$pnlName
	
	PopupMenu modeP title="mode:", pos={46,68}, size={124,21}, bodyWidth=90, proc=KMSubtraction#pnlPopup, win=$pnlName
	if (isComplex)		//	複素数ウエーブは3次元のみ
		PopupMenu modeP mode=1, value="Layer;Phase", win=$pnlName
	elseif (WaveDims(w) == 2)
		PopupMenu modeP mode=1, value="Plane;Line;Exp;Log", win=$pnlName
	else
		PopupMenu modeP mode=1, value="Plane;Line;Layer", win=$pnlName
	endif
	PopupMenu orderP title="order:", pos={207,68}, size={83,20}, bodyWidth=50, proc=KMSubtraction#pnlPopup, win=$pnlName
	PopupMenu orderP mode=2, value= "0;1;2;3;4;5;6;7", disable=isComplex, win=$pnlName
	PopupMenu directionP title="direction:", pos={32,99}, size={138,21}, disable=1, win=$pnlName
	PopupMenu directionP mode=1, bodyWidth=90, value= "Row;Column", win=$pnlName
	
	CheckBox roiC title="roi", pos={79,102}, value=0, proc=KMSubtraction#pnlCheck, disable=(WaveDims(w)!=2 || isComplex), win=$pnlName
	SetVariable p1V title="p1:", pos={129,101}, value=_NUM:0, limits={0,DimSize(w,0)-1,1},win=$pnlName
	SetVariable q1V title="q1:", pos={129,123}, value=_NUM:0, limits={0,DimSize(w,1)-1,1},win=$pnlName
	SetVariable p2V title="p2:", pos={222,101}, value=_NUM:DimSize(w,0)-1, limits={0,DimSize(w,0)-1,1},win=$pnlName
	SetVariable q2V title="q2:", pos={222,123}, value=_NUM:DimSize(w,1)-1, limits={0,DimSize(w,1)-1,1}, win=$pnlName
	ModifyControlList "p1V;q1V;p2V;q2V" size={73,16}, bodyWidth=55, disable=1, win=$pnlName
	
	SetVariable indexV title="index:", pos={211,70}, size={92,16}, bodyWidth=60, proc=KMSubtraction#pnlSetVar, win=$pnlName
	SetVariable indexV value=_NUM:0, limits={0,DimSize(w,2)-1,1}, disable=!isComplex, win=$pnlName
	TitleBox valueT title=num2str(DimOffset(w,2))+" (mV)", pos={211,99}, frame=0, disable=!isComplex, win=$pnlName
	
	PopupMenu expP title="exp:", pos={57,99}, size={113,20}, bodyWidth=90, win=$pnlName
	PopupMenu expP mode=2, value="single;double", disable=1, win=$pnlName
	PopupMenu scanP title="slow scan:", pos={186,68}, size={113,20}, bodyWidth=60, win=$pnlName
	PopupMenu scanP mode=2, value="x;y", disable=1, win=$pnlName
	PopupMenu xscanP title="x scan:", pos={200,99}, size={149,20}, bodyWidth=110, win=$pnlName
	PopupMenu xscanP mode=1, value="left to right;right to left", disable=1, win=$pnlName
	PopupMenu yscanP title="y scan:", pos={200,130}, size={149,20}, bodyWidth=110, win=$pnlName
	PopupMenu yscanP mode=1, value="bottom to top;top to bottom", disable=1, win=$pnlName
	
	Button doB title="Do It", pos={9,165}, size={60,20}, proc=KMSubtraction#pnlButton, win=$pnlName
	CheckBox displayC title="display", pos={79,168}, value=1, win=$pnlName
	PopupMenu toP title="To", pos={142,165}, size={50,20}, bodyWidth=50, win=$pnlName
	PopupMenu toP value="Cmd Line;Clip", mode=0, proc=KMSubtraction#pnlPopup, win=$pnlName
	Button helpB title="Help", pos={214,165}, size={60,20}, proc=KMSubtraction#pnlButton, win=$pnlName
	Button cancelB title="Cancel", pos={289,165}, size={60,20}, proc=KMSubtraction#pnlButton, win=$pnlName
	
	ModifyControlList ControlNameList(pnlName,";","*"), focusRing=0, win=$pnlName
	
	if (!ParamIsDefault(grfName))	//	右クリックから呼び出される時
		CheckBox displayC value=0, win=$pnlName
		AutoPositionWindow/E/M=0/R=$grfName $pnlName
	endif
End
//-------------------------------------------------------------
//	ボタン
//-------------------------------------------------------------
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
			Wave cvw = KMGetCtrlValues(s.win, "orderP;directionP;indexV;owC;displayC;expP;scanP;xscanP;yscanP;roiC;p1V;q1V;p2V;q2V")
			Wave/T ctw = KMGetCtrlTexts(s.win,"modeP;resultV")
			Variable direction = (cvw[6]-1) + (cvw[7]-1)*2 + (cvw[8]-1)*4
			String result = SelectString(cvw[3], ctw[1], "")
			KillWindow $s.win
			
			Variable mode = WhichListItem(ctw[0],ks_mode)
			switch (mode)
				case 0:
					if ((cvw[0] == 2) && (cvw[9] == 1))
						Wave resw = KMSubtraction(w, roi={{cvw[10],cvw[11]},{cvw[12],cvw[13]}}, result=result, history=1)
					else	
						Wave resw = KMSubtraction(w, order=cvw[0]-1, result=result, history=1)
					endif
					break
				case 4:
					Wave resw = KMSubtraction(w, mode=4, order=cvw[5]-1, direction=direction, result=result, history=1)
					break
				case 5:
					Wave resw = KMSubtraction(w, mode=5, direction=direction, result=result, history=1)
					break
				default:
					Wave resw = KMSubtraction(w, mode=mode, order=cvw[0]-1, direction=cvw[1]-1, index=cvw[2], result=result, history=1)
			endswitch
			
			if (cvw[4])
				KMDisplay(w=resw)
			endif
			break
		case "helpB":
			KMOpenHelpNote("subtraction",pnlName=s.win,title="Subtraction")
			break
		default:
	endswitch
End
//-------------------------------------------------------------
//	値設定
//-------------------------------------------------------------
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
			TitleBox valueT title=num2str(DimOffset(w,2)+DimDelta(w,2)*round(s.dval))+" (mV)", win=$s.win
			break
	endswitch
End
//-------------------------------------------------------------
//	ポップアップ
//-------------------------------------------------------------
Static Function pnlPopup(STRUCT WMPopupAction &s)
	
	if (s.eventCode != 2)
		return 1
	endif
	
	strswitch (s.ctrlName)
		case "modeP":
			if (!CmpStr(s.popStr,"Plane"))
				PopupMenu orderP mode=2, value= "0;1;2;3;4;5;6;7", win=$s.win
			elseif (!CmpStr(s.popStr,"Line"))
				PopupMenu orderP mode=1, value= "0;1;2", win=$s.win
			endif
			//	*** THROUGH ***
		case "orderP":
			KMSubtractionPnlDisable(s.win)
			break
		case "toP":
			Wave w = $GetUserData(s.win, "", "src")
			Wave cvw = KMGetCtrlValues(s.win, "orderP;directionP;indexV;owC;expP;scanP;xscanP;yscanP;roiC;p1V;q1V;p2V;q2V;")
			Wave/T ctw = KMGetCtrlTexts(s.win,"modeP;resultV")
			Variable direction = (cvw[5]-1) + (cvw[6]-1)*2 + (cvw[7]-1)*4
			String paramStr, resultStr = SelectString(cvw[3], ctw[1], "")
			Variable mode = WhichListItem(ctw[0],ks_mode)
			switch (mode)
				case 0:
					if ((cvw[0] == 2) && (cvw[8] == 1))
						paramStr = echoStr(w,0,1,cvw[1]-1,cvw[2],{{cvw[9],cvw[10]},{cvw[11],cvw[12]}},resultStr)
					else
						paramStr = echoStr(w,0,cvw[0]-1,cvw[1]-1,cvw[2],{0},resultStr)
					endif
					break
				case 4:
					paramStr = echoStr(w,4,cvw[4]-1,direction,0,{0},resultStr)
					break
				case 5:
					paramStr = echoStr(w,5,0,direction,0,{0},resultStr)
					break
				default:
					paramStr = echoStr(w,mode,cvw[0]-1,cvw[1]-1,cvw[2],{0},resultStr)
			endswitch
			
			KMPopupTo(s, paramStr)
			break
	endswitch
End
//-------------------------------------------------------------
//	チェックボックス
//-------------------------------------------------------------
Static Function pnlCheck(STRUCT WMCheckboxAction &s)
	
	if (s.eventCode != 2)
		return 1
	endif
	
	strswitch (s.ctrlName)
		case "owC":
			SetVariable resultV disable=s.checked*2, win=$s.win
			break
		case "roiC":
			KMSubtractionPnlDisable(s.win)
			break
	endswitch
End
//-------------------------------------------------------------
//		表示状態を変える
//-------------------------------------------------------------
Static Function KMSubtractionPnlDisable(String pnlName)
	
	ControlInfo/W=$pnlName modeP ;	String modeStr = S_Value
	int forPlane = !CmpStr(modeStr, "Plane")
	int forLine = !CmpStr(modeStr, "Line")
	int forExp = !CmpStr(modeStr, "Exp")
	int forLog = !CmpStr(modeStr, "Log")
	int forComplex = (!CmpStr(modeStr, "Layer") || !CmpStr(modeStr, "Phase"))
	
	Wave w = $GetUserData(pnlName, "", "src")
	int is2dReal = WaveDims(w)==2 && !(WaveType(w) & 0x01)
	ControlInfo/W=$pnlName orderP ;	int forRoi = forPlane && (V_value==2) && is2dReal
	ControlInfo/W=$pnlName roiC ;		int forRoiNum = forRoi && V_value
	
	PopupMenu orderP disable=!(forPlane || forLine), win=$pnlName
	PopupMenu directionP disable=!forLine, win=$pnlName
	ModifyControlList "indexV;valueT" disable=!forComplex, win=$pnlName
	CheckBox roiC disable=!forRoi, win=$pnlName
	ModifyControlList "p1V;q1V;p2V;q2V" disable=!forRoiNum, win=$pnlName
	PopupMenu expP disable=!forExp, win=$pnlName
	ModifyControlList "scanP;xscanP;yscanP" disable=!(forExp || forLog), win=$pnlName
End


//=====================================================================================================


//******************************************************************************
//	KMLayerSubtraction
//******************************************************************************
Static Function/WAVE KMLayerSubtraction(Wave w,int index)
	
	Duplicate/FREE w tw
	
	if (WaveType(tw) & 0x01)
		Make/C/N=(DimSize(tw,0),DimSize(tw,1),DimSize(tw,2))/FREE tcw
		MultiThread tcw = tw[p][q][index]
		FastOp/C tw = tw - tcw
	else
		Make/N=(DimSize(tw,0),DimSize(tw,1),DimSize(tw,2))/FREE trw
		trw = tw[p][q][index]
		FastOp tw = tw - trw
	endif
	
	return tw
End

//******************************************************************************
//	KMPhaseSubtraction
//******************************************************************************
Static Function/WAVE KMPhaseSubtraction(
	Wave/C w,	//	以下の表現を使うにはwが明示的に複素数として宣言されていなければならないらしい
	int index
	)
	
	Duplicate/FREE w tw
	
	Make/C/N=(DimSize(tw,0),DimSize(tw,1),DimSize(tw,2))/FREE tcw
	MultiThread tcw = conj(tw[p][q][index])/cmplx(real(r2polar(tw[p][q][index])),0)
	FastOp/C tw = tw * tcw
	
	return tw
End

