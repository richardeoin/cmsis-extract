**cmsis-extract** is a utility for extracting device data for CMSIS from the
  user manuals of NXP's LPCxxxx series microcontrollers. This is just a fancy
  parser to turn the *Register overview* tables into C structs and macro
  definitions, you should use `pdftotext -layout` first to turn the PDF into a
  text file.

This script outputs `cmsis_device.h`. You should insert the code generated there
into a new `Device.h` CMSIS file by hand. You can find a BSD-Licensed template
[here](https://github.com/pfalcon/ARM-CMSIS-BSD/blob/master/Device/_Template_Vendor/Vendor/Device/Include/Device.h).

## Prequesites ##

`Ruby` and `pdftotext`

## Usage ##

Use `pdftotext -layout <PDF-file> <text-file>` to create a text file from the
user manual.

Then run `ruby extract.rb` and follow the prompts.

**The output is unlikely to be fully correct, you will need to do some by hand
  youself! Be sure to check against the device datasheet**

## License ##

MIT
