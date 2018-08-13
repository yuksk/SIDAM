#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3	

#ifndef SIDAMstarting
#include "KM Utilities_Str"		//	for KMUnquoteName
#endif

#ifndef SIDAMshowProc
#pragma hide = 1
#endif

#ifdef SIDAMstarting
// Update All KM Procedures.ipf for backward compatibility
Function SIDAMBackwardCompatibility()
	updateOldIncludeFile()
	updateOldPackageFile()
End
#endif

#ifndef SIDAMstarting
Function SIDAMBackwardCompatibility()
	//	Change the unit string from ﾅ \u00c5 (Igor Pro 6 -> 7)
	angstromStr(root:)

	//	Rename the temporary folder from '_KM' to '_SIDAM'
	updateTemporaryDF("")

	//	If All KM Procedures.ipf is included, it means that this function is called in opening 
	//	an experiment file in which KM was used and that #include "All KM Procedures" exists
	//	in the procedure window. The following is to remove the dependence to the old file.
	if (strlen(WinList(KM_FILE_INCLUDE+".ipf",";","WIN:128")) > 0)
		Execute/P "DELETEINCLUDE \"" + KM_FILE_INCLUDE + "\""
		Execute/P "INSERTINCLUDE \"" + SIDAM_FILE_INCLUDE + "\""
		Execute/P "COMPILEPROCEDURES "
	endif
End
#endif

//--------------------------------------------------------------------------------------

#ifdef SIDAMstarting

Static Function updateOldIncludeFile()
	Variable refNum
	String pathStr = SpecialDirPath("Igor Pro User Files", 0, 0, 0) + "User Procedures:"
	String pathName = UniqueName("path",12,0)
	NewPath/Q $pathName, pathStr
	Open/P=$pathName/Z refNum, as KM_FILE_INCLUDE+".ipf"
	if (!V_flag)
		fprintf refNum, "//\tThis file is left for backward compatibility to prevent a compile error\r"
		fprintf refNum, "//\tin opening an experiment file created by Kohsaka Macro. You can remove\r"
		fprintf refNum, "//\tthis file and solve the error by yourself. In the error dialog saying\r"
		fprintf refNum, "//\t\"include file not found\", you can edit the command from '#include \"All\r"
		fprintf refNum, "//\tKM Procedures\"' to '#include \"SIDAM_Procedures\" and click the Retry button.\r"
		fprintf refNum, "#include \"%s\"\r", SIDAM_FILE_INCLUDE
		Close refNum
	endif
	KillPath $pathName
End

Static Function updateOldPackageFile()
	String packages = SpecialDirPath("Packages",0,0,0)
	MoveFolder/Z packages+"Kohsaka Macro" as packages+"SIDAM"
	if (V_flag)	//	Old directory did not exist
		return 0
	endif
	MoveFile/Z packages+"SIDAM:KM.bin" as packages+"SIDAM:SIDAM.bin"
End
#endif

//--------------------------------------------------------------------------------------

#ifndef SIDAMstarting

Static Function angstromStr(DFREF dfr)
	int i, n, dim
	
	for (i = 0, n = CountObjectsDFR(dfr, 4); i < n; i++)
		angstromStr(dfr:$GetIndexedObjNameDFR(dfr, 4, i))
	endfor
	
	for (i = 0, n = CountObjectsDFR(dfr, 1); i < n; i++)
		Wave/SDFR=dfr w = $GetIndexedObjNameDFR(dfr, 1, i)
		for (dim = -1; dim <= 3; dim++)
			changeUnitStr(w, dim)
		endfor
	endfor
End

Static Function changeUnitStr(Wave w, int dim)
	String oldUnit = "ﾅ"
	String newUnit = "\u00c5"
	String unit = WaveUnits(w,dim)
	
	if (CmpStr(ConvertTextEncoding(unit,4,1,3,0), oldUnit) && CmpStr(unit, oldUnit))
		return 0
	endif
	
	SetWaveTextEncoding 1,2, w
	switch (dim)
		case -1:
			Setscale d, WaveMin(w), WaveMax(w), newUnit, w
			break
		case 0:
			Setscale/P x DimOffset(w,0), DimDelta(w,0), newUnit, w
			break
		case 1:
			Setscale/P y DimOffset(w,1), DimDelta(w,1), newUnit, w
			break
		case 2:
			Setscale/P z DimOffset(w,2), DimDelta(w,2), newUnit, w
			break
		case 3:
			Setscale/P t DimOffset(w,3), DimDelta(w,3), newUnit, w
			break
	endswitch
	
	return 1
End

//--------------------------------------------------------------------------------------

StrConstant OLD_DF = "root:'_KM'"

Static Function updateTemporaryDF(String listStr)
	if (!strlen(listStr))
		listStr = WinList("*",";","WIN:1")
	endif
	
	int i, j
	String win, chdList, dfTmp
	for (i = 0; i < ItemsInList(listStr); i++)
		win = StringFromList(i,listStr)
		chdList = ChildWindowList(win)
		if (strlen(chdList))
			for (j = 0; j < ItemsInList(chdList); j++)
				updateTemporaryDF(win+"#"+StringFromList(j,chdList))
			endfor
		endif
		dfTmp = GetUserData(win,"","dfTmp")
		if (!strlen(dfTmp))
			continue
		endif
		SetWindow $win userData(dfTmp) = ReplaceString(OLD_DF,dfTmp,SIDAM_DF)
	endfor
	
	if (DataFolderExists(OLD_DF))
		RenameDataFolder $OLD_DF $KMUnquoteName(StringFromList(1,SIDAM_DF,":"))
	endif
	
	if (DataFolderExists(SIDAM_DF_CTAB+"KM"))
		RenameDataFolder $(SIDAM_DF_CTAB+"KM") SIDAM
	endif
End

//--------------------------------------------------------------------------------------


//******************************************************************************
//	deprecated functions, to be removed in future
//******************************************************************************
//	v8.1.0 ----------------------------------------------------------------------
//******************************************************************************
//	KMGetMousePos
//		マウスカーソル位置の座標を取得します
//******************************************************************************
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

	printf "%sKMGetMousePos is deprecated and will be removed.\r", PRESTR_CAUTION
	printf "%sUse SIDAMGetMousePos.\r", PRESTR_CAUTION
		
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

//	v8.0.2 ----------------------------------------------------------------------
Function/S KMSuffixStr(num,[digit])
	int num, digit
	
	if (ParamIsDefault(digit))
		digit = 3
	endif
	
	String rtnStr = num2str(num)
	int digitOfNum = abs(num) ? floor(log(num))+1 : 1
	int i
	
	for (i = digitOfNum; i < digit; i++)
		rtnStr = "0"+rtnStr
	endfor
	
	printf "%sKMSuffixStr is deprecated and will be removed.\r", PRESTR_CAUTION
	printf "%sUse %s%dd in the format string of prinf.\r", PRESTR_CAUTION, "%0", digit
	
	return rtnStr
End

Function KMCtrlClicked(STRUCT WMWinHookStruct &s, String grpName)
	printf "%sKMCtrlClicked is deprecated and will be removed.\r", PRESTR_CAUTION
	ControlInfo/W=$s.winName $grpName
	return (V_left < s.mouseLoc.h && s.mouseLoc.h < V_left + V_width && V_top < s.mouseLoc.v && s.mouseLoc.v < V_top + V_height)
End


#endif