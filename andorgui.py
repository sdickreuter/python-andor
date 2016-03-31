"""An object-oriented, high-level interface for Andor cameras.

Extends the cyandor.AndorUI interface by adding a live video display,
line plots for profiles or single-track data.

Because it does no call on the Andor SDK, Cython is not required here,
which makes it easier to expand (no recompiling).

G. Lepert, Feb 2015
"""

from andor import AndorUI, AndorError
from camdisp import CameraDisplay
import numpy as np
import matplotlib.pyplot as plt
import Tkinter as tk
import matplotlib as mpl
from matplotlib.backends.backend_tkagg import FigureCanvasTkAgg, NavigationToolbar2TkAgg
import h5py as h5


def if_new_data_ready(update_func):
  """Wrapper for the live display/plot update() method that will prevent it from updating if there is no new data."""
  # This is both for performance purpose and to avoid the "DRV_NO_NEW_DATA" error that
  # may arise if the Video acquisition is restarted while the display is live.
  def if_new_data_ready_decorated(*args, **kwargs):
    live_object = args[0]
    try:
      if (live_object._cam.Acquire.status[1] is "DRV_ACQUIRING") and (live_object._cam.Acquire.images_in_buffer['last'] is not live_object.last_image_read):
        update_func(*args, **kwargs)
      if (live_object._cam.Acquire._name is not 'Video'):# and (live_object._cam.Acquire.snapshot_count is not live_object._cam.Acquire.last_snap_read):
        update_func(*args, **kwargs)
        live_object._cam.Acquire.last_snap_read = live_object._cam.Acquire.snapshot_count
    except AndorError as error:
      if error.string not in ("DRV_NO_NEW_DATA", "DRV_NOT_INITIALIZED"): # ignore this error; occurs when changing exposure on the fly.
          raise error
  return if_new_data_ready_decorated

class AndorGUI(AndorUI):
  """Create a camera object with live display.
  
  Keyword arguments:
  - camera: a reference an initialised AndorUI object. If not provided, the camera will be initialised.
  
  See also the AndorUI docstring.
  """
  def __init__(self, camera=None, start=True):
    if camera is None:
      super(AndorGUI, self).__init__(start=start)
    else:
      self = camera
    self.Display = LiveDisplay(self, zoom=4)

class LiveDisplay(CameraDisplay):
  """Provides a window to display acquired images. Work as a video display if the acquisition mode is Video."""
  def __init__(self, cam, zoom=1, tk_window=None, imagemode="L"):
    self._cam = cam
    super(LiveDisplay, self).__init__(self._cam.Detector.width, self._cam.Detector.height,
				      zoom, tk_window, imagemode)
    self.delay = 100 # live refresh rate, in ms.
    self.live = False
    self.wheel = ('-',"\\",'|','/')
    self.count = 0
    self.last_image_read = None
    
    self.dyn = 2**self._cam.Detector.bit_depth - 1 # dynamic range
    
    self.rescale(None, None) # Full dynamic range display

  def rescale(self, min, max):
    """Tuple: (min, max) that rescales the pixel amplitudes to lie between min and max."""
    self._rescale = (0 if min is None else min, self.dyn if max is None else max)
  
  @if_new_data_ready
  def update(self):
    self.imdata=np.int64(self._cam.Acquire.Newest(type=32)) # need 32 bits for the rescaling operation
    self.last_image_read = self._cam.Acquire.images_in_buffer['last']
    expo = self._cam.exposure
    rescaled_data = (((self.imdata - self._rescale[0])*self.dyn)/(self._rescale[1]-self._rescale[0]))/(2**(self._cam.Detector.bit_depth-8))
    self.rescaled_data = rescaled_data
    self.set_image(np.uint8(rescaled_data.clip(0, 255)))
    self.show()
    self.title('Andor | Max: {max: >4d} | Exposure: {exp: 3.4f} ms | Image #{imgno: >5d}({wheel:s})'.format(max=self.imdata.max(), exp=expo, wheel=self.wheel[self.count % 4], imgno=self._cam.Acquire.images_in_buffer['last']))

  def start(self):
    """ Start live display."""
       # Make sure the refresh rate is shorter than the exposure time
       # if expo > self.live_delay:
       #   delay_next = expo
       # else:
       #   delay_next = self.live_delay
    self.update()
    self.count = self.count + 1
    self.callback_id = self._window.after(int(self.delay), self.start)
    self.live = True

  def stop(self):
    """ Stop live display."""
    self._window.after_cancel(self.callback_id)
    self.live = False
    
  @property
  def zoom(self):
    return self._zoom
    
  @zoom.setter
  def zoom(self, zoom):
    #self._cam.Display = LiveDisplay(self._cam, zoom=zoom, tk_window=self._window, imagemode="L")
    self._zoom = zoom
    
  def plot_histogram(self):
    self.histogram = Histogram(self._cam)
    self.histogram.start()


