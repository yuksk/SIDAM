#pragma TextEncoding="UTF-8"
#pragma rtGlobals=3
#pragma ModuleName=LoadNanonis3ds

#ifndef KMshowProcedures
#pragma hide = 1
#endif

//******************************************************************************
//	ファイル読み込みメイン
//******************************************************************************
Function/WAVE LoadNanonis3ds(String pathStr)
	DFREF dfrSav = GetDataFolderDFR()	//	基準となるデータフォルダ
	
	//	ヘッダ読み込み
	NewDataFolder/O/S $KM_DF_SETTINGS
	STRUCT Nanonis3ds s
	LoadNanonis3dsGetHeader(pathStr, s)
	
	//	データ読み込み
	SetDataFolder dfrSav
	Wave/WAVE resw = LoadNanonis3dsGetData(pathStr, s)
	
	return resw
End


//******************************************************************************
//	ヘッダ読み込み
//		ヘッダから読み込んだ値(の一部)はグローバル変数としてカレントデータフォルダへ保存される
//******************************************************************************
Static Function LoadNanonis3dsGetHeader(String pathStr, STRUCT Nanonis3ds &s)
	
	//	ヘッダを読み込んでグローバル変数として保存する
	s.headerSize = LoadNanonisCommonGetHeader(pathStr)
	Wave/Z s.mlsw = 'multiline settings'
	s.filename = ParseFilePath(3, pathStr, ":", 0, 0)	//	拡張子抜きのファイル名
	
	//	ヘッダの値を構造体へコピーする
	//	NumVarOrDefault や StrVarOrDefault は NVAR や SVAR を使わずにすむ方法として用いている
	//	(実際に NaN 等が入ることを期待しているわけではない)
	SVAR/Z gridDim = 'Grid dim'
	s.pnts.x = str2num(StringFromList(0, gridDim, " "))
	s.pnts.y = str2num(StringFromList(2, gridDim, " "))
	
	SVAR/Z gridSettings = 'Grid settings'
	s.center.x = str2num(StringFromList(0,gridSettings))
	s.center.y = str2num(StringFromList(1,gridSettings))
	s.size.x = str2num(StringFromList(2,gridSettings))
	s.size.y = str2num(StringFromList(3,gridSettings))
	s.angle = str2num(StringFromList(4,gridSettings))
	
	s.type = StrVarOrDefault("Filetype", "")
	s.signal = StrVarOrDefault("Sweep Signal", "")
	s.paramList = StrVarOrDefault("Fixed parameters", "") + ";" + StrVarOrDefault("Experiment parameters", "")
	s.numParam = NumVarOrDefault("# Parameters (4 byte)",NaN)
	s.expSize = NumVarOrDefault("Experiment size (bytes)", NaN)
	s.pnts.z = NumVarOrDefault("Points", NaN)
	s.channels = StrVarOrDefault("Channels", "")
	s.delay = NumVarOrDefault("Delay before measuring (s)", NaN)
	s.exp = StrVarOrDefault("Experiment", "")
	
	Variable dd, mm, yyyy, hour, minite, second
	SVAR/Z startTime = 'Start time'
	if (SVAR_Exists(startTime))
		sscanf startTime, "%d.%d.%d %d:%d:%d", dd, mm, yyyy, hour, minite, second
		s.start = date2secs(yyyy,mm,dd) + hour*3600 + minite*60 + second
	endif
	SVAR/Z endTime = 'End time'
	if (SVAR_Exists(endTime))
		sscanf endTime, "%d.%d.%d %d:%d:%d", dd, mm, yyyy, hour, minite, second
		s.end = date2secs(yyyy,mm,dd) + hour*3600 + minite*60 + second
	endif
	
	s.user = StrVarOrDefault("User", "")
	s.temperature = NumVarOrDefault("Temperature", NaN)
	s.field = NumVarOrDefault("Field", NaN)
	s.comment = StrVarOrDefault("Comment", "")
	
	LoadNanonis3dsGetHeaderBias(s)
	LoadNanonis3dsGetHeaderBiasSpec(s)
	LoadNanonis3dsGetHeaderCurrent(s)
	LoadNanonis3dsGetHeaderLockin(s)
	LoadNanonis3dsGetHeaderMain(s)
	LoadNanonis3dsGetHeaderPiezo(s)
	LoadNanonis3dsGetHeaderScan(s)
	LoadNanonis3dsGetHeaderZCtrl(s)
End

Static Function LoadNanonis3dsGetHeaderBias(STRUCT Nanonis3ds &s)
	s.bias.value = NumVarOrDefault(":Bias:'Bias (V)'", NaN)
	s.bias.calibration = NumVarOrDefault(":Bias:'Calibration (V/V)'", NaN)
	s.bias.offset = NumVarOrDefault(":Bias:'Offset (V)'", NaN)
End

