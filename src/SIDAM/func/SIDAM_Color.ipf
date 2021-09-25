#pragma TextEncoding="UTF-8"
#pragma rtGlobals=3
#pragma ModuleName=SIDAMColor

#include "SIDAM_Preference"
#include "SIDAM_Utilities_Control"
#include "SIDAM_Utilities_ImageInfo"
#include "SIDAM_Utilities_Panel"
#include "SIDAM_Utilities_WaveDf"

#ifndef SIDAMshowProc
#pragma hide = 1
#endif

#include <WMImageInfo>


//@
//	Set a color table to a image or a list of images.
//
//	## Parameters
//	grfName : string, default `WinName(0,1,1)`
//		The name of a window.
//	imgList : string, default `ImageNameList(WinName(0,1,1),";")`
//		The list of images. A single image is also accepted.
//	ctable : string
//		The name of a color table or path to a color table wave.
//		Unless specified, the present value is used.
//	rev : int {0 or !0}
//		Set !0 to reverse the color table.
//		Unless specified, the present value is used.
//	log : int {0 or !0}
//		Set !0 to use logarithmically-spaced colors.
//		Unless specified, the present value is used.
//	minRGB, maxRGB : wave
//		Set the color for values less than the minimum/maximum value of the range.
//		Unless specified, the present value is used.
//		- {0} : use the color for the minimum/maximum value of the range.
//		- {NaN} : transparent.
//		- {r,g,b} : specify the color.
//	history : int {0 or !0}, default 0
//		Set !0 to print this command in the history.
//
//	## Returns
//	variable
//		* 0: Normal exit
//		* !0: Any error in input parameters
//@
Function SIDAMColor([String grfName, String imgList, String ctable, int rev,
	int log, Wave minRGB, Wave maxRGB, int history])

	STRUCT paramStruct s
	s.grfName = SelectString(ParamIsDefault(grfName), grfName, WinName(0,1,1))
	s.imgList = SelectString(ParamIsDefault(imgList), imgList, ImageNameList(s.grfName,";"))
	
	STRUCT paramStruct ds
	ds.grfName = s.grfName
	ds.imgList = s.imgList
	defaultValues(ds)
	
	s.ctable = SelectString(ParamIsDefault(ctable), ctable, ds.ctable)
	s.rev = ParamIsDefault(rev) ? ds.rev : rev
	s.log = ParamIsDefault(log) ? ds.log : log
	if (ParamIsDefault(minRGB))
		Wave s.min.w = ds.min.w
	else
		Wave s.min.w = minRGB
	endif
	if (ParamIsDefault(maxRGB))
		Wave s.max.w = ds.max.w
	else
		Wave s.max.w = maxRGB
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

	int i, n = ItemsInList(s.imgList), flag = 0
	for (i = 0; i < n; i++)
		flag += applyColorTable(s,i)
	endfor

	return flag
End

Static Structure paramStruct
	String grfName
	String imgList
	String ctable
	Variable rev
	Variable log
	STRUCT paramSubStruct min
	STRUCT paramSubStruct max
	String errMsg
EndStructure

Static Structure paramSubStruct
	uchar mode
	Wave w
	STRUCT RGBColor clr
EndStructure

Static Function defaultValues(STRUCT paramStruct &s)
	String imgName = StringFromList(0, s.imgList)
	s.ctable = WM_ColorTableForImage(s.grfName, imgName)
	s.rev = WM_ColorTableReversed(s.grfName, imgName)
	s.log = SIDAM_ColorTableLog(s.grfName, imgName)

	STRUCT RGBColor color
	Make/N=1/FREE zerow = {0}, nanw = {NaN}
	s.min.mode = SIDAM_ImageColorRGBMode(s.grfName, imgName, "minRGB")
	s.max.mode = SIDAM_ImageColorRGBMode(s.grfName, imgName, "maxRGB")
	switch (s.min.mode)
		case 0:
			Wave s.min.w = zerow
			break
		case 1:
			SIDAM_ImageColorRGBValues(s.grfName, imgName, "minRGB", color)
			Make/N=3/FREE colorw = {color.red, color.green, color.blue}
			Wave s.min.w = colorw
			break
		case 2:
			Wave s.min.w = nanw
			break
		default:
			Wave s.min.w = zerow
	endswitch

	switch (s.max.mode)
		case 0:
			Wave s.max.w = zerow
			break
		case 1:
			SIDAM_ImageColorRGBValues(s.grfName, imgName, "maxRGB", color)
			Make/N=3/FREE colorw = {color.red, color.green, color.blue}
			Wave s.max.w = colorw
			break
		case 2:
			Wave s.max.w = nanw
			break
		default:
			Wave s.max.w = zerow
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
			SIDAMColorKillWaves()	//	Kill waves loaded for this check
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

	if (numpnts(s.min.w) == 3)
		s.min.mode = 1
	elseif (numtype(s.min.w[0]))
		s.min.mode = 2
	else
		s.min.mode = 0
	endif

	if (numpnts(s.max.w) == 3)
		s.max.mode = 1
	elseif (numtype(s.max.w[0]))
		s.max.mode = 2
	else
		s.max.mode = 0
	endif

	return 0
End

Static Function printHistory(STRUCT paramStruct &s, STRUCT paramStruct &base)
	String str0 = "", str1 = ""
	if (CmpStr(s.ctable,base.ctable))
		if (strsearch(s.ctable, SIDAM_DF_CTAB, 0) == -1)
			str0 += ",ctable=\""+s.ctable+"\""
		else
			str0 += ",ctable=SIDAM_DF_CTAB+\""+ReplaceString(SIDAM_DF_CTAB, s.ctable, "")+"\""
		endif
	endif
	str0 += SelectString(s.rev==base.rev,",rev="+num2istr(s.rev),"")
	str0 += SelectString(s.log==base.log,",log="+num2istr(s.log),"")
	if (WaveExists(s.min.w) && !WaveExists(base.min.w))
		str0 += SelectString(equalWaves(s.min.w,base.min.w,1),",minRGB="+SIDAMWaveToString(s.min.w),"")
	endif
	if (WaveExists(s.max.w) && !WaveExists(base.max.w))
		str0 += SelectString(equalWaves(s.max.w,base.max.w,1),",maxRGB="+SIDAMWaveToString(s.max.w),"")
	endif
	if (!strlen(str0))
		return 0
	endif

	str1 += SelectString(CmpStr(s.grfName,base.grfName),"",",grfName=\""+s.grfName+"\"")
	str1 += SelectString(CmpStr(s.imgList,base.imgList),"",",imgList=\""+s.imgList+"\"")
	str1 += str0
	printf "%sSIDAMColor(%s)\r", PRESTR_CMD, str1[1,inf]
