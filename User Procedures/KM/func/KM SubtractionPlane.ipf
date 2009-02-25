#pragma TextEncoding="UTF-8"
#pragma rtGlobals=1

#ifndef KMshowProcedures
#pragma hide = 1
#endif

//******************************************************************************
//	KMPlaneSubtraction
//		各実行関数の呼び出し
//******************************************************************************
Function/WAVE KMPlaneSubtraction(w,order,[roi])
	Wave w				//	実行対象となるウエーブ、実行結果が上書きされます
	Wave roi
	Variable order	//	差し引く曲面の次元、省略時は1
	
	DFREF dfrSav = GetDataFolderDFR()
	SetDataFolder NewFreeDataFolder()
	
	Duplicate w tw
	
	if (ParamIsDefault(roi))
		if (WaveDims(w) == 2)
			WaveStats/Q/M=1 tw
			if (order == 0)
				tw -= V_avg
			elseif (order == 1 && !V_numNaNs && !V_numINFs)
				KMPlaneSubtraction2D(tw)
			else
				Make/N=(DimSize(tw,0),DimSize(tw,1))/B/U/FREE troi=1
				ImageRemoveBackground /R=troi/O/P=(order) tw
			endif
		elseif (WaveDims(w) == 3)
			KMPlaneSubtraction3D(tw,order)
		endif
	else
		//	roi = {{p0,q0},{p1,q1}} のように与えられる
		//	 roi[0][0] = p0, roi[1][0] = q0, roi[0][1] = p1, roi[1][1] = q1
		Duplicate/FREE/R=[roi[0][0],roi[0][1]][roi[1][0],roi[1][1]] w tw2
		Wave coefw =  KMPlaneSubtraction2D(tw2, coefw={0,0,0})//	取得した領域についての係数を求める
		KMPlaneSubtraction2D(tw, coefw=coefw, history=1)	//	平面除去
	endif
	
	SetDataFolder dfrSav
	
	return tw
End


//******************************************************************************
//	実行関数: 2D
//******************************************************************************
//-------------------------------------------------------------
//	KMPlaneSubtraction2D
//		平面を差し引く場合
//		ImageRemoveBackGroundよりも実行速度が速い。
//		512*512ピクセルの像で3倍以上高速
//-------------------------------------------------------------
Static Function/WAVE KMPlaneSubtraction2D(
	Wave w,
	[
		Wave/Z coefw,
		int history
	])
	
	Variable nx = DimSize(w,0), ny = DimSize(w,1), mode, a, b, c
	
	Make/N=(nx,ny)/FREE pMat, qMat
	MultiThread pMat = p
	MultiThread qMat = q
	
	if (ParamIsDefault(coefw))
		mode = 0	//	係数を求めて平面除去
	elseif (coefw[0] || coefw[1] || coefw[2])
		mode = 1	//	係数を与えて平面除去
	else
		mode = 2	//	係数を求めて返す(平面除去しない)
	endif
	
	if (mode == 1)
		a = coefw[0]
		b = coefw[1]
		c = coefw[2]
	else
		//  最小自乗法における係数を求める方程式 Ax = b において
		
		//  行列A
		Make/N=(3,3)/FREE m
		m[0][0] = 2*(nx-1)*(2*nx-1)	; m[0][1] = 3*(nx-1)*(ny-1)		; m[0][2] = 6*(nx-1)
		m[1][0] = 3*(nx-1)*(ny-1)		; m[1][1] = 2*(ny-1)*(2*ny-1)	; m[1][2] = 6*(ny-1)
		m[2][0] = 6*(nx-1)			; m[2][1] = 6*(ny-1)			; m[2][2] = 12
		m *= (nx*ny/12)
		
		//  ベクトルb
		Make/N=(nx,ny)/FREE vw0, vw1
		FastOp vw0 = w * pMat
		FastOp vw1 = w * qMat
		Make/N=3/FREE v = {sum(vw0), sum(vw1), sum(w)}
		
		//  係数ベクトルxを求めるクラメルの公式 ・・・ MatrixSolveを使うより速い
		Variable detA = m[0][0]*m[1][1]*m[2][2]+m[0][2]*m[1][0]*m[2][1]+m[0][1]*m[1][2]*m[2][0]-m[0][2]*m[1][1]*m[2][0]-m[0][0]*m[1][2]*m[2][1]-m[0][1]*m[1][0]*m[2][2]
		Variable detx0 = v[0]*m[1][1]*m[2][2]+m[0][2]*v[1]*m[2][1]+m[0][1]*m[1][2]*v[2]-m[0][2]*m[1][1]*v[2]-v[0]*m[1][2]*m[2][1]-m[0][1]*v[1]*m[2][2]
		Variable detx1 = m[0][0]*v[1]*m[2][2]+m[0][2]*m[1][0]*v[2]+v[0]*m[1][2]*m[2][0]-m[0][2]*v[1]*m[2][0]-m[0][0]*m[1][2]*v[2]-v[0]*m[1][0]*m[2][2]
		Variable detx2 = m[0][0]*m[1][1]*v[2]+v[0]*m[1][0]*m[2][1]+m[0][1]*v[1]*m[2][0]-v[0]*m[1][1]*m[2][0]-m[0][0]*v[1]*m[2][1]-m[0][1]*m[1][0]*v[2]
		a = detx0/detA
		b = detx1/detA
		c = detx2/detA
	endif
	
	if (mode == 2)
		Make/FREE rtnw = {a,b,c}
		return rtnw
	endif
	
	//  平面除去
	Make/N=(nx,ny)/FREE subw
	FastOp subw = (a)*pMat
	FastOp subw = (b)*qMat+subw
	FastOp subw = subw+(c)
	FastOp w = w-subw
	
	//  履歴出力
	if (ParamIsDefault(history) || history)
		printf "subtracted plane (ap+bq+c):\r"
		printf "a: %e\tb: %e\tc:%e\t(%f [deg])\r", a, b, c, acos((a^2+b^2+1)^-0.5)/pi*180
	endif
End


//******************************************************************************
//	KMPlaneSubtraction3D
//		実行関数: 3D
//******************************************************************************
Static Function KMPlaneSubtraction3D(Wave w, int order)
	
	int i, nz = DimSize(w,2)
	
	//  0次の場合
	if (order == 0)
		for (i = 0; i < nz; i++)
			MatrixOP/O/FREE tw = w[][][i]
			WaveStats/Q/M=1 tw		//	inf が含まれるとき、ImageStats で与えられる V_avg は inf になる
			w[][][i] -= V_avg
		endfor
		return 0
	endif
	
	//  1次以上の場合
	Make/N=(DimSize(w,0),DimSize(w,1)) $"_KMPlaneSubtraction3D"/WAVE=tw
	
	WaveStats/Q/M=1 w
	if (order == 1 && !V_numNaNs && !V_numINFs)
		for (i = 0; i < nz; i++)
			MatrixOP/O/S tw = w[][][i]
			KMPlaneSubtraction2D(tw,history=0)
			w[][][i] = tw[p][q]
		endfor
	else
		Make/N=(DimSize(w,0),DimSize(w,1))/B/U/FREE roi=1
		for (i = 0; i < nz; i++)
			MatrixOP/O/S tw = w[][][i]
			ImageRemoveBackground /R=roi/O/P=(order) tw
			w[][][i] = tw[p][q]
		endfor
	endif
	KillWaves/Z tw
End
