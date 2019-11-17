#pragma TextEncoding="UTF-8"
#pragma rtGlobals=3
#pragma ModuleName=KMFFT

#include "SIDAM_Display"
#include "SIDAM_Preference"
#include "SIDAM_Compatibility_Old_Functions"
#include "SIDAM_Utilities_Bias"
#include "SIDAM_Utilities_Control"
#include "SIDAM_Utilities_Help"
#include "SIDAM_Utilities_Image"
#include "SIDAM_Utilities_Panel"
#include "SIDAM_Utilities_WaveDf"

#ifndef SIDAMshowProc
#pragma hide = 1
#endif

//  結果ウエーブの名前が指定されていないときに、入力ウエーブの名前の後ろにつけて
//  結果ウエーブの名前とするための文字列
Static StrConstant SUFFIX = "_FFT"

//  ウインドウ関数の名前
Static StrConstant WINFNLIST = "Bartlett;Blackman367;Blackman361;Blackman492;Blackman474;Cos1;Cos2;Cos3;Cos4;KaiserBessel20;KaiserBessel25;KaiserBessel30;Hamming;Hanning;Parzen;Poisson2;Poisson3;Poisson4;Riemann;Welch;none"
//	出力形式の名前
Static StrConstant OUTPUTLIST = "complex;real;magnitude;magnitude squared;phase;imaginary;normalized magnitude;normalized magnitude squared"

//******************************************************************************
//	KMFFT
//		入力変数のチェックとその内容に応じた各実行関数の呼び出し
//******************************************************************************
Function/WAVE KMFFT(
	Wave/Z w,				//	対象となる2Dウエーブもしくは3Dウエーブ
							//	省略時は、カレントデータフォルダに計算可能なウエーブがあれば、パネル表示
	[
		String result,	//	結果ウエーブの名前, 省略時は"_FFT"が入力ウエーブの名前の後ろについたもの
		String win,		//	FFT実行前に使用する窓関数の種類を指定する. 窓関数の種類は以下の通り
							//	Hanning, Hamming, Bartlett, Blackman, Welch
							//	IgorのImageWindowを使用しているので、Welch以外は関数の種類と名前もそのまま
							//	省略時は窓関数を使用しない
		int out,			//	出力形式を数字で指定する. 数字と形式の対応は以下の通り.
							//	1: complex, 2: real, 3: magnitude, 4: magnitude squared, 5 phase, 6: imaginary, 7: normalized magnitude, 8: normalized magnitude squared
							//	1-5はIgorのFFTとそのまま対応する. 省略時は3
		int subtract,	//	計算前に平均値を引く(1), 引かない(0), 省略時は0
		int history		//	履歴欄にコマンドを出力する(1), しない(0), 省略時は0
	])
	
	STRUCT paramStruct s
	Wave/Z s.w = w
	s.win = SelectString(ParamIsDefault(win), win, "none")
	s.out = ParamIsDefault(out) ? 3 : out
	s.subtract = ParamIsDefault(subtract) ? 0 : subtract
	s.result = SelectString(ParamIsDefault(result), result, NameOfWave(w)+SUFFIX)
	
	//	エラーチェック
	if (!isValidArguments(s))
		print s.errMsg
		return $""
	endif
	
	//  履歴欄出力
	if (!ParamIsDefault(history) && history == 1)
		print PRESTR_CMD + echoStr(w, s.result, s.win, s.out, s.subtract)
	endif
	
	//  実行
	if (WaveDims(w) == 2)
		Wave resw = KMFFT2D(w, s.win, s.out, s.subtract)
	elseif (WaveDims(w) == 3)
		Wave resw = KMFFT3D(w, s.win, s.out, s.subtract)
	endif
	DFREF dfr = GetWavesDataFolderDFR(w)
	Duplicate/O resw dfr:$s.result/WAVE=rtnw
	Note rtnw, StringFromList(s.out-1, OUTPUTLIST) + ", " + s.win 
	
	return rtnw
End

