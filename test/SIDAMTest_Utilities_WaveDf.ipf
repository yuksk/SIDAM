#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3
#pragma ModuleName = SIDAMTest_Utilities_WaveDf

Static Function TestSIDAMNewDF()
	String str = SIDAMNewDF("a","b")
	String expectedStr = "root:Packages:SIDAM:b:a:"
	CHECK_EQUAL_STR(str,expectedStr)
	CHECK_EQUAL_VAR(DataFolderRefStatus($expectedStr),1)
	KillDataFolder root:Packages:SIDAM:b
End

Static Function TestSIDAMWaveToString()
	Make/FREE nw = {1.10,2.00,3.14}
	Make/FREE nw2 = {{1,2},{3,4}}
	Make/T/FREE tw = {"a","b"}

	String s0, s1

	s0 = SIDAMWaveToString(nw); s1 = "{1.1,2,3.14}"
	CHECK_EQUAL_STR(s0,s1)

	s0 = SIDAMWaveToString(nw2); s1 = "{{1,2},{3,4}}"
	CHECK_EQUAL_STR(s0,s1)

	s0 = SIDAMWaveToString(tw); s1 = "{\"a\",\"b\"}"
	CHECK_EQUAL_STR(s0,s1)

	s0 = SIDAMWaveToString(tw,noquote=1); s1 = "{a,b}"
	CHECK_EQUAL_STR(s0,s1)

	s0 = SIDAMWaveToString(:nonexisting)
	CHECK_EMPTY_STR(s0)

	Redimension/N=(-1,-1,2) nw2
	s0 = SIDAMWaveToString(nw2)
	CHECK_EMPTY_STR(s0)

	Redimension/N=(-1,2) tw
	s0 = SIDAMWaveToString(tw)
	CHECK_EMPTY_STR(s0)
End

