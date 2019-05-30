#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3

#ifndef SIDAMshowProc
#pragma hide = 1
#endif

#include "unit-testing"
#include ":SIDAMTest_Utilities_Bias"
#include ":SIDAMTest_Utilities_Control"
#include ":SIDAMTest_Utilities_ImageInfo"
#include ":SIDAMTest_Utilities_Panel"
#include ":SIDAMTest_Utilities_WaveDf"
#include ":SIDAMTest_Subtraction"

Menu "SIDAM"
	SubMenu "Developer"
		SubMenu "Test"
			"All Test", SIDAMTest("")
			"-"
			"Subtraction", SIDAMTest("SIDAMTest_Subtraction")
			"Utilities_Bias", SIDAMTest("SIDAMTest_Utilities_Bias")
			"Utilities_Control", SIDAMTest("SIDAMTest_Utilities_Control")
			"Utilities_ImageInfo", SIDAMTest("SIDAMTest_Utilities_ImageInfo")
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

