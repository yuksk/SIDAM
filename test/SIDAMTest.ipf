#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3

#include "unit-testing"
#include ":SIDAMTest_ImageInfo"
#include ":SIDAMTest_Utilities_Panel"
#include ":SIDAMTest_Utilities_WaveDf"

Menu "SIDAM"
	SubMenu "Developer"
		SubMenu "Test"
			"All Test", SIDAMTest("")
			"-"
			"ImageInfo", SIDAMTest("SIDAMTest_ImageInfo")
			"Utilities_Panel", SIDAMTest("SIDAMTest_Utilities_Panel")
			"Utilities_WaveDf", SIDAMTest("SIDAMTest_Utilities_WaveDf")
		End
	End
End

Function SIDAMTest(String filename)
	if (strlen(filename))
		RunTest(filename+".ipf")	
	else
		RunTest("SIDAMTest_.+\\.ipf",enableRegExp=1)
	endif
End

