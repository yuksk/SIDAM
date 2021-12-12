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
#include "SIDAM_Help"
#include "SIDAM_Histogram"
#include "SIDAM_ImageRotate"
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
#include "SIDAM_TraceOffset"
#include "SIDAM_Utilities_Image"
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
		SIDAMDisplay#mainMenuItem(0,"/F3"), /Q, SIDAMDisplay#mainMenuDo()
		help = {"Display a wave(s)"}

		SIDAMDisplay#mainMenuItem(1,""), /Q, SIDAMDisplay($GetBrowserSelection(0),traces=1,history=1)
		help = {"Display a 2D wave as 1d-traces"}

		SIDAMDisplay#mainMenuItem(2,""), /Q, SIDAMDisplay($GetBrowserSelection(0),traces=2,history=1)
		help = {"Display a 2D wave as xy-traces"}
		
		SIDAMInfoBar#mainMenuItem()+"/F8", /Q, SIDAMInfoBar("")
		help = {"Show information bar at the top of image graph."}
	End

	"-"

	Submenu "Config"
		"Open SIDAM config file", /Q, SIDAMConfig#mainMenuDo(0)
		SIDAMConfig#mainMenuItem(), /Q, SIDAMConfig#mainMenuDo(1)
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
		SIDAMUtilMisc#mainMenuItem(), /Q, SIDAMshowProcedures()
		"List of Deprecated Functions", /Q, print SIDAMDeprecatedFunctions()
		help = {"Show a list of deprecated functions in the history area"}
	End

	"-"

	//	Exit or Restart
	SIDAMStartExit#mainMenuItem(), /Q, SIDAMStartExit#mainMenuDo()
End


//******************************************************************************
//	conditional menu
//******************************************************************************
Static Function/S only3D(String str)
	String grfName = WinName(0,1)
	if (!strlen(grfName))
		return ""
	endif
	Wave/Z w = SIDAMImageNameToWaveRef(grfName)
	if (!WaveExists(w))
		return ""
	endif
	return SelectString(WaveDims(w)==3, "", str)
End

//******************************************************************************
//	Show a custom control for the menu
//******************************************************************************
Function SIDAMMenuCtrl(String pnlName, String menuName)
	CustomControl menuCC title="\u2630", pos={2,2}, size={18,18}, frame=0, win=$pnlName
	CustomControl menuCC userData(menu)=menuName, win=$pnlName
	CustomControl menuCC proc=SIDAMMenus#ctrlAction, focusRing=0, win=$pnlName
End

Static Function ctrlAction(STRUCT WMCustomControlAction &s)
	if (s.eventCode != 1)
		return 0
	endif

	strswitch (s.ctrlName)
		case "menuCC":
			if (!strlen(GetUserData(s.win, s.ctrlName, "on")))
				CustomControl $s.ctrlName frame=3, userData(on)="1", win=$s.win
				ControlInfo/W=$s.win kwControlBar
				Variable barHeight = V_Height
				ControlInfo/W=$s.win $s.ctrlName
				//	When the menu control is shown in Line Profile or Line Spectra
				//	barHeight = 0 and it's okay.
				PopupContextualMenu/N/C=(V_left, V_top+V_Height-barHeight) GetUserData(s.win, s.ctrlName, "menu")
			endif
			CustomControl $s.ctrlName frame=0, userData(on)="", win=$s.win
			break
	endswitch
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

