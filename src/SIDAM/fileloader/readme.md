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

Save your function in a procedure file.

### 2 Place your procedure file

You can add your procedure file here. Instead, you can put your procedure file
at any location. If you do so, you need to specify the folder where you put
your procedure file in the configuration file. See below.

### 3. Modify the configuration file

The main routine to load a data file selects a loading function based on the
extension of the data file. You need to register your function in the
configuration file. Also, if you put your procedure file at any place not here,
you need to specify the folder in the configuration file. `SIDAM.default.toml`
for details.
