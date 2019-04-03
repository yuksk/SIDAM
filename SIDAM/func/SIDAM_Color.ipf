#pragma TextEncoding="UTF-8"
#pragma rtGlobals=3
#pragma ModuleName=SIDAMColor

#ifndef SIDAMshowProc
#pragma hide = 1
#endif

#include <WMImageInfo>

//	References of the color tables
//
//	Wolfram
//	http://reference.wolfram.com/language/guide/ColorSchemes.ja.html
//
//	Matplotlib
//	http://matplotlib.org/examples/color/colormaps_reference.html
//
//	IDL
//	https://www.harrisgeospatial.com/docs/loadingdefaultcolortables.html
//	http://www.paraview.org/Wiki/Colormaps
//
//	CET Perceptually Uniform Colour Maps
//	http://peterkovesi.com/projects/colourmaps/

//******************************************************************************
///	SIDAMColor
///	@param grfName [optional, default = WinName(0,1,1)]
///		Name of a window.
///	@param imgList [optional, default = ImageNameList(grfName,";")]
///		List of images.
///	@param ctable [optional]
///		Name of a color table or path to a color table wave.
///		The default is the present value.
///	@param rev [optional]
///		0 or 1. Set 1 to reverse the color table.
///		The default is the present value.
///	@param log [optional]
///		0 or 1. 0 sets the default linearly-spaced colors.
///		1 sets logarithmically-spaced colors.
///		The default is the present value.
///	@param minRGB [optional]
///		{0}, {NaN}, or {r,g,b}. Set the color less than the ctab zMin.
///		{0} turns min color off. {NaN} uses transparent.
///		{r,g,b} sets the color. The default is the present value.
///	@param maxRGB [optional]
///		{0}, {NaN}, or {r,g,b}. Set the color greater than the ctab zMax.
///		{0} turns max color off. {NaN} uses transparent.
///		{r,g,b} sets the color. The default is the present value.
///	@param history [optional, default = 0]
///		0 or !0. Set !0 to print this command in the history.
///	@param kill [optional, default = 0]
///		0 or !0. Set !0 to kill all unused color table waves.
///	@return
///		0 for normal exit, 1 for any error in input parameters
//******************************************************************************
Function SIDAMColor([String grfName, String imgList, String ctable, int rev, int log,
	Wave minRGB, Wave maxRGB, int history, int kill])

	if (!ParamIsDefault(kill) && kill)
		killUnusedWaves()
		return 0
	endif

	STRUCT paramStruct ds
	defaultValues(ds)

	STRUCT paramStruct s
	s.grfName = SelectString(ParamIsDefault(grfName), grfName, ds.grfName)
	s.imgList = SelectString(ParamIsDefault(imgList), imgList, ds.imgList)
	s.ctable = SelectString(ParamIsDefault(ctable), ctable, ds.ctable)
	s.rev = ParamIsDefault(rev) ? ds.rev : rev
	s.log = ParamIsDefault(log) ? ds.log : log
	if (ParamIsDefault(minRGB))
		Wave s.minRGB = ds.minRGB
	else
		Wave s.minRGB = minRGB
	endif
	if (ParamIsDefault(maxRGB))
		Wave s.maxRGB = ds.maxRGB
	else
		Wave s.maxRGB = maxRGB
	endif

	if (validateInputs(s))
		printf "%sSIDAMColor gave error: %s\r", PRESTR_CAUTION, s.errMsg
		return 1
	elseif (ParamIsDefault(ctable) && ParamIsDefault(rev) && ParamIsDefault(log) \
		&& ParamIsDefault(minRGB) && ParamIsDefault(maxRGB))
		pnl(s.grfName)
		return 0
	endif

	if (!ParamIsDefault(history) && history)
		printHistory(s,ds)
	endif

	int i, n
	for (i = 0, n = ItemsInList(s.imgList); i < n; i++)
		applyColorTable(s,i)
	endfor

	return 0
End

Static Structure paramStruct
	String grfName
	String imgList
	String ctable
	Variable rev
	Variable log
	Wave	minRGB
	Wave 	maxRGB
	String errMsg
EndStructure

Static Function defaultValues(STRUCT paramStruct &s)
	s.grfName = WinName(0,1,1)
	s.imgList = ImageNameList(s.grfName,";")

	String imgName = StringFromList(0, s.imgList)
	s.ctable = WM_ColorTableForImage(s.grfName, imgName)
	s.rev = WM_ColorTableReversed(s.grfName, imgName)
	s.log = SIDAM_ColorTableLog(s.grfName, imgName)

	STRUCT RGBColor color
	Make/N=1/FREE zerow = {0}, nanw = {NaN}
	switch (SIDAM_ImageColorRGBMode(s.grfName, imgName, "minRGB"))
		case 0:
			Wave s.minRGB = zerow
			break
		case 1:
			SIDAM_ImageColorRGBValues(s.grfName, imgName, "minRGB", color)
			Make/N=3/FREE colorw = {color.red, color.green, color.blue}
			Wave s.minRGB = colorw
			break
		case 2:
			Wave s.minRGB = nanw
			break
		default:
			Wave s.minRGB = zerow
	endswitch

	switch (SIDAM_ImageColorRGBMode(s.grfName, imgName, "maxRGB"))
		case 0:
			Wave s.maxRGB = zerow
			break
		case 1:
			SIDAM_ImageColorRGBValues(s.grfName, imgName, "maxRGB", color)
			Make/N=3/FREE colorw = {color.red, color.green, color.blue}
			Wave s.maxRGB = colorw
			break
		case 2:
			Wave s.maxRGB = nanw
			break
		default:
			Wave s.maxRGB = zerow
	endswitch
End

Static Function validateInputs(STRUCT paramStruct &s)

	if (!strlen(s.grfName))
		s.errMsg = "graph not found."
		return 1
	elseif (!SIDAMWindowExists(s.grfName))
		s.errMsg = "a graph named " + s.grfName + " is not found."
		return 1
	elseif (!strlen(ImageNameList(s.grfName,";")))
		s.errMsg = s.grfName + " has no image."
		return 1
	endif

	int i, n
	for (i = 0, n = ItemsInList(s.imgList); i < n; i++)
		if (WhichListItem(StringFromList(i,s.imgList),ImageNameList(s.grfName,";")) < 0)
			s.errMsg = "an image named " + StringFromList(i,s.imgList) + " is not found."
			return 1
		endif
	endfor

	//	If a path to color table wave is given, make sure if it exists.
	//	If not, load all ibw files of color table waves and check again.
	if (strlen(s.ctable) && WhichListItem(s.ctable,CTabList()) < 0 && !WaveExists($s.ctable))
		loadColorTableAll()
		if (!WaveExists($s.ctable))
			killUnusedWaves()	//	Kill waves loaded for this check
			s.errMsg = "a color table " + s.ctable + " is not found."
			return 1
		endif
	endif

	if (s.rev < 0 || s.rev > 1)
		s.errMsg = "rev must be 0 or 1."
		return 1
	endif

	if (s.log < 0 || s.log > 1)
		s.errMsg = "log must be 0 or 1."
		return 1
	endif

	return 0
