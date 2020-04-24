#pragma TextEncoding="UTF-8"
#pragma rtGlobals=1

#ifndef SIDAMshowProc
#pragma hide = 1
#endif

//******************************************************************************
//	LoadTopometrix
//		KMLoadDataProcから読み出すファイルへのパスを受け取り、データタイプに応じてそれぞれの
//		読み出し関数を呼び出します。
//******************************************************************************
Function/WAVE LoadTopometrix(pathStr)
	String pathStr
	
	STRUCT GenericHeader GenHeader
	
	//	キーボードの状態
	//	shiftが押されていたらI-V,dI/dVスペクトルを平均しない
	//	altが押されていたらヘッダのXML出力をして終わる
	GenHeader.mode = GetKeyState(1)
	
	//  ヘッダを読み込む
	Variable refNum
	Open/R refNum as pathStr
	ReadTopoGenericHeader(refNum, GenHeader)
	Close refNum
	
	if (GenHeader.mode&2)	//	altが押されていたらヘッダのXML出力をして終わる
		PutTopoGenericHeader_XML(GenHeader)
		return $""
	endif
	
	DFREF dfrSav = GetDataFolderDFR()
	
	//  ヘッダの内容をグローバル変数に書き出す
	NewDataFolder/S $SIDAM_DF_SETTINGS
	PutTopoGenericHeader(GenHeader)
	
	//  ファイル読み込み
	SetDataFolder dfrSav	
	String filename = ParseFilePath(0, pathStr, ":", 1, 0)	//	ファイル名
	switch (ReturnDataType(filename))
		case 0:
			Wave resw = ReadTopoSTMRasterFile(GenHeader)
			break
		case 2:
			Wave resw = ReadTopoMapFile(GenHeader)
			break
		case 1:
		case 3:
		case 4:
			Wave resw = ReadTopoSTSFile(GenHeader)
			break
		default:
	endswitch
	
	return resw
End

//******************************************************************************
//	ReturnDataType
//		ファイルの拡張子に基づいてデータタイプを判別します.
//		0: map, 1: I-V, 2: layer, 3, dI/dV, 4: I-S, -1: 無効
//******************************************************************************
Static Function ReturnDataType(filename)
	String filename
	
	Variable type
	String extStr = LowerStr(ParseFilePath(4, filename, ":", 0, 0))
	strswitch (extStr)
		case "tfr":
		case "tfp":
		case "ffr":
		case "ffp":
		case "1fr":
		case "1fp":
		case "2fr":
		case "2fp":
			type = 0
			break
		case "iv1":
		case "iv2":
			type = 1
			break
		case "1fl":
		case "2fl":
			type = 2
			break
		case "di1":
		case "di2":
			type = 3
			break
		case "is1":
		case "is2":
			type = 4
			break
		default:
			type = -1
	endswitch
	return type
End

//******************************************************************************
//	ヘッダ読み込みのための構造体定義
//******************************************************************************
Static Structure TopoDOCUMENTINFO
	int32	iRelease		 	//  [1..4]      parsed release number
	int32	iOffset 			//  [5..8]      byte offset to actual data in file
	char		szRelease[16] 	//  [9..24]     release of software associated with this file
	char		szDatetime[20] 	//  [25..44]    date and time when data were generated
	char		szDescription[40] 	//  [45..84]    description string
	float		fPosX[8]			//  [85..116]   position of curve in x in iXYUnitType units
	float		fPosY[8]			//  [117..148]  position of curve in y in iXYUnitType units
	int16	iCurves 			//  [149..150]  number of curves (1/2 cycles) in graph
	int32	iRows 			//  [151..154]  number of data points in x
	int32	iCols 			//  [155..158]  number of data points in y
	uint16	iDACmax 		//  [159..160]  maximum value in data set
	uint16	iDACmin 		//  [151..162] minimum value in data set
	float		fXmin
	float		fXmax			//  [163..170]  scan distance in x for data set in iXYUnitType units
	float		fYmin
	float		fYmax			//  [171..178]  scan distance in y for data set in iXYUnitType units
	float		fDACtoWorld		//  [179..182]  conversion factor from DAC units to physical units
	float		fDACtoWorldZero	//  [183..186]  zero set point for physical units
	uint16	iDACtoColor 		//  [187..188]  conversion factor from DAC units to color indices
	uint16	iDACtoColorZero	//  [189..190]  zero set point for color indices
	int16	iWorldUnitType	//  [191..192]  physical unit type for display
	int16	iXYUnitType 		//  [193..194]  physical unit type in x and y for display
	char		szWorldUnit[10] 	//  [195..204]  string of physical units in z
	char		szXYUnit[10] 		//  [205..214]  string of physical units in x and y (see iXYUnitType)
	char		szRateUnit[10] 	//  [215..224]  string of scan rate unit
	int16	iLayers 			//  [225..226]  total number of image layers
	int16	bHasEchem 		//  [227..228]  has Echem data
	int16	bHasBkStrip 		//  [229..230]  has bkStrip data
	int16	iPts[8]			//  [231..246]  datapoints per spectroscopy curve
	int16	iXUnitType	 	//  [247..248]  physical unit type in x for spectroscopy display
	char		szXUnit[10] 		//  [249..258]  string of physical units in x (see iXUnitType)
	int16	bHasAcqDisplay 	//  [259..260]  has acquisition display parameters
	int16	iTilt 			//  [261..262]  acquisition tilt removal type
	int16	iScaleZ 			//  [263..264]  acquisition data range calculation type
	int16	iFilter 			//  [265..266]  acquisition filter type
	int16	iShading	 		//  [267..268]  acquisition shading type
	double	dTiltC[8]			//  [269..332]  acquisition tilt removal coefficients
	uint16	iDACDisplayZero 	//  [333..334]  z adjust zero point in DAC unitsiDACDispl
	uint16	iDACDisplayRange //  [335..336]  z adjust range in DAC units
	int16	rRoi[4] 			//  [337..344]  active image selection
	//char	cFiller[424]		//  [345..768]  fill bytes to make struct a fixed length
	double	cFiller[53]		//  [345..768]  fill bytes to make struct a fixed length
endStructure

