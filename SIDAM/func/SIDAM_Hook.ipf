#pragma TextEncoding="UTF-8"
#pragma rtGlobals=3

#ifndef SIDAMshowProc
#pragma hide = 1
#endif

#include "KM Prefs"							//	for KMLoadPrefs, KMSavePrefs
#include "SIDAM_Compatibility"			//	for SIDAMBackwardCompatibility

//	AfterCompiledHook
Function KMAfterCompiledHook()
	//	save present time
	STRUCT KMPrefs p
	KMLoadPrefs(p)
	p.last = DateTime
	KMSavePrefs(p)
	
	//	backward compatibility for an old experiment file
	SIDAMBackwardCompatibility()
End


#ifndef SIDAMstarting

//	BeforeFileOpenHook
Function KMFileOpenHook(refNum,filename,path,type,creator,kind)
	Variable refNum,kind
	String filename,path,type,creator
	
	Variable dontInvokeIgorFn = 0
	
	if (kind == 0 || kind == 6 || kind == 7)
		PathInfo $path
		try
			KMLoadData(S_path+filename,history=1)
			KillStrings/Z S_waveNames
			dontInvokeIgorFn = 1
		catch
			//	file not found, cancel not to overwrite a datafolder, etc.
			if (V_AbortCode == -3)
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
	
	//	Remove unused color scales
	KMColor()
	
	return 0
End

#endif