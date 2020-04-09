#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3

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

//	v8.1.12 ----------------------------------------------------------------------
Function KMSubtraction(Wave/Z w, [Wave roi, int mode, int degree,	int direction, int index, int history, String result])
	deprecatedCaution("SIDAMSubtraction")
	SIDAMSubtraction(w,roi=roi,mode=mode,degree=degree,direction=direction,index=index,history=history,result=result)
End

Function KMOpenHelpNote(String noteFileName, [String pnlName, String title])
	deprecatedCaution("KMOpenHelpNote")
	SIDAMOpenHelpNote(noteFileName,pnlName,title)
End

//	v8.1.11 ----------------------------------------------------------------------
Function/WAVE KMGetMarquee(int mode)
	deprecatedCaution("SIDAMGetMarquee")
	SIDAMGetMarquee(mode)
End

Function KMExportGraphicsTransparent([String grfName, Variable size])
	deprecatedCaution("SIDAMExportGraphicsTransparent")
	SIDAMExportGraphicsTransparent(grfName=grfName,size=size)
End

Function KMGetCursorState(String csrName, String grfName)
	deprecatedCaution("")
	String infoStr = CsrInfo($csrName, grfName)
	Variable rtn = strlen(infoStr) ? 2^0 : 0
	rtn += (strsearch(StringByKey("RECREATION", infoStr), "/A=0",0) != -1) ? 0 : 2^1
	rtn += NumberByKey("ISFREE", infoStr) * 2^2
	return rtn
End

Function/S KMWaveList(DFREF dfr, int dim, [int forFFT, int nx, int ny])
	deprecatedCaution("")
End

Function/S KMWaveToTraceName(String pnlName, Wave w)
	deprecatedCaution("")
End

Function/S KMWaveToString(Wave/Z w, [Variable noquot])
	deprecatedCaution("SIDAMWaveToString")
	return SIDAMWaveToString(w, noquote=noquot)
End

Function KMSetBias(Wave w, Wave biasw)
	deprecatedCaution("SIDAMSetBias")
	SIDAMSetBias(w, biasw)
End

Function/WAVE KMGetBias(Wave w, int dim)
	deprecatedCaution("SIDAMGetBias")
	return SIDAMGetBias(w, dim)
End

Function KMCopyBias(Wave srcw, Wave destw)
	deprecatedCaution("SIDAMCopyBias")
	SIDAMCopyBias(srcw, destw)
End

Function KMisUnevenlySpacedBias(Wave w)
	deprecatedCaution("SIDAMisUnevenlySpacedBias")
	SIDAMisUnevenlySpacedBias(w)
End

Function KMScaleToIndex(Wave w, Variable value, int dim)
	deprecatedCaution("SIDAMScaleToIndex")
	return SIDAMScaleToIndex(w, value, dim)
End

Function KMIndexToScale(Wave w, int index, int dim)
	deprecatedCaution("SIDAMIndexToScale")
	return SIDAMIndexToScale(w, index, dim)
End

Function KMEndEffect(Wave w, int endeffect)
	deprecatedCaution("SIDAMEndEffect")
	SIDAMEndEffect(w, endeffect)
End

Function KMClosePnl(STRUCT WMWinHookStruct &s)
	deprecatedCaution("SIDAMWindowHookClose")
	SIDAMWindowHookClose(s)
End

Function KMonClosePnl(String pnlName, [String df])
	deprecatedCaution("SIDAMKillDataFolder")
	SIDAMKillDataFolder($GetUserData(pnlName, "", "dfTmp"))
End

Function KMRemoveAll(String grfName,[String df])
	deprecatedCaution("")

	if (ParamIsDefault(df) || !strlen(df))
		df = ""
	elseif (!DataFolderExists(df))
		print PRESTR_CAUTION + "KMRemoveAll gave error: datafolder is not found."
		return 1
	endif
	int i, n
	String cwList = ChildWindowList(grfName)
	if (strlen(cwList))
		for (i = 0, n = ItemsInList(cwList); i < n; i++)
			KMRemoveAll(grfName+"#"+StringFromList(i,cwList),df=df)
		endfor
	elseif (WinType(grfName) != 1)
		return 1
	endif
	String listStr = TraceNameList(grfName,";",1)
	Variable NumOfItems = ItemsInList(listStr)
	if (NumOfItems)
		for (i = NumOfItems-1; i >= 0; i--)
			if (strlen(df) && !stringmatch(GetWavesDataFolder(TraceNameToWaveRef(grfName,StringFromList(i,listStr)),1),df))
				continue
			endif
			RemoveFromGraph/W=$grfName $StringFromList(i,listStr)
		endfor
	endif
	listStr = ImageNameList(grfName,";")
	NumOfItems = ItemsInList(listStr)
	if (NumOfItems)
		for (i = NumOfItems-1; i >= 0; i--)
			if (strlen(df) && !stringmatch(GetWavesDataFolder(ImageNameToWaveRef(grfName,StringFromList(i,listStr)),1),df))
				continue
			endif
			RemoveImage/W=$grfName $StringFromList(i,listStr)
		endfor
	endif
	return 0
