#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3	
#pragma ModuleName = SIDAMTest_Utilities_Panel

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
