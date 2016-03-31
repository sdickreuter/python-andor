""" A object-oriented, high-level interface for Andor cameras, written in Cython.

Based on the Andor SDK v2
"""

import numpy as np
cimport numpy as np
np.import_array()

import atmcd
import time

cimport cython
cimport atmcdLXd as sdk   # Andor SDK definition file

# Errors
class AndorError(Exception):
  def __init__(self, error_code, sdk_func = None):
    self.code = error_code
    self.string = ERROR_CODE[self.code]
    self.sdk_func = sdk_func
  def __str__(self):
    return self.string

def andorError(error_code, ignore = (), info = ()):
  """Wrap each SDK function in andorError to catch errors.
  Error codes in 'ignore' will be silently ignored, 
  while those is 'info' will trigger and AndorInfo exception. ??? not for now, not sure what to do with those...
  for now they will just print the error message"""
  if (error_code in info):
    print("Andor info: " + ERROR_CODE[error_code])
  elif (error_code != sdk.DRV_SUCCESS) and (ERROR_CODE[error_code] not in ignore):
    raise AndorError(error_code)
  else:
    pass
  
def _initialize(library_path = "/usr/local/etc/andor/"):
  andorError(sdk.Initialize(library_path))
  
def _shutdown():
  andorError(sdk.ShutDown())
    
def AvailableCameras():
  """Return the total number of Andor cameras currently installed.
  
  It is possible to call this function before any of the cameras are initialized.
  """
  cdef np.int32_t totalCameras
  andorError(sdk.GetAvailableCameras(&totalCameras))
  return totalCameras
  
def while_acquiring(func):
  """Decorator that allows calling SDK functions while the camera is
  acquiring in Video mode (acquisition will stopped and restarted).
  """
  def decorated_function(*args, **kwargs):
    self = args[0]
    try:
      func(*args, **kwargs)
    except AndorError as error:
      if error.string is "DRV_ACQUIRING" and self._cam.Acquire._name is 'Video':
        andorError(sdk.AbortAcquisition())
        func(*args, **kwargs)
        andorError(sdk.StartAcquisition())
      else:
        raise error
  return decorated_function
  
def rollover(func):
  """ Decorator that correct for the ADC roll-over by replacing zeros
  with 2**n-1 in image data.
  """
  def inner(*args, **kwargs):
    self = args[0]
    data = func(*args, **kwargs)
    if self.rollover:
      dynamic_range = 2**self._cam.Detector.bit_depth - 1
      data[data==0] = dynamic_range
    return data
  return inner
  
class AndorUI(object):
  """A high-level, object-oriented interface for Andor cameras (SDK v2).
  
  Usage: 
    The UI contains the following objects, most of which are self-explanatory:
    - CameraInfo
    - Temperature
    - Shutter
    - EM : electron-multiplying gain control
    - PreAmp: pre-amplifier control
    - Detector: CCD control, including:
        - VSS: vertical shift speed
        - HSS: horizontal shift speed
        - ADC: analog-to-digital converter
        - OutputAmp: the output amplifier
    - ReadMode: select the CCD read-out mode (full frame, vertical binning, tracks, etc.)
    - AcqMode: select the acquisition mode (single shot, video, accumulate, kinetic)
    - Acquire: control the acquisition and collect data
    - Display: the live CCD display
    
  Upon initialisation, the camera is set by default to:
    - Acquisition mode: single shot
    - Readout mode: full image
    - EM gain: off
    - Vertical shift speed: maximum recommanded
    - Horizontal shift speed: second fastest.
  """
  
  def __init__(self, init=True, start=False, with_sdk=False):
    """Initialize the camera and returns a user-friendly interface. 
    
    Options: 
    - init:  set to False to skip the camera initialisation
             (if it has been initialised already). Default: True.
    - start: if True, start the camera in Video mode. Otherwise, Single shot
    - sdk:   whether to include Andor's ctype SDK wrapper (accessible as _sdk)
    """
    if init:
      andorError(sdk.Initialize("/usr/local/etc/andor/"))
    self._cam = self
    self.CameraInfo = CameraInfo()
    self.Temperature = Temperature(self)
    self.Shutter = InternalShutter(self)
    self.EM = EMGain(self)
    self.PreAmp = PreAmpGain(self)
    self.Detector = Detector()
    #self.Acquire = None
    self.ReadMode = ReadModes(self.CameraInfo.capabilities.ReadModes, {"_cam": self})
    self._AcqMode = AcqModes(self.CameraInfo.capabilities.AcqModes, {"_cam": self})
    # Set up default modes: Single Acq, Image
    self.Acquire = self._AcqMode.Video
    self.Acquire()
    self.ReadMode.Image()
    # Make Andor's ctypes wrapper available
    if with_sdk:
      self._sdk = atmcd.atmcd()
    
  def __del__(self):
    self.Acquire.stop()
    self.Shutter.Close()
    andorError(sdk.ShutDown())
  
  @property
  def exposure(self):
    """Exposure time, in ms """
    t = self.acquisitionTimings
    return t['exposure'] * 1000.0
  @exposure.setter
  @while_acquiring
  def exposure(self, value):
    # Allow setting exposure when acquiring in Video mode
    #if (self.Acquire._name is "Video") and (self.Acquire.status[1] is "DRV_ACQUIRING"):
    #  self.Acquire.stop()
      andorError(sdk.SetExposureTime(value/1000.0))
    #  self.Acquire.start()
    #else:
      andorError(sdk.SetExposureTime(value/1000.0))

  @property 
  def acquisitionTimings(self):
    """ Returns the actual exposure time, accumulation and kinetic cycle times, in seconds
    """
    cdef float exp, acc, kin
    andorError(sdk.GetAcquisitionTimings(&exp, &acc, &kin))
    return {'exposure': exp, 'accumulate': acc, 'kinetic': kin}

class CameraInfo(object):
  """Informations about the camera."""
  def __init__(self):
    cdef int serial
    andorError(sdk.GetCameraSerialNumber(&serial))
    self.serial_number = serial
    cdef char controllerCardModel
    andorError(sdk.GetControllerCardModel(&controllerCardModel))
    self.controller_card = controllerCardModel
    self.capabilities = Capabilities()
    #... more to come
    
  def __repr__(self):
    return "<Andor " + self.capabilities.CameraType + " camera, serial number "+ str(self.serial_number)+">"

class OutputAmp(object):
  """The output amplifier.
  
  Some cameras have a conventional CCD amplifier in addition to the EMCCD amplifier, 
  although most often the EMCCD amplifier is used even with the gain switched off, 
  as it is faster.
  """
  def __init__(self):
    self._active = 0
    self.__call__(0)
  
  def __repr__(self):
    return "Currently active amplifier: " + self.description()+ ". Number of available amplifiers: "+ str(self.number)
  
  @property
  def number(self):
    """Returns the number of available amplifier."""
    cdef int noAmp
    andorError(sdk.GetNumberAmp(&noAmp))
    return noAmp

  @property
  def max_speed(self):
    """ Maximum available horizontal shift speed for the amplifier currently selected."""
    cdef float speed
    andorError(sdk.GetAmpMaxSpeed(self._active, &speed))
    return speed
  
  def __call__(self, amp):
    """ Set output amplifier
    0: Standard EMCCD (default)
    1: Conventional CCD (if available)
    """
    andorError(sdk.SetOutputAmplifier(amp))
    self._active = amp
    
  @property
  def active(self):
    return self._active

  def description(self, index=None):
    """ Return a string with the description of the currently selected amplifier.
    
    Options:
    - index: select a different amplifier
    """
    cdef char *name
    name = "                     " # init char with length 21
    if index == None: 
      index = self._active
    andorError(sdk.GetAmpDesc(index, name, 21))
    return name    

