#pragma TextEncoding="UTF-8"
#pragma rtGlobals=3
#pragma ModuleName=SIDAMShowParameters

#include "SIDAM_Utilities_Image"
#include "SIDAM_Utilities_Window"

#ifndef SIDAMshowProc
#pragma hide = 1
#endif

Static Constant FONTSIZE = 10
Static Constant FONTSTYLE = 0

Function SIDAMShowParameters()
	String grfName = WinName(0,1)

	DFREF dfr = getSIDAMSettingDFR(grfName)
	if (!DataFolderRefStatus(dfr))
		return 0
	endif

	String pnlName = "properties"
	if (SIDAMWindowExists(grfName+"#"+pnlName))
		return 0
	endif
		
	//	A notebook can not be a subwindow of a graph. Therefore, create a new panel
	//	as a subwindow of a graph, and create a notebook as a subwindow of the panel.
	NewPanel/HOST=$grfName/EXT=0/W=(0,0,10,10)/N=$pnlName as "properties"	//	the size is temporary
	ModifyPanel/W=$grfName#$pnlName fixedSize=0

	String nbName = "nb", fullName = grfName+"#"+pnlName+"#"+nbName
	NewNotebook/F=0/K=1/N=$nbName/V=0/W=(0,0,1,1)/HOST=$grfName#$pnlName
	Variable tabSize = getTabWidth(dfr, GetDefaultFont(fullName)) + 20

	writeParameters(dfr, fullName)
	Notebook $fullName defaultTab=tabSize, fSize=FONTSIZE, statusWidth=0, writeProtect=1
	Notebook $fullName selection={startOfFile, startOfFile}, text="", visible=1	//	Move to the top

	GetWindow $grfName wsizeDC
	MoveSubWindow/W=$grfName#$pnlName fnum=(0,0,tabSize*2*screenresolution/72,V_bottom-V_top)

	SetActiveSubwindow $grfName
End

Static Function/S menuItem()
	String grfName = WinName(0,1)
	if (!strlen(grfName))
		return ""
	endif
	DFREF dfr = getSIDAMSettingDFR(grfName)
	return SelectString(DataFolderRefStatus(dfr),"(","") + "Data Parameters..."
End

Static Function/DF getSIDAMSettingDFR(String grfName)
	Wave/Z srcw = SIDAMImageNameToWaveRef(grfName)
	if (!WaveExists(srcw))
		Wave/Z srcw = TraceNameToWaveRef(grfName,StringFromList(0,TraceNameList(grfName,";",1)))
	endif
	if (!WaveExists(srcw))
		return $""
	endif

	return GetWavesDataFolderDFR(srcw):$(SIDAM_DF_SETTINGS)
End

Static Constant MAXITEMS = 512

Static Function writeParameters(DFREF dfr, String notebookName, [int style])
	int i, k, n
	String name
	if (ParamIsDefault(style))
		if (isNanonis(dfr))
			style = 1
		else
			style = 0
		endif
	endif

	Make/N=(2,MAXITEMS)/T/FREE params

	for (i = 0, k = 0, n = CountObjectsDFR(dfr,2); i < n; i++, k++)
		name = GetIndexedObjNameDFR(dfr,2,i)
		NVAR/SDFR=dfr var = $name
		params[][k] = {name, num2str(var)}
	endfor

	for (i = 0, n = CountObjectsDFR(dfr,3); i < n; i++, k++)
		name = GetIndexedObjNameDFR(dfr,3,i)
		SVAR/SDFR=dfr str = $name
		params[][k] = {name, str}
	endfor

	if (style)
		nanonisStyle(params)
	endif

	for (i = 0; strlen(params[0][i]) > 0; i++)
		Notebook $notebookName text=params[0][i]+"\t"+params[1][i]+"\r"
	endfor

	for (i = 0, n = CountObjectsDFR(dfr,4); i < n; i++)
		name = GetIndexedObjNameDFR(dfr,4,i)
		Notebook $notebookName text="\r:"+name+"\r"
		writeParameters(dfr:$name, notebookName, style=style)
	endfor
