#pragma TextEncoding="UTF-8"
#pragma rtGlobals=3
#pragma ModuleName=LoadNanonis3ds

#ifndef SIDAMshowProc
#pragma hide = 1
#endif

//	Main function
Function/WAVE SIDAMLoadNanonis3ds(String pathStr, int noavg)
	DFREF dfrSav = GetDataFolderDFR()
	
	//	Read the header
	NewDataFolder/O/S $SIDAM_DF_SETTINGS
	STRUCT Nanonis3ds s
	LoadNanonis3dsGetHeader(pathStr, s)
	
	//	Read the data
	SetDataFolder dfrSav
	Wave/WAVE resw = LoadNanonis3dsGetData(pathStr, noavg, s)
	
	if (s.angle != 0)
		SIDAMLoadDataNanonisCommon#nonZeroAngleCaution()
	endif
	
	return resw
End


//	Read the header
//
//	The values read from the header are saved as global variables
//	in the current datafolder.
//	Information necessary for the data reading function is saved to
//	the structure "s".
Static Function LoadNanonis3dsGetHeader(String pathStr, STRUCT Nanonis3ds &s)
	
	//	Save the header values as global variables
	s.headerSize = SIDAMLoadDataNanonisCommon#getHeaderDat3ds(pathStr)
	Wave/Z s.mlsw = 'multiline settings'
	s.filename = ParseFilePath(3, pathStr, ":", 0, 0)	//	filename w/o an extension
	
	//	Keep the header values in the structure for the data loading function.
	//	NumVarOrDefault and StrVarOrDefault are used because NVAR and SVAR
	//	do not have to be used. (NaN is not expected.)
	SVAR gridDim = $SIDAMNumStrName("Grid dim", 1)
	s.pnts.x = str2num(StringFromList(0, gridDim, " "))
	s.pnts.y = str2num(StringFromList(2, gridDim, " "))
	
	SVAR gridSettings = $SIDAMNumStrName("Grid settings", 1)
	s.center.x = str2num(StringFromList(0,gridSettings))
	s.center.y = str2num(StringFromList(1,gridSettings))
	s.size.x = str2num(StringFromList(2,gridSettings))
	s.size.y = str2num(StringFromList(3,gridSettings))
	s.angle = str2num(StringFromList(4,gridSettings))
	
	s.type = SIDAMStrVarOrDefault("Filetype", "")
	s.signal = SIDAMStrVarOrDefault("Sweep Signal", "")
	s.paramList = SIDAMStrVarOrDefault("Fixed parameters", "") + ";" \
		+ SIDAMStrVarOrDefault("Experiment parameters", "")
	s.numParam = SIDAMNumVarOrDefault("# Parameters (4 byte)", NaN)
	s.expSize = SIDAMNumVarOrDefault("Experiment size (bytes)", NaN)
	s.pnts.z = SIDAMNumVarOrDefault("Points", NaN)
	s.channels = SIDAMStrVarOrDefault("Channels", "")
	s.delay = SIDAMNumVarOrDefault("Delay before measuring (s)", NaN)
	s.exp = SIDAMStrVarOrDefault("Experiment", "")
	
	Variable dd, mm, yyyy, hour, minite, second
	SVAR/Z startTime = $SIDAMNumStrName("Start time", 1)
	if (SVAR_Exists(startTime))
		sscanf startTime, "%d.%d.%d %d:%d:%d", dd, mm, yyyy, hour, minite, second
		s.start = date2secs(yyyy,mm,dd) + hour*3600 + minite*60 + second
	endif
	SVAR/Z endTime = $SIDAMNumStrName("End time", 1)
	if (SVAR_Exists(endTime))
		sscanf endTime, "%d.%d.%d %d:%d:%d", dd, mm, yyyy, hour, minite, second
		s.end = date2secs(yyyy,mm,dd) + hour*3600 + minite*60 + second
	endif
	
	s.user = SIDAMStrVarOrDefault("User", "")
	s.temperature = SIDAMNumVarOrDefault("Temperature", NaN)
	s.field = SIDAMNumVarOrDefault("Field", NaN)
	s.comment = SIDAMStrVarOrDefault("Comment", "")
	
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
	s.bias.value = SIDAMNumVarOrDefault(":Bias:'Bias (V)'", NaN)
	s.bias.calibration = SIDAMNumVarOrDefault(":Bias:'Calibration (V/V)'", NaN)
	s.bias.offset = SIDAMNumVarOrDefault(":Bias:'Offset (V)'", NaN)
