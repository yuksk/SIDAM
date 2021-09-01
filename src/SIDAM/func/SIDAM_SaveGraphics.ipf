#pragma TextEncoding="UTF-8"
#pragma rtGlobals=3
#pragma ModuleName=SIDAMSaveGraphics

#include "SIDAM_SaveCommon"
#include "SIDAM_Utilities_Bias"
#include "SIDAM_Utilities_Control"
#include "SIDAM_Utilities_Image"

#ifndef SIDAMshowProc
#pragma hide = 1
#endif

//	When uncommented, the command string to save graphics is displayed in the history window
//	instead of saving graphics.
//#define DEBUG

// The disable state of the controls in this list depends on the format of graphics
Static StrConstant FORMAT_DEPENDENT_CTRL = "rgb_rC;cmyk_rC;tranC;dontembedC;embedC;exceptC;resolutionP;dpiP"


Static Function/S menu()
	int isWindows = stringmatch(IgorInfo(2),"Windows")
	
	Wave/Z w = SIDAMImageWaveRef(WinName(0,1))
	if (!WaveExists(w))
		return ""
	endif
	int is3D = WaveDims(w)==3
	
	return SelectString(isWindows && is3D, "", "\\M0Save Graphics (Layers)...")
End

Static Function menuDo()
	pnl(WinName(0,1))
End


//******************************************************************************
//	Display panel
//******************************************************************************
Static Function pnl(String grfName)
	NewPanel/HOST=$grfName/EXT=0/W=(0,0,390,390)
	RenameWindow $grfName#$S_name, SaveGraphics
	String pnlName = grfName + "#SaveGraphics"
	Wave w = SIDAMImageWaveRef(grfName)
	
	//	layer
	GroupBox layerG title="Layer", pos={5,4}, size={380,50}, win=$pnlName
	CheckBox all_rC title="all", pos={16,28}, value=1, proc=SIDAMSaveCommon#pnlCheck, win=$pnlName
	CheckBox select_rC title="", pos={78,28}, value=0, proc=SIDAMSaveCommon#pnlCheck, win=$pnlName
	SetVariable from_f_V title="from:", pos={97,26}, size={79,15}, value=_NUM:0, win=$pnlName
	SetVariable to_f_V title="to:", pos={186,26}, size={66,15}, value=_NUM:DimSize(w,2)-1, win=$pnlName
	ModifyControlList "from_f_V;to_f_V" bodyWidth=50, limits={0,DimSize(w,2)-1,1}, format="%d", proc=SIDAMSaveCommon#pnlSetVar, win=$pnlName
	
	//	format
	GroupBox formatG title="Format:", pos={5,60}, size={380,195}, win=$pnlName
	GroupBox group0 pos={12,80},size={140,168}, labelBack=(65535,65535,65535)
	
	CheckBox format_EMF_rC title="Enhanced Metafile", pos={20,85}, value=1, userData(value)="-2", win=$pnlName
	CheckBox format_BMP_rC title="Bitmap", pos={20,85+20}, userData(value)="-4", win=$pnlName
	CheckBox format_EPS_rC title="EPS File", pos={20,85+20*2}, userData(value)="-3", win=$pnlName
	CheckBox format_PDF_rC title="PDF", pos={20,85+20*3}, userData(value)="-8", win=$pnlName
	CheckBox format_PNG_rC title="PNG File", pos={20,85+20*4}, userData(value)="-5", win=$pnlName
	CheckBox format_JPG_rC title="JPEG File", pos={20,85+20*5}, userData(value)="-6", win=$pnlName
	CheckBox format_TIF_rC title="TIFF File", pos={20,85+20*6}, userData(value)="-7", win=$pnlName
	CheckBox format_SVG_rC title="SVG", pos={20,85+20*7}, userData(value)="-9", win=$pnlName
	
	CheckBox colorC title="Color", pos={175,85}, value=1, win=$pnlName
	CheckBox rgb_rC title="RGB", pos={240,85}, value=1, userData(format)="EPS;PDF;TIF", proc=SIDAMSaveCommon#pnlCheck, win=$pnlName
	CheckBox cmyk_rC title="CMYK", pos={288,85}, userData(format)="EPS;PDF;TIF", proc=SIDAMSaveCommon#pnlCheck, win=$pnlName
	CheckBox tranC title="Transparent", pos={175,109}, userData(format)="PNG;TIF", win=$pnlName
	CheckBox dontembedC title="Don't embed standard fonts", pos={175,109}, userData(format)="EPS", win=$pnlName
	CheckBox embedC title="Embed Fonts", pos={175,109}, value=1, userData(format)="PDF", proc=SIDAMSaveCommon#pnlCheck, win=$pnlName
	CheckBox exceptC title="Except Standard Fonts", pos={185,130}, userData(format)="PDF", win=$pnlName
	PopupMenu resolutionP title="Resolution:", pos={175,145}, size={142,19}, bodyWidth=80, win=$pnlName
	PopupMenu resolutionP value="Screen;2X Screen;4X Screen;5X Screen;8X Screen;Other DPI", mode=1, popvalue="Screen", win=$pnlName
	PopupMenu resolutionP userData(format)="BMP;PNG;JPG;TIF", userData(value)="72;144;288;360;576", proc=SIDAMSaveCommon#pnlPopup, win=$pnlName
	PopupMenu dpiP pos={325,145}, size={50,20}, bodyWidth=50, win=$pnlName
	PopupMenu dpiP value="72;75;96;100;120;150;200;300;400;500;600;750;800;1000;1200;1500;2000;2400;2500;3000;3500;3600;4000;4500;4800"
	PopupMenu dpiP mode=1, popvalue="72", userData(format)="BMP;PNG;JPG;TIF", win=$pnlName
	
	//	file
	GroupBox fileG title="File:", pos={5,260}, size={380,96}, win=$pnlName
	SetVariable filenameV title="Basename:", pos={12,281}, size={190,18}, bodyWidth=130, win=$pnlName
	SetVariable filenameV value=_STR:NameOfWave(w), proc=SIDAMSaveCommon#pnlSetVar, win=$pnlName
	PopupMenu suffixP title="Suffix:", pos={216,281}, size={157,20}, bodyWidth=120, win=$pnlName
	PopupMenu suffixP mode=1, value="index only;value only;index and value;", win=$pnlName
	PopupMenu pathP title="Path:", pos={12,305}, size={190,20}, bodyWidth=160, mode=1, win=$pnlName
	PopupMenu pathP value="_Use Dialog_;_Specify Path_;"+PathList("*",";",""), proc=SIDAMSaveCommon#pnlPopup, win=$pnlName
	CheckBox overwriteC title="Force Overwrite", pos={216,307}, win=$pnlName
	SetVariable pathV pos={10,330}, size={370,15}, bodyWidth=370, value=_STR:"", format="", frame=0, noedit=1, labelBack=(56797,56797,56797), win=$pnlName
	
	//	button
	Button saveB title="Save", pos={4,363}, size={70,20}, proc=SIDAMSaveCommon#pnlButton, userData(fn)="SIDAMSaveGraphics#saveGraphics", win=$pnlName
	Button closeB title="Close", pos={315,363}, size={70,20}, proc=SIDAMSaveCommon#pnlButton, win=$pnlName
	
	ModifyControlList FORMAT_DEPENDENT_CTRL, disable=1, win=$pnlName
	ModifyControlList ControlNameList(pnlName,";","format_*_rC"), proc=SIDAMSaveGraphics#pnlCheckFormat, win=$pnlName
	ModifyControlList ControlNameList(pnlName,";","*_rC") mode=1, win=$pnlName
	ModifyControlList ControlNameList(pnlName,";","*") focusRing=0, win=$pnlName

	SetActiveSubwindow $grfName
