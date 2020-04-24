#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3
#pragma ModuleName = SIDAMSubtraction_FLDKM

#ifndef SIDAMshowProc
#pragma hide = 1
#endif

Static Constant THRESHOLD_CONVERGENCE = 1e-7
static Constant THRESHOLD_MAP = 0.9
Static Constant METHOD_KMEANS = 1
Static Constant METHOD_GAUSSIAN = 2

//******************************************************************************
//	SIDAMSubtraction_FLDKM
///	@param w
///		A numeric 2D wave.
///	@param responsibility_init
///		A numeric 3D wave that specifies an initial guess of responsibility.
///		The numbers of rows and columns of this wave are the same as those of
///		the input wave, and the number of layers is the number of clusters,
///		which must be 2-256.
///	@param degree [optional, default = 1]
///		The degree of subtracted plane.
///	@param hold [optional, default = 0]
///		0 or !0. Set !0 to hold the initial guess of responsibility.
///	@param roi [optional]
///		An unsigned 8-bit 2D wave that has the same number of rows and columns
///		as the image wave and specifies a region of interst. Set the pixels to
///		be included in the calculation to 1.
///	@param method [optional, default = 1]
///		1 for K-means clustering, and 2 for Gaussian mixture.
///	@param maxiterations [optional, default = 32]
///		The maximum number of iterations.
///	@return
///		A reference 1D wave. 1st and 2nd elements are references to a subtracted
///		wave and a responsibility wave, respectively.
///	@details
///		An example of 2 clusters to subtract a linear plane from wave0:
///			Make/N=(DimSize(wave0,0),DimSize(wave0,1),2) responsibility = 0
///			responsibility[0,75][210,255][0] = 1
///			responsibility[60,185][95,185][1] = 1
///			SIDAMSubtraction_FLDKM(wave0,responsibility)
//******************************************************************************
Function/WAVE SIDAMSubtraction_FLDKM(Wave w, Wave responsibility_init,
	[int degree, int hold, Wave roi, int method, int maxiterations])

	degree = ParamIsDefault(degree) ? 1 : limit(degree, 1, inf)
	hold = ParamIsDefault(hold) ? 0 : hold
	method = ParamIsDefault(method) ? METHOD_KMEANS : method
	maxiterations = \
		ParamIsDefault(maxiterations) ? 32 : limit(maxiterations, 1, inf)

	if (validate(w, responsibility_init, roi, method))
		return $""
	endif

	Duplicate/FREE responsibility_init, responsibility, responsibility_new
	assign_responsibility(responsibility, roi=roi)

	Make/D/N=(maxiterations+1)/FREE objective
	objective[0] = calc_objective(w, calc_avg(w,responsibility), responsibility)

#ifdef DEBUG_SIDAMSubtraction_FLDKM
	Wave/Z responsibility_debug
	Variable trn
	[responsibility_debug, trn] = prepare_debugging_variables(responsibility, \
		maxiterations)
#endif

	Wave vecphi = calc_vecphi(w, degree)

	int i
	for (i = 1; i <= maxiterations; i++)

		//	Plane (curve) subtraction
		//	The coefficients are calculated by using Fisher's linear discriminant
		Wave/Z w_subtracted, coef
		[w_subtracted, coef] = calc_subtracted_wave(w, responsibility, vecphi)

		//	Renew the parameters (average and variance) of each cluster
		Wave avg = calc_avg(w_subtracted, responsibility)
		if (method == METHOD_GAUSSIAN)
			Wave var = calc_variance(w_subtracted, responsibility, avg)
		endif

		//	Recalculate responsibility for the subtracted image
		if (method == METHOD_KMEANS)
			calc_responsibility(responsibility_new, w_subtracted, avg)
		elseif (method == METHOD_GAUSSIAN)
			calc_responsibility(responsibility_new, w_subtracted, avg, var=var)
		endif

		if (hold)
			assign_responsibility(responsibility_new, init=responsibility_init)
		endif

		if (WaveExists(roi))
			assign_responsibility(responsibility_new, roi=roi)
		endif

		objective[i] = calc_objective(w_subtracted, avg, responsibility_new)

#ifdef DEBUG_SIDAMSubtraction_FLDKM
		MultiThread responsibility_debug[][][][i] = responsibility_new[p][q][r]
