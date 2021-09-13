---
title: "SIDAMSyncCursor"
---
<p class="function_definition">SIDAMSyncCursor(<span class="function_variables">syncWinList, [mode]</span>)</p>

Synchronize the cursor position of windows.

## Parameters

**syncWinList :** ***string***  
The list of windows to be synchronized. If a window(s) that is
not synchronized, it is synchronized with the remaining windows.
If all the windows are synchronized, stop synchronization.

**mode :** ***int***  
0 or 1. 0 to synchronize in p and q, 1 to synchronize in x and y.
