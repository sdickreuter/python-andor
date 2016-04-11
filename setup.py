from distutils.core import setup
from distutils.extension import Extension
from Cython.Build import cythonize
from Cython.Distutils import build_ext


extensions = cythonize([
    Extension("Andor.camera", ["Andor/camera.pyx","Andor/atmcdLXd.pxd"],
              libraries = ['andor'])
    ])


setup(
  name = 'Andor',
  cmdclass = {'build_ext': build_ext},
  packages=['Andor'],
  ext_modules = extensions
)