class HSSpeed(object):
  """Controls the horizontal shift speed.  
  
  also includes AD and OutputAmp
  """
  # might be a good idea to not call the SDK functions every time...
  def __init__(self, OutAmp):
    self.ADC = ADChannel(self)
    self.OutputAmp = OutAmp
    self.__call__(0) # default to second fastest speed.
    self.choose = self.__call__
    self.list_settings = []
    self.current = None
    self.ADC.ADConverters = self.ADC.list_ADConverters()
    
  @property 
  def info(self):
    return self.__repr__()
 
  @property
  def number(self):
    cdef int noHSSpeed
    andorError(sdk.GetNumberHSSpeeds(self.ADC.channel, self.OutputAmp.active, &noHSSpeed))
    return noHSSpeed
  
  @property
  def speeds(self):
    cdef float speed
    HSSpeeds = {}
    for index in range(self.number):
      andorError(sdk.GetHSSpeed(self.ADC.channel, self.OutputAmp.active, index, &speed))
      HSSpeeds[index] = speed
    return HSSpeeds
      
  def __repr__(self):
    return "Horizontal shift speed value: " + str(self.current) + "MHz. Possible values: " + str(self.speeds)
      
  def __call__(self, index = None):
    """ Set the speed to that given by the index, or let the user choose from menu
    """
    if index == None:
      print("Select horizontal shift speed values from: ")
      print(self.speeds)
      choice = input('> ')
    else:
      choice = index
    andorError(sdk.SetHSSpeed(self.OutputAmp.active, choice))
    self.current = self.speeds[choice]
      
class VSSpeed(object):
  """ Controls the vertical shift speed (VSS).
  
  Upon initialisation, it defaults to the fastest recommanded speed.
  Call the class with no arguments to select a different speed.
  """
  def __init__(self):
    cdef int noVSSpeed
    andorError(sdk.GetNumberVSSpeeds(&noVSSpeed))
    self.number = noVSSpeed
    self.speeds = {}
    cdef float speed
    for index in range(noVSSpeed):
      andorError(sdk.GetVSSpeed(index, &speed))
      self.speeds[index] = speed
    self._fastestRecommended = self.fastestRecommended
    self.__call__(index = self._fastestRecommended["index"])
    self.choose = self.__call__
    self._voltage = 0
      
  def __repr__(self):
    return "Current vertical shift speed: "+ str(self.current) + "us. \nPossible values : " + str(self.speeds) + "\nMax Recommanded: "+str(self.fastestRecommended)
    
  @property 
  def info(self):
    return self.__repr__()
    
  def __call__(self, index = None):
    """ Set the speed to that given by the index, or let the user choose from menu
    """
    if index == None:
      print("Select vertical shift speed values (in us) from: ")
      print(self.speeds)
      choice = input('> ')
    else:
      choice = index
    andorError(sdk.SetVSSpeed(choice))
    self.current = self.speeds[choice]
  
  @property
  def fastestRecommended(self):
    cdef int index
    cdef float speed
    andorError(sdk.GetFastestRecommendedVSSpeed (&index, &speed))
    return {"index": index, "speed": speed}
  
  @property
  def voltage(self):
    """If you choose a high readout speed (a low readout time), then you should also consider
    increasing the amplitude of the Vertical Clock Voltage.
    There are five levels of amplitude available for you to choose from:
    Normal (0); +1, +2, +3, +4.
    Exercise caution when increasing the amplitude of the vertical clock voltage, since higher
    clocking voltages may result in increased clock-induced charge (noise) in your signal. In
    general, only the very highest vertical clocking speeds are likely to benefit from an
    increased vertical clock voltage amplitude.
    """
    return self._voltage
  
  @voltage.setter
  def voltage(self, v):
    andorError(sdk.SetVSAmplitude(v))
    self._voltage = v
   
         
class ADChannel(object):
  """ The analog-to-digital converter.
  
  Some cameras have more than one ADC with a different dynamic range (e.g. 14 and 16 bits). 
  The choice of ADC will affect the allowed horizontal shift speeds: see the ADConverters
  property for a list of valid comninations.
  """
  def __init__(self, HSS=None):
    self.HSS = HSS
    self.channel = 1
    # Don't finalise initialisation here as HSS.__init__() may not have completed yet!
  
  def list_ADConverters(self):
    adc = []
    current_channel = self.channel
    for i in range(self.number):
      self.channel = i
      if self.HSS == None:
        adc.append({"index": i, "bit_depth": self.bit_depth})
      else:
        adc.append({"index": i, "bit_depth": self.bit_depth, "HSSpeeds": self.HSS.speeds})
    self.channel = current_channel
    return adc
      
  @property
  def number(self):
    """ Returns the number of analog-to-digital converters."""
    cdef int chans
    andorError(sdk.GetNumberADChannels(&chans))
    return chans    
  
  @property
  def channel(self):
    """ The currently selected AD converter."""
    return self._channel
  
  @channel.setter
  def channel(self, chan):
    andorError(sdk.SetADChannel(chan))
    self._channel = chan
    
  @property
  def bit_depth(self):
    """Returns the dynamic range of the currently selected AD converter."""
    cdef int depth
    andorError(sdk.GetBitDepth(self._channel, &depth))
    return depth
    
  def __repr__(self):
    return "Currently selected A/D converter: "+ str(self.channel) +" ("+str(self.bit_depth) + " bits).\nPossible settings are: " + str(self.ADConverters)