Static Structure TopoLOCKINPARAMS
	float		fFrequency	//  [1..4]  Drive Frequency
	float		fAmplitude	//  [5..8]  Drive Amplitude
	float		fPhase		//  [9..12]  Phase of detected response
	float		fSensitivity	//  [13..16]  Sensitivity (gain) setting (in V)
	float		fTimeConst	//  [17..20]  Time Constant (in S)
	int16	iRolloff		//  [21..22]  Slope per Octave
	int16	iReserve		//  [23..24]  Dynamic Reserve
	int16	iFilters		//  [25..26]  Filters activated (can have multiple)
	int16	iHarmonic	//  [27..28]  Harmonic being detected
	int16	iExpand		//  [29..30]  Expansion factor (1,10 or 100)
	float		fOffset		//  [31..34]  Offset (as a percentage)
endStructure

Static Structure TopoSCANPARAMSLAYER
	float		fVzStart			//  [1..4]  voltage/distance start value in V or nm
	float		fVzStop			//  [5..8]  voltage/distance stop value  in V or nm
	float		fVzLimit			//  [9..12]  force limit in nA
	float		fVzArray			//  [13..16]  array of voltage/distance values (size determined by iLayers)
	float		fVzSpeed1		//  [17..20]  speed of voltage/distance ramp (sample point)       in V/s or microns/s
	float		fVzSpeed2		//  [21..24]  speed of voltage/distance ramp (pullback)           in V/s or microns/s
	float		fVzSpeed3		//  [25..28]  speed of voltage/distance ramp (first sample point) in V/s or microns/s
	float		fVzSpeed4		//  [29..32]  speed of voltage/distance ramp (back into feedback) in V/s or microns/s
	float		fVzPullback		//  [33..36]  pullback distance (to get out of contact) in nm
	int16	iLayers			//  [37..38]  number of layers
	int16	iHalfCycles		//  [39..40]  number of half cycles (forward = 1, forward+backward = 2)
	int16	iAvgPoint		//  [41..42]  averaging number per layer point
	float		fDelayStart		//  [43..46]  time delay before first sample point in mirco-sec
	float		fDelaySample		//  [47..50]  time delay before each sample in mirco-sec
	float		fDelayPullback	//  [51..54]  time delay after pullback in micro-sec
	float		fDelayEstFeedbk	//  [55..58]  time delay to re-establish feedback in micro-sec
	int16	bFeedbkPoints	//  [59..60]  TRUE: enabled feedback between points
	int16	bFeedbkCurves	//  [61..62]  TRUE: enabled feedback between curves
	int16	bVzRelative		//  [63..64]  TRUE: voltage/distance values are relative
	float		fModFreq		//  [65..68]  modulation frequency
	float		fVzMod			//  [69..72]  voltage/distance modulation
	int16	iExtLayer		//  [73..74]  extracted layer
	int16	bSpecialNCScan	//  [75..76]  special NC scanning
	STRUCT	TopoLOCKINPARAMS	lockin	//  [77..110]  lockin parameter settings (if using dIdV curve)
	int16	iXPosition		//  [111..112]  X Pixel position on last image at which scan was taken
	int16	iYPosition		//  [113..114]  Y Pixel position on last image at which scan was taken
	//char	cFiller[142]	//  [115..256]  fill bytes to make struct a fixed length
	int16	cFiller[71]		//  [115..256]  fill bytes to make struct a fixed length
endStructure

Static Structure TopoSCANPARAMS
	int16	iDataType	//  [1..2]  raw data source (Z, sensor, external #1,...)
	int16	iDataDir		//  [3..4]  direction in which data were collected
	int16	iDataMode	//  [5..6]  collection mode: (2D, CITS, DITS, FIS, MFM, EFM, FS, IV,...)
	float		fScanZmax	//  [7..10]  Z DAC max: 0 ... 0xFFFF
	float		fScanZmin	//  [11..14]  Z DAC min: 0 ... 0xFFFF
	float		fScanXmax	//  [15..18]  X piezo resolution in points
	float		fScanYmax	//  [19..22]  Y piezo resolution in points
	float		fVtip		//  [23..26]  tip-sample voltage in mV
	float		fI			//  [27..30]  desired sensor feedback/tunneling current in nA
	float		fVz			//  [31..34]  Z piezo setpoint in the range 0 ... 440 volts
	float		fRange		//  [35..38]  scanned image range
	float		fRate		//  [39..42]  XY scan rate in unitType units/sec
	int16	iGain		//  [43..44]  DEAD!!!!! ADC gain flag
	float		fPro
	float		fInteg
	float		fDer				//  [45..56]  PID parameters
	int16	iGainZ			//  [57..58]  Z piezo gain flag
	float		fRotation		//  [59..62]  XY scan rotation in radians
	float		fModLevel		//  [63..66]  modulation mode: modulation in  angstroms
	float		fAveraging		//  [67..70]  modulation mode: number of points to avg per image point
	float		fSpCalFactor		//  [71..74]  modulation mode: calibration factor (additional gain to get to correct units)
	int16	iCalibType		//  [75..76]  XY calibration type
	int16	iLaserIntensity	//  [77..78]  laser setting for AFM
	uint16	iScaleFactorZ	//  [79..80]  z scale factor
	uint16	iDACminX
	uint16	iDACmaxX		//  [81..84]  piezo scan location x
	uint16	iDACminY
	uint16	iDACmaxY		//  [85..88]  piezo scan location y
	char		cScanType[6]		//  [89..94]  ASCII/binary separator with encoded scan type info (only used for pre Windows files)
	int16	iProbeType		//  [95..96]  probe type (STM, AFM...)
	int16	iStageType		//  [97..98]  stage type (STM, AFM, Aurora, Observer,...)
	int16	iCalFileSource	//  [99..100]  calibration file type used: ZYGO or MTI (from scanner SYSTEM file)
	float		fOverscanX		//  [101..104]  overscan range in percent of scan range
	float		fOverscanY		//  [105..108]  overscan range in percent of scan range
	int16	iSetpointUnits	//  [109..110]  setpoint (fI) unit types
	float		fNcRegAmp		//  [111..114]  register frequency of non contact
	int16	iGainXY			//  [115..116]  XY gain (0=low,1=high,2 = div 2, 3 = div 4...
	uint16	iOffsetX
	uint16	iOffsetY			//  [117..120]  x and y piezo offset DAC values
	float		fHysteresisX[4]	//  [121..136]  X piezo hysteresis polynomial
	float		fHysteresisY[4]	//  [137..152]  Y piezo hysteresis polynomial
	uint16	iOffsetZ			//  [153..154]  Z piezo offset DAC value
	float		fHysteresisZ[4]	//  [155..170]  Z piezo hysteresis polynomial
	float		fCrossTalkCoef	//  [171..174]  xy crosstalk coefficient
	float		fSensorResponse	//  [175..178]  sensor response in nA/nm
	float		fKc				//  [179..182]  spring constant in N/m
	int16	iCantileverType	//  [183..184]  cantilever type
	char		szScannerSerialNumber[16]	//  [185..200]  scanner serial number
	int16	iZlinearizer		//  [201..202]  z linearizer type
	int32	iADC			//  [203..206]  adc used
	int16	bNonContact		//  [207..208]  auto non_contact flag
	int16	CantileverType	//  [209..210]  0: Low Freq, 1: High Freq, 2:General Freq
	float		fDriveAmplitude	//  [211..214]  Driving Amplitude
	float		fDriveFrequency	//  [215..218]  Driving Frquency
	int16	iNonContactMode	//  [219..220]  0: Amplitude 1: phase
	int16	iNonContactPhase//  [221..222]  0, 90, 180, 270
	char		cFiller[34]		//  [223..256]  fill bytes to make struct a fixed length
	STRUCT	TopoSCANPARAMSLAYER	scan3d	//  [257..512]  scanning parameters layered imaging
	char		szStageType[64]	//  [513..576]  stage type from stages.ini
	char		szStageName[64]	//  [577..640]  specific stage name from stages.ini
	char		szStageText[64]	//  [641..704]
	uint16	iOldOffsetX
	uint16	iOldOffsetY		//  [705..708]  x and y piezo offset DAC values
	uint16	iOldDACminX
	uint16	iOldDACmaxX		//  [709..712]  piezo scan location x
	uint16	iOldDACminY
	uint16	iOldDACmaxY		//  [713..716]  piezo scan location y
	int16	iOldGainXY		//  [717..718]  XY gain (0=low,1=high,2 = div 2, 3 = div 4...
	//char	cFiller1[370]		//  [719..1088]  512 bytes filler add in ver3.07
	double	cFiller1[46]
	int16	cFilter2			//  [719..1088]  512 bytes filler add in ver3.07
