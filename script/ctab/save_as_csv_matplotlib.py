import os

import numpy as np
import matplotlib.cm as cm
from matplotlib.colors import Normalize

# https://matplotlib.org/stable/gallery/color/colormap_reference.html
cmaps = {
    '0_Perceptually_Uniform_Seq': {
        'viridis': 256,
        'plasma': 256,
        'inferno': 256,
        'magma': 256,
        'cividis': 256,
        },
    '1_Sequential': {
        #'binary': 256,		# reverse of Gray256
        #'gist_yarg': 256,	# reverse of Gray256
        #'gist_gray': 256,	# same as Gray256
        #'gray': 256,		# same as Gray256
        'bone': 256,
        'pink': 256,
        'spring': 256,
        'summer': 256,
        'autumn': 256,
        'winter': 256,
        #'cool': 256,		# same as CyanMagenta
        'Wistia': 256,
        'hot': 256,
        'afmhot': 256,
        'gist_heat': 256,
        'copper': 256,
        },
    '2_Diverging': {
        'coolwarm': 256,
        #'bwr': 256,	# reverse of RedWhiteBlue256
        'seismic': 256,
        },
    '3_Cyclic': {
        'twilight': 256,
        'twilight_shifted': 256,
        'hsv': 256,
        },
    '4_Qualitative': {
        'tab10': 10,
        'tab20': 20,
        'tab20b': 20,
        'tab20c': 20,
       },
    '5_Miscellaneous': {
        'flag': 256,
        'prism': 256,
        'ocean': 256,
        'gist_earth': 256,
        'terrain': 256,
        'gist_stern': 256,
        'gnuplot': 256,
        'gnuplot2': 256,
        'CMRmap': 256,
        'cubehelix': 256,
        #'brg': 256,		# same as BlueRedGreen256
        'gist_rainbow': 256,
        'rainbow': 256,
        'jet': 256,
        #'turbo': 256,		# same as Turbo
        'nipy_spectral': 256,
        'gist_ncar': 256,
        }
}


def save_colormap_as_csv(name, num):
    cmap = cm.get_cmap(name)
    rgba = cmap(Normalize()(list(range(num))))
    rgb = np.delete(rgba, 3, 1) * 65535
    np.savetxt(name+'.csv', rgb, fmt='%d', delimiter=',')


if __name__ == "__main__":
    for dirname in cmaps:
        os.makedirs(dirname, exist_ok=True)
        os.chdir(dirname)
        for name, num in cmaps[dirname].items():
            save_colormap_as_csv(name, num)
        os.chdir('..')


