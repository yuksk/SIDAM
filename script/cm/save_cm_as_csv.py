import os

import cmcrameri
import numpy as np
import matplotlib.cm as cm
from matplotlib.colors import Normalize

def save_colormap_as_csv(name, num):
    cmap = cm.get_cmap(name)
    rgba = cmap(Normalize()(list(range(num))))
    rgb = np.delete(rgba, 3, 1) * 65535
    np.savetxt(name+'.csv', rgb, fmt='%d', delimiter=',')

# https://matplotlib.org/3.1.0/gallery/color/colormap_reference.html
matplotlib_cmaps = {
    '0_Perceptually_Uniform_Seq': {
        'viridis': 256,
        'plasma': 256,
        'inferno': 256,
        'magma': 256,
        'cividis': 256,
        },
    '1_Sequential': {
        'Greys': 256,
        'Purples': 256,
        'Blues': 256,
        'Greens': 256,
        'Oranges': 256,
        'Reds': 256,
        'YlOrBr': 256,
        'YlOrRd': 256,
        'OrRd': 256,
        'PuRd': 256,
        'RdPu': 256,
        'BuPu': 256,
        'GnBu': 256,
        'PuBu': 256,
        'YlGnBu': 256,
        'PuBuGn': 256,
        'BuGn': 256,
        'YlGn': 256,
        },
    '2_Sequential2': {
        'binary': 256,
        'gist_yarg': 256,
        'gist_gray': 256,
        'gray': 256,
        'bone': 256,
        'pink': 256,
        'spring': 256,
        'summer': 256,
        'autumn': 256,
        'winter': 256,
        'cool': 256,
        'Wistia': 256,
        'hot': 256,
        'afmhot': 256,
        'gist_heat': 256,
        'copper': 256,
        },
    '3_Diverging': {
        'PiYG': 256,
        'PRGn': 256,
        'BrBG': 256,
        'PuOr': 256,
        'RdGy': 256,
        'RdBu': 256,
        'RdYlBu': 256,
        'RdYlGn': 256,
        'Spectral': 256,
        'coolwarm': 256,
        'bwr': 256,
        'seismic': 256,
        },
    '4_Cyclic': {
        'twilight': 256,
        'twilight_shifted': 256,
        'hsv': 256,
        },
    '5_Qualitative': {
        'Pastel1': 9,
        'Pastel2': 8,
        'Paired': 12,
        'Accent': 8,
        'Dark2': 8,
        'Set1': 9,
        'Set2': 8,
        'Set3': 12,
        'tab10': 10,
        'tab20': 20,
        'tab20b': 20,
        'tab20c': 20,
       },
    '6_Miscellaneous': {
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
        'brg': 256,
        'gist_rainbow': 256,
        'rainbow': 256,
        'jet': 256,
        'nipy_spectral': 256,
        'gist_ncar': 256,
        }
}

# version 7
crameri_cmaps = {
    '0_Sequential': [
        'batlow', 'batlowW', 'batlowK', 'devon', 'lajolla', 'bamako', 'davos',
        'bilbao', 'nuuk', 'oslo', 'grayC', 'hawaii', 'lapaz', 'tokyo', 'buda',
        'acton', 'turku', 'imola',
    ],
    '1_Diverging':[
        'broc', 'cork', 'vik', 'lisbon', 'tofino', 'berlin', 'roma', 'bam',
        'vanimo',
    ],
    '2_MultiSequential': [
        'oleron', 'bukavu', 'fes',
    ],
    '3_Cyclic': [
        'romaO', 'bamO', 'brocO', 'corkO', 'vikO',
    ],
    '4_Categorical': [
         'actonS', 'bamakoS', 'batlowS', 'bilbaoS', 'budaS', 'davosS',
         'devonS', 'grayCS', 'hawaiiS', 'imolaS', 'lajollaS', 'lapazS',
         'nuukS', 'osloS', 'tokyoS', 'turkuS',
    ],
}

if __name__ == "__main__":
    # matplotlib
    os.makedirs('matplotlib_colormaps', exist_ok=True)
    os.chdir('matplotlib_colormaps')

    for dirname in matplotlib_cmaps:
        os.makedirs(dirname, exist_ok=True)
        os.chdir(dirname)
        for name, num in matplotlib_cmaps[dirname].items():
            save_colormap_as_csv(name, num)
        os.chdir('..')

    os.chdir('..')

    # cmcrameri
    os.makedirs('cmcrameri', exist_ok=True)
    os.chdir('cmcrameri')

    pathstr = str(cmcrameri.cm.paths[0].parent) + '/'
    for dirname, cmlist in crameri_cmaps.items():
        os.makedirs(dirname, exist_ok=True)
        os.chdir(dirname)
        for name in cmlist:
            np.savetxt(name+'.csv', np.loadtxt(pathstr+name+'.txt') * 65535,
                       fmt='%d', delimiter=',')
        os.chdir('..')

