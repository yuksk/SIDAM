#pragma TextEncoding = "UTF-8"
#pragma rtGlobals = 3
#pragma ModuleName = SIDAMRange

#include "SIDAM_Histogram"
#include "SIDAM_Utilities_Control"
#include "SIDAM_Utilities_Image"
#include "SIDAM_Utilities_ImageInfo"
#include "SIDAM_Utilities_Panel"
#include "SIDAM_Utilities_WaveDf"

#ifndef SIDAMshowProc
#pragma hide = 1
#endif

#include <WMImageInfo>

//@
//	Set a range of a color scale used for a image(s)
//
//	Parameters
//	----------
//	grfName : string, default ``WinName(0,1,1)``
//		The name of window.
//	imgList : string, default ``ImageNameList(grfName,";")``
//		The list of images.
//	zminmode : int, default 1
//		The z mode for min.
//
//			0. auto
//			1. fix
//			2. sigma
//			3. cut
//			4. logsigma
//
//	zmaxmode : int, default 1
//		The z mode for max. The numbers are the same as those for the zminmode.
//	zmin : variable
//		The minimum value of the range.
//		When the zmaxmode is 2 or 3, this is a parameter of the mode.
//	zmax : variable
//		The maximum value of the range.
//		When the zminmode is 2 or 3, this is a parameter of the mode.
//@
Function SIDAMRange([String grfName, String imgList, Variable zmin,
	Variable zmax, int zminmode, int zmaxmode])

	STRUCT paramStruct s
	s.grfName = SelectString(ParamIsDefault(grfName), grfName, WinName(0,1,1))
	s.imgList = SelectString(ParamIsDefault(imgList), imgList, ImageNameList(s.grfName,";"))
	s.zmin = ParamIsDefault(zmin) ? inf : zmin
	s.zmax = ParamIsDefault(zmax) ? inf : zmax
	s.zminmode = ParamIsDefault(zminmode) ? 1 : zminmode
	s.zmaxmode = ParamIsDefault(zmaxmode) ? 1 : zmaxmode

	if (validate(s))
		print s.errMsg
		return 1
	elseif (ParamIsDefault(zmin) && ParamIsDefault(zmax))
		pnl(s.grfName)
		return 0
	endif

	setZmodeValue(s.grfName, s.imgList, "m0", s.zminmode)
	setZmodeValue(s.grfName, s.imgList, "v0", s.zmin)
	setZmodeValue(s.grfName, s.imgList, "m1", s.zmaxmode)
	setZmodeValue(s.grfName, s.imgList, "v1", s.zmax)
	updateZRange(s.grfName)

	if (s.zminmode >= 2 || s.zmaxmode >= 2)
		SetWindow $s.grfName hook(SIDAMRange)=SIDAMRange#pnlHookParent
	endif

	if (canZmodeBeDeleted(s.grfName))
		deleteZmodeValues(s.grfName)
		SetWindow $s.grfName hook(SIDAMRange)=$""
	endif
End

Static Function validate(STRUCT paramStruct &s)

	s.errMsg = PRESTR_CAUTION + "SIDAMRange gave error: "

	if (!strlen(s.grfName))
		s.errMsg += "graph not found."
		return 1
	elseif (!SIDAMWindowExists(s.grfName))
		s.errMsg += "an window named \"" + s.grfName + "\" is not found."
		return 1
	elseif (!strlen(ImageNameList(s.grfName,";")))
		s.errMsg += s.grfName + " has no image."
		return 1
	endif

	String list = ImageNameList(s.grfName,";")
	int i, n
	for (i = 0, n = ItemsInList(s.imgList); i < n; i++)
		if (WhichListItem(StringFromList(i,s.imgList),list) < 0)
			s.errMsg += "an image named \"" + StringFromList(i,s.imgList) + "\" is not found."
			return 1
		endif
	endfor

	if (numtype(s.zmin) == 1 && numtype(s.zmax) != 1)
		s.errMsg += "zmin must be given."
		return 1
	endif

	if (numtype(s.zmax) == 1 && numtype(s.zmin) != 1)
		s.errMsg += "zmax must be given."
		return 1
	endif

	if (s.zminmode < 0 || s.zminmode > 4)
		s.errMsg += "zminmode must be an integer between 0 and 4."
		return 1
	endif

	if (s.zmaxmode < 0 || s.zmaxmode > 4)
		s.errMsg += "zmaxmode must be an integer between 0 and 4."
		return 1
	endif

	return 0
End

Static Structure paramStruct
	String	grfName
	String	imgList
	Variable zmin
	Variable zmax
	uchar zminmode
	uchar zmaxmode
	String	errMsg
EndStructure

//******************************************************************************
//	Set first z and last z to an image
//	"auto" if zmin=NaN or zmax=NaN
//******************************************************************************
Static Function applyZRange(String grfName, String imgName, Variable zmin, Variable zmax)

	String ctab = SIDAM_ColorTableForImage(grfName, imgName)
	Variable rev = WM_ColorTableReversed(grfName, imgName)
	if (numtype(zmin)==2 && numtype(zmax)==2)
		ModifyImage/W=$grfName $imgName ctab={*,*,$ctab,rev}
	elseif (numtype(zmin)==2)
		ModifyImage/W=$grfName $imgName ctab={*,zmax,$ctab,rev}
	elseif (numtype(zmax)==2)
		ModifyImage/W=$grfName $imgName ctab={zmin,*,$ctab,rev}
	else
		ModifyImage/W=$grfName $imgName ctab={zmin,zmax,$ctab,rev}
	endif
	DoUpdate/W=$grfName
End

//-------------------------------------------------------------
//	Menu functions
//-------------------------------------------------------------
Static Function/S menu(int mode)	//	mode 2: sigma, 3, cut

	String grfName = WinName(0,1)
	String menuStr = "3\u03c3;0.5%", checkmark = "!"+num2char(18)
	return SelectString(isAllImagesInMode(grfName, mode), "",checkmark) + StringFromList(mode-2,menuStr)
End

