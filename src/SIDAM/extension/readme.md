# Extension folder

Procedure files in this folder are included when SIDAM is started.
If you have your own macro used together with SIDAM, it's useful to put your ipf files in this folder.

## Example
An ipf file in this folder can be used to define your own shortcuts.
Here is an example to define a shortcut (Ctrl+1) setting a color scale (Autumn) to the top window.
Save this example with an arbitrary file name with an extension of .ipf (but it must be different from existing macro files) in this folder, restart the macro, and you can use the shortcut.

~~~
Menu "SIDAM"
	SubMenu "Extension"
		SubMenu "Shortcuts"
			"Set Autunm/1", /Q, SIDAMColor(ctable="Autumn")
		End
	End
End
~~~
