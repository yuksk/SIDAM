#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3

#include "unit-testing"
#include ":SIDAMTest_Utilities_Img"
#include ":SIDAMTest_Utilities_Panel"

Menu "SIDAM"
	SubMenu "Developer"
		"Execute Test", SIDAMTest()
	End
End

Function SIDAMTest()
	RunTest("SIDAMTest_.+\\.ipf",enableRegExp=1)
End