End

//	Apply color table to an image in the list
Static Function applyColorTable(STRUCT paramStruct &s, int i)

	String imgName = StringFromList(i, s.imgList)
	Variable zmin, zmax
	Variable flag = SIDAM_GetColorTableMinMax(s.grfName, imgName, zmin, zmax, allowNaN=1)
	if (GetRTError(1) || flag)
		printf "%sSIDAMColor gave error: present z-range can not be obtained.\r", PRESTR_CAUTION
		printf "%sA color index wave may be used.\r", PRESTR_CAUTION
		return 1
	endif

	if (numtype(zmin)==2 && numtype(zmax)==2)
		ModifyImage/W=$s.grfName $imgName ctab={*,*,$s.ctable,s.rev}, log=s.log
	elseif (numtype(zmin)==2)
		ModifyImage/W=$s.grfName $imgName ctab={*,zmax,$s.ctable,s.rev}, log=s.log
	elseif (numtype(zmax)==2)
		ModifyImage/W=$s.grfName $imgName ctab={zmin,*,$s.ctable,s.rev}, log=s.log
	else
		ModifyImage/W=$s.grfName $imgName ctab={zmin,zmax,$s.ctable,s.rev}, log=s.log
	endif

	switch (s.min.mode)
		case 0:
		case 2:
			ModifyImage/W=$s.grfName $imgName minRGB=s.min.w[0]
			break
		case 1:
			ModifyImage/W=$s.grfName $imgName minRGB=(s.min.w[0],s.min.w[1],s.min.w[2])
			break
	endswitch

	switch (s.max.mode)
		case 0:
		case 2:
			ModifyImage/W=$s.grfName $imgName maxRGB=s.max.w[0]
			break
		case 1:
			ModifyImage/W=$s.grfName $imgName maxRGB=(s.max.w[0],s.max.w[1],s.max.w[2])
			break
	endswitch

	return 0
End


//==============================================================================
//	Panel
//==============================================================================
//	Positions of region for color tables
Static Constant leftMargin = 160
Static Constant topMargin = 50
Static Constant bottomMargin = 5

//	Height of group boxes of options, before first color, and after last color
Static Constant optionBoxHeight = 70
Static Constant colorBoxHeight = 90

//	Width of a single column
Static Constant columnWidth = 230

//	Number of color tables in a column
Static Constant ctabsInColumn = 28

//	Size of a color table
Static Constant ctabHeight = 14
Static Constant ctabWidth = 87

//	Margin between color tables
Static Constant ctabMargin = 2

//	Margin between color tables and checkboxes in a column
Static Constant checkBoxMargin = 5

//	Width of option button + gap
Static Constant separatorWidth = 22

