#pragma TextEncoding="UTF-8"
#pragma rtGlobals=3

#include "SIDAM_Constants"
#include "SIDAM_CreateProcedures"

Function SIDAMStart()
	printf "\r SIDAM %d.%d.%d\r", SIDAM_VERSION_MAJOR, SIDAM_VERSION_MINOR, SIDAM_VERSION_PATCH

	//	Construct SIDAM_Procedures.ipf and complie
	SIDAMCreateProcedures()
	Execute/P "INSERTINCLUDE \"" + SIDAM_FILE_INCLUDE + "\""
	Execute/P "COMPILEPROCEDURES "
	
	SetIgorHook BeforeFileOpenHook = SIDAMFileOpenHook
	SetIgorHook BeforeExperimentSaveHook = SIDAMBeforeExperimentSaveHook
	SetIgorHook AfterCompiledHook = SIDAMAfterCompiledHook
End