End

Static Function getTabWidth(DFREF dfr, String fontName)
	int n2 = CountObjectsDFR(dfr,2), n3 = CountObjectsDFR(dfr,3), n4 = CountObjectsDFR(dfr,4), i
	String name
	Make/N=(n2+n3+n4)/FREE/B/U tw

	for (i = 0; i < n2; i++)
		name = GetIndexedObjNameDFR(dfr,2,i)
		tw[i] = FontSizeStringWidth(fontName,FONTSIZE,FONTSTYLE,name)
	endfor

	for (i = 0; i < n3; i++)
		name = GetIndexedObjNameDFR(dfr,3,i)
		tw[i+n2] = FontSizeStringWidth(fontName,FONTSIZE,FONTSTYLE,name)
	endfor

	for (i = 0; i < n4; i++)
		name = GetIndexedObjNameDFR(dfr,4,i)
		tw[i+n2+n3] = getTabWidth(dfr:$name, fontName)
	endfor

	return WaveMax(tw)
End

//	for nanonis
Static Function isNanonis(DFREF dfr)
	SVAR/SDFR=dfr/Z Experiment
	NVAR/SDFR=dfr/Z NANONIS_VERSION
	return SVAR_Exists(Experiment) || NVAR_Exists(NANONIS_VERSION)
End

#if IgorVersion() >= 9
Static Function nanonisStyle(Wave/T params)

	int i, j
	String prefix, txt
	Variable coef, v

	Wave indexw = nanonisStyleSearch(params, "Setpoint")
	if (numpnts(indexw))
		params[0][indexw[0]] += " ("+params[1][indexw[1]]+")"
	endif

	for (i = 0; strlen(params[0][i]) > 0; i++)
		if (strsearch(params[0][i],"acquisition_time",0) != -1)
			v = str2num(params[1][i])
			if (v < 180)
				Sprintf txt "%.2f s", v
			elseif (v < 3600)
				Sprintf txt "%d m %d s", floor(v/60), mod(v,60)
			else
				Sprintf txt "%d h %d m %d s", floor(v/3600), floor(mod(v,3600)/60), mod(v,60)
			endif
			params[][i] = {"acquisition time", txt}

		elseif (strsearch(params[0][i],"n_pixels",0) != -1 && \
				strsearch(params[0][i+1],"n_lines",0) != -1)
			InsertPoints/M=1 i+2, 1, params
			params[0][i+2] = "number of pixels"
			params[1][i+2] = params[1][i]+", "+params[1][i+1]
			DeletePoints/M=1 i, 2, params

		elseif (strsearch(params[0][i],"width_m",0) != -1 && \
				strsearch(params[0][i+1],"height_m",0) != -1)
			InsertPoints/M=1 i+2, 1, params
			Sprintf txt, "%.2f, %.2f", str2num(params[1][i])*1e9,\
				str2num(params[1][i+1])*1e9
			params[][i+2] = {"size (nm)", txt}
			DeletePoints/M=1 i, 2, params

		elseif (strsearch(params[0][i],"center_x_m",0) != -1 && \
				strsearch(params[0][i+1],"center_y_m",0) != -1)
			InsertPoints/M=1 i+2, 1, params
			Sprintf txt, "%.2f, %.2f", str2num(params[1][i])*1e9,\
				str2num(params[1][i+1])*1e9
			params[][i+2] = {"center (nm)", txt}
			DeletePoints/M=1 i, 2, params

		elseif (strsearch(params[0][i],"Grid_settings",0) != -1)
			InsertPoints/M=1 i+1, 3, params
			Sprintf txt, "%.2f, %.2f", str2num(StringFromList(0,params[1][i]))*1e9,\
				str2num(StringFromList(1,params[1][i]))*1e9
			params[][i+1] = {"Grid center (nm)", txt}
			Sprintf txt, "%.2f, %.2f", str2num(StringFromList(2,params[1][i]))*1e9,\
				str2num(StringFromList(3,params[1][i]))*1e9
			params[][i+2] = {"Grid size (nm)", txt}
			Sprintf txt, "%.2f", str2num(StringFromList(4,params[1][i]))
			params[][i+3] = {"Grid angle (deg)", txt}
			DeletePoints/M=1 i, 1, params
			i += 2

		elseif (strsearch(params[0][i],"Scanfield",0) != -1)
			InsertPoints/M=1 i+1, 3, params
			Sprintf txt, "%.2f, %.2f", str2num(StringFromList(0,params[1][i]))*1e9, \
				str2num(StringFromList(1,params[1][i]))*1e9
			params[][i+1] = {"Scanfield center (nm)", txt}
			Sprintf txt, "%.2f, %.2f", 	str2num(StringFromList(2,params[1][i]))*1e9,\
				str2num(StringFromList(3,params[1][i]))*1e9
			params[][i+2] = {"Scanfield size (nm)", txt}
			Sprintf txt, "%.2f", str2num(StringFromList(4,params[1][i]))
			params[][i+3] = {"Scanfield angle (deg)", txt}
			DeletePoints/M=1 i, 1, params
			i += 2

		elseif (strsearch(params[0][i],"P gain",0) != -1)
			params[0][i] = "P gain (m)"

		elseif (strsearch(params[0][i],"I gain",0) != -1)
			params[0][i] = "I gain (m/s)"

		endif
	endfor

	Make/T/N=(2,11)/FREE uw
	uw[][0] = {"_V_m_2_","V/m^2"}
	uw[][1] = {"_m_s_","m/s"}
	uw[][2] = {"_m_V_","m/V"}
	uw[][3] = {"_A_V_","A/V"}
	uw[][4] = {"_V_V_","V/V"}
	uw[][5] = {"_m_","m"}
	uw[][6] = {"_A_","A"}
	uw[][7] = {"_V_","V"}
	uw[][8] = {"_s_","s"}
	uw[][9] = {"_Hz_","Hz"}
	uw[][10] = {"_deg_","deg"}
	for (i = 0; strlen(params[0][i]) > 0; i++)
		for (j = 0; j < DimSize(uw, 1); j++)
			if (strsearch(params[0][i],uw[0][j],0) == -1)
				continue
			endif
			[prefix, coef] = nanonisStylePrefix(str2num(params[1][i]))
			params[0][i] = ReplaceString(uw[0][j],params[0][i],"("+prefix+uw[1][j]+")")
			params[1][i] = num2str(str2num(params[1][i])*10^coef)
		endfor
		params[0][i] = ReplaceString("_",params[0][i]," ")
	endfor