class EMGain(object):
  """ Controls the electron multiplying gain.
  
  >>> EMGain.on()/off()
  >>> EMGain.gain = 123 to set
  Note that setting the gain to 0 is the same as switching it off.
  """
  def __init__(self, cam):
    self._cam = cam
    current = self._read_gain_from_camera(readonly=False) # read current setting and set software parameters
    self.modes = {"default": 0, "extended": 1, "linear": 2, "real":3}
    self._mode = self.modes["default"]
  
  @property
  def range(self):
    cdef int low, high
    andorError(sdk.GetEMGainRange(&low, &high))
    return (low, high)

  def _read_gain_from_camera(self, readonly = True):
    cdef int value
    andorError(sdk.GetEMCCDGain(&value))
    if not readonly: 
      # reset software value of sensor gain
      andorError(sdk.GetEMCCDGain(&value))
      self._switch = (value > 0)
      self._gain = value
    return value
    
  @property
  def gain(self):
    return self._gain
  
  @gain.setter
  @while_acquiring
  def gain(self, value):
    self._gain = value
    # only update the sensor gain if EM gain is ON:
    if self._switch:
      andorError(sdk.SetEMCCDGain(value))
  
  def __call__(self, gain):
    self.gain = gain
  
  @while_acquiring  
  def on(self):
    andorError(sdk.SetEMCCDGain(self._gain))
    self._switch = True
  
  @while_acquiring  
  def off(self):
    andorError(sdk.SetEMCCDGain(0))
    self._switch = False
    
  @property
  def is_on(self):
    return self._switch
    
  @is_on.setter
  def is_on(self, state):
    if state:
      self.on()
    else:
      self.off()
    
  def __repr__(self):
    if self._switch:
      return "EMCCD gain is ON, gain value: " + str(self.gain) + "."
    else:
      return "EMCCD gain is OFF."
  
  @property
  def status(self):
    print self.__repr__()
    
  @property
  def advanced(self):
    """Turns on and off access to higher EM gain levels.
    
    Typically optimal signal to noise ratio and dynamic range is achieved between x1 to x300 EM Gain.
    Higher gains of > x300 are recommended for single photon counting only. Before using
    higher levels, you should ensure that light levels do not exceed the regime of tens of
    photons per pixel, otherwise accelerated ageing of the sensor can occur.
    """
    return self._advanced
  @advanced.setter
  def advanced(self, bint state):
    andorError(sdk.SetEMAdvanced(state))
    self._advanced = state
    
  #@property
  #def mode(self):
    #"""The EM Gain mode can be one of the following possible settings:
    
     #Mode 0: The EM Gain is controlled by DAC settings in the range 0-255. Default mode.
          #1: The EM Gain is controlled by DAC settings in the range 0-4095.
          #2: Linear mode.
          #3: Real EM gain
    #To access higher gain values (if available) it is necessary to enable advanced EM gain,
    #see SetEMAdvanced.
    #"""
    #return self._mode
  #@mode.setter
  #def mode(self, mode):
    #if isinstance(mode, str):
      #value = self.modes[mode]
    #else:
      #value = mode
    #andorError(sdk.SetEMGainMode(mode))
    #self._mode
    
class Temperature(object):
  """Manages the camera cooler. 
  
  Default temperature setpoint is -65C.
  """
  def __init__(self, cam):
    self._cam = cam
    self._setpoint = -65
    
  @property
  def range(self):
    """The valid range of temperatures in centigrade to which the detector can be cooled."""
    cdef int tmin, tmax
    andorError(sdk.GetTemperatureRange(&tmin, &tmax))
    return (tmin, tmax)
  
  @property
  def precision(self):
    """The number of decimal places to which the sensor temperature can be returned.""" 
    cdef int precision
    andorError(sdk.GetTemperaturePrecision(&precision))#, ignore = (sdk.DRV_NOT_SUPPORTED,))
    return precision
    
  @property
  def setpoint(self):
    return self._setpoint
  
  @setpoint.setter
  def setpoint(self, value):
    andorError(sdk.SetTemperature(value))
    self._setpoint = value
    
  @property
  def read(self):
    """Returns the temperature of the detector to the nearest degree, and the status of cooling process."""
    cdef int value
    error_code = sdk.GetTemperature(&value)
    andorError(error_code, ignore={ERROR_CODE[k] for k in TEMPERATURE_MESSAGES})
    return {"temperature": value, "status": ERROR_CODE[error_code]}

  @property
  def cooler(self):
    """Read or set the state of the TEC cooler (True: ON, False: OFF)."""
    cdef bint state
    andorError(sdk.IsCoolerOn(&state)) # returns 1 if on, 0 if off
    return state
    
  @cooler.setter  
  def cooler(self, state):
    if state:
      andorError(sdk.CoolerON())
    else:
      andorError(sdk.CoolerOFF())
      
  def __repr__(self):
    return "Current temperature: " + str(self.read) + ", cooler: "+ ("ON" if str(self.cooler) else "OFF") + ", setpoint: " + str(self.setpoint)+"." 
  
class PreAmpGain(object):
  """ The pre-amplifier gain. 
  
  >>> preamp.gain # to see the current setting
  >>> preamp() or preamp.choose()   # just call the object with no argument to choose the gain from a list
  """
  def __init__(self, cam):
    self._cam = cam
    self.number = self._number()
    self.gains = self.list_gains()
    self.__call__(1)
    self.choose = self.__call__
  
  def _number(self):
    cdef int noGains
    andorError(sdk.GetNumberPreAmpGains(&noGains))
    return noGains
  
  def list_gains(self):
    cdef float gain
    gain_list = {}
    for index in range(self.number):
      andorError(sdk.GetPreAmpGain(index, &gain))
      gain_list[index] = gain
    return gain_list
  
  @while_acquiring
  def __call__(self, index = None):
    if index == None:
      print("Select PreAmp gain from: ")
      print(self.gains)
      choice = input('> ')
    else:
      choice = index
    andorError(sdk.SetPreAmpGain(choice))
    self._gain = {"index": choice, "value": self.gains[choice]}
    
  @property
  def gain(self):
    """ Current pre-amplifier gain """
    return self._gain["value"]
    
  def __repr__(self):
    return "Current PreAmp gain: x" + str(self.gain) + ". Possible settings: " + str(self.gains)
  
class InternalShutter(object):
  """Controls the internal shutter.
  
  Use Open(), Closed() or Auto(), or Set(TTL, mode. closingtime openingtime) for custom operation.
  The opening/closing times ar set to minimum by default.
  """
  def __init__(self, cam):
    self._cam = cam
    cdef bint isInstalled
    andorError(sdk.IsInternalMechanicalShutter(&isInstalled))
    self.installed = isInstalled
    self.transfer_times = self.MinTransferTimes
    self.mode = {"auto":0, "open": 1, "closed": 2, "open for FVB series": 4, "open for any series": 5}
    self.TTL_open = {"low":0, "high": 1}
    self.state = None
  
  @property 
  def MinTransferTimes(self):
   cdef int minclosingtime, minopeningtime
   andorError(sdk.GetShutterMinTimes(&minclosingtime,&minopeningtime))
   return {"closing": minclosingtime, "opening": minopeningtime}
  
  def Set(self, mode, ttl=None, closingtime=None, openingtime=None):
    if ttl is None: ttl = self.TTL_open["high"]
    if closingtime is None: closingtime = self.transfer_times["closing"]
    if openingtime is None: openingtime = self.transfer_times["opening"]
    andorError(sdk.SetShutter(ttl, mode, closingtime, openingtime))
  
  @while_acquiring
  def Open(self):
    self.Set(self.mode["open"])
    self.state = "open"
  
  @while_acquiring
  def Close(self):
    self.Set(self.mode["closed"])
    self.state = "closed"
    
  def Auto(self):
    self.Set(self.mode["auto"])
    self.state = "auto"
    
  def __repr__(self):
    return "Internal Shutter present and currently + self.state." if self.installed else "No internal shutter."

