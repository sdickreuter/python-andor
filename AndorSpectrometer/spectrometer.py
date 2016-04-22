
import numpy as np
import time

from Andor.andorSDK import AndorSDK
from Shamrock.shamrockSDK import ShamrockSDK

class Spectrometer:

    verbosity = 2
    cam = None
    spec = None


    def __init__(self, verbosity = 2):
        self.verbosity = verbosity

        self.cam = AndorSDK()
        self.cam.verbosity = self.verbosity
        self.cam.Initialize()

        time.sleep(2)

        # //Set Read Mode to --Image--
        self.cam.SetReadMode(4);

        # //Set Acquisition mode to --Single scan--
        self.cam.SetAcquisitionMode(1);

        # //Set initial exposure time
        self.cam.SetExposureTime(1);

        # //Get Detector dimensions
        self.width, self.height = self.cam.GetDetector()
        print((self.width, self.height))

        # Get Size of Pixels
        self.pixelwidth, self.pixelheight = self.cam.GetPixelSize()

        # //Initialize Shutter
        self.cam.SetShutter(1, 0, 50, 50);

        # //Setup Image dimensions
        self.cam.SetImage(1, 1, 1, self.width, 1, self.height);

        self.spec = ShamrockSDK()

        self.spec.Initialize()

        self.spec.SetNumberPixels(self.width)

        self.spec.SetPixelWidth(self.pixelwidth)


    def __del__(self):
        self.cam = None
        self.spec = None

