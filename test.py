
import numpy as np
import time
import matplotlib.pyplot as plt
from AndorSpectrometer import Spectrometer

spec = Spectrometer(start_cooler=False,init_shutter=True)
#time.sleep(30)

spec.SetCentreWavelength(650)
spec.SetSlitWidth(50)
spec.SetSingleTrack()
spec.SetExposureTime(1)
d = spec.TakeSingleTrack()
d2 = spec.TakeSingleTrack()

spec.SetFullImage()
img = spec.TakeFullImage()

spec.SetExposureTime(0.001)
spec.SetSlitWidth(2500)
spec.SetImageofSlit()
slit = spec.TakeImageofSlit()

print(d.shape)

plt.plot(spec.GetWavelength(),d)
plt.show()

plt.plot(spec.GetWavelength(),d2)
plt.show()

plt.imshow(img)
plt.show()

plt.imshow(slit)
plt.show()