Static Function menuDo(int mode)	//	mode 2: sigma, 3, cut

	String grfName = WinName(0,1)

	if (isAllImagesInMode(grfName, mode))
		//	If already in the mode, unset it.
		deleteZmodeValues(grfName)
		SetWindow $grfName hook(SIDAMRange)=$""

	elseif (mode==2)
		SIDAMRange(imgList=ImageNameList("",";"),zminmode=2,zmin=-3,zmaxmode=2,zmax=3)

	elseif (mode==3)
		SIDAMRange(imgList=ImageNameList("",";"),zminmode=3,zmin=0.5,zmaxmode=3,zmax=99.5)
	endif
End

//	Return 1 if all the images are in the mode of "3sigma" or "0.5%"
Static Function isAllImagesInMode(String grfName, int mode)	//	mode 2: sigma, 3, cut

	String imgList = ImageNameList(grfName,";"), imgName
	Variable m0, m1, v0, v1
	int i

	for (i = 0; i < ItemsInList(imgList); i++)
		imgName = StringFromList(i,imgList)
		m0 = getZmodeValue(grfName, imgName, "m0")
		m1 = getZmodeValue(grfName, imgName, "m1")
		if (m0!=mode || m1!=mode)
			return 0
		endif
		//	In the following, m0=m1=2 or m0=m1=3
		//	SIDAM_GetColorTableMinMax may cause slowing down for complex waves.
		//	To avoid this, m0 and m1 are checked above.
		v0 = getZmodeValue(grfName, imgName, "v0")
		v1 = getZmodeValue(grfName, imgName, "v1")
		if (mode==2 && !(v0==-3 && v1==3))
			return 0
		elseif (mode==3 && !(v0==0.5 && v1==99.5))
			return 0
		endif

	endfor

	return 1
End


//==============================================================================
//	Panel
//==============================================================================
Static Constant CTRLHEIGHT = 175
Static Constant BOTTOMHEIGHT = 30
Static Constant PNLHEIGHT = 335
Static Constant PNLWIDTH = 262

Static Constant BINS = 48		//	Number of bins of a histogram
Static StrConstant HIST = "SIDAMRange_hist"			//	Name of a histogram wave
Static StrConstant HISTCLR = "SIDAMRange_histclr"	//	Name of a color histogram wave

Static Function pnl(String grfName)

	if (SIDAMWindowExists(grfName+"#Range"))
		return 0
	endif

	//	Acquire the z range of the top image
	String imgName = StringFromList(0,ImageNameList(grfName,";"))
	Variable zmin, zmax
	SIDAM_GetColorTableMinMax(grfName, imgName, zmin, zmax)

	String dfTmp = pnlInit(grfName, imgName, zmin, zmax)

	NewPanel/EXT=0/HOST=$StringFromList(0, grfName, "#")/W=(0,0,PNLWIDTH,PNLHEIGHT)/N=Range
	String pnlName = StringFromList(0, grfName, "#") + "#Range"

	//	Controls
	PopupMenu imageP title="image",pos={3,7},size={218,19},bodyWidth=180,win=$pnlName
	CheckBox allC title="all",pos={233,9},proc=SIDAMRange#pnlCheck,win=$pnlName

	GroupBox zminG pos={4,30},size={128,141},title="first Z",fColor=(65280,32768,32768),win=$pnlName

	CheckBox zminC      pos={9,53}, title="", win=$pnlName
	CheckBox zminAutoC  pos={9,76}, title="auto", win=$pnlName
	CheckBox zminSigmaC pos={9,99}, title="\u03bc +", win=$pnlName
	CheckBox zminCutC   pos={9,122},title="cut", win=$pnlName
	CheckBox zminLogsigmaC   pos={9,145}, title="log", win=$pnlName
	
	SetVariable zminV      pos={27,51},format="%g",win=$pnlName
	SetVariable zminSigmaV pos={47,98},value=_NUM:-3,limits={-inf,inf,0.1},win=$pnlName
	SetVariable zminCutV   pos={47,121},value=_NUM:0.5,limits={0,100,0.1},win=$pnlName
	SetVariable zminLogsigmaV pos={47,144},value=_NUM:-3,limits={-inf,inf,0.1},win=$pnlName

	TitleBox zminSigmaT pos={111,99}, title="\u03c3",win=$pnlName
	TitleBox zminCutT   pos={111,122},title="%",win=$pnlName
	TitleBox zminLogigmaT pos={111,145}, title="\u03c3",win=$pnlName

	GroupBox zmaxG pos={134,30},size={128,141},title="last Z",fColor=(32768,40704,65280),win=$pnlName

	CheckBox zmaxC      pos={139,53}, title="", win=$pnlName
	CheckBox zmaxAutoC  pos={139,76}, title="auto",win=$pnlName
	CheckBox zmaxSigmaC pos={139,99}, title="\u03bc +",win=$pnlName
	CheckBox zmaxCutC   pos={139,122}, title="cut", win=$pnlName
	CheckBox zmaxLogsigmaC   pos={139,145}, title="log", win=$pnlName

	SetVariable zmaxV      pos={157,51},format="%g",win=$pnlName
	SetVariable zmaxSigmaV pos={177,98},value=_NUM:3,limits={-inf,inf,0.1},win=$pnlName
	SetVariable zmaxCutV   pos={177,121},value=_NUM:99.5,limits={0,100,0.1},win=$pnlName
	SetVariable zmaxLogsigmaV pos={177,144},value=_NUM:3,limits={-inf,inf,0.1},win=$pnlName

	TitleBox zmaxSigmaT pos={241,99},title="\u03c3",win=$pnlName
	TitleBox zmaxCutT   pos={241,122},title="%",win=$pnlName
	TitleBox zmaxLogigmaT pos={241,145},title="\u03c3",win=$pnlName

	PopupMenu adjustP pos={5,312}, size={75,19}, bodyWidth=75, win=$pnlName
	PopupMenu adjustP mode=0, value="present z;full z", win=$pnlName
	PopupMenu adjustP title="histogram", proc=SIDAMRange#pnlPopup, win=$pnlName
	Button doB pos={118,312}, title="Do It", win=$pnlName
	Button cancelB pos={195,312}, title="Cancel", win=$pnlName

	ModifyControlList ControlNameList(pnlName,";","zm*C") mode=1, proc=SIDAMRange#pnlCheck, win=$pnlName
	ModifyControlList ControlNameList(pnlName,";","zm*V") size={60,18}, bodyWidth=60, proc=SIDAMRange#pnlSetVar, win=$pnlName
	ModifyControlList "zminV;zmaxV" size={100,18}, bodyWidth=100, win=$pnlName
	ModifyControlList ControlNameList(pnlName,";","*T") frame=0,win=$pnlName
	ModifyControlList ControlNameList(pnlName,";","*B") size={65,20},proc=SIDAMRange#pnlButton,win=$pnlName
	ModifyControlList ControlNameList(pnlName,";","*") focusRing=0, win=$pnlName

	//	Histogram
	DefineGuide/W=$pnlName SIDAMFT={FT, CTRLHEIGHT}
	DefineGuide/W=$pnlName SIDAMFB={FB, -BOTTOMHEIGHT}
	Display/FG=(FL,SIDAMFT,FR,SIDAMFB)/HOST=$pnlName
	String subGrfName = pnlName + "#" + S_name

	AppendToGraph/W=$subGrfName $(dfTmp+HIST)	//	One is for the color
	AppendToGraph/W=$subGrfName $(dfTmp+HIST)	//	The other is for the outline
	Cursor/C=(65280,32768,32768)/F/H=2/N=1/S=2/T=2/W=$subGrfName I $HIST zmin, 0
	Cursor/C=(32768,40704,65280)/F/H=2/N=1/S=2/T=2/W=$subGrfName J $HIST zmax, 0

	ModifyGraph/W=$subGrfName margin(top)=8, margin(right)=12, margin(bottom)=32, margin(left)=40, gfSize=12
	ModifyGraph/W=$subGrfName tick=2, btlen=5, mirror=1, lblMargin=0, prescaleExp(left)=2
	ModifyGraph/W=$subGrfName mode=6, lstyle=1, rgb=(0,0,0)
	Label/W=$subGrfName bottom "z (\u\M)"
	Label/W=$subGrfName left "Probability (\u#2%)"
	SetActiveSubwindow ##

	//	Hook functions
	//	These must come after displaying the cursors because the hook function gives an error
	//	if the cursors are not shown
	SetWindow $grfName hook(SIDAMRange)=SIDAMRange#pnlHookParent
	SetWindow $pnlName hook(self)=SIDAMRange#pnlHook
	SetWindow $pnlName userData(grf)=grfName
	SetWindow $pnlName userData(dfTmp)=dfTmp
	SetWindow $pnlName userData(subGrfName)=subGrfName, activeChildFrame=0

	//	Save the initial z mode information to revert
	initializeZmodeValue(grfName)
	SetWindow $pnlName userData($MODEKEY)=GetUserData(grfName,"",MODEKEY)

	//	Items which must be here at the last after all things are done.
	PopupMenu imageP proc=SIDAMRange#pnlPopup,value=#"SIDAMRange#imageListForImageP()",win=$pnlName
	resetPnlCtrls(pnlName)
	
	SetActiveSubwindow $grfName
