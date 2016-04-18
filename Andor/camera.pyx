import sys
import time

from Andor.errorcodes import ERROR_CODE
cimport atmcdLXd as lib

import numpy as np
cimport numpy as np

from cpython cimport array
import array

class Camera:

    verbosity = 2
    _init_path = '/usr/local/etc/andor'
    _width = 0
    _height = 0

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

    def Initialize(self):
        self._Initialize()

        #//Set Read Mode to --Image--
        self._SetReadMode(4);

        #//Set Acquisition mode to --Single scan--
        self._SetAcquisitionMode(1);

        #//Set initial exposure time
        self._SetExposureTime(1);

        #//Get Detector dimensions
        self._width, self._height = self._GetDetector()
        print((self._width,self._height))

        #//Initialize Shutter
        self._SetShutter(1,0,50,50);

        #//Setup Image dimensions
        self._SetImage(1,1,1,self._width,1,self._height);

    def Shutdown(self):
        error = lib.ShutDown()
        #self.verbose(error, sys._getframe().f_code.co_name)

    def TakeImage(self):
        self._StartAcquisition()

        while self._GetStatus() is 20072:
            time.sleep(0.000001)

        data = self._GetAcquiredData(self._width,self._height)
        return data

    def _Initialize(self):
        dir_bytes = self._init_path.encode('UTF-8')
        cdef char* dir = dir_bytes
        error = lib.Initialize(dir)
        time.sleep(0.2)
        self.verbose(error, sys._getframe().f_code.co_name)

    def _GetDetector(self):
        cdef int width = 0
        cdef int* width_ptr = &width
        cdef int height = 0
        cdef int* height_ptr = &height
        error = lib.GetDetector(width_ptr,height_ptr)
        self.verbose(error, sys._getframe().f_code.co_name)
        return width, height

    def _SetAcquisitionMode(self, mode):
        cdef int m = mode
        error = lib.SetAcquisitionMode(m)
        self.verbose(error, sys._getframe().f_code.co_name)

    def _SetReadMode(self, mode):
        cdef int m = mode
        error = lib.SetReadMode(m)
        self.verbose(error, sys._getframe().f_code.co_name)

    def _SetExposureTime(self,seconds):
        cdef float s = seconds
        error = lib.SetExposureTime(s)
        self.verbose(error, sys._getframe().f_code.co_name)

    def _SetImage(self, hbin, vbin, hstart, hend, vstart, vend):
        cdef int hb = hbin
        cdef int vb = vbin
        cdef int hs = hstart
        cdef int he = hend
        cdef int vs = vstart
        cdef int ve = vend
        error = lib.SetImage(hb, vb, hs, he, vs, ve)
        self.verbose(error, sys._getframe().f_code.co_name)

    def _SetShutter(self, typ, mode, closingtime, openingtime):
        cdef int t = typ
        cdef int m = mode
        cdef int ct = closingtime
        cdef int ot = openingtime
        error = lib.SetShutter(t, m, ct, ot)
        self.verbose(error, sys._getframe().f_code.co_name)

    def _StartAcquisition(self):
        error = lib.StartAcquisition()
        self.verbose(error, sys._getframe().f_code.co_name)

    def _GetNumberDevices(self):
        cdef int num = -1
        cdef int* num_ptr = &num
        error = lib.GetNumberDevices(num_ptr)
        self.verbose(error, sys._getframe().f_code.co_name)
        print(num)

    def _GetStatus(self):
        cdef int status = 0
        cdef int* status_ptr = &status
        error = lib.GetStatus(status_ptr)
        self.verbose(error, sys._getframe().f_code.co_name)
        return status

    def _GetAcquiredData(self,width,height):
        cdef unsigned int size = width*height
        cdef array.array data = array.array('i', np.zeros(size,dtype=np.int))
        error = lib.GetAcquiredData(data.data.as_ints, size)
        return np.array(data).reshape((width,height))