#endif

		Variable isConverged = \
			abs(objective[i]-objective[i-1])/objective[i] < THRESHOLD_CONVERGENCE
		if (isConverged)
			break
		endif

		//	Update for next step
		responsibility = responsibility_new
	endfor

	//	Output results
	DFREF dfrSav = GetDataFolderDFR()
	SetDataFolder GetWavesDataFolderDFR(w)
	Duplicate/O w_subtracted, $(NameOfWave(w)+"_FLDKM_result")/WAVE=resw0
	Duplicate/O responsibility, $(NameOfWave(w)+"_FLDKM_responsibility")/WAVE=resw1
	Make/WAVE/N=2/FREE ww = {resw0, resw1}

	if (!isConverged)
		printf "not converged after %d iterations\r", i-1
	endif

#ifdef DEBUG_SIDAMSubtraction_FLDKM
	//	Some more outputs for debugging
	if (isConverged)
		printf "iterations: %d\r", i
		DeletePoints/M=0 i+1, maxiterations+1-(i+1), objective
		DeletePoints/M=3 i+1, maxiterations+1-(i+1), responsibility_debug
	endif
	printf "coefficients: %f, %f\r", coef[0], coef[1]
	printf "time (s): %.3f\r", stopMSTimer(trn)*1e-6

	Duplicate/O objective, $(NameOfWave(w)+"_FLDKM_debug_objective")

	make_debugging_map(w, responsibility_debug)
#endif

	SetDataFolder dfrSav
	return ww
End


//---------------------------------------------------------------------
Static Function validate(Wave w, Wave responsibility_init, Wave/Z roi,
	int method)

	String errMsg = PRESTR_CAUTION + GetRTStackInfo(2) + " gave an error: "

	//	For the image wave
	if (WaveDims(w) != 2)
		print errMsg + "image wave must be 2D."
		return 1
	elseif (isComplex(w))
		print errMsg + "image wave must be real."
		return 1
	endif

	int isFloat = WaveType(w) & 0x02
	int isDouble = WaveType(w) & 0x04
	if (!(isFloat || isDouble))
		print errMsg + "image wave must be float or double."
		return 1
	endif

	//	For the responsibility wave
	if (WaveDims(responsibility_init) != 3)
		print errMsg + "responsibility wave must be 3D."
		return 1
	elseif (isComplex(responsibility_init))
		print errMsg + "responsibility wave must be real."
		return 1
	endif

	int isNumeric = WaveType(responsibility_init,1) == 1
	if (!isNumeric)
		print errMsg + "responsibility wave must be numeric."
		return 1
	endif

	int isSameSize = DimSize(w,0)==DimSize(responsibility_init,0) \
		&& DimSize(w,1)==DimSize(responsibility_init,1)
	if (!isSameSize)
		print errMsg + "responsibility wave must have the same number "\
			+ "of rows and columns as the input wave."
		return 1
	endif

	int isValidCluster = DimSize(responsibility_init,2) <= 256 || \
		DimSize(responsibility_init,2) >= 2
	if (!isValidCluster)
		print errMsg + "number of clusters, which is given by the "\
			+ "number of layers of responsibility wave, must be 2-256."
		return 1
	endif

	//	For the roi wave
	if (WaveExists(roi) && !equalWaves(w,roi,512))
		print errMsg + "roi wave must have the same number of rows and "\
			+ "columns as the input wave."
		return 1
	endif

	int isByteInteger = WaveType(roi) & 0x08
	int isUnsigned = WaveType(roi) & 0x40
	if (WaveExists(roi) && !(isByteInteger && isUnsigned))
		print errMsg + "roi wave must be unsigned 8-bit integer."
		return 1
	endif

	//	For the method
	if (method != METHOD_KMEANS && method != METHOD_GAUSSIAN)
		print errMsg + "unknown method"
		return 1
	endif

	return 0
End

Static Function isComplex(Wave w)
	return WaveType(w) & 0x01
End


Static Function assign_responsibility(Wave responsibility,
	[Wave/Z init, Wave/Z roi])

	Make/B/N=(DimSize(responsibility,0),DimSize(responsibility,1))/FREE dummy

	if (WaveExists(init))
		MultiThread dummy = \
			assign_responsibility_helper_init(responsibility, init, p, q)
	endif

	if (WaveExists(roi))
		MultiThread dummy = \
			assign_responsibility_helper_roi(responsibility, roi, p, q)
	endif
End

ThreadSafe Static Function assign_responsibility_helper_init(
	Wave responsibility, Wave responsibility_init, int pp, int qq)

	WaveStats/P/Q/M=0/RMD=[pp][qq][] responsibility_init
	if (V_max)
		responsibility[pp][qq][] = responsibility_init[pp][qq][r]
	endif

	return 0
End

