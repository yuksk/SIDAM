#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3
#pragma ModuleName = SIDAMUtilDev

#ifndef SIDAMshowProc
#pragma hide = 1
#endif

Static Function/S menu()
	return SelectString(defined(SIDAMshowProc), "Show", "Hide")+" SIDAM Procedures"
End

//	Show or hide procedures of SIDAM in the procedure list (Window > Procedure Windows)
Function SIDAMShowProcedures()
	if (defined(SIDAMshowProc))
		Execute/P/Q "SetIgorOption poundUndefine=SIDAMshowProc"
	else
		Execute/P/Q "SetIgorOption poundDefine=SIDAMshowProc"
	endif
	Execute/P "COMPILEPROCEDURES "
End

//	Function to load xml files at http://www.paraview.org/Wiki/Colormaps into waves
Function SIDAMxml2ibw()
	Variable refNum
	Open/R refNum
	if (!refNum)
		return 0
	endif

	String buffer, name

	do
		FReadLine refNum, buffer
		if (!strlen(buffer))
			break
		elseif (strsearch(buffer, "<ColorMap ",0)>=0)
			name = StringByKey("name", buffer,"="," ")
			name = CleanupName(name[1,strlen(name)-2],1)
			if (WaveExists($name))
				print name
				Duplicate xml2wave(refNum) $UniqueName(name,1,0)
			else
				Duplicate xml2wave(refNum) $name
			endif
		endif
	while(1)

	Close refNum
End

Static Function/WAVE xml2wave(Variable refNum)
	String buffer
	int n

	Make/N=0/FREE xw, rw, gw, bw
	do
		FReadLine refNum, buffer
		if (strsearch(buffer,"</ColorMap>",0)>=0)
			break
		endif
		Redimension/N=(numpnts(xw)+1) xw, rw, gw, bw
		xw[inf] = getValue("x", buffer)
		rw[inf] = getValue("r", buffer)
		gw[inf] = getValue("g", buffer)
		bw[inf] = getValue("b", buffer)
	while(1)

	Make/N=(numpnts(xw))/FREE rw2, gw2, bw2
	Setscale/I x WaveMin(xw), WaveMax(xw), "", rw2, gw2, bw2
	Interpolate2/T=1/Y=rw2/I=3 xw,rw
	Interpolate2/T=1/Y=gw2/I=3 xw,gw
	Interpolate2/T=1/Y=bw2/I=3 xw,bw

	Make/W/U/N=(numpnts(xw),3)/FREE rtnw
	rtnw[][0] = round(rw2[p]*65535)
	rtnw[][1] = round(gw2[p]*65535)
	rtnw[][2] = round(bw2[p]*65535)
	return rtnw
End

Static Function getValue(String key, String buffer)
	String str = StringByKey(key, buffer, "=", " ")
	return str2num(str[1,strlen(str)-2])
End
