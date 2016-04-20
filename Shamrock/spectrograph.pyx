import sys

from Shamrock.errorcodes import ERROR_CODE
cimport ShamrockCIF as lib

import numpy as np
cimport numpy as np


from cpython cimport array
import array

class Spectrograph:

    verbosity = 2
    init_path = '/usr/local/etc/andor'
    camera = None
    device = 0

    def __init__(self, camera):
        self.cam = camera
        print("spectrograph")
        if self.cam is None:
            RuntimeError("No Camera, aborting")

    def __del__(self):
        lib.ShamrockClose()

    def verbose(self, error, function=''):
        if self.verbosity > 0:
            if not error is 20002:
                print("[%s]: %s" % (function, ERROR_CODE[error]))
            elif self.verbosity > 1:
                print("[%s]: %s" % (function, ERROR_CODE[error]))

    def _Initialize(self):
        dir_bytes = self.init_path.encode('UTF-8')
        cdef char* dir = dir_bytes
        error = lib.ShamrockInitialize(dir)
        self.verbose(error, "_Initialize")

    def _GetNumberDevices(self):
        cdef int num = -1
        cdef int* num_ptr = &num
        error = lib.ShamrockGetNumberDevices(num_ptr)
        self.verbose(error, "_GetNumberDevices")
        print(num)

    def _SetPixelWidth(self,width):
        cdef float w = width
        error = lib.ShamrockSetPixelWidth(self.device, w)
        self.verbose(error, "_SetPixelWidth")

    def _SetNumberPixels(self,pixelnumber):
        cdef int n = pixelnumber
        error = lib.ShamrockSetNumberPixels(self.device, n)
        self.verbose(error, "_SetNumberPixels")

    def _SetGrating(self, grating):
        cdef int g = grating
        error = lib.ShamrockSetGrating(self.device, g)
        self.verbose(error, "_SetGrating")

    def _GetGrating(self):
        cdef int grating = 0
        cdef int* grating_ptr = &grating
        error = lib.ShamrockGetGrating(self.device, grating_ptr)
        self.verbose(error, "_GetGrating")
        return grating

    def _GetNumberGratings(self):
        cdef int n = 0
        cdef int* n_ptr = &n
        error = lib.ShamrockGetNumberGratings(self.device, n_ptr)
        self.verbose(error, "_GetNumberGratings")
        return n

    def _GetGratingInfo(self, grating):
        #unsigned int ShamrockGetGratingInfo(int device,int Grating, float *Lines,  char* Blaze, int *Home, int *Offset)
        cdef int g = grating
        cdef float lines = 0
        cdef float* lines_ptr = &lines
        blaze_bytes = '     '.encode('UTF-8') # 5 chars long !
        cdef char* blaze = blaze_bytes
        cdef int home = 0
        cdef int* home_ptr = &home
        cdef int offset = 0
        cdef int* offset_ptr = &offset
        error = lib.ShamrockGetGratingInfo(self.device, g, lines_ptr, blaze, home_ptr, offset_ptr)
        self.verbose(error, "_GetNumberGratings")
        return lines, blaze, home, offset

    def _SetWavelength(self, wavelength):
        cdef float wl = wavelength
        error = lib.ShamrockSetWavelength(self.device, wl)
        self.verbose(error, "_SetWavelength")

    def _GetWavelength(self):
        cdef float wl = 0
        cdef float* wl_ptr = &wl
        error = lib.ShamrockGetWavelength(self.device, wl_ptr)
        self.verbose(error, "_GetWavelength")
        return wl

    def _GetWavelengthLimits(self, grating):
        cdef int g = grating
        cdef float min = 0
        cdef float* min_ptr = &min
        cdef float max = 0
        cdef float* max_ptr = &max
        error = lib.ShamrockGetWavelengthLimits(self.device, g, min_ptr, max_ptr)
        self.verbose(error, "_GetWavelength")
        return min, max

    def _GetCalibration(self, numberpixels):
        cdef int n = numberpixels
        #cdef array.array values = array.array('f', np.zeros(numberpixels,dtype=np.float))
        #cdef float  waves[n]
        #cdef np.ndarray[float, ndim=1, mode="c"] waves_numpy = np.empty(numberpixels,dtype=np.float32)
        #cdef float *waves = &waves_numpy[0]
        #error = lib.ShamrockGetCalibration(self.device, waves, n)
        #waves_numpy = np.array(waves)
        cdef np.float32[:] waves = np.zeros(numberpixels, dtype=np.float32)
        waves = input.view(np.float32)
        error = lib.ShamrockGetCalibration(self.device, <float *>&waves, n)
        #print(waves_numpy[0])
        self.verbose(error, "_GetCalibration")
        return waves

    def _SetFlipperMirrorPosition(self, flipper, position):
        cdef int f = flipper
        cdef int pos = position
        error = lib.ShamrockSetFlipperMirrorPosition(self.device, f, pos)
        self.verbose(error, "_SetFlipperMirrorPosition")

    def _GetFlipperMirrorPosition(self, flipper):
        cdef int f = flipper
        cdef int pos = 0
        cdef int* pos_ptr = &pos
        error = lib.ShamrockGetFlipperMirrorPosition(self.device, f, pos_ptr)
        self.verbose(error, "_GetFlipperMirrorPosition")
        return pos

    def _SetAutoSlitWidth(self, index, width):
        cdef int i = index
        cdef float w = width
        error = lib.ShamrockSetAutoSlitWidth(self.device, i, w)
        self.verbose(error, "_SetAutoSlitWidth")

    def _GetAutoSlitWidth(self, index):
        cdef int i = index
        cdef float w = 0
        cdef float* w_ptr = &w
        error = lib.ShamrockSetAutoSlitWidth(self.device, i, w)
        self.verbose(error, "_GetAutoSlitWidth")
        return w