Static Function LoadNanonis3dsGetHeaderBiasSpec(STRUCT Nanonis3ds &s)
	s.spec.start = NumVarOrDefault(":'Bias Spectroscopy':'Sweep Start (V)'", NaN)
	s.spec.end = NumVarOrDefault(":'Bias Spectroscopy':'Sweep End (V)'", NaN)
	s.spec.zpnts = NumVarOrDefault(":'Bias Spectroscopy':'Num Pixel'", NaN)
	s.spec.zavg = NumVarOrDefault(":'Bias Spectroscopy':'Z Avg time (s)'", NaN)
	s.spec.zoffset = NumVarOrDefault(":'Bias Spectroscopy':'Z offset (m)'", NaN)
	s.spec.initdelay = NumVarOrDefault(":'Bias Spectroscopy':'1st Settling time (s)'", NaN)
	s.spec.sampledelay = NumVarOrDefault(":'Bias Spectroscopy':'Settling time (s)'", NaN)
	s.spec.integ = NumVarOrDefault(":'Bias Spectroscopy':'Integration time (s)'", NaN)
	s.spec.enddelay = NumVarOrDefault(":'Bias Spectroscopy':'End Settling time (s)'", NaN)
	s.spec.rate = NumVarOrDefault(":'Bias Spectroscopy':'Max Slew rate (V/s)'", NaN)
	s.spec.zctrl = NumVarOrDefault(":'Bias Spectroscopy':'Z control time (s)'", NaN)
	s.spec.backward = StrVarOrDefault(":'Bias Spectroscopy':'backward sweep'", "")
	s.spec.hold = StrVarOrDefault(":'Bias Spectroscopy':'Z-controller hold'", "")
	s.spec.sweeps = NumVarOrDefault(":'Bias Spectroscopy':'Number of sweeps'", NaN)
	s.spec.channels = StrVarOrDefault(":'Bias Spectroscopy':Channels", "")
	s.spec.resetbias = StrVarOrDefault(":'Bias Spectroscopy':'Reset Bias'", "")
	s.spec.finalz = StrVarOrDefault(":'Bias Spectroscopy':'Record final Z'", "")
	s.spec.lockin = StrVarOrDefault(":'Bias Spectroscopy':'Lock-In run'", "")
	s.spec.mode = StrVarOrDefault(":'Bias Spectroscopy':'Sweep mode'", "")
End

Static Function LoadNanonis3dsGetHeaderCurrent(STRUCT Nanonis3ds &s)
	s.current.value = NumVarOrDefault(":Current:'Current (A)'", NaN)
	s.current.calibration = NumVarOrDefault(":Current:'Calibration (A/V)'", NaN)
	s.current.offset = NumVarOrDefault(":Current:'Offset (A)'", NaN)
End

Static Function LoadNanonis3dsGetHeaderLockin(STRUCT Nanonis3ds &s)
	s.lockin.status = StrVarOrDefault(":'Lock-in':'Lock-in status'", "")
	s.lockin.modulated = StrVarOrDefault(":'Lock-in':'Modulated signal'", "")
	s.lockin.freq = NumVarOrDefault(":'Lock-in':'Frequency (Hz)'", NaN)
	s.lockin.amp = NumVarOrDefault(":'Lock-in':Amplitude", NaN)
	s.lockin.signal = StrVarOrDefault(":'Lock-in':'Demodulated signal'", "")
	s.lockin.harmonic = NumVarOrDefault(":'Lock-in':Harmonic", NaN)
	s.lockin.phase = NumVarOrDefault(":'Lock-in':'Reference phase (deg)'", NaN)
End

Static Function LoadNanonis3dsGetHeaderMain(STRUCT Nanonis3ds &s)
	s.main.path = StrVarOrDefault(":NanonisMain:'Session Path'", "")
	s.main.version = StrVarOrDefault(":NanonisMain:'SW Version'", "")
	s.main.ui = NumVarOrDefault(":NanonisMain:'UI Release'", NaN)
	s.main.rt = NumVarOrDefault(":NanonisMain:'RT Release'", NaN)
	s.main.freq = NumVarOrDefault(":NanonisMain:'RT Frequency (Hz)'", NaN)
	s.main.oversampling = NumVarOrDefault(":NanonisMain:'Signals Oversampling'", NaN)
	s.main.animations = NumVarOrDefault(":NanonisMain:'Animations Period (s)'", NaN)
	s.main.indicators = NumVarOrDefault(":NanonisMain:'Indicators Period (s)'", NaN)
	s.main.measurements = NumVarOrDefault(":NanonisMain:'Measurements Period (s)'", NaN)
End