End

Function/S KMNewPanel(String title, Variable width, Variable height,
	[Variable float, Variable nofixed, Variable kill])
	deprecatedCaution("SIDAMNewPanel")
	float = (ParamIsDefault(float) || !float) ? 0 : 1
	nofixed = (ParamIsDefault(nofixed) || !nofixed) ? 0 : 1
	return SIDAMNewPanel(title, width, height, float=float, resizable=nofixed)
End

Function KMWaveSelector(String title, String listStr, [String grfName])
	deprecatedCaution("")
End

Function/WAVE KM_GetColorTableMinMax(String grfName, String imgName)
	deprecatedCaution("SIDAM_GetColorTableMinMax")
	Variable zmin, zmax
	SIDAM_GetColorTableMinMax(grfName,imgName,zmin,zmax)
	Make/D/FREE/N=2 rw = {zmin, zmax}
	return rw
End

Function isFirstZAuto(String grfName, String imgName)
	deprecatedCaution("")
End

Function isLastZAuto(String grfName, String imgName)
	deprecatedCaution("")
End

//	v8.1.4 ----------------------------------------------------------------------
Function KM_ImageColorMinRGBValues(String grfName, String imgName, STRUCT RGBColor &s)
	deprecatedCaution("SIDAM_ImageColorRGBMode")
	SIDAM_ImageColorRGBValues(grfName, imgName, "minRGB", s)
End

Function KM_ImageColorMaxRGBValues(String grfName, String imgName, STRUCT RGBColor &s)
	deprecatedCaution("SIDAM_ImageColorRGBMode")
	SIDAM_ImageColorRGBValues(grfName, imgName, "maxRGB", s)
End

Function KM_ImageColorMinRGBMode(String grfName, String imgName)
	deprecatedCaution("SIDAM_ImageColorRGBMode")
	return SIDAM_ImageColorRGBMode(grfName,imgName,"minRGB")
End

Function KM_ImageColorMaxRGBMode(String grfName, String imgName)
	deprecatedCaution("SIDAM_ImageColorRGBMode")
	return SIDAM_ImageColorRGBMode(grfName,imgName,"maxRGB")
End

Function KM_ColorTableLog(String grfName, String imgName)
	deprecatedCaution("SIDAM_ColorTableLog")
	return SIDAM_ColorTableLog(grfName, imgName)
End

