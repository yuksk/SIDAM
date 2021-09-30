#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3	
#pragma ModuleName=SIDAMSaveMovie

#include "SIDAM_Help"
#include "SIDAM_SaveCommon"
#include "SIDAM_Utilities_Control"
#include "SIDAM_Utilities_Image"

#ifndef SIDAMshowProc
#pragma hide = 1
#endif


Static Function/S menuItem()
	Wave/Z w = SIDAMImageNameToWaveRef(WinName(0,1))
	if (!WaveExists(w))
		return ""
	endif
	int is3D = WaveDims(w)==3
	int isWindows = stringmatch(IgorInfo(2),"Windows")	
	return SelectString(isWindows && is3D, "", "\\M0Save Graphics (Movie)...")
End

Static Function menuDo()
	pnl(WinName(0,1))
End

//******************************************************************************
//	Display panel
//******************************************************************************
Static Function pnl(String grfName)
	NewPanel/HOST=$grfName/EXT=0/W=(0,0,320,270)
	RenameWindow $grfName#$S_name, SaveMovie
	String pnlName = grfName + "#SaveMovie"
	Wave w = SIDAMImageNameToWaveRef(grfName)
	
	//	layer
	GroupBox layerG title="Layer", pos={5,4}, size={310,50}, win=$pnlName
	CheckBox all_rC title="all", pos={16,28}, value=1, win=$pnlName
	CheckBox select_rC title="", pos={78,28}, value=0, win=$pnlName
	SetVariable from_f_V title="from:", pos={97,26}, size={79,15}, value=_NUM:0, win=$pnlName
	SetVariable to_f_V title="to:", pos={186,26}, size={66,15}, value=_NUM:DimSize(w,2)-1, win=$pnlName
	ModifyControlList "all_rc;select_rC" mode=1, proc=SIDAMSaveCommon#pnlCheck, win=$pnlName
	ModifyControlList "from_f_V;to_f_V" bodyWidth=50, limits={0,DimSize(w,2)-1,1}, format="%d", proc=SIDAMSaveCommon#pnlSetVar, win=$pnlName
	
	//	parameters
	GroupBox formatG title="Parameters:", pos={5,60}, size={310,75}, win=$pnlName
	int isWindows = strsearch(IgorInfo(2), "Windows", 0, 2) >= 0
	String codecList = "mp4;"+SelectString(isWindows,"","wmv")
	PopupMenu codecP title="Compression codec:", pos={16,81}, size={169,19}, bodywidth=60, win=$pnlName
	PopupMenu codecP value=#("\""+codecList+"\""), win=$pnlName
	SetVariable factorV title="factor:", pos={198,81}, size={98,18}, win=$pnlName
	SetVariable factorV value=_NUM:200, bodyWidth=60, win=$pnlName
	SetVariable rateV title="Frames per second", pos={18,107}, size={151,15}, win=$pnlName
	SetVariable rateV bodyWidth=50, value=_NUM:2, limits={1,60,1}, format="%d", win=$pnlName

	//	file
	GroupBox fileG title="File:", pos={5,141}, size={310,96}, win=$pnlName	
	SetVariable filenameV title="Filename:", pos={12,164}, size={295,18}, bodyWidth=241, win=$pnlName
	SetVariable filenameV value=_STR:NameOfWave(w), proc=SIDAMSaveCommon#pnlSetVar, win=$pnlName
	PopupMenu pathP title="Path:", pos={12,189}, size={180,20}, bodyWidth=150, mode=1, win=$pnlName
	PopupMenu pathP value="_Use Dialog_;_Specify Path_;"+PathList("*",";",""), proc=SIDAMSaveCommon#pnlPopup, win=$pnlName
	CheckBox overwriteC title="Force Overwrite", pos={206,191}, win=$pnlName	
	SetVariable pathV pos={10,215}, size={300,15}, bodyWidth=300, value=_STR:"", format="", frame=0, noedit=1, labelBack=(56797,56797,56797), win=$pnlName

	//	button
	Button saveB title="Save", pos={4,243}, userData(fn)="SIDAMSaveMovie#saveMovie", win=$pnlName
	Button closeB title="Close", pos={245,243}, win=$pnlName
	ModifyControlList "saveB;closeB", size={70,20}, proc=SIDAMSaveCommon#pnlButton, win=$pnlName
	
	ModifyControlList ControlNameList(pnlName,";","*") focusRing=0, win=$pnlName

	Make/T/N=(2,10)/FREE helpw
	helpw[][0] = {"all_rC", "Check to include all layers in the movie."}
	helpw[][1] = {"select_rC", "Check to specify a range of layers included in the movie."}
	helpw[][2] = {"from_f_V", "Enter the first index of layers included in the movie."}
	helpw[][3] = {"to_f_V", "Enter the last index of layers included in the movie."}
	helpw[][4] = {"codecP", "Select the compression codec to use."}
	helpw[][5] = {"factorV", "Enter a compression factor relative to the theoretical "\
		+ "uncompressed value. The default compression factor is 200."}
	helpw[][6] = {"rateV", "Enter a value of frames per second between 1 and 60."}
	helpw[][7] = {"filenameV", "Enter the name of movie file."}
	helpw[][8] = {"pathP", "Select a path where the movie file is saved."}
	helpw[][9] = {"overwriteC", "Check to overwrite the movie file if already exists."}
	SIDAMApplyHelpStringsWave(pnlName, helpw)
	
	SetActiveSubwindow $grfName
