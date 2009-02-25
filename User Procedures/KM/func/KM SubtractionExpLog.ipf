#pragma TextEncoding="UTF-8"
#pragma rtGlobals=1

#ifndef KMshowProcedures
#pragma hide = 1
#endif

Static Constant k__FitMaxIters = 256

Function/WAVE KMExpLogSubtraction(w, mode, direction)
	Wave w					//	入力ウエーブ
	Variable mode		//	0: single exponetial, 1, double exponential, 2, log
	Variable direction	//	bit 0: slow scan方向　0: x, 1: y
							//	bit 1: x方向のスキャン方向	0: 順(左から右), 1: 逆
							//	bit 2: y方向のスキャン方向	0: 順(下から上), 1: 逆
	
	Variable isYslow = direction & 1
	Variable isXrev = direction & 2
	Variable isYrev = direction & 4
	Variable V_fitOptions=4, V_FitMaxIters = k__FitMaxIters
	
	DFREF dfrSav = GetDataFolderDFR()
	SetDataFolder NewFreeDataFolder()
	
	//	フィット用の一時ウエーブを用意する
	Duplicate w tw
	SetScale/P x 0, 1, "", tw		//	フィットする式に合わせる
	SetScale/P y 0, 1, "", tw		//	同上
	//	逆順であればひっくり返しておく
	if (isXrev)
		Reverse/P/DIM=0 tw
	endif
	if (isYrev)
		Reverse/P/DIM=1 tw
	endif
	
	//	2次元フィットの初期値を得る
	try
		Wave coefw = KMExpLogSubtractionInitGuess(w, mode, direction)
	catch
		printf  "**KMSubtraction gave an error: %s in getting initial values.\r", GetErrMessage(GetRTError(1))
		SetDataFolder dfrSav
		Abort
	endtry
	
	Variable n = numpnts(coefw)
	Redimension/N=(n+3) coefw
	if (isYslow)
		coefw[n-1] = {0, 0, 1, DimSize(w,0)}	//	最後の2つは変数ではなく、slow scan方向を定義するために与える定数
	else
		coefw[n-1] = {0, 0, DimSize(w,1), 1}	//	同上
	endif

	//	2次元フィット
	//	フィッティング変数を一部固定化することでslow scan方向に関する情報を渡している
	//	構造体を使うのが本来のやり方だろうが、そうするとなぜか遅くなる
	try
		switch (mode)
			case 0:		//	single exp
				FuncFitMD/NTHR=0/Q/H="0000011" KMExpSubtractionFit2Ds coefw tw /D /R;		AbortOnRTE
				break
			case 1:		//	double exp
				FuncFitMD/NTHR=0/Q/H="000000011" KMExpSubtractionFit2Dd coefw tw /D /R;		AbortOnRTE
				break
			case 2:		//	log
				FuncFitMD/NTHR=0/Q/H="0000011" KMLogSubtractionFit2D coefw tw /D /R;		AbortOnRTE
				break
		endswitch
	catch
		printf  "**KMSubtraction gave an error: %s in 2D fitting.\r", GetErrMessage(GetRTError(1))
		SetDataFolder dfrSav
		Abort
	endtry
	
	Wave resw = Res_tw
	Redimension/S resw
		
	//	ひっくり返したものを元に戻す
	if (isXrev)
		Reverse/P/DIM=0 resw
	endif
	if (isYrev)
		Reverse/P/DIM=1 resw
	endif
	
	//	スケールを合わせる
	CopyScales w resw
	
	SetDataFolder dfrSav
	
	//	結果表示
	String str, noteStr = ""
	switch (mode)
		case 0:		//	single exp
			sprintf str, "subtracted plane (A*exp(-n/tau)+ap+bq+c)"
			print str	;	noteStr += str + "\r"
			sprintf str, "A: %f\ttau: %e\t(tau/N: %f)", coefw[1], coefw[2], coefw[2]/numpnts(w)
			print str	;	noteStr += str + "\r"
			sprintf str, "a: %e\tb: %e\tc: %e\t(%f [deg])", coefw[3], coefw[4], coefw[0], acos((coefw[3]^2+coefw[4]^2+1)^-0.5)/pi*180
			print str	;	noteStr += str + "\r"
			break
		case 1:		//	double exp
			sprintf str, "subtracted plane (A1*exp(-n/tau1)+A2*exp(-n/tau2)+ap+bq+c)"
			print str	;	noteStr += str + "\r"
			sprintf str, "A1: %f\ttau1: %e\t(tau1/N: %f)", coefw[1], coefw[2], coefw[2]/numpnts(w)
			print str	;	noteStr += str + "\r"
			sprintf str, "A2: %f\ttau2: %e\t(tau2/N: %f)", coefw[3], coefw[4], coefw[4]/numpnts(w)
			print str	;	noteStr += str + "\r"
			sprintf str, "a: %e\tb: %e\tc: %e\t(%f [deg])", coefw[5], coefw[6], coefw[0], acos((coefw[5]^2+coefw[6]^2+1)^-0.5)/pi*180
			print str	;	noteStr += str + "\r"
			break
		case 2:		//	log
			sprintf str, "subtracted plane (A*log(n+B)+ap+bq+c)"
			print str	;	noteStr += str + "\r"
			sprintf str, "A: %f\tB: %f", coefw[1], coefw[2]
			print str	;	noteStr += str + "\r"
			sprintf str, "a: %e\tb: %e\tc: %e\t(%f [deg])", coefw[3], coefw[4], coefw[0], acos((coefw[3]^2+coefw[4]^2+1)^-0.5)/pi*180
			print str	;	noteStr += str + "\r"
			break
	endswitch
	sprintf str, "chisq: %f", V_chisq
	print str	;	noteStr += str
	Note resw, noteStr
	
	return resw