class Detector(object):
  """ Represents the EMCCD sensor, including A/D converter, output amplifier, vertical and horizontal shift speed.
  """
  # NOTE: actually the AD converter and output amp are not really part of the sensor, if we limit it to the 2D CCD array...
  def __init__(self):
    self.VSS = VSSpeed()
    self.OutputAmp = OutputAmp()#
    self.HSS = HSSpeed(self.OutputAmp)
    self.ADC = self.HSS.ADC
    #self.bit_depth = self.ADC.bit_depth  # we only need ADChannel to read the bit depth
    self.size = self._size
    self.pixel_size = self._pixel_size
  
  @property
  def _pixel_size(self):
    """ Returns the dimension of the pixels in the detector in microns."""
    cdef float xSize, ySize
    andorError(sdk.GetPixelSize(&xSize, &ySize))
    return (xSize, ySize)
    
  @property
  def _size(self):
    """Returns the size of the detector in pixels. The horizontal axis is taken to be the axis parallel to the readout register."""
    cdef int xpixels, ypixels
    andorError(sdk.GetDetector(&xpixels, &ypixels))
    self.width = xpixels
    self.height = ypixels
    self.pixels = xpixels * ypixels
    return (xpixels, ypixels)
  
  @property
  def bit_depth(self):
    return self.ADC.bit_depth
    
  def __repr__(self):
    return "Andor CCD | "+str(self.size[0])+"x"+str(self.size[1]) +" pixels | Pixel size: " + str(self.pixel_size[0])+"x"+str(self.pixel_size[1]) +"um."


# CAPABILITIES
# Upon initialisation, the camera capabilities are determined and only the valid ones 
# are made available.

class _AddCapabilities(object):
  # Populates a type of capabilities (ReadModes, AcqModes etc.) with only the modes that are available.
  # Use in Andor class as:
  # self._capabilities = _Capabilities()
  # self.ReadMode = _AddCapabilities(self._capabilities.ReadModes, ref)
  # self.AcqMode = _AddCapabilities(self._capabilities.AcqModes)
  # ref is a dict of {"string": object} tuple giving an optional object to insert as attribute 'string'
  def __init__(self, caps, ref = {}):
    for c in caps:
      if c._available:
        setattr(c, c._typ, self) # include reference to higher-level class of the right type.
        for key, value in ref.iteritems(): # add custom references
          setattr(c, key, value)
        setattr(self, c._name, c) # create Capability with the right name
    self.current = None
    
  @property 
  def info(self):
    """ Print user-friendly information about the object and its current settings. """
    return self.__repr__()
    
#Better to have a different class for each mode since they are not configured in the same way...
    
class Capability(object):
  """ A general class for camera capabilities.
  
  This is mostly a convenience class that allows to programmatically declare 
  the available capabilities.
  
  typ: Capability type (eg ReadMode, AcqMode...)
  name: Capability name
  code: the Capability identifier (eg sdk.AC_READMODE_FVB)
  caps: the element of the Capability structure corresponding to typ (eg caps.ulReadModes)  
  """
  def __init__(self, typ, name, code, caps):
    self._name = name # This will be the name as it appear to the user
    self._available = code & caps > 0
    self._code = code
    self._typ = typ

# ReadModes capabilities

class ReadModes(_AddCapabilities):
  """ This class is just container for the available ReadMode_XXX classes """
  # It's little more than an alias for _AddCapabilities
  def __init__(self, caps, ref = {}):
    super(ReadModes, self).__init__(caps, ref)
        
  def __repr__(self):
    return "Current Read mode : " + self.current._name

    
class ReadMode(Capability):
  """An abstract class from whom all ReadMode classes will derive."""
  #Doesn't do anything but makes the class hierachy more sensible. 
  def __init__(self, typ, name, code, caps):
    super(ReadMode, self).__init__(typ, name, code, caps)  
    
class ReadMode_FullVerticalBinning(ReadMode):
  """ Set the camera in FVB mode.
  
  Arguments: None
  """
  def __init__(self, typ, name, code, caps):
    super(ReadMode_FullVerticalBinning, self).__init__(typ, name, code, caps)
    
  def __call__(self):
    andorError(sdk.SetReadMode(0))
    self.ReadMode.current = self
    self.shape = [1]
    self.shape = self._cam.Detector.width
    self.pixels = self._cam.Detector.width
    
class ReadMode_SingleTrack(ReadMode):
  """ Set the camera in Single Track mode.
  
  Arguments: - Position of track center (in pixel)
             - Track height (in pixels)
             
  Use set_centre() and set_height to change the track settings during a Video run.
  """
  def __init__(self, typ, name, code, caps):
    super(ReadMode_SingleTrack, self).__init__(typ, name, code, caps)
    
  def __call__(self, centre, height):
    """Set and configure the Readout Mode to Single Track."""
    andorError(sdk.SetReadMode(3))
    andorError(sdk.SetSingleTrack(centre, height))
    self.centre = centre
    self.height = height
    self.position = (centre, height)
    self._cam.ReadMode.current = self
    self.pixels = self._cam.Detector.width
    self.ndims = 1
    self.shape = [self._cam.Detector.width]
    
  @while_acquiring
  def set_centre(self, centre):
    """Update the track position (can be called during acquisition)."""
    andorError(sdk.SetSingleTrack(centre, self.height))
    self.centre = centre
    
  @while_acquiring
  def set_height(self, height):
    """Update the track height (can be called during acquisition)."""
    andorError(sdk.SetSingleTrack(self.centre, height))
    self.height = height
    
class ReadMode_MultiTrack(ReadMode):
  """ Set the camera in Multitrack mode.
  
  Arguments: - Number of tracks
             - Track height, in pixels
             - First track offset, in pixels
  """
  def __init__(self, typ, name, code, caps):
    super(ReadMode_MultiTrack, self).__init__(typ, name, code, caps)
    
  def __call__(self, number, height, offset):
    andorError(sdk.SetReadMode(1))
    cdef int bottom, gap
    andorError(sdk.SetMultiTrack(number, height, offset, &bottom, &gap))
    self.number = number
    self.height = height
    self.offset = offset
    self.bottom = bottom
    self.gap = gap
    self._cam.ReadMode.current = self
    self.pixels = self._cam.Detector.width * self.number
    if self.number == 1:
      self.ndims = 1
      self.shape= [self._cam.Detector.width]
    else:
      self.ndims = 2
      self.shape= [self.number, self._cam.Detector.width]
      
class ReadMode_RandomTrack(ReadMode):
  """ Set the camera in RandomTrack mode.
  
  Arguments: - Number of tracks: int
             - track parameters: tuple (start1, stop1, start2, stop2, ...)
  """
  def __init__(self, typ, name, code, caps):
    super(ReadMode_RandomTrack, self).__init__(typ, name, code, caps)
    
  def __call__(self, numTracks, areas):
    """ Set the camera in RandomTrack mode.
    
    Arguments: - Number of tracks: int
               - track parameters: tuple (start1, stop1, start2, stop2, ...)
    """
    cdef np.ndarray[np.int_t, mode="c", ndim=1] areasnp = np.ascontiguousarray(np.empty(shape=6, dtype = np.int))
    andorError(sdk.SetReadMode(2))
    andorError(sdk.SetRandomTracks(numTracks, &areasnp[0]))
    self.numTracks = numTracks
    self.areas = areas
    self._cam.ReadMode.current = self
    self.pixels = self._cam.Detector.width * self.numTracks
    if self.numTracks == 1:
      self.ndims = 1
      self.shape= [self._cam.Detector.width]
    else:
      self.ndims = 2
      self.shape= [self.numTracks, self._cam.Detector.width]
      
  def data_to_image(self, data):
    """Forms an image from Random Track data."""
    raise NotImplementedError
   
