#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3
#pragma ModuleName=SIDAMTOML

#ifndef SIDAMshowProc
#pragma hide = 1
#endif

//------------------------------------------------------------------------------
//	Concise parser of toml
//------------------------------------------------------------------------------

//	Return contents of a table as a key:value; list
Function/S SIDAMTOMLListFromTable(Variable refNum, String tableName, [int usespecial])
	usespecial = ParamIsDefault(usespecial) ? 0 : usespecial
	
	String listsep = SelectString(usespecial, ";", SIDAM_CHAR_ITEMSEP)
	String keysep = SelectString(usespecial, ":", SIDAM_CHAR_KEYSEP)

	int status = fastforward(refNum, tableName)
	if (status)
		return ""
	endif
	
	String listStr = "", buffer
	do
		FReadLine refNum, buffer
		buffer = TrimString(buffer)
		if (!strlen(buffer))	//	EOF, empty line
			break
		elseif (GrepString(buffer, "^\[.*?\]"))	//	next table
			break
		endif
		removeComment(buffer)
		if (strlen(buffer))
			listStr += SIDAMTOMLKeyFromLine(buffer) + keysep \
				+ SIDAMTOMLStringFromLine(buffer) + listsep
		endif
	while (1)

	return listStr
End

Function/WAVE SIDAMTOMLWaveFromTable(Variable refNum, String tableName)
	int status = fastforward(refNum, tableName)
	if (status)
		return $""
	endif
	
	String buffer
	int n = 0
	Make/N=(2,16)/T/FREE rtnw	//	16 is mostly enough

	do
		FReadLine refNum, buffer
		buffer = TrimString(buffer)
		if (!strlen(buffer))	//	EOF, empty line
			break
		elseif (GrepString(buffer, "^\[.*?\]"))	//	next table
			break
		endif
		removeComment(buffer)
		if (strlen(buffer))
			rtnw[][n++] = {SIDAMTOMLKeyFromLine(buffer), SIDAMTOMLStringFromLine(buffer)}
		endif
		if (n == DimSize(rtnw,1))
			InsertPoints/M=1 n, n, rtnw
		endif
	while (1)
	DeletePoints/M=1 n, DimSize(rtnw,1)-n, rtnw
	
	return rtnw
End


Function/S SIDAMTOMLKeyFromLine(String line)
	//	For ease of implementation, "=" is not assumed to be included in the key.
	return unsurrounding(StringFromList(0, line, "="))
End

Function/S SIDAMTOMLStringFromLine(String line)
	//	For ease of implementation, "=" is not assumed to be included in the key.
	//	Multi-lines are not supported.
	int i0 = strsearch(line, "=", 0)
	return unsurrounding(line[i0+1,strlen(line)-1]	)
End

Function SIDAMTOMLValueFromLine(String line)
	//	For ease of implementation, "=" is not assumed to be included in the key.
	return str2num(StringFromList(1, line, "="))
End

Function/WAVE SIDAMTOMLWaveFromValue(String value)
	String str = unsurrounding(value)
	if (strsearch(str, "\"", 0) != -1 || strsearch(str, "'", 0) != -1)
		Make/T/FREE/N=(ItemsInList(str, ",")) tw = unsurrounding(StringFromList(p, str, ","))
		return tw
	else
		Make/D/FREE/N=(ItemsInList(str, ",")) vw = str2num(StringFromList(p, str, ","))
		return vw
	endif
End

//------------------------------------------------------------------------------

//	Start from the beginning of the configuration file, and search the table
//	specified by the tableName parameter.
Static Function fastforward(Variable refNum, String tableName)
	String buffer
	FSetPos refNum, 0
	do
		FReadLine refNum, buffer
		if (!strlen(buffer))	//	EOF
			return 1
		elseif (!CmpStr(buffer, tableName+"\r"))
			return 0
		endif
	while(1)
End

Static Function removeComment(String &str)
	int i = strsearch(str, "#", 0)
	str = SelectString(i == -1, str[0, i-1], str)
End

Static Function/S unsurrounding(String str)
	int n = strlen(str)-1
	int i0 = strsearch(str, "\"", 0), i1 = strsearch(str, "\"", n, 1)
	int j0 = strsearch(str, "'", 0), j1 = strsearch(str, "'", n, 1)
	int k0 = strsearch(str, "[", 0), k1 = strsearch(str, "]", n, 1)
	int nosurrounding = i0 == -1 && j0 == -1 && k0 == -1
	if (nosurrounding)
		return removeSpace(str)
	elseif (i0 != -1 && i0 != i1)
		return str[i0+1, i1-1]
	elseif (j0 != -1 && j0 != j1)
		return str[j0+1, j1-1]
	elseif (k0 != -1 && k0 != k1)
		return str[k0+1, k1-1]
	else
		Abort "unmatched quotations"
	endif
End

Static Function/S removeSpace(String str)
	return ReplaceString(" ", str, "")
End