//-------------------------------------------------------------
//	チェック用関数
//-------------------------------------------------------------
Static Function isValidArguments(STRUCT paramStruct &s)
	s.errMsg = PRESTR_CAUTION + "KMFFT gave error: "
	
	String msg = KMFFTCheckWaveMsg(s.w)
	if (strlen(msg))
		s.errMsg += msg
		return 0
	endif
	
	if (s.out < 1 || s.out > 8)	//  出力形式
		s.errMsg += "out must be an integer between 1 and 8."
		return 0
	elseif (WhichListItem(s.win,WINFNLIST) < 0)	//  窓関数の種類
		s.errMsg += "such a window function is not found."
		return 0
	elseif (strlen(s.result) > MAX_OBJ_NAME)	//  結果ウエーブの名前
		s.errMsg += "length of name for output wave will exceed the limit ("+num2istr(MAX_OBJ_NAME)+" characters)."
		return 0
	endif
	
	s.subtract = s.subtract ? 1 : 0
	
	return 1
End
//-------------------------------------------------------------
//	KMFFTCheckWave
//		FFTを使うためのウエーブチェック, エラーが見つかった場合は対応する
//		メッセージを返す. 相関関数計算などFFTを使用する計算の前にもエラーチェックと
//		して使われている. (そのため、Staticを指定していない)
//-------------------------------------------------------------
Static Function WaveTypeForFFT(Wave/Z w)
	if (!WaveExists(w))
		return 1
	elseif (WaveDims(w) != 2 && WaveDims(w) != 3)
		return 2
	elseif (mod(DimSize(w,0),2))	//  x方向のデータ点数は偶数でなければならない
		return 3
	elseif (DimSize(w,0) < 4 || DimSize(w,1) < 4)	//  最低データ点数は4
		return 4
	elseif (WaveType(w,0) & 0x01)	//	複素数ウエーブなら
		return 5
	elseif (numtype(sum(w)))		//  NaN や INF を含んではならない, WaveStats を使うより速い
		return 6
	endif
	
	return 0
End

Function/S KMFFTCheckWaveMsg(Wave/Z w)
	Make/T/FREE msg = {\
		"",\
		"wave not found.",\
		"the dimension of input wave must be 2 or 3.",\
		"the first dimension of input wave must be an even number.",\
		"the minimum length of input wave is 4 points.",\
		"the input wave must be real.",\
		"the input wave must not contain NaNs or INFs."\
	}
	return msg[WaveTypeForFFT(w)]
End
	//	FFTに適したウエーブであるかチェックする場合
	//	KMFFTCheckWave を実行すると WaveStatsを使うことになるので、大きなウエーブを扱う際にはメニューの反応速度低下の原因となる
	//	そこで、最後にメニューが開かれたときからウエーブに更新があったかどうかを確認し、あった場合にのみ KMFFTCheckWave を実行するようにする
Function KMFFTCheckWaveMenu()
	String grfName = WinName(0,1)
	Wave/Z w = SIDAMImageWaveRef(grfName)
	if (!WaveExists(w))
		return 1
	endif
	
	Variable grfTime = str2num(GetUserData(grfName, "", "modtime"))
	Variable wTime = NumberByKey("MODTIME", WaveInfo(w, 0))
	Variable fftavailable = str2num(GetUserData(grfName, "", "fftavailable"))
	//	最後にメニューを開いたときからウエーブに変更があった場合 or 記録がない場合
	if (wTime > grfTime || numtype(grfTime) || numtype(fftavailable))
		fftavailable = !WaveTypeForFFT(w)
		SetWindow $grfName userData(modtime)=num2istr(wTime)				//	更新時間を更新
		SetWindow $grfName userData(fftavailable)=num2istr(fftavailable)	//	表示情報を更新
	endif
	
	return !fftavailable
End

Static Structure paramStruct
	Wave	w
	String	errMsg
	String	result
	String	win
	uint16	out
	uint16	subtract
EndStructure

//-------------------------------------------------------------
//	履歴欄出力用文字列作成
//-------------------------------------------------------------
Static Function/S echoStr(Wave w, String result, String win, int out, int subtract)
	String paramStr = GetWavesDataFolder(w,2)
	paramStr += SelectString(CmpStr(result, NameOfWave(w)+SUFFIX), "", ",result=\""+result+"\"")
	paramStr += SelectString(CmpStr(win, "none"), "", ",win=\""+win+"\"")
	paramStr += SelectString(out==3, ",out="+num2str(out), "")
	paramStr += SelectString(subtract, "", ",subtract="+num2str(subtract))
	Sprintf paramStr, "KMFFT(%s)", paramStr
	return paramStr