//******************************************************************************
//	Display a panel
//******************************************************************************
Static Function pnl(String grfName)
	String targetWin = StringFromList(0,grfName,"#")
	if (SIDAMWindowExists(targetWin+"#Color"))
		return 0
	endif

	String imgName = StringFromList(0,ImageNameList(grfName,";"))
	int needUpdate = DataFolderExists(SIDAM_DF_CTAB) ? \
		NumVarOrDefault(SIDAM_DF_CTAB+"needUpdate",1) : 1
	int i, n
	STRUCT SIDAMPrefs prefs
	SIDAMLoadPrefs(prefs)
	int isOpen = prefs.color != 0

	//	Display a panel
	int pnlwidth = (isOpen ? leftMargin : separatorWidth)+columnWidth*2
	int pnlHeight = topMargin+(ctabHeight+ctabMargin)*ctabsInColumn+bottomMargin
	NewPanel/EXT=0/HOST=$targetWin/W=(0,0,pnlWidth,pnlHeight)/K=1
	RenameWindow $targetWin#$S_name, Color
	String pnlName = targetWin + "#Color"

	SetWindow $pnlName hook(self)=SIDAMColor#pnlHook
	SetWindow $pnlName userData(grf)=grfName, activeChildFrame=0
	//	grfName can be a subwindow such as "Panel0#image" (LineProfile, LineSpectra)
	//	The hook function for the parent window must be given to the main window.
	SetWindow $StringFromList(0,grfName,"#") hook(SIDAMColorPnl)=SIDAMColor#pnlHookParent

	saveInitialColor(pnlName)

	//	Controls (top)
	PopupMenu imageP pos={7,7},size={235,19},bodyWidth=200,title="image",win=$pnlName
	String cmdStr = "PopupMenu imageP proc=SIDAMColor#pnlPopup,value="
	sprintf cmdStr, "%s#\"ImageNameList(\\\"%s\\\", \\\";\\\")\",win=%s", cmdStr, grfName, pnlName
	Execute/Q cmdStr
	CheckBox allC pos={258,9},title=" all",value=0,win=$pnlName
	Button doB pos={310,6},size={70,22},title="Do It",proc=SIDAMColor#pnlButton,win=$pnlName
	Button cancelB pos={386,6},size={70,22},title="Cancel",proc=SIDAMColor#pnlButton,win=$pnlName

	//	Controls (left)
	Button optionB title=SelectString(isOpen,"\u25B6","\u25C0"), win=$pnlName
	Button optionB pos={(leftMargin-separatorWidth)*isOpen,topMargin}, win=$pnlName
	Button optionB size={16,(ctabHeight+ctabMargin)*ctabsInColumn}, win=$pnlName
	Button optionB userData(status)=num2istr(isOpen), proc=SIDAMColor#pnlButton,win=$pnlName

	Variable boxesTop = pnlHeight-((colorBoxHeight+5)*2+optionBoxHeight+5)
	GroupBox op_revlogG pos={5,boxesTop},title="Options",win=$pnlName
	GroupBox op_revlogG size={leftMargin-35,optionBoxHeight},win=$pnlName
	CheckBox op_revC pos={14,boxesTop+21},title=" Reverse Colors",win=$pnlName
	CheckBox op_logC pos={14,boxesTop+45},title=" Log Colors",win=$pnlName

	Variable base = boxesTop + optionBoxHeight + 5
	GroupBox op_beforeG pos={5,base},title="Before First Color",win=$pnlName
	GroupBox op_beforeG size={leftMargin-35,colorBoxHeight},win=$pnlName
	CheckBox op_beforeUseC pos={14,base+20},title=" Use First Color",mode=1,win=$pnlName
	CheckBox op_beforeClrC pos={14,base+44},title="",mode=1,win=$pnlName
	CheckBox op_beforeTransC pos={14,base+66},title=" Transparent",mode=1,win=$pnlName
	PopupMenu op_beforeClrP pos={32,base+42},value=#"\"*COLORPOP*\"",win=$pnlName

	base += colorBoxHeight + 5
	GroupBox op_lastG pos={5,base},title="After Last Color",win=$pnlName
	GroupBox op_lastG size={leftMargin-35,colorBoxHeight},win=$pnlName
	CheckBox op_lastUseC pos={14,base+20},title=" Use Last Color",mode=1,win=$pnlName
	CheckBox op_lastClrC pos={14,base+44},title="",mode=1,win=$pnlName
	CheckBox op_lastTransC pos={14,base+66},title=" Transparent",mode=1,win=$pnlName
	PopupMenu op_lastClrP pos={32,base+42},value=#"\"*COLORPOP*\"",win=$pnlName

	ModifyControlList ControlNameList(pnlName,";","*C") proc=SIDAMColor#pnlCheckRadio, win=$pnlName
	ModifyControlList "allC;op_revC;op_logC" proc=SIDAMColor#pnlCheck, win=$pnlName
	ModifyControlList ControlNameList(pnlName,";","*P") mode=1, proc=SIDAMColor#pnlPopup, win=$pnlName
	ModifyControlList "op_beforeClrP;op_lastClrP" size={40,19},bodyWidth=40,win=$pnlName
	ModifyControlList ControlNameList(pnlName,";","op_*") disable=!isOpen, win=$pnlName

	//	Update controls involved with rev, log, mixRGB, and maxRGB
	updateOptionCheckboxes(pnlName,imgName)

	//	Listbox of color table groups
	String ctabgroupList = "Igor;" + SIDAM_CTAB
	Variable activegroup = findGroup(grfName,imgName)
	Variable listHeight = boxesTop - topMargin - 10
	DFREF dfrSav = GetDataFolderDFR()
	SetDataFolder $SIDAMNewDF("",ParseFilePath(0,SIDAM_DF_CTAB,":",1,0))
	Make/T/O/N=(ItemsInList(ctabgroupList)) ctabgroup=StringFromList(p,ctabgroupList)
	ListBox ctabgroupL pos={5,topMargin}, size={leftMargin-40,listHeight},frame=0, win=$pnlName
	ListBox ctabgroupL mode=2, listWave=ctabgroup, selRow=activegroup, win=$pnlName
	ListBox ctabgroupL disable=!isOpen, proc=SIDAMColor#pnlList, win=$pnlName
	TitleBox groupT pos={separatorWidth,30}, title=ctabgroup[activegroup], win=$pnlName
	TitleBox groupT frame=0, fstyle=1, disable=prefs.color, win=$pnlName
	SetDataFolder dfrSav

	int ctabLeftPos = isOpen ? leftMargin : separatorWidth
	DefineGuide/W=$pnlname ctabL = {FL, ctabLeftPos}
	DefineGuide/W=$pnlName ctabT = {FT, topMargin}
	DefineGuide/W=$pnlName ctabB = {FB, -bottomMargin}

	if (needUpdate)
		showLoading(pnlName,isOpen)
		loadColorTableAll()
		Variable/G $(SIDAM_DF_CTAB+"needUpdate") = 0
		//	Backward compatibility
		//	Old color index waves may be used since new color table waves were not used
		cindexWave2ctabWave()
	endif

	Wave cw = SIDAMGetCtrlValues(pnlName,"op_revC;op_logC")
	pnlGroupComponents(pnlName, activegroup, rev=cw[0], log=cw[1],\
		selected=SIDAM_ColorTableForImage(grfName,imgName))

	if (needUpdate)
		deleteLoading(pnlName)
	endif
	DoUpdate/W=$pnlName

	//	Create the other groups
	for (i = 0, n = ItemsInList(SIDAM_CTAB)+1; i < n; i++)
		if (i == activegroup)
			continue
		endif
		pnlGroupComponents(pnlName, i, hide=1, rev=cw[0], log=cw[1])
	endfor
	SetActiveSubwindow ##
	ModifyControlList ControlNameList(pnlName,";","*") focusRing=0,win=$pnlName

	SetActiveSubwindow $grfName
End

