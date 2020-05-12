#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3
#pragma ModuleName = SIDAMSubtraction_MLE

#ifndef SIDAMshowProc
#pragma hide = 1
#endif

Static Constant DEFAULT_DEGREE = 1
Static Constant DEFAULT_MAXITERATIONS = 64
Static Constant DEFAULT_TOLERANCE = 1e-7

Static Constant DISTRIB_GAUSS_ZERO_VARIANCE = 1
Static Constant DISTRIB_GAUSS = 2
Static Constant DISTRIB_GAUSS_COMMON_VARIANCE = 3
Static Constant DISTRIB_CAUCHY = 4
Static Constant DISTRIB_CAUCHY_COMMON_SCALE = 5

Static Constant DEFAULT_DEBUG_THRESHOLD_MAP = 0.99

//******************************************************************************
//	SIDAMSubtraction_MLE
///	@param w
///		A numeric 2D wave.
///	@param responsibility
///		A numeric 3D wave that specifies an initial guess of responsibility.
///		This wave will be overwritten by calculated responsibility.
///		The numbers of rows and columns of this wave are the same as those of
///		the input wave, and the number of layers is the number of clusters,
///		which must be 2-256.
///	@param degree [optional, default = 1]
///		The degree of subtracted plane.
///	@param roi [optional]
///		An unsigned 8-bit 2D wave that has the same number of rows and columns
///		as the image wave and specifies a region of interst. Set the pixels to
///		be included in the calculation to 1.
///	@param distrib [optional, default = 1]
///		1: Gauss distributions with zero variance
///			(Least-squares fit & K-means clustering)
///		2: Gauss distributions
///		3: Gauss distributions with a common variance
///		4: Cauchy distributions
///		5: Cauchy distributions with a common scale parameter
///	@param maxiterations [optional, default = 64]
///		The maximum number of iterations.
///	@param tol [optional, default = 1e-7]
///		A fractional tolerance to stop iteration.
///	@return
///		A subtracted wave. This is a free wave.
///	@details
///		An example of 2 clusters to subtract a linear plane from wave0:
///			Make/N=(DimSize(wave0,0),DimSize(wave0,1),2) responsibility = 0
///			responsibility[0,75][210,255][0] = 1
///			responsibility[60,185][95,185][1] = 1
///			SIDAMSubtraction_MLE(wave0,responsibility)
//******************************************************************************
Function/WAVE SIDAMSubtraction_MLE(Wave w, Wave responsibility,
	[int degree, Wave roi, int distrib, int maxiterations, Variable tol])

	degree = ParamIsDefault(degree) ? DEFAULT_DEGREE : limit(degree, 1, inf)
	distrib = ParamIsDefault(distrib) ? DISTRIB_GAUSS_ZERO_VARIANCE : distrib
	maxiterations = ParamIsDefault(maxiterations) ? DEFAULT_MAXITERATIONS : \
		limit(maxiterations, 1, inf)
	tol = ParamIsDefault(tol) ? DEFAULT_TOLERANCE : tol

	if (validate(w, responsibility, roi, distrib))
		return $""
	endif

	assign_roi(responsibility, roi)

	//	initial step
	Wave vecphi = calc_vecphi(w, degree)
	Wave center = calc_center(w, responsibility)
	Wave w_subtracted = subtract_plane(w, responsibility, vecphi, center,\
		initial_guess=1)
	Variable objective = calc_objective(w_subtracted, center, responsibility)
	if (distrib == DISTRIB_CAUCHY || \
		distrib == DISTRIB_CAUCHY_COMMON_SCALE)
		Duplicate/FREE responsibility responsibility_tilde
	endif

#ifdef DEBUG_SIDAMSubtraction_MLE
	STRUCT debug_structure s
	debug_initialize_variables(s, responsibility, objective, maxiterations)