End

Static Function/S pnlInit(String grfName, String imgName, Variable zmin, Variable zmax)

	String dfTmp = SIDAMNewDF(StringFromList(0, grfName, "#"),"Range")
	Wave w = SIDAMImageWaveRef(grfName, imgName=imgName, displayed=1)
	Duplicate SIDAMHistogram(w, startz=zmin-(zmax-zmin)*0.05, endz=zmax+(zmax-zmin)*0.05, \
		bins=BINS) $(dfTmp+HIST)/WAVE=hw
	Duplicate hw $(dfTmp+HISTCLR)/WAVE=rangew
	rangew = x

	return dfTmp
End

//******************************************************************************
//	Hook functions
//******************************************************************************
//-------------------------------------------------------------
//	Hook function for the parent window
//
//	This is the function adjusting the range when a graph is
//	modified like changing the axis range or the layer.
//	This function works when
//	(1) the z range is changed from the Igor default dialog
//	(2) the layer of a 3D wave is changed
//	(3) the wave of an image is changed
//	(4) an image is removed
//-------------------------------------------------------------
Static Function pnlHookParent(STRUCT WMWinHookStruct &s)

	if (s.eventCode != 8)	//	modified only
		return 0
	endif

	//	When the z range is changed from the panel, this function should not work.
	//	Actually, to prevent this function from working, an userdata "pauseHook"
	//	is set when the z range is changed from the panel. In this case, delete
	//	the userdata and finish.
	if (strlen(GetUserData(s.winName, "", "pauseHook")))
		SetWindow $s.winName userData(pauseHook)=""
		return 0
	endif

	String imgList = ImageNameList(s.winName,";"), imgName
	Variable recorded, present
	int i

	for (i = 0; i < ItemsInList(imgList); i++)
		imgName = StringFromList(i,imgList)

		//	(1) Check if the z range is changed from the Igor default dialog.
		//		If changed, update the z mode values to reflect the present status.
		pnlHookParentIgorDialog(s.winName, imgName)

		//	(2) Check if the layer is changed.
		//		If changed, update the z mode value to reflect the present layer
		pnlHookParentLayerChanged(s.winName, imgName)

		//	(3) Check if the wave is changed.
		//		If changed, update the z mode value to reflect the present modtime
		pnlHookParentWaveModified(s.winName, imgName)
	endfor

	//	(4) in case a image(s) is removed. If no image has been removed, do nothing.
	cleanZmodeValue(s.winName)

	updateZRange(s.winName, pause=1)

	//	When the panel is shown, reflect the present z mode values to the panel.
	//	(If not shown, do nothing)
	int isPanelShown = pnlHookParentUpdatePanel(s.winName)

	//	When the panel is not shown, check the z mode values.
	//	If they are 0 or 1 for all images, this hook function is no longer necessary.
	if(!isPanelShown && canZmodeBeDeleted(s.winName))
		deleteZmodeValues(s.winName)
		SetWindow $s.winName hook(SIDAMRange)=$""
	endif

	SetWindow $s.winName userData(pauseHook)=""
	return 0
