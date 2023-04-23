#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3

#include ":csv_to_ibw_common"

Function save_colorbrewer_as_ibw()
	csv_to_ibw#save_csv_as_ibw("ColorBrewer")
End
