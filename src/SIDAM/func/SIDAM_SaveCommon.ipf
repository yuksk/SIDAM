#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3	
#pragma ModuleName=SIDAMSaveCommon

#ifndef SIDAMshowProc
#pragma hide = 1
#endif

//	Functions used commonly in SIDAM_SaveGraphics and SIDAM_SaveMovie

//******************************************************************************
//	Controls
//******************************************************************************
//-------------------------------------------------------------
//	Button
//-------------------------------------------------------------
Static Function pnlButton(STRUCT WMButtonAction &s)
	if (s.eventCode != 2)
		return 0
	endif
	
	strswitch (s.ctrlName)
		case "saveB":
			ControlInfo/W=$s.win pathV
			String path = S_value
			if (strlen(path))
				GetFileFolderInfo/Q/Z path
				if (V_Flag)
					DoAlert 0, "\""+path+"\" can not be found."
					return 1
				endif
			else
				DoAlert 1, "A dialog to save a file will be displayed for each layer when you don't specify the path. Do you continue?"
				if (V_flag == 2)
					return 0
				endif
			endif
			KMChangeAllControlsDisableState(s.win,0,2)
			FUNCREF KMDoButtonPrototype fn = $GetUserData(s.win,s.ctrlName,"fn")
			fn(s.win)
			// *** FALLTHROUGH ***
		case "closeB":
			KillPath/Z SIDAMSaveCommon#getPathName(s.win)
			KillWindow $s.win
			break
	endswitch
End
//-------------------------------------------------------------
//	Checkbox for all except formatC in SaveGraphics
//-------------------------------------------------------------
Static Function pnlCheck(STRUCT WMCheckboxAction &s)
	if (s.eventCode != 2)
		return 0
	endif
	
	//	rgb_rC, cmyk_rC, and embedC, which are not used in SaveMovie,
	//	are just ignored in SaveMovie
	strswitch (s.ctrlName)
		case "all_rC":
			CheckBox select_rC value=0, win=$s.win
			break
		case "select_rC":
			CheckBox all_rC value=0, win=$s.win
			break
		case "rgb_rC":
			CheckBox cmyk_rC value=0, win=$s.win
			break
		case "cmyk_rC":
			CheckBox rgb_rC value=0, win=$s.win
			break
		case "embedC":
			CheckBox exceptC disable=!s.checked, win=$s.win
	endswitch
	
	return 0
End
//-------------------------------------------------------------
//	SetVariable
//-------------------------------------------------------------
Static Function pnlSetVar(STRUCT WMSetVariableAction &s)
	if (s.eventCode == -1)
		return 1
	endif
	
	strswitch (s.ctrlName)
		case "from_f_V":
		case "to_f_V":
			CheckBox all_rC value=0, win=$s.win
			Checkbox select_rC value=1, win=$s.win
			break
			
		case "filenameV":
			Button saveB disable=GrepString(s.sval, "[\\/:*?\"<>|]")*2, win=$s.win
			break
			
	endswitch
End
//-------------------------------------------------------------
//	Popupmenu
//-------------------------------------------------------------
Static Function pnlPopup(STRUCT WMPopupAction &s)
	if (s.eventCode != 2)
		return 0
	endif
	
	strswitch (s.ctrlName)
		
		//	resolutionP is not used in SaveMovie and just ignored
		case "resolutionP":
			PopupMenu dpiP disable=(s.popNum != 6), win=$s.win
			break
			
		case "pathP":
			String pathName = getPathName(StringFromList(1,s.win,"#"))
			switch (s.popNum)
				case 1:
					SetVariable pathV value=_STR:"", win=$s.win
					break
				case 2:
					NewPath/O/Q/M="Specify folder to save files" $pathName
					if (!V_flag)
						PathInfo $pathName
						SetVariable pathV value=_STR:S_path, win=$s.win
					endif
					break
				default:
					PathInfo $s.popStr
					SetVariable pathV value=_STR:SelectString(V_flag, "", S_path), win=$s.win
			endswitch
			break
			
	endswitch
	
	return 0
End

//******************************************************************************
//	misc
//******************************************************************************
//-------------------------------------------------------------
//	get "from", "to", and present layers
//-------------------------------------------------------------
Static Function/WAVE getLayers(String pnlName)
	String grfName = StringFromList(0,pnlName,"#")
	int initIndex = KMLayerViewerDo(grfName)	//	present layer
	
	ControlInfo/W=$pnlName all_rC
	if (V_Value)
		Wave w = KMGetImageWaveRef(grfName)
		Make/W/U/FREE rtnw = {0, DimSize(w,2)-1, initIndex}
	else
		Wave cw = KMGetCtrlValues(pnlName,"from_f_V;to_f_V")
		Make/W/U/FREE rtnw = {WaveMin(cw), WaveMax(cw), initIndex}
	endif
	
	return rtnw
End
//-------------------------------------------------------------
//	return a path name used temporary
//-------------------------------------------------------------
Static Function/S getPathName(String pnlName)
	
	strswitch (pnlName)
		case "SaveGraphics":
			return  "SIDAMSaveGraphicsPnl"
			
		case "SaveMovie":
			return "SIDAMSaveMoviePnl"
			
		default:
			return ""
			
	endswitch
End
//-------------------------------------------------------------
//	Prototype for functions invoked by pressing "Do" button
//-------------------------------------------------------------
Function KMDoButtonPrototype(String pnlName)
	return 0
End