#endif

	int i
	for (i = 1; i <= maxiterations; i++)

		//	E-step
		switch (distrib)
			case DISTRIB_GAUSS_ZERO_VARIANCE:
				Wave center = calc_center(w_subtracted, responsibility)
				break
			case DISTRIB_GAUSS:
			case DISTRIB_GAUSS_COMMON_VARIANCE:
				Wave center = calc_center(w_subtracted, responsibility)
				Wave var = calc_variance(w_subtracted, responsibility, center, \
					distrib)
				Wave mixing_coef = calc_mixing_coef(responsibility)
				break
			case DISTRIB_CAUCHY:
			case DISTRIB_CAUCHY_COMMON_SCALE:
				Wave center = calc_center(w_subtracted, responsibility_tilde)
				Wave scale = calc_scale(w, responsibility, \
					responsibility_tilde, distrib)
				Wave mixing_coef = calc_mixing_coef(responsibility)
				break
		endswitch

		//	M-step
		switch (distrib)
			case DISTRIB_GAUSS_ZERO_VARIANCE:
				renew_responsibility(responsibility, w_subtracted, center, roi)
				break
			case DISTRIB_GAUSS:
			case DISTRIB_GAUSS_COMMON_VARIANCE:
				renew_responsibility(responsibility, w_subtracted, center, roi, \
					var=var, mixing_coef=mixing_coef)
				break
			case DISTRIB_CAUCHY:
			case DISTRIB_CAUCHY_COMMON_SCALE:
				renew_responsibility(responsibility, w_subtracted, center, roi, \
					scale=scale, tilde=responsibility_tilde, \
					mixing_coef=mixing_coef)
				break
		endswitch

		Variable objective_new = calc_objective(w_subtracted, center, \
			responsibility)

#ifdef DEBUG_SIDAMSubtraction_MLE
		debug_store_variables(s, responsibility, objective_new, i)
#endif

		Variable isConverged = abs(objective_new-objective)/objective_new < tol
		if (isConverged)
			break
		endif

		objective = objective_new
		switch (distrib)
			case DISTRIB_GAUSS_ZERO_VARIANCE:
			case DISTRIB_GAUSS:
			case DISTRIB_GAUSS_COMMON_VARIANCE:
				Wave w_subtracted = subtract_plane(w, responsibility, vecphi, center)
				break
			case DISTRIB_CAUCHY:
			case DISTRIB_CAUCHY_COMMON_SCALE:
				Duplicate/FREE responsibility_tilde, tw
				MultiThread tw = scale[r] ? tw/scale[r] : 0
				Wave w_subtracted = subtract_plane(w, tw, vecphi, center)
				break
		endswitch
	endfor

	if (!isConverged)
		printf "not converged after %d iterations\r", i-1
	endif

#ifdef DEBUG_SIDAMSubtraction_MLE
	Wave/Z s.center = center, s.var = var, s.scale = scale
	debug_save_outputs(s, w, isConverged, i)
#endif

	return w_subtracted
End


//------------------------------------------------------------------------------


Static Function validate(Wave w, Wave responsibility, Wave/Z roi,
	int distrib)

	String errMsg = PRESTR_CAUTION + GetRTStackInfo(2) + \
		" gave an error: "

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
	if (WaveDims(responsibility) != 3)
		print errMsg + "responsibility wave must be 3D."
		return 1
	elseif (isComplex(responsibility))
		print errMsg + "responsibility wave must be real."
		return 1
	endif

	int isNumeric = WaveType(responsibility,1) == 1
	if (!isNumeric)
		print errMsg + "responsibility wave must be numeric."
		return 1
	endif

	int isSameSize = DimSize(w,0)==DimSize(responsibility,0) \
		&& DimSize(w,1)==DimSize(responsibility,1)
	if (!isSameSize)
		print errMsg + "responsibility wave must have the same number of rows "\
			+ "and columns as the input wave."
		return 1
	endif

	int isValidCluster = DimSize(responsibility,2) <= 256 || \
		DimSize(responsibility,2) >= 2
	if (!isValidCluster)
		print errMsg + "number of clusters, which is given by the number of "\
			+ "layers of responsibility wave, must be 2-256."
		return 1
	endif

	//	For the roi wave
	if (WaveExists(roi) && !equalWaves(w,roi,512))
		print errMsg + "roi wave must have the same number of rows "\
			+ "and columns as the input wave."
		return 1
	endif

	int isByteInteger = WaveType(roi) & 0x08
	int isUnsigned = WaveType(roi) & 0x40
	if (WaveExists(roi) && !(isByteInteger && isUnsigned))
		print errMsg + "roi wave must be unsigned 8-bit integer."
		return 1
	endif

	//	For the distrib
	switch (distrib)
		case DISTRIB_GAUSS_ZERO_VARIANCE:
		case DISTRIB_GAUSS:
		case DISTRIB_GAUSS_COMMON_VARIANCE:
		case DISTRIB_CAUCHY:
		case DISTRIB_CAUCHY_COMMON_SCALE:
			break
		default:
			print errMsg + "unknown distribution"
			return 1
	endswitch

	return 0
