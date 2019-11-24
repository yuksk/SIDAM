#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3
#pragma ModuleName = SIDAMTest_Subtraction

#ifndef SIDAMshowProc
#pragma hide = 1
#endif

Static Function Testsubtract_plane()
	int n = 256
	Make/D/FREE coefw = {0.01, 0.02, 0.035}
	Make/D/N=(n,n-2)/FREE w0 = coefw[0]*p + coefw[1]*q + coefw[2]
	Make/D/N=(n,n-2,2)/FREE w1 = (coefw[0]+r)*p + (coefw[1]+r)*q + coefw[2]+r
	Make/D/FREE roi = {{0,0},{n-1,n-3}}
	Setscale/P x -0.5, 0.1, "", w0, w1

	//	2D, order=0
	Wave resultw = SIDAMSubtraction#subtract_plane(w0,roi,0)
	WaveStats/Q/M=0 resultw
	CHECK_SMALL_VAR(V_avg,tol=1e-14)

	//	3D, order=0
	Wave resultw = SIDAMSubtraction#subtract_plane(w1,roi,0)
	ImageStats/Q/P=1 resultw
	CHECK_SMALL_VAR(V_avg,tol=1e-14)

	//	2D, order=1
	Wave resultw = SIDAMSubtraction#subtract_plane(w0,roi,1)
	CHECK_EQUAL_WAVES(resultw,w0,mode=WAVE_SCALING)
	CHECK_SMALL_VAR(WaveMax(resultw),tol=2e-12)
	CHECK_SMALL_VAR(WaveMin(resultw),tol=2e-12)

	//	3D, order=1
	Wave resultw = SIDAMSubtraction#subtract_plane(w1,roi,1)
	CHECK_EQUAL_WAVES(resultw,w1,mode=WAVE_SCALING)
	CHECK_SMALL_VAR(WaveMax(resultw),tol=1e-11)
	CHECK_SMALL_VAR(WaveMin(resultw),tol=1e-11)

	Make/D/N=(n,n-2)/FREE w2 = 0
	Make/D/N=(n,n-2,2)/FREE w3 = 0
	int p0 = round(n*0.2), p1 = round(n*0.4), q0 = p0, q1 = p1*2
	w2[p0,p1][q0,q1] = coefw[0]*p + coefw[1]*q + coefw[2]
	w3[p0,p1][q0,q1][] = (coefw[0]+r)*p + (coefw[1]+r)*q + coefw[2]+r
	roi = {{p0,q0},{p1,q1}}

	//	2D, roi, order=0
	Wave resultw = SIDAMSubtraction#subtract_plane(w2,roi,0)
	ImageStats/Q/M=0/G={p0,p1,q0,q1} resultw
	CHECK_SMALL_VAR(V_avg,tol=1e-13)

	//	3D, roi, order=0
	Wave resultw = SIDAMSubtraction#subtract_plane(w3,roi,0)
	ImageStats/Q/M=0/P=1/G={p0,p1,q0,q1} resultw
	CHECK_SMALL_VAR(V_avg,tol=1e-13)

	//	2D, roi, order=1
	Wave resultw = SIDAMSubtraction#subtract_plane(w2,roi,1)
	ImageStats/Q/M=0/G={p0,p1,q0,q1} resultw
	CHECK_SMALL_VAR(V_max,tol=1e-13)
	CHECK_SMALL_VAR(V_min,tol=1e-13)

	//	3D, roi, order=1
	Wave resultw = SIDAMSubtraction#subtract_plane(w3,roi,1)
	ImageStats/Q/M=0/G={p0,p1,q0,q1} resultw
	CHECK_SMALL_VAR(V_max,tol=1e-13)
	CHECK_SMALL_VAR(V_min,tol=1e-13)
End

Static Function Testplane_coef()
	int n = 256
	Make/D/FREE coefw = {0.01, 0.02, 0.035}
	Make/D/N=(n,n-2)/FREE w0 = coefw[0]*p + coefw[1]*q + coefw[2]

	Wave resultw = SIDAMSubtraction#plane_coef(w0)
	CHECK_EQUAL_WAVES(coefw,resultw,mode=WAVE_DATA,tol=1e-14)
