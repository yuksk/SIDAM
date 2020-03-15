#pragma TextEncoding="UTF-8"
#pragma rtGlobals=3
#pragma ModuleName=LoadNanonis3ds

#ifndef SIDAMshowProc
#pragma hide = 1
#endif

//******************************************************************************
//	ファイル読み込みメイン
//******************************************************************************
Function/WAVE LoadNanonis3ds(String pathStr)
	DFREF dfrSav = GetDataFolderDFR()	//	基準となるデータフォルダ
	
	//	ヘッダ読み込み
	NewDataFolder/O/S $SIDAM_DF_SETTINGS
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

Structure Nanonis3ds
	STRUCT	ixyz	pnts			//	Grid dim, Points
	STRUCT	vxy	center, size		//	Grid settings
	Variable	angle				//	Grid settings
	String	type					//	Filetype
	String	signal					//	Sweep signal
	String	paramList				//	Fixed parameters + ";" + Experiment parameters
	uint16	numParam				//	# Parameters (4 byte)
	uint16	expSize				//	Experiment size (bytes)
	String	channels				//	Channels
	Variable	delay				//	Delay before measuring (s)
	String	exp						//	Experiment
	uint32	start, end			//	Start time, End time
	String	user					//	User
	Variable	temperature		//	Temperature	(拡張), 使用されていない場合には NaN
	Variable	field				//	Field (拡張), 使用されていない場合には NaN
	String	comment				//	Comment
	STRUCT	Nanonis3dsSetpoint	bias
	STRUCT	Nanonis3dsBiasSpectrscopy	spec
	STRUCT	Nanonis3dsSetpoint	current
	STRUCT	Nanonis3dsLockin		lockin
	STRUCT	Nanonis3dsMain		main
	STRUCT	Nanonis3dsPiezo		piezo
	STRUCT	Nanonis3dsScan		scan
	STRUCT	Nanonis3dsZCtrl		zctrl
	Wave	mlsw					//	MLSモードでのｌ電圧情報
	uint16	headerSize			//	ヘッダのサイズ, 読み込みルーチン用
	String	filename				//	ファイル名, ログ作成用
EndStructure

Static Structure Nanonis3dsSetpoint
	Variable	value				//	Bias (V), Current (A)
	Variable	calibration		//	calibration (V/V)
	Variable	offset				//	Offset (V)
	Variable	gain				//	Gain
EndStructure

Static Structure Nanonis3dsBiasSpectrscopy
	Variable	start, end		//	Sweep Start (V), Sweep End (V)
	uint16	zpnts					//	Num Pixels
	Variable	zavg				//	Z Avg time (s)
	Variable	zoffset			//	Z offset (m)
	Variable	initdelay			//	1st Settling time (s)
	Variable	sampledelay		//	Settling time (s)
	Variable	integ				//	Integration time (s)
	Variable	enddelay			//	End Settling time (s)
	Variable	zctrl				//	Z control time (s)
	Variable	rate				//	Max Slew rate (V/s)
	String	backward				//	backward sweep
	String	hold					//	Z-controller hold
	uint16	sweeps					//	Number of sweeps
	String	channels				//	Channels
	String	resetbias				//	Reset bias
	String	finalz					//	Record final Z
	String	lockin					//	Lock-in run
	String	mode					//	Sweep mode
EndStructure

Static Structure Nanonis3dsLockin
	String 	status				//	Lock-in status
	String	modulated				//	Modulated signal
	Variable	freq				//	Frequency (Hz)
	Variable	amp					//	Amplitude
	String 	signal				//	Demodulated signal
	uchar	harmonic				//	Harmonic
	Variable	phase				//	Reference phase (deg)
EndStructure

Static Structure Nanonis3dsMain
	String	path					//	Session path
	String	version				//	SW Version
	uint16	ui						//	UI Release
	uint16	rt						//	RT Release
	Variable	freq				//	RT Frequency (Hz)
	uint16	oversampling			//	Signals Oversampling
	Variable	animations		//	Animations Period (s)
	Variable	indicators		//	Indicators Period (s)
	Variable	measurements		//	Measurements Period (s)
EndStructure