End

Static Function printHistory(STRUCT paramStruct &s, STRUCT paramStruct &base)
	String paramStr = ""
	paramStr += SelectString(CmpStr(s.grfName,base.grfName),"",",grfName=\""+s.grfName+"\"")
	paramStr += SelectString(CmpStr(s.imgList,base.imgList),"",",imgList=\""+s.imgList+"\"")
	paramStr += SelectString(CmpStr(s.ctable,base.ctable),"",",ctable=\""+s.ctable+"\"")
	paramStr += SelectString(s.rev==base.rev,",rev="+num2istr(s.rev),"")
	paramStr += SelectString(s.log==base.log,",log="+num2istr(s.log),"")
	paramStr += SelectString(equalWaves(s.minRGB,base.minRGB,1),",minRGB="+KMWaveToString(s.minRGB),"")
	paramStr += SelectString(equalWaves(s.maxRGB,base.maxRGB,1),",maxRGB="+KMWaveToString(s.maxRGB),"")
	printf "%sSIDAMColor(%s)\r", PRESTR_CMD, paramStr[1,inf]
End

//	Apply color table to an image in the list
Static Function applyColorTable(STRUCT paramStruct &s, int i)

	String imgName = StringFromList(i, s.imgList)
	Wave rw = KM_GetColorTableMinMax(s.grfName, imgName)
	Variable zmin = isFirstZAuto(s.grfName, imgName) ? NaN : rw[0]
	Variable zmax = isLastZAuto(s.grfName, imgName) ? NaN : rw[1]

	if (numtype(zmin)==2 && numtype(zmax)==2)
		ModifyImage/W=$s.grfName $imgName ctab={*,*,$s.ctable,s.rev}, log=s.log
	elseif (numtype(zmin)==2)
		ModifyImage/W=$s.grfName $imgName ctab={*,zmax,$s.ctable,s.rev}, log=s.log
	elseif (numtype(zmax)==2)
		ModifyImage/W=$s.grfName $imgName ctab={zmin,*,$s.ctable,s.rev}, log=s.log
	else
		ModifyImage/W=$s.grfName $imgName ctab={zmin,zmax,$s.ctable,s.rev}, log=s.log
	endif

	if (numpnts(s.minRGB)==1)
		ModifyImage/W=$s.grfName $imgName minRGB=s.minRGB[0]
	elseif (numpnts(s.minRGB)==3)	//	(r,g,b)
		ModifyImage/W=$s.grfName $imgName minRGB=(s.minRGB[0],s.minRGB[1],s.minRGB[2])
	endif

	if (numpnts(s.maxRGB)==1)
		ModifyImage/W=$s.grfName $imgName maxRGB=s.maxRGB[0]
	elseif (numpnts(s.maxRGB)==3)	//	(r,g,b)
		ModifyImage/W=$s.grfName $imgName maxRGB=(s.maxRGB[0],s.maxRGB[1],s.maxRGB[2])
	endif

End


//=====================================================================================================
//	Panel
//=====================================================================================================
//	Positions of tab
Static Constant leftMargin = 10
Static Constant topMargin = 65
Static Constant topExpanded = 165

//	Size of a color table
Static Constant ctabHeight = 14
Static Constant ctabWidth = 90

//	Margin between color tables
Static Constant ctabMargin = 2

//	Number of color tables in a column
Static Constant ctabsInColumn = 38

//	Width of a single column
Static Constant columnWidth = 270

//	Margin between color tables and checkboxes in a column
Static Constant checkBoxMargin = 5

