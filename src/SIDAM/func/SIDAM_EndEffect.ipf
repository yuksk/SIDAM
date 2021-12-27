#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3

#ifndef SIDAMshowProc
#pragma hide = 1
#endif

//******************************************************************************
///	Return an extended wave with an end effect similar to that of Smooth
///	@param w	input 2D/3D wave
///	@param endeffect
//		0: bounce, w[-i] = w[i], w[n+i] = w[n-i]
//		1: wrap, w[-i] = w[n-i], w[n+i] = w[i]
//		2: zero, w[-i] = w[n+i] = 0
//		3: repeat, w[-i] = w[0], w[n+i] = w[n]
//******************************************************************************
Function/WAVE SIDAMEndEffect(Wave w, int endeffect)
	if (WaveDims(w) != 2 && WaveDims(w) != 3)
		return $""
	elseif (WaveType(w) & 0x01) //	complex
		return $""
	elseif (endeffect < 0 || endeffect > 3)
		return $""
	endif

	int nx = DimSize(w,0), ny = DimSize(w,1), nz = DimSize(w,2)
	int mx = nx-1, my = ny-1
	switch (endeffect)
		case 0:	//	bounce
			Duplicate/FREE w, xw, yw, xyw
			Reverse/P/DIM=0 xw, xyw
			Reverse/P/DIM=1 yw, xyw
			Concatenate/FREE/NP=0 {xyw, yw, xyw}, ew2	//	top and bottom
			Concatenate/FREE/NP=0 {xw, w, xw}, ew1		//	middle
			Concatenate/FREE/NP=1 {ew2, ew1, ew2}, ew
			break
		case 1:	//	wrap
			Concatenate/FREE/NP=0 {w, w, w}, ew1
			Concatenate/FREE/NP=1 {ew1, ew1, ew1}, ew
			break
		case 2:	//	zero
			Duplicate/FREE w, zw
			MultiThread zw = 0
			Concatenate/FREE/NP=0 {zw, w, zw}, ew1	//	middle
			Redimension/N=(nx*3,-1,-1) zw			//	top and bottom
			Concatenate/FREE/NP=1 {zw, ew1, zw}, ew
			break
		case 3:	//	repeat
			Duplicate/FREE w, ew1, ew2, ew3
			MultiThread ew1 = w[0][0][r]			//	left, bottom
			MultiThread ew2 = w[p][0][r]			//	center, bottom
			MultiThread ew3 = w[mx][0][r]			//	right, bottom
			Concatenate/FREE/NP=0 {ew1,ew2,ew3}, bottom
			MultiThread ew1 = w[0][q][r]			//	left, middle
			MultiThread ew2 = w[mx][q][r]			//	right, middle
			Concatenate/FREE/NP=0 {ew1,w,ew2}, middle
			MultiThread ew1 = w[0][my][r]			//	left, top
			MultiThread ew2 = w[p][my][r]			//	center, top
			MultiThread ew3 = w[mx][my][r]		//	right, top
			Concatenate/FREE/NP=0 {ew1,ew2,ew3}, top
			Concatenate/FREE/NP=1 {bottom,middle,top}, ew
			break
	endswitch

	SetScale/P x DimOffset(w,0)-DimDelta(w,0)*nx, DimDelta(w,0), WaveUnits(w,0), ew
	SetScale/P y DimOffset(w,1)-DimDelta(w,1)*ny, DimDelta(w,1), WaveUnits(w,1), ew
	SetScale/P z DimOffset(w,2), DimDelta(w,2), WaveUnits(w,2), ew

	return ew
End