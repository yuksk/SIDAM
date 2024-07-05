---
title: "SIDAMTimestamp"
---
<p class="function_definition">SIDAMTimestamp(<span class="function_variables">timestr</span>)</p>

Convert a timestamp string to the number of seconds since midnight on 1904-01-01.

## Parameters

**timestr :** ***string***  
A timestamp string. 
* The date and time must be separated by a space.
* The date format can be either "yyyy-mm-dd" or "yyyy/mm/dd".
* The time format is "HH:MM:SS".
* Seconds can include a decimal point.

**Examples:** ***"2024-07-05 13:15:12", "2024/07/05 13:15:12.22"***  

## Returns
***variable***  
The number of seconds since midnight on 1904-01-01.
