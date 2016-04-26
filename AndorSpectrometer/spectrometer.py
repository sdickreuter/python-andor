
import numpy as np
import time

from Andor.andorSDK import AndorSDK
from Shamrock.shamrockSDK import ShamrockSDK

class Spectrometer:

    verbosity = 2
    _max_slit_width = 2.5 # maximal width of slit in mm
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
        self._width, self._height = self.cam.GetDetector()
        print((self._width, self._height))

        # Get Size of Pixels
        self._pixelwidth, self._pixelheight = self.cam.GetPixelSize()

        # //Initialize Shutter
        self.cam.SetShutter(1, 0, 50, 50);

        # //Setup Image dimensions
        self.cam.SetImage(1, 1, 1, self._width, 1, self._height);

        self.spec = ShamrockSDK()

        self.spec.Initialize()

        self.spec.SetNumberPixels(self._width)

        self.spec.SetPixelWidth(self._pixelwidth)


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

        # Calculate which pixels in x direction are acutally illuminated (usually the slit will be much smaller than the ccd)
        visible_xpixels = self._max_slit_width/self._pixelwidth
        min_width = round(self._width/2-visible_xpixels/2)
        max_width = self._width-min_width
        print((min_width,max_width))

        self.cam.SetImage(1, 1, min_width, max_width, 1, self._height);

        self.spec.SetWavelength(0)
        self.spec.SetAutoSlitWidth(0, self._max_slit_width)

        data = self.TakeImage()

        # return to old settings
        if reset:
            self.spec.SetWavelength(wavelength)
            self.spec.SetAutoSlitWidth(slit)
            self.cam.SetImage(1, 1, 1, self._width, 1, self._height);

        return data


    def TakeSpectrum(self):
