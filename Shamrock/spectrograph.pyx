import sys

from Shamrock.errorcodes import ERROR_CODE
cimport ShamrockCIF as lib

class Spectrograph:

    verbosity = 2
    init_path = '/usr/local/etc/andor'

    def __init__(self):
        print("spectrograph")

    def verbose(self, error, function=''):
        if self.verbosity > 0:
            if not error is 20002:
                print("[%s]: %s" % (function, ERROR_CODE[error]))
            elif self.verbosity > 1:
                print("[%s]: %s" % (function, ERROR_CODE[error]))

    def Initialize(self):
        dir_bytes = self.init_path.encode('UTF-8')
        cdef char* dir = dir_bytes
        error = lib.ShamrockInitialize(dir)
        self.verbose(error, sys._getframe().f_code.co_name)

    def GetNumberDevices(self):
        cdef int num = -1
        cdef int* num_ptr = &num
        error = lib.ShamrockGetNumberDevices(num_ptr)
        self.verbose(error, sys._getframe().f_code.co_name)
        print(num)