End

//-------------------------------------------------------------
//	右クリック用
//-------------------------------------------------------------
Static Function rightclickDo()
	pnl(SIDAMImageWaveRef(WinName(0,1)),WinName(0,1))
End


//=====================================================================================================


//******************************************************************************
//	KMFFT2D
//		実行関数: 2D
//		窓関数をかけてFFTを実行した後に、結果ウエーブを折り返して対称化する
//		対称化後の原点は[nx/2-1][ny/2] (第2象限) になる
//******************************************************************************
Static Function/WAVE KMFFT2D(Wave w, String winStr, int out, int subtract)
	
	Variable nx = DimSize(w,0), ny = DimSize(w,1)
	DFREF dfrSav = GetDataFolderDFR()
	SetDataFolder NewFreeDataFolder()
	
	//	規格化するかどうかを保存したのち、
	//	normalized magnitude (7), normalized magnitude squared (8) を、
	//	それぞれ、magnitude (3), magnitude squared (4) として扱う
	int normalize = (out >= 7) ? 1 : 0
	out -= (out >= 7) ? 4 : 0
	
	//  窓関数の用意
	int win = CmpStr(winStr,"none")
	if (win)
		Wave iw = imageWindowWave(nx, ny, winStr)
	endif
	
	//	平均を引く & 窓関数をかける & DP化
	if (subtract && win)
		MatrixOP/NTHR=0/FREE tw = (w-mean(w)) * iw	//	mean と iw によりDPになる
	elseif (subtract && !win)
		MatrixOP/NTHR=0/FREE tw = w-mean(w)			//	mean によりDPになる
	elseif (!subtract && win)
		MatrixOP/NTHR=0/FREE tw = w * iw				//	iw によりDPになる
	else
		MatrixOP/NTHR=0/FREE tw = fp64(w)			//	DPにする
	endif
		
	//  FFT実行
	//  虚部を求める場合には、一旦複素フーリエ変換を得て、そこから虚部だけを出力する
	//  FFT結果が複素数である場合には MatrixOP が速い
	//  FFT結果が実数である場合には FFT -> FastOP が速い
	switch (out)
		case 1:	//	complex
			MatrixOP fftw = FFT(tw, 0) / (nx * ny)
			break
		case 5:	//	phase
			FFT/OUT=(out)/DEST=fftw tw
			FastOp fftw = (180/pi) * fftw
			break
		case 6:	//  imaginary
			MatrixOP fftw = imag(FFT(tw, 0)) / (nx * nx)
			break
		default:	//  real, magnitude, magnitude squared
			FFT/OUT=(out)/DEST=fftw tw
			FastOP fftw = (1/nx/ny) * fftw
			break
	endswitch
	
	//	対称化する
	Wave resw = symmetrize(fftw, out)
	
	//	スケーリング代入
	//	MatixOPを使ってFFTを行った場合に備えて、元のウエーブからスケーリング値を求める
	Variable lx = DimSize(w,0)*DimDelta(w,0), ly = DimSize(w,1)*DimDelta(w,1)
	SetScale/P x -(DimSize(w,0)/2-1)/lx, 1/lx, changeUnit(WaveUnits(w,0)), resw
	SetScale/P y -DimSize(w,1)/2/ly, 1/ly, changeUnit(WaveUnits(w,1)), resw
	
	if (normalize)
		Variable s = 1/sum(resw)
		FastOP resw = (s) * resw
	endif
	
	//	SPに戻す
	if (NumberByKey("NUMTYPE",WaveInfo(w,0)) & 2)
		Redimension/S resw
	endif
		
	SetDataFolder dfrSav
	
	return resw
End