endStructure

Static Structure GenericHeader
	String	RString
	STRUCT	TopoDOCUMENTINFO sInfo
	STRUCT	TopoSCANPARAMS sScanParam
	String 	path		//  KM拡張
	String	filename	//  KM拡張
	int16 	mode	//  KM拡張
endStructure

//******************************************************************************
//	ReadTopoGenericHeader
//		データファイルの最初にあるヘッダ部分を読み込みます。これらは全てのデータ形式で共通です。
//******************************************************************************
Static Function ReadTopoGenericHeader(refNum, GenHeader)
	Variable refNum
	STRUCT GenericHeader &GenHeader
	
	String ReleaseString = PadString("",256,0x20)
	STRUCT TopoDOCUMENTINFO nTopoDOCUMENTINFO
	STRUCT TopoSCANPARAMS nTopoSCANPARAMS
	
	//  ヘッダ読み出し
	FBinRead refNum, ReleaseString
	FBinRead refNum, nTopoDOCUMENTINFO
	FBinRead refNum, nTopoSCANPARAMS
	GenHeader.RString = ReleaseString
	GenHeader.sInfo = nTopoDOCUMENTINFO
	GenHeader.sScanParam = nTopoSCANPARAMS
	
	//  KM拡張
	FStatus refNum
	GenHeader.path = S_path
	GenHeader.filename = S_filename
End


//******************************************************************************
//	ReadTopoSTMRasterFile
//		STM Raster データファイル (data type = 0) を読み込みます。
//******************************************************************************
Static Function/WAVE ReadTopoSTMRasterFile(GenHeader)
	STRUCT GenericHeader &GenHeader
	
	Variable xpnts = GenHeader.sInfo.iRows, ypnts = GenHeader.sInfo.iCols
	
	//  出力ウエーブ
	Make/N=(xpnts,ypnts)/O $GenHeader.filename/WAVE=w
	
	DFREF dfrSav = GetDataFolderDFR()
	SetDataFolder NewFreeDataFolder()
	
	//  読み込み実行
	GBLoadWave/B/Q/N=tmp/T={80,2}/S=(GenHeader.sInfo.iOffset)/W=1/U=(xpnts*ypnts) GenHeader.path+GenHeader.filename
	Wave tw = :tmp0
	
	//  上下反転しつつ２次元ウエーブへ代入
	w = tw[p+xpnts*(ypnts-1-q)]
	
	//  単位変換
	w = w * GenHeader.sInfo.fDACtoWorld + GenHeader.sInfo.fDACtoWorldZero
	w *= 10	//  nm からÅへの変換
	
	//  スケール・単位設定
	SetScale d 0, 0, "\u00c5", w
	SetScale/I x GenHeader.sInfo.fXmin, GenHeader.sInfo.fXmax, "\u00c5", w
	SetScale/I y GenHeader.sInfo.fYmin, GenHeader.sInfo.fYmax, "\u00c5", w
	
	SetDataFolder dfrSav
	return w
End