End

Static Function LoadNanonis3dsGetHeaderBiasSpec(STRUCT Nanonis3ds &s)
	s.spec.start = SIDAMNumVarOrDefault(":'Bias Spectroscopy':'Sweep Start (V)'", NaN)
	s.spec.end = SIDAMNumVarOrDefault(":'Bias Spectroscopy':'Sweep End (V)'", NaN)
	s.spec.zpnts = SIDAMNumVarOrDefault(":'Bias Spectroscopy':'Num Pixel'", NaN)
	s.spec.zavg = SIDAMNumVarOrDefault(":'Bias Spectroscopy':'Z Avg time (s)'", NaN)
	s.spec.zoffset = SIDAMNumVarOrDefault(":'Bias Spectroscopy':'Z offset (m)'", NaN)
	s.spec.initdelay = SIDAMNumVarOrDefault(":'Bias Spectroscopy':'1st Settling time (s)'", NaN)
	s.spec.sampledelay = SIDAMNumVarOrDefault(":'Bias Spectroscopy':'Settling time (s)'", NaN)
	s.spec.integ = SIDAMNumVarOrDefault(":'Bias Spectroscopy':'Integration time (s)'", NaN)
	s.spec.enddelay = SIDAMNumVarOrDefault(":'Bias Spectroscopy':'End Settling time (s)'", NaN)
	s.spec.rate = SIDAMNumVarOrDefault(":'Bias Spectroscopy':'Max Slew rate (V/s)'", NaN)
	s.spec.zctrl = SIDAMNumVarOrDefault(":'Bias Spectroscopy':'Z control time (s)'", NaN)
	s.spec.backward = SIDAMStrVarOrDefault(":'Bias Spectroscopy':'backward sweep'", "")
	s.spec.hold = SIDAMStrVarOrDefault(":'Bias Spectroscopy':'Z-controller hold'", "")
	s.spec.sweeps = SIDAMNumVarOrDefault(":'Bias Spectroscopy':'Number of sweeps'", NaN)
	s.spec.channels = SIDAMStrVarOrDefault(":'Bias Spectroscopy':Channels", "")
	s.spec.resetbias = SIDAMStrVarOrDefault(":'Bias Spectroscopy':'Reset Bias'", "")
	s.spec.finalz = SIDAMStrVarOrDefault(":'Bias Spectroscopy':'Record final Z'", "")
	s.spec.lockin = SIDAMStrVarOrDefault(":'Bias Spectroscopy':'Lock-In run'", "")
	s.spec.mode = SIDAMStrVarOrDefault(":'Bias Spectroscopy':'Sweep mode'", "")
End

Static Function LoadNanonis3dsGetHeaderCurrent(STRUCT Nanonis3ds &s)
	s.current.value = SIDAMNumVarOrDefault(":Current:'Current (A)'", NaN)
	s.current.calibration = SIDAMNumVarOrDefault(":Current:'Calibration (A/V)'", NaN)
	s.current.offset = SIDAMNumVarOrDefault(":Current:'Offset (A)'", NaN)
End

Static Function LoadNanonis3dsGetHeaderLockin(STRUCT Nanonis3ds &s)
	s.lockin.status = SIDAMStrVarOrDefault(":'Lock-in':'Lock-in status'", "")
	s.lockin.modulated = SIDAMStrVarOrDefault(":'Lock-in':'Modulated signal'", "")
	s.lockin.freq = SIDAMNumVarOrDefault(":'Lock-in':'Frequency (Hz)'", NaN)
	s.lockin.amp = SIDAMNumVarOrDefault(":'Lock-in':Amplitude", NaN)
	s.lockin.signal = SIDAMStrVarOrDefault(":'Lock-in':'Demodulated signal'", "")
	s.lockin.harmonic = SIDAMNumVarOrDefault(":'Lock-in':Harmonic", NaN)
	s.lockin.phase = SIDAMNumVarOrDefault(":'Lock-in':'Reference phase (deg)'", NaN)
