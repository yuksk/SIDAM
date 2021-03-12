#pragma TextEncoding="UTF-8"
#pragma rtGlobals=3

#ifndef SIDAMshowProc
#pragma hide = 1
#endif

#include "SIDAM_Color"
#include "SIDAM_LoadData"
#include "SIDAM_Preference"
#include "SIDAM_Compatibility"

//	AfterCompiledHook
Function SIDAMAfterCompiledHook()
	//	save present time
	STRUCT SIDAMPrefs p
	SIDAMLoadPrefs(p)
	p.last = DateTime
	SIDAMSavePrefs(p)

	//	backward compatibility for an old experiment file
	SIDAMBackwardCompatibility()
	
	return 0
End

//	BeforeFileOpenHook
Function SIDAMFileOpenHook(refNum,filename,path,type,creator,kind)
	Variable refNum,kind
	String filename,path,type,creator

	Variable dontInvokeIgorFn = 0

	if (kind == 0 || kind == 6 || kind == 7)
		PathInfo $path
		try
			SIDAMLoadData(S_path+filename,history=1)
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
Function SIDAMBeforeExperimentSaveHook(refNum,filename,path,type,creator,kind)
	Variable refNum,kind
	String filename,path,type,creator

	//	Remove unused color scales
	SIDAMColorKillWaves()

	return 0
End


//	Backward compatibility
Function KMAfterCompiledHook()
	SetIgorHook/K AfterCompiledHook = KMAfterCompiledHook
	SetIgorHook AfterCompiledHook = SIDAMAfterCompiledHook
	SIDAMAfterCompiledHook()
End