ThreadSafe Static Function assign_responsibility_helper_roi(
	Wave responsibility, Wave roi, int pp, int qq)

	if (!roi[pp][qq])
		responsibility[pp][qq][] = 0
	endif

	return 0
End


Static Function/WAVE calc_vecphi(Wave w, int degree)

	Make/D/N=(DimSize(w,0), DimSize(w,1), (degree+2)*(degree+1)/2)/FREE vecphi
	MultiThread vecphi[][][0] = w[p][q]

	int i, j, k
	for (i = 1, k = 1; i <= degree; i++)
		for (j = 0; j <= i; j++, k++)
	//		printf "%d, %d\r", i-j, j
			MultiThread vecphi[][][k] = p^(i-j) * q^j
		endfor
	endfor

	return vecphi
End


Static Function [Wave resw, Wave coef] calc_subtracted_wave(Wave w,
	Wave responsibility, Wave vecphi)

	Wave vecm = calc_vecm(vecphi, responsibility)

	//	Sum of within-class covariance matrix
	Wave SW = calc_SW(vecm, vecphi, responsibility)

	//	The coefficients are calculated by using Fisher's linear discriminant
	Wave coef = calc_coef(vecm, SW, responsibility)

	//	Plane (curve) subtraction
	Wave resw = subtract_plane(w, coef, vecphi)

	return [resw, coef]
End


Static Function/WAVE calc_vecm(Wave vecphi, Wave responsibility)

	Make/D/N=(DimSize(vecphi,2), DimSize(responsibility,2))/FREE vecm
	MultiThread vecm = calc_vecm_helper(vecphi, responsibility, p, q)

	return vecm
End

ThreadSafe Static Function calc_vecm_helper(Wave vecphi, Wave responsibility,
	int d, int cls)

	MatrixOP/FREE tw = sum(vecphi[][][d] * responsibility[][][cls]) / sum(responsibility[][][cls])

	return tw[0]
End


//	Sum of within-class covariance matrix
Static Function/WAVE calc_SW(Wave vecm, Wave vecphi, Wave responsibility)

	Make/D/N=(DimSize(vecm,0),DimSize(vecm,0),DimSize(vecm,1))/FREE cov
	Make/B/U/N=(DimSize(vecm,1))/FREE dummy
	MultiThread dummy = \
		calc_SW_helper(cov, vecm, vecphi, responsibility, p)
	MatrixOP/FREE SW = sumBeams(cov)

	return SW
End

ThreadSafe Static Function calc_SW_helper(Wave cov, Wave vecm, Wave vecphi,
	Wave responsibility, int c)

	int nx = DimSize(vecphi,0), ny = DimSize(vecphi,1), i, j, k
	Make/D/N=(DimSize(vecm,0),nx*ny)/FREE tw0

	for (j = 0, k = 0; j < ny; j++)
		for (i = 0; i < nx; i++, k++)
			tw0[][k] = (vecphi[i][j][p] - vecm[p][c]) * responsibility[i][j][c]
		endfor
	endfor

	MatrixOP/FREE tw1 = tw0 x tw0^t
	cov[][][c] = tw1[p][q]

	return 0
End


//	Calculate coefficients of subtraction by Fisher's linear discriminant
Static Function/WAVE calc_coef(Wave vecm, Wave SW, Wave responsibility)

	int ncluster = DimSize(responsibility,2), k
	Variable i, j	//	must be variable to use them in MatrixOP

	//	1st dimension is for coefficients
	//	2nd dimension is for combinations of clusters
	Make/D/N=(DimSize(vecm,0)-1,factorial(ncluster)/2)/FREE coefficients

	MatrixOP/FREE mixing_coef = sumRows(sumCols(responsibility)) / numPoints(responsibility)
	Redimension/N=(numpnts(mixing_coef)) mixing_coef

	//	calculate Fisher's linear discriminant for each pair of clusters
	for (i = 0, k = 0; i < ncluster; i++)
		for (j = i+1; j < ncluster; j++, k++)
			//	Fisher's linear disciminant
			MatrixOP/FREE tw0 = inv(SW) x (col(vecm,i)-col(vecm,j))
			//	coefficients for subtraction are obtained as weighted average
			coefficients[][k] = -tw0[p+1] / tw0[0] * \
				(mixing_coef[i] + mixing_coef[j])
		endfor
	endfor
	MatrixOP/FREE coef_answer = sumRows(coefficients) * 0.5

	return coef_answer
End


Static Function/WAVE subtract_plane(Wave w, Wave coef, Wave vecphi)

	Duplicate/FREE w, resw

	int i
	for (i = 0; i < numpnts(coef); i++)
		MultiThread resw -= coef[i] * vecphi[p][q][i+1]
	endfor

	return resw