//******************************************************************************
//	Display a panel
//******************************************************************************
Static Function pnl(String grfName)
	String targetWin = StringFromList(0,grfName,"#")

	if (SIDAMWindowExists(grfName+"#Color"))
		return 0
	endif

	String imgName = StringFromList(0,ImageNameList(grfName,";"))
	int needUpdate = DataFolderExists(SIDAM_DF_CTAB) ? \
		NumVarOrDefault(SIDAM_DF_CTAB+"needUpdate",1) : 1
	int i, n

	//	Display a panel
	int pnlwidth = (leftMargin+columnWidth)*2
	int pnlHeight = topMargin+(ctabHeight+ctabMargin)*ctabsInColumn+10
	NewPanel/EXT=0/HOST=$targetWin/W=(0,0,pnlWidth,pnlHeight)/K=1
	RenameWindow $targetWin#$S_name, Color
	String pnlName = targetWin + "#Color"

	SetWindow $grfName hook(SIDAMColorPnl)=SIDAMColor#pnlHookParent
	SetWindow $pnlName hook(self)=SIDAMColor#pnlHook
	SetWindow $pnlName userData(grf)=grfName, activeChildFrame=0

	saveInitialColor(pnlName)

	//	Tab
	String tabNameList = "Igor;" + ReplaceString("$APPLICATION:",SIDAM_CTABGROUPS,"")
	Variable activeTab = findTabForPresentCtab(grfName,imgName)
	TabControl mTab pos={2,topMargin-30}, proc=SIDAMColor#pnlTab, win=$pnlName
	TabControl mTab size={pnlwidth-2,pnlHeight-topMargin+30}, win=$pnlName
	for (i = 0, n = ItemsInList(tabNameList); i < n; i++)
		TabControl mTab tabLabel(i)=StringFromList(i,tabNameList), win=$pnlName
	endfor
	TabControl mTab value=activeTab, win=$pnlName

	//	Controls ouside of the tab
	PopupMenu imageP pos={7,7},size={235,19},bodyWidth=200,title="image",win=$pnlName
	PopupMenu imageP proc=SIDAMColor#pnlPopup,value=#"SIDAMColor#imagePvalue()",win=$pnlName
	CheckBox allC pos={258,9},title=" all",value=0,win=$pnlName
	CheckBox optionC title="Options",pos={310,10},mode=2,win=$pnlName
	Button doB pos={410,6},size={70,22},title="Do It",proc=SIDAMColor#pnlButton,win=$pnlName
	Button cancelB pos={486,6},size={70,22},title="Cancel",proc=SIDAMColor#pnlButton,win=$pnlName

	//	Controls ouside of the tab, and hidden depending on optionC
	GroupBox op_revlogG pos={5,35},size={130,90},title="Color Table Options",win=$pnlName
	CheckBox op_revC pos={14,56},title=" Reverse Colors",win=$pnlName
	CheckBox op_logC pos={14,80},title=" Log Colors",win=$pnlName

	GroupBox op_beforeG pos={140,35},size={130,90},title="Before First Color"	,win=$pnlName
	CheckBox op_beforeUseC pos={149,55},title=" Use First Color",mode=1,win=$pnlName
	CheckBox op_beforeClrC pos={149,79},title="",mode=1,win=$pnlName
	CheckBox op_beforeTransC pos={149,101},title=" Transparent",mode=1,win=$pnlName
	PopupMenu op_beforeClrP pos={167,77},size={40,19},bodyWidth=40,value= #"\"*COLORPOP*\"",win=$pnlName

	GroupBox op_lastG pos={275,35},size={130,90},title="After Last Color",win=$pnlName
	CheckBox op_lastUseC pos={284,55},title=" Use Last Color",mode=1,win=$pnlName
	CheckBox op_lastClrC pos={284,79},title="",mode=1,win=$pnlName
	CheckBox op_lastTransC pos={284,101},title=" Transparent",mode=1,win=$pnlName
	PopupMenu op_lastClrP pos={302,77},size={40,19},bodyWidth=40,value= #"\"*COLORPOP*\"",win=$pnlName

	ModifyControlList ControlNameList(pnlName,";","*C") proc=SIDAMColor#pnlCheckRadio, win=$pnlName
	ModifyControlList "allC;optionC;op_revC;op_logC" proc=SIDAMColor#pnlCheck, win=$pnlName
	ModifyControlList ControlNameList(pnlName,";","op_*") disable=1,win=$pnlName
	ModifyControlList ControlNameList(pnlName,";","*P") mode=1, proc=SIDAMColor#pnlPopup, win=$pnlName

	//	Update controls involved with rev, log, mixRGB, and maxRGB
	updateOptionControls(pnlName,imgName)

	//	Guides for subwindows in which color scales are shown
	DefineGuide/W=$pnlname ctab0L = {FL, leftMargin}
	DefineGuide/W=$pnlName ctab0R = {FL, leftMargin+ctabWidth}
	DefineGuide/W=$pnlname ctab1L = {FL, leftMargin+columnWidth}
	DefineGuide/W=$pnlName ctab1R = {FL, leftMargin+columnWidth+ctabWidth}
	DefineGuide/W=$pnlName ctabT = {FT, topMargin}
	DefineGuide/W=$pnlName ctabB = {FT, topMargin+(ctabHeight+ctabMargin)*ctabsInColumn-ctabMargin}

	if (needUpdate)
		//	Load color table waves
		showLoading(pnlName)
		loadColorTableAll()
		Variable/G $(SIDAM_DF_CTAB+"needUpdate") = 0
		//	Backward compatibility
		//	Old color index waves may be used since new color table waves were not used
		cindexWave2ctabWave()
	endif

	//	Create and draw the active tab before the others
	pnlTabComponents(pnlName, activeTab, 0)

	//	Check the checkbox of the present color scale
	String selected = findCheckBox(pnlName,imgName)
	if (strlen(selected))
		CheckBox $selected value=1, win=$pnlName
	endif

	//	Reflect rev and log to the color scales in the active tab
	updateColorscales(pnlName,onlyInThisTab=activeTab)

	if (needUpdate)
		deleteLoading(pnlName)
	endif
	DoUpdate/W=$pnlName

	//	Create the other tabs
	for (i = 0, n = ItemsInList(SIDAM_CTABGROUPS)+1; i < n; i++)
		if (i == activeTab)
			continue
		endif
		pnlTabComponents(pnlName, i, 1)
	endfor
	SetActiveSubwindow ##
	ModifyControlList ControlNameList(pnlName,";","*") focusRing=0,win=$pnlName

	updateColorscales(pnlName)
End

//-----------------------------------------------------------------------
//	Show an overlay when waves are being loaded
//-----------------------------------------------------------------------
Static Function showLoading(String pnlName)
	String name = "loading"
	Variable top = 55
	Variable bottom = topMargin+(ctabHeight+ctabMargin)*ctabsInColumn+10

	DrawAction/L=Overlay/W=$pnlName getgroup=$name

	SetDrawLayer/W=$pnlName Overlay
	SetDrawEnv/W=$pnlName gname=$name, gstart

	SetDrawEnv/W=$pnlName fillfgc=(0,0,0,32768),linethick=0
	DrawRect/W=$pnlName 5,top,555,bottom

	SetDrawEnv/W=$pnlName textrgb=(65535,65535,65535), textxjust=1, textyjust=1
	DrawText/W=$pnlName 275,(top+bottom)/2,"Now loading..."

	SetDrawEnv/W=$pnlName gstop
	SetDrawLayer/W=$pnlName UserBack

	DoUpdate/W=$pnlName
End

//-----------------------------------------------------------------------
//	Delete the overlay when waves are being loaded
//-----------------------------------------------------------------------
Static Function deleteLoading(String pnlName)
	String name = "loading"
	DrawAction/L=Overlay/W=$pnlName getgroup=$name, delete
End

//-----------------------------------------------------------------------
//	Create components in each tab
//-----------------------------------------------------------------------
Static Function pnlTabComponents(String pnlName, int tab, int hide)

	String list
	if (tab == 0)	//	Igor
		list = CTabList()
	else				//	Color table waves
		String dfNames = ReplaceString("$APPLICATION:",SIDAM_CTABGROUPS,"")
		DFREF dfr = $(SIDAM_DF_CTAB+StringFromList(tab-1,dfNames))
		list = fetchWavepathList(dfr)
	endif
	int i, n

	//	Subwindow for displaying color scales
	Display/HOST=$pnlName/HIDE=(hide)
	MoveSubWindow/W=$pnlName#G0 fguide=(ctab0L, ctabT, ctab0R, ctabB)
	RenameWindow $pnlName#G0 $("G_"+num2istr(tab)+"_0")

	Display/HOST=$pnlName/HIDE=(hide)
	MoveSubWindow/W=$pnlName#G0 fguide=(ctab1L, ctabT, ctab1R, ctabB)
	RenameWindow $pnlName#G0 $("G_"+num2istr(tab)+"_1")

	for (i = 0, n = ItemsInList(list); i < n; i++)
		//	Color scales are displayed in the subwindows
		String csName = "cs_"+num2istr(tab)+"_"+num2istr(i)
		String ctabName = StringFromList(i, list)
		String subWinName = "G_"+num2istr(tab)+"_"+num2istr(floor(i/ctabsInColumn))
		ColorScale/W=$pnlName#$subWinName/C/N=$csName/F=0/A=LT/X=0/Y=(mod(i,ctabsInColumn)/ctabsInColumn*100) widthPct=100,height=ctabHeight,vert=0,ctab={0,100,$ctabName,0},nticks=0,tickLen=0.00

		//	Checkboxes are displayed in the panel
		//	The title of checkbox is
		//	(1) name of color table for Igor Pro's table
		//	(2) name of wave for color table waves
		String cbName = "cb_"+num2istr(tab)+"_"+num2istr(i)
		String titleName = ParseFilePath(0, StringFromList(i, list), ":", 1, 0)
		Variable left = leftMargin+ctabWidth+checkBoxMargin+columnWidth*floor(i/ctabsInColumn)
		Variable top = topMargin+((ctabHeight+ctabMargin)*mod(i,ctabsInColumn))
		CheckBox $cbName pos={left,top}, title=" "+titleName, disable=(hide), mode=1, win=$pnlName
		CheckBox $cbName proc=SIDAMColor#pnlCheckRadio, userData(ctabName)=ctabName, win=$pnlName
	endfor
