
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

    def TakeImage(self):
        self.cam.StartAcquisition()

        acquiring = True
        while acquiring:
            status = self.cam.GetStatus()
            if status == 20073:
                acquiring = False
            time.sleep(0.01)

        data = self.cam.GetAcquiredData(self._width, self._height)
        return data

    def SetCentreWavelength(self,wavelength):

        minwl, maxwl = self.spec.GetWavelengthLimits()

        if wavelength < maxwl & wavelength > minwl:
            self.spec.SetWavelength(wavelength)
        else:
            pass


    def TakeImageofSlit(self, reset = False):
        #get inital settings
        if reset:
            wavelength = self.spec.GetWavelength()
            slit = self.spec.GetAutoSlitWidth(0)

        self.cam.SetImage(1, 1, 1, self.width, 1, self.height);

        self.spec.SetWavelength(0)
        self.spec.SetAutoSlitWidth(0, 2500) #TODO: check unit of slit width !

        data = self.TakeImage()

        # return to old settings
        if reset:
            self.spec.SetWavelength(wavelength)
            self.spec.SetAutoSlitWidth(slit)
            self.cam.SetImage(1, 1, 1, self.width, 1, self.height);


        return data