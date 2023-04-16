#pragma TextEncoding="UTF-8"
#pragma rtGlobals=3
#pragma ModuleName = SIDAMPrefs

#ifndef SIDAMshowProc
#pragma hide = 1
#endif

Static StrConstant PACKAGE = "SIDAM"
Static StrConstant FILENAME = "SIDAM.bin"
Static Constant ID = 0
Static Constant VERSION = 19


//	Preference structure
//	This preference is mainly used to save status of a panel to recover it
//	next time a user opens the panel.
Structure SIDAMPrefs
	uint32		version
	uchar		fourier[3]
	uchar		color
	int32		disable	//	no longer used. delete next update.
	double		last
EndStructure


Function SIDAMLoadPrefs(STRUCT SIDAMPrefs &prefs)
	LoadPackagePreferences/MIS=1 PACKAGE, FILENAME, ID, prefs

	//	If correctly loaded, nothing to do is left
	if (!V_flag && V_bytesRead && prefs.version == VERSION)
		return 0
	endif

	setInitialValues(prefs)
	inheritValues(prefs)

	SIDAMSavePrefs(prefs)
End

Function SIDAMSavePrefs(STRUCT SIDAMPrefs &prefs)
	SavePackagePreferences PACKAGE, FILENAME, ID, prefs
End

Function SIDAMPrintPrefs()
	STRUCT SIDAMPrefs prefs
	SIDAMLoadPrefs(prefs)
	print prefs
End

Static Function setInitialValues(STRUCT SIDAMPrefs &p)
	p.version = VERSION
	
	if (inheritValues(p))
		return 0
	endif
	
	//	For panel of Fourier transform
	p.fourier[0] = 1		//	subtract, on
	p.fourier[1] = 3		//	output, magnitude
	p.fourier[2] = 21	//	window, none

	//	Date and time of last compile
	p.last = DateTime

	//	Options of the color panel
	//	0: close, 1: open
	p.color = 0
End

//	Backward compatibility
Static Function inheritValues(STRUCT SIDAMPrefs &prefs)

	STRUCT SIDAMPrefs18 prefs18
	LoadPackagePreferences/MIS=1 PACKAGE, FILENAME, ID, prefs18
	if (!V_flag && V_bytesRead && prefs18.version == 18)
		prefs.fourier[0] = prefs18.fourier[0]
		prefs.fourier[1] = prefs18.fourier[1]
		prefs.fourier[2] = prefs18.fourier[2]
		prefs.color = prefs18.color
		prefs.last = prefs18.last
		return 1
	endif
	
	STRUCT SIDAMPrefs17 prefs17
	LoadPackagePreferences/MIS=1 PACKAGE, FILENAME, ID, prefs17
	if (!V_flag && V_bytesRead && prefs17.version == 17)
		prefs.fourier[0] = prefs17.fourier[0]
		prefs.fourier[1] = prefs17.fourier[1]
		prefs.fourier[2] = prefs17.fourier[2]
		prefs.last = prefs17.last
		return 1
	endif
	
	STRUCT SIDAMPrefs16 prefs16
	LoadPackagePreferences/MIS=1 PACKAGE, FILENAME, ID, prefs16
	if (!V_flag && V_bytesRead && prefs16.version == 16)
		prefs.fourier[0] = prefs16.fourier[0]
		prefs.fourier[1] = prefs16.fourier[1]
		prefs.fourier[2] = prefs16.fourier[2]
		prefs.last = prefs16.last
		return 1
	endif
	
	return 0
End

Structure SIDAMPrefs18
	uint32		version
	uchar		fourier[3]
	uchar		color
	double		last
EndStructure

Structure SIDAMPrefs17
	uint32		version
	STRUCT		viewer16	viewer
	uchar		fourier[3]
	uint16		export[3]
	double		last
	uchar		precision
	uchar		color
	float		TopoGainFactor
	float		TopoCorrFactor
EndStructure

Structure SIDAMPrefs16
	uint32		version
	STRUCT		viewer16	viewer
	STRUCT		preview16	preview
	uchar		fourier[3]
	uint16		export[3]
	double		last
	uchar		precision
	float		TopoGainFactor
	float		TopoCorrFactor
EndStructure

Static Structure preview16
	STRUCT Rect	size
	uint16	Scolumn[4]
EndStructure

Static Structure viewer16
	float	width
	uchar	height
EndStructure
