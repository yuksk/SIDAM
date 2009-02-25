#pragma TextEncoding="UTF-8"
#pragma rtGlobals=3

#ifndef KMshowProcedures
#pragma hide = 1
#endif

//******************************************************************************
//	KMLineSubtraction
//		実行関数の呼び出し
//******************************************************************************
Function/WAVE KMLineSubtraction(
	Wave w,			//	実行対象となるウエーブ、実行結果が上書きされます
	int order,		//	0は平均を、1は最小自乗法による直線を差し引く、省略時は0
	int direction	//	実行する方向 0:横, 1:縦, 省略時は0
	)
	
	//  実行
	if (WaveDims(w) == 2)
		switch (order)
			case 0:
				return avgSubFor2D(w,direction)
			case 1:
				return lineSubFor2D(w,direction)
			case 2:
				return parabolaSubFor2D(w,direction)
		endswitch
	elseif (WaveDims(w) == 3)
		return subFor3D(w,order,direction)
	endif
End


//=====================================================================================================


//******************************************************************************
//	実行関数: 平均・2D
//******************************************************************************
Static Function/WAVE avgSubFor2D(Wave w, int direction)
	
	Duplicate/FREE w rtnw
	
	Variable nx = DimSize(w,0), ny = DimSize(w,1)
	if (direction)	//	縦
		MatrixOP/FREE tw = sumRows(w) / ny
		rtnw -= tw[p]
	else			//	横
		MatrixOP/FREE tw = sumCols(w) / nx
		rtnw -= tw[0][q]
	endif
	
	return rtnw
End

//******************************************************************************
//	実行関数: 直線・2D
//******************************************************************************
Static Function/WAVE lineSubFor2D(Wave w, int direction)
	
	Duplicate/FREE w rtnw
	
	if (direction)
		Make/N=(DimSize(w,1),2)/FREE matrixA = p^q
	else
		Make/N=(DimSize(w,0),2)/FREE matrixA = p^q
	endif
	
	if (direction)	//	縦
		Make/N=(DimSize(w,0))/FREE dummy
		MultiThread dummy = lineSubFor2D_workerV(rtnw,p,matrixA)
	else				//	横
		Make/N=(DimSize(w,1))/FREE dummy
		MultiThread dummy = lineSubFor2D_workerH(rtnw,p,matrixA)
	endif
	
	return rtnw
End

ThreadSafe Static Function lineSubFor2D_workerV(Wave w, Variable index, Wave Aw)
	MatrixOP/FREE tw = row(w,index)
	Redimension/N=(DimSize(w,0)) tw
	MatrixLLS Aw tw
	Wave bw = M_B
	w[index][] -= bw[0] + bw[1]*q
	return V_flag
End

ThreadSafe Static Function lineSubFor2D_workerH(Wave w, Variable index, Wave Aw)
	MatrixOP/FREE tw = col(w,index)
	MatrixLLS Aw tw
	Wave bw = M_B
	w[][index] -= bw[0] + bw[1]*p
	return V_flag
End

//******************************************************************************
//	実行関数: 2次曲線・2D
//******************************************************************************
Static Function/WAVE parabolaSubFor2D(Wave w, int direction)

	Duplicate/FREE w rtnw
		
	if (direction)
		Make/N=(DimSize(w,1),3)/FREE matrixA = p^q
	else
		Make/N=(DimSize(w,0),3)/FREE matrixA = p^q
	endif
	
	if (direction)	//	縦
		Make/N=(DimSize(w,0))/FREE dummy
		MultiThread dummy = parabolaSubFor2D_workerV(rtnw,p,matrixA)
	else				//	横
		Make/N=(DimSize(w,1))/FREE dummy
		MultiThread dummy = parabolaSubFor2D_workerH(rtnw,p,matrixA)
	endif
	
	return rtnw
End

ThreadSafe Static Function parabolaSubFor2D_workerV(Wave w, Variable index, Wave Aw)
	MatrixOP/FREE tw = row(w,index)
	Redimension/N=(DimSize(w,0)) tw
	MatrixLLS Aw tw
	Wave bw = M_B
	w[index][] -= bw[0] + (bw[1]+bw[2]*q)*q
	return V_flag
End

ThreadSafe Static Function parabolaSubFor2D_workerH(Wave w, Variable index, Wave Aw)
	MatrixOP/FREE tw = col(w,index)
	MatrixLLS Aw tw
	Wave bw = M_B
	w[][index] -= bw[0] + (bw[1]+bw[2]*p)*p
	return V_flag
End

//******************************************************************************
//	実行関数: 3D
//******************************************************************************
Static Function/WAVE subFor3D(Wave w, int order, int direction)
	
	Make/N=(DimSize(w,2))/WAVE/FREE tww
	
	int i
	for (i = 0; i < DimSize(w,2); i++)
		MatrixOP/FREE tw = w[][][i]
		switch (order)
			case 0:
				tww[i] = avgSubFor2D(tw,direction)
				break
			case 1:
				tww[i] = lineSubFor2D(tw,direction)
				break
			case 2:
				tww[i] = parabolaSubFor2D(tw,direction)
				break
		endswitch		
	endfor
	
	Wave rtnw = tww[0]
	for (i = 1; i < DimSize(w,2); i++)
		Concatenate/NP=2 {tww[i]}, rtnw
	endfor
	Copyscales w, rtnw
	
	return rtnw
End