//-----------------------------------------------------------------------
//	Show an overlay when waves are being loaded
//-----------------------------------------------------------------------
Static Function showLoading(String pnlName, int isOpen)
	String name = "loading"
	Variable top = topMargin
	Variable bottom = topMargin+(ctabHeight+ctabMargin)*ctabsInColumn+10
	Variable left = isOpen ? leftMargin : separatorWidth
	Variable right = left + columnWidth*2

	DrawAction/L=Overlay/W=$pnlName getgroup=$name

	SetDrawLayer/W=$pnlName Overlay
	SetDrawEnv/W=$pnlName gname=$name, gstart

	SetDrawEnv/W=$pnlName fillfgc=(0,0,0,32768),linethick=0
	DrawRect/W=$pnlName left,top,right,bottom

	SetDrawEnv/W=$pnlName textrgb=(65535,65535,65535), textxjust=1, textyjust=1
	DrawText/W=$pnlName (left+right)/2,(top+bottom)/2,"Now loading..."

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
//	Create components in each group
//-----------------------------------------------------------------------
Static Function pnlGroupComponents(String pnlName, int group, [int hide, int rev, int log, String selected])
	hide = ParamIsDefault(hide) ? 0 : hide
	rev = ParamIsDefault(rev) ? 0 : rev
	log = ParamIsDefault(log) ? 0 : log
	selected = SelectString(ParamIsDefault(selected),selected,"")

	String list
	if (group == 0)	//	Igor
		//	Igor's list. Some color scales have 2 tables, 100 and 256.
		//	Do not list 100 ones.
		list = RemoveFromList("Grays;Rainbow;YellowHot;BlueHot;BlueRedGreen;"\
			+"RedWhiteBlue;PlanetEarth;Terrain;", CTabList())
	else
		//	Color table waves
		DFREF dfr = $(SIDAM_DF_CTAB+PossiblyQuoteName(StringFromList(group-1,SIDAM_CTAB)))
		list = fetchWavepathList(dfr)
	endif
	int i, n
	ControlInfo/W=$pnlName kwBackgroundColor

	String subPnlName = "P_"+num2istr(group)
	NewPanel/HOST=$pnlName/FG=(ctabL, ctabT, FR, ctabB)/HIDE=(hide)
	ModifyPanel/W=$pnlName#P0 frameStyle=0
	RenameWindow $pnlName#P0 $subPnlName

	DefineGuide/W=$pnlName#$subPnlName ctab0R = {FL, ctabWidth}
	DefineGuide/W=$pnlname#$subPnlName ctab1L = {FL, columnWidth}
	DefineGuide/W=$pnlName#$subPnlName ctab1R = {FL, columnWidth+ctabWidth}

	Display/HOST=$pnlName#$subPnlName
	MoveSubWindow/W=$pnlName#$subPnlName#G0 fguide=(FL, FT, ctab0R, FB)
	ModifyGraph/W=$pnlName#$subPnlName#G0 gbRGB=(V_Red,V_Green,V_Blue), wbRGB=(V_Red,V_Green,V_Blue)

	Display/HOST=$pnlName#$subPnlName
	MoveSubWindow/W=$pnlName#$subPnlName#G1 fguide=(ctab1L, FT, ctab1R, FB)
	ModifyGraph/W=$pnlName#$subPnlName#G1 gbRGB=(V_Red,V_Green,V_Blue), wbRGB=(V_Red,V_Green,V_Blue)

	String subWinNameFull, ctabName, colorscaleName, checkboxName, titleName
	Variable left, top
	for (i = 0, n = ItemsInList(list); i < n; i++)
		subWinNameFull = pnlName+"#"+subPnlName+"#G"+num2istr(floor(i/ctabsInColumn))
		ctabName = StringFromList(i, list)
		colorscaleName = "cs_"+num2istr(group)+"_"+num2istr(i)
		ColorScale/W=$subWinNameFull/N=$colorscaleName/F=0/A=LT/X=0/Y=(mod(i,ctabsInColumn)/ctabsInColumn*100)
		ColorScale/W=$subWinNameFull/C/N=$colorscaleName widthPct=100,height=ctabHeight,vert=0,nticks=0,tickLen=0
		ColorScale/W=$subWinNameFull/C/N=$colorscaleName ctab={0,100,$ctabName,rev}, log=log

		//	Checkboxes are displayed in the panel
		//	The title of checkbox is
		//	(1) name of color table for Igor Pro's table
		//	(2) name of wave for color table waves
		checkboxName = "cb_"+num2istr(group)+"_"+num2istr(i)
		titleName = ParseFilePath(0, StringFromList(i, list), ":", 1, 0)
		left = ctabWidth+checkBoxMargin+columnWidth*floor(i/ctabsInColumn)
		top = (ctabHeight+ctabMargin)*mod(i,ctabsInColumn)
		CheckBox $checkboxName pos={left,top}, title=" "+titleName, win=$pnlName#$subPnlName
		CheckBox $checkboxName proc=SIDAMColor#pnlCheckCtab, userData(ctabName)=ctabName, win=$pnlName#$subPnlName
		CheckBox $checkboxName mode=1, help={titleName}, focusRing=0, win=$pnlName#$subPnlName
		CheckBox $checkboxName value=CmpStr(ctabName,selected)==0, win=$pnlName#$subPnlName
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
	String list = "", str

	for (i = 0, n = CountObjectsDFR(dfr, 4), str=""; i < n; i++)
		str += fetchWavepathList(dfr:$GetIndexedObjNameDFR(dfr, 4, i))
	endfor
	list += SortList(str)

	for (i = 0, n = CountObjectsDFR(dfr, 1), str=""; i < n; i++)
		Wave/SDFR=dfr w = $GetIndexedObjNameDFR(dfr, 1, i)
		str += GetWavesDataFolder(w,2) + ";"
	endfor
	list += SortList(str)

	return list
End

//-----------------------------------------------------------------------
//	Return group number where the present color scale is included
//-----------------------------------------------------------------------
Static Function findGroup(String grfName, String imgName)
	String ctab = SIDAM_ColorTableForImage(grfName,imgName)
	if (strsearch(ctab,":",0) == -1)	//	Igor
		return 0
	endif
	String groupName = StringFromList(ItemsInList(SIDAM_DF,":")+1,ctab,":")
	return WhichListItem(groupName,SIDAM_CTAB)+1
End

//-----------------------------------------------------------------------
//	Return name of checkbox corresponding to the color scale
//	used for imgName in pnlName
//-----------------------------------------------------------------------
Static Function/S findCheckBox(String pnlName, String imgName)
	String grfName = GetUserData(pnlName,"","grf")
	String ctabName = SIDAM_ColorTableForImage(grfName,imgName)

	Wave/T checkBoxListWave = ListToTextWave(checkBoxNameList(pnlName),";")
	Make/T/N=(numpnts(checkBoxListWave))/FREE ctabNameListWave
	ctabNameListWave = GetUserData(pnlName+"#P_"+StringFromList(1,checkBoxListWave[p],"_"),checkBoxListWave[p],"ctabName")
	FindValue/TEXT=ctabName/TXOP=2 ctabNameListWave
	if (V_Value==-1)
		return ""
	else
		return checkBoxListWave[V_Value]
	endif