End

//-----------------------------------------------------------------------
//	Return a string containing a list of absolulte paths of all waves
//	under dfr including subdatafolder
//-----------------------------------------------------------------------
Static Function/S fetchWavepathList(DFREF dfr)
	if (!DataFolderRefStatus(dfr))
		return ""
	endif

	int i, n
	String list = ""

	for (i = 0, n = CountObjectsDFR(dfr, 4); i < n; i++)
		list += fetchWavepathList(dfr:$GetIndexedObjNameDFR(dfr, 4, i))
	endfor

	//	Sort by name, instead of order added to parent datafolder of GetIndexedObjNameDFR
	n = CountObjectsDFR(dfr,1)
	Make/N=(n)/T/FREE namew = GetIndexedObjNameDFR(dfr,1,p)
	Sort namew, namew

	for (i = 0, n = CountObjectsDFR(dfr, 1); i < n; i++)
		Wave/SDFR=dfr w = $namew[i]
		list += GetWavesDataFolder(w,2) + ";"
	endfor

	return list
End

//-----------------------------------------------------------------------
//	Return tab number where the present color scale is included
//-----------------------------------------------------------------------
Static Function findTabForPresentCtab(String grfName, String imgName)
	String ctab = SIDAM_ColorTableForImage(grfName,imgName)
	if (strsearch(ctab,":",0) == -1)	//	Igor
		return 0
	endif
	String groupName = StringFromList(ItemsInList(SIDAM_DF,":")+1,ctab,":")
	return WhichListItem(groupName,SIDAM_CTABGROUPS)+1
End

//-----------------------------------------------------------------------
//	Return name of checkbox corresponding to the color scale
//	used for imgName in pnlName
//-----------------------------------------------------------------------
Static Function/S findCheckBox(String pnlName, String imgName)
	String grfName = GetUserData(pnlName,"","grf")
	String ctabName = SIDAM_ColorTableForImage(grfName,imgName)

	Wave/T checkBoxListWave = ListToTextWave(ControlNameList(pnlName,";","cb_*"),";")
	Make/T/N=(numpnts(checkBoxListWave))/FREE ctabNameListWave
	ctabNameListWave = GetUserData(pnlName,checkBoxListWave[p],"ctabName")
	FindValue/TEXT=ctabName ctabNameListWave
	return SelectString(V_Value==-1, checkBoxListWave[V_Value], "")
End

//---------------------------------------------------------------------------
//	Save the initial state when the panel is opened, to userData of the panel
//---------------------------------------------------------------------------
Static Structure initParam
	uchar rev
	uchar log
	STRUCT initParamSub min
	STRUCT initParamSub max
EndStructure

Static Structure initParamSub
	uchar mode
	STRUCT RGBColor clr
EndStructure

Static Function saveInitialColor(String pnlName)
	String grfName = GetUserData(pnlName,"","grf")
	String imgList = ImageNameList(grfName,";")
	String imgName, ctabName, str
	String sepStr = num2char(31)
	STRUCT initParam s
	int i, n

	SetWindow $pnlName userData(imgList) = imgList

	for (i = 0, n = ItemsInList(imgList); i < n; i++)
		imgName = StringFromList(i,imgList)

		ctabName = SIDAM_ColorTableForImage(grfName,imgName)
		s.rev = WM_ColorTableReversed(grfName,imgName)
		s.log = SIDAM_ColorTableLog(grfName,imgName)

		s.min.mode = SIDAM_ImageColorRGBMode(grfName,imgName,"minRGB")
		if (s.min.mode == 1) // (r,g,b)
			SIDAM_ImageColorRGBValues(grfName,imgName,"minRGB",s.min.clr)
		endif

		s.max.mode = SIDAM_ImageColorRGBMode(grfName,imgName,"maxRGB")
		if (s.max.mode == 1) // (r,g,b)
			SIDAM_ImageColorRGBValues(grfName,imgName,"maxRGB",s.max.clr)
		endif

		StructPut/S s, str
		SetWindow $pnlName userData($imgName) = ctabName + sepStr + str
	endfor
End


//******************************************************************************
//	Hook Functions
//******************************************************************************
//-------------------------------------------------------------
//	Hook function for the panel
//-------------------------------------------------------------
Static Function pnlHook(STRUCT WMWinHookStruct &s)
	switch (s.eventCode)
		case 2:	//	kill
			SetWindow $GetUserData(s.winName,"","grf") hook(SIDAMColorPnl)=$""
			break

		case 11:	//	keyboard
			switch (s.keycode)
				case 27:	//	esc
					SetWindow $GetUserData(s.winName,"","grf") hook(SIDAMColorPnl)=$""
					KillWindow $s.winName
					break
				case 28:	//	left
				case 29:	//	right
				case 30:	//	up
				case 31:	//	down
					pnlHookArrows(s.winName, s.keycode)
					break
			endswitch
			break

		case 22:	//	mouseWheel
			pnlHookWheel(s)
			break
	endswitch
End

Static Function pnlHookArrows(String pnlName, int keycode)
	//	get selected tab and checkbox
	Variable tab0, box0
	String list = ControlNameList(pnlName,";","cb_*")
	Wave cw = KMGetCtrlValues(pnlName,list)
	WaveStats/Q/M=1 cw
	if (V_max)
		sscanf StringFromList(V_maxloc,list), "cb_%d_%d", tab0, box0
	else	//	no checkbox is checked
		return 0
	endif
	int isInLeftColumn = box0 < ctabsInColumn

	//	get new tab and checkbox
	Variable tab1, box1
	switch (keycode)
		case 28:	//	left
			tab1 = isInLeftColumn ? tab0-1 : tab0
			if (isInLeftColumn)
				box1 = box0 + ctabsInColumn*bothColumnsExist(pnlName,tab1)
			else
				box1 = box0 - ctabsInColumn
			endif
			break
		case 29:	//	right
			tab1 = !isInLeftColumn || !bothColumnsExist(pnlName,tab0) ? tab0+1 : tab0
			if (isInLeftColumn)
				box1 = box0 + ctabsInColumn*bothColumnsExist(pnlName,tab0)
			else
				box1 = box0 - ctabsInColumn
			endif
			break
		case 30:	//	up
			tab1 = tab0
			box1 = box0 - (mod(box0,ctabsInColumn)!=0)
			break
		case 31:	//	down
			tab1 = tab0
			box1 = box0 + (mod(box0,ctabsInColumn)!=ctabsInColumn-1)
	endswitch

	if (tab1 < 0 || tab1 > ItemsInList(SIDAM_CTABGROUPS))
		return 0
	endif
	box1 = limit(box1,0,ItemsInList(ControlNameList(pnlName,";","cb_"+num2istr(tab1)+"_*"))-1)

	if (tab1 == tab0 && box1 == box0)
		return 0
	endif

	String cbName = "cb_"+num2istr(tab1)+"_"+num2istr(box1)
	KMClickCheckBox(pnlName, cbName)
	clickTab(pnlName, tab1)
