import sys
import time

from Andor.errorcodes import ERROR_CODE
cimport atmcdLXd as lib

class Camera:

    verbosity = 2
    init_path = '/usr/local/etc/andor'


    def __init__(self):
        print("camera")

    def verbose(self, error, function=''):
        if self.verbosity > 0:
            if not error is 20002:
                print("[%s]: %s" % (function, ERROR_CODE[error]))
            elif self.verbosity > 1:
                print("[%s]: %s" % (function, ERROR_CODE[error]))

    def Initialize(self):
        dir_bytes = self.init_path.encode('UTF-8')
        cdef char* dir = dir_bytes
        error = lib.Initialize(dir)
        time.sleep(0.2)
        self.verbose(error, sys._getframe().f_code.co_name)

    def GetDetector(self):
        cdef int width = 0
        cdef int* width_ptr = &width
        cdef int height = 0
        cdef int* height_ptr = &height
        error = lib.GetDetector(width_ptr,height_ptr)
        self.verbose(error, sys._getframe().f_code.co_name)
        return width, height

    def SetAcquisitionMode(self, mode):
        error = lib.SetAcquisitionMode(mode)
        self.verbose(error, sys._getframe().f_code.co_name)

    def SetReadMode(self, mode):
        error = lib.SetReadMode(mode)
        self.verbose(error, sys._getframe().f_code.co_name)

    def SetExposureTime(self,seconds):
        error = lib.SetExposureTime(seconds)
        self.verbose(error, sys._getframe().f_code.co_name)

    def SetShutter(self, typ, mode, closingtime, openingtime):
        error = lib.SetShutter(typ, mode, closingtime, openingtime)
        self.verbose(error, sys._getframe().f_code.co_name)


    def GetNumberDevices(self):
        cdef int num = -1
        cdef int* num_ptr = &num
        error = lib.GetNumberDevices(num_ptr)
        self.verbose(error, sys._getframe().f_code.co_name)
        print(num)