End


Static Function/WAVE calc_avg(Wave w, Wave responsibility)

	Make/D/N=(DimSize(responsibility,2))/FREE avg
	MultiThread avg = calc_avg_helper(w, responsibility, p)

	return avg
End

ThreadSafe Static Function calc_avg_helper(Wave w, Wave responsibility, int c)

	MatrixOP/FREE tw = sum(w * responsibility[][][c]) / sum(responsibility[][][c])

	return tw[0]
End


Static Function/WAVE calc_variance(Wave w, Wave responsibility, Wave avg)

	Make/D/N=(DimSize(responsibility,2))/FREE sdev
	MultiThread sdev = calc_variance_helper(w, responsibility, avg, p)

	return sdev
End

ThreadSafe Static Function calc_variance_helper(Wave w, Wave responsibility,
	Wave avg, int c)

	MatrixOP/FREE tw = sum(magSqr(w-avg[c]) * responsibility[][][c]) / sum(responsibility[][][c])

	return tw[0]
End


Static Function calc_responsibility(Wave responsibility, Wave w, Wave avg,
	[Wave var])

	Make/B/N=(DimSize(responsibility,0),DimSize(responsibility,1))/FREE dummy

	if (ParamIsDefault(var))
		MultiThread dummy = \
			calc_responsibility_helper_kmeans(responsibility,w,avg,p,q)

	else
		//	Gaussian mixture
		MatrixOP/FREE mixing_coef = sumRows(sumCols(responsibility)) / numPoints(responsibility)
		Redimension/N=(numpnts(mixing_coef)) mixing_coef
		MultiThread dummy = \
			calc_responsibility_helper_Gaussian_mixture(\
			responsibility,w,avg,var,mixing_coef,p,q)
	endif

End

ThreadSafe Static Function calc_responsibility_helper_kmeans(
	Wave responsibility, Wave w, Wave avg, int pp, int qq)

	Make/D/N=(numpnts(avg))/FREE dis = (w[pp][qq]-avg[p])^2
	WaveStats/Q/M=0 dis
	responsibility[pp][qq][] = r==V_minloc

	return 0
End

ThreadSafe Static Function calc_responsibility_helper_Gaussian_mixture(
	Wave responsibility, Wave w, Wave avg, Wave var, Wave mixing_coef,
	int pp, int qq)

	Variable v = w[pp][qq]
	MatrixOP/FREE numerator = mixing_coef / sqrt(2*pi*var) * exp(-magSqr(avg-v)/(2*var))
	responsibility[pp][qq][] = numerator[r]/sum(numerator)

	return 0
End


Static Function calc_objective(Wave w, Wave avg,	Wave responsibility)

	Make/D/N=(numpnts(avg))/FREE tw
	MultiThread tw = calc_objective_helper(w, avg, responsibility, p)

	return sum(tw)
End

ThreadSafe Static Function calc_objective_helper(Wave w, Wave avg,
	Wave responsibility, Variable cls)

	MatrixOP/FREE tw = sum(magSqr(w-avg[cls]) * responsibility[][][cls])

	return tw[0]
End


#ifdef DEBUG_SIDAMSubtraction_FLDKM

Static Function [Wave responsibility_debug, Variable trn] prepare_debugging_variables(
	Wave responsibility, int maxiterations)

	Duplicate/FREE responsibility, responsibility_debug
	Redimension/N=(-1,-1,-1,maxiterations+1) responsibility_debug
	MultiThread responsibility_debug[][][][0] = responsibility[p][q][r]
	trn = startMSTimer

	return [responsibility_debug, trn]
End


Static Function make_debugging_map(Wave w, Wave responsibility_debug)

	int nx = DimSize(responsibility_debug,0)
	int ny = DimSize(responsibility_debug,1)
	Make/B/U/N=(nx,ny,DimSize(responsibility_debug,3))/O $(NameOfWave(w)\
		+"_FLDKM_debug_responsibility_map")/WAVE=responsibility_map
	MultiThread responsibility_map = \
		make_debugging_map_helper(responsibility_debug, p, q, r)
	Copyscales w, responsibility_map
End

ThreadSafe Static Function make_debugging_map_helper(Wave responsibility_debug,
	int pp, int qq, int rr)

	WaveStats/P/Q/M=0/RMD=[pp][qq][][rr] responsibility_debug

	return V_max >= THRESHOLD_MAP ? V_maxLayerLoc : -1
End

#endif
