import numpy as np
import time
import sys
import Andor.andorSDK as Andor
import Shamrock.shamrockSDK as Shamrock


class Spectrometer:
    verbosity = 2
    _max_slit_width = 2500  # maximal width of slit in um
    exp_time = 1.0
    cam = None
    spec = None
    closed = False
    mode = None
    single_track_minimum_vertical_pixels = 0

    def __init__(self, start_cooler=False, init_shutter=False, verbosity=2):

        self.andor = Andor.Andor(verbosity)
        self.shamrock = Shamrock.Shamrock(verbosity)

        self._wl = None
        self._hstart = 128-5
        self._hstop = 128+5
        andor_initialized = 0
        shamrock_initialized = 0

        andor_initialized = self.andor.Initialize()
        time.sleep(2)
        shamrock_initialized = self.shamrock.Initialize()

        if (andor_initialized > 0) and (shamrock_initialized > 0):

            self.andor.SetTemperature(-15)
            if start_cooler:
                self.andor.CoolerON()

            # //Set Read Mode to --Image--
            self.andor.SetReadMode(4)

            # //Set Acquisition mode to --Single scan--
            self.andor.SetAcquisitionMode(1)

            # //Get Detector dimensions
            self._width, self._height = self.andor.GetDetector()
            # print((self._width, self._height))
            self.min_width = 1
            self.max_width = self._width

            # Get Size of Pixels
            self._pixelwidth, self._pixelheight = self.andor.GetPixelSize()

            # //Initialize Shutter
            if init_shutter:
                self.andor.SetShutter(1, 0, 30, 30)

            self._wl = self.shamrock.GetCalibration(self._width)

            # //Setup Image dimensions
            self.andor.SetImage(1, 1, 1, self._width, 1, self._height)

            # shamrock = ShamrockSDK()

            self.shamrock.SetNumberPixels(self._width)

            self.shamrock.SetPixelWidth(self._pixelwidth)

            # //Set initial exposure time
            self.andor.SetExposureTime(self.exp_time)

            self.HSSpeeds = self.andor.GetHSSpeedList()
            print("HSSpeeds available: "+str(self.HSSpeeds))
            # set HSSpeed to 100Mhz
            self.andor.SetHSSpeed(0)

            # set vertical Speed to fastest recommended
            index = self.andor.GetFastestRecommendedVSSpeed()
            self.andor.SetVSSpeed(index)


        else:
            raise RuntimeError("Could not initialize Spectrometer")
            sys.exit(0)

    def __del__(self):
        if not self.closed:
            self.andor.Shutdown()
            self.shamrock.Shutdown()
            # print("Begin AndorSpectrometer.__del__")
            # if not self.closed:
            #     try:
            #         andor.Shutdown()
            #     except (AttributeError, TypeError) as e:
            #         print(e)
            #     try:
            #         shamrock.Shutdown()
            #     except (AttributeError, TypeError) as e:
            #         print(e)
            # print("End AndorSpectrometer.__del__")

    def Shutdown(self):
        self.andor.Shutdown()
        self.shamrock.Shutdown()
        self.closed = True

    def SetTemperature(self, temp):
        self.andor.SetTemperature(temp)

    def GetTemperature(self):
        return self.andor.GetTemperature()

    def GetSlitWidth(self):
        return self.shamrock.GetAutoSlitWidth(1)

    def GetGratingInfo(self):
        num_gratings = self.shamrock.GetNumberGratings()
        gratings = {}
        for i in range(num_gratings):
            lines, blaze, home, offset = self.shamrock.GetGratingInfo(i + 1)
            gratings[i + 1] = lines
        return gratings

    def GetGrating(self):
        return self.shamrock.GetGrating()

    def SetGrating(self, grating):
        status = self.shamrock.SetGrating(grating)
        self._wl = self.shamrock.GetCalibration(self._width)
        return status

    def AbortAcquisition(self):
        self.andor.AbortAcquisition()

    def SetNumberAccumulations(self, number):
        self.andor.SetNumberAccumulations(number)

    def SetExposureTime(self, seconds):
        self.andor.SetExposureTime(seconds)
        self.exp_time = seconds

    def SetSlitWidth(self, slitwidth):
        self.shamrock.SetAutoSlitWidth(1, slitwidth)
        if self.mode is 'Image':
            self.andor.SetImage(1, 1, self.min_width, self.max_width, 1, self._height)
        else:
            self.CalcSingleTrackSlitPixels()
            self.andor.SetImage(1, 1, 1, self._width, self._hstart, self._hstop)

    def GetWavelength(self):
        return self._wl

    def SetFullImage(self):
        self.andor.SetImage(1, 1, 1, self._width, 1, self._height)
        self.mode = 'Image'

    def TakeFullImage(self):
        return self.TakeImage(self._width, self._height)

    def TakeImage(self, width, height):
        self.andor.StartAcquisition()
        acquiring = True
        while acquiring:
            status = self.andor.GetStatus()
            if status == 20073:
                acquiring = False
            elif not status == 20072:
                return None
        data = self.andor.GetAcquiredData(width, height)
        # return data.transpose()
        return data

    def SetCentreWavelength(self, wavelength):
        minwl, maxwl = self.shamrock.GetWavelengthLimits(self.shamrock.GetGrating())
        # if (wavelength < maxwl) and (wavelength > minwl):
        #     self.shamrock.SetWavelength(wavelength)
        #     self._wl = self.shamrock.GetCalibration(self._width)
        # else:
        #     pass
        self.shamrock.SetWavelength(wavelength)
        self._wl = self.shamrock.GetCalibration(self._width)
        if (wavelength > maxwl) or (wavelength < minwl):
            print("You set the centre wavelength outside the usable range, wavelengths will be invalid")

    def CalcImageofSlitDim(self):
        # Calculate which pixels in x direction are acutally illuminated (usually the slit will be much smaller than the ccd)
        visible_xpixels = (self._max_slit_width) / self._pixelwidth
        min_width = round(self._width / 2 - visible_xpixels / 2)
        max_width = self._width - min_width

        # This two values have to be adapted if to fit the image of the slit on your detector !
        min_width -= 25#45#25
        max_width -= -25#0#5

        if min_width < 1:
            min_width = 1
        if max_width > self._width:
            max_width = self._width

        return min_width, max_width


    def SetImageofSlit(self):
        self.shamrock.SetWavelength(0)

        min_width, max_width = self.CalcImageofSlitDim()
        self.min_width = min_width
        self.max_width = max_width

        self.andor.SetImage(1, 1, self.min_width, self.max_width, 1, self._height)
        self.mode = 'Image'

    def TakeImageofSlit(self):
        return self.TakeImage(self.max_width - self.min_width + 1, self._height)

    def SetSingleTrackMinimumVerticalPixels(self,pixels):
        self.single_track_minimum_vertical_pixels = pixels

    def CalcSingleTrackSlitPixels(self):
        slitwidth = self.shamrock.GetAutoSlitWidth(1)
        pixels = (slitwidth / self._pixelheight)
        if pixels < self.single_track_minimum_vertical_pixels:  #read out a minimum of 7 pixels, this is the smallest height that could be seen on the detector, smaller values will give wrong spectra due to chromatic abberation
            pixels = self.single_track_minimum_vertical_pixels
        middle = round(self._height / 2)
        self._hstart = round(middle - pixels / 2)
        self._hstop = round(middle + pixels / 2)+3
        print('Detector readout:'+ str(self._hstart)+' - '+str(self._hstop)+' pixels, middle at '+str(middle)+', throwing away '+str(self._hstop-3)+'-'+str(self._hstop) )
        # the -3 is a workaround as the detector tends to saturate the first two rows, so we take these but disregard them later

    def SetSingleTrack(self, hstart=None, hstop=None):
        if (hstart is None) or (hstop is None):
            self.CalcSingleTrackSlitPixels()
        else:
            self._hstart = hstart
            self._hstop = hstop
        self.andor.SetImage(1, 1, 1, self._width, self._hstart, self._hstop)
        self.mode = 'SingleTrack'

    def TakeSingleTrack(self):
        self.andor.StartAcquisition()
        acquiring = True
        while acquiring:
            status = self.andor.GetStatus()
            if status == 20073:
                acquiring = False
            elif not status == 20072:
                print(Andor.ERROR_CODE[status])
                return np.zeros((self._width,7))
        data = self.andor.GetAcquiredData(self._width, (self._hstop - self._hstart) + 1)
        #data = np.mean(data, 1)
        data = data[:, 3:]  # throw away 'bad rows', see CalcSingleTrackSlitPixels(self) for details
        print('Acquired Data: '+ str(data.shape))
        #return data[:, 3:]  # throw away 'bad rows', see CalcSingleTrackSlitPixels(self) for details
        return data
