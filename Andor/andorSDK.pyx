import sys
import time

from Andor.errorcodes import ERROR_CODE
cimport atmcdLXd as lib

import numpy as np
cimport numpy as np

from cpython cimport array
import array

#class AndorSDK:

verbosity = 2
_init_path = '/usr/local/etc/andor'

    #def __init__():
    #    print("camera")

def verbose(error, function=''):
    if verbosity > 0:
        if not error is 20002:
            print("[%s]: %s" % (function, ERROR_CODE[error]))
        elif verbosity > 1:
            print("[%s]: %s" % (function, ERROR_CODE[error]))

    #def __del__():
    #    Shutdown()

def Shutdown():
    CoolerOFF()

    warm = False
    while not warm:
        if GetTemperature() > -20:
            warm = True
        time.sleep(0.1)

    error = lib.ShutDown()
    #verbose(error, sys._getframe().f_code.co_name)

def Initialize():
    dir_bytes = _init_path.encode('UTF-8')
    cdef char* dir = dir_bytes
    error = lib.Initialize(dir)
    time.sleep(0.2)
    verbose(error, "Initialize")
    if error is 20002:
        return 1
    else:
        return 0

def AbortAcquisition():
    error = lib.AbortAcquisition()
    verbose(error, "GetDetector")

def GetDetector():
    cdef int width = 0
    cdef int* width_ptr = &width
    cdef int height = 0
    cdef int* height_ptr = &height
    error = lib.GetDetector(width_ptr,height_ptr)
    verbose(error, "GetDetector")
    return width, height

def SetAcquisitionMode(mode):
    cdef int m = mode
    error = lib.SetAcquisitionMode(m)
    verbose(error, "SetAcquisitionMode")

def SetReadMode(mode):
    cdef int m = mode
    error = lib.SetReadMode(m)
    verbose(error, "SetReadMode")

def SetExposureTime(seconds):
    seconds = float(seconds)
    cdef float s = seconds
    error = lib.SetExposureTime(s)
    verbose(error, "SetExposureTime")

def SetImage(hbin, vbin, hstart, hend, vstart, vend):
    cdef int hb = hbin
    cdef int vb = vbin
    cdef int hs = hstart
    cdef int he = hend
    cdef int vs = vstart
    cdef int ve = vend
    error = lib.SetImage(hb, vb, hs, he, vs, ve)
    verbose(error, "SetImage")

def SetShutter(typ, mode, closingtime, openingtime):
    cdef int t = typ
    cdef int m = mode
    cdef int ct = closingtime
    cdef int ot = openingtime
    error = lib.SetShutter(t, m, ct, ot)
    verbose(error, "SetShutter")

def StartAcquisition():
    #status = GetStatus()
    #if status == 20073: # 20073: 'DRV_IDLE'
    #    error = lib.StartAcquisition()
    #    verbose(error, "StartAcquisition")
    #else:
    #    print("[StartAcquisition]: not idle !")
    #    verbose(20992, "StartAcquisition")
    error = lib.StartAcquisition()
    verbose(error, "StartAcquisition")


def GetNumberDevices():
    cdef int num = -1
    cdef int* num_ptr = &num
    error = lib.GetNumberDevices(num_ptr)
    verbose(error, "GetNumberDevices")
    print(num)

def GetStatus():
    cdef int status = 0
    cdef int* status_ptr = &status
    error = lib.GetStatus(status_ptr)
    #verbose(error, "_GetStatus")
    return status

def GetAcquiredData(width, height):
    cdef unsigned int size = width*height
    cdef array.array data = array.array('i', np.zeros(size,dtype=np.int))
    error = lib.GetAcquiredData(data.data.as_ints, size)
    verbose(error, "GetAcquiredData")
    return np.array(data).reshape((height,width)).transpose()

def GetPixelSize():
    cdef float xSize = 0
    cdef float* xSize_ptr = &xSize
    cdef float ySize = 0
    cdef float* ySize_ptr = &ySize
    error = lib.GetPixelSize(xSize_ptr, ySize_ptr)
    verbose(error, "GetPixelSize")
    return xSize, ySize

def GetTECStatus():
    cdef int flag = 0
    cdef int* flag_ptr = &flag
    error = lib.GetTECStatus(flag_ptr)
    if (flag):
        print("ERROR: TEC has overheated !")
    verbose(error, "GetTECStatus")


def GetTemperature():
    cdef int temp = 0
    cdef int* temp_ptr = &temp
    error = lib.GetTemperature(temp_ptr)
    verbose(error, "GetTemperature")
    return temp

def GetTemperatureRange():
    cdef int min_temp = 0
    cdef int* min_temp_ptr = &min_temp
    cdef int max_temp = 0
    cdef int* max_temp_ptr = &max_temp
    error = lib.GetTemperatureRange(min_temp_ptr, max_temp_ptr)
    verbose(error, "GetTemperatureRange")
    return min_temp, max_temp

def SetTemperature(temperature):
    cdef int temp = temperature
    error = lib.SetTemperature(temp)
    verbose(error, "SetTemperatur")

def CoolerON():
    error = lib.CoolerON()
    verbose(error, "CoolerON")

def CoolerOFF():
    error = lib.CoolerOFF()
    verbose(error, "CoolerOFF")

