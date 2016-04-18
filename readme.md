This is a package for using the linux Andor SDK with python.

Usage Example:
```
import Andor
import numpy as np

cam = Andor.Camera()
cam.Initialize()
data = cam.TakeImage()

```