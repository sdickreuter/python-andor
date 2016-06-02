
import numpy as np
import time

import Andor.andorSDK as andor
import Shamrock.shamrockSDK as shamrock

class Spectrometer:

    verbosity = 2
    _max_slit_width = 2500 # maximal width of slit in um
    cam = None
    spec = None


    def __init__(self, start_cooler = False, init_shutter = False,verbosity = 2):
        self.verbosity = verbosity
        andor.verbosity = self.verbosity

        andor_initialized = andor.Initialize()
        time.sleep(2)
        shamrock_initialized = shamrock.Initialize()

        self._wl = None
        self._hstart = 100
        self._hstop = 110

        if andor_initialized and shamrock_initialized:

            andor.SetTemperature(-15)
            if start_cooler:
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
            self.min_width = 1
            self.max_width = self._width

            # Get Size of Pixels
            self._pixelwidth, self._pixelheight = andor.GetPixelSize()

            # //Initialize Shutter
            if init_shutter:
                andor.SetShutter(1, 0, 50, 50);

            # //Setup Image dimensions
            andor.SetImage(1, 1, 1, self._width, 1, self._height)

            #shamrock = ShamrockSDK()

            shamrock.SetNumberPixels(self._width)

            shamrock.SetPixelWidth(self._pixelwidth)

        else:
            raise RuntimeError("Could not initialize Spectrometer")


    def __del__(self):
        andor.Shutdown()
        shamrock.Shutdown()
        #andor = None
        #shamrock = None

    def SetExposureTime(self, seconds):
        andor.SetExposureTime(seconds)

    def SetSlitWidth(self, slitwidth):
        shamrock.SetAutoSlitWidth(1,slitwidth)

    def GetWavelength(self):
        return self._wl

    def SetFullImage(self):
        andor.SetImage(1, 1, 1, self._width, 1, self._height)

    def TakeFullImage(self):
        return self.TakeImage(self._width,self._height)

    def TakeImage(self, width, height):
        andor.SetReadMode(4)
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

        minwl, maxwl = shamrock.GetWavelengthLimits(shamrock.GetGrating())

        if (wavelength < maxwl) and (wavelength > minwl):
            shamrock.SetWavelength(wavelength)
            self._wl = shamrock.GetCalibration(self._width)
        else:
            pass


    def SetImageofSlit(self):
        # Calculate which pixels in x direction are acutally illuminated (usually the slit will be much smaller than the ccd)
        visible_xpixels = (self._max_slit_width)/self._pixelwidth
        min_width = round(self._width/2-visible_xpixels/2)
        max_width = self._width-min_width

        # This two values have to be adapter if to fit the image of the slit on your detector !
        min_width -= 20
        max_width += 0

        if min_width < 1 :
            min_width = 1
        if max_width > self._width:
            max_width = self._width

        self.min_width = min_width
        self.max_width = max_width

        andor.SetImage(1, 1, self.min_width, self.max_width, 1, self._height);

        shamrock.SetWavelength(0)


    def TakeImageofSlit(self):
        data = self.TakeImage(self.max_width-self.min_width+1,self._height)
        return data


    def SetSingleTrack(self,hstart,hstop):
        self._hstart = hstart
        self._hstop = hstop
        andor.SetImage(1, 1, 1, self._width, hstart, hstop);


    def TakeSingleTrack(self):
        andor.SetReadMode(4)
        andor.StartAcquisition()

        acquiring = True
        while acquiring:
            status = andor.GetStatus()
            if status == 20073:
                acquiring = False
            time.sleep(0.01)
        data = andor.GetAcquiredData(self._width, (self._hstop-self._hstart)+1 )
        return data