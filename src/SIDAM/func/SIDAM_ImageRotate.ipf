#pragma TextEncoding="UTF-8"
#pragma rtGlobals=3
#pragma ModuleName = SIDAMImageRotate

#include "SIDAM_Bias"
#include "SIDAM_Display"
#include "SIDAM_Help"
#include "SIDAM_Utilities_Control"
#include "SIDAM_Utilities_Image"
#include "SIDAM_Utilities_Window"

#ifndef SIDAMshowProc
#pragma hide = 1
#endif

//-
//	Rotate an image wave around the center of the image
//
//	## Parameters
//	w : wave
//		The input wave, 2D or 3D.
//	angle : variable
//		The rotation angle in degrees. A positive value means a 
//		counter-clock wise rotation.
//
//	## Returns
//	wave
//		Rotated wave.
//-
Function/WAVE SIDAMImageRotate(Wave w, Variable angle)

	int err = validate(w)
	if (err)
		printf "%s%s gave error: %s\r", PRESTR_CAUTION, GetRTStackInfo(1), errormsg(err)
		return $""
	endif
	
	DFREF dfrSav = GetDataFolderDFR()
	SetDataFolder NewFREeDataFolder()
		
	//	calculate coordinates of four corners
	Variable ox = DimOffset(w,0), oy = DimOffset(w,1)
	Variable dx = DimDelta(w,0), dy = DimDelta(w,1)
	Variable nx = DimSize(w,0), ny = DimSize(w,1)
	Variable lx = dx*nx, ly = dy*ny
	Make/D/N=(2,4) corners
	corners[][0] = {ox-dx/2, oy-dy/2}
	corners[][1] = {ox-dx/2+lx, oy-dy/2}
	corners[][2] = {ox-dx/2+lx, oy-dy/2+ly}
	corners[][3] = {ox-dx/2, oy-dy/2+ly}
	
	Make/D/N=2 center = {ox-dx/2+lx/2, oy-dy/2+ly/2}
	corners -= center[p]

	Variable theta = angle/180*pi
	Make/D rot = {{cos(theta),sin(theta)},{-sin(theta),cos(theta)}}
	MatrixOP corners_rotated = rot x corners
	
	corners_rotated += center[p]
		
	MatrixOP minw = minRows(corners_rotated)
	MatrixOP maxw = maxRows(corners_rotated)

	if (mod(angle,360)==90 ||mod(angle,360)==-270)
		ImageRotate/C w
	elseif (mod(angle,360)==270 ||mod(angle,360)==-90)
		ImageRotate/W w
	else
		ImageRotate/A=(angle) w
	endif
	Wave rw = M_RotatedImage
	Setscale/I x minw[0]+dx/2, maxw[0]-dx/2, WaveUnits(w,0), rw
	Setscale/I y minw[1]+dy/2, maxw[1]-dy/2, WaveUnits(w,1), rw
	if (SIDAMisUnevenlySpacedBias(w))
		SIDAMCopyBias(w, rw)
	else
		Setscale/P z DimOffset(w,2), DimDelta(w,2), WaveUnits(w,2), rw
	endif
	Setscale d 0, 1, WaveUnits(w,-1), rw
	
	SetDataFolder dfrSav
	return rw
End

Static Function validate(Wave/Z w)
	if (!WaveExists(w))
		return 1
	elseif (WaveType(w,1)!=1)
		return 2
	elseif (WaveDims(w)!=2 && WaveDims(w)!=3)
		return 3
	endif
	
	return 0
End

Static Function/S errormsg(int flag)
	Make/N=4/T/FREE msg
	msg = { \
		"", \
		"the input wave is not found.", \
		"the input wave must be numeric.", \
		"the dimension of input wave must be 2 or 3."\
	}
	return msg[flag]
End

Static Function/S echoStr(String path, Variable angle, String result)
	String str
	sprintf str "Duplicate/O SIDAMImageRotate(%s, %f), %s%s"\
		, path, angle, ParseFilePath(1, path, ":", 1, 0), PossiblyQuoteName(result)
	return str
End

Static Function menuDo()
	String grfName = WinName(0,4311,1)
	Wave/Z w = SIDAMImageNameToWaveRef(grfName)
	if (WaveExists(w))
		pnl(w, grfName)
	endif
End

//******************************************************************************
//	Panel
//******************************************************************************
Static StrConstant SUFFIX = "_rot"