End

Static Function bothColumnsExist(String pnlName, int tab)
	if (tab < 0 || tab > ItemsInList(SIDAM_CTABGROUPS))
		return 0
	else
		return ItemsInList(ControlNameList(pnlName,";","cb_"+num2istr(tab)+"_*")) > ctabsInColumn
	endif
End

Static Function pnlHookWheel(STRUCT WMWinHookStruct &s)
	String pnlName = s.winName
	if (ItemsInList(pnlName,"#") == 3)		//	when the mouse cursor in the subwindow G_*_*
		pnlName = RemoveEnding(ParseFilePath(1,s.winName,"#",0,2),"#")
	endif
	ControlInfo/W=$pnlName mTab
	if (s.mouseLoc.h < V_left || s.mouseLoc.h > V_left+V_Width || s.mouseLoc.v < V_top || s.mouseLoc.v > V_top+V_Height)
		return 0
	endif
	int newTab = V_Value-sign(s.wheelDy)	//	move to the right tab by scrolling down
	if (newTab >= 0 && newTab <= ItemsInList(SIDAM_CTABGROUPS))
		clickTab(pnlName, newTab)
	endif
End

//-------------------------------------------------------------
//	Hook function for the parent window.
//	Reflect changes made outside of the panel to the panel.
//-------------------------------------------------------------
Static Function pnlHookParent(STRUCT WMWinHookStruct &s)
	if (s.eventCode != 8)	//	modified only
		return 0
	endif

	String pnlName = s.winName + "#Color"
	ControlInfo/W=$pnlName imageP
	String imgName = S_Value

	//	Select a checkbox of the present color table
	selectCheckBox(pnlName, findCheckBox(pnlName,imgName))

	//	Reflect rev, log, minRGB, and maxRGB of the image to the panel
	updateOptionControls(pnlName,imgName)

	//	Update color scales in the panel to refrect rev and log
	updateColorscales(pnlName)
End


//******************************************************************************
//	Controls
//******************************************************************************
//	Tab
Static Function pnlTab(STRUCT WMTabControlAction &s)
	if (s.eventCode == 2)
		clickTab(s.win, s.tab)
	endif
	return 0
End

//	Checkbox
Static Function pnlCheck(STRUCT  WMCheckboxAction &s)

	if (s.eventCode != 2)
		return 0
	endif

	strswitch (s.ctrlName)
		case "allC":
			PopupMenu imageP disable=s.checked*2, win=$s.win
			if (s.checked)
				updateAllImaeges(s)
			endif
			break

		case "optionC":
			int top = s.checked ? topExpanded : topMargin
			int width = (leftMargin+columnWidth)*2
			int height = top+(ctabHeight+ctabMargin)*ctabsInColumn+10
			DefineGuide/W=$s.win ctabT = {FT, top}
			DefineGuide/W=$s.win ctabB = {FT, top+(ctabHeight+ctabMargin)*ctabsInColumn-ctabMargin}
			MoveSubWindow/W=$s.win fnum=(0,0,width,height)
			ModifyControlList ControlNameList(s.win,";","op_*") disable=!s.checked, win=$s.win
			int dy = (topExpanded-topMargin)*(s.checked?1:-1)
			TabControl mTab pos+={0,dy}, win=$s.win
			ModifyControlList ControlNameList(s.win,";","cb_*") pos+={0,dy}, win=$s.win
			break

		case "op_revC":
		case "op_logC":
			String grfName = GetUserData(s.win,"","grf")
			String imgList = targetImageList(s.win)
			if (CmpStr(s.ctrlName,"op_revC"))
				SIDAMColor(grfName=grfName, imgList=imgList, log=s.checked)
			else
				SIDAMColor(grfName=grfName, imgList=imgList, rev=s.checked)
			endif
			updateColorscales(ParseFilePath(1,s.win,"#",1,0))
			break

	endswitch
	return 0
End

//	Checkbox (radio buttons)
Static Function pnlCheckRadio(STRUCT WMCheckboxAction &s)

	if (s.eventCode != 2)
		return 0
	endif

	//	call this to uncheck all checkboxes in the same group
	selectCheckBox(s.win, s.ctrlName)

	String grfName = GetUserData(s.win,"","grf")
	String imgList = targetImageList(s.win)
	strswitch (s.ctrlName)
		case "op_beforeUseC":
			SIDAMColor(grfName=grfName, imgList=imgList, minRGB={0})
			break
		case "op_beforeClrC":
			ControlInfo/W=$s.win op_beforeClrP
			SIDAMColor(grfName=grfName, imgList=imgList, minRGB={V_Red,V_Green,V_Blue})
			break
		case "op_beforeTransC":
			SIDAMColor(grfName=grfName, imgList=imgList, minRGB={NaN})
			break
		case "op_lastUseC":
			SIDAMColor(grfName=grfName, imgList=imgList, maxRGB={0})
			break
		case "op_lastClrC":
			ControlInfo/W=$s.win op_lastClrP
			SIDAMColor(grfName=grfName, imgList=imgList, maxRGB={V_Red,V_Green,V_Blue})
			break
		case "op_lastTransC":
			SIDAMColor(grfName=grfName, imgList=imgList, maxRGB={NaN})
			break
		default:	//	"cb_*"
			SIDAMColor(grfName=grfName, imgList=imgList, ctable=GetUserData(s.win,s.ctrlName,"ctabName"))
	endswitch

	return 0
End

//	Popup
Static Function pnlPopup(STRUCT WMPopupAction &s)

	if (s.eventCode != 2)
		return 0
	endif

	strswitch (s.ctrlName)
		case "imageP":
			//	Check the checkbox of the color scale of the selected image
			String cbName = findCheckBox(s.win,s.popStr)
			selectCheckBox(s.win, cbName)

			//	Activate the tab in which the above checkbox is included
			clickTab(s.win, str2num(StringFromList(1,cbName,"_")))

			//	Update controls involved with rev, log, mixRGB, and maxRGB
			updateOptionControls(s.win,s.popStr)

			//	Update color scales in the panel to refrect rev and log
			updateColorscales(s.win)
			break

		case "op_beforeClrP":
		case "op_lastClrP":
			//	Change the color scale as chosen
			String grfName = GetUserData(s.win,"","grf")
			String imgList = targetImageList(s.win)
			int red, green, blue
			sscanf s.popStr, "(%d,%d,%d)", red, green, blue
			if (stringmatch(s.ctrlName,"op_beforeClrP"))
				SIDAMColor(grfName=grfName,imgList=imgList, minRGB={red,green,blue})
			else
				SIDAMColor(grfName=grfName,imgList=imgList, maxRGB={red,green,blue})
			endif
			break
	endswitch
