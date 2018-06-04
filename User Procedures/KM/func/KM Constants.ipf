#pragma TextEncoding="UTF-8"
#pragma rtGlobals=3

#ifndef KMshowProcedures
#pragma hide = 1
#endif

//	バージョン番号
Constant KM_REVISION = 1175

//	URL
StrConstant KM_URL_CMD = "http://www.riken.jp/epmrt/kohsaka/km/cmdlist.html"
StrConstant KM_URL_LOG = "http://www.riken.jp/epmrt/kohsaka/km/changelog.xml"
StrConstant KM_URL_SHORTCUTS = "http://www.riken.jp/epmrt/kohsaka/km/shortcuts.pdf"

//	データフォルダ
StrConstant KM_DF = "root:'_KM'"
StrConstant KM_DF_CTAB = "root:'_KM':ctable:"	//	カラーテーブルを読み込んで保存しておくデータフォルダの絶対パス
StrConstant KM_DF_SETTINGS = "settings"		//	データファイルのヘッダ情報を保存するデータフォルダの名前

//	一時データフォルダを用いているグラフの表示色
Constant KM_CLR_LINE_R = 0,		KM_CLR_LINE_G = 65280,		KM_CLR_LINE_B = 0		//	データ・軸
Constant KM_CLR_LINE2_R = 65280,	KM_CLR_LINE2_G = 48896,	KM_CLR_LINE2_B = 48896	//	データ強調色
Constant KM_CLR_NOTE_R = 32768,	KM_CLR_NOTE_G = 40704,		KM_CLR_NOTE_B = 65280	//	注意書き
Constant KM_CLR_BG_R = 0,			KM_CLR_BG_G = 0,				KM_CLR_BG_B = 0			//	背景

//	数値に変換するsetvariableの文字色
Constant KM_CLR_EVAL_R = 0, 		KM_CLR_EVAL_G = 15872,		 KM_CLR_EVAL_B = 65280

//	要修正のsetvariableの背景色
Constant KM_CLR_CAUTION_R = 65280, KM_CLR_CAUTION_G = 32768, KM_CLR_CAUTION_B = 32768


//	フォルダ・ファイル
StrConstant KM_FOLDER_FUNC = "func"
StrConstant KM_FOLDER_COLOR = "ctab"
StrConstant KM_FOLDER_LOADER = "file loaders"
StrConstant KM_FOLDER_EXT = "extension"
StrConstant KM_FOLDER_HELP = "help"
StrConstant KM_FILE_INCLUDE = "All KM Procedures"
StrConstant KM_FILE_LOADERLIST = "Function List.txt"

StrConstant KM_WAVE_LIST = "KM_list"
StrConstant KM_WAVE_SELECTED = "KM_selected"
StrConstant KM_WAVE_COLOR = "KM_color"

//	Igorで使われている定数の定義
#if (IgorVersion() >= 8.00)
	Constant MAX_OBJ_NAME = 255
	Constant MAX_WIN_PATH = 2000
	Constant MAXCMDLEN = 2500
#else
	Constant MAX_OBJ_NAME = 31
	Constant MAX_WIN_PATH = 259
	Constant MAXCMDLEN = 1000
#endif

StrConstant PRESTR_CMD = "•"			//	履歴欄でコマンドの前につく文字
StrConstant PRESTR_CAUTION = "** "	//	履歴欄で警告の前につく文字

StrConstant MENU_COMPLEX1D = "real and imaginary;real only;imaginary only;magnitude;phase (radians)"
StrConstant MENU_COMPLEX2D = "Magnitude;Real only;Imaginary only;Phase in radians"

//	データファイルの文字コード
StrConstant TEXTENCODING_NANONIS = "ShiftJIS"