//******************************************************************************
//	ReadTopoMapFile
//		STM Map データファイルを読み込みます。
//		NistViewのFile_ReadTopoData.pro 20041004 BUG CL版では、レイヤーの数が1であるような
//		ファイルを読み込むとエラーが起きますが、その問題はここでは起きません。
//******************************************************************************
Static Function/WAVE ReadTopoMapFile(GenHeader)
	STRUCT GenericHeader &GenHeader
	
	Variable xpnts = GenHeader.sInfo.iRows
	Variable ypnts = GenHeader.sInfo.iCols
	Variable zpnts = GenHeader.sScanParam.scan3d.iLayers
	
	//  出力ウエーブ
	Make/N=(xpnts,ypnts,zpnts)/O $GenHeader.filename/WAVE=w
	
	DFREF dfrSav = GetDataFolderDFR()
	SetDataFolder NewFreeDataFolder()
	
	//  読み込み実行
	GBLoadWave/B/Q/N=tmp/T={80,2}/S=(GenHeader.sInfo.iOffset)/W=1/U=(xpnts*ypnts*zpnts) GenHeader.path+GenHeader.filename 
	Wave tw = :tmp0
	
	//  上下反転しつつ3次元ウエーブへ代入	
	w = tw[p+xpnts*(ypnts-1-q)+xpnts*ypnts*r]
	
	//---------------------------------------------------------------------------
	//  DAC出力から現実世界の物理量への変換方法
	//
	//  データはunsigned intergerで保存されていて、その値は 0 から 65535 (= 2^16-1) まで。
	//  それをfloatに変換しながら読み込んだのがここまで。
	//  ECUへの入力は常に -10V から +10V の間で、DACは16bitなので、Vへの変換係数は
	//    DACtoWorld = 0.000305180 = 20/65536
	//    DACtoWorldZero = -10
	//  となります。VからnSへの変換には、sensitivity, driveamp, attenuation, bias divider を考慮します。
	//  (fsens/10)/driveamp が V から nS への変換を与えますが、減衰によりdriveampは実効的には
	//  記録されている値よりも小さくなっています。1.495が減衰係数として使われていますが、これはSTM1の
	//  ための値なので、STM2では異なっているかもしれません。
	//
	//	KMにおける変更
	//
	//  NistViewのFile_ReadTopoData.pro 20041004 BUG CL版ではI-VもdI/dVと同様に読み込まれ
	//  ますが、ここではI-Vは変換しないように書き換えました。(2005.1.16)
	//
	//	オリジナルではI-VもdI/dVとみなして変換してしまいますが、ここではiDataTypeの違いによって変換する
	//	しないを決定します. これは入力チャンネルを反映しているので、配線を変えるなどした場合には変更
	//	しなければならないかもしれません. また、I-Vの際には値の変換をせずにそのまま出力していますが、
	//	これはアンプのゲインが1e9であるとの仮定に基づいています. (2005.5.5)
	//---------------------------------------------------------------------------
	Variable dac2w = GenHeader.sInfo.fDACtoWorld
	Variable dac2wz = GenHeader.sInfo.fDACtoWorldZero
	w = w*dac2w+dac2wz
	
	String valueunits = GenHeader.sInfo.szWorldUnit
	
	if (GenHeader.sScanParam.iDataMode == 2)		//  I-S, WF
		WaveStats/M=1/Q w
		if (V_avg < 0)		//  全体として正になるように (反転アンプかそうでないかによって変わり得る)
			w *= -1
		endif
		valueunits = "nA"
	elseif (GenHeader.sScanParam.iDataMode == 6)	//  dI/dV, I-V
		if (GenHeader.sScanParam.iDataType == 5)			//	I-V (ch. 1)
			valueunits = "nA"	//  プリアンプの出力そのまま
		elseif (GenHeader.sScanParam.iDataType == 6 && abs(dac2w-0.00030518) < 1e-8 && abs(dac2wz+10) < 1e-8 && stringmatch(valueunits,"V"))	//	dI/dV (ch. 2)
			Variable sensitivity = GenHeader.sScanParam.scan3d.lockin.fSensitivity
			Variable driveamp = GenHeader.sScanParam.scan3d.lockin.fAmplitude
			if (!sensitivity)		//  正しく保存されていない、あるいは読み込まれていないファイルも扱うように
				sensitivity = 1
			endif
			if (!driveamp)		//  正しく保存されていない、あるいは読み込まれていないファイルも扱うように
				driveamp = 1
			endif
			if (sensitivity >= 1e-6 && sensitivity <= 10 && driveamp >= 0.003 && driveamp <= 5.001)
				STRUCT SIDAMPrefs prefs
				SIDAMLoadPrefs(prefs)
				w *= prefs.TopoGainFactor*(sensitivity/10)/(driveamp/100)*prefs.TopoCorrFactor
				valueunits = "nS"
			endif
		endif
	endif
	
	//  スケール・単位設定
	Variable zstart = GenHeader.sScanParam.scan3d.fvzstart
	Variable zend = GenHeader.sScanParam.scan3d.fvzstop
	SetScale d 0, 0, valueunits, w
	SetScale/I x GenHeader.sInfo.fXmin, GenHeader.sInfo.fXmax, "\u00c5", w
	SetScale/I y GenHeader.sInfo.fYmin, GenHeader.sInfo.fYmax, "\u00c5", w
	if (GenHeader.sScanParam.iDataMode == 2)
		SetScale/I z zstart*10, -zend*10, "\u00c5", w	//  変位の符号を反転する、nmからÅへの変換を含む
	else
		SetScale/I z zstart*1000, zend*1000, "mV", w
	endif
	
	SetDataFolder dfrSav
	return w
End

