
cdef extern from "ShamrockCIF.h" :
    
    #//sdkbasic functions
    unsigned int ShamrockInitialize(char * IniPath)
    unsigned int ShamrockClose()
    unsigned int ShamrockGetNumberDevices(int *nodevices)
    unsigned int ShamrockGetFunctionReturnDescription(int error,char *description, int MaxDescStrLen)
    #//sdkeeprom functions
    unsigned int ShamrockGetSerialNumber(int device,char *serial)
    unsigned int ShamrockEepromGetOpticalParams(int device,float *FocalLength,float *AngularDeviation,float *FocalTilt)
    #//sdkgrating functions
    unsigned int ShamrockSetGrating(int device,int grating)
    unsigned int ShamrockGetGrating(int device,int *grating)
    unsigned int ShamrockWavelengthReset(int device)
    unsigned int ShamrockGetNumberGratings(int device,int *noGratings)
    unsigned int ShamrockGetGratingInfo(int device,int Grating, float *Lines,  char* Blaze, int *Home, int *Offset)
    unsigned int ShamrockSetDetectorOffset(int device,int offset)
    unsigned int ShamrockGetDetectorOffset(int device,int *offset)
    unsigned int ShamrockSetDetectorOffsetPort2(int device,int offset)
    unsigned int ShamrockGetDetectorOffsetPort2(int device,int *offset)
    unsigned int ShamrockSetDetectorOffsetEx(int device, int entrancePort, int exitPort, int offset)
    unsigned int ShamrockGetDetectorOffsetEx(int device, int entrancePort, int exitPort, int *offset)
    unsigned int ShamrockSetGratingOffset(int device,int Grating, int offset)
    unsigned int ShamrockGetGratingOffset(int device,int Grating, int *offset)
    unsigned int ShamrockGratingIsPresent(int device,int *present)
    unsigned int ShamrockSetTurret(int device,int Turret)
    unsigned int ShamrockGetTurret(int device,int *Turret)
    #//sdkwavelength functions
    unsigned int ShamrockSetWavelength(int device, float wavelength)
    unsigned int ShamrockGetWavelength(int device, float *wavelength)
    unsigned int ShamrockGotoZeroOrder(int device)
    unsigned int ShamrockAtZeroOrder(int device, int *atZeroOrder)
    unsigned int ShamrockGetWavelengthLimits(int device, int Grating, float *Min, float *Max)
    unsigned int ShamrockWavelengthIsPresent(int device,int *present)
    #//sdkslit functions
    
    #// New Slit Functions
    unsigned int ShamrockSetAutoSlitWidth(int device, int index, float width)
    unsigned int ShamrockGetAutoSlitWidth(int device, int index, float *width)
    unsigned int ShamrockAutoSlitReset(int device, int index)
    unsigned int ShamrockAutoSlitIsPresent(int device, int index, int *present)
    unsigned int ShamrockSetAutoSlitCoefficients(int device, int index, int x1, int y1, int x2, int y2)
    #unsigned int ShamrockGetAutoSlitCoefficients(int device, int index, int &x1, int &y1, int &x2, int &y2)

    #///// Deprecated Slit Functions
    #// Deprecated Input Slit Functions
    #unsigned int ShamrockSetSlit(int device,float width)
    #unsigned int ShamrockGetSlit(int device,float *width)
    #unsigned int ShamrockSlitReset(int device)
    #unsigned int ShamrockSlitIsPresent(int device,int *present)
    #unsigned int ShamrockSetSlitCoefficients(int device, int x1, int y1, int x2, int y2)
    #unsigned int ShamrockGetSlitCoefficients(int device, int &x1, int &y1, int &x2, int &y2)
    
    #// Deprecated Ouput Slit functions
    #unsigned int ShamrockSetOutputSlit(int device,float width)
    #unsigned int ShamrockGetOutputSlit(int device,float *width)
    #unsigned int ShamrockOutputSlitReset(int device)
    #unsigned int ShamrockOutputSlitIsPresent(int device,int *present)
    #/////
    
    #//sdkshutter functions
    unsigned int ShamrockSetShutter(int device,int mode)
    unsigned int ShamrockGetShutter(int device, int *mode)
    unsigned int ShamrockIsModePossible(int device,int mode,int *possible)
    unsigned int ShamrockShutterIsPresent(int device,int *present)
    #//sdkfilter functions
    unsigned int ShamrockSetFilter(int device,int filter)
    unsigned int ShamrockGetFilter(int device,int *filter)
    unsigned int ShamrockGetFilterInfo(int device,int Filter, char* Info)
    unsigned int ShamrockSetFilterInfo(int device,int Filter, char* Info)
    unsigned int ShamrockFilterReset(int device)
    unsigned int ShamrockFilterIsPresent(int device,int *present)
    
    #//sdkflipper functions
    
    #// New flipper functions
    unsigned int ShamrockSetFlipperMirror(int device, int flipper, int port)
    unsigned int ShamrockGetFlipperMirror(int device, int flipper, int * port)
    unsigned int ShamrockFlipperMirrorReset(int device, int flipper)
    unsigned int ShamrockFlipperMirrorIsPresent(int device, int flipper, int *present)
    unsigned int ShamrockGetCCDLimits(int device, int port, float *Low, float *High)
    unsigned int ShamrockSetFlipperMirrorPosition(int device, int flipper, int position)
    unsigned int ShamrockGetFlipperMirrorPosition(int device, int flipper, int *position)
    unsigned int ShamrockGetFlipperMirrorMaxPosition(int device, int flipper, int *max)
    
    #// Deprecated
    #unsigned int ShamrockSetPort(int device,int port)
    #unsigned int ShamrockGetPort(int device, int*port)
    #unsigned int ShamrockFlipperReset(int device)
    #unsigned int ShamrockFlipperIsPresent(int device,int *present)
    
    #//sdkaccessory functions
    unsigned int ShamrockSetAccessory(int device,int Accessory, int State)
    unsigned int ShamrockGetAccessoryState(int device,int Accessory, int *state)
    unsigned int ShamrockAccessoryIsPresent(int device,int *present)
    
    #//sdkshutter functions
    unsigned int ShamrockSetFocusMirror(int device, int focus)
    unsigned int ShamrockGetFocusMirror(int device, int *focus)
    unsigned int ShamrockGetFocusMirrorMaxSteps(int device, int *steps)
    unsigned int ShamrockFocusMirrorReset(int device)
    unsigned int ShamrockFocusMirrorIsPresent(int device, int *present)
    
    #//sdkcalibration functions
    unsigned int ShamrockSetPixelWidth(int device, float Width)
    unsigned int ShamrockSetNumberPixels(int device, int NumberPixels)
    unsigned int ShamrockGetPixelWidth(int device, float* Width)
    unsigned int ShamrockGetNumberPixels(int device, int* NumberPixels)
    unsigned int ShamrockGetCalibration(int device, float* CalibrationValues, int NumberPixels)
    unsigned int ShamrockGetPixelCalibrationCoefficients(int device, float* A, float* B, float* C, float* D)
