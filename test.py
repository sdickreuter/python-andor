
import numpy as np
import matplotlib.pyplot as plt
import AndorSpectrometer

spec = AndorSpectrometer.Spectrometer()

data = spec.TakeImageofSlit()

plt.imshow(data)
plt.show()

