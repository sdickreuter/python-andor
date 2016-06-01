
import numpy as np
import time

import Andor.andorSDK as andor
import Shamrock.shamrockSDK as shamrock

class Spectrometer:

    verbosity = 2
    _max_slit_width = 2500 # maximal width of slit in um
    cam = None
    spec = None


    def __init__(self, verbosity = 2):
        self.verbosity = verbosity
        andor.verbosity = self.verbosity

        andor_initialized = andor.Initialize()
        time.sleep(2)
        shamrock_initialized = shamrock.Initialize()

        if andor_initialized and shamrock_initialized:

            andor.SetTemperature(-15)
            andor.CoolerON()

            # //Set Read Mode to --Image--
            andor.SetReadMode(4);

            # //Set Acquisition mode to --Single scan--
            andor.SetAcquisitionMode(1);

            # //Set initial exposure time
            andor.SetExposureTime(10);

            # //Get Detector dimensions
            self._width, self._height = andor.GetDetector()
            print((self._width, self._height))

            # Get Size of Pixels
            self._pixelwidth, self._pixelheight = andor.GetPixelSize()

            # //Initialize Shutter
            #andor.SetShutter(1, 0, 50, 50);

            # //Setup Image dimensions
            andor.SetImage(1, 1, 1, self._width, 1, self._height)

            #shamrock = ShamrockSDK()

            shamrock.SetNumberPixels(self._width)

            shamrock.SetPixelWidth(self._pixelwidth)

        else:
            raise RuntimeError("Could not initialize Spectrometer")


    def __del__(self):
        andor = None
        shamrock = None

    def TakeFullImage(self):
        andor.SetImage(1, 1, 1, self._width, 1, self._height)
        return self.TakeImage(self._width, self._height)

    def TakeImage(self, width, height):
        andor.SetReadMode(4);
        andor.StartAcquisition()

        acquiring = True
        while acquiring:
            status = andor.GetStatus()
            if status == 20073:
                acquiring = False
            time.sleep(0.01)
        data = andor.GetAcquiredData(width, height)
        return data.transpose()

    def SetCentreWavelength(self,wavelength):

        minwl, maxwl = shamrock.GetWavelengthLimits()

        if wavelength < maxwl & wavelength > minwl:
            shamrock.SetWavelength(wavelength)
        else:
            pass


    def TakeImageofSlit(self, reset = False):
        #get inital settings
        if reset:
            wavelength = shamrock.GetWavelength()
            slit = shamrock.GetAutoSlitWidth(1)

        # Calculate which pixels in x direction are acutally illuminated (usually the slit will be much smaller than the ccd)
        visible_xpixels = (self._max_slit_width)/self._pixelwidth
        min_width = round(self._width/2-visible_xpixels/2)
        max_width = self._width-min_width

        min_width -= 20
        max_width += 20

        if min_width < 1 :
            min_width = 1
        if max_width > self._width:
            max_width = self._width

        print((min_width,max_width))

        andor.SetImage(1, 1, min_width, max_width, 1, self._height);

        shamrock.SetWavelength(0)
        shamrock.SetAutoSlitWidth(1, self._max_slit_width)

        data = self.TakeImage(max_width-min_width+1,self._height)

        # return to old settings
        if reset:
            shamrock.SetWavelength(wavelength)
            shamrock.SetAutoSlitWidth(slit)
            andor.SetImage(1, 1, 1, self._width, 1, self._height);

        return data.transpose()


    def SetSingleTrack(self,hstart,hstop):

        andor.SetImage(1, 1, 1, self._width, hstart, hstop);


    def TakeSpectrum(self):
        pass