End

Static Function pnlHookParentIgorDialog(String grfName, String imgName)

	//	Recorded z range
	Variable z0 = getZmodeValue(grfName, imgName, "z0")
	Variable z1 = getZmodeValue(grfName, imgName, "z1")

	//	Present z range
	Variable zmin, zmax
	SIDAM_GetColorTableMinMax(grfName, imgName, zmin, zmax)

	//	If "auto" is different, or the values are different,
	//	the z range has been modified from the Igor default dialog
	int isRecFirstAuto = getZmodeValue(grfName, imgName, "m0")==0
	int isRecLastAuto  = getZmodeValue(grfName, imgName, "m1")==0
	int isFirstAuto = isZAuto(grfname,imgName,0)
	int isLastAuto = isZAuto(grfname,imgName,1)
	int needUpdateFirst = (isRecFirstAuto %^ isFirstAuto) || (abs(zmin-z0) > 1e-13)
	int needUpdateLast  = (isRecLastAuto  %^ isLastAuto)  || (abs(zmax-z1) > 1e-13)

	if (needUpdateFirst)
		setZmodeValue(grfName, imgName, "m0", !isFirstAuto)
		setZmodeValue(grfName, imgName, "z0", zmin)
	endif

	if (needUpdateLast)
		setZmodeValue(grfName, imgName, "m1", !isLastAuto)
		setZmodeValue(grfName, imgName, "z1", zmax)
	endif

	return (needUpdateFirst || needUpdateLast)
End

//	Return if the z range is auto or not
//	minormax 0 for min, 1 for max
Static Function isZAuto(String grfName, String imgName, int minormax)
	String ctabInfo = WM_ImageColorTabInfo(grfName,imgName)
	return strlen(ctabInfo) ? Stringmatch("*", StringFromList(minormax,ctabInfo,",")) : 0
End

Static Function pnlHookParentLayerChanged(String grfName, String imgName)

	Variable recorded = getZmodeValue(grfName, imgName, "layer")	//	nan for no record
	Variable present = SIDAMGetLayerIndex(grfName)					//	non for 2D
	if (!numtype(present) && recorded!=present)
		setZmodeValue(grfName, imgName, "layer", present)
		return 1
	else
		return 0
	endif
End

Static Function pnlHookParentWaveModified(String grfName, String imgName)
	Variable recorded = getZmodeValue(grfName, imgName, "modtime")		//	non for no record
	Variable present = NumberByKey("MODTIME",WaveInfo(ImageNameToWaveRef(grfName,imgName),0))
	if (recorded != present)
		setZmodeValue(grfName, imgName, "modtime", present)
		return 1
	else
		return 0
	endif
End

Static Function pnlHookParentUpdatePanel(String grfName)

	String pnlName = grfName + "#Range"
	if (!SIDAMWindowExists(pnlName))
		return 0
	endif

	//	If the wave selected in the panel is removed from the graph,
	//	select a new wave in the popupmenu.
	ControlInfo/W=$pnlName imageP
	Wave/Z w = SIDAMImageWaveRef(grfName, imgName=S_Value)
	if (!WaveExists(w))
		PopupMenu imageP value=#"SIDAMRange#imageListForImageP()", mode=1, win=$pnlName
	endif

	//	If only one image is shown in the graph, allC is unnecessary.
	if (ItemsInList(ImageNameList(grfName,";")) < 2)
		CheckBox allC value=0, disable=1, win=$pnlName
	endif

	updatePnlHistogram(pnlName, 0)
	resetPnlCtrls(pnlName)

	return 1
End

//----------------------------------------------------------------------
//	Hook function for the panel
//----------------------------------------------------------------------
Static Function pnlHook(STRUCT WMWinHookStruct &s)

	switch (s.eventCode)

		case 2:	//	kill
		case 14:	//	subwindowKill
			pnlHookClose(s.winName)
			break

		case 3:	//	mousedown
			//	suppress any click in the panel except dragging the cursors
			return 1

		case 7:	//	cursor moved
			//	This is supposed to work when a cursor is moved by a user,
			//	and not to work when a cursor is moved by a certain function.
			int hasCallingFunction = strlen(GetRTStackInfo(2)) != 0
			if (!hasCallingFunction)
				pnlHookCursor(s)		//	s.winName = Graph0#Range#G0
			endif
			break

		case 11:	//	keyboard
			if (s.keycode == 27)		//	27: esc
				pnlHookClose(s.winName)
				KillWindow $s.winName
			endif
			break

	endswitch
	return 0
End

//	Behavior when the panel is closed
Static Function pnlHookClose(String pnlName)

	String grfName = StringFromList(0, pnlName, "#")
	if (SIDAMWindowExists(grfName))
		if (!strlen(GetUserData(pnlName,"","norevert")))
			revertZmode(pnlName)
			updateZRange(grfName, pause=1)
		endif
	 	if (canZmodeBeDeleted(grfName))
			deleteZmodeValues(grfName)
			SetWindow $grfName hook(SIDAMRange)=$""
		endif
	endif

	SIDAMKillDataFolder($GetUserData(pnlName,"","dfTmp"))
End

