#pragma TextEncoding="UTF-8"
#pragma rtGlobals=3

#ifndef SIDAMshowProc
#pragma hide = 1
#endif

//------------------------------------------------------------------------------
//	Version
//------------------------------------------------------------------------------
Constant SIDAM_VERSION_MAJOR = 9
Constant SIDAM_VERSION_MINOR = 5
Constant SIDAM_VERSION_PATCH = 1

//------------------------------------------------------------------------------
//	Data Folder
//------------------------------------------------------------------------------
StrConstant SIDAM_DF = "root:Packages:SIDAM"
StrConstant SIDAM_DF_CTAB = "root:Packages:SIDAM:ctable:"
StrConstant SIDAM_DF_SETTINGS = "settings"

//------------------------------------------------------------------------------
//	Colors
//------------------------------------------------------------------------------
//	for characters of SetVariable
//	indicating input strings can be converted to numbers
Constant SIDAM_CLR_EVAL_R = 0
Constant SIDAM_CLR_EVAL_G = 15872
Constant SIDAM_CLR_EVAL_B = 65280

//	for background of SetVariable
//	indicating something necesary to be modifed
Constant SIDAM_CLR_CAUTION_R = 65280
Constant SIDAM_CLR_CAUTION_G = 32768
Constant SIDAM_CLR_CAUTION_B = 32768

//------------------------------------------------------------------------------
//	Folders and files
//------------------------------------------------------------------------------
StrConstant SIDAM_FOLDER_MAIN = "SIDAM"
StrConstant SIDAM_FOLDER_ADDTIONAL = "extension;"
StrConstant SIDAM_FOLDER_HELP = "help"
StrConstant SIDAM_FILE_CONFIG = "SIDAM.toml"
StrConstant SIDAM_FILE_CONFIG_DEFAULT = "SIDAM.default.toml"
StrConstant SIDAM_FILE_INCLUDE = "SIDAM_Procedures"
StrConstant SIDAM_FILE_SHORTCUTS = "help:shortcuts.md"

//------------------------------------------------------------------------------
//	Temporary waves
//------------------------------------------------------------------------------
StrConstant SIDAM_WAVE_LIST = "SIDAM_list"
StrConstant SIDAM_WAVE_SELECTED = "SIDAM_selected"
StrConstant SIDAM_WAVE_COLOR = "SIDAM_color"

//------------------------------------------------------------------------------
//	Special characters
//------------------------------------------------------------------------------
StrConstant SIDAM_CHAR_LISTSEP = "\u001D"
StrConstant SIDAM_CHAR_KEYSEP = "\u001E"
StrConstant SIDAM_CHAR_ITEMSEP = "\u001F"

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
