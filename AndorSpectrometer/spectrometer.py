import numpy as np
import time
import sys
import Andor.andorSDK as andor
import Shamrock.shamrockSDK as shamrock

from PyQt5.QtCore import QMutex, QMutexLocker


class Spectrometer:
    verbosity = 2
    _max_slit_width = 2500  # maximal width of slit in um
    cam = None
    spec = None
    closed = False
    lock = QMutex()
    mode = None


    def __init__(self, start_cooler=False, init_shutter=False, verbosity=2):
        self.verbosity = verbosity
        andor.verbosity = self.verbosity
        shamrock.verbosity = self.verbosity

        self._wl = None
        self._hstart = 100
        self._hstop = 110
        self.exp_time = 0.2
        andor_initialized = 0
        shamrock_initialized = 0

        with QMutexLocker(self.lock):
            andor_initialized = andor.Initialize()
            time.sleep(2)
            shamrock_initialized = shamrock.Initialize()

        if (andor_initialized > 0) and (shamrock_initialized > 0):

            with QMutexLocker(self.lock):
                andor.SetTemperature(-15)
                if start_cooler:
                    andor.CoolerON()

                # //Set Read Mode to --Image--
                andor.SetReadMode(4);

                # //Set Acquisition mode to --Single scan--
                andor.SetAcquisitionMode(1);

                # //Set initial exposure time
                andor.SetExposureTime(self.exp_time);

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

                # shamrock = ShamrockSDK()

                shamrock.SetNumberPixels(self._width)

                shamrock.SetPixelWidth(self._pixelwidth)

        else:
            raise RuntimeError("Could not initialize Spectrometer")
            sys.exit(0)

    def __del__(self):
        if not self.closed:
            self.lock.unlock()
            andor.Shutdown()
            shamrock.Shutdown()
        #print("Begin AndorSpectrometer.__del__")
        # if not self.closed:
        #     try:
        #         andor.Shutdown()
        #     except (AttributeError, TypeError) as e:
        #         print(e)
        #     try:
        #         shamrock.Shutdown()
        #     except (AttributeError, TypeError) as e:
        #         print(e)
        #print("End AndorSpectrometer.__del__")

    def Shutdown(self):
        andor.Shutdown()
        shamrock.Shutdown()
        self.closed = True

    def GetTemperature(self):
        with QMutexLocker(self.lock):
            return andor.GetTemperature()

    def GetSlitWidth(self):
        with QMutexLocker(self.lock):
            return shamrock.GetAutoSlitWidth(1)

    def GetGratingInfo(self):
        with QMutexLocker(self.lock):
            num_gratings = shamrock.GetNumberGratings()
            gratings = {}
            for i in range(num_gratings):
                lines, blaze, home, offset = shamrock.GetGratingInfo(i+1)
                gratings[i+1] = lines
        return gratings

    def GetGrating(self):
        with QMutexLocker(self.lock):
            return shamrock.GetGrating()

    def SetGrating(self, grating):
        with QMutexLocker(self.lock):
            return shamrock.SetGrating(grating)

    def AbortAcquisition(self):
        with QMutexLocker(self.lock):
            andor.AbortAcquisition()

    def SetNumberAccumulations(self, number):
        with QMutexLocker(self.lock):
            andor.SetNumberAccumulations(number)

    def SetExposureTime(self, seconds):
        self.exp_time = seconds
        with QMutexLocker(self.lock):
            andor.SetExposureTime(seconds)

    def SetSlitWidth(self, slitwidth):
        with QMutexLocker(self.lock):
            shamrock.SetAutoSlitWidth(1, slitwidth)

    def GetWavelength(self):
        return self._wl

    def SetFullImage(self):
        with QMutexLocker(self.lock):
            andor.SetImage(1, 1, 1, self._width, 1, self._height)
        self.mode = "Image"

    def TakeFullImage(self):
        with QMutexLocker(self.lock):
            return self.TakeImage(self._width, self._height)

    def TakeImage(self, width, height):
        with QMutexLocker(self.lock):
            print(andor.ERROR_CODE[andor.GetStatus()])
            andor.StartAcquisition()
            acquiring = True
            while acquiring:
                status = andor.GetStatus()
                if status == 20073:
                    acquiring = False
                elif not status == 20072:
                    print(andor.ERROR_CODE[status])
                    return None
            data = andor.GetAcquiredData(width, height)
            return data.transpose()

    def SetCentreWavelength(self, wavelength):
        with QMutexLocker(self.lock):
            minwl, maxwl = shamrock.GetWavelengthLimits(shamrock.GetGrating())

        if (wavelength < maxwl) and (wavelength > minwl):
            with QMutexLocker(self.lock):
                shamrock.SetWavelength(wavelength)
                self._wl = shamrock.GetCalibration(self._width)
        else:
            pass

    def SetImageofSlit(self):
        # Calculate which pixels in x direction are acutally illuminated (usually the slit will be much smaller than the ccd)
        visible_xpixels = (self._max_slit_width) / self._pixelwidth
        min_width = round(self._width / 2 - visible_xpixels / 2)
        max_width = self._width - min_width

        # This two values have to be adapter if to fit the image of the slit on your detector !
        min_width -= 25
        max_width -= 5

        if min_width < 1:
            min_width = 1
        if max_width > self._width:
            max_width = self._width

        self.min_width = min_width
        self.max_width = max_width

        with QMutexLocker(self.lock):
            andor.SetImage(1, 1, self.min_width, self.max_width, 1, self._height);
            shamrock.SetWavelength(0)
        self.mode = "Image"

    def TakeImageofSlit(self):
        with QMutexLocker(self.lock):
            data = self.TakeImage(self.max_width - self.min_width + 1, self._height)
        return data

    def SetSingleTrack(self, hstart=None, hstop=None):
        if (hstart is None) or (hstop is None):
            with QMutexLocker(self.lock):
                slitwidth = shamrock.GetAutoSlitWidth(1)
            pixels = (slitwidth / self._pixelheight)
            middle = self._height / 2
            self._hstart = round(middle - pixels / 2)
            self._hstop = round(middle + pixels / 2)
        else:
            self._hstart = hstart
            self._hstop = hstop
        with QMutexLocker(self.lock):
            andor.SetImage(1, 1, 1, self._width, self._hstart, self._hstop);
        self.mode = "SingleTrack"

    def TakeSingleTrack(self):
        with QMutexLocker(self.lock):
            andor.SetExposureTime(self.exp_time)
            andor.StartAcquisition()
        acquiring = True
        #i = 0
        while acquiring:
            time.sleep(0.01)
            with QMutexLocker(self.lock):
                status = andor.GetStatus()
            if status == 20073:
                acquiring = False
            elif not status == 20072:
                print(andor.ERROR_CODE[status])
                return np.zeros(self._width)
            #if (i+1)*0.01 > self.exp_time:
            #    print("Acquisition is taking longer than expected, exiting")
            #    return np.zeros(self._width)
            #i += 1
        with QMutexLocker(self.lock):
            data = andor.GetAcquiredData(self._width, (self._hstop - self._hstart) + 1)
        data = np.mean(data,1)
        return data