End
#else
Static Function nanonisStyle(Wave/T params)

	int i, j
	String units = "m;m/s;m/V;A;A/V;s"
	String unit, prefix, txt
	Variable coef, v

	Wave indexw = nanonisStyleSearch(params, "Setpoint")
	if (numpnts(indexw))
		params[0][indexw[0]] += " ("+params[1][indexw[1]]+")"
	endif

	for (i = 0; strlen(params[0][i]) > 0; i++)
		if (strsearch(params[0][i],"acquisition time",0) != -1)
			v = str2num(params[1][i])
			if (v < 180)
				Sprintf txt "%.2f s", v
			elseif (v < 3600)
				Sprintf txt "%d m %d s", floor(v/60), mod(v,60)
			else
				Sprintf txt "%d h %d m %d s", floor(v/3600), floor(mod(v,3600)/60), mod(v,60)
			endif
			params[][i] = {"acquisition time", txt}

		elseif (strsearch(params[0][i],"# pixels",0) != -1 && \
				strsearch(params[0][i+1],"# lines",0) != -1)
			InsertPoints/M=1 i+2, 1, params
			params[0][i+2] = "number of pixels"
			params[1][i+2] = params[1][i]+", "+params[1][i+1]
			DeletePoints/M=1 i, 2, params

		elseif (strsearch(params[0][i],"width (m)",0) != -1 && \
				strsearch(params[0][i+1],"height (m)",0) != -1)
			InsertPoints/M=1 i+2, 1, params
			Sprintf txt, "%.2f, %.2f", str2num(params[1][i])*1e9,\
				str2num(params[1][i+1])*1e9
			params[][i+2] = {"size (nm)", txt}
			DeletePoints/M=1 i, 2, params

		elseif (strsearch(params[0][i],"center x (m)",0) != -1 && \
				strsearch(params[0][i+1],"center y (m)",0) != -1)
			InsertPoints/M=1 i+2, 1, params
			Sprintf txt, "%.2f, %.2f", str2num(params[1][i])*1e9,\
				str2num(params[1][i+1])*1e9
			params[][i+2] = {"center (nm)", txt}
			DeletePoints/M=1 i, 2, params

		elseif (strsearch(params[0][i],"Grid settings",0) != -1)
			InsertPoints/M=1 i+1, 3, params
			Sprintf txt, "%.2f, %.2f", str2num(StringFromList(0,params[1][i]))*1e9,\
				str2num(StringFromList(1,params[1][i]))*1e9
			params[][i+1] = {"Grid center (nm)", txt}
			Sprintf txt, "%.2f, %.2f", str2num(StringFromList(2,params[1][i]))*1e9,\
				str2num(StringFromList(3,params[1][i]))*1e9
			params[][i+2] = {"Grid size (nm)", txt}
			Sprintf txt, "%.2f", str2num(StringFromList(4,params[1][i]))
			params[][i+3] = {"Grid angle (deg)", txt}
			DeletePoints/M=1 i, 1, params
			i += 2

		elseif (strsearch(params[0][i],"Scanfield",0) != -1)
			InsertPoints/M=1 i+1, 3, params
			Sprintf txt, "%.2f, %.2f", str2num(StringFromList(0,params[1][i]))*1e9, \
				str2num(StringFromList(1,params[1][i]))*1e9
			params[][i+1] = {"Scanfield center (nm)", txt}
			Sprintf txt, "%.2f, %.2f", 	str2num(StringFromList(2,params[1][i]))*1e9,\
				str2num(StringFromList(3,params[1][i]))*1e9
			params[][i+2] = {"Scanfield size (nm)", txt}
			Sprintf txt, "%.2f", str2num(StringFromList(4,params[1][i]))
			params[][i+3] = {"Scanfield angle (deg)", txt}
			DeletePoints/M=1 i, 1, params
			i += 2

		elseif (strsearch(params[0][i],"P gain",0) != -1)
			params[0][i] = "P gain (m)"

		elseif (strsearch(params[0][i],"I gain",0) != -1)
			params[0][i] = "I gain (m/s)"

		endif
	endfor

	for (i = 0; strlen(params[0][i]) > 0; i++)
		for (j = 0; j < ItemsInList(units); j++)
			unit = StringFromList(j,units)
			if (strsearch(params[0][i],"("+unit+")",0) == -1)
				continue
			endif
			[prefix, coef] = nanonisStylePrefix(str2num(params[1][i]))
			params[0][i] = ReplaceString("("+unit+")",params[0][i],"("+prefix+unit+")")
			params[1][i] = num2str(str2num(params[1][i])*10^coef)
		endfor
	endfor
End
#endif

Static Function[String prefix, Variable coef] nanonisStylePrefix(Variable var)
	int exponent = floor(log(abs(var)))
	if (exponent < -15 || exponent > 9)
		return ["", 0]
	endif

	int index = floor(exponent/3)+6
	Make/T/FREE prefixw = {"a", "f", "p", "n", "u", "m", "", "k", "M", "G"}
	return [prefixw[index], 18-3*index]
End

Static Function/WAVE nanonisStyleSearch(Wave/T params, String regstr)
	DFREF dfrSav = GetDataFolderDFR()
	SetDataFolder NewFreeDataFolder()

	Duplicate/T params tw
	MatrixTranspose tw
	Grep/E=regstr/INDX/Q tw
	Wave indxw = W_Index

	SetDataFolder dfrSav
	return indxw
End