End

Static Function Testsubtract_poly()
	int n = 256
	Make/D/FREE cw = {1e-4, 2e-4, 1.5e-4, 0.01, 0.02, 0.035}
	Make/D/N=(n,n-2)/FREE w0 = cw[0]*p*p + cw[1]*q*q + cw[2]*p*q + cw[3]*p + cw[4]*q + cw[5]
	Setscale/P x -0.5, 0.1, "", w0

	Wave resultw = SIDAMSubtraction#subtract_poly(w0,{{0,0},{DimSize(w0,0)-1,DimSize(w0,1)-1}},2)
	CHECK_EQUAL_WAVES(resultw,w0,mode=WAVE_SCALING)
	CHECK_SMALL_VAR(WaveMax(resultw),tol=2e-12)
	CHECK_SMALL_VAR(WaveMin(resultw),tol=2e-12)
End

Static Function Testsubtract_line_constant()
	int nx = 15, ny = 25, nz = 3
	Make/D/N=(ny)/FREE coef = gnoise(1)
	Make/D/N=(nx,ny)/FREE w0 = coef[q]+p, w1 = coef[p]+q
	Make/D/N=(nx,ny,nz)/FREE w2 = coef[q]+p+0.1*(r+1)
	Setscale/I x -0.5, 0.5, "", w0, w1

	int i, j, k

	//	x direction
	Wave rw0 = SIDAMSubtraction#subtract_line_constant(w0,0)
	Make/D/N=(ny)/FREE aw0
	for (j = 0; j < ny; j++)
		ImageStats/Q/M=0/G={0,nx-1,j,j} rw0
		aw0[j] = abs(V_avg)
	endfor
	CHECK_SMALL_VAR(WaveMax(aw0),tol=1e-14)
	CHECK_EQUAL_WAVES(w0,rw0,mode=WAVE_SCALING)

	//	y direction
	Wave rw1 = SIDAMSubtraction#subtract_line_constant(w1,1)
	Make/D/N=(nx)/FREE aw1
	for (i = 0; i < nx; i++)
		ImageStats/Q/M=0/G={i,i,0,ny-1} rw1
		aw1[i] = abs(V_avg)
	endfor
	CHECK_SMALL_VAR(WaveMax(aw1),tol=1e-14)

	//	32bit float
	Duplicate/FREE w0 w0s
	Redimension/S w0s
	Wave rw0s = SIDAMSubtraction#subtract_line_constant(w0s,0)
	CHECK_EQUAL_WAVES(w0s,rw0s,mode=WAVE_DATA_TYPE)

	//	3D
	Wave rw2 = SIDAMSubtraction#subtract_line_constant(w2,0)
	Make/D/N=(ny,nz)/FREE aw2
	for (k = 0; k < nz; k++)
		for (j = 0; j < ny; j++)
			ImageStats/Q/M=0/P=(k)/G={0,nx-1,j,j} rw2
			aw2[j][k] = abs(V_avg)
		endfor
	endfor
	CHECK_SMALL_VAR(WaveMax(aw2),tol=1e-14)
End