End

//******************************************************************************
//	function invoked by pressing "Save" button
//******************************************************************************
Static Function saveMovie(String pnlName)

	//	get name of file
	ControlInfo/W=$pnlName filenameV
	String fileName = S_Value, extStr
	ControlInfo/W=$pnlName codecP
	extStr = "."+S_value
	fileName = RemoveEnding(fileName, extStr) + extStr
		
	//	Execute NewMovie with flags specified in the panel
	String cmd
	sprintf cmd, "%s as \"%s\"", createCmdStr(pnlName), fileName
	Execute/P/Q cmd
		
	//	Add movie frames
	//	lw[0]: start layer, lw[1]: end layer, lw[2]: present layer
	// The following commands need to be put into the queue so that each layer
	// is saved after any modifications such as adjusting the z range. This is
	// required in Igor 9 where modified events are sent to a window only when
	// Igor's main outer loop runs. DoUpdate is necessary for Igor 8.
	Wave lw = SIDAMSaveCommon#getLayers(pnlName)
	String grfName = StringFromList(0,pnlName,"#")
	int i
	for (i = lw[0]; i <= lw[1]; i++)
		sprintf cmd, "SIDAMSetLayerIndex(\"%s\", %d);DoUpdate/W=%s", grfName, i, grfName
		Execute/P/Q cmd
		Execute/P/Q "AddMovieFrame"
	endfor
	
	Execute/P/Q "CloseMovie"
	sprintf cmd, "SIDAMSetLayerIndex(\"%s\", %d)", grfName, lw[2]
	Execute/P/Q cmd
End
//-------------------------------------------------------------
//	return the command string from the items chosen in the panel
//-------------------------------------------------------------
Static Function/S createCmdStr(String pnlName)

	String cmdStr = "NewMovie"
	
	Wave cw = SIDAMGetCtrlValues(pnlName,"overwriteC;rateV")
	cmdStr += SelectString(cw[0], "", "/O")
	cmdStr += "/F="+num2istr(cw[1])
	
	ControlInfo/W=$pnlname codecP
	cmdStr += "/CTYP=\""+StringFromList(V_Value-1,"mp4v;WMV3")+"\""
	ControlInfo/W=$pnlName factorV
	if (V_Value != 200)
		cmdStr += "/CF="+num2str(V_Value)
	endif
	
	//	get path
	ControlInfo/W=$pnlName pathP
	if (V_Value == 1)		// _Use Dialog_
		return cmdStr
	elseif (V_Value > 2)	//	a path is chosen
		return cmdStr + "/P="+S_Value
	endif
	
	// _Specify Path_
	ControlInfo/W=$pnlName pathV
	if (!strlen(S_value))
		return cmdStr
	endif

	GetFileFolderInfo/Q/Z S_value
	if (!V_Flag) 	//	file or folder was found
		cmdStr += "/P="+SIDAMSaveCommon#getPathName(StringFromList(1,pnlName,"#"))
	endif
	
	return cmdStr
End