End

//	Button
Static Function pnlButton(STRUCT WMButtonAction &s)
	if (s.eventCode != 2)
		return 0
	endif

	strswitch (s.ctrlName)
		case "cancelB":
			revertImageColor(s.win)
			//	*** FALLTHROUGH ***
		case "doB":
			KillWindow $(s.win)
			break
		default:
	endswitch

	return 0
End

//******************************************************************************
//	Helper funcitons for control
//******************************************************************************
//-------------------------------------------------------------
//	Returns string for imageP
//-------------------------------------------------------------
Static Function/S imagePvalue()
	String pnlName = GetUserData(WinName(0,1)+"#Color","","grf")
	return ImageNameList(pnlName, ";")
End

//-------------------------------------------------------------
//	Return a list of images to be modified, depending on
//	the status of allC
//-------------------------------------------------------------
Static Function/S targetImageList(String pnlName)
	String grfName = GetUserData(pnlName,"","grf")
	ControlInfo/W=$pnlName allC
	if (V_Value)
		return ImageNameList(grfName,";")
	else
		ControlInfo/W=$pnlName imageP
		return S_Value
	endif
End

//-------------------------------------------------------------
//	Show color tables and checkboxes of the clicked tab, and
//	hide the others
//-------------------------------------------------------------
Static Function clickTab(String pnlName, int tab)
	TabControl mTab value=tab, win=$pnlName

	int i, n

	for (i = 0, n = ItemsInList(SIDAM_CTABGROUPS)+1; i < n; i++)
		SetWindow $pnlName#$("G_"+num2istr(i)+"_0") hide=(i!=tab)
		SetWindow $pnlName#$("G_"+num2istr(i)+"_1") hide=(i!=tab)
	endfor

	ModifyControlList ControlNameList(pnlName, ";", "cb_*") disable=1, win=$pnlName
	ModifyControlList ControlNameList(pnlName, ";", "cb_"+num2istr(tab)+"*") disable=0, win=$pnlName

	DoUpdate/W=$pnlName		//	to prevent some color scales are weirdly left
End

//-------------------------------------------------------------
//	Update color scales of all images
//-------------------------------------------------------------
Static Function updateAllImaeges(STRUCT  WMCheckboxAction &s)
	String grfName = GetUserData(s.win,"","grf")
	String imgList = ImageNameList(grfName,";")

	String cbName = findSelectedCheckbox(s.win)
	String ctable = GetUserData(s.win,cbName,"ctabName")
	Wave cw = KMGetCtrlValues(s.win,"op_revC;op_logC")

	SIDAMColor(grfName=grfName,imgList=imgList,ctable=ctable,rev=cw[0],log=cw[1],\
		minRGB=getRGBWave(s.win,"minRGB"),maxRGB=getRGBWave(s.win,"maxRGB"))
End

//--------------------------------------------------------------------
//	Update the control about rev, log, minRGB, and maxRGB in the panel
//	so that they reflect the status of the image.
//--------------------------------------------------------------------
Static Function updateOptionControls(String pnlName, String imgName)
	String grfName = GetUserData(pnlName,"","grf")
	CheckBox op_revC value=WM_ColorTableReversed(grfName,imgName),win=$pnlName
	CheckBox op_logC value=SIDAM_ColorTableLog(grfName,imgName),win=$pnlName

	int minMode = SIDAM_ImageColorRGBMode(grfName,imgName,"minRGB")
	STRUCT RGBColor s
	SIDAM_ImageColorRGBValues(grfName,imgName,"minRGB",s)
	CheckBox op_beforeUseC value=(minMode==0),win=$pnlName
	CheckBox op_beforeClrC value=(minMode==1),win=$pnlName
	CheckBox op_beforeTransC value=(minMode==2),win=$pnlName
	if (minMode == 1)
		PopupMenu op_beforeClrP popColor=(s.red,s.green,s.blue),win=$pnlName
	endif

	int maxMode = SIDAM_ImageColorRGBMode(grfName,imgName,"maxRGB")
	SIDAM_ImageColorRGBValues(grfName,imgName,"maxRGB",s)
	CheckBox op_lastUseC value=(maxMode==0),win=$pnlName
	CheckBox op_lastClrC value=(maxMode==1),win=$pnlName
	CheckBox op_lastTransC value=(maxMode==2),win=$pnlName
	if (maxMode == 1)
		PopupMenu op_lastClrP popColor=(s.red,s.green,s.blue),win=$pnlName
	endif
End

//-------------------------------------------------------------
//	Update the color scales shown in the panel so that they
//	reflect the status of op_revC and op_logC.
//-------------------------------------------------------------
Static Function updateColorscales(String pnlName, [int onlyInThisTab])
	//	e.g., pnlName = Graph0#Color
	Wave cw = KMGetCtrlValues(pnlName,"op_revC;op_logC")
	String columnList = ChildWindowList(pnlName), column
	String csNameList, csName, cbName, ctabName

	int i, j, tab

	for (i = 0; i < ItemsInList(columnList); i++)
		column = StringFromList(i,columnList)
		if (WinType(pnlName+"#"+column) != 1)
			continue
		endif

		tab = str2num(StringFromList(1,column,"_"))
		if (!ParamIsDefault(onlyInThisTab) && tab != onlyInThisTab)
			continue
		endif

		csNameList = AnnotationList(pnlName+"#"+column)
		for (j = 0; j < ItemsInList(csNameList); j++)
			csName = StringFromList(j,csNameList)			//	e.g., cs_0_0
			cbName = ReplaceString("cs",csName,"cb")		//	e.g., cb_0_0
			ctabName = GetUserData(pnlName,cbName,"ctabName")
			ColorScale/W=$(pnlName+"#"+column)/C/N=$csName ctab={0,100,$ctabName,cw[0]}, log=cw[1]
		endfor
	endfor
End

//---------------------------------------------------------------------
//	Check a checkbox and uncheck the other checkboxes in the same group
//---------------------------------------------------------------------
Static Function selectCheckBox(String pnlName, String ctrlName)
	if (!strlen(ctrlName))
		return 0
	endif
	CheckBox $ctrlName value=1, win=$pnlName

	String ctrlList = ""
	if (stringmatch(ctrlName,"cb_*"))
		ctrlList = ControlNameList(pnlName,";","cb_*")
	elseif (stringmatch(ctrlName,"op_before*C"))
		ctrlList = ControlNameList(pnlName,";","op_before*C")
	elseif (stringmatch(ctrlName,"op_last*C"))
		ctrlList = ControlNameList(pnlName,";","op_last*C")
	endif
	ctrlList = RemoveFromList(ctrlName,ctrlList)

	int i, n = ItemsInList(ctrlList)
	for (i = 0; i < n; i++)
		Checkbox $StringFromList(i,ctrlList) value=0, win=$pnlName
	endfor