Static Function Testsubtract_line_poly()
	int nx = 16, ny = 24
	Make/D/N=(nx,ny)/O w1 = -2.3*p+0.2*q, w2 = -1.2*p^2+0.2*p+2.1*q^2-1.2*q
	Duplicate/O w1, w1s
	Redimension/S w1s
	Setscale/P x -0.5, 0.1, "", w1, w2, w1s

	Wave rw0 = SIDAMSubtraction#subtract_line_poly(w1,1,0)
	CHECK_EQUAL_WAVES(w1,rw0,mode=WAVE_SCALING)
	CHECK_SMALL_VAR(WaveMax(rw0),tol=1e-13)
	CHECK_SMALL_VAR(WaveMin(rw0),tol=1e-13)

	Wave rw1 = SIDAMSubtraction#subtract_line_poly(w1,1,1)
	CHECK_SMALL_VAR(WaveMax(rw1),tol=1e-13)
	CHECK_SMALL_VAR(WaveMin(rw1),tol=1e-13)

	Wave rw2 = SIDAMSubtraction#subtract_line_poly(w2,2,0)
	CHECK_SMALL_VAR(WaveMax(rw2),tol=1e-12)
	CHECK_SMALL_VAR(WaveMin(rw2),tol=1e-12)

	Wave rw3 = SIDAMSubtraction#subtract_line_poly(w2,2,1)
	CHECK_SMALL_VAR(WaveMax(rw3),tol=1e-12)
	CHECK_SMALL_VAR(WaveMin(rw3),tol=1e-12)

	Wave rw4 = SIDAMSubtraction#subtract_line_poly(w1s,1,0)
	CHECK_SMALL_VAR(WaveMax(rw4),tol=2e-6)
	CHECK_SMALL_VAR(WaveMin(rw4),tol=2e-6)
End

Static Function Testsubtract_line_median_constant()
	int nx = 16, ny = 24
	Make/D/N=(nx,ny)/O w0=1.2, w1=0.5
	w0[nx-1][] = 2.8
	w1[][ny-1] = 1.2
	Duplicate/O w1, w1s
	Redimension/S w1s
	Setscale/P x -0.5, 0.1, "", w0, w1, w1s

	Wave rw0 = SIDAMSubtraction#subtract_line_median_constant(w0,0)
	CHECK_EQUAL_WAVES(w0,rw0,mode=WAVE_SCALING)
	ImageStats/Q/M=0/G={0,nx-2,0,ny-1} rw0
	CHECK_EQUAL_VAR(V_max,0)
	CHECK_EQUAL_VAR(V_min,0)
	ImageStats/Q/M=0 rw0
	CHECK_NEQ_VAR(V_max,0)
	CHECK_EQUAL_VAR(V_min,0)

	Wave rw1 = SIDAMSubtraction#subtract_line_median_constant(w1,1)
	ImageStats/Q/M=0/G={0,nx-1,0,ny-2} rw1
	CHECK_EQUAL_VAR(V_max,0)
	CHECK_EQUAL_VAR(V_min,0)
	ImageStats/Q/M=0 rw1
	CHECK_NEQ_VAR(V_max,0)
	CHECK_EQUAL_VAR(V_min,0)

	Wave rw1s = SIDAMSubtraction#subtract_line_median_constant(w1s,1)
	CHECK_EQUAL_WAVES(rw1s,w1s,mode=WAVE_DATA_TYPE)
End

Static Function Testsubtract_line_median_slope()
	int nx = 16, ny = 24
	Make/D/N=(nx,ny)/O w0=1.2*(p+1), w1=0.05*(q+1)
	w0[nx-1][] = 2.89
	w1[][ny-1] = 3.92
	Duplicate/O w1, w1s
	Redimension/S w1s
	Setscale/P x -0.5, 0.1, "", w0, w1, w1s

	Wave rw0 = SIDAMSubtraction#subtract_line_median_slope(w0,0)
	CHECK_EQUAL_WAVES(w0,rw0,mode=WAVE_SCALING)
	ImageStats/Q/M=0/G={0,nx-2,0,ny-1} rw0
	CHECK_SMALL_VAR(V_max,tol=1e-14)
	CHECK_SMALL_VAR(V_min,tol=1e-14)
	ImageStats/Q/M=0 rw0
	CHECK_NEQ_VAR(V_max,0)

	Wave rw1 = SIDAMSubtraction#subtract_line_median_slope(w1,1)
	ImageStats/Q/M=0/G={0,nx-1,0,ny-2} rw1
	CHECK_SMALL_VAR(V_max,tol=1e-14)
	CHECK_SMALL_VAR(V_min,tol=1e-14)
	ImageStats/Q/M=0 rw1
	CHECK_NEQ_VAR(V_max,0)

	Wave rw1s = SIDAMSubtraction#subtract_line_median_slope(w1s,1)
	CHECK_EQUAL_WAVES(rw1s,w1s,mode=WAVE_DATA_TYPE)
