#pragma TextEncoding="UTF-8"
#pragma rtGlobals=3

#ifndef SIDAMshowProc
#pragma hide = 1
#endif

//  後ろにつけて結果ウエーブの名前とするための文字列
StrConstant ks_index_iamp = "_a"
StrConstant ks_index_ioffset = "_off"
StrConstant ks_index_wf = "_wf"
StrConstant ks_index_chisq = "_chisq"
StrConstant ks_index_error = "_err"
StrConstant ks_index_quit="_quit"

Static Constant k_convert = 0.9525082672661202

//******************************************************************************
//	KMWorkfunction
//		動作振り分け
//******************************************************************************
Function/WAVE KMWorkfunction(w,[result,startp,endp,offset,history])
	Wave/Z w			//	表示対象となる1D/3Dウエーブ
	Variable startp	//	startp [optional]:	フィッティング開始点, 省略時は0
	Variable endp	//	endp [optional]:	フィッティング終了点, 省略時は最終点
	Variable offset	//	offset [optional]:	プリアンプのオフセット, 省略時はこれもフィッティングパラメータになる
	Variable history	//	history [optional]:	bit 0: 履歴欄にコマンドを出力する
						//	bit 1: 入力ウエーブが1Dの時に結果を履歴欄に出力する
						//	省略時は2
	String result
	
	STRUCT check s
	Wave/Z s.w = w
	s.result = SelectString(ParamIsDefault(result), result, NameOfWave(w))
	s.startp = ParamIsDefault(startp) ? 0 : startp
	s.endp = ParamIsDefault(endp) ? DimSize(w,WaveDims(w)-1)-1 : endp
	s.offset = ParamIsDefault(offset) ? inf : offset
	
	//	各種チェック
	if (KMWorkfunctionCheck(s))
		print s.errMsg
		return $""
	endif
	
	//  履歴欄出力
	if (ParamIsDefault(history))
		history = 2
	elseif (history&1)
		print PRESTR_CMD + KMWorkfunctionEcho(s.w, s.result, s.startp, s.endp, s.offset)
	endif
	
	//  実行関数
	if (WaveDims(w) == 1)
		return KMWorkfunction1D(w, s.startp, s.endp, s.offset, history)
	else
		return KMWorkfunction3D(w, s.result, s.startp, s.endp, s.offset)
	endif
End
//-------------------------------------------------------------
//	KMWorkfunctionCheck
//		チェック用関数
//-------------------------------------------------------------
Static Function KMWorkfunctionCheck(s)
	STRUCT check &s
	
	s.errMsg = PRESTR_CAUTION + "KMWorkfunction gave error: "
	
	if (!WaveExists(s.w))
		s.errMsg += "wave not found."
		return 1
	elseif (WaveDims(s.w) != 1 && WaveDims(s.w) != 3)
		s.errMsg += "dimension of the input wave must be 1 or 3."
		return 1
	endif
	
	//	結果ウエーブの名前について
	int dim = WaveDims(s.w)
	if (dim == 3)
		if (strlen(s.result)+MaxSuffixLength() > MAX_OBJ_NAME)
			s.errMsg += "too long name."
			return 1
		endif
	endif
	
	//	フィッティング範囲について
	if (s.startp < 0 || s.startp > DimSize(s.w, dim-1) - 1)
		s.errMsg += "startp must be an integer between 0 and "+num2str(DimSize(s.w, dim-1) - 1)
		return 1
	endif
	
	if (s.endp < 0 || s.endp > DimSize(s.w, dim-1)-1)
		s.errMsg += "endp must be an integer between 0 and "+num2str(DimSize(s.w, dim-1) - 1)
		return 1
	endif
	
	if (abs(s.startp - s.endp) < 2)
		s.errMsg += "you must have at least as many data point as fit parameters."
		return 1
	endif
	
	return 0
End

Static Structure check
	Wave	w
	String	errMsg
	String	result
	uint16	startp
	uint16	endp
	Variable	offset
EndStructure
//-------------------------------------------------------------
//	MaxSuffixLength
//		ks_index_** (iamp,ioffset,wf,chisq) の中で一番長い文字列の長さを返す
//-------------------------------------------------------------
Static Function MaxSuffixLength()
	Make/N=4/T/FREE tw = {ks_index_iamp, ks_index_ioffset, ks_index_wf, ks_index_chisq}
	Make/N=4/FREE lw = strlen(tw[p])
	return WaveMax(lw)
