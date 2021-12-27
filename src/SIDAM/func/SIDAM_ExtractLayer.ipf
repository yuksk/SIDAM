#pragma TextEncoding="UTF-8"
#pragma rtGlobals=3
#pragma moduleName = SIDAMExtractLayer

#include "SIDAM_Color"
#include "SIDAM_Display"
#include "SIDAM_Range"
#include "SIDAM_Utilities_Control"
#include "SIDAM_Utilities_Image"
#include "SIDAM_Utilities_ImageInfo"
#include "SIDAM_Utilities_Window"

#ifndef SIDAMshowProc
#pragma hide = 1
#endif

#include <WMImageInfo>

//-------------------------------------------------------------
//	Menu items
//-------------------------------------------------------------
Static Function/S menuItem()
	Wave/Z w = SIDAMImageNameToWaveRef(WinName(0,1))
	if (!WaveExists(w) || WaveDims(w) != 3)
		return ""
	endif
	return "Extract Layers..."
End

Static Function menuDo()
	pnl(WinName(0,1))
End

//-------------------------------------------------------------
//	Panel
//-------------------------------------------------------------
Static Function pnl(String grfName)
	
	if (SIDAMWindowExists(grfName+"#ExtractLayers"))
		return 0
	endif
	
	Wave w = SIDAMImageNameToWaveRef(grfName)
	int plane = SIDAMGetLayerIndex(grfName)

	NewPanel/HOST=$grfName/EXT=0/W=(0,0,290,195)
	RenameWindow $grfName#$S_name, ExtractLayers
	String pnlName = grfName + "#ExtractLayers"
	
	GroupBox layer0G title="Layer", pos={11,4}, size={268,70}, win=$pnlName
	CheckBox thisC title="this ("+num2str(plane)+")", pos={23,26}, size={66,14}, value=1, mode=1, proc=SIDAMExtractLayer#pnlCheck, win=$pnlName
	CheckBox fromC title="", pos={23,49}, size={16,14}, value=0, mode=1, proc=SIDAMExtractLayer#pnlCheck, win=$pnlName
	SetVariable from_w_V title="from:", pos={41,48}, size={79,15}, bodyWidth=50, proc=SIDAMExtractLayer#pnlSetVar, win=$pnlName
	SetVariable from_w_V value=_NUM:0, limits={0,DimSize(w,2)-1,1}, format="%d", win=$pnlName
	SetVariable to_w_V title="to:", pos={131,48}, size={66,15}, bodyWidth=50, proc=SIDAMExtractLayer#pnlSetVar, win=$pnlName
	SetVariable to_w_V value=_NUM:DimSize(w,2)-1, limits={0,DimSize(w,2)-1,1}, format="%d", win=$pnlName

	GroupBox waveG title="Wave", pos={11,80}, size={268,70}, win=$pnlName
	TitleBox resultT title="output name:", pos={30,101}, frame=0, win=$pnlName
	SetVariable resultV title=" ", pos={28,121}, size={235,15}, bodyWidth=235, proc=SIDAMExtractLayer#pnlSetVar, win=$pnlName
	SetVariable resultV value=_STR:NameOfWave(w)[0,30-strlen("_r"+num2str(plane))]+"_r"+num2str(plane), win=$pnlName

	Button doB title="Do It", pos={8,165}, size={70,20}, proc=SIDAMExtractLayer#pnlButton, win=$pnlName
	Button closeB title="Close", pos={214,165}, size={70,20}, proc=SIDAMExtractLayer#pnlButton, win=$pnlName
	CheckBox displayC title="display", pos={87,168}, value=1, win=$pnlName
	
	ModifyControlList ControlNameList(pnlName,";","*") focusRing=0, win=$pnlName
	
	SetActiveSubwindow $grfName
End

//-------------------------------------------------------------
//	Controls
//-------------------------------------------------------------
//	Button
Static Function pnlButton(STRUCT WMButtonAction &s)
	
	if (s.eventCode != 2)
		return 0
	endif
	
	strswitch (s.ctrlName)
		case "doB":
			pnlSave(s.win)
			// *** FALLTHROUGH ***
		case "closeB":
			KillWindow $s.win
			break
		default:
	endswitch
End

//	Checkbox
Static Function pnlCheck(STRUCT WMCheckboxAction &s)
	
	if (s.eventCode != 2)
		return 1
	endif
	
	CheckBox thisC value=stringmatch(s.ctrlName,"thisC"), win=$s.win
	CheckBox fromC value=stringmatch(s.ctrlName,"fromC"), win=$s.win
	CheckBox displayC disable=stringmatch(s.ctrlName,"fromC")*2, win=$s.win
	TitleBox resultT title=SelectString(WhichListItem(s.ctrlName,"thisC;fromC;"),"output name:","basename"), win=$s.win
	
	String parentWin = StringFromList(0, s.win, "#")
	Wave w = SIDAMImageNameToWaveRef(parentWin)
	int plane = SIDAMGetLayerIndex(parentWin)
	
	String name = NameOfWave(w)+"_r"
	ControlInfo/W=$s.win resultV
	//	If the name is the default name
	if (stringmatch(S_value[0,strlen(NameOfWave(w))+1], name))
		if (stringmatch(s.ctrlName,"thisC"))
			SetVariable resultV value=_STR:name+num2str(plane), win=$s.win
		elseif (stringmatch(s.ctrlName,"fromC"))
			SetVariable resultV value=_STR:name, win=$s.win
		endif
	endif
	Button doB disable=CheckResultStrLength(s.win)*2, win=$s.win
