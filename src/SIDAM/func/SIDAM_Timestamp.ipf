#pragma TextEncoding="UTF-8"
#pragma rtGlobals=3
#pragma ModuleName=SIDAMUtilTimestamp

#ifndef SIDAMshowProc
#pragma hide = 1
#endif

//@
//	Convert a timestamp string to the number of seconds since midnight on 1904-01-01.
//
//	## Parameters
//	timestr : string
//		A timestamp string.
//		* The date and time must be separated by a space.
//		* The date format can be either "yyyy-mm-dd" or "yyyy/mm/dd".
//		* The time format is "HH:MM:SS".
//		* Seconds can include a decimal point.
//
//		Examples: "2024-07-05 13:15:12", "2024/07/05 13:15:12.22"
//
//	## Returns
//	variable
//		The number of seconds since midnight on 1904-01-01.
//@
ThreadSafe Function SIDAMTimestamp(String timestr)
	Variable yyyy, mm, dd, hour, minite, second, status = 0

	//	e.g. 2024-07-05 13:15:12 or 2024/07/05 13:15:12.22
	if (GrepString(timestr, "\\d{4}[-/]\\d{2}[-/]\\d{2} \\d{1,2}:\\d{2}:\\d{2}(\.\\d*)?"))
		sscanf timestr, "%4d%*[-/]%2d%*[-/]%2d %2d:%2d:%f", yyyy, mm, dd, hour, minite, second
		status = 1
	endif

	return status ? date2secs(yyyy, mm, dd) + hour*3600 + minite*60 + second : NaN
End