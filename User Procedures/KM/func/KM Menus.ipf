#pragma TextEncoding="UTF-8"
#pragma rtGlobals=3
#pragma ModuleName=KMMenus

#ifndef KMshowProcedures
#pragma hide = 1
#endif

//******************************************************************************
//	メニューバー用メニュー
//******************************************************************************
Menu "KM", dynamic
	SubMenu "Load Data..."
		"Load Data...", /Q, KMLoadData("",history=1)
		help = {"Loads data from binary/text files into Igor waves."}
		
		"Load Data From a Folder...", /Q, KMLoadDataFromFolder()
		help = {"Loads all data in a folder."}
	End
	
	Submenu "Display..."
		KMDisplay#menu(0)+"/F3", /Q, KMDisplay(history=1)
		help = {"Display a wave(s)"}
		
		KMDisplay#menu(1), /Q, KMDisplay(w=$GetBrowserSelection(0),traces=1,history=1)
		help = {"Display a 2D wave as traces"}
		
		KMInfoBar#menu()+"/F8", /Q, KMInfoBar("")
		help = {"Show information bar at the top of image graph."}
	End
	
	"-"
	
	"Preference", /Q, KMPrefsPnl()
	
	Submenu "Help"
		"Command List", /Q, BrowseURL KM_URL_CMD;KillVariables/Z V_Flag
		help = {"Shows a list of KM commands"}
		
		"Cheet sheet of shortcuts", /Q, BrowseURL KM_URL_SHORTCUTS;KillVariables/Z V_Flag
		
		"-"
		
		"Change log", /Q, BrowseURL KM_URL_LOG;KillVariables/Z V_Flag
		help = {"Shows change log of KM"}
		
		KMCheckUpdateMenu(), /Q, KMCheckUpdate()
	End
	
	Submenu "Extension"
	End
	
	"-"
	
	Submenu "Nanonis tools"
		"Make a log wave of 3ds files", /Q, KMNanonis3dsLog("",history=1)
		KMLoadNanonisSXMNSP#menu(), /Q, KMNanonisConcatMultipass(GetDataFolderDFR(),history=1)
	End	
	
	Submenu "Developer"
		KMShowProc#menu(), /Q, KMShowProcedures()
		"Kill Variables", /Q, KMKillVariablesStrings(root:)
		help = {"Kill \"V_*\" variables and \"S_*\" strings"}
	End
	
	"-"
	
	//	Exit or Restart
	KMMenus#mainMenuStrExit(0), /Q, KMMenus#KMExit()
	help = {KMMenus#mainMenuStrExit(1)}
End

//-------------------------------------------------------------
//	補助関数
//-------------------------------------------------------------
//	メニュー文字列、終了もしくは再起動
Static Function/S mainMenuStrExit(int mode)
	return SelectString(GetKeyState(0) && 0x04, "Exit", "Restart") + SelectString(mode, " KM", "s Kohsaka Macro")
End

//	マクロ終了
Static Function KMExit()
	GetLastUserMenuInfo
	int isRestart = !CmpStr(S_value, "Restart KM")
	
	SetIgorHook/K BeforeFileOpenHook = KMFileOpenHook
	SetIgorHook/K AfterCompiledHook = KMAfterCompiledHook
	SetIgorHook/K BeforeExperimentSaveHook = KMBeforeExperimentSaveHook
	Execute/P/Q/Z "DELETEINCLUDE \""+KM_FILE_INCLUDE+"\""
	Execute/P/Q/Z "SetIgorOption poundUndefine=KMshowProcedures"
	Execute/P/Q/Z "COMPILEPROCEDURES "
	Execute/P/Q/Z "BuildMenu \"All\""
	KillPath/Z KMMain
	KillPath/Z KMCtab		//	backward compatibility
	KillPath/Z KMHelp		//	backward compatibility
	
	if (isRestart)
		KM()
	endif
End


//******************************************************************************
//	右クリック用メニュー (2,3次元)
//******************************************************************************
Menu "KMRightClickCtrlBar", dynamic, contextualmenu
	//	Range
	SubMenu "Range"
		help = {"Adjust of z range of images in the active graph."}
		"Manual.../F4",/Q, KMRange()
		"-"
		KMRange#rightclickMenu(2), /Q, KMRange#rightclickDo(2)
		KMRange#rightclickMenu(3), /Q, KMRange#rightclickDo(3)
	End
	
	"Color Table.../F5",/Q, KMColor()
	help = {"Change the color table used to display the top image in the active graph."}
	
	SubMenu "Sync"
		//	Sync Layers
		KMMenus#rMenuStr("Sync Layers...",dim=3), /Q, KMSyncLayer#rightclickDo()
		help = {"Syncronize layer index of LayerViewers"}
		//	Sync Axis Range
		KMMenus#rMenuStr("Sync Axis Range..."), /Q, KMSyncAxisRange#rightclickDo()
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
		//	Auto Annotation of LayerViewer
		KMLayerViewer#rightclickMenu(1), /Q, KMLayerViewer#rightclickDo(1)
		//	Show/Hide Axis
		KMInfoBar#rightclickMenu(2), /Q, KMInfoBar#rightclickDo(2)
		help = {"Show/Hide axes of the graph."}
	End
	
	SubMenu "\\M0Save/Export Graphics"
		"Save Graphics...", DoIgorMenu "File", "Save Graphics"
		KMSaveGraphics#rightclickMenu(), /Q, KMSaveGraphics#rightclickDo()
		KMSaveMovie#rightclickMenu(), /Q, KMSaveMovie#rightclickDo()
		
		"-"
		
		"\\M0Export Graphics (Transparent)", /Q, KMExportGraphicsTransparent()
	End
	
	"-"
	
	//	View spectra of LayerViewer
	KMMenus#rMenuStr("Point Spectrum...", dim=3), /Q, KMSpectrumViewer#rightclickDo()
	KMMenus#rMenuStr("Line Spectra...", dim=3), /Q, KMLineSpectra#rightclickDo()
	//	Line Profile
	KMMenus#rMenuStr("Line Profile..."),/Q, KMLineProfile#rightclickDo()
	help = {"Make a line profile wave of the image in the active graph."}
	
	
	"-"
	
	//	Subtraction
	KMMenus#rMenuStr("Subtract...")+"/F6", /Q, KMSubtraction#rightclickDo()
	help = {"Subtract n-th plane or line from a 2D wave or each layer of a 3D wave"}
	//	Histogram
	KMMenus#rMenuStr("Histogram..."),/Q, KMHistogram#rightclickDo()
	help = {"Compute the histogram of a source wave."}
	SubMenu "Fourier"
		//	Fourier Transform
		SelectString(KMFFTCheckWaveMenu(), "", "(")+"Fourier Transform.../F7", /Q, KMFFT#rightclickDo()
		help = {"Compute a Fourier transform of a source wave."}
		//	Fourier filter
		SelectString(KMFFTCheckWaveMenu(), "", "(")+"Fourier Filter...", /Q, KMFourierFilter#rightclickDo()
		help = {"Apply a Fourier filter to a source wave"}
		//	Fourier Symmetrization
		KMMenus#rMenuStr("Fourier Symmetrization...", noComplex=1), /Q, KMFourierSym#rightclickDo()
		help = {"Symmetrize a FFT image"}
	End
	
	//	Correlation
	SelectString(KMFFTCheckWaveMenu(), "", "(")+"Correlation...", /Q, KMCorrelation#rightclickDo()
	help = {"Compute a correlation function of a source wave(s)."}
	//	Stats
	KMMenus#rMenuStr("Stats...", dim=3), /Q, KMWavesStats#rightclickDo()
	help = {"Compute statistics of waves."}
	//	Work Function
	KMMenus#rMenuStr("Work Function...", dim=3), /Q,  KMWorkfunctionR()
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
//	補助関数
//-------------------------------------------------------------
Static Function/S rMenuStr(String str, [int noComplex, int dim])
	
	noComplex = ParamIsDefault(noComplex) ? 0 : noComplex
	
	String grfName = WinName(0,1)
	if (!strlen(grfName))
		return "(" + str
	endif
	Wave/Z w = KMGetImageWaveRef(grfName)
	if (!WaveExists(w))
		return "(" + str
	endif
	
	//	LayerViewerにのみ表示する場合
	if (!ParamIsDefault(dim) && dim==3 && WaveDims(w)!=3)
		return ""
	endif
	
	//	複素数ウエーブを除外
	if (noComplex)
		return SelectString((WaveType(w) & 0x01), "", "(") + str
	endif
	
	return str
End

//******************************************************************************
//	右クリック用メニュー (1次元)
//******************************************************************************
Menu "KMRightClickCtrlBar1D", dynamic, contextualmenu
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
		
		"\\M0Export Graphics (Transparent)", /Q, KMExportGraphicsTransparent()
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
//	マーキーメニュー
//******************************************************************************
Menu "GraphMarquee", dynamic
	KMSubtraction#marqueeMenu(),/Q, KMSubtraction#marqueeDo()
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