End

Static Function LoadNanonis3dsGetHeaderMain(STRUCT Nanonis3ds &s)
	s.main.path = SIDAMStrVarOrDefault(":NanonisMain:'Session Path'", "")
	s.main.version = SIDAMStrVarOrDefault(":NanonisMain:'SW Version'", "")
	s.main.ui = SIDAMNumVarOrDefault(":NanonisMain:'UI Release'", NaN)
	s.main.rt = SIDAMNumVarOrDefault(":NanonisMain:'RT Release'", NaN)
	s.main.freq = SIDAMNumVarOrDefault(":NanonisMain:'RT Frequency (Hz)'", NaN)
	s.main.oversampling = SIDAMNumVarOrDefault(":NanonisMain:'Signals Oversampling'", NaN)
	s.main.animations = SIDAMNumVarOrDefault(":NanonisMain:'Animations Period (s)'", NaN)
	s.main.indicators = SIDAMNumVarOrDefault(":NanonisMain:'Indicators Period (s)'", NaN)
	s.main.measurements = SIDAMNumVarOrDefault(":NanonisMain:'Measurements Period (s)'", NaN)
End

Static Function LoadNanonis3dsGetHeaderPiezo(STRUCT Nanonis3ds &s)
	s.piezo.active = SIDAMStrVarOrDefault(":'Piezo Calibration':'Active Calib.'", "")
	s.piezo.piezo.x = SIDAMNumVarOrDefault(":'Piezo Calibration':'Calib. X (m/V)'", NaN)
	s.piezo.piezo.y = SIDAMNumVarOrDefault(":'Piezo Calibration':'Calib. Y (m/V)'", NaN)
	s.piezo.piezo.z = SIDAMNumVarOrDefault(":'Piezo Calibration':'Calib. Z (m/V)'", NaN)
	s.piezo.gain.x = SIDAMNumVarOrDefault(":'Piezo Calibration':'HV Gain X'", NaN)
	s.piezo.gain.y = SIDAMNumVarOrDefault(":'Piezo Calibration':'HV Gain Y'", NaN)
	s.piezo.gain.z = SIDAMNumVarOrDefault(":'Piezo Calibration':'HV Gain Z'", NaN)
	s.piezo.tilt.x = SIDAMNumVarOrDefault(":'Piezo Calibration':'Tilt X (deg)'", NaN)
	s.piezo.tilt.y = SIDAMNumVarOrDefault(":'Piezo Calibration':'Tilt Y (deg)'", NaN)
	s.piezo.curvature.x = SIDAMNumVarOrDefault(":'Piezo Calibration':'Curvature radius X (m)'", NaN)
	s.piezo.curvature.y = SIDAMNumVarOrDefault(":'Piezo Calibration':'Curvature radius Y (m)'", NaN)
	s.piezo.correction.x = SIDAMNumVarOrDefault(":'Piezo Calibration':'2nd order corr X (V/m^2)'", NaN)
	s.piezo.correction.y = SIDAMNumVarOrDefault(":'Piezo Calibration':'2nd order corr Y (V/m^2)'", NaN)
	s.piezo.drift.x = SIDAMNumVarOrDefault(":'Piezo Calibration':'Drift X (m/s)'", NaN)
	s.piezo.drift.y = SIDAMNumVarOrDefault(":'Piezo Calibration':'Drift Y (m/s)'", NaN)
	s.piezo.drift.z = SIDAMNumVarOrDefault(":'Piezo Calibration':'Drift Z (m/s)'", NaN)
	s.piezo.status = SIDAMStrVarOrDefault(":'Piezo Calibration':'Drift correction status (on/off'", "")
End