Function KMColor([String grfName, String imgList, String ctable, int rev, int log,
	Wave minRGB, Wave maxRGB, int history)
	deprecatedCaution("SIDAMColor")
	SIDAMColor(grfName=grfName, imgList=imgList, ctable=ctable, rev=rev, log=log,\
	minRGB=minRGB, maxRGB=minRGB, history=history)
End

Function KMWindowExists(String pnlName)
	deprecatedCaution("SIDAMWindowExists")
	return SIDAMWindowExists(pnlName)
End

Function/S KMDisplay([Wave/Z w, int traces, int history	])
	deprecatedCaution("SIDAMDisplay")
	SIDAMDisplay(w,traces=traces,history=history)
End

Function/S KMAddCheckmark(Variable num, String menuStr)
	deprecatedCaution("SIDAMAddCheckmark")
	SIDAMAddCheckmark(num, menuStr)
End

Function/S KMGetPath()
	deprecatedCaution("SIDAMPath")
	SIDAMPath()
End

Function/S KMUnquoteName(String str)
	deprecatedCaution("")
	if (!CmpStr("'",str[strlen(str)-1]))
		str = str[0,strlen(str)-2]
	endif
	if (!CmpStr("'",str[0]))
		str = str[1,strlen(str)-1]
	endif
	return str
End

//	v8.1.3 ----------------------------------------------------------------------
Function/WAVE KMLoadData(String pathStr, [int folder, int history])
	deprecatedCaution("SIDAMWindowExists")
	return SIDAMLoadData(pathStr, folder=folder, history=history)
End

//	v8.1.0 ----------------------------------------------------------------------
Structure KMMousePos
	//	入力
	STRUCT WMWinHookStruct winhs
	uchar	grid
	//	出力
	String	xaxis
	String	yaxis
	String	name
	float		x
	float		y
	Variable/C	z
	float		p
	float		q
	Wave	w
EndStructure

Function KMGetMousePos(s, [winhs, grid])
	STRUCT KMMousePos &s
	STRUCT WMWinHookStruct &winhs
	Variable grid

	deprecatedCaution("SIDAMGetMousePos")

	if (!ParamIsDefault(winhs))
		s.winhs = winhs
	endif
	if (!ParamIsDefault(grid))
		s.grid = grid
	endif

	//	ショートカット
	String grfName = s.winhs.winName
	Variable h = s.winhs.mouseLoc.h, v = s.winhs.mouseLoc.v

	//	グラフ表示域だけで有効にする。
	GetWindow $grfName, psizeDC
	if (h < V_left || h > V_right || v > V_bottom || v < V_top)
		return 2
	endif

	Variable swap = strsearch(WinRecreation(grfName,1), "swapXY", 4) != -1
	Variable imageExist = strlen(ImageNameList(grfName, ";"))

	if (imageExist)		//	イメージが存在する場合にはそちらを優先
		s.xaxis = StringByKey("XAXIS", ImageInfo(grfName,"",0))
		s.yaxis = StringByKey("YAXIS", ImageInfo(grfName,"",0))
		Variable tx = AxisValFromPixel(grfName, s.xaxis, (swap ? v : h))
		Variable ty = AxisValFromPixel(grfName, s.yaxis, (swap ? h : v))
		Wave/Z s.w = KMGetMousePosWave(tx, ty, grfName)
		if (!WaveExists(s.w))	//	マウスカーソルがイメージ上にない場合には false
			s.p = NaN ;	s.q = NaN ;	s.x = NaN ;	s.y = NaN ;	s.z = NaN
			s.name = ""
			return 1
		endif
		Variable ox = DimOffset(s.w,0), oy = DimOffset(s.w,1)
		Variable dx = DimDelta(s.w,0), dy = DimDelta(s.w,1)
		tx = limit(tx, min(ox,ox+dx*(DimSize(s.w,0)-1)), max(ox,ox+dx*(DimSize(s.w,0)-1)))
		ty = limit(ty, min(oy,oy+dy*(DimSize(s.w,1)-1)), max(oy,oy+dy*(DimSize(s.w,1)-1)))
		Variable tp = (tx-ox)/dx, tq = (ty-oy)/dy
		s.p = s.grid ? round(tp) : tp
		s.q = s.grid ? round(tq) : tq
		s.x = s.grid ? (ox + dx * s.p) : tx
		s.y = s.grid ? (oy + dy * s.q) : ty
		Variable layer = NumberByKey("plane", ImageInfo(grfName, NameOfWave(s.w), 0), "=")	//	現在の表示レイヤー
		//	ウエーブが2次元だと layer には NaN が入るが下の式で問題なく動作する
		s.z = s.w(tx)(ty)[layer]
		s.name = NameOfWave(s.w)
		return 0

	else		//	トレースのみ
		String trcName = StringFromList(0, TraceNameList(grfName, ";", 1))
		if (!strlen(trcName))
			return 2
		endif
		s.xaxis = StringByKey("XAXIS",TraceInfo(grfName, trcName, 0))
		s.yaxis = StringByKey("YAXIS",TraceInfo(grfName, trcName, 0))
		Wave/Z s.w = TraceNameToWaveRef(grfName,trcName)
		s.name = trcName
		s.x = AxisValFromPixel(grfName, s.xaxis, (swap ? v : h))
		s.y = AxisValFromPixel(grfName, s.yaxis, (swap ? h : v))
		s.z = NaN
		s.p = NaN
		s.q = NaN
		return 0
	endif
End

//	マウスカーソルが乗っているイメージへの参照を返す
Static Function/WAVE KMGetMousePosWave(xvalue, yvalue, grfName)
	Variable xvalue, yvalue
	String grfName

	String winNameList = ImageNameList(grfName,";")
	int n = ItemsInList(winNameList), i

	for (i = n-1; i >= 0; i--)		//	リストの後ろにあるものが上に表示されている
		Wave w = ImageNameToWaveRef(grfName, StringFromList(i, winNameList))
		Variable nx = DimSize(w,0), ny = DimSize(w,1)
		Variable dx = DimDelta(w,0), dy = DimDelta(w,1)
		Variable ox = DimOffset(w,0), oy = DimOffset(w,1)
		Variable x0 = min(ox, ox+dx*(nx-1))-dx/2, y0 = min(oy, oy+dy*(ny-1))-dy/2
		Variable x1 = max(ox, ox+dx*(nx-1))+dx/2, y1 = max(oy, oy+dy*(ny-1))+dy/2
		Variable inRangeX = (xvalue-x0) * (xvalue-x1) < 0
		Variable inRangeY = (yvalue-y0) * (yvalue-y1) < 0
		if ( inRangeX && inRangeY )
			return w
		endif
	endfor

	return $""		//	全てのウエーブの範囲外にある場合は空文字列
End