End

Static Function isComplex(Wave w)
	return WaveType(w) & 0x01
End


Static Function assign_roi(Wave responsibility, Wave/Z roi)

	if (!WaveExists(roi))
		return 0
	endif

	Make/B/N=(DimSize(responsibility,0), DimSize(responsibility,1))/FREE dummy
	MultiThread dummy = assign_roi_helper(responsibility, roi, p, q)

End

ThreadSafe Static Function assign_roi_helper(Wave responsibility, Wave roi,
	int pp, int qq)

	if (!roi[pp][qq])
		responsibility[pp][qq][] = 0
	endif

	return 0
End


Static Function/WAVE calc_vecphi(Wave w, int degree)

	Make/D/N=(DimSize(w,0), DimSize(w,1), \
		(degree+2)*(degree+1)/2)/FREE vecphi
	vecphi[][][0] = 1

	int i, j, k
	for (i = 1, k = 1; i <= degree; i++)
		for (j = 0; j <= i; j++, k++)
	//		printf "%d, %d\r", i-j, j
			MultiThread vecphi[][][k] = p^(i-j) * q^j
		endfor
	endfor

	return vecphi
End


Static Function/WAVE calc_center(Wave w, Wave responsibility)

	Make/D/N=(DimSize(responsibility,2))/FREE center
	MultiThread center = calc_center_helper(w, responsibility, p)

	return center
End

ThreadSafe Static Function calc_center_helper(Wave w, Wave responsibility, int k)

	MatrixOP/FREE tw0 = sum(responsibility[][][k])
	if (tw0[0] == 0)
		return 0
	endif

	//	sum with respect to n
	MatrixOP/FREE tw1 = sum(w * responsibility[][][k])

	return tw1[0] / tw0[0]
End


Static Function/WAVE calc_variance(Wave w, Wave responsibility, Wave center,
	int distrib)

	Make/D/N=(DimSize(responsibility,2))/FREE var

	if (distrib == DISTRIB_GAUSS_COMMON_VARIANCE)
		MultiThread var = calc_variance_helper_common_variance(\
			w, responsibility, center, p)
		//	sum with respect to k (var)
		//	sum with respect to both k and n (responsibility)
		Variable a = sum(var) / sum(responsibility)
		var = a

	elseif (distrib == DISTRIB_GAUSS)
		MultiThread var = calc_variance_helper(w, responsibility, center, p)

	endif

	return var
End

ThreadSafe Static Function calc_variance_helper_common_variance(Wave w,
	Wave responsibility, Wave center, int k)

	//	sum with respect to n
	MatrixOP/FREE tw = sum(responsibility[][][k] * magSqr(w-center[k]))

	return tw[0]
End

ThreadSafe Static Function calc_variance_helper(Wave w, Wave responsibility,
	Wave center, int k)

	MatrixOP/FREE tw0 = sum(responsibility[][][k])
	if (tw0[0] == 0)
		return 0
	endif

	//	sum with respect to n
	MatrixOP/FREE tw1 = sum(magSqr(w-center[k]) * responsibility[][][k])

	return tw1[0] / tw0[0]
End


Static Function/WAVE calc_scale(Wave w, Wave responsibility,
	Wave responsibility_tilde, int distrib)

	//	sum with respect to n
	//	Note the sum of MatrixOP applies on a layer by layer basis
	MatrixOP/FREE numerator = sum(responsibility)
	MatrixOP/FREE denominator = sum(responsibility_tilde) * 2 * pi

	if (distrib == DISTRIB_CAUCHY)
		MatrixOP/FREE scale = numerator / denominator
		Redimension/N=(numpnts(scale)) scale
		scale = numtype(denominator[p]) ? 0 : scale[p]
		return scale

	elseif (distrib == DISTRIB_CAUCHY_COMMON_SCALE)
		//	sum with respect to k
		Variable n = sum(numerator), d = sum(denominator)
		Make/D/N=(DimSize(responsibility,2))/FREE scale2 = n/d
		return scale2

	endif

End


Static Function/WAVE calc_mixing_coef(Wave responsibility)

	//	sum with respect to n
	//	Note the sum of MatrixOP applies on a layer by layer basis
	MatrixOP/FREE N_k = sum(responsibility)
	//	sum with respect to both n and k (denominator)
	Make/D/N=(numpnts(N_k))/FREE pi_k = N_k[0][0][p] / sum(responsibility)

	return pi_k
