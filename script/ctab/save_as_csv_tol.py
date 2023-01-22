import os
import urllib.request

import numpy as np
import matplotlib.cm as cm
from matplotlib.colors import Normalize, to_rgba_array


def download_file():
    download_url = 'https://personal.sron.nl/~pault/data/tol_colors.py'
    filename = 'tol_colors.py'
    data = urllib.request.urlopen(download_url).read()
    with open(filename, mode="wb") as f:
        f.write(data)

cmaps = {
    'sunset_discrete': 11,
    'sunset': 256,
    'nightfall_discrete': 9,
    'nightfall': 256,
    'BuRd_discrete': 9,
    'BuRd': 256,
    'PRGn_discrete': 9,
    'PRGn': 256,
    'YlOrBr_discrete': 9,
    'YlOrBr': 256,
    'WhOrBr': 256,
    'iridescent': 256,
    'rainbow_PuRd': 256,
    'rainbow_PuBr': 256,
    'rainbow_WhRd': 256,
    'rainbow_WhBr': 256,
    'rainbow_discrete': 29,
}

csets = ['bright', 'high-contrast', 'vibrant', 'muted',
    'medium-contrast', 'light']

def save_colormap_as_csv(name, num):
    cmap = tol.tol_cmap(name)
    rgba = cmap(Normalize()(list(range(num))))
    rgb = np.delete(rgba, 3, 1) * 65535
    np.savetxt(name+'.csv', rgb, fmt='%d', delimiter=',')

def save_colorset_as_csv(name):
    cmap = tol.tol_cset(name)
    rgba = to_rgba_array(list(cmap))
    rgb = np.delete(rgba, 3, 1) * 65535
    rgb = np.delete(rgb, -1, 0)  # somehow (0,0,0) at the end
    np.savetxt(name+'.csv', rgb, fmt='%d', delimiter=',')

if __name__ == "__main__":
    download_file()
    import tol_colors as tol

    os.makedirs('0_maps', exist_ok=True)
    os.chdir('0_maps')
    for name, num in cmaps.items():
        save_colormap_as_csv(name, num)
    os.chdir('..')

    os.makedirs('1_sets', exist_ok=True)
    os.chdir('1_sets')
    for name in csets:
        save_colorset_as_csv(name)
    os.chdir('..')