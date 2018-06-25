# About extension folder

Procedure files in this folder are included when the macro is started.

A usage of this folder is to define shortcuts for yourself.
Here is an example to define a shortcut (Ctrl+1) setting a color scale (Autumn) to the top window.
Save this example with an arbitrary file name with an extension of .ipf (but it must be different from existing macro files) in this folder, restart the macro, and you can use the shortcut.

~~~
Menu "SIDAM"
	SubMenu "Extension"
		SubMenu "Shortcuts"
			"Set Autunm/1", /Q, KMColor(ctable="Autumn")
		End
	End
End
~~~