Static Function Testnum2text()
	Make/T/FREE tw = {"1.1","2","3.14"}
	Make/FREE w = {1.10,2.00,3.14}
	CHECK_EQUAL_TEXTWAVES(SIDAMUtilWaveDf#num2text(w),tw)
End

Static Function Testjoin()
	Make/T/FREE tw = {"a","b","c"}
	String s0 = "{a,b,c}", s1 = SIDAMUtilWaveDf#join(tw,1)
	CHECK_EQUAL_STR(s0,s1)
	s0 = "{\"a\",\"b\",\"c\"}", s1 = SIDAMUtilWaveDf#join(tw,0)
	CHECK_EQUAL_STR(s0,s1)
End

Static Function Testcol()
	Make/FREE w0 = {{1,2},{3,4}}
	Make/FREE w1 = {3,4}
	CHECK_EQUAL_WAVES(SIDAMUtilWaveDf#col(w0,1),w1,mode=1)
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
	REQUIRE_EQUAL_VAR(SIDAMUtilWaveDf#killWaveDataFolder(root:test),0)
	
	//	Kill waves in a child datafolder of the designated datafolder
	NewDataFolder/S test2
	Make wave0,wave1	
	SetDataFolder root:test
	REQUIRE_EQUAL_VAR(SIDAMUtilWaveDf#killWaveDataFolder(root:test),0)

	//	Kill waves even in use
	SetDataFolder root:test
	Make wave0,wave1,wave2,wave3
	Display wave0,wave1
	grfName = S_name
	REQUIRE_EQUAL_VAR(SIDAMUtilWaveDf#killWaveDataFolder(root:test),0)
	KillWindow $grfName
		
	//	Move to root: when the current datafolder is killed 
	SetDataFolder root:test
	NewDataFolder/S test2
	REQUIRE_EQUAL_VAR(SIDAMUtilWaveDf#killWaveDataFolder(root:test),0)
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
	REQUIRE_EQUAL_VAR(SIDAMUtilWaveDf#killWaveDataFolder(root:test),1)
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
	
	SIDAMUtilWaveDf#killDependence(root:test)
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
	SIDAMUtilWaveDf#removeImageTrace(dfr)
	
	Make/N=2 wave0
	Make/N=(2,3) wave1
	Make/N=(2,2,2) wave2
	
	//	a trace
	Display wave0
	SIDAMUtilWaveDf#removeImageTrace(dfr)
	CheckDisplayed/A wave0
	REQUIRE_EQUAL_VAR(V_flag,0)
	KillWindow $S_name

	//	two traces of the same wave	
	Display wave0
	AppendToGraph wave0
	SIDAMUtilWaveDf#removeImageTrace(dfr)
	CheckDisplayed/A wave0
	REQUIRE_EQUAL_VAR(V_flag,0)
	KillWindow $S_name
	
	//	a trace of an 2D wave
	Display wave1
	SIDAMUtilWaveDf#removeImageTrace(dfr)
	CheckDisplayed/A wave1
	REQUIRE_EQUAL_VAR(V_flag,0)
	KillWindow $S_name

	//	two traces of the same 2D wave	
	Display wave1[][0], wave1[][1]
	SIDAMUtilWaveDf#removeImageTrace(dfr)
	CheckDisplayed/A wave1
	REQUIRE_EQUAL_VAR(V_flag,0)
	KillWindow $S_name
	
	//	two traces of two waves
	Display wave0, wave1[][0]
	SIDAMUtilWaveDf#removeImageTrace(dfr)
	CheckDisplayed/A wave0
	REQUIRE_EQUAL_VAR(V_flag,0)
	CheckDisplayed/A wave1
	REQUIRE_EQUAL_VAR(V_flag,0)
	KillWindow $S_name

	//	an image
	Display
	AppendImage wave1
	SIDAMUtilWaveDf#removeImageTrace(dfr)
	CheckDisplayed/A wave1
	REQUIRE_EQUAL_VAR(V_flag,0)
	KillWindow $S_name
	
	//	two images of the same wave	
	Display
	AppendImage wave1
	AppendImage wave1
	SIDAMUtilWaveDf#removeImageTrace(dfr)
	CheckDisplayed/A wave1
	REQUIRE_EQUAL_VAR(V_flag,0)
	KillWindow $S_name
	
	//	an image of a 3D wave
	Display
	AppendImage wave2
	SIDAMUtilWaveDf#removeImageTrace(dfr)
	CheckDisplayed/A wave2
	REQUIRE_EQUAL_VAR(V_flag,0)
	KillWindow $S_name
	
	//	two images of 2 waves
	Display
	AppendImage wave1
	AppendImage wave2
	SIDAMUtilWaveDf#removeImageTrace(dfr)
	CheckDisplayed/A wave1
	REQUIRE_EQUAL_VAR(V_flag,0)
	CheckDisplayed/A wave2
	REQUIRE_EQUAL_VAR(V_flag,0)
	KillWindow $S_name
	
	//	mixture of trace an image
	Display wave0
	AppendImage wave1
	SIDAMUtilWaveDf#removeImageTrace(dfr)
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
	SIDAMUtilWaveDf#removeImageTrace(dfr)
	CheckDisplayed/A wave1
	REQUIRE_EQUAL_VAR(V_flag,1)
	KillWindow $S_name
	
	//	trace in a subwindow (graph in graph)
	SetDataFolder root:test
	Display
	String name = S_name
	Display/HOST=$name wave0
	SIDAMUtilWaveDf#removeImageTrace(dfr)
	CheckDisplayed/A wave0
	REQUIRE_EQUAL_VAR(V_flag,0)
	KillWindow $name
	
	//	trace in a subwindow (graph in panel)
	NewPanel
	name = S_name
	Display/HOST=$name wave0
	SIDAMUtilWaveDf#removeImageTrace(dfr)
	CheckDisplayed/A wave0
	REQUIRE_EQUAL_VAR(V_flag,0)
	KillWindow $name
		
	//	xwave of trace
	SetDataFolder root:
	Make/N=2 ywave
	Display ywave vs root:test:wave0
	SIDAMUtilWaveDf#removeImageTrace(dfr)
	CheckDisplayed/A wave0
	REQUIRE_EQUAL_VAR(V_flag,0)
	KillWindow $S_name
	
	//	teardown
	SetDataFolder root:
	KillDataFolder root:test
	KillWaves ywave
End

Static Function TestSIDAMEndEffect()
	int n = 4, m = n-1

	//	3D --------------------------------
	Make/N=(n,n,n) w = gnoise(1)
	Make/N=3/D/FREE dw0 = {10,5,2}, ow0 = {-10*n,-5*n,0}
	Make/N=3/T/FREE uw0 = {"x", "y", "z"}
	Setscale/P x, 0, dw0[0], uw0[0], w
	Setscale/P y, 0, dw0[1], uw0[1], w
	Setscale/P z, 0, dw0[2], uw0[2], w

	Make/N=4/WAVE/FREE ww = SIDAMEndEffect(w,p)
	Wave w0 = ww[0], w1 = ww[1], w2 = ww[2], w3 = ww[3]

	//	Check wave size
	Make/N=(4,3)/B/U/FREE nw0
	nw0[][0,1] = n*3
	nw0[][2] = n
	Make/N=(4,3)/B/U/FREE nw1= DimSize(ww[p],q)
	CHECK_EQUAL_WAVES(nw0,nw1,mode=1)

	//	Check wave scaling
	Make/N=3/D/FREE dw1 = DimDelta(ww[0],p), ow1 = DimOffset(ww[0],p)
	Make/N=3/T/FREE uw1 = WaveUnits(ww[0],p)
	CHECK_EQUAL_WAVES(dw0,dw1,mode=1)
	CHECK_EQUAL_WAVES(ow0,ow1,mode=1)
	CHECK_EQUAL_TEXTWAVES(uw0,uw1)

	//	Check values
	Make/N=(3,3) tw0 = w0[n*p][n*q][1], ew0
	ew0[][0] = {w[m][m][1],w[0][m][1],w[m][m][1]}
	ew0[][1] = {w[m][0][1],w[0][0][1],w[m][0][1]}
	ew0[][2] = {w[m][m][1],w[0][m][1],w[m][m][1]}
	CHECK_EQUAL_WAVES(tw0,ew0,mode=1)

	Make/N=(3,3) tw1 = w1[n*p][n*q][1], ew1 = w[0][0][1]
	CHECK_EQUAL_WAVES(tw1,ew1,mode=1)

	Make/N=(3,3) tw2 = w2[n*p][n*q][1], ew2 = 0
	ew2[1][1] = w[0][0][1]
	CHECK_EQUAL_WAVES(tw2,ew2,mode=1)

	Make/N=(3,3) tw3 = w3[n*p][n*q][1], ew3
	ew3[][0] = {w[0][0][1],w[0][0][1],w[m][0][1]}
	ew3[][1] = {w[0][0][1],w[0][0][1],w[m][0][1]}
	ew3[][2] = {w[0][m][1],w[0][m][1],w[m][m][1]}
	CHECK_EQUAL_WAVES(tw3,ew3,mode=1)

	//	2D --------------------------------
	Redimension/N=(-1,-1) w
	ww = SIDAMEndEffect(w,p)

	//	Check wave size
	Make/N=(4,3)/B/U/FREE nw0
	Redimension/N=(-1,2) nw0, nw1
	nw0 = n*3
	nw1 = DimSize(ww[p],q)
	CHECK_EQUAL_WAVES(nw0,nw1,mode=1)

	//	Check wave scaling
	Redimension/N=2 dw1, ow1, uw1, dw0, ow0, uw0
	dw1 = DimDelta(ww[0],p)
	ow1 = DimOffset(ww[0],p)
	uw1 = WaveUnits(ww[0],p)
	CHECK_EQUAL_WAVES(dw0,dw1,mode=1)
	CHECK_EQUAL_WAVES(ow0,ow1,mode=1)
	CHECK_EQUAL_TEXTWAVES(uw0,uw1)

	//	Check values
	tw0 = w0[n*p][n*q]
	ew0[][0] = {w[m][m],w[0][m],w[m][m]}
	ew0[][1] = {w[m][0],w[0][0],w[m][0]}
	ew0[][2] = {w[m][m],w[0][m],w[m][m]}
	CHECK_EQUAL_WAVES(tw0,ew0,mode=1)

	tw1 = w1[n*p][n*q]
	ew1 = w[0][0]
	CHECK_EQUAL_WAVES(tw1,ew1,mode=1)

	tw2 = w2[n*p][n*q]
	ew2 = 0
	ew2[1][1] = w[0][0]
	CHECK_EQUAL_WAVES(tw2,ew2,mode=1)

	tw3 = w3[n*p][n*q]
	ew3[][0] = {w[0][0],w[0][0],w[m][0]}
	ew3[][1] = {w[0][0],w[0][0],w[m][0]}
	ew3[][2] = {w[0][m],w[0][m],w[m][m]}
	CHECK_EQUAL_WAVES(tw3,ew3,mode=1)

	KillWaves w, tw0, ew0, tw1, ew1, tw2, ew2, tw3, ew3
End
