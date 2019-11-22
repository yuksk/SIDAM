#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3	
#pragma ModuleName = SIDAMTest_Utilities_Panel

Static Function TestSIDAMNewPanel()
	//	Check only title and size because the position requires the same commands
	//	used in SIDAMNewPanel
	String title = "abc"
	String name = SIDAMNewPanel(title, 100, 50)
	DoWindow $name
	REQUIRE_EQUAL_VAR(V_flag,1)
	GetWindow $name title
	REQUIRE_EQUAL_STR(S_Value,title)
	GetWindow $name wsizeDC
	REQUIRE_EQUAL_VAR(V_right,100)
	REQUIRE_EQUAL_VAR(V_bottom,50)
	REQUIRE_EQUAL_VAR(isFixed_IGNORE(name),1)
	REQUIRE_EQUAL_VAR(isFloated_IGNORE(name),0)
	KillWindow $name

	name = SIDAMNewPanel(title, 100, 50, resizable=0)
	REQUIRE_EQUAL_VAR(isFixed_IGNORE(name),1)
	KillWindow $name

	name = SIDAMNewPanel(title, 100, 50, resizable=1)
	REQUIRE_EQUAL_VAR(isFixed_IGNORE(name),0)
	KillWindow $name

	SIDAMNewPanel(title, 100, 50, float=0)
	REQUIRE_EQUAL_VAR(isFloated_IGNORE(name),0)
	KillWindow $name

	SIDAMNewPanel(title, 100, 50, float=1)
	REQUIRE_EQUAL_VAR(isFloated_IGNORE(name),1)
	KillWindow $name
End

Static Function isFixed_IGNORE(String name)
	String infoStr = WinRecreation(name,0)
	int n0 = strsearch(infoStr,"fixedSize",0)
	return n0 == -1 ? 0 : str2num(infoStr[n0+10])
End

Static Function isFloated_IGNORE(String name)
	String infoStr = WinRecreation(name,0)
	return strsearch(infoStr,"_endfloat_",0) != -1
End

Static Function TestSIDAMWindowExists()
	Display
	String grfName0 = S_name
	String nullStr
	REQUIRE_EQUAL_VAR(SIDAMWindowExists(grfName0),1)
	REQUIRE_EQUAL_VAR(SIDAMWindowExists(""),0)
	REQUIRE_EQUAL_VAR(SIDAMWindowExists("not_existing_window"),0)
	
	Display/HOST=$grfName0
	String grfName1 = grfName0 + "#" + S_name
	
	REQUIRE_EQUAL_VAR(SIDAMWindowExists(grfName1),1)
	REQUIRE_EQUAL_VAR(SIDAMWindowExists(grfName0+"#not_existing_subwindow"),0)
	
	Display/HOST=$grfName1
	String grfName2 = S_name

	REQUIRE_EQUAL_VAR(SIDAMWindowExists(grfName1+"#"+grfName2),1)
	REQUIRE_EQUAL_VAR(SIDAMWindowExists(grfName1+"#not_existing_subwindow"),0)
	REQUIRE_EQUAL_VAR(SIDAMWindowExists(grfName0+"#not_existing_subwindow#"+grfName2),0)

	KillWindow/Z $grfName0
End

Static Function TestSIDAMKillDataFolder()
	CHECK_EQUAL_VAR(SIDAMKillDataFolder(root:notexisting),0)
	CHECK_EQUAL_VAR(SIDAMKillDataFolder(root:),1)
	
	//	Kill parents until reaching root:
	SetDataFolder root:
	NewDataFolder/S test
	NewDataFolder test2
	SetDataFolder root:
	CHECK_EQUAL_VAR(SIDAMKillDataFolder(root:test:test2),1)
	CHECK_EQUAL_VAR(DataFolderRefStatus(root:test:test2),0)
	CHECK_EQUAL_VAR(DataFolderRefStatus(root:test),0)
	
	//	Kill itself only due to the presence of a sibling
	SetDataFolder root:
	NewDataFolder/S test
	NewDataFolder test2a
	NewDataFolder test2b
	SetDataFolder root:
	CHECK_EQUAL_VAR(SIDAMKillDataFolder(root:test:test2b),2)
	CHECK_EQUAL_VAR(DataFolderRefStatus(root:test:test2b),0)
	CHECK_EQUAL_VAR(DataFolderRefStatus(root:test:test2a),1)
	
	//	Kill itself even in the presence of dependence
	SetDataFolder root:test
	NewDataFolder/S test2b
	Make wave0, wave1
	wave1 := K0
	SetDataFolder root:
	CHECK_EQUAL_VAR(SIDAMKillDataFolder(root:test:test2b),2)
	CHECK_EQUAL_VAR(DataFolderRefStatus(root:test:test2b),0)
	CHECK_EQUAL_VAR(DataFolderRefStatus(root:test:test2a),1)
	
	//	Kill itself even in the presence of a wave in use
	SetDataFolder root:test
	NewDataFolder/S test2b
	Make wave0
	Display wave0
	SetDataFolder root:
	CHECK_EQUAL_VAR(SIDAMKillDataFolder(root:test:test2b),2)
	CHECK_EQUAL_VAR(DataFolderRefStatus(root:test:test2b),0)
	CHECK_EQUAL_VAR(DataFolderRefStatus(root:test:test2a),1)
	KillWindow $S_name
	
	//	Not killed due to a color table wave
	SetDataFolder root:test:test2a
	Make/N=(2,3) wave0
	SetDataFolder root:
	Make/N=(2,2) wave1
	NewImage wave1
	ModifyImage wave1 ctab={*,*,root:test:test2a:wave0,1}
	CHECK_EQUAL_VAR(SIDAMKillDataFolder(root:test:test2a),3)
	CHECK_EQUAL_VAR(DataFolderRefStatus(root:test:test2a),1)
	KillWindow $S_name
	KillWaves root:wave1
	
	KillDataFolder root:test
