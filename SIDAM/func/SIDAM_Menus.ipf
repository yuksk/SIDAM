#pragma TextEncoding="UTF-8"
#pragma rtGlobals=3
#pragma ModuleName=SIDAMMenus

#ifndef SIDAMshowProc
#pragma hide = 1
#endif

//******************************************************************************
//	Definition of main menu in the menu bar
//******************************************************************************
Menu "SIDAM", dynamic
	SubMenu "Load Data..."
		"Load Data...", /Q, SIDAMLoadData("", history=1)
		help = {"Loads data from binary/text files into Igor waves."}
		
		"Load Data From a Folder...", /Q, SIDAMLoadData("", folder=1, history=1)
		help = {"Loads all data in a folder."}
	End
	
	Submenu "Display..."
		KMPreview#menu("/F3"), /Q, KMPreviewPnl()
		help = {"Display a preview panel"}
		
		SIDAMDisplay#menu(0,"/F3"), /Q, SIDAMDisplay#menuDo()
		help = {"Display a wave(s)"}
		
		SIDAMDisplay#menu(1,""), /Q, SIDAMDisplay($GetBrowserSelection(0),traces=1,history=1)
		help = {"Display a 2D wave as traces"}
		
		KMInfoBar#menu()+"/F8", /Q, KMInfoBar("")
		help = {"Show information bar at the top of image graph."}
	End
	
	"-"
	
	"Preference", /Q, SIDAMPrefsPnl()
	
	Submenu "Help"
		"Command List", /Q, SIDAMOpenExternalHelp(SIDAM_FILE_CMD)
		help = {"Shows a list of KM commands"}
		
		"Cheet sheet of shortcuts", /Q, SIDAMOpenExternalHelp(SIDAM_FILE_SHORTCUTS)
	End
	
	Submenu "Extension"
	End
	
	"-"
	
	Submenu "Nanonis tools"
		"Make a log wave of 3ds files", /Q, KMNanonis3dsLog("",history=1)
		KMLoadNanonisSXMNSP#menu(), /Q, KMNanonisConcatMultipass(GetDataFolderDFR(),history=1)
	End	
	
	Submenu "Developer"
		SIDAMShowProcedures#menu(), /Q, SIDAMshowProcedures()
		"Kill Variables", /Q, SIDAMKillVariablesStrings(root:)
		help = {"Kill \"V_*\" variables and \"S_*\" strings"}
	End
	
	"-"
	
	//	Exit or Restart
	SIDAMMenus#Exitmenu(), /Q, SIDAMMenus#Exit()
End

//-------------------------------------------------------------
//	Exit or restart SIDAM
//-------------------------------------------------------------
Static Function/S Exitmenu()
	//	"Restart" when the shift key is pressed
	return SelectString(GetKeyState(0) && 0x04, "Exit", "Restart") + " SIDAM"
End

Static Function Exit()
	GetLastUserMenuInfo
	int isRestart = !CmpStr(S_value, "Restart SIDAM")
	
	sidamExit()
	
	if (isRestart)
		sidam()
	endif
End


