from distutils.core import setup, Extension
from Cython.Distutils import build_ext
import numpy

classifiers = [
    'Development Status :: 4 - Beta'
    'Environment :: Console'
    'Intended Audience :: Science/Research'
    'License :: OSI Approved :: MIT License'
    'Natural Language :: English'
    'Operating System :: POSIX :: Linux'
    'Programming Language :: C'
    'Programming Language :: Cython'
    'Programming Language :: Python :: 3.5'
    'Topic :: Home Automation'
    'Topic :: Scientific/Engineering'
]

cyandor = Extension("andor",
		   sources = ["andor.pyx"],
		   library_dirs = ['.','usr/local/lib'],
		   include_dirs = ['.', '..', numpy.get_include(),'/usr/lib64/python/site-packages/Cython/Includes'],
		   libraries = ['andor'])

setup(
    name = 'andor',
    version = '1.0',
    description = 'Object-oriented interface for Andor EMCCD cameras',
    author = 'Guillaume Lepert',
    author_email = 'guillaume.lepert07@imperial.ac.uk',
    long_description="""An object-oriented, high-level interface for Andor cameras.

Includes live display for camera images and spectra/profiles.
    """,
    url="",
    cmdclass={'build_ext': build_ext},
    ext_modules = [cyandor],
    py_modules = ['andorgui', 'camdisp'],
    requires=['numpy', 'cython', 'matplotlib', 'h5py'],
    platforms=['linux']
    
)

