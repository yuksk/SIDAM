#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3
#pragma moduleName = KMFourierPeak

#ifndef SIDAMshowProc
#pragma hide = 1
#endif

//-------------------------------------------------------------
//	マーキーメニュー実行用
//-------------------------------------------------------------
Static Function marqueeDo(int mode)
	//	ピーク位置取得
	String grfName = WinName(0,1)
	Wave iw = SIDAMImageWaveRef(grfName)
	try
		Wave posw = KMFourierPeakGetPos(iw, mode, marquee=1)
	catch
		DoAlert 0, "Failed to fit "+num2istr(V_AbortCode)
		return 0
	endtry
	
	//	結果の出力　（ウエーブ）
	DFREF dfrSav = GetDataFolderDFR()
	SetDataFolder GetWavesDataFolderDFR(iw)
	String name = Uniquename("peakPos",1,0)
	Duplicate posw $name
	SetDataFolder dfrSav
	
	//	結果の出力　（ウエーブ & アラート）
	Make/N=5 $(Uniquename("wave",1,0))/WAVE=xw={-posw[%xwidthneg], posw[%xwidthpos], nan, 0, 0}
	Make/N=5 $(Uniquename("wave",1,0))/WAVE=yw={0,0,nan,-posw[%ywidthneg], posw[%ywidthpos]}
	Make/N=5 $(Uniquename("wave",1,0))/WAVE=xw2
	Make/N=5 $(Uniquename("wave",1,0))/WAVE=yw2
	xw2 = xw*cos(posw[%angle]) - yw*sin(posw[%angle]) + posw[%xcenter]
	yw2 = xw*sin(posw[%angle]) + yw*cos(posw[%angle]) + posw[%ycenter]
	AppendToGraph/W=$grfName yw2 vs xw2
	ModifyGraph/W=$grfName mode($NameOfWave(yw2))=0, mrkThick($NameOfWave(yw2))=1, rgb($NameOfWave(yw2))=(65535,0,52428)
	String msg0, msg1
	sprintf msg0, "Output wave: %s\rPosition: (%g, %g)\r", GetWavesDataFolder(iw,1)+name, posw[%xcenter], posw[%ycenter]
	sprintf msg1, "x width: (%g, %g)\ry width: (%g, %g)\rangle: %g degree", posw[%xwidthneg], posw[%xwidthpos], posw[%ywidthneg], posw[%ywidthpos], posw[%angle]/pi*180
	DoUpdate/W=$grfName
	DoAlert 0, msg0+msg1
	RemoveFromGraph/W=$grfName $NameOfWave(yw2)
	KillWaves xw, yw, xw2, yw2
End
//-------------------------------------------------------------
//	マーキーメニュー文字列
//-------------------------------------------------------------
Static Function/S marqueeMenu(int mode)
	Wave/Z w = SIDAMImageWaveRef(WinName(0,1))	
	
	//	ウエーブが存在しない、存在しても複素数ウエーブ
	if (!WaveExists(w) || (WaveType(w) & 0x01))
		return ""
	endif
	
	String rtnStr = "asymmetric "
	return rtnStr + SelectString(mode, "Gauss2D", "Lorentz2D")
End

//******************************************************************************
//	フィッティングによりピーク位置を求める
//******************************************************************************
Function/WAVE KMFourierPeakGetPos(
	Wave w,		//	範囲指定された2Dウエーブ, マーキーで範囲を指定する
	int fitfn,	//	フィッティング関数 0: asymGauss2D, 1: asymLor2D
	[
		int marquee	//	マーキーで範囲を指定する場合は 1
	])
	
	//	マーキーによる範囲指定をするかどうか
	marquee = ParamIsDefault(marquee) ? 0 : marquee
	if (marquee)
		Wave mw = SIDAMGetMarquee(0)
		if (WaveDims(w)==3)
			//	3Dウエーブの場合は表示されているレイヤーについてピーク位置を求める
			Duplicate/R=[mw[0][0],mw[0][1]][mw[1][0],mw[1][1]][KMLayerViewerDo(WinName(0,1))]/FREE w, tw
			Redimension/N=(-1,-1) tw
		else
			Duplicate/R=[mw[0][0],mw[0][1]][mw[1][0],mw[1][1]]/FREE w, tw
		endif
	else
		Duplicate/FREE w, tw
	endif
	
	DFREF dfrSav = GetDataFolderDFR()
	SetDataFolder NewFreeDataFolder()
	Variable V_FitError	
	
	//	初期変数の見当を付けるためにGauss2Dを使う
	CurveFit/M=2/W=2/N=1/Q Gauss2D, tw/D
	AbortOnValue V_FitError, 21
	Wave cw = W_coef
	
	//	指定された関数でフィッティング
	Variable fitResult = 0
	Make/D/N=9 initcoef = {cw[0],cw[1],cw[2],cw[4],cw[3],cw[3],cw[5],cw[5],0}
	
	Make/D angles = {pi/6, -pi/6}				//	初期角度
	Make/D/N=(2,numpnts(angles)) results	//	[0][] = V_FitError, [1][] = V_chisq
	Make/WAVE/N=(numpnts(angles)) ww			//	coef
	ww = KMFourierPeakGetPosDoFit(fitfn, initcoef, angles, tw, results, p)
	
	//	全ての初期角度でフィットがうまくいかなければ中止
	Make/N=(numpnts(angles)) tw2
	tw2 = results[0][p]
	AbortOnValue WaveMin(tw2), 22
	
	//	最も良い結果を与えた初期角度からの結果を用いる
	tw2 = results[1][p]
	WaveStats/Q/M=1 tw2
	Wave coef = ww[V_minloc]
	
	//	DimLabel設定
	SetDimLabel 0, 0, offset, coef
	SetDimLabel 0, 1, amplitude, coef
	SetDimLabel 0, 2, xcenter, coef
	SetDimLabel 0, 3, ycenter, coef
	SetDimLabel 0, 4, xwidthpos, coef
	SetDimLabel 0, 5, xwidthneg, coef
	SetDimLabel 0, 6, ywidthpos, coef
	SetDimLabel 0, 7, ywidthneg, coef
	SetDimLabel 0, 8, angle, coef
	
	SetDataFolder dfrSav
	return coef
