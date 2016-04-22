from distutils.core import setup
from distutils.extension import Extension
from Cython.Build import cythonize
from Cython.Distutils import build_ext


extensions = cythonize([
    Extension("Andor.camera", ["Andor/andorSDK.pyx","Andor/atmcdLXd.pxd"],
              libraries = ['andor']),
    Extension("Shamrock.spectrograph", ["Shamrock/shamrockSDK.pyx", "Shamrock/ShamrockCIF.pxd"],
              libraries=['shamrockcif'])
    ])


setup(
  name = 'Andor',
  cmdclass = {'build_ext': build_ext},
  packages=['Andor','Shamrock'],
  ext_modules = extensions
)