End

Static Function Testsubtract_line_median_curvature()
	int nx = 16, ny = 24
	Make/D/N=(nx,ny)/O w0=0.2*(p+1)^2+1.2*(p+1), w1=1e-2*(q+1)^2+0.05*(q+1)
	w0[nx-1][] = 200.89
	w1[][ny-1] = 300.92
	Duplicate/O w1, w1s
	Redimension/S w1s
	Setscale/P x -0.5, 0.1, "", w0, w1, w1s

	Wave rw0 = SIDAMSubtraction#subtract_line_median_curvature(w0,0)
	CHECK_EQUAL_WAVES(w0,rw0,mode=WAVE_SCALING)
	ImageStats/Q/M=0/G={0,nx-2,0,ny-1} rw0
	CHECK_SMALL_VAR(V_max,tol=1e-14)
	CHECK_SMALL_VAR(V_min,tol=1e-14)
	ImageStats/Q/M=0 rw0
	CHECK_NEQ_VAR(V_max,0)

	Wave rw1 = SIDAMSubtraction#subtract_line_median_curvature(w1,1)
	ImageStats/Q/M=0/G={0,nx-1,0,ny-2} rw1
	CHECK_SMALL_VAR(V_max,tol=1e-14)
	CHECK_SMALL_VAR(V_min,tol=1e-14)
	ImageStats/Q/M=0 rw1
	CHECK_NEQ_VAR(V_max,0)

	Wave rw1s = SIDAMSubtraction#subtract_line_median_curvature(w1s,1)
	CHECK_EQUAL_WAVES(rw1s,w1s,mode=WAVE_DATA_TYPE)
End

Static Function Testsubtract_layer()
	Make/D/N=(2,2,3)/FREE w0 = gnoise(1)
	Make/D/C/N=(2,2,3)/FREE w1 = cmplx(gnoise(1),enoise(1))
	Setscale/P x -0.5, 0.1, "", w0, w1

	Wave rw = SIDAMSubtraction#subtract_layer(w0,2)
	Duplicate/R=[][][1]/FREE w0, w0_1
	Duplicate/R=[][][2]/FREE w0, w0_2
	Duplicate/R=[][][1]/FREE rw, rw_1
	w0_1 -= w0_2
	CHECK_EQUAL_WAVES(rw_1,w0_1,mode=WAVE_DATA)
	CHECK_EQUAL_WAVES(rw,w0,mode=WAVE_SCALING)

	Wave/C cw = SIDAMSubtraction#subtract_layer(w1,2)
	MatrixOP/FREE trw = real(cw[][][1]-(w1[][][1]-w1[][][2]))
	MatrixOP/FREE tiw = imag(cw[][][1]-(w1[][][1]-w1[][][2]))
	CHECK_EQUAL_WAVES(cw,w1,mode=WAVE_SCALING)
	CHECK_EQUAL_VAR(WaveMax(trw),0)
	CHECK_EQUAL_VAR(WaveMin(trw),0)
	CHECK_EQUAL_VAR(WaveMax(tiw),0)
	CHECK_EQUAL_VAR(WaveMin(tiw),0)
End

Static Function Testsubtract_phase()
	Make/D/C/N=(2,2,3)/FREE w0 = cmplx(gnoise(1),enoise(1))
	Wave/C w1 = SIDAMSubtraction#subtract_phase(w0,2)
	Setscale/P x -0.5, 0.1, "", w0, w1

	MatrixOP/FREE pw = cos(phase(w1[][][1])-(phase(w0[][][1])-phase(w0[][][2])))
	CHECK_CLOSE_VAR(WaveMin(pw),1,tol=1e-14)

	MatrixOP/FREE a0 = abs(w0[][][1])
	MatrixOP/FREE a1 = abs(w1[][][1])
	CHECK_EQUAL_WAVES(a0,a1,mode=WAVE_DATA|WAVE_SCALING,tol=1e-14)
End