End

//******************************************************************************
//	Controls
//******************************************************************************
//-------------------------------------------------------------
//	Checkbox for format
//-------------------------------------------------------------
Static Function pnlCheckFormat(STRUCT WMCheckboxAction &s)
	if (s.eventCode != 2)
		return 0
	endif
	
	int i, n
	
	// Make all checkboxes except the selected one zero
	String list = RemoveFromList(s.ctrlName, ControlNameList(s.win,";","format_*_rC"))
	for (i = 0, n = ItemsInList(list); i < n; i++)
		CheckBox $StringFromList(i,list) value=0, win=$s.win
	endfor
	
	//	Change the disable state of controls
	for (i = 0, n = ItemsInList(FORMAT_DEPENDENT_CTRL); i < n; i++)
		String format = StringFromList(1,s.ctrlName,"_")
		String ctrl = StringFromList(i,FORMAT_DEPENDENT_CTRL)
		int disable = (WhichListItem(format,GetUserData(s.win,ctrl,"format")) == -1)
		ModifyControl $ctrl disable=disable, win=$s.win
	endfor
	
	//	if embedC is displayed and checked, display exceptC
	ControlInfo/W=$s.win embedC
	CheckBox exceptC disable=(V_disable || !V_Value), win=$s.win
	
	//	if resolutionP is displayed and "Other DPI" is selected, display dpiP
	ControlInfo/W=$s.win resolutionP
	PopupMenu dpiP disable=(V_disable || V_Value!=6), win=$s.win
	
	return 0
End

