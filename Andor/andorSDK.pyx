import sys

from Andor.errorcodes import ERROR_CODE
cimport atmcdLXd as lib

import numpy as np
cimport numpy as np

from cpython cimport array
import array
import time

class Andor:

    verbosity = 2
    _init_path = '/usr/local/etc/andor'

    AcquistionModes = { 'Single Scan' : 1,
                        'Accumulate' : 2,
                        'Kinetics' : 3,
                        'Fast Kinetics' : 4,
                        'Run till abort' : 5}

    def __init__(self, verbosity=2):
        self.verbosity = verbosity


    def verbose(self, error, function=''):
        if self.verbosity > 0:
            if not error == 20002:
                print("[%s]: %s" % (function, ERROR_CODE[error]))
            elif self.verbosity > 1:
                print("[%s]: %s" % (function, ERROR_CODE[error]))

    def Shutdown(self):
        lib.AbortAcquisition()
        self.SetTemperature(-10)
        if self.GetTemperature() <= -10:
            print("Detector warming up, please wait.")
            sys.stdout.flush()
            warm = False
            while not warm:
                time.sleep(1)
                temp = self.GetTemperature()
                print("Detector at "+str(temp)+" °C")
                sys.stdout.flush()
                if temp > -10:
                    warm = True
            print("Warmup finished.")
            sys.stdout.flush()


        self.CoolerOFF()
        error = lib.ShutDown()
        #verbose(error, sys._getframe().f_code.co_name)

    def Initialize(self):
        dir_bytes = self._init_path.encode('UTF-8')
        cdef char* dir = dir_bytes
        error = lib.Initialize(dir)
        time.sleep(2)
        self.verbose(error, "Initialize")
        if error is 20002:
            return 1
        else:
            return 0

    def AbortAcquisition(self):
        error = lib.AbortAcquisition()
        self.verbose(error, "AbortAcquisition")

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

    def SetExposureTime(self, float seconds):
        error = lib.SetExposureTime(seconds)
        self.verbose(error, "SetExposureTime")
        #print(error)
        #print(self.GetAcquisitionTimings())

    def GetAcquisitionTimings(self):
        cdef float exposure = 0
        cdef float* exposure_ptr = &exposure
        cdef float accumulate = 0
        cdef float* accumulate_ptr = &accumulate
        cdef float kinetic = 0
        cdef float* kinetic_ptr = &kinetic
        error = lib.GetAcquisitionTimings(exposure_ptr, accumulate_ptr, kinetic_ptr)
        self.verbose(error, "GetAcquisitionTimings")
        return exposure, accumulate, kinetic

    def SetImage(self, int hbin,int vbin,int hstart,int hend,int vstart,int vend):
        error = lib.SetImage(hbin, vbin, hstart, hend, vstart, vend)
        self.verbose(error, "SetImage")

    def SetShutter(self, int typ,int mode,int closingtime,int openingtime):
        error = lib.SetShutter(typ, mode, closingtime, openingtime)
        self.verbose(error, "SetShutter")


    def SetHSSpeed(self,int index):
        cdef int typ = 0
        #unsigned int WINAPI SetHSSpeed(int typ, int index)
        error = lib.SetHSSpeed(typ, index)
        self.verbose(error, "SetHSSpeed")

    def SetVSSpeed(self, int index):
        #unsigned int WINAPI SetVSSpeed(int index)
        error = lib.SetVSSpeed(index)
        self.verbose(error, "SetVSSpeed")

    def StartAcquisition(self):
        #status = GetStatus()
        #if status == 20073: # 20073: 'DRV_IDLE'
        #    error = lib.StartAcquisition()
        #    verbose(error, "StartAcquisition")
        #else:
        #    print("[StartAcquisition]: not idle !")
        #    verbose(20992, "StartAcquisition")
        error = lib.StartAcquisition()
        self.verbose(error, "StartAcquisition")


    def GetNumberDevices(self):
        cdef int num = -1
        cdef int* num_ptr = &num
        error = lib.GetNumberDevices(num_ptr)
        self.verbose(error, "GetNumberDevices")
        return num

    def GetNumberHSSpeeds(self):
        cdef int channel = 0
        cdef int typ = 0
        cdef int speeds = -1
        cdef int* speeds_ptr = &speeds
        #unsigned int WINAPI GetNumberHSSpeeds(int channel, int typ, int* speeds)
        error = lib.GetNumberHSSpeeds(channel, typ,speeds_ptr)
        self.verbose(error, "GetNumberHSSpeeds")
        return speeds


    def GetHSSpeed(self, int index):
        cdef int channel = 0
        cdef int typ = 0
        cdef float speed = -1
        cdef float* speed_ptr = &speed
        #unsigned int WINAPI GetHSSpeed(int channel, int typ, int index, float* speed)
        error = lib.GetHSSpeed(channel, typ, index,speed_ptr)
        self.verbose(error, "GetHSSpeed")
        return speed

    def GetHSSpeedList(self):
        n = self.GetNumberHSSpeeds()
        speeds = []
        for i in range(n):
            speeds.append(self.GetHSSpeed(i))
        return speeds

    def GetFastestRecommendedVSSpeed(self):
        cdef int index = -1
        cdef int* index_ptr = &index
        cdef float speed = 0
        cdef float* speed_ptr = &speed
        #unsigned int WINAPI GetFastestRecommendedVSSpeed (int* index, float* speed)
        error = lib.GetFastestRecommendedVSSpeed(index_ptr, speed_ptr)
        self.verbose(error, "GetNumberHSSpeeds")
        print("Fastest recommended vertical shift speed: "+str(speed)+" usec")
        return index


    def GetStatus(self):
        cdef int status = 0
        cdef int* status_ptr = &status
        error = lib.GetStatus(status_ptr)
        #verbose(error, "_GetStatus")
        return status

    def GetAcquiredData(self, width, height):
        cdef unsigned int size = width*height
        cdef array.array data = array.array('i', [0] * size)
        error = lib.GetAcquiredData(data.data.as_ints, size)
        self.verbose(error, "GetAcquiredData")
        return np.array(data,dtype=np.int32).reshape((height,width)).transpose()
        #return np.array(data).reshape((height,width)).transpose()
        #return data

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
        if (error != 20035) and (error != 20037) and (error != 20036):
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

    def SetTemperature(self, temperature):
        cdef int temp = temperature
        error = lib.SetTemperature(temp)
        self.verbose(error, "SetTemperatur")

    def CoolerON(self):
        error = lib.CoolerON()
        self.verbose(error, "CoolerON")

    def CoolerOFF(self):
        error = lib.CoolerOFF()
        self.verbose(error, "CoolerOFF")

    def SetNumberAccumulations(self, number):
        cdef int n = number
        error = lib.SetNumberAccumulations(n)
        self.verbose(error, "SetNumberAccumulations")