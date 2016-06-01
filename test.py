
import numpy as np
import matplotlib.pyplot as plt
from AndorSpectrometer import Spectrometer

spec = Spectrometer()

spec.SetCentreWavelength(650)
spec.SetSingleTrack(100,105)
spec.SetExposureTime(10)
d = spec.TakeSingleTrack()
d2 = spec.TakeSingleTrack()

print(d.shape)

plt.plot(spec.GetWavelength(),d)
plt.show()

plt.plot(spec.GetWavelength(),d2)
plt.show()