//-------------------------------------------------------------
//	窓関数への参照を返す
//-------------------------------------------------------------
Static Function/WAVE imageWindowWave(int nx, int ny, String win)
	int mx = (nx-1)/2, my = (ny-1)/2
	
	Make/D/N=(nx, ny)/FREE iw = 1
	Make/D/N=4/FREE cw
	
	strswitch (win)
		case "Hanning":
		case "Hamming":
		case "Bartlett":
		case "KaiserBessel20":
		case "KaiserBessel25":
		case "KaiserBessel30":
			ImageWindow/O $win iw
			break
		case "Blackman367":
			cw = {0.42323, 0.49755, 0.07922}
			MultiThread iw *= cw[0] - cw[1]*cos(2*pi*p/nx) + cw[2]*cos(4*pi*p/nx)
			MultiThread iw *= cw[0] - cw[1]*cos(2*pi*q/ny) + cw[2]*cos(4*pi*q/ny)
			break
		case "Blackman361":
			cw = {0.44959, 0.49364, 0.05677}
			MultiThread iw *= cw[0] - cw[1]*cos(2*pi*p/nx) + cw[2]*cos(4*pi*p/nx)
			MultiThread iw *= cw[0] - cw[1]*cos(2*pi*q/ny) + cw[2]*cos(4*pi*q/ny)
			break
		case "Blackman492":
			cw = {0.35875, 0.48829, 0.14128, 0.01168}
			MultiThread iw *= cw[0] - cw[1]*cos(2*pi*p/nx) + cw[2]*cos(4*pi*p/nx) - cw[3]*cos(6*pi*p/nx)
			MultiThread iw *= cw[0] - cw[1]*cos(2*pi*q/ny) + cw[2]*cos(4*pi*q/ny) - cw[3]*cos(6*pi*q/ny)
			break
		case "Blackman474":
			cw = {0.40217, 0.49703, 0.09392, 0.00183}
			MultiThread iw *= cw[0] - cw[1]*cos(2*pi*p/nx) + cw[2]*cos(4*pi*p/nx) - cw[3]*cos(6*pi*p/nx)
			MultiThread iw *= cw[0] - cw[1]*cos(2*pi*q/ny) + cw[2]*cos(4*pi*q/ny) - cw[3]*cos(6*pi*q/ny)
			break
		case "Cos1":
			MultiThread iw *= sin(pi*p/nx) * sin(pi*q/ny)
			break
		case "Cos2":
			MultiThread iw *= sin(pi*p/nx)^2 * sin(pi*q/ny)^2
			break
		case "Cos3":
			MultiThread iw *= sin(pi*p/nx)^3 * sin(pi*q/ny)^3
			break
		case "Cos4":
			MultiThread iw *= sin(pi*p/nx)^4 * sin(pi*q/ny)^4
			break
		case "Parzen":
			MultiThread iw *= (1 - ((2*p-nx)/nx)^2) * (1 - ((2*q-ny)/ny)^2)
			break
		case "Poisson2":
			MultiThread iw *= exp(-2*abs(p-nx/2)/nx) * exp(-2*abs(q-ny/2)/ny)
			break
		case "Poisson3":
			MultiThread iw *= exp(-3*abs(p-nx/2)/nx) * exp(-3*abs(q-ny/2)/ny)
			break
		case "Poisson4":
			MultiThread iw *= exp(-4*abs(p-nx/2)/nx) * exp(-4*abs(q-ny/2)/ny)
			break
		case "Riemann":
			MultiThread iw *= (p == nx/2) ? 1 : sin(2*pi*p/nx) / (pi - 2*pi*p/nx)
			MultiThread iw *= (q == ny/2) ? 1 : sin(2*pi*q/ny) / (pi - 2*pi*q/ny)
			break
		case "Welch":
			MultiThread iw *= (1-((p-mx)/mx)^2)*(1-((q-my)/my)^2)
			break
		default:	//  none
	endswitch
	
	return iw
End
//-------------------------------------------------------------
//	右半分から対称化ウエーブを作製する
//-------------------------------------------------------------
Static Function/WAVE symmetrize(Wave rw, int out)
	Duplicate/FREE rw, lw					//	左半分の用意
	Reverse/P/DIM=0 lw						//	上下左右反転する
	Reverse/P/DIM=1 lw
	DeletePoints/M=0 0, 1, lw				//	反転したものから左右1ピクセルずつ削除する
	DeletePoints/M=0 DimSize(lw,0)-1, 1, lw
	switch (out)							//	1つ上にずらす (ピクセル削除よりこれを先に行うとなぜかうまくいかない)
		case 1:		//	complex
			MatrixOP/NTHR=0/FREE resw = conj(rotateCols(lw,1))	//	複素数ウエーブの場合はここで複素共役をとっておく
			break
		case 5:		//	phase
		case 6:		//	imaginary
			MatrixOP/NTHR=0/FREE resw = -rotateCols(lw,1)
			break
		default:		//  real, magnitude, magnitude squared
			MatrixOP/NTHR=0/FREE resw = rotateCols(lw,1)
	endswitch
	Concatenate/NP=0 {rw}, resw			//	左半分と右半分をくっつける
	
	return resw