Static Function LoadNanonis3dsGetHeaderScan(STRUCT Nanonis3ds &s)
	String str = SIDAMStrVarOrDefault(":scan:Scanfield","")
	s.scan.center.x = strlen(str) ? str2num(StringFromList(0, str)) : NaN
	s.scan.center.y = strlen(str) ? str2num(StringFromList(1, str)) : NaN
	s.scan.size.x = strlen(str) ? str2num(StringFromList(2, str)) : NaN
	s.scan.size.y = strlen(str) ? str2num(StringFromList(3, str)) : NaN
	s.scan.angle = strlen(str) ? str2num(StringFromList(4, str)) : NaN
	s.scan.name = SIDAMStrVarOrDefault(":scan:'series name'", "")
	s.scan.channels = SIDAMStrVarOrDefault(":scan:channels", "")
	s.scan.pnts.x = SIDAMNumVarOrDefault(":scan:'pixels/line'", NaN)
	s.scan.pnts.y = SIDAMNumVarOrDefault(":scan:lines", NaN)
	s.scan.forward = SIDAMNumVarOrDefault(":scan:'speed forw. (m/s)'", NaN)
	s.scan.backward = SIDAMNumVarOrDefault(":scan:'speed backw. (m/s)'", NaN)
End

Static Function LoadNanonis3dsGetHeaderZCtrl(STRUCT Nanonis3ds &s)
	s.zctrl.z = SIDAMNumVarOrDefault(":'Z-Controller':'Z (m)'", NaN)
	s.zctrl.name = SIDAMStrVarOrDefault(":'Z-Controller':'Controller name'", "")
	s.zctrl.status = SIDAMStrVarOrDefault(":'Z-Controller':'Controller status'", "")
	s.zctrl.setpoint = SIDAMNumVarOrDefault(":'Z-Controller':Setpoint", NaN)
	s.zctrl.unit = SIDAMStrVarOrDefault(":'Z-Controller':'Setpoint unit'", "")
	s.zctrl.p = SIDAMNumVarOrDefault(":'Z-Controller':'P gain'", NaN)
	s.zctrl.i = SIDAMNumVarOrDefault(":'Z-Controller':'I gain'", NaN)
	s.zctrl.tconst = SIDAMNumVarOrDefault(":'Z-Controller':'Time const (s)'", NaN)
	s.zctrl.lift = SIDAMNumVarOrDefault(":'Z-Controller':'TipLift (m)'", NaN)
	s.zctrl.delay = SIDAMNumVarOrDefault(":'Z-Controller':'Switch off delay (s)'", NaN)
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
	Variable	temperature		//	Temperature	(extension), NaN if not used.
	Variable	field				//	Field (extension), NaN if not used.
	String	comment				//	Comment
	STRUCT	Nanonis3dsSetpoint	bias
	STRUCT	Nanonis3dsBiasSpectrscopy	spec
	STRUCT	Nanonis3dsSetpoint	current
	STRUCT	Nanonis3dsLockin		lockin
	STRUCT	Nanonis3dsMain		main
	STRUCT	Nanonis3dsPiezo		piezo
	STRUCT	Nanonis3dsScan		scan
	STRUCT	Nanonis3dsZCtrl		zctrl
	Wave	mlsw					//	Voltages in the MLS mode
	uint16	headerSize			//	Header size
	String	filename				//	for log
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


//	Data reading functions.
//	The resultant waves are saved in the current datafolder.
Static Function/WAVE LoadNanonis3dsGetData(String pathStr, int noavg, STRUCT Nanonis3ds &s)
	String fileName = ParseFilePath(3, pathStr, ":", 0, 0)	//	filename w/o an extension
	
	GBLoadWave/Q/N=tmp/T={2,4}/S=(s.headerSize)/W=1 pathStr
	wave w=tmp0
	Redimension/N=(ItemsInList(s.paramList)+ItemsInList(s.channels)*s.pnts.z, s.pnts.x, s.pnts.y) w
	
	//	Make an STM image wave from the big wave
	Wave stmw = LoadNanonis3dsGetDataParam(w, fileName, s)
	
	//	Make wave names from the channel information
	Wave/T namew = LoadNanonis3dsGetDataWaveNames(fileName, s.channels)
	
	//	Make spectrum waves from the big wave
	Wave/WAVE specw = LoadNanonis3dsGetDataSpec(w, namew, s)
	
	if (!noavg)
		//	If only forward sweep is saved, the following fails
		Wave/WAVE/Z avgw = SIDAMLoadDataNanonisCommon#averageSweeps("_bwd")
	endif
	
	//	Here I assume no mixture of forward-sweep-only channels and both sweep channels
	if (noavg || !numpnts(avgw))
		Make/N=(1+numpnts(specw))/WAVE/FREE refw
		refw[0] = {stmw}
		refw[1,] = specw[p-1]
	else
		Make/N=(1+numpnts(avgw))/WAVE/FREE refw
		refw[0] = {stmw}
		refw[1,] = avgw[p-1]
	endif
	
	KillWaves w
	return refw