Static Structure Nanonis3dsPiezo
	String	active					//	Avtive calib.
	STRUCT	vxyz	piezo			//	Calib. X, Y, Z (m/V)
	STRUCT	ixyz	gain			//	HV Gain X, Y, Z
	STRUCT	vxy	tilt				//	Tilt X, Y (deg)
	STRUCT	vxy	curvature			//	Curvature radius X, Y (m)
	STRUCT	vxy	correction		//	2nd order corr X, Y (V/m^2)
	STRUCT	vxyz	drift			//	Drift X, Y, Z (m/s)
	String	status					//	Drift correction status (on/off)
EndStructure

Static Structure Nanonis3dsScan
	STRUCT	vxy	center, size		//	Scanfield
	Variable	angle				//	Scanfield
	String	name					//	series name
	String	channels				//	channels
	STRUCT	ixy	pnts				//	pixels/line, lines
	Variable	forward			//	speed forw. (m/s)
	Variable	backward			//	speed backw. (m/s)
EndStructure

Static Structure Nanonis3dsZCtrl
	Variable	z					//	Z (m)
	String	name					//	Controller name
	String	status					//	Controller status
	Variable	setpoint			//	Setpoint
	String	unit					//	Setpoint unit
	Variable	p					//	P gain
	Variable	i					//	I gain
	Variable	tconst				//	Time constant (s)
	Variable	lift				//	Tiplift (m)
	Variable	delay				//	Switch off delay (s)
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
	Variable sweepStart = w[startIndex][0][0], sweepEnd = w[endIndex][0][0]
	Variable nchan = ItemsInList(s.channels), nparam =  ItemsInList(s.paramList)
	int i, v
	
	Make/N=(nchan)/FREE/WAVE refw
	
	for (i = 0; i < nchan; i++)
		
		v = nparam + i*s.pnts.z
		Duplicate/FREE/R=[v,v+s.pnts.z-1][][] w tw
		
		//	MatrixOP $namew[i] = fp32(transposeVol(tw2,4)) とするよりも、先にfp32を実行してしまうほうが少し速い
		MatrixOP/FREE tw2 = fp32(tw)
		//	ラインカットの場合には上のMatrixOPで次元が落ちてしまうため、transposeVolでエラーが出るのを防ぐ必要がある
		if (!DimSize(tw2,2))
			Redimension/N=(-1,-1,1) tw2
		endif
		MatrixOP $CleanupName(namew[i],1)/WAVE=specw = transposeVol(tw2,4)	//	名前に : が含まれることがあるので CleanupName が必要
		
		if (s.pnts.y == 1)		//	linecut
			SetScale/I x, 0, s.size.x*1e10, "\u00c5", specw				//	m -> angstrom
		else
			//	測定点座標は、測定領域端よりもピクセルの幅の半分だけ内側に入っている
			SetScale/P x (s.center.x-s.size.x/2+s.size.x/s.pnts.x/2)*1e10, s.size.x/s.pnts.x*1e10, "\u00c5", specw	//	m -> angstrom
			SetScale/P y (s.center.y-s.size.y/2+s.size.y/s.pnts.y/2)*1e10, s.size.y/s.pnts.y*1e10, "\u00c5", specw	//	m -> angstrom
		endif
		
		if (WaveExists(s.mlsw))	//	MLS
			LoadNanonis3dsSetMLSBias(specw, s)
		else							//	linear
			strswitch (s.signal)
				case "Bias (V)":
					SetScale/I z, sweepStart*1e3, sweepEnd*1e3, "mV", specw			//	V -> mV
					break
				case "Z (m)":
					SetScale/I z, sweepStart*1e10, sweepEnd*1e10, "\u00c5", specw	//	m -> angstrom
					break
				default:
					SetScale/I z, sweepStart, sweepEnd, "", specw
					break
			endswitch
			if (sweepStart > sweepEnd)
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
Static Function LoadNanonis3dsSetMLSBias(Wave specw, STRUCT Nanonis3ds &s)
	Wave mlsw = s.mlsw
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
	
	strswitch (s.signal)
		case "Bias (V)":
			ew *= 1e3		//	V -> mV
			break
		case "Z (m)":
			ew *= 1e10	//	m -> angstrom
			break
		default:
			//	do nothing
	endswitch	
	
	SIDAMSetBias(specw, ew)
End