Static Function LoadNanonis3dsGetHeaderPiezo(STRUCT Nanonis3ds &s)
	s.piezo.active = StrVarOrDefault(":'Piezo Calibration':'Active Calib.'", "")
	s.piezo.piezo.x = NumVarOrDefault(":'Piezo Calibration':'Calib. X (m/V)'", NaN)
	s.piezo.piezo.y = NumVarOrDefault(":'Piezo Calibration':'Calib. Y (m/V)'", NaN)
	s.piezo.piezo.z = NumVarOrDefault(":'Piezo Calibration':'Calib. Z (m/V)'", NaN)
	s.piezo.gain.x = NumVarOrDefault(":'Piezo Calibration':'HV Gain X'", NaN)
	s.piezo.gain.y = NumVarOrDefault(":'Piezo Calibration':'HV Gain Y'", NaN)
	s.piezo.gain.z = NumVarOrDefault(":'Piezo Calibration':'HV Gain Z'", NaN)
	s.piezo.tilt.x = NumVarOrDefault(":'Piezo Calibration':'Tilt X (deg)'", NaN)
	s.piezo.tilt.y = NumVarOrDefault(":'Piezo Calibration':'Tilt Y (deg)'", NaN)
	s.piezo.curvature.x = NumVarOrDefault(":'Piezo Calibration':'Curvature radius X (m)'", NaN)
	s.piezo.curvature.y = NumVarOrDefault(":'Piezo Calibration':'Curvature radius Y (m)'", NaN)
	s.piezo.correction.x = NumVarOrDefault(":'Piezo Calibration':'2nd order corr X (V/m^2)'", NaN)
	s.piezo.correction.y = NumVarOrDefault(":'Piezo Calibration':'2nd order corr Y (V/m^2)'", NaN)
	s.piezo.drift.x = NumVarOrDefault(":'Piezo Calibration':'Drift X (m/s)'", NaN)
	s.piezo.drift.y = NumVarOrDefault(":'Piezo Calibration':'Drift Y (m/s)'", NaN)
	s.piezo.drift.z = NumVarOrDefault(":'Piezo Calibration':'Drift Z (m/s)'", NaN)
	s.piezo.status = StrVarOrDefault(":'Piezo Calibration':'Drift correction status (on/off'", "")
End

Static Function LoadNanonis3dsGetHeaderScan(STRUCT Nanonis3ds &s)
	String str = StrVarOrDefault(":scan:Scanfield","")
	s.scan.center.x = strlen(str) ? str2num(StringFromList(0, str)) : NaN
	s.scan.center.y = strlen(str) ? str2num(StringFromList(1, str)) : NaN
	s.scan.size.x = strlen(str) ? str2num(StringFromList(2, str)) : NaN
	s.scan.size.y = strlen(str) ? str2num(StringFromList(3, str)) : NaN
	s.scan.angle = strlen(str) ? str2num(StringFromList(4, str)) : NaN
	s.scan.name = StrVarOrDefault(":scan:'series name'", "")
	s.scan.channels = StrVarOrDefault(":scan:channels", "")
	s.scan.pnts.x = NumVarOrDefault(":scan:'pixels/line'", NaN)
	s.scan.pnts.y = NumVarOrDefault(":scan:lines", NaN)
	s.scan.forward = NumVarOrDefault(":scan:'speed forw. (m/s)'", NaN)
	s.scan.backward = NumVarOrDefault(":scan:'speed backw. (m/s)'", NaN)
End

Static Function LoadNanonis3dsGetHeaderZCtrl(STRUCT Nanonis3ds &s)
	s.zctrl.z = NumVarOrDefault(":'Z-Controller':'Z (m)'", NaN)
	s.zctrl.name = StrVarOrDefault(":'Z-Controller':'Controller name'", "")
	s.zctrl.status = StrVarOrDefault(":'Z-Controller':'Controller status'", "")
	s.zctrl.setpoint = NumVarOrDefault(":'Z-Controller':Setpoint", NaN)
	s.zctrl.unit = StrVarOrDefault(":'Z-Controller':'Setpoint unit'", "")
	s.zctrl.p = NumVarOrDefault(":'Z-Controller':'P gain'", NaN)
	s.zctrl.i = NumVarOrDefault(":'Z-Controller':'I gain'", NaN)
	s.zctrl.tconst = NumVarOrDefault(":'Z-Controller':'Time const (s)'", NaN)
	s.zctrl.lift = NumVarOrDefault(":'Z-Controller':'TipLift (m)'", NaN)
	s.zctrl.delay = NumVarOrDefault(":'Z-Controller':'Switch off delay (s)'", NaN)
End

Static Structure Nanonis3ds
	STRUCT	ixyz	pnts			//	Grid dim, Points
	STRUCT	vxy	center, size	//	Grid settings
	Variable	angle			//	Grid settings
	String	type				//	Filetype
	String	signal			//	Sweep signal
	String	paramList		//	Fixed parameters + ";" + Experiment parameters
	uint16	numParam		//	# Parameters (4 byte)
	uint16	expSize			//	Experiment size (bytes)
	String	channels			//	Channels
	Variable	delay			//	Delay before measuring (s)
	String	exp				//	Experiment
	uint32	start, end		//	Start time, End time
	String	user				//	User
	Variable	temperature		//	Temperature	(拡張), 使用されていない場合には NaN
	Variable	field				//	Field (拡張), 使用されていない場合には NaN
	String	comment		//	Comment
	STRUCT	Nanonis3dsSetpoint	bias
	STRUCT	Nanonis3dsBiasSpectrscopy	spec
	STRUCT	Nanonis3dsSetpoint	current
	STRUCT	Nanonis3dsLockin		lockin
	STRUCT	Nanonis3dsMain		main
	STRUCT	Nanonis3dsPiezo		piezo
	STRUCT	Nanonis3dsScan		scan
	STRUCT	Nanonis3dsZCtrl		zctrl
	Wave	mlsw			//	MLSモードでのｌ電圧情報
	uint16	headerSize		//	ヘッダのサイズ, 読み込みルーチン用
	String	filename			//	ファイル名, ログ作成用
