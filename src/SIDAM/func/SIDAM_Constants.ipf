#pragma TextEncoding="UTF-8"
#pragma rtGlobals=3

#ifndef SIDAMshowProc
#pragma hide = 1
#endif

//------------------------------------------------------------------------------
//	Version
//------------------------------------------------------------------------------
Constant SIDAM_VERSION_MAJOR = 9
Constant SIDAM_VERSION_MINOR = 1
Constant SIDAM_VERSION_PATCH = 0

//------------------------------------------------------------------------------
//	Data Folder
//------------------------------------------------------------------------------
StrConstant SIDAM_DF = "root:Packages:SIDAM"
StrConstant SIDAM_DF_CTAB = "root:Packages:SIDAM:ctable:"
StrConstant SIDAM_DF_SETTINGS = "settings"

//------------------------------------------------------------------------------
//	Colors
//------------------------------------------------------------------------------------------------
//	for windows
Constant SIDAM_CLR_LINE_R = 0,		SIDAM_CLR_LINE_G = 32768,		SIDAM_CLR_LINE_B = 65535	//	data and axis
Constant SIDAM_CLR_LINE2_R = 65535,	SIDAM_CLR_LINE2_G = 43690,	SIDAM_CLR_LINE2_B = 0		//	for emphasis
Constant SIDAM_CLR_NOTE_R = 32768,	SIDAM_CLR_NOTE_G = 40704,		SIDAM_CLR_NOTE_B = 65280	//	note

//	for characters of SetVariable, indicating input strings can be converted to numbers
Constant SIDAM_CLR_EVAL_R = 0, 		SIDAM_CLR_EVAL_G = 15872,		 SIDAM_CLR_EVAL_B = 65280

//	for background of SetVariable, indicating something necesary to be modifed
Constant SIDAM_CLR_CAUTION_R = 65280, SIDAM_CLR_CAUTION_G = 32768, SIDAM_CLR_CAUTION_B = 32768

//------------------------------------------------------------------------------
//	Folders and files
//------------------------------------------------------------------------------
StrConstant SIDAM_FOLDER_MAIN = "SIDAM"
StrConstant SIDAM_FOLDER_FUNC = "func"
StrConstant SIDAM_FOLDER_COLOR = "ctab"
StrConstant SIDAM_FOLDER_LOADER = "fileloader"
StrConstant SIDAM_FOLDER_EXT = "extension"
StrConstant SIDAM_FOLDER_HELP = "help"
StrConstant SIDAM_FILE_COLORLIST = "ctab.ini"
StrConstant SIDAM_FILE_COLORLIST_DEFAULT = "ctab.default.ini"
StrConstant SIDAM_FILE_LOADERLIST = "functions.ini"
StrConstant SIDAM_FILE_LOADERLIST_DEFAULT = "functions.default.ini"
StrConstant SIDAM_FILE_INCLUDE = "SIDAM_Procedures"
StrConstant SIDAM_FILE_SHORTCUTS = "shortcuts.md"

//------------------------------------------------------------------------------
//	Temporary waves
//------------------------------------------------------------------------------
StrConstant SIDAM_WAVE_LIST = "SIDAM_list"
StrConstant SIDAM_WAVE_SELECTED = "SIDAM_selected"
StrConstant SIDAM_WAVE_COLOR = "SIDAM_color"

//------------------------------------------------------------------------------
//	Constants used in Igor Pro
//------------------------------------------------------------------------------
Constant MAX_OBJ_NAME = 255
Constant MAX_WIN_PATH = 2000
Constant MAXCMDLEN = 2500

StrConstant PRESTR_CMD = "•"			//	prefix character for regular commands in the history window
StrConstant PRESTR_CAUTION = "** "	//	prefix characters for cautions in the history window

StrConstant MENU_COMPLEX1D = "real and imaginary;real only;imaginary only;magnitude;phase (radians)"
StrConstant MENU_COMPLEX2D = "Magnitude;Real only;Imaginary only;Phase in radians"

//------------------------------------------------------------------------------
//	Text encoding
//------------------------------------------------------------------------------
//	for nanonis, this prorbaby depends on OS
StrConstant TEXTENCODING_NANONIS = "ShiftJIS"