class ReadMode_Image(ReadMode):
  """ Set the camera to full image mode.
  
  Arguments: None
  """
  def __init__(self, typ, name, code, caps):
    super(ReadMode_Image, self).__init__(typ, name, code, caps)
    
  def __call__(self, binning=None, size=None, lower_left=None, bint isolated_crop=False):
    """Set Readout mode to Image, with optional binning and sub-area coordinates.
    
    NOTE: binning and subarea not implemented yet
    
    **kwargs: - binning = (hbin, vbin)
              - size = (hsize, vsize) (in binned pixels
              - lower_left: (h0, v0) coordinates of lower left pixel
    """
    #NOTE: this is probably buggy
    andorError(sdk.SetReadMode(4))
    # process **kwargs and set Image parameters if they are defined:  
    (hbin, vbin) = (1, 1) if binning is None else binning
    (hsize, vsize) = self._cam.Detector.size if size is None else size
    (h0, v0) = (1, 1) if lower_left is None else lower_left
    #if not None in (binning, size, lower_left):
    #  andorError(sdk.SetImage(hbin, vbin, h0, h0 + hsize - 1, v0, v0 + vsize - 1))
    #if isolated_crop:
    #  andorError(SetIsolatedCropMode(isolated_crop, hsize * hbin, vbin, hbin))
    
    self._cam.ReadMode.current = self
    self.pixels = hsize * vsize
    self.shape = [hsize, vsize]
    self.ndims = 2
    
    
# AcqModes capabilities
# The AcqMode class provide functions that are common to all modes (status, start, stop),
# while the AcqMode_XXX classes provide mode-specific functions (initialisation and doc)
# NOTE : the "typ" parameters could be removed here...
# To change the mode or change the parameters, just call the object:
# >>> main.AcqMode.Kinetic(params)
# The first call to an SDK function will raise an error if it can't be change, so we don't need to worry about that.
# Then to start the acquisition:
# >>> main.Acquire.start()
# >>> main.Acquire.status
# >>> main.Acquire.stop()
# main.Acquire is just a reference to the current AcqMode object.

class AcqModes(_AddCapabilities):
  """ This class is a container for the available AcqMode_XXX classes. """
  # It's little more than an alias for _AddCapabilities
  def __init__(self, caps, ref = {}):
    super(AcqModes, self).__init__(caps, ref)
    self.current = None
    
  def __repr__(self):
    return "Current Acquisition mode : " + self.current._name