EndStructure

Static Structure Nanonis3dsSetpoint
	Variable	value			//	Bias (V), Current (A)
	Variable	calibration		//	calibration (V/V)
	Variable	offset			//	Offset (V)
	Variable	gain				//	Gain
EndStructure

Static Structure Nanonis3dsBiasSpectrscopy
	Variable	start, end		//	Sweep Start (V), Sweep End (V)
	uint16	zpnts			//	Num Pixels
	Variable	zavg				//	Z Avg time (s)
	Variable	zoffset			//	Z offset (m)
	Variable	initdelay			//	1st Settling time (s)
	Variable	sampledelay		//	Settling time (s)
	Variable	integ			//	Integration time (s)
	Variable	enddelay			//	End Settling time (s)
	Variable	zctrl			//	Z control time (s)
	Variable	rate				//	Max Slew rate (V/s)
	String	backward			//	backward sweep
	String	hold				//	Z-controller hold
	uint16	sweeps			//	Number of sweeps
	String	channels			//	Channels
	String	resetbias			//	Reset bias
	String	finalz			//	Record final Z
	String	lockin			//	Lock-in run
	String	mode			//	Sweep mode
EndStructure

Static Structure Nanonis3dsLockin
	String 	status			//	Lock-in status
	String	modulated		//	Modulated signal
	Variable	freq				//	Frequency (Hz)
	Variable	amp				//	Amplitude
	String 	signal			//	Demodulated signal
	uchar	harmonic		//	Harmonic
	Variable	phase			//	Reference phase (deg)
EndStructure

Static Structure Nanonis3dsMain
	String	path				//	Session path
	String	version			//	SW Version
	uint16	ui				//	UI Release
	uint16	rt				//	RT Release
	Variable	freq				//	RT Frequency (Hz)
	uint16	oversampling		//	Signals Oversampling
	Variable	animations		//	Animations Period (s)
	Variable	indicators		//	Indicators Period (s)
	Variable	measurements	//	Measurements Period (s)
EndStructure

Static Structure Nanonis3dsPiezo
	String	active			//	Avtive calib.
	STRUCT	vxyz	piezo		//	Calib. X, Y, Z (m/V)
	STRUCT	ixyz	gain			//	HV Gain X, Y, Z
	STRUCT	vxy	tilt			//	Tilt X, Y (deg)
	STRUCT	vxy	curvature	//	Curvature radius X, Y (m)
	STRUCT	vxy	correction	//	2nd order corr X, Y (V/m^2)
	STRUCT	vxyz	drift			//	Drift X, Y, Z (m/s)
	String	status			//	Drift correction status (on/off)
EndStructure

Static Structure Nanonis3dsScan
	STRUCT	vxy	center, size	//	Scanfield
	Variable	angle			//	Scanfield
	String	name			//	series name
	String	channels			//	channels
	STRUCT	ixy	pnts			//	pixels/line, lines
	Variable	forward			//	speed forw. (m/s)
	Variable	backward			//	speed backw. (m/s)
EndStructure

Static Structure Nanonis3dsZCtrl
	Variable	z				//	Z (m)
	String	name			//	Controller name
	String	status			//	Controller status
	Variable	setpoint			//	Setpoint
	String	unit				//	Setpoint unit
	Variable	p				//	P gain
	Variable	i				//	I gain
	Variable	tconst			//	Time constant (s)
	Variable	lift				//	Tiplift (m)
	Variable	delay			//	Switch off delay (s)
EndStructure

Static Structure vxyz
	Variable	x
	Variable	y
	Variable	z
EndStructure

Static Structure vxy
	Variable	x
	Variable	y
EndStructure

Static Structure ixyz
	uint16	x
	uint16	y
	uint16	z
EndStructure

Static Structure ixy
	uint16	x
	uint16	y
EndStructure

//******************************************************************************
//	データ読み込み
//		読み込まれたウエーブはカレントデータフォルダへ保存される
//******************************************************************************
Static Function/WAVE LoadNanonis3dsGetData(String pathStr, STRUCT Nanonis3ds &s)
	String fileName = ParseFilePath(3, pathStr, ":", 0, 0)	//	拡張子抜きの名前
	
	//	ファイルからデータを読み込み、ウエーブを作る
	GBLoadWave/Q/N=tmp/T={2,4}/S=(s.headerSize)/W=1 pathStr
	wave w=tmp0
	Redimension/N=(ItemsInList(s.paramList)+ItemsInList(s.channels)*s.pnts.z, s.pnts.x, s.pnts.y) w
	
	//	読み込まれたウエーブからSTM像ウエーブを構成する
	Wave stmw = LoadNanonis3dsGetDataParam(w, fileName, s)
	
	// 各チャンネルの名前からウエーブ名を構成する
	Wave/T namew = LoadNanonis3dsGetDataWaveNames(fileName, s.channels)
	
	//	読み込まれたウエーブからスペクトルウエーブを構成する
	Wave/WAVE specw = LoadNanonis3dsGetDataSpec(w, namew, s)
	
	if (GetKeyState(1)&4)	//	shiftが押されていたら
		//	読み込まれたウエーブへの参照ウエーブを構成する
		Make/N=(1+numpnts(specw))/WAVE/FREE refw
		refw[0] = {stmw}
		refw[1,] = specw[p-1]
	else
		//	スペクトルウエーブの fwd と bwd の平均を求める
		Wave/WAVE avgw = LoadNanonisCommonDataAvg("_bwd")
		//	読み込まれたウエーブへの参照ウエーブを構成する
		Make/N=(1+numpnts(avgw))/WAVE/FREE refw
		refw[0] = {stmw}
		refw[1,] = avgw[p-1]
	endif
	
	KillWaves w
	return refw
