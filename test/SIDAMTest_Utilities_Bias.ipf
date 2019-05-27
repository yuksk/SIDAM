#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3
#pragma ModuleName = SIDAMTest_Utilities_Bias

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