End
//-------------------------------------------------------------
//	KMExpLogSubtractionInitGuess
//		2次元フィットの初期値を与える
//-------------------------------------------------------------
Static Function/WAVE KMExpLogSubtractionInitGuess(w, mode, direction)
	Wave w
	Variable mode, direction
	
	Variable V_fitOptions=4, V_FitMaxIters = k__FitMaxIters
	
	DFREF dfrSav = GetDataFolderDFR()
	SetDataFolder NewFreeDataFolder()
	
	Wave tw = KMExpLogSubtractionChrono(w, direction)
	switch (mode)
		case 0:		//	single exp
			CurveFit/NTHR=0/Q exp_XOffset tw /D;	AbortOnRTE
			Wave coefw = W_coef
			Redimension/N=4 coefw
			coefw[3] = {0}
			FuncFit/NTHR=0/Q KMExpSubtractionFit1Ds coefw tw /D;	AbortOnRTE
			break
		case 1:		//	double exp
			CurveFit/NTHR=0/Q dblexp_XOffset tw /D;	AbortOnRTE
			Wave coefw = W_coef
			Redimension/N=6 coefw
			coefw[5] = {0}
			FuncFit/NTHR=0/Q KMExpSubtractionFit1Dd coefw tw /D;	AbortOnRTE
			break
		case 2:		//	log
			Make/N=4 coefw = {tw[0], WaveMax(tw)-WaveMin(tw), numpnts(tw)/10, 0}
			break
	endswitch

	SetDataFolder dfrSav
	
	return coefw
End
//-------------------------------------------------------------
//	KMExpLogSubtractionChrono
//		時間順に一次元化する
//-------------------------------------------------------------
Static Function/WAVE KMExpLogSubtractionChrono(w, direction)
	Wave w
	Variable direction
	
	Variable isYslow = direction & 1
	Variable isXrev = direction & 2
	Variable isYrev = direction & 4
	Variable nx = DimSize(w,0), ny = DimSize(w,1)
	
	//	逆順であればひっくり返しておく
	Duplicate/FREE w tw
	if (isXrev)
		Reverse/P/DIM=0 tw
	endif
	if (isYrev)
		Reverse/P/DIM=1 tw
	endif
		
	//	時間順に並べる
	if (isYslow)
		Make/N=(nx*ny)/FREE tw2
		MultiThread tw2 = tw[mod(p,nx)][floor(p/nx)]
	else
		Make/N=(nx*ny)/FREE tw2
		MultiThread tw2 = tw[floor(p/ny)][mod(p,ny)]
	endif
	
	return tw2
End
//-------------------------------------------------------------
//	フィッティング用関数
//-------------------------------------------------------------
Function KMExpSubtractionFit1Dd(w,x)
	Wave w
	Variable x
	
	return w[0] + w[1]*exp(-x/w[2]) + w[3]*exp(-x/w[4]) + w[5]*x
End

Function KMExpSubtractionFit1Ds(w,x)
	Wave w
	Variable x
	
	return w[0] + w[1]*exp(-x/w[2]) + w[3]*x
End

Function KMExpSubtractionFit2Dd(w,x,y)
	Wave w
	Variable x, y
	
	Variable v = w[7]*x+w[8]*y		//	直接代入するより、このように分ける方が少し速い
	return w[0] + w[1]*exp(-v/w[2]) + w[3]*exp(-v/w[4]) + w[5]*x + w[6]*y
End

Function KMExpSubtractionFit2Ds(w,x,y)
	Wave w
	Variable x, y
	
	return w[0] + w[1]*exp(-(w[5]*x+w[6]*y)/w[2]) + w[3]*x + w[4]*y
End

Function KMLogSubtractionFit1D(w,x)
	Wave w
	Variable x
	
	return w[0] + w[1]*log(x+w[2]) + w[3]*x
End

Function KMLogSubtractionFit2D(w,x, y)
	Wave w
	Variable x, y
	
	return w[0] + w[1]*log(w[5]*x+w[6]*y+w[2]) + w[3]*x + w[4]*y
End