//******************************************************************************
//	Definition of right-click menu for 2D/3D waves
//******************************************************************************
Menu "SIDAMMenu2D3D", dynamic, contextualmenu
	//	Range
	SubMenu "Range"
		help = {"Adjust of z range of images in the active graph."}
		"Manual.../F4",/Q, KMRange()
		"-"
		KMRange#rightclickMenu(2), /Q, KMRange#rightclickDo(2)
		KMRange#rightclickMenu(3), /Q, KMRange#rightclickDo(3)
	End
	
	"Color Table.../F5",/Q, SIDAMColor()
	help = {"Change the color table used to display the top image in the active graph."}
	
	SubMenu "Sync"
		//	Sync Layers
		SIDAMMenus#menu("Sync Layers...",dim=3), /Q, KMSyncLayer#rightclickDo()
		help = {"Syncronize layer index of LayerViewers"}
		//	Sync Axis Range
		SIDAMMenus#menu("Sync Axis Range..."), /Q, KMSyncAxisRange#rightclickDo()
		help = {"Syncronize axis range"}
		//	Sync Cursors
		KMSyncCursor#rightclickMenu(), /Q, KMSyncCursor#rightclickDo()
		help = {"Synchronize cursor positions in graphs showing images"}
	End
	
	SubMenu "Window"
		SubMenu "Coordinates"
			KMInfoBar#rightclickMenu(0), /Q,  KMInfoBar#rightclickDo(0)
		End
		SubMenu "Title"
			KMInfoBar#rightclickMenu(1), /Q,  KMInfoBar#rightclickDo(1)
		End
		SubMenu "Complex"
			KMInfoBar#rightclickMenu(3), /Q,  KMInfoBar#rightclickDo(3)
		End
		"Scale Bar...", /Q, KMScaleBar#rightclickDo()
		"Layer Annotation...", /Q, SIDAMLayerAnnotation#rightclickDo()
		//	Show/Hide Axis
		KMInfoBar#rightclickMenu(2), /Q, KMInfoBar#rightclickDo(2)
		help = {"Show/Hide axes of the graph."}
	End
	
	SubMenu "\\M0Save/Export Graphics"
		"Save Graphics...", DoIgorMenu "File", "Save Graphics"
		SIDAMSaveGraphics#rightclickMenu(), /Q, SIDAMSaveGraphics#rightclickDo()
		SIDAMSaveMovie#rightclickMenu(), /Q, SIDAMSaveMovie#rightclickDo()
		
		"-"
		
		"\\M0Export Graphics (Transparent)", /Q, SIDAMExportGraphicsTransparent()
	End
	
	"-"
	
	//	View spectra of LayerViewer
	SIDAMMenus#menu("Point Spectrum...", dim=3), /Q, KMSpectrumViewer#rightclickDo()
	SIDAMMenus#menu("Line Spectra...", dim=3), /Q, KMLineSpectra#rightclickDo()
	//	Line Profile
	SIDAMMenus#menu("Line Profile..."),/Q, KMLineProfile#rightclickDo()
	help = {"Make a line profile wave of the image in the active graph."}
	
	
	"-"
	
	//	Subtraction
	SIDAMMenus#menu("Subtract...")+"/F6", /Q, SIDAMSubtraction#menuDo()
	help = {"Subtract n-th plane or line from a 2D wave or each layer of a 3D wave"}
	//	Histogram
	SIDAMMenus#menu("Histogram..."),/Q, KMHistogram#rightclickDo()
	help = {"Compute the histogram of a source wave."}
	SubMenu "Fourier"
		//	Fourier Transform
		SelectString(KMFFTCheckWaveMenu(), "", "(")+"Fourier Transform.../F7", /Q, KMFFT#rightclickDo()
		help = {"Compute a Fourier transform of a source wave."}
		//	Fourier filter
		SelectString(KMFFTCheckWaveMenu(), "", "(")+"Fourier Filter...", /Q, KMFourierFilter#rightclickDo()
		help = {"Apply a Fourier filter to a source wave"}
		//	Fourier Symmetrization
		SIDAMMenus#menu("Fourier Symmetrization...", noComplex=1), /Q, KMFourierSym#rightclickDo()
		help = {"Symmetrize a FFT image"}
	End
	
	//	Correlation
	SelectString(KMFFTCheckWaveMenu(), "", "(")+"Correlation...", /Q, KMCorrelation#rightclickDo()
	help = {"Compute a correlation function of a source wave(s)."}
	//	Stats
	SIDAMMenus#menu("Stats...", dim=3), /Q, KMWavesStats#rightclickDo()
	help = {"Compute statistics of waves."}
	//	Work Function
	SIDAMMenus#menu("Work Function...", dim=3), /Q,  KMWorkfunctionR()
	help = {"Compute work function."}
	
	"-"
	
	"Position Recorder", /Q, KMPositionRecorder#rightclickDo()
	
	
	"-"
	
	//	Extract Layers of LayerViewer
	KMLayerViewer#rightclickMenu(0), /Q, KMLayerViewer#rightclickDo(0)
	//	"Data Parameters"
	KMShowParameters#rightclickMenu(), /Q, KMShowParameters()
	
	"-"
	
	"Close Infobar", /Q, KMInfoBar(WinName(0,1))
