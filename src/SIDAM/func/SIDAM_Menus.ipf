#pragma TextEncoding="UTF-8"
#pragma rtGlobals=3
#pragma ModuleName=SIDAMMenus

#include "SIDAM_Color"
#include "SIDAM_Compatibility_Old_Functions"
#include "SIDAM_Config"
#include "SIDAM_Correlation"
#include "SIDAM_Display"
#include "SIDAM_ExtractLayer"
#include "SIDAM_FFT"
#include "SIDAM_Fourier_Filter"
#include "SIDAM_Fourier_Symmetrization"
#include "SIDAM_Histogram"
#include "SIDAM_InfoBar"
#include "SIDAM_LayerAnnotation"
#include "SIDAM_LineProfile"
#include "SIDAM_LineSpectra"
#include "SIDAM_LoadData"
#include "SIDAM_PeakPos"
#include "SIDAM_Position_Recorder"
#include "SIDAM_Range"
#include "SIDAM_Subtraction"
#include "SIDAM_SaveGraphics"
#include "SIDAM_SaveMovie"
#include "SIDAM_ScaleBar"
#include "SIDAM_ShowParameters"
#include "SIDAM_SpectrumViewer"
#include "SIDAM_StartExit"
#include "SIDAM_SyncAxisRange"
#include "SIDAM_SyncCursor"
#include "SIDAM_SyncLayer"
#include "SIDAM_Trace"
#include "SIDAM_Utilities_Help"
#include "SIDAM_Utilities_Image"
#include "SIDAM_Utilities_WaveDf"
#include "SIDAM_Utilities_misc"
#include "SIDAM_Workfunction"

#ifndef SIDAMshowProc
#pragma hide = 1
#endif

