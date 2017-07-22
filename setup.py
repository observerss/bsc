from os import walk
from os.path import dirname, join
from setuptools import Extension, setup
from Cython.Build import cythonize


bsc_path = join(dirname(__file__), 'bsc')
libbsc_path = join(dirname(__file__), 'bsc', 'libbsc')

libbsc_sources = []
for root, dirs, names in walk('bsc/libbsc'):
    for name in names:
        if name == 'bsc.cpp':
            continue
        if name.endswith('.cpp') or name.endswith('.c'):
            libbsc_sources.append(join(root, name))


bsc_ext = Extension(
    name="bsc._bsc",
    sources=["bsc/_bsc.pyx"] + libbsc_sources,
    include_dirs=[bsc_path, libbsc_path],
    extra_compile_args=[
        '-DLIBBSC_SORT_TRANSFORM_SUPPORT',
        '-fomit-frame-pointer',
        '-fstrict-aliasing',
        '-ffast-math',
        '-O3',
    ],
)


setup(name='bsc',
      version='0.1.2',
      description='Python binding for libbsc, a fast yet capable compressor',
      author='Jingchao Hu',
      author_email='jingchaohu@gmail.com',
      url='http://github.com/observerss/bsc',
      packages=['bsc'],
      package_data={'bsc': ['*.pyx', '*.h', '*.cuh', '*.cpp', '*.c']},
      # include_package_data=True,
      install_requires=['cython'],
      python_requires='>=3.5',
      ext_modules=cythonize([bsc_ext]),
      classifiers=[
          'Development Status :: 4 - Beta',
          'Intended Audience :: Developers',
          'Topic :: System :: Archiving :: Compression',
          'License :: OSI Approved :: MIT License',
          'Programming Language :: Python :: 3',
      ]
      )
