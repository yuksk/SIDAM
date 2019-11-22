#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3	
#pragma ModuleName = SIDAMTest_Utilities_Panel

Static Function TestSIDAMNewPanel()
	//	Check only title and size because the position requires the same commands
	//	used in SIDAMNewPanel
	String title = "abc"
	String name = SIDAMNewPanel(title, 100, 50)
	DoWindow $name
	REQUIRE_EQUAL_VAR(V_flag,1)
	GetWindow $name title
	REQUIRE_EQUAL_STR(S_Value,title)
	GetWindow $name wsizeDC
	REQUIRE_EQUAL_VAR(V_right,100)
	REQUIRE_EQUAL_VAR(V_bottom,50)
	REQUIRE_EQUAL_VAR(isFixed_IGNORE(name),1)
	REQUIRE_EQUAL_VAR(isFloated_IGNORE(name),0)
	KillWindow $name

	name = SIDAMNewPanel(title, 100, 50, resizable=0)
	REQUIRE_EQUAL_VAR(isFixed_IGNORE(name),1)
	KillWindow $name

	name = SIDAMNewPanel(title, 100, 50, resizable=1)
	REQUIRE_EQUAL_VAR(isFixed_IGNORE(name),0)
	KillWindow $name

	SIDAMNewPanel(title, 100, 50, float=0)
	REQUIRE_EQUAL_VAR(isFloated_IGNORE(name),0)
	KillWindow $name

	SIDAMNewPanel(title, 100, 50, float=1)
	REQUIRE_EQUAL_VAR(isFloated_IGNORE(name),1)
	KillWindow $name
End

Static Function isFixed_IGNORE(String name)
	String infoStr = WinRecreation(name,0)
	int n0 = strsearch(infoStr,"fixedSize",0)
	return n0 == -1 ? 0 : str2num(infoStr[n0+10])
End

Static Function isFloated_IGNORE(String name)
	String infoStr = WinRecreation(name,0)
	return strsearch(infoStr,"_endfloat_",0) != -1
End

Static Function TestSIDAMWindowExists()
	Display
	String grfName0 = S_name
	String nullStr
	REQUIRE_EQUAL_VAR(SIDAMWindowExists(grfName0),1)
	REQUIRE_EQUAL_VAR(SIDAMWindowExists(""),0)
	REQUIRE_EQUAL_VAR(SIDAMWindowExists("not_existing_window"),0)
	
	Display/HOST=$grfName0
	String grfName1 = grfName0 + "#" + S_name
	
	REQUIRE_EQUAL_VAR(SIDAMWindowExists(grfName1),1)
	REQUIRE_EQUAL_VAR(SIDAMWindowExists(grfName0+"#not_existing_subwindow"),0)
	
	Display/HOST=$grfName1
	String grfName2 = S_name

	REQUIRE_EQUAL_VAR(SIDAMWindowExists(grfName1+"#"+grfName2),1)
	REQUIRE_EQUAL_VAR(SIDAMWindowExists(grfName1+"#not_existing_subwindow"),0)
	REQUIRE_EQUAL_VAR(SIDAMWindowExists(grfName0+"#not_existing_subwindow#"+grfName2),0)

	KillWindow/Z $grfName0
End

