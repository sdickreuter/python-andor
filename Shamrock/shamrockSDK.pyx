import sys

from Shamrock.errorcodes import ERROR_CODE
cimport ShamrockCIF as lib

import numpy as np
cimport numpy as np

from cpython cimport array
import array

verbosity = 2
init_path = '/usr/local/etc/andor'
device = 0

def verbose(error, function=''):
    if verbosity > 0:
        if not error is 20202:
            print("[%s]: %s" % (function, ERROR_CODE[error]))
        elif verbosity > 1:
            print("[%s]: %s" % (function, ERROR_CODE[error]))

def Initialize():
    dir_bytes = init_path.encode('UTF-8')
    cdef char* dir = dir_bytes
    error = lib.ShamrockInitialize(dir)
    verbose(error, "_Initialize")
    if error is 20202:
        return 1
    else:
        return 0
    
def Shutdown():
    lib.ShamrockClose()

def GetNumberDevices():
    cdef int num = -1
    cdef int* num_ptr = &num
    error = lib.ShamrockGetNumberDevices(num_ptr)
    verbose(error, "_GetNumberDevices")
    print(num)

def SetPixelWidth(width):
    cdef float w = width
    error = lib.ShamrockSetPixelWidth(device, w)
    verbose(error, "_SetPixelWidth")

def SetNumberPixels(pixelnumber):
    cdef int n = pixelnumber
    error = lib.ShamrockSetNumberPixels(device, n)
    verbose(error, "_SetNumberPixels")

def SetGrating(grating):
    cdef int g = grating
    error = lib.ShamrockSetGrating(device, g)
    verbose(error, "_SetGrating")

def GetGrating():
    cdef int grating = 0
    cdef int* grating_ptr = &grating
    error = lib.ShamrockGetGrating(device, grating_ptr)
    verbose(error, "_GetGrating")
    return grating

def GetNumberGratings():
    cdef int n = 0
    cdef int* n_ptr = &n
    error = lib.ShamrockGetNumberGratings(device, n_ptr)
    verbose(error, "_GetNumberGratings")
    return n

def GetGratingInfo(grating):
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
    error = lib.ShamrockGetGratingInfo(device, g, lines_ptr, blaze, home_ptr, offset_ptr)
    verbose(error, "_GetNumberGratings")
    return lines, blaze, home, offset

def SetWavelength(wavelength):
    cdef float wl = wavelength
    error = lib.ShamrockSetWavelength(device, wl)
    verbose(error, "_SetWavelength")

def GetWavelength():
    cdef float wl = 0
    cdef float* wl_ptr = &wl
    error = lib.ShamrockGetWavelength(device, wl_ptr)
    verbose(error, "_GetWavelength")
    return wl

def GetWavelengthLimits(grating):
    cdef int g = grating
    cdef float min = 0
    cdef float* min_ptr = &min
    cdef float max = 0
    cdef float* max_ptr = &max
    error = lib.ShamrockGetWavelengthLimits(device, g, min_ptr, max_ptr)
    verbose(error, "_GetWavelength")
    return min, max

def GetCalibration(numberpixels):
    cdef int n = numberpixels
    #cdef array.array values = array.array('f', np.zeros(numberpixels,dtype=np.float))
    #cdef float  waves[n]
    #cdef np.ndarray[float, ndim=1, mode="c"] waves_numpy = np.empty(numberpixels,dtype=np.float32)
    #cdef float *waves = &waves_numpy[0]
    #error = lib.ShamrockGetCalibration(device, waves, n)
    #waves_numpy = np.array(waves)
    #cdef float[:] waves = np.zeros(numberpixels, dtype=np.float32)
    #error = lib.ShamrockGetCalibration(device, <float *>&waves, n)
    cdef array.array waves = array.array('f', np.zeros(numberpixels,dtype=np.float32))
    error = lib.ShamrockGetCalibration(device, waves.data.as_floats, numberpixels)

    #print(waves_numpy[0])
    verbose(error, "_GetCalibration")
    return np.array(waves)

def SetFlipperMirrorPosition(flipper, position):
    cdef int f = flipper
    cdef int pos = position
    error = lib.ShamrockSetFlipperMirrorPosition(device, f, pos)
    verbose(error, "_SetFlipperMirrorPosition")

def GetFlipperMirrorPosition(flipper):
    cdef int f = flipper
    cdef int pos = 0
    cdef int* pos_ptr = &pos
    error = lib.ShamrockGetFlipperMirrorPosition(device, f, pos_ptr)
    verbose(error, "_GetFlipperMirrorPosition")
    return pos

def SetAutoSlitWidth(index, width): # width in um !
    cdef int i = index
    cdef float w = width
    error = lib.ShamrockSetAutoSlitWidth(device, i, w)
    verbose(error, "_SetAutoSlitWidth")

def GetAutoSlitWidth(index):
    cdef int i = index
    cdef float w = 0
    cdef float* w_ptr = &w
    error = lib.ShamrockGetAutoSlitWidth(device, i, w_ptr)
    verbose(error, "_GetAutoSlitWidth")
    return w # w in um !


