#pragma TextEncoding="UTF-8"
#pragma rtGlobals=3

#ifndef SIDAMshowProc
#pragma hide = 1
#endif

#include "SIDAM_Prefs"						//	for SIDAMLoadPrefs, SIDAMSavePrefs
#include "SIDAM_Compatibility"			//	for SIDAMBackwardCompatibility

//	AfterCompiledHook
Function SIDAMAfterCompiledHook()
	//	save present time
	STRUCT SIDAMPrefs p
	SIDAMLoadPrefs(p)
	p.last = DateTime
	SIDAMSavePrefs(p)
	
	// if the precision in the preference and the actual preference is different,
	//	correct the latter
	if (p.precision == 1 && defined(SIDAMhighprecision))
		SIDAMInfoBarSetPrecision(0)
	elseif (p.precision == 2 && !defined(SIDAMhighprecision))
		SIDAMInfoBarSetPrecision(1)
	endif
	
	//	backward compatibility for an old experiment file
	SIDAMBackwardCompatibility()
End


#ifndef SIDAMstarting

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
	KMColor()
	
	return 0
End

#endif


//	For backward compatibility
Function KMAfterCompiledHook()
	SIDAMAfterCompiledHook()
End