# Could make this more general by telling user to subclass it and provide its own update(). Would need to 
# pass ntracks and npoints to constructor too, which is OK

class CustomToolbar(NavigationToolbar2TkAgg):
  """matplotlib toolbar with extra buttons for:
    1. toggle live display
    2. That's all!
    """
  # Just add a tuple (Name, Tooltip, Icon, Method) to toolitems to set more buttons.
  def __init__(self, canvas_, parent_, toggle):
    self.toolitems = super(CustomToolbar, self).toolitems + (('Live', 'Toggle live display', 'stock_refresh', 'toggle'),)
    self.toggle = toggle
    super(CustomToolbar, self).__init__(canvas_, parent_)
    

class LivePlot(object):
  """Provides a window to display 1D data (such as profiles across images or when in Single-Track/FVB acquisition mode).
  
  To use it you must either
    1) Provide a function to the data_func keyword argument, or
    2) Sub-class LivePlot and define a get_data() method.
  Both data_func and get_data must return a 2D array od dimensions (ntracks, npoints).
  
  In addition, the following methods can be overriden if necessary:
    - init_plot
    - if_new_data_ready
    - title
  
  All tracks will be displayed in the same plot.
  Use start() to update the plot automatically (every 100ms by default, settable via the delay property).
  """
  def __init__(self, cam, ntracks, npoints, data_func=None):
    """Create a pyplot window and initialise the plot with zeros.
    
    Arguments:
    - cam: a reference to the top-level AndorUI object.
    """
    self.window = tk.Tk()
    self._cam = cam
    self.data_func = data_func
    # Create figure
    plt.ion()
    self._init_app()
    self.init_fig(ntracks, npoints)
    # Stuff for live updating
    self.delay = 100 # refresh rate, in ms.
    self.live = False
    self._wheel = ('-',"\\",'|','/')
    self.count = 0
    self._if_new_data_ready_counter = 0
    self.last_image_read = None
    
  def _init_app(self):
    self.figure = mpl.figure.Figure()
    self.ax = self.figure.add_subplot(111)
    self.canvas = FigureCanvasTkAgg(self.figure, self.window)
    self.toolbar = CustomToolbar(self.canvas, self.window, self.toggle)
    self.toolbar.update()
    self.widget = self.canvas.get_tk_widget()
    self.widget.pack(side=tk.TOP, fill=tk.BOTH, expand=1)
    self.toolbar.pack(side=tk.TOP, fill=tk.BOTH, expand=1)
    self.canvas.show()
    
  #def if_new_data_ready(self, update_func):
    #"""Wrapper for the plot update() method that will prevent it from updating if there is no new data."""
    ## This is both for performance purpose and to avoid the "DRV_NO_NEW_DATA" error that
    ## may arise if the Video acquisition is restarted while the display is live.
    #self._if_new_data_ready_counter += 1
    #def inner(*args, **kwargs):
      #if (self._cam.Acquire.status[1] is "DRV_ACQUIRING") and (self._cam.Acquire.images_in_buffer['last'] is not self.last_image_read):
        #try:
          #update_func(*args, **kwargs)
        #except AndorError as error:
          #if error.string is not "DRV_NO_NEW_DATA": # ignore this error; occurs when changing exposure on the fly.
            #raise error
	  #else:
	    #pass
    #return inner
        
  def init_fig(self, ntracks, npoints):
    """Initialise figure with n tracksof n points each."""
    self.ntracks = ntracks
    self.npoints = npoints
    for i in range(self.ntracks):   # create as many line plots as lines in the data set (eg, 2 if there are two tracks
      self.ax.plot(np.arange(1, self.npoints+1), np.zeros(shape=self.npoints))
      
  def title(self):
    """A title string for the plot window"""
    return 'Andor | {mode} profile | Exposure: {exp: 3.2f} ms | Image #{imgno: >5d}'.format(mode=self._cam.ReadMode.current._name,
											    exp=self._cam.exposure,
											    imgno=self._cam.Acquire.images_in_buffer['last'])
  
  @if_new_data_ready
  def update(self):
    """Update the live plot."""
    #if self._cam.Acquire.status[1] is "DRV_ACQUIRING": # do not refresh plot if no new data is coming in
    self.last_image_read = self._cam.Acquire.images_in_buffer['last']
    self.data = self.get_data()
    for i, line in enumerate(self.ax.lines):
      line.set_ydata(self.data[i]) # update ydata of each line
    self.window.title(self.title())
    self.canvas.draw()

  def get_data(self):
    """Specifies how to get the data to be plotted.
    
    It must either be overidden by subclasses or provided to the object constructor kwarg "data_func".
    """
    if data_func is None:
      raise NotImplementedError
    else:
      return self.data_func()

  def start(self):
    """Start live updating of the plot."""
    #self.if_new_data_ready(self.update())
    self.update()
    self.callback_id = self.widget.after(int(self.delay), self.start)
    self.live = True
    self.count += 1
    
  def stop(self):
    """Stop live updating."""
    self.widget.after_cancel(self.callback_id)
    self.live = False
    
  def toggle(self):
    """Toggle live updating."""
    if self.live:
      self.stop()
    else:
      self.start()
    
  def __del__(self):
    self.stop()
    
    