End

Static Function/WAVE KMFourierPeakGetPosDoFit(int fitfn, Wave initcoef, Wave angle, Wave w, Wave results, int index)
	Duplicate/FREE initcoef, coef
	coef[8] = angle[index]
	Variable V_FitError, V_chisq
	Make/T/FREE T_constraint = {"K8 <= pi/4", "K8 >= -pi/4", "K4 > 0", "K5 > 0", "K6 > 0", "K7 > 0"}
	switch (fitfn)
		case 0:	//	asymmetric gauss2D
			FuncFitMD/N=1/Q/W=2 KMFourierPeak#asymGauss2D coef w /D /C=T_constraint
			break
		case 1:	//	asymmetric lorentz2D
			FuncFitMD/N=1/Q/W=2 KMFourierPeak#asymLor2D coef w /D /C=T_constraint
			break
	endswitch
	results[0][index] = V_FitError
	results[1][index] = V_chisq
	return coef
End


//--------------------------------------------------------------------------------
//	フィッティング関数
//--------------------------------------------------------------------------------
Function KMFit2DPrototype(Wave w, Variable x, Variable y)
End

ThreadSafe Static Function asymGauss2D(Wave w, Variable x, Variable y)
	Variable cx = x-w[2], cy = y-w[3]
	//	角度(w[8])が0のときには、cx と cy の正負が場合分けの条件になる
	//	角度が有限のときには、cx > 0 は　cy > tan(w[8]+pi/2)*cx に、cy > 0 は cy > tan(w[8])*x　になる
	Variable wx, wy
	if (w[8] > 0)
		wx = (cy > tan(w[8]+pi/2)*cx) ? w[4] : w[5]
		wy = (cy > tan(w[8])*cx) ? w[6] : w[7]
	elseif (w[8] < 0)
		wx = (cy < tan(w[8]+pi/2)*cx) ? w[4] : w[5]
		wy = (cy > tan(w[8])*cx) ? w[6] : w[7]
	else
		wx = cx > 0 ? w[4] : w[5]
		wy = cy > 0 ? w[6] : w[7]
	endif
	Variable cx2 = cx*cos(w[8]) + cy*sin(w[8]), cy2 = cx*sin(w[8]) - cy*cos(w[8])
	return w[0] + w[1]*exp(-(cx2/wx)^2)*exp(-(cy2/wy)^2)
End

ThreadSafe Static Function asymLor2D(Wave w, Variable x, Variable y)
	Variable cx = x-w[2], cy = y-w[3]
	Variable cx2 = cx*cos(w[8]) + cy*sin(w[8]), cy2 = -cx*sin(w[8]) + cy*cos(w[8])
	//	角度(w[8])が0のときには、cx と cy の正負が場合分けの条件になる
	//	角度が有限のときには、cx > 0 は　cy > tan(w[8]+pi/2)*cx に、cy > 0 は cy > tan(w[8])*x　になる
	Variable wx, wy
	if (w[8] > 0)
		wx = (cy > tan(w[8]+pi/2)*cx) ? w[4] : w[5]
		wy = (cy > tan(w[8])*cx) ? w[6] : w[7]
	elseif (w[8] < 0)
		wx = (cy < tan(w[8]+pi/2)*cx) ? w[4] : w[5]
		wy = (cy > tan(w[8])*cx) ? w[6] : w[7]
	else
		wx = cx > 0 ? w[4] : w[5]
		wy = cy > 0 ? w[6] : w[7]
	endif
	return w[0] + w[1]*wx^2/(cx2^2+wx^2)*wy^2/(cy2^2+wy^2)
End
