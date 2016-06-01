This is a package for using the linux Andor SDK with python.
It has three modules:
* AndorSDK for direct access to the Andor SDK functions
* ShamrockSDK for direct acces to the Shamrock SDK functions
* AndorSpectrometer.Spectrometer() wrapps SDK functions for both camera and spectrograph in one class


Usage Example:
```
import AndorSpectrometer
import numpy as np

spec = AndorSpectrometer.Spectrometer()
pic = spec.TakeImage()
...

```

**Important:**
When you use the TEC Cooler with temperatures below -20°C your programm has to make sure that the
TEC is only switched off when the temperature is above -20°C, and not earlier.
So you have to call Andor.Shutdown() if anythin goes wrong, this will let the TEC-Controller slowly
increase the temperature until the detector is warm enough.
For example you can us a try finnally block:
```
import AndorSpectrometer

try:
    spec= AndorSpectrometer.Spectrometer()
    ...
    ...
finally:
    AndorSpectrometer.Andor.Shutdown()

```