//	Behavior when a cursor is moved by a user
Static Function pnlHookCursor(STRUCT WMWinHookStruct &s)

	//	Since the cursor value is given between 0 and 1. Therefore, the axis
	//	range is necessary to get an x value.
	String xAxis = StringByKey("XAXIS",TraceInfo(s.winName, s.traceName, 0))
	GetAxis/W=$s.winName/Q $xAxis
	Variable xmin = V_min, xmax = V_max
	Variable xvalue = xmin + (xmax-xmin)*s.pointNumber

	//	s.winName = Graph0#Range#G0
	//	pnlName = Graph0#Range
	String pnlName = RemoveEnding(ParseFilePath(1, s.winName, "#", 1, 0))

	String checkBoxName = StringByKey(s.cursorName, "I:zminC;J:zmaxC;")
	updatePnlRadioBox(pnlName, checkBoxName)

	//	The value of SetVariable is change, but pnlSetVar is NOT called here
	//	by this change
	String setVarName = StringByKey(s.cursorName, "I:zminV;J:zmaxV;")
	SetVariable $setVarName value=_NUM:xvalue, win=$pnlName

	updatePnlColor(pnlName)

	updateZmode(pnlName)
	updateZRange(GetUserData(pnlName,"","grf"), pause=1)
End

//******************************************************************************
//	Controls
//******************************************************************************
//	SetVariable
Static Function pnlSetVar(STRUCT WMSetVariableAction &s)

	//	Handle either mouse up, enter key, or begin edit
	if (!(s.eventCode == 1 || s.eventCode == 2 || s.eventCode == 7))
		return 1
	endif

	if (!CmpStr(s.ctrlName,"zminV") || !CmpStr(s.ctrlName,"zmaxV"))
		SetVariable $s.ctrlName limits={-inf,inf,10^(floor(log(abs(s.dval)))-1)}, win=$s.win
	endif

	String checkBoxName = (s.ctrlName)[0,strlen(s.ctrlName)-2]+"C"
	updatePnlRadioBox(s.win, checkBoxName)

	updateZmode(s.win)
	updateZRange(GetUserData(s.win,"","grf"), pause=1)

	updatePnlCursorsPos(s.win)
	updatePnlColor(s.win)
	updatePnlPresentValues(s.win)

	return 0
End

//	PopupMenu
Static Function pnlPopup(STRUCT WMPopupAction &s)

	if (s.eventCode != 2)
		return 0
	endif

	strswitch (s.ctrlName)
		case "imageP":
			//	The histogram has to be updated before the initilization.
			//	Otherwise, the cursor position may be wrong.
			updatePnlHistogram(s.win, 0)
			resetPnlCtrls(s.win)
			break

		case "adjustP":
			if (s.popNum == 1)		//	present
				updatePnlHistogram(s.win, 0)
			elseif (s.popNum == 2)	//	full
				updatePnlHistogram(s.win, 1)
			endif
			updatePnlCursorsPos(s.win)
			updatePnlColor(s.win)
			break

	endswitch
	return 0
End

//	Button
Static Function pnlButton(STRUCT WMButtonAction &s)

	if (s.eventCode != 2)
		return 0
	endif

	strswitch (s.ctrlName)
		case "doB":
			STRUCT paramStruct ps
			ps.grfName = GetUserData(s.win,"","grf")
			String zModeInfo = GetUserData(ps.grfName,"",MODEKEY)

			ControlInfo/W=$s.win allC
			if (V_Value)
				ps.imgList = ""
				String imgName = StringFromList(0, ImageNameList(ps.grfName,";"))
				ps.zminmode = getZmodeValue(ps.grfName, imgName, "m0")
				ps.zmaxmode = getZmodeValue(ps.grfName, imgName, "m1")
				ps.zmin = getZmodeValue(ps.grfName, imgName, "v0")
				ps.zmax = getZmodeValue(ps.grfName, imgName, "v1")
				printHistory(ps)
			else
				int i
				for (i = 0; i < ItemsInList(zModeInfo); i++)
					ps.imgList = StringFromList(0,StringFromList(i,zModeInfo),":")
					ps.zminmode = getZmodeValue(ps.grfName, ps.imgList, "m0")
					ps.zmaxmode = getZmodeValue(ps.grfName, ps.imgList, "m1")
					ps.zmin = getZmodeValue(ps.grfName, ps.imgList, "v0")
					ps.zmax = getZmodeValue(ps.grfName, ps.imgList, "v1")
					printHistory(ps)
				endfor
			endif

			SetWindow $s.win userData(norevert)="1"
			//*** FALLTHROUGH ***
		case "cancelB":
			KillWindow $s.win
			break

	endswitch
	return 0
End

//	Checkbox
Static Function pnlCheck(STRUCT WMCheckboxAction &s)

	if (s.eventCode != 2)
		return 0
	endif

	if (CmpStr(s.ctrlName,"allC"))
		updatePnlRadioBox(s.win, s.ctrlName)
	else
		Variable height = s.checked ? CTRLHEIGHT+BOTTOMHEIGHT : PNLHEIGHT
		Variable dy = (PNLHEIGHT-CTRLHEIGHT-BOTTOMHEIGHT) * (s.checked ? -1 : 1)
		MoveSubWindow/W=$s.win fnum=(0,0,PNLWIDTH,height)
		SetWindow $(s.win+"#G0") hide=s.checked
		ModifyControlList "doB;cancelB" pos+={0,dy}, win=$s.win
		ModifyControlList "imageP;adjustP" disable=(s.checked*2), win=$s.win
	endif

	updateZmode(s.win)
	updateZRange(GetUserData(s.win,"","grf"), pause=1)

	updatePnlCursorsPos(s.win)
	updatePnlColor(s.win)
	updatePnlPresentValues(s.win)

	return 0
End

//******************************************************************************
//	Helper functions of controls
//******************************************************************************
//	Menu contents of imageP
Static Function/S imageListForImageP()
	String pnlName = GetUserData(WinName(0,1)+"#Range","","grf")
	return ImageNameList(pnlName, ";")
End

Static Function revertZmode(String pnlName)

	String grfName = GetUserData(pnlName,"","grf")
	String initialZmode = GetUserData(pnlName,"",MODEKEY), valueStr
	String imgName
	int i

	for (i = 0; i < ItemsInList(initialZmode); i++)
		imgName = StringFromList(0,StringFromList(i,initialZmode),":")
		valueStr = StringFromList(1,StringFromList(i,initialZmode),":")
		setZmodeValue(grfName, imgName, "m0", NumberByKey("m0",valueStr,"=",","))
		setZmodeValue(grfName, imgName, "m1", NumberByKey("m1",valueStr,"=",","))
		setZmodeValue(grfName, imgName, "v0", NumberByKey("v0",valueStr,"=",","))
		setZmodeValue(grfName, imgName, "v1", NumberByKey("v1",valueStr,"=",","))
	endfor