End

Static Function/S checkBoxNameList(String pnlName)
	String childPnlList = ChildWindowList(pnlName), childPnlName
	String list = ""
	int i, n
	for (i = 0, n = ItemsInList(childPnlList); i < n; i++)
		childPnlName = pnlName + "#" + StringFromList(i,childPnlList)
		list += ControlNameList(childPnlName,";","cb_*")
	endfor
	return list
End

//---------------------------------------------------------------------------
//	Save the initial state when the panel is opened, to userData of the panel
//---------------------------------------------------------------------------
Static Structure paramStructLite
	uchar rev
	uchar log
	STRUCT paramSubStructLite min
	STRUCT paramSubStructLite max
EndStructure

Static Structure paramSubStructLite
	uchar mode
	STRUCT RGBColor clr
EndStructure

Static Function saveInitialColor(String pnlName)
	String grfName = GetUserData(pnlName,"","grf")
	String imgList = ImageNameList(grfName,";")
	String imgName, ctabName, str
	String sepStr = num2char(31)
	STRUCT paramStructLite s
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
			pnlHookClose(s.winName)
			break

		case 11:	//	keyboard
			//	s.winName can be a subwindow of the color panel.
			String pnlName = StringFromList(0,s.winName,"#")+"#Color"
			switch (s.keycode)
				case 27:	//	esc
					pnlHookClose(pnlName)
					KillWindow $pnlName
					break
				case 28:	//	left
				case 29:	//	right
				case 30:	//	up
				case 31:	//	down
					pnlHookArrows(pnlName, s.keycode)
					break
			endswitch
			break

		case 22:	//	mouseWheel
			pnlHookWheel(s)
			break
	endswitch
End

Static Function pnlHookClose(String pnlName)
	SetWindow $StringFromList(0,pnlName,"#") hook(SIDAMColorPnl)=$""
	if (!strlen(GetUserData(pnlName,"","norevert")))
		revertImageColor(pnlName)
	endif
End

Static Function pnlHookArrows(String pnlName, int keycode)
	int presentGroup, presentBox
	ControlInfo/W=$pnlName imageP
	String cbName = findCheckBox(pnlName, S_Value)
	if (!strlen(cbName))	//	no checkbox is checked
		return 0
	endif
	sscanf cbName, "cb_%d_%d", presentGroup, presentBox

	ControlInfo/W=$pnlName ctabgroupL
	Wave/T/SDFR=$S_DataFolder ctabgroup
	int numOfGroups = numpnts(ctabgroup)
	int isLastGroup = presentGroup==numOfGroups-1
	int isInLeft = presentBox < ctabsInColumn
	int isAtTop = mod(presentBox,ctabsInColumn)==0
	int isAtBottom = presentBox==ctabsIncolumn-1 || presentBox==numOfCheckBoxes(pnlName,presentGroup)-1

	//	get new group and checkbox
	int nextGroup, nextBox
	switch (keycode)
		case 28:	//	left
			if (isInLeft)
				return 0
			endif
			nextGroup = presentGroup
			nextBox = presentBox - ctabsInColumn
			break
		case 29:	//	right
			if (!isInLeft)
				return 0
			endif
			nextGroup = presentGroup
			nextBox = presentBox + ctabsInColumn
			break
		case 30:	//	up
			if (isAtTop)
				if (!presentGroup)
					return 0
				endif
				nextGroup = presentGroup - 1
				if (isInLeft)
					nextBox = min(ctabsInColumn,numOfCheckBoxes(pnlName,nextGroup))-1
				else
					nextBox = numOfCheckBoxes(pnlName,nextGroup)-1
				endif
			else
				nextGroup = presentGroup
				nextBox = presentBox - 1
			endif
			break
		case 31:	//	down
			if (isAtBottom)
				if (isLastGroup)
					return 0
				endif
				nextGroup = presentGroup + 1
				nextBox = (!isInLeft && isDoubleColumns(pnlName,nextGroup)) ? ctabsInColumn : 0
			elseif (!isAtBottom)
				nextGroup = presentGroup
				nextBox = presentBox + 1
			endif
			break
	endswitch

	cbName = "cb_"+num2istr(nextGroup)+"_"+num2istr(nextBox)
	SIDAMClickCheckBox(pnlName+"#P_"+num2istr(nextGroup), cbName)
	selectGroup(pnlName, nextGroup)
End

Static Function numOfCheckBoxes(String pnlName, int group)
	return ItemsInList(ControlNameList(pnlName+"#P_"+num2istr(group),";","cb_*"))
End

Static Function isDoubleColumns(String pnlName, int group)
	return numOfCheckBoxes(pnlName,group) > ctabsInColumn
End

Static Function pnlHookWheel(STRUCT WMWinHookStruct &s)
	String pnlName = s.winName
	if (ItemsInList(pnlName,"#") > 2)		//	when the mouse cursor in a subwindow
		pnlName = RemoveEnding(ParseFilePath(1,s.winName,"#",0,2),"#")
	endif
	ControlInfo/W=$pnlName ctabgroupL
	int newGroup = V_Value-sign(s.wheelDy)	//	move to the right group by scrolling down
	if (newGroup >= 0 && newGroup <= ItemsInList(SIDAM_CTAB))
		ListBox ctabgroupL selRow=newGroup, win=$pnlName
		selectGroup(pnlName, newGroup)
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

	//	s.winName can be "Graph0" or "Panel0#image".
	String pnlName = StringFromList(0, s.winName, "#") + "#Color"
	ControlInfo/W=$pnlName imageP
	String imgName = S_Value

	selectCheckBox(pnlName, findCheckBox(pnlName,imgName))
	updateOptionCheckboxes(pnlName,imgName)
	updateColorscalesInPnl(pnlName)
End