//******************************************************************************
//	ReadTopoSTSFile
//		STS データファイル (data type=1(IV), 3(dIdV)) を読み込みます。
//******************************************************************************
Static Function/WAVE ReadTopoSTSFile(GenHeader)
	STRUCT GenericHeader &GenHeader
	
	Variable numcurves = GenHeader.sInfo.iCurves
	Variable numpoints = GenHeader.sInfo.ipts[0]
	Variable i
	String cmd
	DFREF dfrSav = GetDataFolderDFR()
	SetDataFolder NewFreeDataFolder()
	
	//---------------------------------------------------------------------------
	//  読み込み実行
	//
	//  ヘッダの後にデータが保存されています。データはfloatのペアから構成されています。それぞれのペアの
	//  1つ目の要素には電圧が、2つ目の要素には測定値(I, dI/dV)が保存されています。これらのペアがデータ
	//  点の数だけ並んで1つのカーブのデータとなります。2つめのデータ(1つめの逆方向カーブ)は、この1つめの
	//  カーブの後に同様にして保存されています。
	//  Topometrix形式(di1, iv1)ではそれぞれのカーブでデータ点数が異なっていても構いません。また、
	//  順方向と逆方向で、測定時のの電圧が異なっていても構いません。しかし、実際の測定においてはこの
	//  ようなことは起こらないので、ファイルの読み込みにおいてはこの可能性は考慮しません。
	//  したがって、各カーブにおけるデータ点数と測定電圧は最初のカーブのものが用いられています。
	//  電圧は順方向・逆方向ともに同じ順序で保存されているので、逆方向のカーブのデータ順を反転させる
	//  必要はありません。
	//
	//	KMにおける変更 (2005.5.5)
	//
	//	オリジナルでは iDataMode が10の時にI-Vであると判断するようになっていますが、(少なくとも)STM2
	//	ではI-Vも18になります。したがって、dI/dVとI-Vの違いの判断はiDataTypeで行います。これは入力
	//	チャンネルを反映しているので、配線を変えるなどした場合には変更しなければならないかもしれません.
	//---------------------------------------------------------------------------
	GBLoadWave/B/Q/N=tmp/T={2,2}/S=(GenHeader.sInfo.iOffset)/W=(numcurves)/U=(numpoints*2) GenHeader.path+GenHeader.filename
	Wave tw = :tmp0
	
	//  データ点取り出し、スケール・単位設定
	Variable vstart = tw[0][0]
	Variable vend = tw[(numpoints-1)*2][0]
	String yunits = GenHeader.sInfo.szWorldUnit
	String xunits = GenHeader.sInfo.szXYUnit
	String suffix
	Make/N=(numcurves)/WAVE refw
	for (i = 0; i < numcurves; i += 1)
		Make/N=(numpoints)/O $(GenHeader.filename+"_"+num2str(i))/WAVE=w
		Wave tw = :$("tmp"+num2str(i))
		w = tw[p*2+1]
		if (GenHeader.sScanParam.iDataMode == 11)	//  I-S
			WaveStats/M=1/Q w
			if (V_avg < 0)		//  全体として正になるように (反転アンプかそうでないかによって変わり得る)
				w *= -1
			endif
			SetScale/I x vstart*10, vend*10, "\u00c5", w
			SetScale d 0, 0, "nA", w
		elseif (GenHeader.sScanParam.iDataMode == 18)	//	dI/dV, I-V
			SetScale/I x vstart*1000, vend*1000, "mV", w
			if (GenHeader.sScanParam.iDataType == 5)		//	I-V (ch.1)
				SetScale d 0, 0, "nA", w
			elseif (GenHeader.sScanParam.iDataType == 6)	//	dI/dV (ch.2)
				SetScale d 0, 0, "nS", w
			else
				SetScale d 0, 0, yunits, w
			endif
		else
			SetScale/I x vstart, vend, xunits, w
			SetScale d 0, 0, yunits, w
		endif
		refw[i] = w
	endfor
	
	SetDataFolder dfrSav
	
	//	平均
	if (numcurves < 2)		//	half cycle=1なら平均の必要なし
		Rename w $GenHeader.filename
	elseif (GenHeader.mode&4)		//	shiftが押されていたら平均しない
		for (i = 0; i < numcurves; i += 1)
			Wave tw = refw[i]
			Duplicate/O tw $(GenHeader.filename+"_"+num2str(i))
			refw[i] = $(GenHeader.filename+"_"+num2str(i))
		endfor
		return refw
	else							//	shiftが押されていなかったら平均する
		Duplicate/O calcAvg(refw) $GenHeader.filename
		return $GenHeader.filename
	endif
End

Static Function/WAVE calcAvg(Wave/WAVE refw)
	Wave w0 = refw[0]
	Make/N=(numpnts(w0),numpnts(refw))/FREE tw
	int j
	for (j = 0; j < DimSize(tw,1); j++)
		Wave w = refw[j]
		tw[][j] = w[p]
	endfor
	MatrixOP/FREE avgw = sumRows(tw)/numCols(tw)
	Copyscales w, avgw
	return avgw
End

