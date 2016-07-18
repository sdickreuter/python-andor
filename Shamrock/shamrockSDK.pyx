import sys

from Shamrock.errorcodes import ERROR_CODE
cimport ShamrockCIF as lib

import numpy as np
cimport numpy as np

from cpython cimport array
import array


class Shamrock:

    verbosity = 2
    init_path = '/usr/local/etc/andor'
    device = 0

    def __init__(self, verbosity=2):
        self.verbosity = verbosity


    def verbose(self, error, function=''):
        if self.verbosity > 0:
            if not error == 20202:
                print("[%s]: %s" % (function, ERROR_CODE[error]))
            elif self.verbosity > 1:
                print("[%s]: %s" % (function, ERROR_CODE[error]))

    def Initialize(self):
        dir_bytes = self.init_path.encode('UTF-8')
        cdef char* dir = dir_bytes
        error = lib.ShamrockInitialize(dir)
        self.verbose(error, "Initialize")
        if error is 20202:
            return 1
        else:
            return 0

    def Shutdown(self):
        lib.ShamrockClose()

    def GetNumberDevices(self):
        cdef int num = -1
        cdef int* num_ptr = &num
        error = lib.ShamrockGetNumberDevices(num_ptr)
        self.verbose(error, "GetNumberDevices")
        print(num)

    def SetPixelWidth(self, width):
        cdef float w = width
        error = lib.ShamrockSetPixelWidth(self.device, w)
        self.verbose(error, "SetPixelWidth")

    def SetNumberPixels(self, pixelnumber):
        cdef int n = pixelnumber
        error = lib.ShamrockSetNumberPixels(self.device, n)
        self.verbose(error, "SetNumberPixels")

    def SetGrating(self, grating):
        cdef int g = grating
        error = lib.ShamrockSetGrating(self.device, g)
        self.verbose(error, "SetGrating")

    def GetGrating(self):
        cdef int grating = 0
        cdef int* grating_ptr = &grating
        error = lib.ShamrockGetGrating(self.device, grating_ptr)
        self.verbose(error, "GetGrating")
        return grating

    def GetNumberGratings(self):
        cdef int n = 0
        cdef int* n_ptr = &n
        error = lib.ShamrockGetNumberGratings(self.device, n_ptr)
        self.verbose(error, "GetNumberGratings")
        return n

    def GetGratingInfo(self, int grating):
        #unsigned int ShamrockGetGratingInfo(int device,int Grating, float *Lines,  char* Blaze, int *Home, int *Offset)
        cdef float lines = 0
        cdef float* lines_ptr = &lines
        blaze_bytes = '     '.encode('UTF-8') # 5 chars long !
        cdef char* blaze = blaze_bytes
        cdef int home = 0
        cdef int* home_ptr = &home
        cdef int offset = 0
        cdef int* offset_ptr = &offset
        error = lib.ShamrockGetGratingInfo(self.device, grating, lines_ptr, blaze, home_ptr, offset_ptr)
        self.verbose(error, "GetGratingInfo")
        return lines, blaze, home, offset

    def SetWavelength(self, float wavelength):
        error = lib.ShamrockSetWavelength(self.device, wavelength)
        self.verbose(error, "SetWavelength")

    def GetWavelength(self):
        cdef float wl = 0
        cdef float* wl_ptr = &wl
        error = lib.ShamrockGetWavelength(self.device, wl_ptr)
        self.verbose(error, "GetWavelength")
        return wl

    def GetWavelengthLimits(self, grating):
        cdef int g = grating
        cdef float min = 0
        cdef float* min_ptr = &min
        cdef float max = 0
        cdef float* max_ptr = &max
        error = lib.ShamrockGetWavelengthLimits(self.device, g, min_ptr, max_ptr)
        self.verbose(error, "GetWavelengthLimits")
        return min, max

    def GetCalibration(self, int numberpixels):
        #cdef array.array values = array.array('f', np.zeros(numberpixels,dtype=np.float))
        #cdef float  waves[n]
        #cdef np.ndarray[float, ndim=1, mode="c"] waves_numpy = np.empty(numberpixels,dtype=np.float32)
        #cdef float *waves = &waves_numpy[0]
        #error = lib.ShamrockGetCalibration(device, waves, n)
        #waves_numpy = np.array(waves)
        #cdef float[:] waves = np.zeros(numberpixels, dtype=np.float32)
        #error = lib.ShamrockGetCalibration(device, <float *>&waves, n)
        cdef array.array waves = array.array('f', np.zeros(numberpixels,dtype=np.float32))
        error = lib.ShamrockGetCalibration(self.device, waves.data.as_floats, numberpixels)

        #print(waves_numpy[0])
        self.verbose(error, "GetCalibration")
        return np.array(waves)

    def SetFlipperMirrorPosition(self, int flipper, int position):
        error = lib.ShamrockSetFlipperMirrorPosition(self.device, flipper, position)
        self.verbose(error, "SetFlipperMirrorPosition")

    def GetFlipperMirrorPosition(self, int flipper):
        cdef int pos = 0
        cdef int* pos_ptr = &pos
        error = lib.ShamrockGetFlipperMirrorPosition(self.device, flipper, pos_ptr)
        self.verbose(error, "GetFlipperMirrorPosition")
        return pos

    def SetAutoSlitWidth(self, int index, float width): # width in um !
        error = lib.ShamrockSetAutoSlitWidth(self.device, index, width)
        self.verbose(error, "SetAutoSlitWidth")

    def GetAutoSlitWidth(self, int index):
        cdef float w = 0
        cdef float* w_ptr = &w
        error = lib.ShamrockGetAutoSlitWidth(self.device, index, w_ptr)
        self.verbose(error, "GetAutoSlitWidth")
        return w # w in um !