End

//	Make an STM image wave from the big wave
//	The created image wave is saved in the current datafolder.
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
	
	//	scan area
	Make/N=5/FREE xw = {-1, 1, 1, -1, -1}, yw = {-1, -1, 1, 1, -1}
	Make/N=(2,5) scan
	scan[0][] = ((xw[q]*cos(s.angle/180*pi) + yw[q]*sin(s.angle/180*pi)) * s.size.x/2 + s.center.x)
	scan[1][] = ((-xw[q]*sin(s.angle/180*pi) + yw[q]*cos(s.angle/180*pi)) * s.size.y/2 + s.center.y)
	scan *= SIDAM_NANONIS_LENGTHSCALE

	//	sts points
	MatrixOP/FREE tw0 = transposeVol(w,4)
	MatrixOP/FREE stspos_x = fp32(tw0[][][xIndex]) * SIDAM_NANONIS_LENGTHSCALE
	MatrixOP/FREE stspos_y = fp32(tw0[][][yIndex]) * SIDAM_NANONIS_LENGTHSCALE
	
	Concatenate/NP=2 {stspos_x, stspos_y}, stspos
	Redimension/N=(s.pnts.x*s.pnts.y*2) stspos
	Redimension/N=(s.pnts.x*s.pnts.y, 2) stspos
	MatrixTranspose stspos
	
	SetDimLabel 0, 0, x, scan, stspos
	SetDimLabel 0, 1, y, scan, stspos
	Setscale d 0, 1, SIDAM_NANONIS_LENGTHUNIT, scan, stspos
		
	SetDataFolder dfrSav
	
	//	stm image
	if (s.pnts.y == 1)	//Linecut
		Make/N=(s.pnts.x) $(fileName+"_Z")/WAVE=topow
		topow[] = w[zIndex][p] * SIDAM_NANONIS_LENGTHSCALE
	else
		Make/N=(s.pnts.x, s.pnts.y) $(fileName+"_Z")/WAVE=topow
		MultiThread topow[][] = w[zIndex][p][q] * SIDAM_NANONIS_LENGTHSCALE
	endif
	SetScale d WaveMin(topow), WaveMax(topow), SIDAM_NANONIS_LENGTHUNIT, w
	
	//	The measured positions are inside the edge of area by half a pixel
	SetScale/P x (s.center.x-s.size.x/2+s.size.x/s.pnts.x/2) * SIDAM_NANONIS_LENGTHSCALE\
	             , s.size.x/s.pnts.x * SIDAM_NANONIS_LENGTHSCALE\
	             , SIDAM_NANONIS_LENGTHUNIT, topow
	SetScale/P y (s.center.y-s.size.y/2+s.size.y/s.pnts.y/2) * SIDAM_NANONIS_LENGTHSCALE\
	             , s.size.y/s.pnts.y * SIDAM_NANONIS_LENGTHSCALE\
	             , SIDAM_NANONIS_LENGTHUNIT, topow
	
	return topow
End

//	Make wave names from the channel information
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
		if (strlen(nameStr) > MAX_OBJ_NAME-4)		//	-4 is for "_bwd"
			if (strsearch(nameStr, "_bwd", 0) == -1)
				namew[i] = nameStr[0,MAX_OBJ_NAME-1-4]
			else
				nameStr = ReplaceString("_bwd", nameStr, "")
				namew[i] = nameStr[0,MAX_OBJ_NAME-1-4] + "_bwd"
			endif
		else
			namew[i] = nameStr
		endif
	endfor
	
	return namew