End

//-------------------------------------------------------------
//	Return name of selected checkbox
//-------------------------------------------------------------
Static Function/S findSelectedCheckbox(String pnlName)
	String cbList = ControlNameList(pnlName,";","cb_*")
	Wave cw = KMGetCtrlValues(pnlName, cbList)
	cw *= p
	return StringFromList(sum(cw),cbList)	//	name of the checked checkbox
End

//-------------------------------------------------------------
//	Revert changes and restore colors when the panel was opened
//-------------------------------------------------------------
Static Function revertImageColor(String pnlName)
	String grfName = GetUserData(pnlName,"","grf")
	String imgList = ImageNameList(grfName,";")
	String imgName, infoStr, ctab
	String sepStr = num2char(31)
	STRUCT initParam s
	int i, n

	for (i = 0, n = ItemsInList(imgList); i < n; i++)
		imgName = StringFromList(i,imgList)
		infoStr = GetUserData(pnlName,"",imgName)
		ctab = StringFromList(0,infoStr,sepStr)
		StructGet/S s, StringFromList(1,infoStr,sepStr)

		switch (s.min.mode)
			case 0:
				Make/FREE minRGB = {0}
				break
			case 1:
				Make/FREE minRGB = {s.min.clr.red,s.min.clr.green,s.min.clr.blue}
				break
			case 2:
				Make/FREE minRGB = {NaN}
				break
		endswitch
		switch (s.max.mode)
			case 0:
				Make/FREE maxRGB = {0}
				break
			case 1:
				Make/FREE maxRGB = {s.max.clr.red,s.max.clr.green,s.max.clr.blue}
				break
			case 2:
				Make/FREE maxRGB = {NaN}
				break
		endswitch
		SIDAMColor(grfName=grfName,imgList=imgName,ctable=ctab,rev=s.rev,log=s.log,\
			minRGB=minRGB,maxRGB=maxRGB)
	endfor
End

//-------------------------------------------------------------
//	Return wave of minRGB/maxRGB
//-------------------------------------------------------------
Static Function/WAVE getRGBWave(String pnlName, String mode)
	String list
	strswitch (mode)
		case "minRGB":
			list = "op_beforeUseC;op_beforeClrC;op_beforeTransC"
			break
		case "maxRGB":
			list = "op_lastUseC;op_lastClrC;op_lastTransC"
			break
		default:
			return $""
	endswitch

	Wave cw = KMGetCtrlValues(pnlName, list)
	cw *= p
	switch (sum(cw))
		case 0:
			Make/FREE w={0}
			return w
		case 1:
			ControlInfo/W=$pnlName $StringFromList(1,list)
			Make/FREE w={V_Red,V_Green,V_Blue}
			return w
		case 2:
			Make/FREE w={NaN}
			return w
	endswitch
End

//-------------------------------------------------------------
//	collect parameters from the panel controls
//-------------------------------------------------------------
Static Function collectParamsFromPanel(STRUCT WMButtonAction &s, STRUCT paramStruct &ps)
	ps.grfName = GetUserData(s.win,"","grf")

	Wave cw = KMGetCtrlValues(s.win, "allC;op_revC;op_logC")
	if (cw[0])
		ps.imgList = ImageNameList(ps.grfName,";")
	else
		ControlInfo/W=$s.win imageP
		ps.imgList = S_Value
	endif

	ps.ctable = GetUserData(s.win,findSelectedCheckbox(s.win),"ctabName")
	ps.rev = cw[1]
	ps.log = cw[2]
	Wave ps.minRGB = getRGBWave(s.win,"minRGB")
	Wave ps.maxRGB = getRGBWave(s.win,"maxRGB")
End

//=====================================================================================================
//	Functions to load and kill color table ibw files
//=====================================================================================================
//-----------------------------------------------------------------------
//	Load all color table ibw files
//-----------------------------------------------------------------------
Static Function loadColorTableAll()
	Variable refNum
	int i, j, n

	//	Open ctab.ini if exists. If not, open ctab.default.ini.
	String pathStr = SIDAMPath()+SIDAM_FOLDER_COLOR+":"
	Open/R/Z refNum as (pathStr+SIDAM_FILE_COLORLIST)
	if (V_flag)
		Open/R refNum as (pathStr+SIDAM_FILE_COLORLIST_DEFAULT)
	endif

	//	Read names of tabs and paths to directories from ctab(.default).ini
	Make/N=(2,256)/T/FREE groups		//	256 is expected to be large enough
	String buffer
	n = 0
	do
		FReadLine refNum, buffer
		//	exclude comment
		i = strsearch(buffer,"//",0)
		if (i == 0)
			continue
		elseif (i != -1)
			buffer = buffer[0,i-1]
		else
			buffer = buffer[0,strlen(buffer)-2]	//	remove \r at the end
		endif
		groups[][n++] = {StringFromList(0,buffer),RemoveListItem(0,buffer)}
	while (strlen(buffer))
	Close refNum
	DeletePoints/M=1 n-1,DimSize(groups,1)-n+1,groups

	//	Load ibw files of color table waves
	String path, absPath, dfStr
	String colorTablesAbsPath = SpecialDirPath("Igor Application",0,0,0)+"Color Tables"
	for (i = 0; i < DimSize(groups,1); i++)
		for (j = 0; j < ItemsInList(groups[1][i]); j++)
			path = StringFromList(j,groups[1][i])
			if (GrepString(path,"\$APPLICATION"))
				// "$APPLICATION" is replaced with
				//	SpecialDirPath("Igor Application",0,0,0)+"Color Tables"
				//	Consequently, absPath would be, for example,
				//	C:Program Files:WaveMetrics:Igor Pro 8 Folder:Color Tables:LANL
				absPath = ReplaceString("$APPLICATION",path,colorTablesAbsPath,1)
			else
				//	Other items in SIDAM_CTABGROUPS are supposed to be at
				//	SIDAMPath() + SIDAM_FOLDER_COLOR
				//	Consequently, absPath would be, for example,
				//	***:User Procedures:SIDAM:ctab:SIDAM
				absPath = SIDAMPath() + SIDAM_FOLDER_COLOR + ":" + path
			endif
			//	Datafolder under which ibw files are loaded
			dfStr = SIDAM_DF_CTAB + groups[0][i]
			//	If more than 1 groups are shown in a tab
			if (ItemsInList(groups[1][i]) > 1)
				dfStr += ":"+StringFromList(0,ReplaceString("$APPLICATION:",path,""),":")
			endif
			loadColorTableIbwFiles(dfStr,absPath)
		endfor
	endfor
End

