import sys
import time

from Andor.errorcodes import ERROR_CODE
cimport atmcdLXd as lib

import numpy as np
cimport numpy as np

from cpython cimport array
import array

class AndorSDK:

    verbosity = 2
    _init_path = '/usr/local/etc/andor'

    def __init__(self):
        print("camera")

    def verbose(self, error, function=''):
        if self.verbosity > 0:
            if not error is 20002:
                print("[%s]: %s" % (function, ERROR_CODE[error]))
            elif self.verbosity > 1:
                print("[%s]: %s" % (function, ERROR_CODE[error]))

    def __del__(self):
        self.Shutdown()

    def Shutdown(self):
        self.CoolerOFF()

        warm = False
        while not warm:
            if self.GetTemperature() > -20:
                warm = True
            time.sleep(0.1)

        error = lib.ShutDown()
        #self.verbose(error, sys._getframe().f_code.co_name)

    def Initialize(self):
        dir_bytes = self._init_path.encode('UTF-8')
        cdef char* dir = dir_bytes
        error = lib.Initialize(dir)
        time.sleep(0.2)
        self.verbose(error, "Initialize")

    def GetDetector(self):
        cdef int width = 0
        cdef int* width_ptr = &width
        cdef int height = 0
        cdef int* height_ptr = &height
        error = lib.GetDetector(width_ptr,height_ptr)
        self.verbose(error, "GetDetector")
        return width, height

    def SetAcquisitionMode(self, mode):
        cdef int m = mode
        error = lib.SetAcquisitionMode(m)
        self.verbose(error, "SetAcquisitionMode")

    def SetReadMode(self, mode):
        cdef int m = mode
        error = lib.SetReadMode(m)
        self.verbose(error, "SetReadMode")

    def SetExposureTime(self, seconds):
        seconds = float(seconds)
        cdef float s = seconds
        error = lib.SetExposureTime(s)
        self.verbose(error, "SetExposureTime")

    def SetImage(self, hbin, vbin, hstart, hend, vstart, vend):
        cdef int hb = hbin
        cdef int vb = vbin
        cdef int hs = hstart
        cdef int he = hend
        cdef int vs = vstart
        cdef int ve = vend
        error = lib.SetImage(hb, vb, hs, he, vs, ve)
        self.verbose(error, "SetImage")

    def SetShutter(self, typ, mode, closingtime, openingtime):
        cdef int t = typ
        cdef int m = mode
        cdef int ct = closingtime
        cdef int ot = openingtime
        error = lib.SetShutter(t, m, ct, ot)
        self.verbose(error, "SetShutter")

    def StartAcquisition(self):
        status = self.GetStatus()
        if status is 20073: # 20073: 'DRV_IDLE'
            error = lib.StartAcquisition()
            self.verbose(error, "StartAcquisition")
        else:
            self.verbose(20992, "StartAcquisition")

    def GetNumberDevices(self):
        cdef int num = -1
        cdef int* num_ptr = &num
        error = lib.GetNumberDevices(num_ptr)
        self.verbose(error, "GetNumberDevices")
        print(num)

    def GetStatus(self):
        cdef int status = 0
        cdef int* status_ptr = &status
        error = lib.GetStatus(status_ptr)
        #self.verbose(error, "_GetStatus")
        return status

    def GetAcquiredData(self, width, height):
        cdef unsigned int size = width*height
        cdef array.array data = array.array('i', np.zeros(size,dtype=np.int))
        error = lib.GetAcquiredData(data.data.as_ints, size)
        self.verbose(error, "GetAcquiredData")
        return np.array(data).reshape((width,height))

    def GetPixelSize(self):
        cdef float xSize = 0
        cdef float* xSize_ptr = &xSize
        cdef float ySize = 0
        cdef float* ySize_ptr = &ySize
        error = lib.GetPixelSize(xSize_ptr, ySize_ptr)
        self.verbose(error, "GetPixelSize")
        return xSize, ySize

    def GetTECStatus(self):
        cdef int flag = 0
        cdef int* flag_ptr = &flag
        error = lib.GetTECStatus(flag_ptr)
        if (flag):
            print("ERROR: TEC has overheated !")
        self.verbose(error, "GetTECStatus")


    def GetTemperature(self):
        cdef int temp = 0
        cdef int* temp_ptr = &temp
        error = lib.GetTemperature(temp_ptr)
        self.verbose(error, "GetTemperature")
        return temp


    def GetTemperatureRange(self):
        cdef int min_temp = 0
        cdef int* min_temp_ptr = &min_temp
        cdef int max_temp = 0
        cdef int* max_temp_ptr = &max_temp
        error = lib.GetTemperatureRange(min_temp_ptr, max_temp_ptr)
        self.verbose(error, "GetTemperatureRange")
        return min_temp, max_temp

    def SetTemperatur(self, temperature):
        cdef int temp = temperature
        error = lib.SetTemperatur(temp)
        self.verbose(error, "SetTemperatur")

    def CoolerON(self):
        error = lib.CoolerON()
        self.verbose(error, "CoolerON")

    def CoolerOFF(self):
        error = lib.CoolerOFF()
        self.verbose(error, "CoolerON")