End
//-------------------------------------------------------------
//	FFTウエーブの単位を返す
//-------------------------------------------------------------
Static Function/S changeUnit(String unitStr)
	strswitch (unitStr)
		case "s":
		case "sec":
			return "Hz"
		case "Hz":
			return "s"
		default:
			if (!strlen(unitStr))
				return ""
			elseif (strsearch(unitStr,"^-1",0)>=0)
				return RemoveEnding(unitStr,"^-1")
			else
				return unitStr + "^-1"
			endif
	endswitch
End

//******************************************************************************
//	KMFFT3D	実行関数: 3D
//******************************************************************************
Static Function/WAVE KMFFT3D(Wave w, String winStr, int out, int subtract)
	
	Variable nx = DimSize(w,0), ny = DimSize(w,1)
	int win = CmpStr(winStr,"none"), i
	
	//  窓関数の用意	
	if (win)
		Wave iw = imageWindowWave(nx, ny, winStr)
	endif
	
	//	平均を引く & 窓関数をかける & DP化
	if (subtract && win)
		MatrixOP/NTHR=0/FREE srcw = (w[][][r]-mean(w[][][r])) * iw[][][0]　//	mean と iw によりDPになる
	elseif (subtract && !win)
		MatrixOP/NTHR=0/FREE srcw = w[][][r]-mean(w[][][r])	//	mean によりDPになる
	elseif (!subtract && win)
		MatrixOP/NTHR=0/FREE srcw = w * iw[][][0]	//	iw によりDPになる
	else
		MatrixOP/NTHR=0/FREE srcw = fp64(w)			//	DPにする
	endif
	
	//  FFT実行
	switch(out)
		case 1:	//	complex
			MatrixOP/NTHR=0/FREE tww = fft(srcw[][][r],0)/(nx*ny)
			break
		case 2:	//	real
			MatrixOP/NTHR=0/FREE tww = real(fft(srcw[][][r],0))/(nx*ny)
			break
		case 3:	//	mag
		case 7:	//	normalized magnitude
			MatrixOP/NTHR=0/FREE tww = abs(fft(srcw[][][r],0))/(nx*ny)
			break
		case 4:	//	magSqr
		case 8:	//	normalized magnitude squared
			MatrixOP/NTHR=0/FREE tww = magSqr(fft(srcw[][][r],0))/(nx*ny)
			break
		case 5:	//	phase
			MatrixOP/NTHR=0/FREE tww = phase(fft(srcw[][][r],0))*(180/pi)
			break
		case 6:	//	imag
			MatrixOP/NTHR=0/FREE tww = imag(fft(srcw[][][r],0))/(nx*ny)
			break
	endswitch
	
	//	対称化実行	
	Wave resw = symmetrize(tww,out)
	
	//	normalized magnitude, normalized magnitude squared
	if (out == 7 || out == 8)
		MatrixOP/NTHR=0/O/FREE resw = resw[][][r] / sum(resw[][][r])
	endif
	
	//	SPに戻す
	if (NumberByKey("NUMTYPE",WaveInfo(w,0)) & 2)
		Redimension/S resw
	endif
	
	SetScale/P x -(nx/2-1)/(DimDelta(w,0)*nx), 1/(DimDelta(w,0)*nx), changeUnit(WaveUnits(w,0)), resw
	SetScale/P y -1/(DimDelta(w,1)*2), 1/(DimDelta(w,1)*ny), changeUnit(WaveUnits(w,1)), resw
	SetScale/P z DimOffset(w,2), DimDelta(w,2), WaveUnits(w,2), resw
	//	NanonisのMLSモードでのウエーブの場合にはバイアス電圧情報をコピーする必要がある
	SIDAMCopyBias(w, resw)
	
	return resw