End

//----------------------------------------------------------------------
//	ファイルから読み込んだ一つの大きなウエーブから、STM像など構成
//		STM像ウエーブはカレントデータフォルダへ保存する
//		返り値はSTM像ウエーブへの参照
//----------------------------------------------------------------------
Static Function/WAVE LoadNanonis3dsGetDataParam(
	Wave w,
	String fileName,
	STRUCT Nanonis3ds &s
	)
	
	Variable xIndex = WhichListItem("X (m)", s.paramList)	//	2
	Variable yIndex = WhichListItem("Y (m)", s.paramList)	//	3
	Variable zIndex = WhichListItem("Z (m)", s.paramList)	//	4
	
	DFREF dfrSav = GetDataFolderDFR()
	NewDataFolder/S pos
	
	//	測定範囲を構成
	Make/N=5/FREE xw = {-1, 1, 1, -1, -1}, yw = {-1, -1, 1, 1, -1}
	Make/N=5 scan_x = ((xw*cos(s.angle/180*pi) + yw*sin(s.angle/180*pi)) * s.size.x/2 + s.center.x) * 1e10	//	m -> angstrom
	Make/N=5 scan_y = ((-xw*sin(s.angle/180*pi) + yw*cos(s.angle/180*pi)) * s.size.y/2 + s.center.y) * 1e10	//	m -> angstrom
	
	//	STS測定点を構成
	MatrixOP/FREE tw0 = transposeVol(w,4)*1e10	//	m -> angstrom
	MatrixOP stspos_x = tw0[][][xIndex]
	MatrixOP stspos_y = tw0[][][yIndex]
	Redimension/N=(s.pnts.x*s.pnts.y)/S stspos_x, stspos_y
	
	SetDataFolder dfrSav
	
	//	STM像を構成
	if (s.pnts.y == 1)	//Linecut
		Make/N=(s.pnts.x) $(fileName+"_Z")/WAVE=topow
		topow[] = w[zIndex][p]*1e10					//	angstrom
	else
		Make/N=(s.pnts.x, s.pnts.y) $(fileName+"_Z")/WAVE=topow
		MultiThread topow[][] = w[zIndex][p][q]*1e10		//	angstrom
	endif
	SetScale d WaveMin(topow), WaveMax(topow), "\u00c5", w
	
	//	測定点座標は、測定領域端よりもピクセルの幅の半分だけ内側に入っている
	SetScale/P x (s.center.x-s.size.x/2+s.size.x/s.pnts.x/2)*1e10, s.size.x/s.pnts.x*1e10, "\u00c5", topow	//	m -> angstrom
	SetScale/P y (s.center.y-s.size.y/2+s.size.y/s.pnts.y/2)*1e10, s.size.y/s.pnts.y*1e10, "\u00c5", topow	//	m -> angstrom
	
	return topow
End

//----------------------------------------------------------------------
//	ヘッダのチャンネル名からウエーブ名を構成する
//----------------------------------------------------------------------
Static Function/WAVE LoadNanonis3dsGetDataWaveNames(String fileName, String chanList)
	
	Make/N=(ItemsInList(chanList))/T/FREE namew
	String nameStr
	Variable i
	for (i = 0; i < ItemsInList(chanList); i += 1)
		nameStr = StringFromList(i, chanList)
		nameStr = ReplaceString(" (A)", nameStr, "")
		nameStr = ReplaceString(" (V)", nameStr, "")
		nameStr = ReplaceString(" omega", nameStr, "")
		nameStr = ReplaceString(" [bwd]", nameStr, "_bwd")
		nameStr = ReplaceString(" ", nameStr, "_")
		nameStr = filename + "_" + nameStr
		if (strlen(nameStr) > MAX_OBJ_NAME-4)		//	-4 は _bwd の分
			if (strsearch(nameStr, "_bwd", 0) == -1)
				namew[i] = nameStr[0,MAX_OBJ_NAME-1-4]
			else
				nameStr = ReplaceString("_bwd", nameStr, "")	//	一度 _bwd を削除して
				namew[i] = nameStr[0,MAX_OBJ_NAME-1-4] + "_bwd"
			endif
		else
			namew[i] = nameStr
		endif
	endfor
	
	return namew
End

