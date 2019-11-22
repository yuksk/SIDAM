#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3
#pragma ModuleName = SIDAMTest_Utilities_Control

//	SIDAMUtilControl#getEventMod() has to be tested by calling SIDAMTest_Utilities_Control#Test_getEventMod_IGNORE()

Static Function Test_getActionFunctionName()
	NewPanel
	String pnlName = S_name
	Button b0
	
	ControlInfo/W=$pnlName b0
	String fnName = SIDAMUtilControl#getActionFunctionName(S_recreation)
	CHECK_EMPTY_STR(fnName)
	
	//	prepare two buttons, one has "proc=***" at the middle of the recreation string
	//	and the other at the end
	String expectedName = "SIDAMTest_Utilities_Control#buttonProc"
	Button b0 proc=$expectedName, title="b0", win=$pnlName
	Button b1 proc=$expectedName, win=$pnlName
	ControlInfo/W=$pnlName b0
	fnName = SIDAMUtilControl#getActionFunctionName(S_recreation)
	CHECK_EQUAL_STR(fnName,expectedName)

	ControlInfo/W=$pnlName b1
	fnName = SIDAMUtilControl#getActionFunctionName(S_recreation)
	CHECK_EQUAL_STR(fnName,expectedName)
		
	KillWindow $pnlName
End

Static Function buttonProc(STRUCT WMButtonAction &s)
End

Static Function Test_getWinRect()
	NewPanel/W=(0,0,200,100)
	
	STRUCT Rect s
	SIDAMUtilControl#getWinRect(S_name,s)
	CHECK_EQUAL_VAR(s.left,0)
	CHECK_EQUAL_VAR(s.top,0)
	CHECK_EQUAL_VAR(s.right,200)
	CHECK_EQUAL_VAR(s.bottom,100)

	KillWindow $S_name
End

Static Function Test_getCtrlRect()
	NewPanel
	String pnlName = S_name
	Button b0 pos={1,2}, size={20,30}
	
	STRUCT Rect s
	SIDAMUtilControl#getCtrlRect(pnlName,"b0",s)
	CHECK_EQUAL_VAR(s.left,1)
	CHECK_EQUAL_VAR(s.top,2)
	CHECK_EQUAL_VAR(s.right,21)
	CHECK_EQUAL_VAR(s.bottom,32)

	KillWindow $pnlName
End

Static Function Test_getEventMod_IGNORE()
	String testStr = ""
	testStr += "click:1;"
	testStr += "click with shift pressed:3;"
	testStr += "click with alt pressed:5;"
	testStr += "click with ctrl pressed:9;"
	testStr += "click with shift and alt pressed:7;"
	//	This can not be tested because clicking with alt and ctrl pressed is assigned
	//	to select a control
//	testStr += "click with alt and ctrl pressed:13;"
	testStr += "click with ctrl and shift pressed:11;"
	testStr += "click with shift, alt, and ctrl pressed:15;"
	NewPanel
	SetWindow $S_name userData(testItem)="0"
	SetWindow $S_name userData(testStr)=testStr
	SetWindow $S_name userData(errorCount)="0"
	SetWindow $S_name hook(test)=SIDAMTest_Utilities_Control#Test_getEventModHook_IGNORE
	TitleBox title0 title=StringFromList(0,StringFromList(0,testStr),":"), frame=0, win=$S_name
End

Static Function Test_getEventModHook_IGNORE(STRUCT WMWinHookStruct &s)
	if (s.eventCode != 3)
		return 0
	endif

	int modifier = SIDAMUtilControl#getEventMod()
	int item = str2num(GetUserData(s.winName,"","testItem"))
	String str = GetUserData(s.winName,"","testStr")
	int expected = str2num(StringFromList(1,StringFromList(item,str),":"))
	if (modifier != expected)
		printf "error in %s\r", StringFromList(0,StringFromList(item,str),":")
		printf "expected: %s\r", StringFromList(1,StringFromList(item,str),":")
		printf "returned: %d\r", num2istr(modifier)
		SetWindow $s.winName userData(errorCount)=num2istr(str2num(GetUserData(s.winName,"","errorCount"))+1)
	endif
	
	if (item == ItemsInList(str)-1)
		int count = str2num(GetUserData(s.winName,"","errorCount"))
		if (count == 1)
			printf "1 error was found\r"
		elseif (count)
			printf "%d errors were found\r"
		else
			printf "no error was found\r"
		endif
		KillWindow $s.winName
	else
		SetWindow $s.winName userData(testItem)=num2istr(++item)
		TitleBox title0 title=StringFromList(0,StringFromList(item,str),":"), win=$s.winName
	endif
End