//******************************************************************************
//	Definition of main menu in the menu bar
//******************************************************************************
Menu "SIDAM", dynamic
	SubMenu "Load Data..."
		"from a File...;from a Directory...", /Q, SIDAMLoadData("", history=1)
		help = {"Load data from a file or directory."}
	End

	Submenu "Display..."
		SIDAMDisplay#menu(0,"/F3"), /Q, SIDAMDisplay#menuDo()
		help = {"Display a wave(s)"}

		SIDAMDisplay#menu(1,""), /Q, SIDAMDisplay($GetBrowserSelection(0),traces=1,history=1)
		help = {"Display a 2D wave as 1d-traces"}

		SIDAMDisplay#menu(2,""), /Q, SIDAMDisplay($GetBrowserSelection(0),traces=2,history=1)
		help = {"Display a 2D wave as xy-traces"}
		
		SIDAMInfoBar#menu()+"/F8", /Q, SIDAMInfoBar("")
		help = {"Show information bar at the top of image graph."}
	End

	"-"

	Submenu "Misc"
		"Open configuration file", /Q, OpenNoteBook/ENCG=1/Z SIDAMConfigPath(0)
	End
	
	Submenu "Help"
		"SIDAM home page", /Q, SIDAMBrowseHelp("home")
		"-"
		"Browse command help", /Q, SIDAMBrowseHelp("commands")
		"Browse cheat sheet of shortcuts", /Q, SIDAMBrowseHelp("shortcuts")
		"-"
		"About SIDAM...", /Q, SIDAMAbout()
		"Update for SIDAM...", /Q, SIDAMCheckUpdate()
	End

	Submenu "Developer"
		SIDAMUtilMisc#menu(), /Q, SIDAMshowProcedures()
		"List of Deprecated Functions", /Q, print SIDAMDeprecatedFunctions()
		help = {"Show a list of deprecated functions in the history area"}
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
		"Manual.../F4",/Q, SIDAMRange()
		"-"
		SIDAMRange#menu(2), /Q, SIDAMRange#menuDo(2)
		SIDAMRange#menu(3), /Q, SIDAMRange#menuDo(3)
	End

	"Color Table.../F5",/Q, SIDAMColor()
	help = {"Change the color table used to display the top image in the active graph."}

	SubMenu "Sync"
		//	Sync Layers
		SIDAMMenus#menu("Sync Layers...",dim=3), /Q, SIDAMSyncLayer#menuDo()
		help = {"Syncronize layer index of LayerViewers"}
		//	Sync Axis Range
		SIDAMMenus#menu("Sync Axis Range..."), /Q, SIDAMSyncAxisRange#menuDo()
		help = {"Syncronize axis range"}
		//	Sync Cursors
		SIDAMSyncCursor#menu(), /Q, SIDAMSyncCursor#menuDo()
		help = {"Synchronize cursor positions in graphs showing images"}
	End

	SubMenu "Window"
		SubMenu "Coordinates"
			SIDAMInfoBar#menuR(0), /Q,  SIDAMInfoBar#menuRDo(0)
		End
		SubMenu "Title"
			SIDAMInfoBar#menuR(1), /Q,  SIDAMInfoBar#menuRDo(1)
		End
		SubMenu "Complex"
			SIDAMInfoBar#menuR(3), /Q,  SIDAMInfoBar#menuRDo(3)
		End
		"Scale Bar...", /Q, SIDAMScaleBar#menuDo()
		SIDAMMenus#menu("Layer Annotation...",dim=3), /Q, SIDAMLayerAnnotation#menuDo()
		//	Show/Hide Axis
		SIDAMInfoBar#menuR(2), /Q, SIDAMInfoBar#menuRDo(2)
		help = {"Show/Hide axes of the graph."}
	End

	SubMenu "\\M0Save/Export Graphics"
		"Save Graphics...", DoIgorMenu "File", "Save Graphics"
		SIDAMSaveGraphics#menu(), /Q, SIDAMSaveGraphics#menuDo()
		SIDAMSaveMovie#menu(), /Q, SIDAMSaveMovie#menuDo()

		"-"

		"\\M0Export Graphics (Transparent)", /Q, SIDAMExportGraphicsTransparent()
	End

	"-"

	//	View spectra of LayerViewer
	SIDAMMenus#menu("Point Spectrum...", dim=3), /Q, SIDAMSpectrumViewer#menuDo()
	SIDAMMenus#menu("Line Spectra...", dim=3), /Q, SIDAMLineSpectra#menuDo()
	//	Line Profile
	SIDAMMenus#menu("Line Profile..."),/Q, SIDAMLineProfile#menuDo()
	help = {"Make a line profile wave of the image in the active graph."}


	"-"

	//	Subtraction
	SIDAMMenus#menu("Subtract...")+"/F6", /Q, SIDAMSubtraction#menuDo()
	help = {"Subtract n-th plane or line from a 2D wave or each layer of a 3D wave"}
	//	Histogram
	SIDAMMenus#menu("Histogram..."),/Q, SIDAMHistogram#menuDo()
	help = {"Compute the histogram of a source wave."}
	SubMenu "Fourier"
		//	Fourier Transform
		SIDAMMenus#menu("Fourier Transform...", forfft=1)+"/F7", /Q, SIDAMFFT#menuDo()
		help = {"Compute a Fourier transform of a source wave."}
		//	Fourier filter
		SIDAMMenus#menu("Fourier Filter...", forfft=1), /Q, SIDAMFourierFilter#menuDo()
		help = {"Apply a Fourier filter to a source wave"}
		//	Fourier Symmetrization
		SIDAMMenus#menu("Fourier Symmetrization...", noComplex=1), /Q, SIDAMFourierSym#menuDo()
		help = {"Symmetrize a FFT image"}
	End

	//	Correlation
	SIDAMMenus#menu("Correlation...", forfft=1), /Q, SIDAMCorrelation#menuDo()
	help = {"Compute a correlation function of a source wave(s)."}
	//	Work Function
	SIDAMMenus#menu("Work Function...", dim=3), /Q, SIDAMWorkfunction#menuDo()
	help = {"Compute work function."}

	"-"

	"Position Recorder", /Q, SIDAMPositionRecorder("")
	//	Extract Layers of LayerViewer
	SIDAMExtractLayer#menu(), /Q, SIDAMExtractLayer#menuDo()
	//	"Data Parameters"
	SIDAMShowParameters#rightclickMenu(), /Q, SIDAMShowParameters()


	"-"

	SubMenu "Extension"
	End

	"-"

	"Close Infobar", /Q, SIDAMInfoBar(WinName(0,1))