//******************************************************************************
//	PutTopoGenericHeader
//		KM拡張: ヘッダの内容をそのままグローバル変数として書き出します
//******************************************************************************
Static Function PutTopoGenericHeader(GenHeader)
	STRUCT GenericHeader &GenHeader
	
	String dfSav = GetDataFolder(1)
	
	//	settings フォルダ内一部を保存
	Variable/G bias = GenHeader.sScanParam.fVtip
	Variable/G current = GenHeader.sScanParam.fI
	String/G text = GenHeader.sInfo.szDescription
	
	NewDataFolder/O/S TopoHeader
	
	//	TopoDOCUMENTINFO
	NewDataFolder/O/S TopoDOCUMENTINFO
	Variable/G iRelease = GenHeader.sInfo.iRelease
	Variable/G iOffset = GenHeader.sInfo.iOffset
	String/G szRelease = GenHeader.sInfo.szRelease
	String/G szDatetime = GenHeader.sInfo.szDatetime
	String/G szDescription = GenHeader.sInfo.szDescription
	Make/N=8 fPosX = GenHeader.sInfo.fPosX[p]
	Make/N=8 fPosY = GenHeader.sInfo.fPosY[p]
	Variable/G iCurves = GenHeader.sInfo.iCurves
	Variable/G iRows = GenHeader.sInfo.iRows
	Variable/G iCols = GenHeader.sInfo.iCols
	Variable/G iDACmax = GenHeader.sInfo.iDACmax
	Variable/G iDACmin = GenHeader.sInfo.iDACmin
	Variable/G fXmin = GenHeader.sInfo.fXmin
	Variable/G fXmax = GenHeader.sInfo.fXmax
	Variable/G fYmin = GenHeader.sInfo.fYmin
	Variable/G fYmax = GenHeader.sInfo.fYmax
	Variable/G fDACtoWorld = GenHeader.sInfo.fDACtoWorld
	Variable/G fDACtoWorldZero = GenHeader.sInfo.fDACtoWorldZero
	Variable/G iDACtoColor = GenHeader.sInfo.iDACtoColor
	Variable/G iDACtoColorZero = GenHeader.sInfo.iDACtoColorZero
	Variable/G iWorldUnitType = GenHeader.sInfo.iWorldUnitType
	Variable/G iXYUnitType = GenHeader.sInfo.iXYUnitType
	String/G szWorldUnit = GenHeader.sInfo.szWorldUnit
	String/G szXYUnit = GenHeader.sInfo.szXYUnit
	String/G szRateUnit = GenHeader.sInfo.szRateUnit
	Variable/G iLayers = GenHeader.sInfo.iLayers
	Variable/G bHasEchem = GenHeader.sInfo.bHasEchem
	Variable/G bHasBkStrip = GenHeader.sInfo.bHasBkStrip
	Make/N=8/W iPts = GenHeader.sInfo.iPts[p]
	Variable/G iXUnitType = GenHeader.sInfo.iXUnitType
	String/G szXUnit = GenHeader.sInfo.szXUnit
	Variable/G bHasAcqDisplay = GenHeader.sInfo.bHasAcqDisplay
	Variable/G iTilt = GenHeader.sInfo.iTilt
	Variable/G iScaleZ = GenHeader.sInfo.iScaleZ
	Variable/G iFilter = GenHeader.sInfo.iFilter
	Variable/G iShading = GenHeader.sInfo.iShading
	Make/N=8/D dTiltC = GenHeader.sInfo.dTiltC[p]
	Variable/G iDACDisplayZero = GenHeader.sInfo.iDACDisplayZero
	Variable/G iDACDisplayRange = GenHeader.sInfo.iDACDisplayRange
	Make/N=4/W rRoi = GenHeader.sInfo.rRoi[p]
	
	//	TopoLOCKINPARAMS
	SetDataFolder $(dfSav+"TopoHeader")
	NewDataFolder/O/S TopoLOCKINPARAMS
	Variable/G fFrequency = GenHeader.sScanParam.scan3d.lockin.fFrequency
	Variable/G fAmplitude = GenHeader.sScanParam.scan3d.lockin.fAmplitude
	Variable/G fPhase = GenHeader.sScanParam.scan3d.lockin.fPhase
	Variable/G fSensitivity = GenHeader.sScanParam.scan3d.lockin.fSensitivity
	Variable/G fTimeConst = GenHeader.sScanParam.scan3d.lockin.fTimeConst
	Variable/G iRolloff = GenHeader.sScanParam.scan3d.lockin.iRolloff
	Variable/G iReserve = GenHeader.sScanParam.scan3d.lockin.iReserve
	Variable/G iFilters = GenHeader.sScanParam.scan3d.lockin.iFilters
	Variable/G iHarmonic = GenHeader.sScanParam.scan3d.lockin.iHarmonic
	Variable/G iExpand = GenHeader.sScanParam.scan3d.lockin.iExpand
	Variable/G fOffset = GenHeader.sScanParam.scan3d.lockin.fOffset
	
	//	TopoSCANPARAMSLAYER
	SetDataFolder $(dfSav+"TopoHeader")
	NewDataFolder/O/S TopoSCANPARAMSLAYER
	Variable/G fVzStart = GenHeader.sScanParam.scan3d.fVzStart
	Variable/G fVzStop = GenHeader.sScanParam.scan3d.fVzStop
	Variable/G fVzLimit = GenHeader.sScanParam.scan3d.fVzLimit
	Variable/G fVzArray = GenHeader.sScanParam.scan3d.fVzArray
	Variable/G fVzSpeed1 = GenHeader.sScanParam.scan3d.fVzSpeed1
	Variable/G fVzSpeed2 = GenHeader.sScanParam.scan3d.fVzSpeed2
	Variable/G fVzSpeed3 = GenHeader.sScanParam.scan3d.fVzSpeed3
	Variable/G fVzSpeed4 = GenHeader.sScanParam.scan3d.fVzSpeed4
	Variable/G fVzPullback = GenHeader.sScanParam.scan3d.fVzPullback
	Variable/G iLayers = GenHeader.sScanParam.scan3d.iLayers
	Variable/G iHalfCycles = GenHeader.sScanParam.scan3d.iHalfCycles
	Variable/G iAvgPoint = GenHeader.sScanParam.scan3d.iAvgPoint
	Variable/G fDelayStart = GenHeader.sScanParam.scan3d.fDelayStart
	Variable/G fDelaySample = GenHeader.sScanParam.scan3d.fDelaySample
	Variable/G fDelayPullback = GenHeader.sScanParam.scan3d.fDelayPullback
	Variable/G fDelayEstFeedbk = GenHeader.sScanParam.scan3d.fDelayEstFeedbk
	Variable/G bFeedbkPoints = GenHeader.sScanParam.scan3d.bFeedbkPoints
	Variable/G bFeedbkCurves = GenHeader.sScanParam.scan3d.bFeedbkCurves
	Variable/G bVzRelative = GenHeader.sScanParam.scan3d.bVzRelative
	Variable/G fModFreq = GenHeader.sScanParam.scan3d.fModFreq
	Variable/G fVzMod = GenHeader.sScanParam.scan3d.fVzMod
	Variable/G iExtLayer = GenHeader.sScanParam.scan3d.iExtLayer
	Variable/G bSpecialNCScan = GenHeader.sScanParam.scan3d.bSpecialNCScan
	Variable/G iXPosition = GenHeader.sScanParam.scan3d.iXPosition
	Variable/G iYPosition = GenHeader.sScanParam.scan3d.iYPosition
	
	//	TopoSCANPARAMS
	SetDataFolder $(dfSav+"TopoHeader")
	NewDataFolder/O/S TopoSCANPARAMS
	Variable/G iDataType = GenHeader.sScanParam.iDataType
	Variable/G iDataDir = GenHeader.sScanParam.iDataDir
	Variable/G iDataMode = GenHeader.sScanParam.iDataMode
	Variable/G fScanZmax = GenHeader.sScanParam.fScanZmax
	Variable/G fScanZmin = GenHeader.sScanParam.fScanZmin
	Variable/G fScanXmax = GenHeader.sScanParam.fScanXmax
	Variable/G fScanYmax = GenHeader.sScanParam.fScanYmax
	Variable/G fVtip = GenHeader.sScanParam.fVtip
	Variable/G fI = GenHeader.sScanParam.fI
	Variable/G fVz = GenHeader.sScanParam.fVz
	Variable/G fRange = GenHeader.sScanParam.fRange
	Variable/G fRate = GenHeader.sScanParam.fRate
	Variable/G iGain = GenHeader.sScanParam.iGain
	Variable/G fPro = GenHeader.sScanParam.fPro
	Variable/G fInteg = GenHeader.sScanParam.fInteg
	Variable/G fDer = GenHeader.sScanParam.fDer
	Variable/G iGainZ = GenHeader.sScanParam.iGainZ
	Variable/G fRotation = GenHeader.sScanParam.fRotation
	Variable/G fModLevel = GenHeader.sScanParam.fModLevel
	Variable/G fAveraging = GenHeader.sScanParam.fAveraging
	Variable/G fSpCalFactor = GenHeader.sScanParam.fSpCalFactor
	Variable/G iCalibType = GenHeader.sScanParam.iCalibType
	Variable/G iLaserIntensity = GenHeader.sScanParam.iLaserIntensity
	Variable/G iScaleFactorZ = GenHeader.sScanParam.iScaleFactorZ
	Variable/G iDACminX = GenHeader.sScanParam.iDACminX
	Variable/G iDACmaxX = GenHeader.sScanParam.iDACmaxX
	Variable/G iDACminY = GenHeader.sScanParam.iDACminY
	Variable/G iDACmaxY = GenHeader.sScanParam.iDACmaxY
	String/G cScanType = GenHeader.sScanParam.cScanType
	Variable/G iProbeType = GenHeader.sScanParam.iProbeType
	Variable/G iStageType = GenHeader.sScanParam.iStageType
	Variable/G iCalFileSource = GenHeader.sScanParam.iCalFileSource
	Variable/G fOverscanX = GenHeader.sScanParam.fOverscanX
	Variable/G fOverscanY = GenHeader.sScanParam.fOverscanY
	Variable/G iSetpointUnits = GenHeader.sScanParam.iSetpointUnits
	Variable/G fNcRegAmp = GenHeader.sScanParam.fNcRegAmp
	Variable/G iGainXY = GenHeader.sScanParam.iGainXY
	Variable/G iOffsetX = GenHeader.sScanParam.iOffsetX
	Variable/G iOffsetY = GenHeader.sScanParam.iOffsetY
	Make/N=4 fHysteresisX = GenHeader.sScanParam.fHysteresisX[p]
	Make/N=4 fHysteresisY = GenHeader.sScanParam.fHysteresisY[p]
	Variable/G iOffsetZ = GenHeader.sScanParam.iOffsetZ
	Make/N=4 fHysteresisZ = GenHeader.sScanParam.fHysteresisZ[p]
	Variable/G fCrossTalkCoef = GenHeader.sScanParam.fCrossTalkCoef
	Variable/G fSensorResponse = GenHeader.sScanParam.fSensorResponse
	Variable/G fKc = GenHeader.sScanParam.fKc
	Variable/G iCantileverType = GenHeader.sScanParam.iCantileverType
	String/G szScannerSerialNumber = GenHeader.sScanParam.szScannerSerialNumber
	Variable/G iZlinearizer = GenHeader.sScanParam.iZlinearizer
	Variable/G iADC = GenHeader.sScanParam.iADC
	Variable/G bNonContact = GenHeader.sScanParam.bNonContact
	Variable/G CantileverType = GenHeader.sScanParam.CantileverType
	Variable/G fDriveAmplitude = GenHeader.sScanParam.fDriveAmplitude
	Variable/G fDriveFrequency = GenHeader.sScanParam.fDriveFrequency
	Variable/G iNonContactMode = GenHeader.sScanParam.iNonContactMode
	Variable/G iNonContactPhase = GenHeader.sScanParam.iNonContactPhase
	String/G szStageType = GenHeader.sScanParam.szStageType
	String/G szStageName = GenHeader.sScanParam.szStageName
	String/G szStageText = GenHeader.sScanParam.szStageText
	Variable/G iOldOffsetX = GenHeader.sScanParam.iOldOffsetX
	Variable/G iOldOffsetY = GenHeader.sScanParam.iOldOffsetY
	Variable/G iOldDACminX = GenHeader.sScanParam.iOldDACminX
	Variable/G iOldDACmaxX = GenHeader.sScanParam.iOldDACmaxX
	Variable/G iOldDACminY = GenHeader.sScanParam.iOldDACminY
	Variable/G iOldDACmaxY = GenHeader.sScanParam.iOldDACmaxY
	Variable/G iOldGainXY = GenHeader.sScanParam.iOldGainXY
	
	SetDataFolder $dfSav
