
import numpy as np
import Andor
import Shamrock

cam = Andor.Camera()
cam.Initialize()

spec = Shamrock.Spectrograph()
spec._Initialize()

