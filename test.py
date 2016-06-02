
import numpy as np
import time
import matplotlib.pyplot as plt
from AndorSpectrometer import Spectrometer

spec = Spectrometer()
time.sleep(30)
spec.SetCentreWavelength(650)
spec.SetSingleTrack(100,105)
spec.SetExposureTime(1)
d = spec.TakeSingleTrack()
d2 = spec.TakeSingleTrack()
img = spec.TakeFullImage()
spec.SetExposureTime(0.001)
slit = spec.TakeImageofSlit(True)

print(d.shape)

plt.plot(spec.GetWavelength(),d)
plt.show()

plt.plot(spec.GetWavelength(),d2)
plt.show()

plt.imshow(img)
plt.show()

plt.imshow(slit)
plt.show()