class TrackPlot(LivePlot):
  """Provides a window to display Single-Track, Multi-Track and FVB data.
  
  All tracks will be displayed in the same plot.
  Use start() to update the plot automatically (every 100ms by default, settable via the delay property).
  """
  def __init__(self, cam):
    self._cam = cam
    if cam.ReadMode.current.ndims > 1:
      self.ntracks = cam.ReadMode.current.shape[0]
      self.npoints = cam.ReadMode.current.shape[1]
    else:
      self.ntracks = 1
      self.npoints = cam.ReadMode.current.shape[0]
    super(TrackPlot, self).__init__(cam, self.ntracks, self.npoints)
    self.ax.set_ylim(1, 2**cam.Detector.bit_depth) # do not set lower ylim to 0 to use log scale
    self.ax.set_xlim(0, self.npoints + 1)
    self.ax.set_xlabel("pixels")
    self.offset = 0
    self.transform = lambda x:x
    
  def get_data(self):
    """Return the latest available data for plotting."""
    self.last_image_read = self._cam.Acquire.images_in_buffer['last']
    if self.ntracks == 1:
      return [self.transform(self._cam.Acquire.Newest()) - self.offset] 
    else:
      return self.transform(self._cam.Acquire.Newest()) - self.offset

  def title(self):
    """A title string for the plot window"""
    return 'Andor track | Exp: {exp: 3.2f} ms | max: {m: >5d} | Image #{imgno: >5d}'.format(mode=self._cam.ReadMode.current._name,
											    exp=self._cam.exposure, m=self.data[0].max(),
											    imgno=self._cam.Acquire.images_in_buffer['last'])
    
class ImageProfile(LivePlot):
  """Provides a plot to display profiles from the image display.
  
  NOT IMPLEMENTED
  """ 
  def __init__(self):
    pass
  
class Histogram(LivePlot):
  def __init__(self, cam, pixels_per_bin):
    super(Histogram, self).__init__(cam, 1, cam.Display.dyn/pixels_per_bin, data_func=None)
    self._pixels_per_bin = pixels_per_bin
    
  def get_data(self):
    return np.histogram(self._cam.Display.imdata, 
			bins=self._cam.Display.dyn/self.pixels_per_bin, 
			range=(0, self._cam.Display.dyn))

  def __repr__(self):
    return "Andor image histogram, " + str(self._pixels_per_bin) + " pixels per bins."

  @property
  def pixels_per_bin(self):
    return self._pixels_per_bin
  @pixels_per_bin.setter
  def pixels_per_bin(self, value):
    self.init_fig(1, self._cam.Display.dyn/value)
    self._pixels_per_bin = value

class XYProfiles(LivePlot):
  """Plots X and Y profiles of the image."""
  def __init__(self, cam):
    self._cam = cam
    self._xlim = (1, self._cam.ReadMode.current.shape[0])
    self._ylim = (1, self._cam.ReadMode.current.shape[1])
    self.offset = (0,0)
    super(XYProfiles, self).__init__(cam, cam.ReadMode.current.shape[0], cam.ReadMode.current.shape[1], data_func=None)
  
  def init_fig(self, dummx, dummy):  # need special init_fig as both axis may have different dimensions
    # Initialise figure
    self.xdim = self.xlim[1] - self.xlim[0] + 1
    self.ydim = self.ylim[1] - self.ylim[0] + 1
    self.ax.set_ylim(0, 2**self._cam.Detector.bit_depth)
    self.ax.lines = []
    for dim in [self.xdim, self.ydim]:
      self.ax.plot(np.arange(1, dim+1), np.zeros(shape=dim))
  
  @property
  def xlim(self):
	  return self._xlim
  @xlim.setter
  def xlim(self, startstop):
    self.stop()
    self._xlim = startstop
    self.init_fig(None, None)
    self.start()
    
  @property
  def ylim(self):
	  return self._ylim
  @ylim.setter
  def ylim(self, startstop):
    self.stop()
    self._ylim = startstop
    self.init_fig(None, None)
    self.start()
  
  def get_data(self):
    data = self._cam.Display.imdata[self.xlim[0]-1:self.xlim[1], self.ylim[0]-1:self.ylim[1]]
    return [data.sum(1)/self.xdim-self.offset[0], data.sum(0)/self.ydim - self.offset[1]]