class AcqMode(Capability):
  # The parent class for all acquisition modes. 
  # Includes methods to start/stop the acquisition and collect the acquired data
  def __init__(self, typ, name, code, caps):
    super(AcqMode, self).__init__(typ, name, code, caps)
    self.current = None
    self.rollover = False
    self.snapshot_count = 0
    self.last_snap_read = 0
    #self.Trigger = _AddCapabilities(self._cam.CameraInfo.capabilities.TriggerModes, {})

  # Acquisition control
  
  @property
  def status(self):
    cdef int status
    andorError(sdk.GetStatus(&status))
    return (status, ERROR_CODE[status])
  
  @property
  def running(self):
    if self.status[1] is "DRV_ACQUIRING":
      return True
    else:
      return False
  
  def start(self):
    andorError(sdk.StartAcquisition())
    self.start_time = time.time()
    self.snapshot_count += 1
    
  def stop(self):
    #try:
      andorError(sdk.AbortAcquisition(), ignore=('DRV_IDLE'))
    #except AndorError as error:
     # if error.string is not 'DRV_IDLE': 
      #  raise error
    
  def wait(self, new_data=False):
    """Wait either for new data to be available or for the whole acquisition sequence (default) to terminate.
    
    Press Ctrl+C to stop waiting.
    """
    try:
      andorError(sdk.WaitForAcquisition())
      if not new_data:
        while self.status[1] is 'DRV_ACQUIRING':
          andorError(sdk.WaitForAcquisition())
    except KeyboardInterrupt:
      pass
    
  def __call__(self):
    # Stuff to do for all modes when calling the method, namely set 'main.AcqMode.current' and 'main.Acquire' to the current mode
    self._cam._AcqMode.current = self
    self._cam.Acquire = self
    
  @property
  def max_exposure(self):
    """Return the maximum Exposure Time in seconds that is settable."""
    cdef float MaxExp
    andorError(sdk.GetMaximumExposure(&MaxExp))
    return MaxExp
  
  # Data collection
  
  @property
  def size_of_circular_buffer(self):
    """Return the maximum number of images the circular buffer can store based on the current acquisition settings."""
    cdef sdk.at_32 index
    andorError(sdk.GetSizeOfCircularBuffer(&index))
    return index
    
  @property
  def images_in_buffer(self):
    """Return information on the number of available images in the circular buffer.
    
   This information can be used with GetImages to retrieve a series of images. If any
   images are overwritten in the circular buffer they no longer can be retrieved and the
   information returned will treat overwritten images as not available.
   """
    cdef sdk.at_32 first, last
    andorError(sdk.GetNumberAvailableImages(&first, &last))
    return {"first": first, "last": last}

  @property
  def new_images(self):
    """Return information on the number of new images (i.e. images which have not yet been retrieved) in the circular buffer.
    
    This information can be used with GetImages to retrieve a series of the latest images. 
    If any images are overwritten in the circular buffer they can no longer be retrieved
    and the information returned will treat overwritten images as having been retrieved.
    """
    cdef sdk.at_32 first, last
    andorError(sdk.GetNumberNewImages(&first, &last))
    return {"first": first, "last": last}
      
  #@rollover
  def Newest(self, n=1, type=16):
    """Returns a data array with the most recently acquired image in any acquisition mode.
    
    Options:
    - number = number of images to retrieve, default 1
    - type=(16|32): whether to return the data as 16 or 32-bits integers (default: 16)
    """
    cdef np.ndarray[np.uint16_t, mode="c", ndim=1] data16
    cdef np.ndarray[np.int32_t, mode="c", ndim=1] data32
    if n == 1:
      npixels = self._cam.ReadMode.current.pixels
      if type == 16:
        data16 = np.ascontiguousarray(np.empty(shape=npixels, dtype=np.uint16))
        andorError(sdk.GetMostRecentImage16(&data16[0], npixels))
        data = data16
      else:
        data32 = np.ascontiguousarray(np.empty(shape=npixels, dtype=np.int32))
        andorError(sdk.GetMostRecentImage(&data32[0], npixels))
        data = data32
      return data.reshape(self._cam.ReadMode.current.shape)
    elif n > 1:
      most_recent = self.images_in_buffer['last']
      return self.Images(most_recent - n + 1, most_recent)
    else:
      raise ValueError('Invalid number of images: ' + str(n))
      
  
  @rollover
  def Oldest(self, type=16):
    """Retrieve the oldest available image from the circular buffer.
    
    Once the oldest image has been retrieved it is no longer available,
    and calling GetOldestImage again will retrieve the next image.
    This is a useful function for retrieving a number of images.
    For example if there are 5 new images available, calling it 5 times will retrieve them all.
    
    Options:
    - type=(16|32): whether to return the data as 16 or 32-bits integers (default: 16)
    """
    npixels = self._cam.ReadMode.current.pixels
    cdef np.ndarray[np.uint16_t, mode="c", ndim=1] data16
    cdef np.ndarray[np.int32_t, mode="c", ndim=1] data32
    if type == 16:
      data16 = np.ascontiguousarray(np.empty(shape=npixels, dtype=np.uint16))
      andorError(sdk.GetOldestImage16(&data16[0], npixels))
      return data16
    else:
      data32 = np.ascontiguousarray(np.empty(shape=npixels, dtype=np.int32))
      andorError(sdk.GetOldestImage(&data32[0], npixels))
      return data32  
  
  @rollover
  def Images(self, first, last, type=16):
    """ Return the specified series of images from the circular buffer.
    
    If the specified series is out of range (i.e. the images have been
    overwritten or have not yet been acquired) then an error will be returned.
    
    Arguments:
    - first: index of first image in buffer to retrieve.
    - last: index of last image in buffer to retrieve.
    
    Options:
    - type=(16|32): whether to return the data as 16 or 32-bits integers (default: 16)
    """
    nimages = last - first + 1
    pixels_per_image = self._cam.ReadMode.current.pixels
    total_pixels = nimages * pixels_per_image
    final_shape = [nimages] + self._cam.ReadMode.current.shape
    cdef np.ndarray[np.uint16_t, mode="c", ndim=1] data16
    cdef np.ndarray[np.int32_t, mode="c", ndim=1] data32
    cdef np.int32_t validfirst, validlast
    if type == 16:
      data16 = np.ascontiguousarray(np.empty(shape=total_pixels, dtype=np.uint16))
      andorError(sdk.GetImages16(first, last, &data16[0], total_pixels, &validfirst, &validlast))
      data = data16
    else:
      data32 = np.ascontiguousarray(np.empty(shape=total_pixels, dtype=np.int32))
      andorError(sdk.GetImages(first, last, &data32[0], total_pixels, &validfirst, &validlast))
      data = data32
    self.valid = {'first': validfirst, 'last': validlast}
    return data.reshape(final_shape)

  @rollover
  def GetAcquiredData(self, type=16):
    """ Return the whole data set from the last acquisition.
    
    GetAcquiredData should be used once the acquisition is complete to retrieve all the data from the series.
    This could be a single scan or an entire kinetic series.
    
    Options:
    - type=(16|32): whether to return the data as 16 or 32-bits integers (default: 16)
    """   
    pixels_per_image = self._cam.ReadMode.current.pixels
    nimages = self.nimages
    total_pixels = nimages * pixels_per_image
    final_shape = [nimages] + self._cam.ReadMode.current.shape
    cdef np.ndarray[np.uint16_t, mode="c", ndim=1] data16
    cdef np.ndarray[np.int32_t, mode="c", ndim=1] data32
    if type == 16:
      data16 = np.ascontiguousarray(np.empty(shape=total_pixels, dtype = np.uint16))
      andorError(sdk.GetAcquiredData16(&data16[0], total_pixels))
      data = data16
    else:
      data32 = np.ascontiguousarray(np.empty(shape=total_pixels, dtype = np.int32))
      andorError(sdk.GetAcquiredData(&data32[0], total_pixels))
      data = data32
    return data.reshape(final_shape) 

  def Video(self):
    """Switch to Video mode and start acquiring."""
    self = self._cam._AcqMode.Video
    self.__call__(start=True)
    
  def Kinetic(self, numberKinetics, kineticCycleTime, numberAccumulation = 1, accumulationCycleTime = 0, safe=True):
    """Switch to and configure Kinetic acquisition."""
    self = self._cam._AcqMode.Kinetic
    self.__call__(numberKinetics, kineticCycleTime, numberAccumulation, accumulationCycleTime,safe=safe)
  
  def Single(self):
    """Switch to Single mode."""
    #self.stop()
    self = self._cam._AcqMode.Single
    self.__call__()

  def Accumulate(self, numberAccumulation, accumulationCycleTime, safe=True):
    """Switch to and configure Accumulate acquisition."""
    self = self._cam._AcqMode.Accumulate
    self.__call__(numberAccumulation, accumulationCycleTime, safe=safe)
    
  def save(self, h5file, dataset, data):
    """Save data and associated metadata to an open HDF5 file.
    
    *args: - h5file: an open, writeable HDF5 file (see h5py module)
           - dataset: string, the name of the HDF5 dataset (see h5py.create_dataset())
           - data: any HDF5 compatible data (eg cam.Acquire.Newest())
           
    The following metadata are also recorded: Acquisition mode, exposure time,
    EM gain, and time."""
    h5file.create_dataset(dataset, data=data)
    h5file[dataset].attrs['mode'] = self._name
    h5file[dataset].attrs['exposure'] = self._cam.exposure
    h5file[dataset].attrs['em_gain'] = self._cam.EM._read_gain_from_camera()
    h5file[dataset].attrs['created'] = time.strftime("%d/%m/%Y %H:%M:%S")
    
  def take_multiple_exposures(self, exposures):
    """Take a series of single images with varying exposure time.
    
    *args: - exposures: a tuple of exposure times.
    
    returns: a numpy array of length len(exposures).
    """
    if self._name is "Video":
      video = True
      self.stop()
      self.Single()
    data = []
    for e in exposures:
      self._cam.exposure = e
      self.start()
      self.wait()
      data.append(self.Newest())
    if video:
      self.Video()
      self.start()
    return np.array(data)
        
    
class AcqMode_Single(AcqMode):
  """ Set the camera in Single Acquisition mode.
  
  The snapshot_count counter is reset when Single() is called, 
  and incremented every time snap() (or equivalently start()) is called.
  
  Arguments: None
  """
  def __init__(self, typ, name, code, caps):
    super(AcqMode_Single, self).__init__(typ, name, code, caps)
    self.shape = []
    self.ndims = 0
    self.nimages = 1
    
  def __call__(self, safe=True):
    """Set the camera in Single Acquisition mode.
    
    If the kwarg 'safe' is set to False, any ongoing acquisition will be stopped;
    if True (default) an error will be raised.
    """
    if not safe:
      self.stop()
    andorError(sdk.SetAcquisitionMode(1))
    super(AcqMode_Single, self).__call__()
    
  def __repr__(self):
    return "Snapshot acquisition mode."
    
    
  def snap(self, wait=True, typ=16):
    """Take a single image. 
    
    If wait=True, wait for the acquisition to complete and return the data.
    """
    self.start()
    if wait:
      self.wait()
      return self.Newest(typ)
    
