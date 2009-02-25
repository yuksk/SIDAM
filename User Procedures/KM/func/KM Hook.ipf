#pragma TextEncoding="UTF-8"
#pragma rtGlobals=3

#ifndef KMshowProcedures
#pragma hide = 1
#endif

#include "KM Utilities_Help"				//	for KMCheckUpdateBackground, KMOpenHelpNote
#include "KM Utilities_Compatibility"	//	for KMBackwardCompatibility
#include "KM Prefs"							//	for KMLoadPrefs, KMSavePrefs

//	AfterCompiledHook
Function KMAfterCompiledHook()
	
	//	最後にコンパイルされてからの経過時間を得る
	STRUCT KMPrefs p
	KMLoadPrefs(p)
	Variable timeAfterLastCompile = DateTime - p.last
	
	//	今回のコンパイル時刻を記録しておく
	p.last = DateTime
	KMSavePrefs(p)
	
	//	バックグラウンドで更新チェックを行う設定
	//	初期設定ファイルが更新された、あるいは最終コンパイルから1日経過した場合に更新チェックを行う
	int checkUpdate = timeAfterLastCompile < 1 || timeAfterLastCompile > 3600*24
	if (checkUpdate)
		CtrlNamedBackground KMCheckUpdate, proc=KMCheckUpdateBackground, start
	endif
	
	//	Igor 6 で保存されたファイルを開いた場合に、Igor 7 にあわせて変更する
	KMBackwardCompatibility()
End


#ifndef KMstarting

//	BeforeFileOpenHook
Function KMFileOpenHook(refNum,filename,path,type,creator,kind)
	Variable refNum,kind
	String filename,path,type,creator
	
	Variable dontInvokeIgorFn = 0
	
	//	SLW,I-Vファイルは6番, 柴田ファイル出力は7番, として認識される
	//	Mac では(Windowsで作成された?)バイナリファイルが0番として認識される
	if (kind == 0 || kind == 6 || kind == 7)
		PathInfo $path
		try
			KMLoadData(S_path+filename,history=1)
			KillStrings/Z S_waveNames
			dontInvokeIgorFn = 1
		catch
			if (V_AbortCode  ==  -3)		//	ファイルが存在しない、データフォルダの上書き回避、等
				dontInvokeIgorFn = 1
			endif
		endtry
	endif
	
	return dontInvokeIgorFn
End

//	BeforeExperimentSaveHook
Function KMBeforeExperimentSaveHook(refNum,filename,path,type,creator,kind)
	Variable refNum,kind
	String filename,path,type,creator
	
	//	使われていないカラーテーブルウエーブは削除する
	KMColor()
	
	return 0
End

#endif