End


Static Function/WAVE subtract_plane(Wave w, Wave responsibility,
	Wave vecphi, Wave center, [int initial_guess])

	if (ParamIsDefault(initial_guess))
		Wave coef = calc_coef(w, responsibility, vecphi, center)
	else
		Wave coef = calc_coef_initial_guess(w, responsibility, vecphi, center)
	endif

	Duplicate/FREE w, rtnw
	int i
	for (i = 0; i < numpnts(coef); i++)
		MultiThread rtnw -= coef[i] * vecphi[p][q][i]
	endfor

	return rtnw
End

//	Calculate coefficients of subtraction
Static Function/WAVE calc_coef(Wave w, Wave responsibility,
	Wave vecphi, Wave center)

	DFREF dfrSav = GetDataFolderDFR()
	SetDataFolder NewFreeDataFolder()

	int d = DimSize(vecphi,2)
	Make/D/N=(d,d) A
	Make/D/N=(d) b
	MultiThread A = calc_coef_matA(responsibility, vecphi, p, q)
	MultiThread b = calc_coef_vecb(w, responsibility, vecphi, center, p)

	MatrixLLS A b
	Wave coef = M_B
	Redimension/N=(d) coef

	SetDataFolder dfrSav

	return coef
End

//	Return a weighted average of coefficients as an initial guess
Static Function/WAVE calc_coef_initial_guess(Wave w, Wave responsibility,
	Wave vecphi, Wave center)

	Make/D/N=(DimSize(vecphi,2),DimSize(responsibility,2))/FREE coefs

	int i
	for (i = 0; i < DimSize(responsibility,2); i++)
		Duplicate/FREE/R=[][][i] responsibility, tw0
		Duplicate/FREE/R=[i] center, tw1
		Wave coef = calc_coef(w, tw0, vecphi, tw1)
		coefs[][i] = coef[p]*sum(tw0)/sum(responsibility)
	endfor
	MatrixOP/FREE coef = sumRows(coefs)

	return coef
End

ThreadSafe Static Function calc_coef_matA(Wave responsibility,
	Wave vecphi, int pp, int qq)

	//	sum with respect to n
	MatrixOP/FREE tw = sum(sumBeams(responsibility) * vecphi[][][pp] * vecphi[][][qq])

	return tw[0]
End

ThreadSafe Static Function calc_coef_vecb(Wave w, Wave responsibility,
	Wave vecphi, Wave center, int pp)

	Make/D/N=(DimSize(responsibility,2))/FREE tw
	tw = calc_coef_vecb_helper(w, responsibility, vecphi, \
		center, pp, p)

	return sum(tw) //	sum with respect to k
End

ThreadSafe Static Function calc_coef_vecb_helper(Wave w, Wave responsibility,
	Wave vecphi, Wave center, int pp, int k)

	//	sum with respect to n
	MatrixOP/FREE tw = sum(responsibility[][][k] * (w-center[k]) * vecphi[][][pp])

	return tw[0]
End


Static Function renew_responsibility(Wave responsibility, Wave w, Wave center,
	WAVE/Z roi, [Wave var, Wave scale, Wave tilde, Wave mixing_coef])

	Make/B/N=(DimSize(responsibility,0),DimSize(responsibility,1))/FREE dummy

	if (!ParamIsDefault(var))
		MultiThread dummy = renew_responsibility_helper_gaussian_mixture(\
			responsibility, w, center, var, mixing_coef, p, q)

	elseif (!ParamIsDefault(scale))
		MultiThread dummy = renew_responsibility_helper_cauchy_mixture(\
			responsibility, w, center, scale, mixing_coef, p, q)
		MultiThread tilde = responsibility * scale[r] / \
			(magSqr(cmplx(w[p][q]-center[r],scale[r])) * pi)

	else
		MultiThread dummy = renew_responsibility_helper_kmeans(\
			responsibility, w, center, p, q)
	endif

	assign_roi(responsibility, roi)
End

ThreadSafe Static Function renew_responsibility_helper_gaussian_mixture(
	Wave responsibility, Wave w, Wave center, Wave var, Wave mixing_coef,
	int pp, int qq)

	Variable h = w[pp][qq]
	MatrixOP/FREE numerator = mixing_coef / sqrt(2*pi*var) * exp(-magSqr(center-h)/(2*var))
	responsibility[pp][qq][] = numerator[r]/sum(numerator)

	return 0