End
//-------------------------------------------------------------
//	conditional menu
//-------------------------------------------------------------
Static Function/S menu(String str, [int noComplex, int dim])
	noComplex = ParamIsDefault(noComplex) ? 0 : noComplex
	
	String grfName = WinName(0,1)
	if (!strlen(grfName))
		return "(" + str
	endif
	Wave/Z w = KMGetImageWaveRef(grfName)
	if (!WaveExists(w))
		return "(" + str
	endif
	
	//	return empty for 2D waves
	if (!ParamIsDefault(dim) && dim==3 && WaveDims(w)!=3)
		return ""
	endif
	
	//	gray out for complex waves
	if (noComplex)
		return SelectString((WaveType(w) & 0x01), "", "(") + str
	endif
	
	return str
End


//******************************************************************************
//	Definition of right-click menu for 1D waves
//******************************************************************************
Menu "SIDAMMenu1D", dynamic, contextualmenu
	//	Trace
	"Offset and Color...", /Q, KMTrace#rightclickDo()
	help = {"Set offset of traces in the top graph."}
	
	SubMenu "Sync"
		//	Sync Axis Range
		"Sync Axis Range...", /Q, KMSyncAxisRangeR()
		help = {"Syncronize axis range"}
	End
	
	SubMenu "Window"
		SubMenu "Coordinates"
			 KMInfoBar#rightclickMenu(0), /Q,  KMInfoBar#rightclickDo(0)
		End
		SubMenu "Complex"
			KMInfoBar#rightclickMenu(4), /Q,  KMInfoBar#rightclickDo(4)
		End
	End
	
	SubMenu "\\M0Save/Export Graphics"
		"Save Graphics...", DoIgorMenu "File", "Save Graphics"
		
		"-"
		
		"\\M0Export Graphics (Transparent)", /Q, SIDAMExportGraphicsTransparent()
	End
	
	"-"
	
	//	Work Function
	"Work Function...", /Q,  KMWorkfunctionR()
	help = {"Compute work function."}
	
	"-"
	
	//	"Data Parameters"
	KMShowParameters#rightclickMenu(), /Q, KMShowParameters()
	
	"-"
	
	"Close Infobar", /Q, KMInfoBar(WinName(0,1))
End


//******************************************************************************
//	Definition of graph marquee menu
//******************************************************************************
Menu "GraphMarquee", dynamic
	SIDAMSubtraction#marqueeMenu(),/Q, SIDAMSubtraction#marqueeDo()
	KMFourierSym#marqueeMenu(),/Q, KMFourierSym#marqueeDo()
	Submenu "Get peak"
		KMFourierPeak#marqueeMenu(0), /Q, KMFourierPeak#marqueeDo(0)
		KMFourierPeak#marqueeMenu(1), /Q, KMFourierPeak#marqueeDo(1)
	End
	Submenu "Erase peak"
		KMFourierPeak#marqueeMenu(0), /Q, KMFourierPeak#marqueeDo(2)
		KMFourierPeak#marqueeMenu(1), /Q, KMFourierPeak#marqueeDo(3)
	End
End


//******************************************************************************
//	Utilities
//******************************************************************************
//	Add the check mark to num-th item of menuStr and return it
Function/S SIDAMAddCheckmark(Variable num, String menuStr)
	if (numtype(num))
		return ""
	elseif (num < 0)
		return menuStr
	endif
	
	String checked = "\\M0:!" + num2char(18)+":", escCode = "\\M0"
	
	//	add escCode before all items
	menuStr = ReplaceString(";", menuStr, ";"+escCode)
	menuStr = escCode + RemoveEnding(menuStr, escCode)
	
	//	replace escCode of num-item with the check mark
	menuStr = AddListItem(checked, menuStr, ";", num)
	return ReplaceString(":;"+escCode, menuStr, ":")
End