End

//	Put the present z range to zminV and zmaxV
Static Function updatePnlPresentValues(String pnlName)

	String grfName = GetUserData(pnlName,"","grf")
	ControlInfo/W=$pnlName imageP
	Variable zmin, zmax
	SIDAM_GetColorTableMinMax(grfName, S_Value, zmin, zmax)
	SetVariable zminV value=_NUM:zmin,limits={-inf,inf,10^(floor(log(abs(zmin)))-1)}, win=$pnlName
	SetVariable zmaxV value=_NUM:zmax,limits={-inf,inf,10^(floor(log(abs(zmax)))-1)}, win=$pnlName
End

//	Reset the controls of the panel
//	This is called:
//		after the panel is created (pnl)
//		when a target wave is changed from the popupmenu (pnlPopup)
//		when the parent window is modified, e.g., displayed layer (pnlHookParent)
Static Function resetPnlCtrls(String pnlName)

	String grfName = GetUserData(pnlName,"","grf")
	ControlInfo/W=$pnlName imageP
	String imgName = S_Value

	updatePnlPresentValues(pnlName)

	//	Select ratioboxes corresonding to the selected Z mode
	int m0 = getZmodeValue(grfName, imgName, "m0")
	int m1 = getZmodeValue(grfName, imgName, "m1")
	updatePnlRadioBox(pnlName, StringFromList(m0,"zminAutoC;zminC;zminSigmaC;zminCutC;zminLogsigmaC"))
	updatePnlRadioBox(pnlName, StringFromList(m1,"zmaxAutoC;zmaxC;zmaxSigmaC;zmaxCutC;zmaxLogsigmaC"))

	//	If the Z mode is sigma or cut, put the value to the corresponding SetVariable
	if (m0 >= 2)
		Variable v0 = getZmodeValue(grfName, imgName, "v0")
		SetVariable $StringFromList(m0-2,"zminSigmaV;zminCutV;zminLogsigmaV") value=_NUM:v0, win=$pnlName
	endif

	if (m1 >= 2)
		Variable v1 = getZmodeValue(grfName, imgName, "v1")
		SetVariable $StringFromList(m1-2,"zmaxSigmaV;zmaxCutV;zmaxLogsigmaV") value=_NUM:v1, win=$pnlName
	endif

	DoUpdate/W=$pnlName		//	to ensure the modifications above are correctly reflected
	updatePnlCursorsPos(pnlName)
	updatePnlColor(pnlName)
End

//	Check the selected ratiobox and uncheck the others in the same group
Static Function updatePnlRadioBox(String pnlName, String ctrlName)

	String minOrMax = (ctrlName)[0,3]
	String ctrlList = ControlNameList(pnlName, ";", minOrMax+"*C")
	ctrlList = RemoveFromList(ctrlName, ctrlList)
	int i
	for (i = 0; i < ItemsInList(ctrlList); i++)
		CheckBox $StringFromList(i,ctrlList) value=0, win=$pnlName
	endfor
	CheckBox $ctrlName value=1, win=$pnlName
End

//	Update the cursor positions to reflect the present values of the range
Static Function updatePnlCursorsPos(String pnlName)

	String grfName = GetUserData(pnlName, "", "grf")
	String subGrfName = GetUserData(pnlName, "", "subGrfName")
	Variable zmin, zmax
	ControlInfo/W=$pnlName imageP
	SIDAM_GetColorTableMinMax(grfName, S_Value, zmin, zmax)

	Cursor/F/W=$subGrfName I $HIST zmin, 0
	Cursor/F/W=$subGrfName J $HIST zmax, 0
End

//	Update the color histogram to reflect the present values of the range
Static Function updatePnlColor(String pnlName)

	String grfName = GetUserData(pnlName, "", "grf")
	String subGrfName = GetUserData(pnlName, "", "subGrfName")

	ControlInfo/W=$pnlName imageP
	String imgName = S_Value
	Variable zmin, zmax
	SIDAM_GetColorTableMinMax(grfName, imgName, zmin, zmax)

	String dfTmp = GetUserData(pnlName, "", "dfTmp")
	Wave/SDFR=$dfTmp clrw = $HISTCLR
	int reversed = WM_ColorTableReversed(grfName,imgName)
	String tableName = SIDAM_ColorTableForImage(grfName,imgName)

	ModifyGraph/W=$subGrfName mode($HIST)=5, hbFill($HIST)=2
	ModifyGraph/W=$subGrfName zColorMax($HIST)=NaN, zColorMin($HIST)=NaN
	if (WaveExists($tableName))
		ModifyGraph/W=$subGrfName zColor($HIST)={clrw,zmin,zmax,ctableRGB,reversed,$tableName}
	else
		ModifyGraph/W=$subGrfName zColor($HIST)={clrw,zmin,zmax,$tableName,reversed}
	endif
End

//	Update the histogram wave shown in the panel
//	The mode determines the range of the histogram
//	mode 0: the range larger than the present one by 5%
//	mode 1: the range between the min and the max of the displayed area
Static Function updatePnlHistogram(String pnlName, int mode)

	ControlInfo/W=$pnlName imageP
	String imgName = S_Value
	String grfName = GetUserData(pnlName, "", "grf")
	Wave w = SIDAMImageWaveRef(grfName, imgName=imgName, displayed=1)

	Variable z0, z1, zmin, zmax
	if ( mode == 0 )
		SIDAM_GetColorTableMinMax(grfName, imgName, zmin, zmax)
		z0 = zmin - (zmax-zmin)*0.05
		z1 = zmax + (zmax-zmin)*0.05
	else
		z0 = WaveMin(w)
		z1 = WaveMax(w)
	endif

	DFREF dfrTmp = $GetUserData(pnlName, "", "dfTmp")
	Duplicate/O SIDAMHistogram(w, startz=z0, endz=z1, bins=BINS) dfrTmp:$HIST/WAVE=hw
	Duplicate/O hw dfrTmp:$HISTCLR/WAVE=clrw
	clrw = x

	DoUpdate/W=$pnlName