End

//-------------------------------------------------------------
//	KMWorkfunctionEcho: 		履歴欄出力用文字列作成
//-------------------------------------------------------------
Static Function/S KMWorkfunctionEcho(w, result, startp, endp, offset)
	Wave w
	String result
	Variable startp, endp, offset
	
	String paramStr = GetWavesDataFolder(w,2)
	paramStr += SelectString(stringmatch(result,NameOfWave(w)) || !strlen(result),",result=\""+result+"\"","")
	paramStr += SelectString(startp,"",",startp="+num2str(startp))
	paramStr += SelectString(endp==DimSize(w,WaveDims(w)-1)-1,",endp="+num2str(endp),"")
	paramStr += SelectString(numtype(offset)==1,",offset="+num2str(offset),"")
	Sprintf paramStr, "KMWorkfunction(%s)", paramStr
	
	return paramStr
End

//-------------------------------------------------------------
//	KMWorkfunctionR: 		右クリック用
//-------------------------------------------------------------
Function KMWorkfunctionR()
	String grfName = WinName(0,1)
	if (strlen(ImageNameList(grfName,";")))
		KMWorkfunctionPnl(KMGetImageWaveRef(grfName), grfName=grfName)
	else
		String trcList = TraceNameList(grfName,";",1)
		Variable num = KMWaveSelector("Work Function", trcList, grfName=grfName)
		if (num)
			KMWorkfunctionPnl(TraceNameToWaveRef(grfName,StringFromList(num-1,trcList)), grfName=grfName)
		endif
	endif
End


//******************************************************************************
//	KMWorkfunction1D
//	KMWorkfunction3D
//		実行関数
//******************************************************************************
//-------------------------------------------------------------
//	KMWorkfunction1D
//		1Dウエーブ用
//-------------------------------------------------------------
Static Function/WAVE KMWorkfunction1D(w, startp, endp, offset,history)
	Wave w
	Variable startp, endp, offset, history
	
	Variable V_fitOptions=4
	Variable V_FitError = 0
	Variable V_FitQuitReason = 0
	
	DFREF dfrSav = GetDataFolderDFR()
	SetDataFolder NewFreeDataFolder()
	
	if (numtype(offset) == 1)		//	offset可変の場合
		CurveFit/NTHR=0/Q/K={0}/W=0 exp_XOffset w[startp,endp]
	else						//	offset固定の場合
		K0 = offset
		CurveFit/NTHR=0/Q/K={0}/W=0/H="100" exp_XOffset w[startp,endp]
	endif
	Wave coefw = $"W_coef"
	
	if (V_FitError)
		print PRESTR_CAUTION + "KMWorkfunction1D gave error: fitting error ("+num2str(V_FitQuitReason)+")"
		return $""
	else
		Make/N=4/FREE resw = {k_convert/coefw[2]^2, coefw[1],V_chisq, coefw[0]}
		if (history&2)
			printf "wave:\t%s\r", NameOfWave(w)
			printf "fitting function: I = A*exp(-z/z0)+I0\r"
			printf "\tz0:\t%f [%s]\r", coefw[2], WaveUnits(w,0)
			printf "\tA:\t%f [%s]\r", coefw[1], StringByKey("DUNITS", WaveInfo(w,0))
			if (numtype(offset) == 1)		//	offset可変の場合
				printf "\tI0:\t%f [%s]\r", coefw[0], StringByKey("DUNITS", WaveInfo(w,0))
			else						//	offset固定の場合
				printf "\tI0:\t%f [%s] (fixed)\r", coefw[0], StringByKey("DUNITS", WaveInfo(w,0))
			endif
			printf "\tchisq:\t%e\r", V_chisq
			printf "work function: %f [eV]\r", resw[0]
		endif
	endif
	
	SetDataFolder dfrSav
	return resw