//******************************************************************************
//	Controls
//******************************************************************************
//	ListBox
Static Function pnlList(STRUCT WMListboxAction &s)
	if (s.eventCode != 4)	//	Cell selection only (mouse or arrow keys)
		return 0
	endif
	Wave/T lw = s.listWave
	if (s.row >= DimSize(lw,0))
		return 0
	endif
	selectGroup(s.win, s.row)
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

		case "op_revC":
		case "op_logC":
			String grfName = GetUserData(s.win,"","grf")
			String imgList = targetImageList(s.win)
			if (CmpStr(s.ctrlName,"op_revC"))
				SIDAMColor(grfName=grfName, imgList=imgList, log=s.checked)
			else
				SIDAMColor(grfName=grfName, imgList=imgList, rev=s.checked)
			endif
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
	endswitch

	return 0
End

//	Checkbox (color table buttons)
Static Function pnlCheckCtab(STRUCT WMCheckboxAction &s)
	if (s.eventCode != 2)
		return 0
	endif

	//	call this to uncheck all checkboxes in the same group
	selectCheckBox(s.win, s.ctrlName)

	//	s.win = Graph0#Color#P_0
	//	pnlName = Graph0#Color
	String pnlName = RemoveEnding(ParseFilePath(1,s.win,"#",1,0),"#")
	String grfName = GetUserData(pnlName,"","grf")
	String imgList = targetImageList(pnlName)
	SIDAMColor(grfName=grfName, imgList=imgList, ctable=GetUserData(s.win,s.ctrlName,"ctabName"))
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
			selectGroup(s.win, str2num(StringFromList(1,cbName,"_")))
			updateOptionCheckboxes(s.win,s.popStr)
			updateColorscalesInPnl(s.win)
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
			break
		case "doB":
			SetWindow $s.win userData(norevert)="1"
			printHistoryAfterPressingButton(s.win)
			break
		case "optionB":
			int isOpen = CmpStr(GetUserData(s.win,s.ctrlName,"status"),"0")
			int left = leftMargin*(1-isOpen)+separatorWidth*isOpen
			int pnlwidth = left + columnWidth*2
			int pnlHeight = topMargin+(ctabHeight+ctabMargin)*ctabsInColumn+bottomMargin
			if(isOpen)
				Button $s.ctrlName title="\u25B6", pos+={separatorWidth-leftMargin,0}, userData(status)="0", win=$s.win
			else
				Button $s.ctrlName title="\u25C0", pos+={leftMargin-separatorWidth,0}, userData(status)="1", win=$s.win
			endif
			TitleBox groupT disable=!isOpen, win=$s.win
			ListBox ctabgroupL disable=isOpen, win=$s.win
			ModifyControlList ControlNameList(s.win,";","op_*") disable=isOpen, win=$s.win
			DefineGuide/W=$s.win ctabL = {FL, left}
			MoveSubWindow/W=$s.win fnum=(0,0,pnlwidth,pnlHeight)
			STRUCT SIDAMPrefs prefs
			SIDAMLoadPrefs(prefs)
			prefs.color = !isOpen
			SIDAMSavePrefs(prefs)
			return 0
		default:
			return 0
	endswitch
	KillWindow $(s.win)

	return 0
End

//******************************************************************************
//	Helper funcitons for control
//******************************************************************************
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
//	Show color tables and checkboxes of the selected group,
//	and hide the others
//-------------------------------------------------------------
Static Function selectGroup(String pnlName, int group)
	ListBox ctabgroupL selRow=group, win=$pnlName
	ControlInfo/W=$pnlName ctabgroupL
	Wave/T/SDFR=$S_DataFolder ctabgroup
	TitleBox groupT title=ctabgroup[group], win=$pnlName

	int i, n, index
	String subPnlList = ChildWindowList(pnlName), subPnlName
	//	This function can be called when only one subpanel exists in the main
	//	color panel. Therefore, the panel index has to be explicitly confirmed
	//	as follows.
	for (i = 0, n = ItemsInList(subPnlList); i < n; i++)
		subPnlName = StringFromList(i,subPnlList)
		sscanf subPnlName, "P_%d", index
		SetWindow $pnlName#$subPnlName hide=(index!=group)
	endfor

	DoUpdate/W=$pnlName	//	to prevent some color scales are weirdly left
End

//-------------------------------------------------------------
//	Update color scales of all images
//-------------------------------------------------------------
Static Function updateAllImaeges(STRUCT  WMCheckboxAction &s)
	String grfName = GetUserData(s.win,"","grf")
	String imgList = ImageNameList(grfName,";")
	String ctable = findSelectedColortable(s.win)
	Wave cw = SIDAMGetCtrlValues(s.win,"op_revC;op_logC")

	STRUCT paramStruct ps
	getRGBFromPanel(s.win, ps)
	SIDAMColor(grfName=grfName, imgList=imgList, ctable=ctable, rev=cw[0],\
		log=cw[1], minRGB=ps.min.w, maxRGB=ps.max.w)
End

//--------------------------------------------------------------------
//	Update the control about rev, log, minRGB, and maxRGB in the panel
//	so that they reflect the status of the image.
//--------------------------------------------------------------------
Static Function updateOptionCheckboxes(String pnlName, String imgName)
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
Static Function updateColorscalesInPnl(String pnlName)
	Wave cw = SIDAMGetCtrlValues(pnlName,"op_revC;op_logC")
	String subPnlList = ChildWindowList(pnlName)	//	P_0, P_1, ...
	int i, n
	for (i = 0, n = ItemsInList(subPnlList); i < n; i++)
		updateColorscalesInSubpnl(pnlName+"#"+StringFromList(i,subPnlList),cw[0],cw[1])
	endfor
End