//----------------------------------------------------------------------
//	ファイルから読み込んだ一つの大きなウエーブから、チャンネル毎にスペクトルウエーブを構成
//		結果のウエーブはカレントデータフォルダへ保存する
//		返り値は各スペクトルウエーブへの参照ウエーブ
//----------------------------------------------------------------------
Static Function/WAVE LoadNanonis3dsGetDataSpec(
	Wave w,
	Wave/T namew,
	STRUCT Nanonis3ds &s
	)
	
	Variable startIndex = WhichListItem("Sweep Start", s.paramList)	//	0のはず
	Variable endIndex = WhichListItem("Sweep End", s.paramList)	//	1のはず
	Variable biasStart = w[startIndex][0][0], biasEnd = w[endIndex][0][0]
	Variable nchan = ItemsInList(s.channels), nparam =  ItemsInList(s.paramList)
	Variable i, v
	
	Make/N=(nchan)/FREE/WAVE refw
	
	for (i = 0; i < nchan; i += 1)
		
		v = nparam + i*s.pnts.z
		Duplicate/FREE/R=[v,v+s.pnts.z-1][][] w tw
		
		//	MatrixOP $namew[i] = fp32(transposeVol(tw2,4)) とするよりも、先にfp32を実行してしまうほうが少し速い
		MatrixOP/FREE tw2 = fp32(tw)
		//	ラインカットの場合には上のMatrixOPで次元が落ちてしまうため、transposeVolでエラーが出るのを防ぐ必要がある
		if (!DimSize(tw2,2))
			Redimension/N=(-1,-1,1) tw2
		endif
		MatrixOP $namew[i]/WAVE=specw = transposeVol(tw2,4)
		
		if (s.pnts.y == 1)		//	linecut
			SetScale/I x, 0, s.size.x*1e10, "\u00c5", specw				//	m -> angstrom
		else
			//	測定点座標は、測定領域端よりもピクセルの幅の半分だけ内側に入っている
			SetScale/P x (s.center.x-s.size.x/2+s.size.x/s.pnts.x/2)*1e10, s.size.x/s.pnts.x*1e10, "\u00c5", specw	//	m -> angstrom
			SetScale/P y (s.center.y-s.size.y/2+s.size.y/s.pnts.y/2)*1e10, s.size.y/s.pnts.y*1e10, "\u00c5", specw	//	m -> angstrom
		endif
		
		if (WaveExists(s.mlsw))	//	MLS
			LoadNanonis3dsSetMLSBias(specw, s.mlsw)
		else					//	linear
			SetScale/I z, biasStart*1e3, biasEnd*1e3, "mV", specw	//	V -> mV
			if (biasStart > biasEnd)
				Reverse/DIM=2 specw
			endif
		endif
		
		//	物理値に変換
		LoadNanonisCommonConversion(specw, driveamp=s.lockin.amp, modulated=s.lockin.modulated)
		
		refw[i] = {specw}
	endfor
	
	return refw
End

//----------------------------------------------------------------------
//	multiline segments関連
//----------------------------------------------------------------------
//	バイアス電圧の値をDimension labelに保存
Static Function LoadNanonis3dsSetMLSBias(Wave specw, Wave mlsw)
	int segIndex, segSteps, layer, i, n, last
	Variable segStart, segEnd
	
	Make/N=0/FREE ew
	for (segIndex = 0, layer = 0; segIndex < DimSize(mlsw,0); segIndex++)
		segStart = mlsw[segIndex][0]
		segEnd = mlsw[segIndex][1]
		segSteps = mlsw[segIndex][4]
		last = (segIndex == DimSize(mlsw,0)-1) ? segSteps : segSteps-1
		for (i = 0; i < last; i++, layer++)
			n = numpnts(ew)
			Redimension/N=(n+1) ew
			ew[n] = segStart + (segEnd - segStart) / (segSteps - 1) * i
		endfor
	endfor
	ew *= 1e3	//	V -> mV
	
	KMSetBias(specw, ew)
End


//******************************************************************************
//	ログ出力
//******************************************************************************
Static Constant k_numoflogitems = 101

Function KMNanonis3dsLog(String pathStr, [int history])
	history = ParamIsDefault(history) ? 0 : history
	
	String str
	
	Wave/T w = searchFolders(pathStr,historyStr=str)
	Wave/T labelw = getLogLabels()
	
	int nx = DimSize(w,0), ny = DimSize(w,1), i
	
	//	行と列を入れ替えて、新しいファイルが上に来る順で出力
	//	(テキストウエーブにはReverseが使えない)
	String name = UniqueName("log",1,0)
	Make/N=(ny,nx)/T $name/WAVE=logw = w[q][ny-1-p]
	
	//	ラベル設定
	for (i = 0; i < nx; i++)
		SetDimLabel 1, i, $(labelw[i]), logw
	endfor
	
	Edit/K=1 logw.ld
	String tblName = S_name
	ModifyTable/W=$tblName selection=(0,1,ny-1,nx,0,0)		//	左端の分をずらして選択する
	ModifyTable/W=$tblName showParts=2^2+2^4+2^5+2^6+2^7	//	insertion cells (2^7)がないと最後の行が選択できない
	
	SetWindow $tblName hook(this)=LoadNanonis3ds#tblHook
	SetWindow $tblName userData(src)=GetWavesDataFolder(logw,2)
	
	if (history)
		printf ,"%sKMNanonis3dsLog(\"%s\")\r", PRESTR_CMD, str
	endif
End