Static Function pnl(Wave w, String grfName)
	String pnlName = grfName+"#Rotation"
	if (SIDAMWindowExists(pnlName))
		return 0
	endif
	
	NewPanel/EXT=0/HOST=$grfName/W=(0,0,328,115)/N=Rotation
	SetWindow $pnlName hook(self)=SIDAMUtilPanel#SIDAMWindowHookClose
	
	SetVariable sourceV title="source wave:", pos={4,3}, size={312,18}, win=$pnlName
	SetVariable sourceV bodyWidth=240, noedit=1, frame=0, win=$pnlName
	SetVariable sourceV value= _STR:GetWavesDataFolder(w,2), win=$pnlName
	SetVariable resultV title="output name:", pos={4,28}, size={315,16}, win=$pnlName
	SetVariable resultV value=_STR:NameOfWave(w)+SUFFIX, bodyWidth=240, win=$pnlName
	SetVariable resultV proc=SIDAMImageRotate#pnlSetVar, win=$pnlName
	SetVariable angleV title="angle:", pos={43,54}, size={96,18}, win=$pnlName
	SetVariable angleV bodyWidth=60, value=_NUM:0, win=$pnlName
		
	Button doB title="Do It", pos={9,85}, size={60,20}, win=$pnlName
	CheckBox displayC title="display", pos={83,87}, value=0, win=$pnlName
	PopupMenu toP title="To", pos={153,86}, size={50,20}, win=$pnlName
	PopupMenu toP value="Cmd Line;Clip", mode=0, bodyWidth=50, win=$pnlName
	PopupMenu toP proc=SIDAMImageRotate#pnlPopup, win=$pnlName
	Button cancelB title="Cancel", pos={257,85}, size={60,20}, win=$pnlName
	
	ModifyControlList "doB;cancelB" proc=SIDAMImageRotate#pnlButton, win=$pnlName
	ModifyControlList ControlNameList(pnlName,";","*"), focusRing=0, win=$pnlName
	
	SIDAMApplyHelp(pnlName, "[SIDAM_ImageRotate]")	
	
	SetActiveSubwindow $pnlName
End

//******************************************************************************
//	Controls
//******************************************************************************
//	Button
Static Function pnlButton(STRUCT WMButtonAction &s)

	if (s.eventCode != 2)
		return 0
	endif

	strswitch (s.ctrlName)
		case "cancelB":
			KillWindow $s.win
			break
		
		case "doB":
			Wave/T ctw = SIDAMGetCtrlTexts(s.win,"sourceV;resultV")
			Wave cvw = SIDAMGetCtrlValues(s.win,"angleV;displayC")
			KillWindow $s.win
			
			printf "%s%s\r" PRESTR_CMD, echoStr(ctw[%sourceV], cvw[%angleV], \
				ctw[%resultV])
			DFREF dfr = GetWavesDataFolderDFR($ctw[%sourceV])
			Duplicate/O SIDAMImageRotate($ctw[%sourceV], cvw[%angleV] \
				) dfr:$ctw[%resultV]/WAVE=resw
		
			if (cvw[%displayC])
				SIDAMDisplay(resw, history=1)
			endif
			break	
	endswitch
End

//	SetVariable (resultV only)
Static Function pnlSetVar(STRUCT WMSetVariableAction &s)

	//	Handle either mouse up, enter key, or end edit
	if (s.eventCode != 1 && s.eventCode != 2 && s.eventCode != 8)
		return 1
	elseif (CmpStr(s.ctrlName,"resultV"))
		return 1
	endif

	Variable disable = SIDAMValidateSetVariableString(s.win,s.ctrlName,0)*2
	Button doB disable=disable, win=$s.win
	CheckBox displayC disable=disable, win=$s.win
	PopupMenu toP disable=disable, win=$s.win
End

//	Popup (toP only)
Static Function pnlPopup(STRUCT WMPopupAction &s)

	if (s.eventCode != 2)
		return 1
	elseif (CmpStr(s.ctrlName,"toP"))
		return 1
	endif
	
	Wave/T ctw = SIDAMGetCtrlTexts(s.win,"sourceV;resultV")
	ControlInfo/W=$s.win angleV
	SIDAMPopupTo(s, echoStr(ctw[%sourceV], V_Value, ctw[%resultV]))
End