End


//******************************************************************************
//	PutTopoGenericHeader_XML
//		KM拡張: ヘッダの内容をXML形式でnotebookに書き出します
//******************************************************************************
Static Function PutTopoGenericHeader_XML(GenHeader)
	STRUCT GenericHeader &GenHeader
	
	String id = LowerStr(ParseFilePath(3, GenHeader.filename, ":", 0, 0))
	String class = ""
	String unit = ""
	if (GenHeader.sScanParam.iDataMode == 2)		//  I-S
		class = "ISmap"
		unit = "nm"
	elseif (GenHeader.sScanParam.iDataMode == 6)	//	dI/dV, I-V
		class = "dIdVmap"
		unit = "V"
	elseif (GenHeader.sScanParam.iDataMode == 0)	//	topo
		class = "topo"
	endif
	
	String movV = num2str(GenHeader.sScanParam.fVtip/1000)		//	moving bias (V)
	String movI = num2str(GenHeader.sScanParam.fI)				//	moving current (nA)
	String range = num2str(GenHeader.sScanParam.fRange/10)		//	scan range (nm)
	String rate = num2str(GenHeader.sScanParam.fRate/10)		//	scan rate (nm/s)
	String ctrlP = num2str(GenHeader.sScanParam.fPro)			//	P
	String ctrlI = num2str(GenHeader.sScanParam.fInteg)			//	I
	String ctrlD = num2str(GenHeader.sScanParam.fDer)			//	D
	String pts = num2str(GenHeader.sInfo.iRows)					//	resolution
	String angle = num2str(GenHeader.sScanParam.fRotation/pi*180)	//	rotate (deg)
	
   	Variable xc = round((0xFFFF-GenHeader.sScanParam.iOffsetX)*(GenHeader.sInfo.fXmax-GenHeader.sInfo.fXmin)/(GenHeader.sScanParam.iDACmaxX-GenHeader.sScanParam.iDACminX)*fXYgainV(1)/fXYgainV(GenHeader.sScanParam.iGainXY))
   	Variable yc = round((GenHeader.sScanParam.iOffsetY)*(GenHeader.sInfo.fYmax-GenHeader.sInfo.fYmin)/(GenHeader.sScanParam.iDACmaxY-GenHeader.sScanParam.iDACminY)*fXYgainV(1)/fXYgainV(GenHeader.sScanParam.iGainXY))
	
	String zpnts = num2str(GenHeader.sScanParam.scan3d.iLayers)			//	layers
	String zstart = num2str(GenHeader.sScanParam.scan3d.fvzstart)			//	starting bias
	String zend = num2str(GenHeader.sScanParam.scan3d.fvzstop)			//	ending bias
	String zcycles = num2str(GenHeader.sScanParam.scan3d.iHalfCycles)	//	half cycles
	
	String freq = num2str(GenHeader.sScanParam.scan3d.lockin.fFrequency)			//	frequency (Hz)
	String amp = num2str(GenHeader.sScanParam.scan3d.lockin.fAmplitude)			//	amplitude (V)
	String phase = num2str(GenHeader.sScanParam.scan3d.lockin.fPhase)			//	phase (deg)
	String sens = num2str(GenHeader.sScanParam.scan3d.lockin.fSensitivity)			//	sensitivity (V)
	String timeconst = num2str(GenHeader.sScanParam.scan3d.lockin.fTimeConst)	//	time constant (s)
	
	String avg = num2str(GenHeader.sScanParam.scan3d.iAvgPoint/1000)			//	averaging time (s)	
	String startdelay = num2str(GenHeader.sScanParam.scan3d.fDelayStart*1e-6)		//	start delay (s)
	String beforesample = num2str(GenHeader.sScanParam.scan3d.fDelaySample*1e-6)//	before sample (s)
	String establish = num2str(GenHeader.sScanParam.scan3d.fDelayEstFeedbk*1e-6)	//	establish feedback (s)
	String s1 = num2str(GenHeader.sScanParam.scan3d.fVzSpeed1)
	String s3 = num2str(GenHeader.sScanParam.scan3d.fVzSpeed3)
	String s4 = num2str(GenHeader.sScanParam.scan3d.fVzSpeed4)
	
	//	get parameters
	Variable bias=0.2, current=0.1
	if (GenHeader.sScanParam.iDataMode)
		Prompt bias, "bias (V):"
		Prompt current, "current (nA):"
		DoPrompt "setpoint", bias, current
	endif
	
	String nb = UniqueName("Notebook",10,0)
	NewNotebook/N=$nb/F=0/V=1/K=1
	Notebook $nb text="<data id=\""+id+"\" class=\""+class+"\">\r"
	
	Notebook $nb text="\t<scan>\r"
	Notebook $nb text="\t\t<bias value=\""+movV+"\" unit=\"V\" />\r"
	Notebook $nb text="\t\t<current value=\""+movI+"\" unit=\"nA\" />\r"
	Notebook $nb text="\t\t<range value=\""+range+"\" unit=\"nm\" />\r"
	Notebook $nb text="\t\t<rate value=\""+rate+"\" unit=\"nm/s\" />\r"
	Notebook $nb text="\t\t<pid p=\""+ctrlP+"\" i=\""+ctrlI+"\" d=\""+ctrlD+"\" />\r"
	Notebook $nb text="\t\t<points value=\""+pts+"\" />\r"
	Notebook $nb text="\t\t<angle value=\""+angle+"\" unit=\"&#176;\" />\r"
	Notebook $nb text="\t\t<center x=\""+num2str(xc)+"\" y=\""+num2str(yc)+"\" unit=\"&#197;\" />\r"
	Notebook $nb text="\t</scan>\r"
	
	Notebook $nb text="\t<spectroscopy>\r"
	if (GenHeader.sScanParam.iDataMode)
		Notebook $nb text="\t\t<start value=\""+zstart+"\" unit=\""+unit+"\" />\r"
		Notebook $nb text="\t\t<end value=\""+zend+"\" unit=\""+unit+"\" />\r"
		Notebook $nb text="\t\t<layers value=\""+zpnts+"\" />\r"
		Notebook $nb text="\t\t<bias value=\""+num2str(bias)+"\" unit=\"V\" />\r"
		Notebook $nb text="\t\t<current value=\""+num2str(current)+"\" unit=\"nA\" />\r"	
	else
		Notebook $nb text="\t\t<start value=\"\" unit=\"\" />\r"
		Notebook $nb text="\t\t<end value=\"\" unit=\"\" />\r"
		Notebook $nb text="\t\t<layers value=\"\" />\r"
		Notebook $nb text="\t\t<bias value=\"\" unit=\"\" />\r"
		Notebook $nb text="\t\t<current value=\"\" unit=\"\" />\r"
	endif
	Notebook $nb text="\t</spectroscopy>\r"
	
	Notebook $nb text="\t<lockin>\r"
	if (GenHeader.sScanParam.iDataMode)
		Notebook $nb text="\t\t<frequency value=\""+freq+"\" unit=\"Hz\" />\r"
		Notebook $nb text="\t\t<amplitude value=\""+amp+"\" unit=\"V\" />\r"
		Notebook $nb text="\t\t<phase value=\""+phase+"\" unit=\"&#176;\" />\r"
		Notebook $nb text="\t\t<sensitivity value=\""+sens+"\" unit=\"V\" />\r"
		Notebook $nb text="\t\t<timeconst value=\""+timeconst+"\" unit=\"s\" />\r"
	else
		Notebook $nb text="\t\t<frequency value=\"\" unit=\"\" />\r"
		Notebook $nb text="\t\t<amplitude value=\"\" unit=\"\" />\r"
		Notebook $nb text="\t\t<phase value=\"\" unit=\"\" />\r"
		Notebook $nb text="\t\t<sensitivity value=\"\" unit=\"\" />\r"
		Notebook $nb text="\t\t<timeconst value=\"\" unit=\"\" />\r"
	endif
	Notebook $nb text="\t</lockin>\r"
	
	Notebook $nb text="\t<time>\r"
	if (GenHeader.sScanParam.iDataMode)
		Notebook $nb text="\t\t<average value=\""+avg+"\" unit=\"s\" />\r"
		Notebook $nb text="\t\t<startdelay value=\""+startdelay+"\" unit=\"s\" />\r"
		Notebook $nb text="\t\t<beforesample value=\""+beforesample+"\" unit=\"s\" />\r"
		Notebook $nb text="\t\t<establishfeedback value=\""+establish+"\" unit=\"s\" />\r"
		Notebook $nb text="\t\t<speed sample=\""+s1+"\" start=\""+s3+"\" feedback=\""+s4+"\" unit=\""+unit+"/s\" />\r"
	else
		Notebook $nb text="\t\t<average value=\"\" unit=\"\" />\r"
		Notebook $nb text="\t\t<startdelay value=\"\" unit=\"\" />\r"
		Notebook $nb text="\t\t<beforesample value=\"\" unit=\"\" />\r"
		Notebook $nb text="\t\t<establishfeedback value=\"\" unit=\"\" />\r"
		Notebook $nb text="\t\t<speed sample=\"\" start=\"\" feedback=\"\" unit=\"\" />\r"
	endif
	Notebook $nb text="\t</time>\r"
	
	Notebook $nb text="\t<description>"+GenHeader.sInfo.szDescription+"</description>\r"
	
	Notebook $nb text="</data>\r"
	
	//	put result to clipboard
	Notebook $nb, selection={startOfFile,endOfFile}
	GetSelection notebook, $nb, 2
	PutScrapText S_selection
End

Static Function fXYgainV(gain)
	Variable gain
	
	switch (gain)
		case 0:
			return 80.0
		case 1:
			return 440.0
		case 2:
			return 220.0
		case 3:
			return 110.0
		case 4:
			return 55.0
		case 5:
			return 27.5
		case 6:
			return 13.75
		case 7:
			return 6.875
		case 8:
			return 3.4375
		default:
			return 440.0;   // ack! shouldn't get here!
	endswitch
End
