from setuptools import setup, Extension

# from distutils.core import setup
#from distutils.extension import Extension
#from Cython.Build import cythonize
#from Cython.Distutils import build_ext

# extensions = cythonize([
#     Extension("Andor.andorSDK", ["Andor/andorSDK.pyx","Andor/atmcdLXd.pxd"],
#               libraries = ['andor']),
#     Extension("Shamrock.shamrockSDK", ["Shamrock/shamrockSDK.pyx", "Shamrock/ShamrockCIF.pxd"],
#               libraries=['shamrockcif'])
#     ])
#
#
# setup(
#   name = 'Andor',
#   requires = ['numpy(>=1.7.0)', 'cython(>=0.23)'],
#   cmdclass = {'build_ext ': build_ext},
#   ext_modules = extensions,
#   #setup_requires=['setuptools>=18.0','Cython>=0.23'],
#   #install_requires=['numpy>=1.7.0','Cython>=0.23'],
#   packages=['Andor','Shamrock','AndorSpectrometer']
# )

setup(name='Andor',
      packages=['Andor', 'Shamrock', 'AndorSpectrometer'],
      package_dir={'Andor': 'Andor','Shamrock': 'Shamrock','AndorSpectrometer': 'AndorSpectrometer'},
      package_data={
          'Andor': ['atmcdLXD.pxd'],
          'Shamrock': ['ShamrockCIF.pxd']},
      description='Python binding for Andor SDK',
      author='Simon Dickreuter',
      author_email='Simon.Dickreuter@uni-tuebingen.de',
      license='GNU LGPL',
      #url='',
      setup_requires=[
          'setuptools>=28.3',
          'Cython>=0.24'
      ],
      install_requires=[
          'numpy>=1.11',
          'Cython>=0.24'
      ],
      ext_modules=[
      #  Extension("Andor.andorSDK", ["Andor/c_andorSDK.c","Andor/andorSDK.pyx"],
      #         libraries = ['andor']),
      #  Extension("Shamrock.shamrockSDK", ["Shamrock/c_shamrockSDK.c","Shamrock/shamrockSDK.pyx"],
      #         libraries=['shamrockcif'])
      Extension("Andor.andorSDK", ["Andor/andorSDK.pyx"],
                libraries=['andor']),
      Extension("Shamrock.shamrockSDK", ["Shamrock/shamrockSDK.pyx"],
                libraries=['shamrockcif'])
      ]
)
