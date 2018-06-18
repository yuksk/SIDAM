# About file loader folder

Procedure files containing data loading functions are in this folder.

## To add your own function

### 1. Prepare your function

A data loading function of SIDAM receives a string of an absolute path to a data file and returns a data wave or a wave reference wave of data waves. Namely, the prototype of a data loading function is as follows.

~~~
Function/WAVE dataloadingfunction(String str)
End
~~~

Save your function in a procedure file and place the file in this folder.

### 2. Modify functions.default.ini

The main routine to load a data file selects a data loading function based on the extension of the file.
Relationship between extensions and data loading functions are written in functions.default.ini.
To add your function, modify functions.default.ini and save it as functions.ini.
See also functions.default.ini for details.