Static Function updateColorscalesInSubpnl(String subPnlNameFull, int rev, int log)
	//	e.g., subPnlNameFull = Graph0#Color#P_0
	String columnList = ChildWindowList(subPnlNameFull)	//	G0, G1
	String columnNameFull
	String colorscaleList, colorscaleName, checkboxName, ctabName
	int i, j, ni, nj

	for (i = 0, ni = ItemsInList(columnList); i < ni; i++)
		columnNameFull = subPnlNameFull+"#"+StringFromList(i,columnList)
		colorscaleList = AnnotationList(columnNameFull)
		for (j = 0, nj = ItemsInList(colorscaleList); j < nj; j++)
			colorscaleName = StringFromList(j,colorscaleList)		//	e.g., cs_0_0
			checkboxName = ReplaceString("cs",colorscaleName,"cb")	//	e.g., cb_0_0
			ctabName = GetUserData(subPnlNameFull,checkboxName,"ctabName")
			ColorScale/W=$columnNameFull/C/N=$colorscaleName ctab={0,100,$ctabName,rev}, log=log
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

	if (stringmatch(ctrlName,"cb_*"))
		selectCtabCheckBox(pnlName, ctrlName)
		return 0
	endif

	String ctrlList = ""
	if (stringmatch(ctrlName,"op_before*C"))
		ctrlList = ControlNameList(pnlName,";","op_before*C")
	elseif (stringmatch(ctrlName,"op_last*C"))
		ctrlList = ControlNameList(pnlName,";","op_last*C")
	endif
	ctrlList = RemoveFromList(ctrlName,ctrlList)

	int i, n = ItemsInList(ctrlList)
	for (i = 0; i < n; i++)
		Checkbox $StringFromList(i,ctrlList) value=0, win=$pnlName
	endfor
	CheckBox $ctrlName value=1, win=$pnlName
End

Static Function selectCtabCheckBox(String pnlName, String ctrlName)
	String clrPnlName, ctabPnlName
	if (ItemsInList(pnlName,"#") == 3)
		//	pnlName = Graph0#Color#P_0
		clrPnlName = RemoveEnding(ParseFilePath(1,pnlName,"#",1,0),"#")
		ctabPnlName = pnlName
	else
		//	pnlName = Graph0#Color
		clrPnlName = pnlName
		ctabPnlName = pnlName + "#P_" + StringFromList(1,ctrlName,"_")
	endif

	String childPnlList = ChildWindowList(clrPnlName), childPnlName
	String ctrlList
	int i, j, ni, nj

	for (i = 0, ni = ItemsInList(childPnlList); i < ni; i++)
		childPnlName = clrPnlName + "#" + StringFromList(i,childPnlList)
		ctrlList = ControlNameList(childPnlName,";","cb_*")
		for (j = 0, nj = ItemsInList(ctrlList); j < nj; j++)
			CheckBox $StringFromList(j,ctrlList) value=0, win=$childPnlName
		endfor
	endfor
	CheckBox $ctrlName value=1, win=$ctabPnlName
End

//-------------------------------------------------------------
//	Return path to selected color table wave
//-------------------------------------------------------------
Static Function/S findSelectedColortable(String pnlName)
	String cbList = ControlNameList(pnlName,";","cb_*")
	Wave/Z cw = SIDAMGetCtrlValues(pnlName, cbList)
	if (numpnts(cw) > 0)
		WaveStats/Q/M=1 cw
		if (V_max)
			String cbName = StringFromList(V_maxloc,cbList)
			return GetUserData(pnlName,cbName,"ctabName")
		endif
	endif
	
	String childWinList = ChildWindowList(pnlName)
	String ctable = ""
	int i
	for (i = 0; i < ItemsInList(childWinList); i++)
		ctable = findSelectedColortable(pnlName+"#"+StringFromList(i,childWinList))
		if (strlen(ctable))
			break
		endif
	endfor
	return ctable
End

//-------------------------------------------------------------
//	Revert changes and restore colors when the panel was opened
//-------------------------------------------------------------
Static Function revertImageColor(String pnlName)
	String grfName = GetUserData(pnlName,"","grf")
	String imgList = ImageNameList(grfName,";")
	String imgName, infoStr, ctab
	String sepStr = num2char(31)
	STRUCT paramStructLite init
	int i, n

	for (i = 0, n = ItemsInList(imgList); i < n; i++)
		imgName = StringFromList(i,imgList)
		infoStr = GetUserData(pnlName,"",imgName)
		ctab = StringFromList(0,infoStr,sepStr)
		StructGet/S init, StringFromList(1,infoStr,sepStr)
		Wave/WAVE ww = makeRGBWave(init)
		SIDAMColor(grfName=grfName, imgList=imgName, ctable=ctab, rev=init.rev,\
			log=init.log, minRGB=ww[0], maxRGB=ww[1])
	endfor
End

Static Function/WAVE makeRGBWave(STRUCT paramStructLite &s)
	switch (s.min.mode)
		case 0:
			Make/FREE minRGB = {0}
			break
		case 1:
			Make/FREE minRGB = {s.min.clr.red, s.min.clr.green, s.min.clr.blue}
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
			Make/FREE maxRGB = {s.max.clr.red, s.max.clr.green, s.max.clr.blue}
			break
		case 2:
			Make/FREE maxRGB = {NaN}
			break
	endswitch
	Make/N=2/WAVE/FREE ww = {minRGB, maxRGB}
	return ww
End

Static Function getRGBFromPanel(String pnlName, STRUCT paramStruct &s)
	getRGBFromPanelHelper(pnlName, s, 0)
	getRGBFromPanelHelper(pnlName, s, 1)
End

Static Function getRGBFromPanelHelper(String pnlName, STRUCT paramStruct &s, int mode)
	String list
	if (mode == 0)
		list = "op_beforeUseC;op_beforeClrC;op_beforeTransC"
	else
		list = "op_lastUseC;op_lastClrC;op_lastTransC"
	endif

	Wave cw = SIDAMGetCtrlValues(pnlName, list)
	cw *= p
	if (mode == 0)
		s.min.mode = sum(cw)
	else
		s.max.mode = sum(cw)
	endif

	switch (sum(cw))
		case 0:
			Make/FREE w={0}
			break
		case 1:
			ControlInfo/W=$pnlName $StringFromList(mode,"op_beforeClrP;op_lastClrP")
			Make/FREE w={V_Red,V_Green,V_Blue}
			break
		case 2:
			Make/FREE w={NaN}
			break
	endswitch

	if (mode == 0)
		Wave s.min.w = w
	else
		Wave s.max.w = w
	endif
End

