This is a package for using the linux Andor SDK with python.
It has three Classes:
* AndorSDK() for direct access to the Andor SDK functions
* ShamrockSDK() for direct acces to the Shamrock SDK functions
* Spectrometer() wrapps SDK functions for both camera and spectrograph




Usage Example:
```
import AndorSpectrometer
import numpy as np

spec = AndorSpectrometer.Spectrometer()
pic = spec.TakeImage()
...

```