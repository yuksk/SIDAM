# File loader folder

Procedure files containing data loading functions are in this folder.

## To add your own function

### 1. Prepare your function

A data loading function of SIDAM takes a string of an absolute path to a data
file and returns a data wave or a wave reference wave of data waves.
The prototype of a data loading function is as follows.

```IGOR Pro
Function/WAVE dataloadingfunction(String str)
End
```

Save your function in a procedure file and place the file in this folder.

### 2. Modify SIDAM.toml

The main routine to load a data file selects a data loading function based
on the extension of the file. Relationship between extensions and data loading
functions are written in `SIDAM.toml`. See `SIDAM.default.toml` for details.
