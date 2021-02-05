#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3
#pragma moduleName = KMScaleBar

#include "SIDAM_ScaleBar"

//	This is for backward compatibility

Static StrConstant NEWNAME = "SIDAMScalebar"
Static StrConstant OLDNAME = "KMScalebar"

Static Function hook(STRUCT WMWinHookStruct &s)
	STRUCT oldStruct os
	StructGet/S os, GetUserData(s.winName,"",OLDNAME)
	SetWindow $s.winName userData($OLDNAME)=""
	
	STRUCT newStruct ns
	ns.anchor[0] = os.anchor[0]
	ns.anchor[1] = os.anchor[1]
	ns.fontsize = os.fontsize
	ns.fgRGBA = os.fgRGBA
	ns.bgRGBA = os.bgRGBA
	ns.overwrite[0] = 0
	ns.overwrite[1] = 0
	ns.overwrite[2] = 0
	ns.overwrite[3] = 0
	ns.box = os.box
	ns.xmin = os.xmin
	ns.xmax = os.xmax
	ns.ymin = os.ymin
	ns.ymax = os.ymax
	ns.ticks = os.ticks
	String str
	StructPut/S ns, str
	SetWindow $s.winName userData($NEWNAME)=str

	SetWindow $s.winName hook($NEWNAME)=SIDAMScaleBar#hook
	SetWindow $s.winName hook($OLDNAME)=$""
End

Static Structure oldStruct
	uchar	anchor[2]
	uint16	fontsize
	STRUCT	RGBAColor	fgRGBA
	STRUCT	RGBAColor	bgRGBA
	uchar	stop
	STRUCT	RectF box
	double	xmin, xmax, ymin, ymax
	double	ticks
EndStructure

Static Structure newStruct
	uchar	anchor[2]
	uint16	fontsize
	STRUCT	RGBAColor	fgRGBA
	STRUCT	RGBAColor	bgRGBA
	uchar overwrite[4]
	STRUCT	RectF box
	double	xmin, xmax, ymin, ymax
	double	ticks
EndStructure

Static Function deleteBar(String grfName)
	DrawAction/L=ProgFront/W=$grfName getgroup=$OLDNAME, delete
End