Static Function/WAVE searchFolders(String pathStr, [String &historyStr])
	int i, n
	
	GetFileFolderInfo/D/Q/Z=2 pathStr	//	pathStr が存在しなければ選択ダイアログを出す
	if (V_Flag == -1)	//	ダイアログが出てキャンセルされた場合
		Abort
	elseif (!V_isFolder)	//	pathStr がフォルダへのパスでなければ、何もしない
		return $""
	endif
	pathStr = S_path
	if (!ParamIsDefault(historyStr))
		historyStr = pathStr
	endif
	
	Make/N=(k_numoflogitems)/T/FREE resw
	String pathName = UniqueName("path", 12, 0)
	NewPath/Q/Z $pathName, pathStr
	
	//	フォルダを含む場合は、それらのフォルダへのパスを引数として自身を呼び出す
	n = ItemsInList(IndexedDir($pathName, -1, 0))
	for (i = 0; i < n; i++)
		Wave/T logw = searchFolders(IndexedDir($pathName, i, 1))
		if (numpnts(logw))
			Concatenate/NP=1/T {logw}, resw
		endif
	endfor
	
	//	3dsファイルを含む場合は、それらへのパスを引数としてログ作成関数を呼び出す
	n = ItemsInList(IndexedFile($pathName, -1, ".3ds"))
	for (i = 0; i < n; i += 1)
		Wave/T logw = extractHeaderFromFile(ParseFilePath(2, pathStr, ":", 0, 0) + IndexedFile($pathName, i, ".3ds"))
		if (numpnts(logw))
			Concatenate/NP=1/T {logw}, resw
		endif
	endfor
	
	KillPath $pathName
	DeletePoints/M=1 0, 1, resw	//	最初に空ウエーブを作成した分
	
	return resw
End

Static Function/WAVE extractHeaderFromFile(String pathStr)
	DFREF dfrSav = GetDataFolderDFR()
	SetDataFolder NewFreeDataFolder()
	STRUCT Nanonis3ds s
	LoadNanonis3dsGetHeader(pathStr, s)
	SetDataFolder dfrSav
	
	return collectLogValues(s)
End

Static Function/WAVE collectLogValues(STRUCT Nanonis3ds &s)
	Make/N=(k_numoflogitems)/T/FREE w
	
	w[0] = putQuotationmark(s.filename)
	w[1] = {num2str(s.pnts.x), num2str(s.pnts.y), num2str(s.pnts.z)}
	w[4] = {num2str(s.size.x*1e9), num2str(s.size.y*1e9), num2str(s.center.x*1e9), num2str(s.center.y*1e9), num2str(s.angle)}
	w[9] = {s.type, s.signal, s.paramList, num2str(s.numParam), num2str(s.expSize), s.channels, num2str(s.delay), s.exp}
	w[17] = Secs2Date(s.start, -2) + " " + Secs2Time(s.start, 3)
	w[18] = Secs2Date(s.end, -2) + " " + Secs2Time(s.end, 3)
	w[19] = s.user
	w[20] = {num2str(s.temperature), num2str(s.field)}
	w[22] = putQuotationmark(s.comment)
	w[23] = {num2str(s.bias.value), num2str(s.bias.calibration), num2str(s.bias.offset)}
	w[26] = {num2str(s.spec.start), num2str(s.spec.end), num2str(s.spec.zpnts)}
	w[29] = {num2str(s.spec.zavg*1e3), num2str(s.spec.zoffset*1e9)}
	w[31] = {num2str(s.spec.initdelay*1e3), num2str(s.spec.sampledelay*1e3), num2str(s.spec.integ*1e3), num2str(s.spec.enddelay*1e3)}
	w[35] = {num2str(s.spec.zctrl*1e3), num2str(s.spec.rate), s.spec.backward, s.spec.hold, num2str(s.spec.sweeps)}
	w[40] = {s.spec.channels, s.spec.resetbias, s.spec.finalz, s.spec.lockin, s.spec.mode}
	w[45] = {num2str(s.current.value*1e12), num2str(s.current.calibration*1e9), num2str(s.current.offset*1e12)}
	w[48] = {s.lockin.status, s.lockin.modulated, num2str(s.lockin.freq), num2str(s.lockin.amp*1e3)}
	w[52] = {s.lockin.signal, num2str(s.lockin.harmonic), num2str(s.lockin.phase)}
	w[55] = {putQuotationmark(s.main.path), s.main.version, num2str(s.main.ui), num2str(s.main.rt), num2str(s.main.freq)}
	w[60] = {num2str(s.main.oversampling), num2str(s.main.animations*1e3), num2str(s.main.indicators*1e3), num2str(s.main.measurements*1e3)}
	w[64] = s.piezo.active
	w[65] = {num2str(s.piezo.piezo.x*1e9), num2str(s.piezo.piezo.y*1e9), num2str(s.piezo.piezo.z*1e9)}
	w[68] = {num2str(s.piezo.gain.x), num2str(s.piezo.gain.y), num2str(s.piezo.gain.z)}
	w[71] = {num2str(s.piezo.tilt.x), num2str(s.piezo.tilt.y)}
	w[73] = {num2str(s.piezo.curvature.x), num2str(s.piezo.curvature.y)}
	w[75] = {num2str(s.piezo.correction.x), num2str(s.piezo.correction.y)}
	w[77] = {num2str(s.piezo.drift.x), num2str(s.piezo.drift.y), num2str(s.piezo.drift.z)}
	w[80] = s.piezo.status
	w[81] = {num2str(s.scan.center.x*1e9), num2str(s.scan.center.y*1e9), num2str(s.scan.size.x*1e9), num2str(s.scan.size.y*1e9), num2str(s.scan.angle)}
	w[86] = {putQuotationmark(s.scan.name), s.scan.channels}
	w[88] = {num2str(s.scan.pnts.x), num2str(s.scan.pnts.y), num2str(s.scan.forward*1e9), num2str(s.scan.backward*1e9)}
	w[92] = {num2str(s.zctrl.z*1e9), s.zctrl.name, s.zctrl.status, num2str(s.zctrl.setpoint*1e12)}
	w[96] = {num2str(s.zctrl.p), num2str(s.zctrl.i), num2str(s.zctrl.tconst), num2str(s.zctrl.lift*1e9), num2str(s.zctrl.delay)}
	
	return w
