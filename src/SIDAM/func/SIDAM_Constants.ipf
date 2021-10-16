#pragma TextEncoding="UTF-8"
#pragma rtGlobals=3

#ifndef SIDAMshowProc
#pragma hide = 1
#endif

//------------------------------------------------------------------------------
//	Version
//------------------------------------------------------------------------------
Constant SIDAM_VERSION_MAJOR = 9
Constant SIDAM_VERSION_MINOR = 6
Constant SIDAM_VERSION_PATCH = 6

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
StrConstant SIDAM_FOLDER_HELP = "help"
StrConstant SIDAM_FILE_CONFIG = "SIDAM.toml"
StrConstant SIDAM_FILE_CONFIG_DEFAULT = "SIDAM.default.toml"
StrConstant SIDAM_FILE_INCLUDE = "SIDAM_Procedures"

//------------------------------------------------------------------------------
//	URLs
//------------------------------------------------------------------------------
StrConstant SIDAM_URL_HOME = "https://github.com/yuksk/SIDAM"
StrConstant SIDAM_URL_COMMANDS = "https://yuksk.github.io/SIDAM/commands/"
StrConstant SIDAM_URL_SHORTCUTS = "https://yuksk.github.io/SIDAM/shortcuts/"
StrConstant SIDAM_URL_API_RELEASE = "https://api.github.com/repos/yuksk/SIDAM/releases"

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
//	Explictly define some constants built-in to Igor
Constant MAX_OBJ_NAME = 255
Constant MAX_WIN_PATH = 400
Constant MAXCMDLEN = 2500

StrConstant PRESTR_CMD = "•"			//	prefix character for regular commands in the history window
StrConstant PRESTR_CAUTION = "** "	//	prefix characters for cautions in the history window

StrConstant MENU_COMPLEX1D = "real and imaginary;real only;imaginary only;magnitude;phase (radians)"
StrConstant MENU_COMPLEX2D = "Magnitude;Real only;Imaginary only;Phase in radians"
