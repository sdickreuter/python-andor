import sys

from Andor.errorcodes import ERROR_CODE
cimport atmcdLXd as lib

import numpy as np
cimport numpy as np

from cpython cimport array
import array
import time

verbosity = 2
_init_path = '/usr/local/etc/andor'

AcquistionModes = { 'Single Scan' : 1,
                    'Accumulate' : 2,
                    'Kinetics' : 3,
                    'Fast Kinetics' : 4,
                    'Run till abort' : 5}

def verbose(error, function=''):
    if verbosity > 0:
        if not error == 20002:
            print("[%s]: %s" % (function, ERROR_CODE[error]))
        elif verbosity > 1:
            print("[%s]: %s" % (function, ERROR_CODE[error]))

def Shutdown():
    lib.AbortAcquisition()
    SetTemperature(-20)
    if GetTemperature() <= -20:
        print("Detector warming up, please wait.")
        warm = False
        while not warm:
            time.sleep(1)
            if GetTemperature() > -20:
                warm = True
        print("Warmup finished.")

    CoolerOFF()
    error = lib.ShutDown()
    #verbose(error, sys._getframe().f_code.co_name)

def Initialize():
    dir_bytes = _init_path.encode('UTF-8')
    cdef char* dir = dir_bytes
    error = lib.Initialize(dir)
    time.sleep(2)
    verbose(error, "Initialize")
    if error is 20002:
        return 1
    else:
        return 0

def AbortAcquisition():
    error = lib.AbortAcquisition()
    verbose(error, "AbortAcquisition")

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

def SetExposureTime(float seconds):
    error = lib.SetExposureTime(seconds)
    verbose(error, "SetExposureTime")
    print(error)
    print(GetAcquisitionTimings())

def GetAcquisitionTimings():
    cdef float exposure = 0
    cdef float* exposure_ptr = &exposure
    cdef float accumulate = 0
    cdef float* accumulate_ptr = &accumulate
    cdef float kinetic = 0
    cdef float* kinetic_ptr = &kinetic
    error = lib.GetAcquisitionTimings(exposure_ptr, accumulate_ptr, kinetic_ptr)
    verbose(error, "GetAcquisitionTimings")
    return exposure

def SetImage(int hbin,int vbin,int hstart,int hend,int vstart,int vend):
    error = lib.SetImage(hbin, vbin, hstart, hend, vstart, vend)
    verbose(error, "SetImage")

def SetShutter(int typ,int mode,int closingtime,int openingtime):
    error = lib.SetShutter(typ, mode, closingtime, openingtime)
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
    return num

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
    if (error != 20035) and (error != 20037):
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

def SetNumberAccumulations(number):
    cdef int n = number
    error = lib.SetNumberAccumulations(n)
    verbose(error, "SetNumberAccumulations")