End


//=====================================================================================================


//******************************************************************************
//	パネル表示
//******************************************************************************
Static Function pnl(Wave w, String grfName)
	
	//  パネル表示
	String pnlName = SIDAMNewPanel("Fourier Transforms ("+NameOfWave(w)+")",350,435)
	AutoPositionWindow/E/M=0/R=$grfName $pnlName
	
	//	初期設定
	String dfTmp = pnlInit(pnlName)
	ControlInfo/W=$pnlName kwBackgroundColor
	STRUCT RGBColor bc ;	bc.red = V_Red ;	bc.green = V_Green ;	bc.blue = V_Blue
	SetWindow $pnlName hook(self)=SIDAMWindowHookClose
	SetWindow $pnlName userData(src)=GetWavesDataFolder(w,2)
	SetWindow $pnlName userData(dfTmp)=dfTmp, activeChildFrame=0
	
	STRUCT SIDAMPrefs prefs
	SIDAMLoadPrefs(prefs)
	
	//  コントロール項目
	SetVariable resultV title="output name:", pos={19,10}, size={324,16}, frame=1, bodyWidth=255, win=$pnlName
	SetVariable resultV value=_STR:NameOfWave(w)+SUFFIX, proc=KMFFT#pnlSetVar, win=$pnlName
	
	CheckBox subtractC title="subtract average before computing", pos={88,38}, value=prefs.fourier[0], win=$pnlName
	
	PopupMenu outputP title="output type:", pos={25,65}, size={263,19}, bodyWidth=200, win=$pnlName
	PopupMenu outputP mode=prefs.fourier[1], value=#"KMFFT#pnlPopupStr(\"out\")", win=$pnlName
	PopupMenu windowP title="window:", pos={46,94}, size={242,19}, proc=KMFFT#pnlPopup, win=$pnlName
	PopupMenu windowP mode=prefs.fourier[2], bodyWidth=200, value=#"KMFFT#pnlPopupStr(\"win\")", win=$pnlName
	
	TabControl mTab pos={3,128}, size={345,258}, value=0, labelBack=(bc.red,bc.green,bc.blue), proc=KMTabControlProc, win=$pnlName
	TabControl mTab tabLabel(0)="window intensity", tabLabel(1)="window profile", win=$pnlName
	
	Button doB title="Do It", pos={8,403}, size={60,20}, proc=KMFFT#pnlButton, win=$pnlName
	Button doB disable=SIDAMValidateSetVariableString(pnlName,"resultV",0)*2, win=$pnlName
	CheckBox displayC title="display", pos={76,406}, value=1, win=$pnlName
	PopupMenu toP title="To", pos={140,403}, size={50,20}, bodyWidth=50, win=$pnlName
	PopupMenu toP value="Cmd Line;Clip", mode=0, proc=KMFFT#pnlPopup, win=$pnlName
	
	Button helpB title="Help", pos={213,403}, size={60,20}, proc=KMFFT#pnlButton, win=$pnlName
	Button cancelB title="Cancel", pos={282,403}, size={60,20}, proc=KMFFT#pnlButton, win=$pnlName
	
	ModifyControlList ControlNameList(pnlName,";","*") focusRing=0,win=$pnlName
	
	//	ウインドウ関数を表示する
	Display/W=(5,145,345,383)/HOST=$pnlName
	Display/W=(5,145,345,383)/HOST=$pnlName	//	同じ位置に2つサブウインドウを用意する
	
	AppendImage/W=$pnlName#G0 $(dfTmp+"win2")
	SetWindow $pnlName#G0 userData(tab)="0"
	ModifyImage/W=$pnlName#G0 win2 ctab= {0,1,Spectrum,0}
	ModifyGraph/W=$pnlName#G0 mirror=0, noLabel=2, axThick=0, standoff=0, height=0,width={Aspect,1}
	ModifyGraph/W=$pnlName#G0 margin=10, margin(left)=60, margin(right)=60
	
	ModifyGraph/W=$pnlName#G0 wbRGB=(bc.red,bc.green,bc.blue),gbRGB=(V_Red,V_Green,V_Blue)
	ColorScale/C/N=text0/A=LC/B=1/F=0/X=103.00/Y=0.00/W=$pnlName#G0 width=8,heightPct=50
	ColorScale/C/N=text0/W=$pnlName#G0 image=win2,nticks=2,tickLen=4.00
	
	AppendToGraph/W=$pnlName#G1 $(dfTmp+"win1")
	ModifyGraph/W=$pnlName#G1 wbRGB=(bc.red,bc.green,bc.blue),gbRGB=(V_Red,V_Green,V_Blue), nticks=2
	SetAxis/W=$pnlName#G1 left 0,1
	SetWindow $pnlName#G1 userData(tab)="1"
	
	SetActiveSubwindow $pnlName
	
	//  初期表示状態
	pnlSetWindowWave(pnlName, StringFromList(prefs.fourier[2]-1,WINFNLIST))
	KMTabControlInitialize(pnlName,"mTab")