End
//-------------------------------------------------------------
//	KMWorkfunction3D
//		3Dウエーブ用
//-------------------------------------------------------------
Static Function/WAVE KMWorkfunction3D(w, result, startr, endr, offset)
	Wave w
	String result
	Variable startr, endr, offset
	
	Variable nx = DimSize(w,0), ny = DimSize(w,1), i, j, n = 3
	
	//  実行
	String pnlName = KMNewPanel("Work function", 320, 35, float=1)
	TitleBox statusT title="fitting...", pos={140,8}, frame=0, anchor=MC, win=$pnlName
	DoUpdate	
	Make/N=(nx,ny)/FREE/WAVE ww
	MultiThread ww = KMWorkfunction3DFit(w, p, q, startr, endr, offset)
	
	DFREF dfrSav = GetDataFolderDFR()
	SetDataFolder GetWavesDataFolderDFR(w)
	
	//  結果ウエーブへ代入
	TitleBox statusT title="constructing resultant waves...", win=$pnlName
	DoUpdate
	Make/N=(nx,ny)/O $(result+ks_index_iamp)/WAVE=aw
	Make/N=(nx,ny)/O $(result+ks_index_wf)/WAVE=wfw
	Make/N=(nx,ny)/O $(result+ks_index_chisq)/WAVE=chisqw
	SetScale/P x DimOffset(w,0), DimDelta(w,0), WaveUnits(w,0), wfw, aw, chisqw
	SetScale/P y DimOffset(w,1), DimDelta(w,1), WaveUnits(w,1), wfw, aw, chisqw
	SetScale d 0, 0, "eV", wfw
	SetScale d 0, 0, StringByKey("DUNITS", WaveInfo(w,0)), aw
	
	MultiThread aw[][] = KMWorkfunction3DWorker(ww, p, q, 1)
	MultiThread wfw[][] =  k_convert/(KMWorkfunction3DWorker(ww, p, q, 2))^2
	MultiThread chisqw[][] = KMWorkfunction3DWorker(ww, p, q, 3)
	
	if (numtype(offset) == 1)
		Make/N=(nx,ny)/O $(result+ks_index_ioffset)/WAVE=offsetw
		MultiThread offsetw[][] = KMWorkfunction3DWorker(ww, p, q, 0)
		CopyScales aw, offsetw
		n += 1
	endif
	
	//	エラーがあればその情報を出力する
	Make/N=(nx,ny)/FREE errw
	MultiThread errw[][] = KMWorkfunction3DWorker(ww, p, q, 4)
	WaveStats/Q/M=1 errw
	Variable err = V_avg
	if (err)
		Make/N=(nx,ny)/O $(result+ks_index_quit)/WAVE=qw
		CopyScales chisqw, errw, qw
		Duplicate/O errw $(result+ks_index_error)/WAVE=ew
		MultiThread qw[][] = KMWorkfunction3DWorker(ww, p, q, 5)
		n += 2
	endif
	
	SetDataFolder dfrSav
	KillWindow $pnlName
	
	Make/N=(n)/FREE/WAVE refw
	refw[0] = {wfw, aw, chisqw}
	if (n == 6)	//	オフセット可変、エラーあり
		refw[3] = {offsetw, ew, qw}
	elseif (err)	//	エラーありだけ(オフセット固定)
		refw[3] = {ew, qw}
	else			//	オフセット可変だけ(エラーなし)
		refw[3] = {offsetw}
	endif
	
	return refw
End

ThreadSafe Static Function/WAVE KMWorkfunction3DFit(srcw, pp, qq, startr, endr, offset)
	Wave srcw
	Variable pp, qq, startr, endr, offset
	
	DFREF dfrSav = GetDataFolderDFR()
	SetDataFolder NewFreeDataFolder()
	
	Make/N=6 resw
	Make/N=(DimSize(srcw,2)) tw = srcw[pp][qq][p]
	SetScale/P x DimOffset(srcw, 2), DimDelta(srcw, 2), "", tw
	
 	Variable V_fitOptions=4, V_FitError = 0, V_FitQuitReason = 0
	if (numtype(offset) == 1)	//	current offset 可変
		CurveFit/N=1/NTHR=0/Q/W=0 exp_XOffset tw[startr,endr]
		Wave coefw = $"W_coef"
	else						//	current offset 固定
		Make/N=3 $"W_coef"/WAVE=coefw
		coefw[0] = offset
		CurveFit/N=1/NTHR=0/Q/W=0/H="100" exp_XOffset tw[startr,endr]
	endif
	resw[,2] = coefw[p]	//	offset, amplitude, tau
	resw[3] = V_chisq
	resw[4] = V_FitError
	resw[5] = V_FitQuitReason
	
	SetDataFolder dfrSav
	
	return resw
End