End

//	Update the Z mode values of the parent window based on
//	the selected values in the panel
Static Function updateZmode(String pnlName)

	//	z mode of first Z and last Z
	int m0, m1
	[m0, m1] = findSelectedMode(pnlName)

	//	z mode value of first Z, 0 for auto
	Wave minValuew = SIDAMGetCtrlValues(pnlName, "zminV;zminSigmaV;zminCutV;zminLogsigmaV")
	Variable v0 = m0 ? minValuew[m0-1] : 0

	//	z mode value of last Z, 0 for auto
	Wave maxValuew = SIDAMGetCtrlValues(pnlName, "zmaxV;zmaxSigmaV;zmaxCutV;zmaxLogsigmaV")
	Variable v1 = m1 ? maxValuew[m1-1] : 0

	String grfName = GetUserData(pnlName,"","grf")
	String imgNameList

	ControlInfo/W=$pnlName allC
	if (V_Value)
		imgNameList = ImageNameList(grfName,";")
	else
		ControlInfo/W=$pnlName imageP
		imgNameList = S_Value + ";"
	endif

	setZmodeValue(grfName, imgNameList, "m0", m0)
	setZmodeValue(grfName, imgNameList, "v0", v0)
	setZmodeValue(grfName, imgNameList, "m1", m1)
	setZmodeValue(grfName, imgNameList, "v1", v1)
End

//	0: auto; 1: fix; 2: sigma; 3: cut, 4: logsigma
Static Function [int m0, int m1] findSelectedMode(String pnlName)
	Wave minw = SIDAMGetCtrlValues(pnlName, "zminAutoC;zminC;zminSigmaC;zminCutC;zminLogsigmaC")
	Wave maxw = SIDAMGetCtrlValues(pnlName, "zmaxAutoC;zmaxC;zmaxSigmaC;zmaxCutC;zmaxLogsigmaC")
	minw *= p
	maxw *= p
	m0 = sum(minw)
	m1 = sum(maxw)
End

//	Set the z range based on the z mode
Static Function updateZRange(String grfName, [int pause])

	String listStr = ImageNameList(grfName,";"), imgName
	int i, n, m0, m1
	Variable v0, v1

	if (!ParamIsDefault(pause) && pause)
		//	Prevent recurrence calling by the hook function of the parent graph
		SetWindow $grfName userData(pauseHook)="1"
	endif

	for (i = 0, n = ItemsInList(listStr); i < n; i++)
		imgName = StringFromList(i,listStr)

		m0 = getZmodeValue(grfName, imgName, "m0")
		v0 = getZmodeValue(grfName, imgName, "v0")
		m1 = getZmodeValue(grfName, imgName, "m1")
		v1 = getZmodeValue(grfName, imgName, "v1")

		Wave zw = updateZRange_getValues(grfName, imgName, m0, v0, m1, v1)
		applyZRange(grfName, imgName, zw[0], zw[1])

		//	Record the present values so that any changes from the Igor default dialog
		//	can be detected later
		setZmodeValue(grfName, imgName, "z0", zw[0])
		setZmodeValue(grfName, imgName, "z1", zw[1])
	endfor
End

Static Function/WAVE updateZRange_getValues(String grfName, String imgName,
	int m0, Variable v0, int m1, Variable v1)

	if (m0 >= 2 || m1 >= 2)		//	sigma, cut, logsigma
		Wave tw = SIDAMImageWaveRef(grfName, imgName=imgName, displayed=1)
		if (m0 == 2 || m1 == 2)	//	sigma
			WaveStats/Q tw
			Variable avg = V_avg, sdev = V_sdev
		endif
		if (m0 == 3 || m1 == 3)	//	cut
			Wave hw = SIDAMHistogram(tw,bins=256,cumulative=1,normalize=1)
		endif
		if (m0 == 4 || m1 == 4)	//	logsimga
			MatrixOP/FREE tw2 = ln(tw)
			WaveStats/Q tw2
			Variable lnavg = V_avg, lnsdev = V_sdev
		endif
	endif

	Variable zmin, zmax
	switch (m0)
		case 0:	//	auto
			zmin = NaN
			break
		case 2:	//	sigma
			zmin = numtype(avg) || numtype(sdev) ? WaveMin(tw) : avg + sdev * v0
			break
		case 3:	//	cut
			FindLevel/Q hw, v0/100
			zmin = V_flag ? WaveMin(tw) : V_LevelX
			break
		case 4:	//	logsigma
			zmin = numtype(lnavg) || numtype(lnsdev) ? WaveMin(tw) : exp(lnavg+lnsdev*v0)
			break
		default:	//	1 (fix)
			zmin = v0
	endswitch

	switch (m1)
		case 0:	//	auto
			zmax = NaN
			break
		case 2:	//	sigma
			zmax = numtype(avg) || numtype(sdev) ? WaveMax(tw) : avg + sdev * v1
			break
		case 3:	//	cut
			FindLevel/Q hw, v1/100
			zmax = V_flag ? WaveMax(tw) : V_LevelX
			break
		case 4:	//	logsigma
			zmax = numtype(lnavg) || numtype(lnsdev) ? WaveMax(tw) : exp(lnavg+lnsdev*v1)
			break
		default:	//	1 (fix)
			zmax = v1
	endswitch

	Make/D/N=2/FREE rtnw = {zmin, zmax}
	return rtnw
End