End
//-------------------------------------------------------------
//	パネル初期設定
//-------------------------------------------------------------
Static Function/S pnlInit(String pnlName)
	String dfTmp = SIDAMNewDF(pnlName,"KMFFTPnl")
	
	Make/N=256 $(dfTmp+"win1")/WAVE=w1 = 1
	Make/N=(256,256) $(dfTmp+"win2")/WAVE=w2 = 1
	
	SetScale/I x 0, 1, "", w1, w2
	SetScale/I y 0, 1, "", w2
	
	return dfTmp
End
//-------------------------------------------------------------
//	ポップアップの出力文字列
//	OUTPUTLIST と WINFNLIST にStatic指定がついているので、関数経由で出力する
//-------------------------------------------------------------
Static Function/S pnlPopupStr(String str)
	strswitch (str)
		case "out":
			return OUTPUTLIST
		case "win":
			return WINFNLIST
		default:
			return ""
	endswitch
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
		case "doB":
			pnlDo(s.win)
			break
		case "helpB":
			SIDAMOpenHelpNote("fourier",s.win,"Fourier Transforms")
			break
		case "cancelB":
			KillWindow $(s.win)
			break
		default:
	endswitch
End

//	SetVariable
Static Function pnlSetVar(STRUCT WMSetVariableAction &s)
	//	Handle either enter key or end edit
	if (s.eventCode != 2 && s.eventCode != 8)
		return 1
	endif
	int disable = SIDAMValidateSetVariableString(s.win,s.ctrlName,0)*2
	Button doB disable=disable, win=$s.win
	PopupMenu toP disable=disable, win=$s.win
End

//	Popup
Static Function pnlPopup(STRUCT WMPopupAction &s)
	if (s.eventCode != 2)
		return 1
	endif
	
	strswitch (s.ctrlName)
		case "windowP":
			pnlSetWindowWave(s.win, s.popStr)
			break
		case "toP":
			Wave cvw = SIDAMGetCtrlValues(s.win, "outputP;subtractC")
			Wave/T ctw = SIDAMGetCtrlTexts(s.win, "resultV;windowP")
			String paramStr = echoStr($GetUserData(s.win,"","src"), ctw[0], ctw[1], cvw[0], cvw[1])
			SIDAMPopupTo(s, paramStr)
			break
	endswitch
End

Static Function pnlDo(String pnlName)
	Wave w = $GetUserData(pnlName,"","src")
	Wave cvw = SIDAMGetCtrlValues(pnlName, "outputP;subtractC;displayC;windowP")
	Wave/T ctw = SIDAMGetCtrlTexts(pnlName, "resultV;windowP")
	KillWindow $pnlName
	
	Wave/Z resw = KMFFT(w,result=ctw[0],win=ctw[1],out=cvw[0],subtract=cvw[1],history=1)
	
	if (cvw[2])
		SIDAMDisplay(resw, history=1)
	endif
	
	STRUCT SIDAMPrefs prefs
	SIDAMLoadPrefs(prefs)
	prefs.fourier[0] = cvw[1]
	prefs.fourier[1] = cvw[0]
	prefs.fourier[2] = cvw[3]
	SIDAMSavePrefs(prefs)
End

Static Function pnlSetWindowWave(String pnlName, String name)
	Wave w = imageWindowWave(256, 256, name)
	Wave/SDFR=$GetUserData(pnlName, "", "dfTmp") win1, win2
	win1 = w[p][127]
	win2 = w
End
