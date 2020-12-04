#!/usr/bin/env python
# coding: utf-8

import os
import numpy as np
import matplotlib.cm as cm
from matplotlib.colors import Normalize

def save_colormap_as_csv(name, N=256):
    cmap = cm.get_cmap(name)
    rgba = cmap(Normalize()(list(range(N))))
    rgb = np.delete(rgba, 3, 1) * 65535
    np.savetxt(name+'.csv', rgb, fmt='%d', delimiter=',')

# https://matplotlib.org/3.1.0/gallery/color/colormap_reference.html
cmaps = [('0_Perceptually_Uniform_Seq', [
            'viridis', 'plasma', 'inferno', 'magma', 'cividis']),
         ('1_Sequential', [
            'Greys', 'Purples', 'Blues', 'Greens', 'Oranges', 'Reds',
            'YlOrBr', 'YlOrRd', 'OrRd', 'PuRd', 'RdPu', 'BuPu',
            'GnBu', 'PuBu', 'YlGnBu', 'PuBuGn', 'BuGn', 'YlGn']),
         ('2_Sequential2', [
            'binary', 'gist_yarg', 'gist_gray', 'gray', 'bone', 'pink',
            'spring', 'summer', 'autumn', 'winter', 'cool', 'Wistia',
            'hot', 'afmhot', 'gist_heat', 'copper']),
         ('3_Diverging', [
            'PiYG', 'PRGn', 'BrBG', 'PuOr', 'RdGy', 'RdBu',
            'RdYlBu', 'RdYlGn', 'Spectral', 'coolwarm', 'bwr', 'seismic']),
         ('4_Cyclic', ['twilight', 'twilight_shifted', 'hsv']),
         ('5_Qualitative', [
            'Pastel1', 'Pastel2', 'Paired', 'Accent',
            'Dark2', 'Set1', 'Set2', 'Set3',
            'tab10', 'tab20', 'tab20b', 'tab20c'], [
             9, 8, 12, 8,
             8, 9, 8, 12,
             10, 20, 20, 20]),
         ('6_Miscellaneous', [
            'flag', 'prism', 'ocean', 'gist_earth', 'terrain', 'gist_stern',
            'gnuplot', 'gnuplot2', 'CMRmap', 'cubehelix', 'brg',
            'gist_rainbow', 'rainbow', 'jet', 'nipy_spectral', 'gist_ncar'])]

# The following try clause warks as "mkdir -p"
try:
    os.mkdir('matplotlib_colormaps')
except FileExistsError:
    pass
os.chdir('matplotlib_colormaps')

for group in cmaps[:]:
    os.mkdir(group[0])
    os.chdir(group[0])

    if len(group) > 2:
        for name, num in zip(group[1], group[2]):
            save_colormap_as_csv(name, num)
    else:
        for name in group[1]:
            save_colormap_as_csv(name)

    os.chdir('..')