//******************************************************************************
//	function invoked by pressing "Save" button
//******************************************************************************
Static Function saveGraphics(String pnlName)
	String parentWin = StringFromList(0, pnlName, "#")
	Wave w = SIDAMImageWaveRef(parentWin)
	
	//	collect information from the panel
	String cmdExtStr = createCmdExtStr(pnlName)
	
	//	lw[0]: start layer, lw[1]: end layer, lw[2]: present layer
	Wave lw = SIDAMSaveCommon#getLayers(pnlName)
		
	ControlInfo/W=$pnlName filenameV
	String basename = S_value
	ControlInfo/W=$pnlName suffixP
	int suffix = V_value

	String cmdStr = StringFromList(0,cmdExtStr)
	String extStr = StringFromList(1,cmdExtStr)
	String digitStr = "%0" + num2istr(floor(log(lw[1]))+1) + "d"	//	%01d for 0-9, %02d for 10-99,...
	String cmd
	int i
	
	//	Save graphics
	DoWindow/F $parentWin
	for (i = lw[0]; i <= lw[1]; i++)
		if (suffix == 1)			//	index only
			sprintf cmd, "%s as \"%s"+digitStr+"%s\"", cmdStr, basename, i, extStr
		elseif (suffix == 2)	//	value only
			sprintf cmd, "%s as \"%s%g%s\"", cmdStr, basename, SIDAMIndexToScale(w,i,2), extStr
		else						//	index and value
			sprintf cmd, "%s as \"%s"+digitStr+"_%g%s\"", cmdStr, basename, i, SIDAMIndexToScale(w,i,2), extStr
		endif
		ModifyImage/W=$parentWin $NameOfWave(w) plane=i
		DoUpdate/W=$parentWin
		#ifdef DEBUG
			print cmd
		#else
			Execute/Z cmd
		#endif
	endfor
	
	SIDAMSetLayerIndex(parentWin, lw[2])
End
//-------------------------------------------------------------
//	return the command string and the extension created from
//	the items chosen in the panel
//-------------------------------------------------------------
Static Function/S createCmdExtStr(String pnlName)
	
	String cmdStr = "SavePICT"
	
	//	overwrite
	ControlInfo/W=$pnlName overwriteC
	cmdStr += SelectString(V_Value, "", "/O")	//	checked
	
	//	format
	String ctrlList = ControlNameList(pnlName,";","format_*_rC")
	Wave cw = SIDAMGetCtrlValues(pnlName, ctrlList)
	cw *= p
	String selectedCheckbox = StringFromList(sum(cw),ctrlList)
	cmdStr += "/E=" + GetUserData(pnlName,selectedCheckbox,"value")
	String extStr = "." + LowerStr(StringFromList(1,selectedCheckBox,"_"))
	
	//	color
	ControlInfo/W=$pnlName colorC
	if (V_Value)
		ControlInfo/W=$pnlName cmyk_rC
		cmdStr += SelectString(V_disable!=1 && V_Value, "", "/C=2")	//	displayed and checked
	else
		cmdStr += "/C=0"
	endif
	
	//	font of eps
	ControlInfo/W=$pnlName dontembedC
	cmdStr += SelectString(V_disable!=1 && V_Value, "", "/EF=1")		//	displayed and checked
	
	//	font of pdf
	ControlInfo/W=$pnlName exceptC
	if (V_disable!=1 && V_Value)		//	displayed and checked
		cmdStr += "/EF=1"
	else
		ControlInfo/W=$pnlName embedC
		cmdStr += SelectString(V_disable!=1 && V_Value, "", "/EF=2")	//	displayed and checked
	endif
	
	//	get path
	ControlInfo/W=$pnlName pathP
	if (V_Value > 2)			//	a path is chosen
		cmdStr += "/P="+S_Value
	elseif (V_Value == 2)	// _Specify Path_
		ControlInfo/W=$pnlName pathV
		if (strlen(S_value))
			GetFileFolderInfo/Q/Z S_value
			if (!V_Flag)	//	file or folder was found.
				cmdStr += "/P="+SIDAMSaveCommon#getPathName(StringFromList(1,pnlName,"#"))
			endif
		endif
	endif
	
	//	resolution
	ControlInfo/W=$pnlName dpiP
	if (V_disable!=1) 		//	displayed
		cmdStr += "/RES="+S_Value
	else
		ControlInfo/W=$pnlName resolutionP
		if (V_disable!=1) 	//	displayed
			cmdStr += "/B="+StringFromList(V_Value-1,GetUserData(pnlName,"resolutionP","value"))
		endif
	endif
	
	//	transparent
	ControlInfo/W=$pnlName tranC
	cmdStr += SelectString(V_disable!=1 && V_Value, "", "/TRAN=1")	//	displayed and checked
	
	return cmdStr + ";" + extStr
End