End
//-------------------------------------------------------------
//	conditional menu
//-------------------------------------------------------------
Static Function/S menu(String str, [int noComplex, int dim, int forfft])
	noComplex = ParamIsDefault(noComplex) ? 0 : noComplex

	String grfName = WinName(0,1)
	if (!strlen(grfName))
		return "(" + str
	endif
	Wave/Z w = SIDAMImageWaveRef(grfName)
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

	//	gray out for waves which are not for FFT
	if (!ParamIsDefault(forfft) && forfft)
		//	When a big wave is contained an experiment file, SIDAMValidateWaveforFFT may
		// make the menu responce slow. Therefore, use SIDAMValidateWaveforFFT only if
		//	the wave in a window has been modified since the last menu call.
		Variable grfTime = str2num(GetUserData(grfName, "", "modtime"))
		Variable wTime = NumberByKey("MODTIME", WaveInfo(w, 0))
		Variable fftavailable = str2num(GetUserData(grfName, "", "fftavailable"))
		int noRecord = numtype(grfTime) || numtype(fftavailable)
		int isModified = wTime > grfTime
		if (isModified || noRecord)
			fftavailable = !SIDAMValidateWaveforFFT(w)
			SetWindow $grfName userData(modtime)=num2istr(wTime)
			SetWindow $grfName userData(fftavailable)=num2istr(fftavailable)
		endif
		return SelectString(fftavailable, "(", "") + str
	endif

	return str
End


//******************************************************************************
//	Definition of right-click menu for 1D waves
//******************************************************************************
Menu "SIDAMMenu1D", dynamic, contextualmenu
	//	Trace
	"Offset and Color...", /Q, SIDAMTrace#menuDo()
	help = {"Set offset of traces in the top graph."}

	SubMenu "Sync"
		//	Sync Axis Range
		"Sync Axis Range...", /Q, SIDAMSyncAxisRange#menuDo()
		help = {"Syncronize axis range"}
	End

	SubMenu "Window"
		SubMenu "Coordinates"
			SIDAMInfoBar#menuR(0), /Q,  SIDAMInfoBar#menuRDo(0)
		End
		SubMenu "Complex"
			SIDAMInfoBar#menuR(4), /Q,  SIDAMInfoBar#menuRDo(4)
		End
	End

	SubMenu "\\M0Save/Export Graphics"
		"Save Graphics...", DoIgorMenu "File", "Save Graphics"

		"-"

		"\\M0Export Graphics (Transparent)", /Q, SIDAMExportGraphicsTransparent()
	End

	"-"

	//	Work Function
	"Work Function...", /Q, SIDAMWorkfunction#menuDo()
	help = {"Compute work function."}

	"-"

	//	"Data Parameters"
	SIDAMShowParameters#rightclickMenu(), /Q, SIDAMShowParameters()

	"-"

	SubMenu "Extension"
	End

	"-"

	"Close Infobar", /Q, SIDAMInfoBar(WinName(0,1))
End


//******************************************************************************
//	Definition of graph marquee menu
//******************************************************************************
Menu "GraphMarquee", dynamic
	SIDAMSubtraction#marqueeMenu(),/Q, SIDAMSubtraction#marqueeDo()
	SIDAMFourierSym#marqueeMenu(),/Q, SIDAMFourierSym#marqueeDo()
	Submenu "Get peak"
		SIDAMPeakPos#marqueeMenu(0), /Q, SIDAMPeakPos#marqueeDo(0)
		SIDAMPeakPos#marqueeMenu(1), /Q, SIDAMPeakPos#marqueeDo(1)
	End
End

