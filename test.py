
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

spec.SetFullImage()
img = spec.TakeFullImage()

spec.SetExposureTime(0.001)
spec.SetSlitWidth(2500)
spec.SetImageofSlit()
slit = spec.TakeImageofSlit()

print(d.shape)

plt.plot(spec.GetWavelength(),np.mean(d,1))
plt.show()

plt.plot(spec.GetWavelength(),np.mean(d2,1))
plt.show()

plt.imshow(img)
plt.show()

plt.imshow(slit)
plt.show()