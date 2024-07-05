#pragma TextEncoding="UTF-8"
#pragma rtGlobals=3

#ifndef SIDAMshowProc
#pragma hide = 1
#endif

#include "SIDAM_Color"
#include "SIDAM_LoadData"
#include "SIDAM_Preference"
#include "SIDAM_Compatibility"
#include "SIDAM_Utilities_Wave"

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

	if (kind == 0 || kind == 6 || kind == 7 || kind == 8)
		PathInfo $path
		try
			Wave/Z w = SIDAMLoadData(S_path+filename,history=1)
			KillStrings/Z S_waveNames
			dontInvokeIgorFn = WaveExists(w)
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

//-------------------------------------------------------------
//	Tooltip
//-------------------------------------------------------------
#if IgorVersion() >= 9
Function SIDAMTooltipHook(STRUCT WMTooltipHookStruct &s)
	int useCustomTooltip = 0
	
	if (strlen(s.imageName) > 0)
		Wave w = s.yWave
		useCustomTooltip = 1
	elseif (strlen(s.traceName) > 0)
		Wave w = s.yWave
		useCustomTooltip = 1
	endif

	if (useCustomTooltip)
		s.tooltip = "<html>"
		s.tooltip += "<b>"+NameOfWave(w)+"</b> "+getNumOfPoints(w)
		s.tooltip += "<br>Datafolder: "+GetWavesDataFolder(w,1)
		s.tooltip += getFOVcenter(w)
		s.tooltip += getFOVsize(w)
		s.tooltip += getSetpoint(w)
		s.tooltip += "</html>"
		s.isHTML=1
	endif
	return useCustomTooltip
End

Static Function/S getNumOfPoints(Wave w)
	Make/U/I/N=4/FREE nw = DimSize(w,p)
	DeletePoints WaveDims(w), 4-WaveDims(w), nw
	String str = SIDAMWaveToString(nw)
	return "["+str[1,strlen(str)-2]+"]"
End

Static Function/S getFOVsize(Wave w)
	if (WaveDims(w) == 1)
		return ""
	endif
	
	Make/N=2/FREE fw = DimDelta(w,p)*DimSize(w,p)
	Make/N=2/T/FREE tw = WaveUnits(w,p)
	String str
	sprintf str, "<br>Size: %.2W1P%s &times; %.2W1P%s", fw[0], tw[0], fw[1], tw[1]
	return str	
End

Static Function/S getFOVcenter(Wave w)
	String df = GetWavesDataFolder(w,1)+SIDAM_DF_SETTINGS	
	String str = ""

	if (WaveDims(w) == 1)
		if (!DataFolderExists(df))
			return ""
		endif
		
		//	Nanonis dat
		NVAR/Z/SDFR=$df X__m_, Y__m_
		if (NVAR_Exists(X__m_) && NVAR_Exists(Y__m_))
			sprintf str, "<br>At: %.2W1Pm, %.2W1Pm", X__m_, Y__m_
			return str
		endif
		
		return ""
	endif
	
	if (DataFolderExists(df))
		//	Nanonis sxm
		NVAR/Z/SDFR=$df cx = center_x_m, cy = center_y_m
		if (NVAR_Exists(cx) && NVAR_Exists(cy))
			sprintf str, "<br>Center: %.2W1Pm, %.2W1Pm", cx, cy
			return str
		endif
		
		//	Nanonis 3ds
		SVAR/Z/SDFR=$df grid = Grid_settings
		if (SVAR_Exists(grid))
			sprintf str, "<br>Center: %.2W1Pm, %.2W1Pm", str2num(StringFromList(0,grid)), str2num(StringFromList(1,grid))
			return str
		endif
	endif
	
	Make/N=2/FREE cw = DimOffset(w,p)+DimDelta(w,p)*(DimSize(w,p)-1)/2
	Make/N=2/T/FREE tw = WaveUnits(w,p)
	sprintf str, "<br>Center: %.2W1P%s, %.2W1P%s", cw[0], tw[0], cw[1], tw[1]
	return str
End

Static Function/S getSetpoint(Wave w)
	String df = GetWavesDataFolder(w,1)+SIDAM_DF_SETTINGS
	if (!DataFolderExists(df))
		return ""
	endif
	
	String str
	sprintf str, "<br>Setpoint: %s @ %s", getCurrent(w), getBias(w)
	return str
End

Static Function/S getBias(Wave w)
	String df = GetWavesDataFolder(w,1)+SIDAM_DF_SETTINGS
	if (!DataFolderExists(df))
		return ""
	endif
	
	String str

	//	Nanonis sxm
	NVAR/Z/SDFR=$df bias_V
	if (NVAR_Exists(bias_V))
		sprintf str, "%.2W1PV", bias_V
		return str
	endif

	//	Nanonis 3ds, dat
	NVAR/Z/SDFR=$(df+":Bias") Bias__V_
	if (NVAR_Exists(Bias__V_))
		sprintf str, "%.2W1PV", Bias__V_
		return str
	endif
		
	return ""
End

Static Function/S getCurrent(Wave w)
	String df = GetWavesDataFolder(w,1)+SIDAM_DF_SETTINGS+":'Z-Controller'"
	if (!DataFolderExists(df))
		return ""
	endif

	String str

	//	Nanonis sxm, 3ds, dat
	//	When the value and unit of the setpoint current are given as two
	//	separated item
	NVAR/Z/SDFR=$df Setpoint_var = Setpoint
	SVAR/Z/SDFR=$df Setpoint_unit
	if (NVAR_Exists(Setpoint_var) && SVAR_Exists(Setpoint_unit))
		sprintf str, "%.2W1P%s", Setpoint_var, Setpoint_unit
		return str
	endif

	//	When both value and unit are given in a single item
	SVAR/Z/SDFR=$df Setpoint_str = Setpoint
	if (SVAR_Exists(Setpoint_str))
		Variable value
		String unit
		sscanf Setpoint_str, "%f %s", value, unit
		sprintf str, "%.2W1P%s",value, unit
		return str
	endif
	
	return ""
End
#endif