class AcqMode_Accumulate(AcqMode):
  """Set the camera in Accumulate mode.
  
  It's a good idea to retrieve the data as 32bits integers."""
  def __init__(self, typ, name, code, caps):
    #
    super(AcqMode_Accumulate, self).__init__(typ, name, code, caps)
    self.shape = []
    self.ndims = 0
    self.nimages = 1
    self._kinetic = False # whether the accumulation cycle is part of a kinetic sequence.
    
  def __call__(self, numberAccumulation, accumulationCycleTime, safe=True):
    """ Set the camera in Accumulate mode.
    
    *args:   - Number of accumulations
             - cycle time
    **kwargs:- safe=True raises an error if an acquisition is ongoing
    """
    if not safe:
      self.stop()
    if not self._kinetic:
      andorError(sdk.SetAcquisitionMode(2))
    andorError(sdk.SetNumberAccumulations(numberAccumulation))
    andorError(sdk.SetAccumulationCycleTime(accumulationCycleTime))
    self.numberAccumulation = numberAccumulation
    self.accumulationCycleTime = accumulationCycleTime
    super(AcqMode_Accumulate, self).__call__()
    
  def __repr__(self):
    return "Accumulate acquisition with settings: \n" + \
           "  Number of Accumulations: "+ str(self.numberAccumulation) +"\n" \
           "  Cycle time: "+ str(self._cam.acquisitionTimings['accumulate']) +"."
  
  def toh5(self, file, name, data):
    super(AcqMode_Accumulate, self).toh5(file, name, data)
    file[name].attrs['accumulate_cycle_time'] = self._cam.acquisitionTimings['accumulate']
    file[name].attrs['accumulate_number'] = self.numberAccumulation


class AcqMode_Video(AcqMode):
  """ Set the camera in Video (Run Till Abort) mode.
  
  Arguments: None
  """
  def __init__(self, typ, name, code, caps):
    super(AcqMode_Video, self).__init__(typ, name, code, caps)
    self.shape = []
    self.ndims = 0
    self.nimages = 1
    
  def __call__(self, start=False, live=False):
    andorError(sdk.SetAcquisitionMode(5))
    super(AcqMode_Video, self).__call__()
    if start:
      super(AcqMode_Video, self).start()
    if live:
      self._cam.Display.start()
      
  def __repr__(self):
    return "Video."

class AcqMode_Kinetic(AcqMode_Accumulate):
  """ Set the camera in Kinetic mode.
  
  *args:    - Number of images in Kinetic sequence
            - cycle time
  **kwargs: - number of accumulation per image in Kinetic sequence (default: no accumulation)
          (optional): accumulation cycle time
  """
  def __init__(self, typ, name, code, caps):
    super(AcqMode_Kinetic, self).__init__(typ, name, code, caps)
    self._kinetic = True
    
  def __call__(self, numberKinetics, kineticCycleTime, numberAccumulation = 1, accumulationCycleTime = 0, safe=True):
    """Set the camera in Kinetic mode.
    
    *args:    - numberKinetics
              - kineticCycleTime
    **kwargs: - numberAccumulation (None)
              - accumulationCycleTime (0)
              - safe (True): set to False to cancel any ongoing acquisition.
    """
    if not safe:
      self.stop()
    andorError(sdk.SetAcquisitionMode(3))
    andorError(sdk.SetNumberKinetics(numberKinetics))
    andorError(sdk.SetKineticCycleTime(kineticCycleTime))
    self.numberKinetics = numberKinetics
    self.kineticCycleTime = kineticCycleTime
    self.ndims = 1
    self.shape = [numberKinetics,]
    self.nimages = numberKinetics
    # Now call Accumulate()
    super(AcqMode_Kinetic, self).__call__(numberAccumulation, accumulationCycleTime, safe)
    
    # NOTE : Should check the value of GetAcquisitionTimings 
  
  def toh5(self, file, name, data):
    super(AcqMode_Kinetic, self).toh5(file, name, data)
    file[name].attrs['kinetic_cycle_time'] = self._cam.acquisitionTimings['kinetic']
  
  def __repr__(self):
    if self.numberAccumulation > 1:
      acc_str = "  Number of Accumulation: " + str(self.numberAccumulation) + "\n" \
            + "  Accumulation cycle time: " + str(self.accumulationCycleTime)
    else:
      acc_str = "  No Accumulation"
    return("Kinetic acquisition with settings : \n" \
            + "  Number in Kinetic series: " + str(self.numberKinetics) + "\n" \
            + "  Kinetic cycle time: " + str(self.kineticCycleTime) + "\n" \
            + acc_str)       
            
class TriggerMode(Capability):
  def __init__(self, typ, name, code, caps, trigger_code):
    super(TriggerMode, self).__init__(typ, name, code, caps)
    self._inverted = False
    self._trigger_code = trigger_code
    
  def __call__(self):
    """Call with no argument to set the trigger mode."""
    andorError(sdk.SetTriggerMode(self._trigger_code))
    
  @property
  def inverted(self):
    """This property will set whether an acquisition will be triggered on a rising (False, default) or falling (True) edge external trigger."""
    return self._inverted
  @inverted.setter
  def inverted(self, bint value):
    andorError(sdk.SetTriggerInvert(value))
    self._inverted = value
    
  def __repr__(self):
    return "<Trigger mode>"

            