//-----------------------------------------------------------------------
//	Load color table ibw files under a directory given by pathStr
//-----------------------------------------------------------------------
Static Function loadColorTableIbwFiles(String dfStr, String pathStr)
	int i, n

	DFREF dfrSav = GetDataFolderDFR()
	SetDataFolder root:
	for (i = 1, n = ItemsInList(dfStr,":"); i < n; i++)
		NewDataFolder/O/S $StringFromList(i,dfStr,":")
	endfor

	String pathName = UniqueName("path", 12, 0)
	NewPath/Q/Z $pathName, pathStr

	String folderList = IndexedDir($pathName,-1,1), folderPath
	for (i = 0, n = ItemsInList(folderList); i < n; i++)
		folderPath = StringFromList(i,folderList)
		loadColorTableIbwFiles(dfStr+":"+ParseFilePath(0,folderPath,":",1,0),folderPath)
	endfor

	String fileList = IndexedFile($pathName, -1, ".ibw"), fileName
	for (i = 0, n = ItemsInList(fileList); i < n; i++)
		fileName = StringFromList(i, fileList)
		if (!isCtabWave(pathName, fileName))
			continue
		endif
		LoadWave/H/O/P=$pathName/Q fileName
	endfor

	KillPath/Z $pathName
	SetDataFolder dfrSav
End

//-----------------------------------------------------------------------
//	Return whether a ibw file is a color table wave
//-----------------------------------------------------------------------
Static Function isCtabWave(String pathName, String wName)

	Variable refNum
	Open/R/P=$pathName refNum, as wName

	Variable var
	FBinRead/F=1 refNum, var		//	if first 1 byte is 0, then big-endian, otherwise little-endian
	Variable endian = var ? 3 : 2

	STRUCT WaveHeader5 s
	FSetPos refNum, 0
	FBinRead/B=(endian) refNum, s

	Close refNum

	//	type is 16 bit unsigned integer or 32 bit floating point
	int isAllowedType = (s.type & (NT_I16+NT_UNSIGNED)) || (s.type & NT_FP32)
	//	(n x 3) 2D wave
	int isAllowedSize = s.nDim[1] == 3 && s.nDim[2] == 0 && s.nDim[3] == 0

	return isAllowedType && isAllowedSize
End

Static Constant MAXDIMS = 4
Static Constant NT_CMPLX =	1		// Complex numbers.
Static Constant NT_FP32 =		2		// 32 bit fp numbers.
Static Constant NT_FP64 =		4		// 64 bit fp numbers.
Static Constant NT_I8 =		8		// 8 bit signed integer.
Static Constant NT_I16 =		0x10	// 16 bit integer numbers.
Static Constant NT_I32 =		0x20	// 32 bit integer numbers.
Static Constant NT_I64 = 		0x80	// 64-bit integer numbers.
Static Constant NT_UNSIGNED =	0x40	// Makes above signed integers unsigned.
Static Structure WaveHeader5
	char space[80]
	int16 type				// See types (e.g. NT_FP64) above. Zero for text waves.
	char space2[50]
	int32 nDim[MAXDIMS]		// Number of of items in a dimension -- 0 means no data.
EndStructure

//-----------------------------------------------------------------------
//	Kill all unused waves under SIDAM_DF_CTAB
//-----------------------------------------------------------------------
Static Function killUnusedWaves()

	if (!DataFolderExists(SIDAM_DF_CTAB))	//	nothing to do
		return 0
	endif

	//	Kill all unused waves under SIDAM_DF_CTAB
	int numOfDF = killUnusedWavesHelper($SIDAM_DF_CTAB)

	//	If no wave is left under SIDAM_DF_CTAB, kill datafolders
	if (numOfDF == 0)
		int i
		for (i = 0; i < ItemsInlist(SIDAM_DF_CTAB,":")-1; i++)
			KillDataFolder/Z $ParseFilePath(1,SIDAM_DF_CTAB,":",1,i)
			if (V_flag)
				break
			endif
		endfor
		return 0
	endif

	//	If a wave(s) is left under SIDAM_DF_CTAB, set a flag to load color table
	//	waves when the panel is opened next time.
	NVAR/SDFR=$SIDAM_DF_CTAB/Z needUpdate
	if (NVAR_Exists(needUpdate))
		needUpdate = 1
	else
		Variable/G $(SIDAM_DF_CTAB+"needUpdate") = 1
	endif
End

Static Function killUnusedWavesHelper(DFREF dfr)
	int i, n
	DFREF dfrSav = GetDataFolderDFR()
	SetDataFolder dfr

	//	Kill all unused waves in the current datafolder
	KillWaves/A/Z

	//	Kill datafolders in the current datafolder, if possible.
	//	DataFolders containing used waves are left.
	for (i = CountObjectsDFR(dfr,4)-1; i >= 0; i--)
		KillDataFolder/Z $GetIndexedObjNameDFR(dfr,4,i)
	endfor

	//	Call recursively this function for the remaining datafolder
	for (i = 0, n = CountObjectsDFR(dfr,4); i < n; i++)
		killUnusedWavesHelper($GetIndexedObjNameDFR(dfr,4,i))
	endfor

	n = CountObjectsDFR(dfr,4)
	SetDataFolder dfrSav

	return n
End


//=====================================================================================================
//	Backward compatibility
//	Use color table waves instead of color index wave (rev. 944)
//=====================================================================================================
Static Function cindexWave2ctabWave()

	String list0 = fetchWavepathList($(SIDAM_DF_CTAB+"SIDAM"))
	String list1 = fetchWavepathList($(SIDAM_DF_CTAB+"NistView"))
	String list2 = fetchWavepathList($(SIDAM_DF_CTAB+"Wolfram"))
	String ctabWaveList = list0 + ";" + list1 + ";" + list2

	String winNameList = WinList("*",";","WIN:1")
	int i, j, k, ni, nj, nk

	for (i = 0, ni = ItemsInList(winNameList); i < ni; i++)

		String win = StringFromList(i,winNameList)
		String imgList = ImageNameList(win,";")

		for (j = 0, nj = ItemsInList(imgList); j < nj; j++)

			String imgName = StringFromList(j,imgList)
			Wave/Z cindexw = $WM_ImageColorIndexWave(win,imgName)
			if (!WaveExists(cindexw))
				continue
			endif
			String ctabName = StringByKey("name",note(cindexw))

			for (k = 0, nk = ItemsInList(ctabWaveList); k < nk; k++)

				String ctabWavePath = StringFromList(k,ctabWaveList)
				if (CmpStr(ParseFilePath(0,ctabWavePath,":",1,0),ctabName))
					continue
				endif

				//	Convert to the new format
				int rev = NumberByKey("rev",note(cindexw)) & 1	//	Ignore invert
				SIDAMColor(grfName=win,imgList=imgName,ctable=ctabWavePath,rev=rev)

				//	Kill the old color index wave if it is no longer used.
				CheckDisplayed/A cindexw
				if (!V_flag)
					KillWaves cindexw
				endif

			endfor
		endfor
	endfor
End