//******************************************************************************
//	Definitions of menus in panels
//******************************************************************************
//	If SIDAMInfobarMenu2D3D and SIDAMInfobarMenu1D are written in
//	SIDAMInfobar.ipf, the order of menu items is somehow screwed up
Menu "SIDAMInfobarMenu2D3D", dynamic, contextualmenu
	//	Range
	SubMenu "Range"
		help = {"Adjust of z range of images in the active graph."}
		"Manual.../F4", /Q, SIDAMRange()
		"-"
		SIDAMRange#menuItem(2), /Q, SIDAMRange#menuDo(2)
		SIDAMRange#menuItem(3), /Q, SIDAMRange#menuDo(3)
	End

	"Color Table.../F5", /Q, SIDAMColor()
	help = {"Change the color table used to display the top image in the active graph."}

	SubMenu "Sync"
		//	Sync Layers
		SIDAMMenus#only3D("Sync Layers..."), /Q, SIDAMSyncLayer#menuDo()
		help = {"Syncronize layer index of LayerViewers"}
		//	Sync Axis Range
		"Sync Axis Range...", /Q, SIDAMSyncAxisRange#menuDo()
		help = {"Syncronize axis range"}
		//	Sync Cursors
		SIDAMSyncCursor#menuItem(), /Q, SIDAMSyncCursor#menuDo()
		help = {"Synchronize cursor positions in graphs showing images"}
	End

	SubMenu "Window"
		SubMenu "Coordinates"
			SIDAMInfoBar#menuItem(0), /Q,  SIDAMInfoBar#menuDo(0)
		End
		SubMenu "Complex"
			SIDAMInfoBar#menuItem(3), /Q,  SIDAMInfoBar#menuDo(3)
		End
		"Scale Bar...", /Q, SIDAMScaleBar#menuDo()
		SIDAMMenus#only3D("Layer Annotation..."), /Q, SIDAMLayerAnnotation#menuDo()
		//	Show/Hide Axis
		SIDAMInfoBar#menuItem(2), /Q, SIDAMInfoBar#menuDo(2)
		help = {"Show/Hide labels of the graph."}
	End

	SubMenu "\\M0Save/Export Graphics"
		"Save Graphics...", DoIgorMenu "File", "Save Graphics"
		SIDAMSaveGraphics#menuItem(), /Q, SIDAMSaveGraphics#menuDo()
		SIDAMSaveMovie#menuItem(), /Q, SIDAMSaveMovie#menuDo()

		"-"

		"\\M0Export Graphics (Transparent)", /Q, SIDAMExportGraphicsTransparent()
	End

	"-"

	//	View spectra of LayerViewer
	SIDAMMenus#only3D("Point Spectrum..."), /Q, SIDAMSpectrumViewer#menuDo()
	SIDAMMenus#only3D("Line Spectra..."), /Q, SIDAMLineSpectra#menuDo()
	//	Line Profile
	"Line Profile...", /Q, SIDAMLineProfile#menuDo()
	help = {"Make a line profile wave of the image in the active graph."}


	"-"

	//	Subtraction
	"Subtract.../F6", /Q, SIDAMSubtraction#menuDo()
	help = {"Subtract n-th plane or line from a 2D wave or each layer of a 3D wave"}
	
	"Rotate image...", /Q, SIDAMImageRotate#menuDo()
	help = {"Rotate an image wave around the center of the image."}

	//	Histogram
	"Histogram...", /Q, SIDAMHistogram#menuDo()
	help = {"Compute the histogram of a source wave."}
		
	SubMenu "Fourier"
		//	Fourier Transform
		"Fourier Transform.../F7", /Q, SIDAMFFT#menuDo()
		help = {"Compute a Fourier transform of a source wave."}
		//	Fourier filter
		"Fourier Filter...", /Q, SIDAMFourierFilter#menuDo()
		help = {"Apply a Fourier filter to a source wave"}
		//	Fourier Symmetrization
		"Fourier Symmetrization...", /Q, SIDAMFourierSym#menuDo()
		help = {"Symmetrize a FFT image"}
	End

	//	Correlation
	"Correlation...", /Q, SIDAMCorrelation#menuDo()
	help = {"Compute a correlation function of a source wave(s)."}
	//	Work Function
	SIDAMMenus#only3D("Work Function..."), /Q, SIDAMWorkfunction#menuDo()
	help = {"Compute work function."}

	"-"

	"Position Recorder", /Q, SIDAMPositionRecorder("")
	//	Extract Layers of LayerViewer
	SIDAMExtractLayer#menuItem(), /Q, SIDAMExtractLayer#menuDo()
	//	"Data Parameters"
	SIDAMShowParameters#menuItem(), /Q, SIDAMShowParameters()


	"-"

	SubMenu "Extension"
	End

	"-"

	"Close Infobar", /Q, SIDAMInfoBar(WinName(0,1))
End

Menu "SIDAMInfobarMenu1D", dynamic, contextualmenu
	//	Trace
	"Offset...", /Q, SIDAMTraceOffset#menuDo()
	help = {"Set offset of traces in the top graph."}

	SubMenu "Sync"
		//	Sync Axis Range
		"Sync Axis Range...", /Q, SIDAMSyncAxisRange#menuDo()
		help = {"Syncronize axis range"}
	End

	SubMenu "Window"
		SubMenu "Coordinates"
			SIDAMInfoBar#menuItem(0), /Q,  SIDAMInfoBar#menuDo(0)
		End
		SubMenu "Complex"
			SIDAMInfoBar#menuItem(4), /Q,  SIDAMInfoBar#menuDo(4)
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
	SIDAMShowParameters#menuItem(), /Q, SIDAMShowParameters()

	"-"

	SubMenu "Extension"
	End

	"-"

	"Close Infobar", /Q, SIDAMInfoBar(WinName(0,1))
End