End

//	Setvariable
Static Function pnlSetVar(STRUCT WMSetVariableAction &s)
	
	//	Handle either mouse up, enter key, or end edit
	if (s.eventCode != 1 && s.eventCode != 2 && s.eventCode != 8)
		return 1
	endif
	
	strswitch (s.ctrlName)
		case "from_w_V" :
		case "to_w_V" :
			SIDAMClickCheckBox(s.win,"fromC")
			break
		case "resultV" :
			Button doB disable=CheckResultStrLength(s.win)*2, win=$s.win
			break
		default:
	endswitch
End

//-------------------------------------------------------------
//	Helper function of controls
//-------------------------------------------------------------
Static Function CheckResultStrLength(String pnlName)
	int maxLength = MAX_OBJ_NAME
	
	ControlInfo/W=$pnlName fromC
	if (V_Value)
		Wave cvw = SIDAMGetCtrlValues(pnlName, "from_w_V;to_w_V")
		//	Subtract the digit of the bigger one of "from" or "to"
		maxLength -= floor(log(WaveMax(cvw)))+1
	endif
	
	return SIDAMValidateSetVariableString(pnlName,"resultV", 0, maxlength=maxLength)
End

Static Function pnlSave(String pnlName)
	
	String grfName = StringFromList(0, pnlName, "#")
	Wave w = SIDAMImageNameToWaveRef(grfName)
	
	ControlInfo/W=$pnlName resultV
	String result = S_value
	
	DFREF dfrSav = GetDataFolderDFR()
	SetDataFolder GetWavesDataFolderDFR(w)
	
	ControlInfo/W=$pnlName thisC
	if (V_Value)

		int plane = SIDAMGetLayerIndex(grfName)
		Duplicate/O/R=[][][plane] w, $result
		Redimension/N=(-1,-1) $result
		ControlInfo/W=$pnlName displayC
		if (V_Value && !V_Disable)
			pnlDisplay($result, grfName)
		endif

	else

		Wave cw = SIDAMGetCtrlValues(pnlName,"from_w_V;to_w_V")
		int digit = WaveMin(cw) ? floor(log(WaveMax(cw)))+1 : 1
		String name
		int i
		for (i = WaveMin(cw); i <= WaveMax(cw); i++)
			sprintf name, "%s%0"+num2istr(digit)+"d", result, i
			Duplicate/O/R=[][][i] w, $name
			Redimension/N=(-1,-1) $name
		endfor

	endif
	
	SetDataFolder dfrSav
End

//	Handle the behavior when displayC is checked.
Static Function pnlDisplay(Wave extw, String LVName)
	
	String grfName = SIDAMDisplay(extw, history=1)
	
	//	Copy the z range
	Wave srcw = SIDAMImageNameToWaveRef(LVName)
	Variable zmin, zmax
	SIDAM_GetColorTableMinMax(LVName, NameOfWave(srcw),zmin,zmax,allowNaN=1)
	SIDAMRange(grfName=grfName,imgList=NameOfWave(extw),zmin=zmin,zmax=zmax)
	
	//	Copy the color table
	String ctab = WM_ColorTableForImage(LVName, NameOfWave(srcw))
	int rev = WM_ColorTableReversed(LVName, NameOfWave(srcw))
	int log = SIDAM_ColorTableLog(LVName,NameOfWave(srcw))
	Wave minRGB = makeRGBWave(LVName, NameOfWave(srcw), "minRGB")
	Wave maxRGB = makeRGBWave(LVName, NameOfWave(srcw), "maxRGB")
	SIDAMColor(grfName=grfName,imgList=NameOfWave(extw),ctable=ctab,rev=rev,\
		log=log,minRGB=minRGB,maxRGB=maxRGB,history=1)
	
	//	Copy expand, axis, and textbox
	String cmd, recStr = WinRecreation(LVName, 4)
	//		subwindow is unnecessary
	Variable v0 = strsearch(recStr, "NewPanel",0)
	v0 = (v0 == -1) ? strlen(recStr)-1 : v0
	recStr = recStr[0,v0]
	
	cmd = ReplaceString("\r\t", GrepList(recStr,"\tModifyGraph",0,"\r"), ";")
	cmd = ReplaceString("expand=-", cmd, "expand=")
	Execute/Z cmd
	cmd = ReplaceString("\r\t", GrepList(recStr,"\tSetAxis",0,"\r"), ";")
	Execute/Z cmd
	cmd = ReplaceString("\r\t", GrepList(recStr,"\tTextBox",0,"\r"), ";")
	Execute/Z cmd
End

Static Function/WAVE makeRGBWave(String grfName, String imgName, String key)
	
	switch (SIDAM_ImageColorRGBMode(grfName,imgName,key))
		case 0:
			Make/FREE rgbw = {0}
			break
		case 1:
			STRUCT RGBColor s
			SIDAM_ImageColorRGBValues(grfName,imgName,key,s)
			Make/FREE rgbw = {s.red,s.green,s.blue}
			break
		case 2:
			Make/FREE rgbw = {NaN}
			break	
	endswitch
	
	return rgbw
End