End

ThreadSafe Static Function renew_responsibility_helper_cauchy_mixture(
	Wave responsibility, Wave w, Wave center, Wave scalew, Wave mixing_coef,
	int pp, int qq)

	Variable h = w[pp][qq]
	MatrixOP/FREE numerator = mixing_coef * scalew / (magSqr(cmplx(center-h,scalew)) * pi)
	responsibility[pp][qq][] = numerator[r]/sum(numerator)

	return 0
End

ThreadSafe Static Function renew_responsibility_helper_kmeans(
	Wave responsibility, Wave w, Wave center, int pp, int qq)

	Make/D/N=(numpnts(center))/FREE distance = (w[pp][qq]-center[p])^2
	WaveStats/Q/M=0 distance
	responsibility[pp][qq][] = r==V_minloc

	return 0
End


Static Function calc_objective(Wave w, Wave center, Wave responsibility)

	Make/D/N=(numpnts(center))/FREE tw
	MultiThread tw = calc_objective_helper(w, center, responsibility, p)

	return sum(tw)
End

ThreadSafe Static Function calc_objective_helper(Wave w, Wave center,
	Wave responsibility, Variable cls)

	MatrixOP/FREE tw = sum(magSqr(w-center[cls]) * responsibility[][][cls])

	return tw[0]
End


//------------------------------------------------------------------------------

#ifdef DEBUG_SIDAMSubtraction_MLE

Static Structure debug_structure
	Wave responsibilities
	Wave objective
	Wave center
	Wave var
	Wave scale
	Variable trn
	uint64 maxiterations
EndStructure

Static Function debug_initialize_variables(STRUCT debug_structure &s,
	Wave responsibility, Variable obj, int maxiterations)

	Duplicate/FREE responsibility, s.responsibilities
	Redimension/N=(-1,-1,-1,maxiterations+1) s.responsibilities

	Make/D/N=(maxiterations+1)/FREE objective
	Wave s.objective = objective

	debug_store_variables(s, responsibility, obj, 0)
	s.trn = startMSTimer
	s.maxiterations = maxiterations
End

Static Function debug_store_variables(STRUCT debug_structure &s,
	Wave responsibility, Variable obj, int index)

	Wave resw = s.responsibilities
	resw[][][][index] = responsibility[p][q][r]

	s.objective[index] = obj
End


Static Function debug_save_outputs(STRUCT debug_structure &s,
	Wave w, int isConverged, int i)

	if (isConverged)
		printf "iterations: %d\r", i
		DeletePoints/M=0 i+1, s.maxiterations+1-(i+1), s.objective
		DeletePoints/M=3 i+1, s.maxiterations+1-(i+1), s.responsibilities
	endif
	printf "time (s): %.3f\r", stopMSTimer(s.trn)*1e-6

	String basename = StrVarOrDefault("DEBUG_BASENAME", NameOfWave(w)) +\
		"_MLE_debug_"
	Duplicate/O s.objective, $(basename+"objective")
	Duplicate/O s.center, $(basename+"center")
	if (WaveExists(s.var))
		Duplicate/O s.var, $(basename+"var")
	endif
	if (WaveExists(s.scale))
		Duplicate/O s.scale, $(basename+"scale")
	endif

	Duplicate/O debug_make_map(w, s.responsibilities), $(basename+\
		"responsibility_map")
End

Static Function/WAVE debug_make_map(Wave w, Wave rw)

	Make/B/U/N=(DimSize(rw,0),DimSize(rw,1),DimSize(rw,3))/FREE mapw
	Variable threshold = NumVarOrDefault("DEBUG_THRESHOLD_MAP", \
		DEFAULT_DEBUG_THRESHOLD_MAP)
	MultiThread mapw = debug_make_map_helper(rw, threshold, p, q, r)
	Copyscales w, mapw

	String noteStr
	Sprintf noteStr, "threshold: %.3f", threshold
	Note mapw, noteStr

	return mapw
End

ThreadSafe Static Function debug_make_map_helper(Wave rw, Variable threshold,
	int pp, int qq, int rr)

	WaveStats/P/Q/M=0/RMD=[pp][qq][][rr] rw

	return V_max >= threshold ? V_maxLayerLoc : -1
End

#endif