class Capabilities:
  """ This class defines the camera capabilities. Each type of capabilities
  (eg Acquisition mode, Read mode...) is a dictionary {"capability", bool}
  """
  # Should we initialise caps here?
  def __init__(self):
    cdef sdk.AndorCapabilities caps
    caps.ulSize = cython.sizeof(caps)
    andorError(sdk.GetCapabilities(&caps))
    self._AcqModes = {"Single": sdk.AC_ACQMODE_SINGLE & caps.ulAcqModes > 0, 
         "Video": sdk.AC_ACQMODE_VIDEO & caps.ulAcqModes > 0,
         "Accumulate": sdk.AC_ACQMODE_ACCUMULATE & caps.ulAcqModes > 0,
         "Kinetic": sdk.AC_ACQMODE_KINETIC & caps.ulAcqModes > 0,
         "Frame transfer": sdk.AC_ACQMODE_FRAMETRANSFER & caps.ulAcqModes > 0,
         "Fast kinetics": sdk.AC_ACQMODE_FASTKINETICS & caps.ulAcqModes > 0,
         "Overlap": sdk.AC_ACQMODE_OVERLAP & caps.ulAcqModes > 0}
    self._ReadModes = {"Full image": sdk.AC_READMODE_FULLIMAGE & caps.ulReadModes > 0,
          "Subimage": sdk.AC_READMODE_SUBIMAGE & caps.ulReadModes > 0,
          "Single track": sdk.AC_READMODE_SINGLETRACK & caps.ulReadModes > 0,
          "Full vertical binning": sdk.AC_READMODE_FVB & caps.ulReadModes > 0,
          "Multi-track": sdk.AC_READMODE_MULTITRACK & caps.ulReadModes > 0,
          "Random track": sdk.AC_READMODE_RANDOMTRACK & caps.ulReadModes > 0,
          "Multi track scan": sdk.AC_READMODE_MULTITRACKSCAN & caps.ulReadModes > 0}
    self._ReadModesWithFrameTransfer = {"Full image": sdk.AC_READMODE_FULLIMAGE & caps.ulFTReadModes > 0,
          "Subimage": sdk.AC_READMODE_SUBIMAGE & caps.ulFTReadModes > 0,
          "Single track": sdk.AC_READMODE_SINGLETRACK & caps.ulFTReadModes > 0,
          "Full vertical binning": sdk.AC_READMODE_FVB & caps.ulFTReadModes > 0,
          "Multi-track": sdk.AC_READMODE_MULTITRACK & caps.ulFTReadModes > 0,
          "Random track": sdk.AC_READMODE_RANDOMTRACK & caps.ulFTReadModes > 0,
          "Multi track scan": sdk.AC_READMODE_MULTITRACKSCAN & caps.ulFTReadModes > 0}
    self._TriggerModes = {"Internal": sdk.AC_TRIGGERMODE_INTERNAL & caps.ulTriggerModes > 0,
          "External": sdk.AC_TRIGGERMODE_EXTERNAL & caps.ulTriggerModes > 0,
          "External with FVB + EM": sdk.AC_TRIGGERMODE_EXTERNAL_FVB_EM & caps.ulTriggerModes > 0,
          "Continuous": sdk.AC_TRIGGERMODE_CONTINUOUS & caps.ulTriggerModes > 0,
          "External start": sdk.AC_TRIGGERMODE_EXTERNALSTART & caps.ulTriggerModes > 0,
          "External exposure": sdk.AC_TRIGGERMODE_EXTERNALEXPOSURE & caps.ulTriggerModes > 0,
          "Inverted": sdk.AC_TRIGGERMODE_INVERTED & caps.ulTriggerModes > 0,
          "Charge shifting": sdk.AC_TRIGGERMODE_EXTERNAL_CHARGESHIFTING & caps.ulTriggerModes > 0}
    self.TriggerModes = (
	  TriggerMode("", "Internal", 1, 1, 0),
          TriggerMode("", "External", sdk.AC_TRIGGERMODE_EXTERNAL, caps.ulTriggerModes, 1),
          TriggerMode("", "External_FVB", sdk.AC_TRIGGERMODE_EXTERNAL_FVB_EM, caps.ulTriggerModes, 9),
          TriggerMode("", "Continuous", sdk.AC_TRIGGERMODE_CONTINUOUS, caps.ulTriggerModes, 10),
          TriggerMode("", "External start", sdk.AC_TRIGGERMODE_EXTERNALSTART, caps.ulTriggerModes, 6),
          TriggerMode("", "External_Exposure", sdk.AC_TRIGGERMODE_EXTERNALEXPOSURE, caps.ulTriggerModes, 7),
          TriggerMode("", "External_Charge_Shifting", sdk.AC_TRIGGERMODE_EXTERNAL_CHARGESHIFTING, caps.ulTriggerModes, 12)
          )
    self.AcqModes = (AcqMode_Single("AcqMode", "Single", sdk.AC_ACQMODE_SINGLE, caps.ulAcqModes),
          AcqMode_Video("AcqMode", "Video", sdk.AC_ACQMODE_VIDEO, caps.ulAcqModes),
          AcqMode_Accumulate("AcqMode", "Accumulate", sdk.AC_ACQMODE_ACCUMULATE, caps.ulAcqModes),
          AcqMode_Kinetic("AcqMode", "Kinetic", sdk.AC_ACQMODE_KINETIC, caps.ulAcqModes),
          )
    self.ReadModes = (ReadMode_Image("ReadMode", "Image", sdk.AC_READMODE_FULLIMAGE, caps.ulReadModes),
          #ReadMode_SubImage("ReadMode", "Subimage", sdk.AC_READMODE_SUBIMAGE, caps.ulReadModes),
          ReadMode_SingleTrack("ReadMode", "SingleTrack", sdk.AC_READMODE_SINGLETRACK, caps.ulReadModes),
          ReadMode_FullVerticalBinning("ReadMode", "FullVerticalBinning", sdk.AC_READMODE_FVB, caps.ulReadModes),
          ReadMode_MultiTrack("ReadMode", "MultiTrack", sdk.AC_READMODE_MULTITRACK, caps.ulReadModes),
          ReadMode_RandomTrack("ReadMode", "RandomTrack", sdk.AC_READMODE_RANDOMTRACK, caps.ulReadModes),
          #ReadMode_MultiTrackScan("ReadMode", "MultiTrackScan", sdk.AC_READMODE_MULTITRACKSCAN, caps.ulReadModes)
          )
    self.CameraType = CameraTypes[caps.ulCameraType]
    self.PixelModes = {"8 bits": sdk.AC_PIXELMODE_8BIT & caps.ulPixelMode > 0, 
                       "14 bits": sdk.AC_PIXELMODE_14BIT & caps.ulPixelMode > 0,
                       "16 bits": sdk.AC_PIXELMODE_16BIT & caps.ulPixelMode > 0,
                       "32 bits": sdk.AC_PIXELMODE_32BIT & caps.ulPixelMode > 0}
    self.SetFunctions = {"Extended EM gain range": sdk.AC_SETFUNCTION_EMADVANCED & caps.ulSetFunctions > 0,
                 "Extended NIR mode": sdk.AC_SETFUNCTION_EXTENDEDNIR & caps.ulSetFunctions > 0,
                 "High capacity mode": sdk.AC_SETFUNCTION_HIGHCAPACITY & caps.ulSetFunctions > 0}
    
CameraTypes = {0: "PDA", 1: "iXon", 2: "ICCD", 3: "EMCCD", 4: "CCD", 5: "iStar", 6: "Not Andor Camera", 
7: "IDus", 8: "Newton", 9: "Surcam", 10: "USBiStar", 11: "Luca", 13: "iKon", 14: "InGaAs",
15: "iVac", 17: "Clara"}

PixelModes = {0: "8 bits", 1: "14 bits", 2: "16 bits", 3: "32 bits"}   
  
TEMPERATURE_MESSAGES = (20034, 20035, 20036, 20037, 20040)
  
ERROR_CODE = {
    20001: "DRV_ERROR_CODES",
    20002: "DRV_SUCCESS",
    20003: "DRV_VXNOTINSTALLED",
    20006: "DRV_ERROR_FILELOAD",
    20007: "DRV_ERROR_VXD_INIT",
    20010: "DRV_ERROR_PAGELOCK",
    20011: "DRV_ERROR_PAGE_UNLOCK",
    20013: "DRV_ERROR_ACK",
    20024: "DRV_NO_NEW_DATA",
    20026: "DRV_SPOOLERROR",
    20034: "DRV_TEMP_OFF",
    20035: "DRV_TEMP_NOT_STABILIZED",
    20036: "DRV_TEMP_STABILIZED",
    20037: "DRV_TEMP_NOT_REACHED",
    20038: "DRV_TEMP_OUT_RANGE",
    20039: "DRV_TEMP_NOT_SUPPORTED",
    20040: "DRV_TEMP_DRIFT",
    20050: "DRV_COF_NOTLOADED",
    20053: "DRV_FLEXERROR",
    20066: "DRV_P1INVALID",
    20067: "DRV_P2INVALID",
    20068: "DRV_P3INVALID",
    20069: "DRV_P4INVALID",
    20070: "DRV_INIERROR",
    20071: "DRV_COERROR",
    20072: "DRV_ACQUIRING",
    20073: "DRV_IDLE",
    20074: "DRV_TEMPCYCLE",
    20075: "DRV_NOT_INITIALIZED",
    20076: "DRV_P5INVALID",
    20077: "DRV_P6INVALID",
    20083: "P7_INVALID",
    20089: "DRV_USBERROR",
    20099: "DRV_BINNING_ERROR",
    20990: "DRV_NOCAMERA",
    20991: "DRV_NOT_SUPPORTED",
    20992: "DRV_NOT_AVAILABLE"
}