ThreadSafe Static Function KMWorkfunction3DWorker(ww, pp, qq, index)
	Wave/WAVE ww
	Variable pp, qq, index
	
	Wave tww = ww[pp][qq]
	return tww[index]
End


//=====================================================================================================


//******************************************************************************
//	KMWorkfunctionPnl
//		パネル
//******************************************************************************
Static Function KMWorkfunctionPnl(w, [grfName])
	Wave w
	String grfName	//	右クリックから呼び出される時
	
	//  パネル表示
	String pnlName = KMNewPanel("Work Function ("+NameOfWave(w)+")", 350, 163)
	if (!ParamIsDefault(grfName))
		AutoPositionWindow/E/M=0/R=$grfName $pnlName
	endif
	
	SetWindow $pnlName hook(self)=KMClosePnl
	SetWindow $pnlName userData(src)=GetWavesDataFolder(w,2)
	Variable dim = WaveDims(w)
	
	//  コントロール項目
	SetVariable resultV title="basename:", pos={10,10}, size={332,16}, frame=1, bodyWidth=275, proc=KMWorkfunctionPnlSetVar, win=$pnlName
	if (dim == 1)
		SetVariable resultV disable=2, value=_STR:"", win=$pnlName
	else
		SetVariable resultV value=_STR:NameOfWave(w), win=$pnlName
	endif
	
	GroupBox rangeG title="fitting range", pos={9,40}, size={160,75}, win=$pnlName
	SetVariable startpV title="start:", pos={19,64}, size={85,15}, bodyWidth=55, proc=KMWorkfunctionPnlSetVar, win=$pnlName
	SetVariable startpV value=_NUM:0, limits={0,DimSize(w,dim-1)-4,1}, disable=2, win=$pnlName
	SetVariable endpV title="end:", pos={25,89}, size={79,15}, bodyWidth=55, proc=KMWorkfunctionPnlSetVar, win=$pnlName
	SetVariable endpV value=_NUM:DimSize(w,dim-1)-1, limits={3,DimSize(w,dim-1)-1,1}, disable=2, win=$pnlName
	SetVariable endpV userData(max)=num2str(DimSize(w,dim-1)-1), win=$pnlName	//	とり得る最大値
	CheckBox startC title="auto", pos={115,65}, value=1, proc=KMWorkfunctionPnlCheckBox, win=$pnlName
	CheckBox endC title="auto", pos={115,90}, value=1, proc=KMWorkfunctionPnlCheckBox, win=$pnlName
	
	GroupBox offsetG title="current offset", pos={182,40}, size={160,75}, win=$pnlName
	CheckBox fitC title="fit", pos={192,65}, mode=1, value=1, proc=KMWorkfunctionPnlCheckBox, win=$pnlName
	CheckBox fixC title="fixed (nA):", pos={192,90}, mode=1, value=0, proc=KMWorkfunctionPnlCheckBox, win=$pnlName
	SetVariable offsetV title=" ", pos={269,89}, size={60,16}, proc=KMWorkfunctionPnlSetVar, win=$pnlName
	SetVariable offsetV limits={-10,10,0.001}, value=_NUM:0, bodyWidth=60, win=$pnlName
	
	Button doB title="Do It", pos={7,130}, size={60,20}, proc=KMWorkfunctionPnlButton, win=$pnlName
	CheckBox displayC title="display", pos={78,133}, value=1, disable=(dim==1)*2, win=$pnlName
	PopupMenu toP title="To", pos={140,130}, size={50,20}, bodyWidth=50, win=$pnlName
	PopupMenu toP value="Cmd Line;Clip", mode=0, proc=KMWorkfunctionPnlPopup, win=$pnlName
//	Button helpB title="Help", pos={213,130}, size={60,20}, proc=KMWorkfunctionPnlButton, win=$pnlName
	Button cancelB title="Cancel", pos={283,130}, size={60,20}, proc=KMWorkfunctionPnlButton, win=$pnlName

	ModifyControlList ControlNameList(pnlName,";","*") focusRing=0, win=$pnlName
End

