#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3	
#pragma ModuleName = SIDAMTest_Utilities_Img

Static Function TestSIDAM_ColorTableForImage()
	DFREF dfrSav = GetDataFolderDFR()
	SetDataFolder root:
	String str
	
	String name = UniqueName("wave",1,0)
	Make/N=(2,3) $name
	NewImage $name
	String grfName = S_name
	
	String rainbowStr = "Rainbow"
	ModifyImage/W=$grfName $name ctab= {*,*,Rainbow,0}
	str = SIDAM_ColorTableForImage(grfName,name)
	REQUIRE_EQUAL_STR(str,rainbowStr)
	
	str = SIDAM_ColorTableForImage(";",name)
	REQUIRE_EMPTY_STR(str)
	str = SIDAM_ColorTableForImage(grfName,";")
	REQUIRE_EMPTY_STR(str)
		
	//	color table wave is in the current datafolder
	ModifyImage/W=$grfName $name ctab= {*,*,$name,0}
	String path = "root:"+name
	str = SIDAM_ColorTableForImage(grfName,name)
	REQUIRE_EQUAL_STR(str,path)

	//	color table wave is in a different datafolder
	String dfname = UniqueName("df",11,0)
	NewDataFolder/S root:$dfName
	str = SIDAM_ColorTableForImage(grfName,name)
	REQUIRE_EQUAL_STR(str,path)
	
	//	teardown
	KillDataFolder root:$dfName
	KillWindow $grfName
	KillWaves $name
	SetDataFolder dfrSav
End

Static Function TestSIDAM_ColorTableLog()
	String name = UniqueName("wave",1,0)
	Make/N=(2,3) $name
	NewImage $name
	String grfName = S_name
	REQUIRE_EQUAL_VAR(SIDAM_ColorTableLog(grfName,name),0)
	
	ModifyImage/W=$grfName $name log=1
	REQUIRE_EQUAL_VAR(SIDAM_ColorTableLog(grfName,name),1)
	
	ModifyImage/W=$grfName $name cindex=$name, log=0
	REQUIRE_EQUAL_VAR(SIDAM_ColorTableLog(grfName,name),0)

	ModifyImage/W=$grfName $name cindex=$name, log=1
	REQUIRE_EQUAL_VAR(SIDAM_ColorTableLog(grfName,name),1)
	
	REQUIRE_EQUAL_VAR(SIDAM_ColorTableLog(":",name),-1)
	
	//	teardown
	KillWindow $grfName
	KillWaves $name
End

Static Function TestSIDAM_ImageColorRGBMode()
	String name = UniqueName("wave",1,0)
	Make/N=(2,3) $name
	NewImage $name
	String grfName = S_name
	REQUIRE_EQUAL_VAR(SIDAM_ImageColorRGBMode(grfName,name,"minRGB"),0)
	REQUIRE_EQUAL_VAR(SIDAM_ImageColorRGBMode(grfName,name,"maxRGB"),0)
	
	REQUIRE_EQUAL_VAR(SIDAM_ImageColorRGBMode(";",name,"minRGB"),-1)
	REQUIRE_EQUAL_VAR(SIDAM_ImageColorRGBMode(grfName,";","minRGB"),-1)
	REQUIRE_EQUAL_VAR(SIDAM_ImageColorRGBMode(grfName,name,""),-1)
	
	ModifyImage/W=$grfName $name ctab={0,0,Grays,0},minRGB=(0,0,0),maxRGB=(0,0,0)
	REQUIRE_EQUAL_VAR(SIDAM_ImageColorRGBMode(grfName,name,"minRGB"),1)
	REQUIRE_EQUAL_VAR(SIDAM_ImageColorRGBMode(grfName,name,"maxRGB"),1)
		
	ModifyImage/W=$grfName $name ctab={0,0,Grays,0},minRGB=NaN,maxRGB=NaN
	REQUIRE_EQUAL_VAR(SIDAM_ImageColorRGBMode(grfName,name,"minRGB"),2)
	REQUIRE_EQUAL_VAR(SIDAM_ImageColorRGBMode(grfName,name,"maxRGB"),2)

	ModifyImage/W=$grfName $name cindex=$name
	REQUIRE_EQUAL_VAR(SIDAM_ImageColorRGBMode(grfName,name,"minRGB"),2)
	REQUIRE_EQUAL_VAR(SIDAM_ImageColorRGBMode(grfName,name,"maxRGB"),2)
		
	ModifyImage/W=$grfName $name explicit=1
	REQUIRE_EQUAL_VAR(SIDAM_ImageColorRGBMode(grfName,name,"minRGB"),2)
	REQUIRE_EQUAL_VAR(SIDAM_ImageColorRGBMode(grfName,name,"maxRGB"),2)
	
	//	teardown
	KillWindow $grfName
	KillWaves $name
End

Static Function TestSIDAM_ImageColorRGBValues()
	String name = UniqueName("wave",1,0)
	Make/N=(2,3) $name
	NewImage $name
	String grfName = S_name
	
	STRUCT RGBColor s
	Make/B/U/N=3/FREE w0={1,2,3}, w1={4,5,6}
	ModifyImage/W=$grfName $name ctab={0,0,Grays,0},minRGB=(w0[0],w0[1],w0[2]),maxRGB=(w1[0],w1[1],w1[2])
	REQUIRE_EQUAL_VAR(SIDAM_ImageColorRGBValues(grfName,name,"minRGB",s),0)
	REQUIRE_EQUAL_WAVES({s.red,s.green,s.blue},w0,mode=WAVE_DATA)
	REQUIRE_EQUAL_VAR(SIDAM_ImageColorRGBValues(grfName,name,"maxRGB",s),0)
	REQUIRE_EQUAL_WAVES({s.red,s.green,s.blue},w1,mode=WAVE_DATA)

	REQUIRE_EQUAL_VAR(SIDAM_ImageColorRGBValues(";",name,"minRGB",s),1)
	REQUIRE_EQUAL_VAR(SIDAM_ImageColorRGBValues(grfName,";","minRGB",s),2)
	REQUIRE_EQUAL_VAR(SIDAM_ImageColorRGBValues(grfName,name,"",s),3)
	
	//	teardown
	KillWindow $grfName
	KillWaves $name
End