Static Function printHistory(STRUCT paramStruct &s)

	String paramStr = "grfName=\"" + s.grfName + "\""

	int hasOnlyOneImage = ItemsInList(ImageNameList(s.grfName,";")) == 1
	int isAllImages = strlen(s.imgList) == 0
	if (!hasOnlyOneImage && !isAllImages)
		paramStr += ",imgList=\"" + s.imgList + "\""
	endif

	switch (s.zminmode)
		case 0:
			paramStr += ",zmin=NaN"
			break
		case 1:
			paramStr += ",zmin="+num2str(s.zmin)
			break
		default:
			paramStr += ",zminmode="+num2istr(s.zminmode)
			paramStr += ",zmin="+num2str(s.zmin)
	endswitch

	switch (s.zmaxmode)
		case 0:
			paramStr += ",zmax=NaN"
			break
		case 1:
			paramStr += ",zmax="+num2str(s.zmax)
			break
		default:
			paramStr += ",zmaxmode="+num2istr(s.zmaxmode)
			paramStr += ",zmax="+num2str(s.zmax)
	endswitch

	printf "%sSIDAMRange(%s)\r", PRESTR_CMD, paramStr
End


//=====================================================================================================
//	z mode functions
//=====================================================================================================
//	The z mode information is stored as a string like
//	imgName:m0=xxx,v0=xxx,z0=xxx,m1=xxx,v1=xxx,z1=xxx;layer=xxx;modtime=xxx
//	This string is repeated for each image.
//	m0 and m1 are the mode (0: auto, 1:fix, 2:sigma, 3:cut, -1:manual)
//	v0 and v1 are the value (e.g. 3sigma of 3)
//	z0 and z1 are values actually used for the image
Static StrConstant MODEKEY = "SIDAMRangeSettings"

//	If a graph has no z mode information, write the present status to revert
//	when the cancel button of the panel is pressed.
Static Function initializeZmodeValue(String grfName)
	int hasRecord = strlen(GetUserData(grfName, "", MODEKEY)) > 0
	if (hasRecord)
		return 0
	endif

	String imgList = ImageNameList(grfName,";"), imgName
	Variable zmin, zmax
	int i
	for (i = 0; i < ItemsInList(imgList); i++)
		imgName = StringFromList(i,imgList)
		setZmodeValue(grfName, imgList, "m0", !isZAuto(grfName, imgName, 0))
		setZmodeValue(grfName, imgList, "m1", !isZAuto(grfName, imgName, 1))
		SIDAM_GetColorTableMinMax(grfName, imgName, zmin, zmax)
		setZmodeValue(grfName, imgList, "v0", zmin)
		setZmodeValue(grfName, imgList, "v1", zmax)
	endfor
End

Static Function setZmodeValue(String grfName, String imgList, String key, Variable var)

	String allImagesSettings = GetUserData(grfName, "", MODEKEY)
	String formatStr = SelectString(!CmpStr(key,"m0")||!CmpStr(key,"m1"),"%.14e","%d")
	String imgName, setting, str
	int i, n

	for (i = 0, n = ItemsInList(imgList); i < n; i++)
		imgName = StringFromList(i,imgList)
		setting = StringByKey(imgName, allImagesSettings)
		Sprintf str formatStr, var
		setting = ReplaceStringByKey(key,setting,str,"=",",")
		allImagesSettings = ReplaceStringByKey(imgName,allImagesSettings,setting)
	endfor

	SetWindow $grfName userData($MODEKEY)=allImagesSettings
End

Static Function getZmodeValue(String grfName, String imgName, String key)

	//	no graph or no image
	if (WhichListItem(imgName, ImageNameList(grfName,";")) == -1)
		return NaN
	endif

	String allImagesSettings = GetUserData(grfName, "", MODEKEY)
	String setting = StringByKey(imgName, allImagesSettings)
	Variable num = NumberByKey(key, setting, "=" , ",")		//	nan for no record

	//	If there is a record, return it
	if (!numtype(num))
		return num
	endif

	Variable zmin, zmax
	strswitch (key)
		case "m0":
			//	If there is no record, the z mode is not used.
			//	An actual value or auto is set.
			return !isZAuto(grfName, imgName, 0)

		case "m1":
			//	If there is no record, the z mode is not used.
			//	An actual value or auto is set.
			return !isZAuto(grfName, imgName, 0)

		case "v0":
		case "z0":
			SIDAM_GetColorTableMinMax(grfName,imgName,zmin,zmax)
			return zmin

		case "v1":
		case "z1":
			SIDAM_GetColorTableMinMax(grfName,imgName,zmin,zmax)
			return zmax
	endswitch
End

//	Delete the z mode info about deleted (not included in the graph) images
Static Function cleanZmodeValue(String grfName)

	String allImagesSettings = GetUserData(grfName, "", MODEKEY)
	String imgList = ImageNameList(grfName,";")
	int i, n0 = ItemsInList(allImagesSettings)

	for (i = ItemsInList(allImagesSettings)-1; i >= 0; i--)
		String setting = StringFromList(i, allImagesSettings)
		String imgName = StringFromList(0, setting, ":")
		if (WhichListItem(imgName,imgList) == -1)
			allImagesSettings = RemoveByKey(imgName,allImagesSettings)
		endif
	endfor

	SetWindow $grfName userData($MODEKEY)=allImagesSettings

	return n0 > ItemsInList(allImagesSettings)		//	true if there is a deleted image
End

//	Delete all the information about the z mode
Static Function deleteZmodeValues(String grfName)
	SetWindow $grfName userdata($MODEKEY)=""
End

//	Return 1 if all the images have the z mode values of 0 or 1
Static Function canZmodeBeDeleted(String grfName)

	cleanZmodeValue(grfName)

	String allImagesSettings = GetUserData(grfName, "", MODEKEY)
	int i
	for (i = 0; i < ItemsInList(allImagesSettings); i++)
		String setting = StringFromList(1,StringFromList(i, allImagesSettings),":")
		Variable m0 = NumberByKey("m0", setting, "=" , ",")		//	nan for no record
		Variable m1 = NumberByKey("m1", setting, "=" , ",")		//	nan for no record
		if (m0 >= 2 || m0 < 0 || m1 >= 2 || m1 < 0)
			return 0
		endif
	endfor

	return 1
End