Static Function printHistoryAfterPressingButton(String pnlName)

	STRUCT paramStruct s
	s.grfName = GetUserData(pnlName,"","grf")

	STRUCT paramStruct base
	base.grfName = s.grfName

	ControlInfo/W=$pnlName allC
	if (V_Value)
		findChangedParameters(pnlName,s,base)
		printHistory(s,base)
		return 0
	endif

	String imgList = ImageNameList(s.grfName,";"), imgName
	int i
	for (i = 0; i < ItemsInList(imgList); i++)
		imgName = StringFromList(i,imgList)
		s.imgList = imgName
		fetchPresentParameters(s)
		base.imgList = ""	//	force to print imgName if there is a change
		fetchInitParameters(GetUserData(pnlName,"",imgName), base)
		printHistory(s,base)
	endfor
End

Static Function findChangedParameters(String pnlName, STRUCT paramStruct &s,
	STRUCT paramStruct &base)

	//	Collect the parameters selected in the panel
	s.imgList = ImageNameList(s.grfName,";")
	s.ctable = findSelectedColortable(pnlName)
	Wave cw = SIDAMGetCtrlValues(pnlName, "op_revC;op_logC")
	s.rev = cw[0]
	s.log = cw[1]
	getRGBFromPanel(pnlName,s)

	base.ctable = s.ctable
	base.rev = s.rev
	base.log = s.log
	Wave/Z base.min.w = s.min.w
	Wave/Z base.max.w = s.max.w
	
	//	Search for initial values of all images. If a parameter is different
	//	from one chosen in the panel, the parameter has to be shown as the
	//	command parameter.
	int i
	String infoStr, ctable, sepStr = num2char(31)
	STRUCT paramStructLite init

	base.imgList = s.imgList
	for (i = 0; i < ItemsInList(s.imgList); i++)
		infoStr = GetUserData(pnlName,"",StringFromList(i,s.imgList))
		ctable = StringFromList(0,infoStr,sepStr)
		if (CmpStr(s.ctable, ctable))
			base.ctable = ""
		endif
		StructGet/S init, StringFromList(1,infoStr,sepStr)
		if (s.rev != init.rev)
			base.rev = NaN
		endif
		if (s.log != init.log)
			base.log = NaN
		endif
		Wave/WAVE ww = makeRGBWave(init)
		if (!equalWaves(s.min.w,ww[0],1))
			Wave/Z base.min.w = $""
		endif
		if (!equalWaves(s.max.w,ww[1],1))
			Wave/Z base.max.w = $""
		endif
	endfor
End

Static Function fetchPresentParameters(STRUCT paramStruct &s)

	String	imgName = s.imgList
	s.ctable = SIDAM_ColorTableForImage(s.grfName,imgName)
	s.rev = WM_ColorTableReversed(s.grfName,imgName)
	s.log = SIDAM_ColorTableLog(s.grfName,imgName)
	STRUCT paramStructLite present
	present.min.mode = SIDAM_ImageColorRGBMode(s.grfName,imgName,"minRGB")
	present.max.mode = SIDAM_ImageColorRGBMode(s.grfName,imgName,"maxRGB")
	Wave/WAVE ww = makeRGBWave(present)
	Wave s.min.w = ww[0], s.max.w = ww[1]
End

Static Function fetchInitParameters(String infoStr, STRUCT paramStruct &s)

	String sepStr = num2char(31)
	s.ctable = StringFromList(0,infoStr,sepStr)
	STRUCT paramStructLite init
	StructGet/S init, StringFromList(1,infoStr,sepStr)
	s.rev = init.rev
	s.log = init.log
	s.min.mode = init.min.mode
	s.max.mode = init.max.mode
	Wave/WAVE ww = makeRGBWave(init)
	Wave s.min.w = ww[0], s.max.w = ww[1]
End


//=====================================================================================================
//	Functions to load and kill color table ibw files
//=====================================================================================================
//-----------------------------------------------------------------------
//	Load all color table ibw files
//-----------------------------------------------------------------------
Static Function loadColorTableAll()
	int i, j, n

	//	Read names of groups and paths to directories
	String key
	Make/N=(2,ItemsInList(SIDAM_CTAB))/T/FREE groups
	for (j = 0; j < ItemsInList(SIDAM_CTAB); j++)
		key = StringFromList(j, SIDAM_CTAB)
		groups[][j] = {key, StringByKey(key, SIDAM_CTAB_PATH, \
			SIDAM_CHAR_KEYSEP, SIDAM_CHAR_ITEMSEP)}
	endfor

	//	Load ibw files of color table waves
	String path, absPath, dfStr
	for (i = 0; i < DimSize(groups,1); i++)
		for (j = 0; j < ItemsInList(groups[1][i]); j++)
			path = StringFromList(j,groups[1][i])
			//	Datafolder under which ibw files are loaded
			dfStr = SIDAM_DF_CTAB + groups[0][i]
			//	If more than 1 groups are shown in a group
			if (ItemsInList(groups[1][i]) > 1)
				dfStr += ":"+ParseFilePath(0,path,":",1,0)
			endif
			loadColorTableIbwFiles(dfStr,path)
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
		divide3Dto1D($StringFromList(0,S_waveNames),n!=1)
	endfor

	KillPath/Z $pathName
	SetDataFolder dfrSav
End

Static Function divide3Dto1D(Wave w, int makesubdir)
	if (WaveDims(w) != 3)
		return 0
	endif

	DFREF dfrSav = GetDataFolderDFR()
	if (makesubdir)
		NewDataFolder/O/S $NameOfWave(w)
	endif

	int i, nz = DimSize(w,2)
	for (i = 0; i < nz; i++)
		Duplicate/O/R=[][][i] w $GetDimLabel(w,2,i)/WAVE=lw
		Redimension/N=(-1,-1) lw
	endfor
	KillWaves w
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
	//	(n x 3) 2D wave, or (n x 3 x m) 3D wave
	int isAllowedSize = s.nDim[1] == 3 && s.nDim[3] == 0

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
Function SIDAMColorKillWaves()
	int status = SIDAMKillDataFolder($SIDAM_DF_CTAB)
	if (status != 3)
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
