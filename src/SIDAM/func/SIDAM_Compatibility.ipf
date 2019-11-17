#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3

#include "SIDAM_Range"
#include "SIDAM_Hook"

#ifndef SIDAMshowProc
#pragma hide = 1
#endif

Function SIDAMBackwardCompatibility()
	//	Set the temporary folder to root:Packages:SIDAM
	updateDF("")

	//	Rename KM*Hook to SIDAM*Hook
	updateHookFunctions()

	//	Change the hook function of Range (KM -> SIDAM)
	updateRangeHook()
End

Static StrConstant OLD_DF1 = "root:'_KM'"
Static StrConstant OLD_DF2 = "root:'_SIDAM'"

Static Function updateDF(String grfPnlList)
	//	When grfPnlList is given, update the information recorded
	//	in userdata of each window.
	if (strlen(grfPnlList))
		int i
		for (i = 0; i < ItemsInList(grfPnlList); i++)
			updateDFUserData(StringFromList(i,grfPnlList))
		endfor
		return 0
	endif

	//	When grfPnlList is empty (this is how this function called
	//	from SIDAMBackwardCompatibility), update the datafolders.
	DFREF dfrSav = GetDataFolderDFR()

	if (DataFolderExists(OLD_DF1))
		NewDataFolder/O/S root:Packages
		MoveDataFolder $OLD_DF1 :
		RenameDataFolder '_KM', SIDAM
	elseif (DataFolderExists(OLD_DF2))
		NewDataFolder/O/S root:Packages
		MoveDataFolder $OLD_DF2 :
		RenameDataFolder '_SIDAM', SIDAM
	endif

	if (DataFolderExists(SIDAM_DF_CTAB+"KM"))
		RenameDataFolder $(SIDAM_DF_CTAB+"KM") SIDAM
	endif

	SetDataFolder dfrSav

	String winListStr = WinList("*",";","WIN:65")
	if (strlen(winListStr))
		updateDF(winListStr)
	endif
End

Static Function updateDFUserData(String grfName)
	String chdList = ChildWindowList(grfName), chdName
	String oldTmp, newTmp
	int i, j, n0, n1
	for (i = 0; i < ItemsInList(chdList); i++)
		chdName = StringFromList(i,chdList)
		if (CmpStr(chdName,"Color"))
			updateDFUserData(grfName+"#"+chdName)
		else
			String oldList = GetUserData(chdName,"","KMColorSettings"), newList="", item
			for (j = 0; j < ItemsInList(oldList); j++)
				item = StringFromList(j,oldList)
				n0 = strsearch(item,"ctab=",0)
				n1 = strsearch(item,":ctable:",n1)
				newList += ReplaceString(item[n0+5,n1+7],item,SIDAM_DF_CTAB)+";"
			endfor
			SetWindow $chdName userData(SIDAMColorSettings)=newList
			SetWindow $chdName userData(KMColorSettings)=""
		endif
	endfor
	oldTmp = GetUserData(grfName,"","dfTmp")
	if (strlen(oldTmp))
		newTmp = ReplaceString(OLD_DF1,oldTmp,SIDAM_DF)
		newTmp = ReplaceString(OLD_DF2,newTmp,SIDAM_DF)
		SetWindow $grfName userData(dfTmp)=newTmp
	endif
End

Static Function updateHookFunctions()
	SetIgorHook BeforeFileOpenHook
	if (WhichListItem("ProcGlobal#KMFileOpenHook",S_info) >= 0)
		SetIgorHook/K BeforeFileOpenHook = KMFileOpenHook
		SetIgorHook BeforeFileOpenHook = SIDAMFileOpenHook
	endif

	SetIgorHook BeforeExperimentSaveHook
	if (WhichListItem("ProcGlobal#KMBeforeExperimentSaveHook",S_info) >= 0)
		SetIgorHook/K BeforeExperimentSaveHook = KMBeforeExperimentSaveHook
		SetIgorHook BeforeExperimentSaveHook = SIDAMBeforeExperimentSaveHook
	endif

	SetIgorHook AfterCompiledHook
	if (WhichListItem("ProcGlobal#KMAfterCompiledHook",S_info) >= 0)
		SetIgorHook/K AfterCompiledHook = KMAfterCompiledHook
		SetIgorHook AfterCompiledHook = SIDAMAfterCompiledHook
	endif
End

Static Function updateRangeHook()
	String listStr = WinList("*",";","WIN:1"), grfName, str
	int i
	for (i = 0; i < ItemsInList(listStr); i++)
		grfName = StringFromList(i,listStr)
		GetWindow $grfName hook(KMRangePnl)
		if (strlen(S_value))
			SetWindow $grfName hook(KMRangePnl)=$""
			SetWindow $grfName hook(SIDAMRange)=SIDAMRange#pnlHookParent
		endif
		str = GetUserData(grfName,"","KMRangeSettings")
		if (strlen(str))
			SetWIndow $grfName userData(SIDAMRangeSettings)=str
			SetWindow $grfName userData(KMRangeSettings)=""
		endif
	endfor
End
