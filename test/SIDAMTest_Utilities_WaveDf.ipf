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

Static Function TestSIDAMSetBias()
	make/n=(2,2,3)/free w0
	make/n=(2,2,2)/free w1
	Make/N=(2,2)/FREE w2
	Make/FREE bw0 = {1,2,4}
	Make/N=2/C/FREE bw1 = cmplx(p,0)
	Make/N=2/T/FREE bw2 = {"1","2"}
	CHECK_EQUAL_VAR(SIDAMSetBias(w0,bw0),0)
	Make/N=3/FREE bw0b = str2num(GetDimLabel(w0,2,p))
	CHECK_EQUAL_WAVES(bw0,bw0b,mode=1)
	CHECK_EQUAL_VAR(SIDAMSetBias(:notexisting,bw0),1)
	CHECK_EQUAL_VAR(SIDAMSetBias(w0,:notexisting),1)
	CHECK_EQUAL_VAR(SIDAMSetBias(w2,bw0),2)	//	not 3D
	CHECK_EQUAL_VAR(SIDAMSetBias(w1,bw0),3)	//	not match in size
	CHECK_EQUAL_VAR(SIDAMSetBias(w1,bw1),4)	//	complex
	CHECK_EQUAL_VAR(SIDAMSetBias(w1,bw2),5)	//	not numeric
End

Static Function TestSIDAMGetBias()
	Make/N=(2,2,3)/FREE w0, w1
	Make/FREE bw0 = {1,2,4}, bw1 = {0.5,1.5,3,5}
	SetDimLabel 2, 0, $num2str(bw0[0]), w0
	SetDimLabel 2, 1, $num2str(bw0[1]), w0
	SetDimLabel 2, 2, $num2str(bw0[2]), w0
	CHECK_EQUAL_WAVES(SIDAMGetBias(w0,1),bw0,mode=1)
	CHECK_EQUAL_WAVES(SIDAMGetBias(w0,2),bw1,mode=1)
	CHECK_EQUAL_VAR(WaveType(SIDAMGetBias(w1,1),1),0)	//	1nd parameter is invalid
	CHECK_EQUAL_VAR(WaveType(SIDAMGetBias(w0,0),1),0)	//	2nd parameter is invalid
	CHECK_EQUAL_VAR(WaveType(SIDAMGetBias(:notexisting,1),1),0)
End

Static Function TestSIDAMCopyBias()
	Make/N=(2,2,2)/FREE w0, w1, w2
	Make/N=(3,3,1)/FREE w3
	SetDimLabel 2, 0, '1.0', w0, w3
	SetDimLabel 2, 1, '2.0', w0
	CHECK_EQUAL_VAR(SIDAMCopyBias(w0,w1),0)
	CHECK_EQUAL_VAR(EqualWaves(w0,w1,32),1)
	CHECK_EQUAL_VAR(SIDAMCopyBias(w2,w1),1)	//	not unevenly spaced bias
	CHECK_EQUAL_VAR(SIDAMCopyBias(w3,w2),1)	//	not match in size
	CHECK_EQUAL_VAR(SIDAMCopyBias(:notexisting,w0),1)
	CHECK_EQUAL_VAR(SIDAMCopyBias(w0,:notexisting),1)
End

Static Function TestSIDAMisUnevenlySpacedBias()
	Make/N=(2,2,2)/FREE w0, w1, w2
	Make/N=2/FREE w3
	SetDimLabel 2, 0, '1.0', w0, w1, w2
	SetDimLabel 2, 1, '2.0', w0
	SetDimLabel 2, 1, a, w2
	CHECK_EQUAL_VAR(SIDAMisUnevenlySpacedBias(w0),1)
	CHECK_EQUAL_VAR(SIDAMisUnevenlySpacedBias(w1),0)	//	with empty layer
	CHECK_EQUAL_VAR(SIDAMisUnevenlySpacedBias(w2),0)	//	with text
	CHECK_EQUAL_VAR(SIDAMisUnevenlySpacedBias(w3),0)	//	not 3D
	CHECK_EQUAL_VAR(SIDAMisUnevenlySpacedBias(:notexisting),-1)
End

Static Function TestSIDAMScaleToIndex()
	Make/N=(2,2,3)/FREE w0, w1
	Make/N=3/FREE w2
	SetDimLabel 2, 0, '1.0', w0
	SetDimLabel 2, 1, '2.0', w0
	SetDimLabel 2, 2, '4.0', w0
	SetScale/P z 1, 1, "", w1
	Setscale/P x 1, 1, "", w2
	CHECK_EQUAL_VAR(SIDAMScaleToIndex(w0,2.9,2),1)	//	3D with unevenly spaced bias
	CHECK_EQUAL_VAR(SIDAMScaleToIndex(w1,2.9,2),2)	//	normal 3D
	CHECK_EQUAL_VAR(SIDAMScaleToIndex(w2,2.9,0),2)	//	1D
	CHECK_EQUAL_VAR(SIDAMScaleToIndex(:notexisting,0,0),nan)
	CHECK_EQUAL_VAR(SIDAMScaleToIndex(w0,nan,0),nan)	//	invalid value
	CHECK_EQUAL_VAR(SIDAMScaleToIndex(w0,0,5),nan)	//	invalid dim
	CHECK_EQUAL_VAR(SIDAMScaleToIndex(w2,0,1),nan)	//	invalid dim
End

Static Function TestSIDAMIndexToScale()
	Make/N=(2,2,3)/FREE w0
	SetDimLabel 2, 0, '1.0', w0
	SetDimLabel 2, 1, '2.0', w0
	SetDimLabel 2, 2, '4.0', w0
	CHECK_EQUAL_VAR(SIDAMIndexToScale(w0,2,2),4)	//	3D with unevenly spaced bias
	CHECK_EQUAL_VAR(SIDAMIndexToScale(w0,1,0),1)	//	normal dimension
	CHECK_EQUAL_VAR(SIDAMIndexToScale(:notexisting,0,0),nan)
	CHECK_EQUAL_VAR(SIDAMIndexToScale(w0,nan,0),nan)	//	invalid value
	CHECK_EQUAL_VAR(SIDAMIndexToScale(w0,0,5),nan)	//	invalid dim
	CHECK_EQUAL_VAR(SIDAMIndexToScale(w0,0,3),nan)	//	invalid dim
	CHECK_EQUAL_VAR(SIDAMIndexToScale(w0,0,4),nan)	//	invalid dim
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