End

Static Function/WAVE getLogLabels()
	Make/N=(k_numoflogitems)/T/FREE w
	
	w[0] = {"Filename", "nx", "ny", "nz", "Scan size X (nm)", "Scan size Y (nm)", "Center X (nm)", "Center Y (nm)", "Angle (deg)"}
	w[9] = {"Filetype", "Sweep Signal", "Parameters", "# Parameters", "Exp size (bytes)", "Channels", "Delay before measuring (s)", "Experiment"}
	w[17] = {"Start", "End"}
	w[19] = {"User", "Temperature (K)", "Field (T)", "Comment"}
	
	w[23] = {"Bias (V)", "Calibration (V/V)", "Offset (V)"}
	w[23,25] = "Bias > "+w[p]
	
	w[26] = {"Sweep Start (V)", "Sweep End (V)", "Num pixel"}
	w[29] = {"Z Avg time (ms)", "Z offset (nm)"}
	w[31] = {"1st Settling time (ms)", "Settling time (ms)", "Integration time (ms)", "End Settling time (ms)"}
	w[35] = {"Z control time (ms)", "Max Slew rate (V/s)", "backward sweep", "Z-controller hold", "Number of sweeps"}
	w[40] = {"Channels", "Reset Bias", "Record final Z", "Lock-In run", "Sweep mode"}
	w[26,44] = "Bias Spectroscopy > "+w[p]
	
	w[45] = {"Current (pA)", "Calibration (nA/V)", "Offset (pA)"}
	w[45,47] = "Current > "+w[p]
	
	w[48] = {"Lock-in status", "Modulated signal", "Frequency (Hz)", "Amplitude (mV)"}
	w[52] = {"Demodulated signal", "Harmonic", "Reference phase (deg)"}
	w[48,54] = "Lock-in > "+w[p]
	
	w[55] = {"Session Path", "SW Version", "UI Release", "RT Release", "RT Frequency (Hz)"}
	w[60] = {"Signals Oversampling", "Animations Period (ms)", "Indicators Period (ms)", "Measurements Period (ms)"}
	w[55,63] = "NanonisMain > "+w[p]
	
	w[64] = "Avtive calib."
	w[65] = {"Calib. X (nm/V)", "Calib. Y (nm/V)", "Calib. Z (nm/V)"}
	w[68] = {"HV Gain X", "HV Gain Y", "HV Gain Z"}
	w[71] = {"Tilt X (deg)", "Tilt Y (deg)"}
	w[73] = {"Curvature radius X (m)" , "Curvature radius Y (m)"}
	w[75] = {"2nd order corr X (V/m^2)", "2nd order corr Y (V/m^2)"}
	w[77] = {"Drift X (m/s)", "Drift Y (m/s)", "Drift Z (m/s)"}
	w[80] = "Drift correction status (on/off)"
	w[64,80] = "Piezo Calibration > "+w[p]
	
	w[81] = {"Center X (nm)", "Center Y (nm)", "Scan size X (nm)", "Scan size Y (nm)", "Angle (deg)"}
	w[86] = {"series name", "channels", "pixel/line", "lines", "speed forw. (nm/s)", "speed backw. (nm/s)"}
	w[81,91] = "Scan > "+w[p]
	
	w[92] = {"Z (nm)", "Controller name", "Controller status", "Setpoint (pA)"}
	w[96] = {"P gain", "I gain", "Time constant (s)", "Tip Lift (nm)", "Switch off delay (s)"}
	w[92,100] = "Z-Controller > "+w[p]
	
	return w
End

Static Function/S putQuotationmark(String str)
	return SelectString(strsearch(str, ",", 0)==-1, "\""+str+"\"", str)
End

Static Function tblHook(STRUCT WMWinHookStruct &s)	
	switch (s.eventCode)
		case 17:	//	killVote
			Wave w = $GetUserData(s.winName,"","src")
			RemoveFromTable/W=$s.winName $NameOfWave(w).ld
			KillWaves/Z w
			break
	endswitch
End