//******************************************************************************
//	パネルコントロール
//******************************************************************************
//-------------------------------------------------------------
//	KMWorkfunctionPnlPopup:	ポップアップ
//-------------------------------------------------------------
Function KMWorkfunctionPnlPopup(STRUCT WMPopupAction &s)
	
	if (s.eventCode == 2)
		Wave cvw = KMGetCtrlValues(s.win, "startpV;endpV;fitC;offsetV")
		Variable offset = cvw[2] ? inf : cvw[3]
		ControlInfo/W=$s.win resultV
		String paramStr = KMWorkfunctionEcho($GetUserData(s.win, "", "src"), S_Value, cvw[0], cvw[1], offset)
		KMPopupTo(s, paramStr)
	endif
End
//-------------------------------------------------------------
//	KMWorkfunctionPnlSetVar:	値設定
//-------------------------------------------------------------
Function KMWorkfunctionPnlSetVar(STRUCT WMSetVariableAction &s)
	
	if (s.eventCode == -1 || s.eventCode == 6)
		return 1
	endif
	
	strswitch (s.ctrlName)
		case "resultV":	//	文字列の長さの判定と表示の変更
			Variable disable = KMCheckSetVarString(s.win,s.ctrlName,0,maxlength=31-MaxSuffixLength())*2
			Button doB disable=disable, win=$s.win
			PopupMenu toP disable=disable, win=$s.win
			break
		case "startpV":	//	整数にして、endpVの選択可能範囲を変える
			SetVariable startpV value=_NUM:round(s.dval), win=$s.win
			SetVariable endpV limits={round(s.dval)+3,str2num(GetUserData(s.win,"endpV","max")),1}, win=$s.win
			break
		case "endpV":	//	整数にして、startpVの選択可能範囲を変える
			SetVariable startpV limits={0,round(s.dval)-3,1}, win=$s.win
			SetVariable endpV value=_NUM:round(s.dval), win=$s.win
			break
		case "offsetV":	//	ラジオボタンの選択状況を変更する
			CheckBox fitC value=0, win=$s.win
			CheckBox fixC value=1, win=$s.win
			break
		default:
	endswitch
End
//-------------------------------------------------------------
//	KMWorkfunctionPnlCheckBox :		チェックボックス
//-------------------------------------------------------------
Function KMWorkfunctionPnlCheckBox(STRUCT WMCheckboxAction &s)
	
	if (s.eventCode != 2)
		return 1
	endif
	
	String dfTmp = GetUserData(s.win,"","dfTmp")
	
	strswitch (s.ctrlName)
		case "startC":
			SetVariable startpV disable=s.checked*2, win=$s.win
			if (s.checked)
				SetVariable startpV value=_NUM:0, win=$s.win
				KMClickSetVariable(s.win,"startpV",1)
			endif
			break
		case "endC":
			SetVariable endpV disable=s.checked*2, win=$s.win
			if (s.checked)
				SetVariable endpV value=_NUM:str2num(GetUserData(s.win,"endpV","max")), win=$s.win
				KMClickSetVariable(s.win,"endpV",1)
			endif
			break
		case "fitC":
			CheckBox fixC value=0, win=$s.win
			break
		case "fixC":
			CheckBox fitC value=0, win=$s.win
			break
		default:
	endswitch
End
//-------------------------------------------------------------
//	KMWorkfunctionPnlButton :	ボタン
//-------------------------------------------------------------
Function KMWorkfunctionPnlButton(STRUCT WMButtonAction &s)
	
	if (s.eventCode != 2)
		return 0
	endif
	
	strswitch (s.ctrlName)
		case "doB":
			KMWorkfunctionPnlButtonDo(s.win)
			break
		case "cancelB":
			KillWindow $s.win
			break
		default:
	endswitch
End
//-------------------------------------------------------------
//	KMWorkfunctionPnlButtonDo : 	Do It ボタンの実行関数
//-------------------------------------------------------------
Static Function KMWorkfunctionPnlButtonDo(String pnlName)
	
	Wave w = $GetUserData(pnlName, "", "src")
	Wave cvw = KMGetCtrlValues(pnlName, "startpV;endpV;fitC;offsetV;displayC")
	Variable offset = cvw[2] ? inf : cvw[3]
	ControlInfo/W=$pnlName resultV ;	String result = S_Value
	
	KillWindow $pnlName
	
	Wave/WAVE refw = KMWorkfunction(w,result=result,startp=cvw[0],endp=cvw[1],offset=offset,history=1+cvw[4]*2)
	
	if (cvw[4] && WaveDims(w) == 3)
		KMDisplay(w=refw)
	endif
End