End

//	Make spectrum waves from the big wave.
//	The created image waves are saved in the current datafolder.
Static Function/WAVE LoadNanonis3dsGetDataSpec(
	Wave w,
	Wave/T namew,
	STRUCT Nanonis3ds &s
	)
	
	Variable startIndex = WhichListItem("Sweep Start", s.paramList)	//	0
	Variable endIndex = WhichListItem("Sweep End", s.paramList)		//	1
	Variable sweepStart = w[startIndex][0][0], sweepEnd = w[endIndex][0][0]
	Variable nchan = ItemsInList(s.channels), nparam =  ItemsInList(s.paramList)
	int i, v
	
	Make/N=(nchan)/FREE/WAVE refw
	
	for (i = 0; i < nchan; i++)
		
		v = nparam + i*s.pnts.z
		Duplicate/FREE/R=[v,v+s.pnts.z-1][][] w tw
		
		//	Doing fp32 before transposeVol is faster than the other way around.
		MatrixOP/FREE tw2 = fp32(tw)
		//	Make sure if the wave is 3D.
		//	In the case of linecut, the above MatrixOP returns a 2D wave.
		if (!DimSize(tw2,2))
			Redimension/N=(-1,-1,1) tw2
		endif
		// The wave name has to be clean because it may contain ":"
		MatrixOP $CleanupName(namew[i],1)/WAVE=specw = transposeVol(tw2,4)
		
		if (s.pnts.y == 1)		//	linecut
			SetScale/I x, 0, s.size.x*SIDAM_NANONIS_LENGTHSCALE\
			            , SIDAM_NANONIS_LENGTHUNIT, specw	
		else
			//	The measured positions are inside the edge of area by half a pixel
			SetScale/P x, (s.center.x-s.size.x/2+s.size.x/s.pnts.x/2)*SIDAM_NANONIS_LENGTHSCALE\
			            , s.size.x/s.pnts.x*SIDAM_NANONIS_LENGTHSCALE\
			            , SIDAM_NANONIS_LENGTHUNIT, specw
			SetScale/P y, (s.center.y-s.size.y/2+s.size.y/s.pnts.y/2)*SIDAM_NANONIS_LENGTHSCALE\
			            , s.size.y/s.pnts.y*SIDAM_NANONIS_LENGTHSCALE\
			            , SIDAM_NANONIS_LENGTHUNIT, specw
		endif
		
		if (WaveExists(s.mlsw))	//	MLS
			LoadNanonis3dsSetMLSBias(specw, s)
		else							//	linear
			strswitch (s.signal)
				case "Bias (V)":
					SetScale/I z, sweepStart*SIDAM_NANONIS_VOLTAGESCALE\
					            , sweepEnd*SIDAM_NANONIS_VOLTAGESCALE\
					            , SIDAM_NANONIS_VOLTAGEUNIT, specw
					break
				case "Z (m)":
					SetScale/I z, sweepStart*SIDAM_NANONIS_LENGTHSCALE\
					            , sweepEnd*SIDAM_NANONIS_LENGTHSCALE\
					            , SIDAM_NANONIS_LENGTHUNIT, specw
					break
				default:
					SetScale/I z, sweepStart, sweepEnd, "", specw
					break
			endswitch
			if (sweepStart > sweepEnd)
				Reverse/DIM=2 specw
			endif
		endif
		
		//	Physical values
		SIDAMLoadDataNanonisCommon#conversion(specw, driveamp=s.lockin.amp, modulated=s.lockin.modulated)
		
		refw[i] = {specw}
	endfor
	
	return refw
End

//	For MLS
//	Save the values of bias voltage to the dimension label
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
			ew *= SIDAM_NANONIS_VOLTAGESCALE
			break
		case "Z (m)":
			ew *= SIDAM_NANONIS_LENGTHSCALE
			break
		default:
			//	do nothing
	endswitch	
	
	SIDAMSetBias(specw, ew)
End