End

Static Function TestkillWaveDataFolder()
	String grfName
	SetDataFolder root:
	NewDataFolder/S test

	//	Kill waves in the designated datafolder
	Make wave0,wave1
	REQUIRE_EQUAL_VAR(SIDAMUtilPanel#killWaveDataFolder(root:test),0)
	
	//	Kill waves in a child datafolder of the designated datafolder
	NewDataFolder/S test2
	Make wave0,wave1	
	SetDataFolder root:test
	REQUIRE_EQUAL_VAR(SIDAMUtilPanel#killWaveDataFolder(root:test),0)

	//	Kill waves even in use
	SetDataFolder root:test
	Make wave0,wave1,wave2,wave3
	Display wave0,wave1
	grfName = S_name
	REQUIRE_EQUAL_VAR(SIDAMUtilPanel#killWaveDataFolder(root:test),0)
	KillWindow $grfName
		
	//	Move to root: when the current datafolder is killed 
	SetDataFolder root:test
	NewDataFolder/S test2
	REQUIRE_EQUAL_VAR(SIDAMUtilPanel#killWaveDataFolder(root:test),0)
	String dfStr = GetDataFolder(1), dfExpected = "root:"
	REQUIRE_EQUAL_STR(dfStr,dfExpected)
	
	//	Color table wave is not killed
	SetDataFolder root:
	Make/N=(2,2) wave0
	SetDataFolder root:test
	NewDataFolder/S test2
	Make/N=(2,3) wave1
	Display
	AppendImage root:wave0
	ModifyImage wave0 ctab={*,*,wave1,0}
	REQUIRE_EQUAL_VAR(SIDAMUtilPanel#killWaveDataFolder(root:test),1)
	KillWindow $S_name
	KillWaves root:wave0

	KillDataFolder root:test
End

Static Function TestkillDependence()
	String str
	SetDataFolder root:
	NewDataFolder/S test
	
	Make wave0, wave1
	wave0 := K0
	wave1 := K1
	
	Variable/G v0, v1
	SetFormula v0, "wave0[0]"
	SetFormula v1, "wave1[0]"
	
	String/G s0, s1
	SetFormula s0, "a"
	SetFormula s1, "b"
	
	REQUIRE_NEQ_VAR(strlen(GetFormula(wave0)),0)
	REQUIRE_NEQ_VAR(strlen(GetFormula(wave1)),0)
	REQUIRE_NEQ_VAR(strlen(GetFormula(v0)),0)
	REQUIRE_NEQ_VAR(strlen(GetFormula(v1)),0)
	REQUIRE_NEQ_VAR(strlen(GetFormula(s0)),0)
	REQUIRE_NEQ_VAR(strlen(GetFormula(s1)),0)
	
	SIDAMUtilPanel#killDependence(root:test)
	REQUIRE_EQUAL_VAR(strlen(GetFormula(wave0)),0)
	REQUIRE_EQUAL_VAR(strlen(GetFormula(wave1)),0)
	REQUIRE_EQUAL_VAR(strlen(GetFormula(v0)),0)
	REQUIRE_EQUAL_VAR(strlen(GetFormula(v1)),0)
	REQUIRE_EQUAL_VAR(strlen(GetFormula(s0)),0)
	REQUIRE_EQUAL_VAR(strlen(GetFormula(s1)),0)
	
	SetDataFolder root:
	KillDataFolder root:test
End

Static Function TestremoveImageTrace()
	SetDataFolder root:
	NewDataFolder/S test
	DFREF dfr = GetDataFolderDFR()
	
	//	no existing wave
	SIDAMUtilPanel#removeImageTrace(dfr)
	
	Make/N=2 wave0
	Make/N=(2,3) wave1
	Make/N=(2,2,2) wave2
	
	//	a trace
	Display wave0
	SIDAMUtilPanel#removeImageTrace(dfr)
	CheckDisplayed/A wave0
	REQUIRE_EQUAL_VAR(V_flag,0)
	KillWindow $S_name

	//	two traces of the same wave	
	Display wave0
	AppendToGraph wave0
	SIDAMUtilPanel#removeImageTrace(dfr)
	CheckDisplayed/A wave0
	REQUIRE_EQUAL_VAR(V_flag,0)
	KillWindow $S_name
	
	//	a trace of an 2D wave
	Display wave1
	SIDAMUtilPanel#removeImageTrace(dfr)
	CheckDisplayed/A wave1
	REQUIRE_EQUAL_VAR(V_flag,0)
	KillWindow $S_name

	//	two traces of the same 2D wave	
	Display wave1[][0], wave1[][1]
	SIDAMUtilPanel#removeImageTrace(dfr)
	CheckDisplayed/A wave1
	REQUIRE_EQUAL_VAR(V_flag,0)
	KillWindow $S_name
	
	//	two traces of two waves
	Display wave0, wave1[][0]
	SIDAMUtilPanel#removeImageTrace(dfr)
	CheckDisplayed/A wave0
	REQUIRE_EQUAL_VAR(V_flag,0)
	CheckDisplayed/A wave1
	REQUIRE_EQUAL_VAR(V_flag,0)
	KillWindow $S_name

	//	an image
	Display
	AppendImage wave1
	SIDAMUtilPanel#removeImageTrace(dfr)
	CheckDisplayed/A wave1
	REQUIRE_EQUAL_VAR(V_flag,0)
	KillWindow $S_name
	
	//	two images of the same wave	
	Display
	AppendImage wave1
	AppendImage wave1
	SIDAMUtilPanel#removeImageTrace(dfr)
	CheckDisplayed/A wave1
	REQUIRE_EQUAL_VAR(V_flag,0)
	KillWindow $S_name
	
	//	an image of a 3D wave
	Display
	AppendImage wave2
	SIDAMUtilPanel#removeImageTrace(dfr)
	CheckDisplayed/A wave2
	REQUIRE_EQUAL_VAR(V_flag,0)
	KillWindow $S_name
	
	//	two images of 2 waves
	Display
	AppendImage wave1
	AppendImage wave2
	SIDAMUtilPanel#removeImageTrace(dfr)
	CheckDisplayed/A wave1
	REQUIRE_EQUAL_VAR(V_flag,0)
	CheckDisplayed/A wave2
	REQUIRE_EQUAL_VAR(V_flag,0)
	KillWindow $S_name
	
	//	mixture of trace an image
	Display wave0
	AppendImage wave1
	SIDAMUtilPanel#removeImageTrace(dfr)
	CheckDisplayed/A wave0
	REQUIRE_EQUAL_VAR(V_flag,0)
	CheckDisplayed/A wave1
	REQUIRE_EQUAL_VAR(V_flag,0)
	KillWindow $S_name
	
	//	a color table wave is not removed
	NewDataFolder/S test2
	Make/N=(2,2) wave3
	Display
	AppendImage wave3
	ModifyImage wave3 ctab={*,*,dfr:wave1,0}
	SIDAMUtilPanel#removeImageTrace(dfr)
	CheckDisplayed/A wave1
	REQUIRE_EQUAL_VAR(V_flag,1)
	KillWindow $S_name
	
	//	trace in a subwindow (graph in graph)
	SetDataFolder root:test
	Display
	String name = S_name
	Display/HOST=$name wave0
	SIDAMUtilPanel#removeImageTrace(dfr)
	CheckDisplayed/A wave0
	REQUIRE_EQUAL_VAR(V_flag,0)
	KillWindow $name
	
	//	trace in a subwindow (graph in panel)
	NewPanel
	name = S_name
	Display/HOST=$name wave0
	SIDAMUtilPanel#removeImageTrace(dfr)
	CheckDisplayed/A wave0
	REQUIRE_EQUAL_VAR(V_flag,0)
	KillWindow $name
		
	//	xwave of trace
	SetDataFolder root:
	Make/N=2 ywave
	Display ywave vs root:test:wave0
	SIDAMUtilPanel#removeImageTrace(dfr)
	CheckDisplayed/A wave0
	REQUIRE_EQUAL_VAR(V_flag,0)
	KillWindow $S_name
	
	//	teardown
	SetDataFolder root:
	KillDataFolder root:test
	KillWaves ywave
End