from distutils.core import setup
from distutils.extension import Extension
from Cython.Build import cythonize
from Cython.Distutils import build_ext


extensions = cythonize([
    Extension("Andor.andorSDK", ["Andor/andorSDK.pyx","Andor/atmcdLXd.pxd"],
              libraries = ['andor']),
    Extension("Shamrock.shamrockSDK", ["Shamrock/shamrockSDK.pyx", "Shamrock/ShamrockCIF.pxd"],
              libraries=['shamrockcif'])
    ])


setup(
  name = 'Andor',
  cmdclass = {'build_ext': build_ext},
  packages=['Andor','Shamrock','AndorSpectrometer'],
  ext_modules = extensions
)


