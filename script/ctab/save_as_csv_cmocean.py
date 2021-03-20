import os
import urllib.request
import zipfile

import numpy as np

download_url = 'https://github.com/matplotlib/cmocean/archive/refs/heads/master.zip'
filename = 'master.zip'

data = urllib.request.urlopen(download_url).read()
with open(filename, mode="wb") as f:
    f.write(data)

# Unzip the downloaded file, and a folder named "cmocean-master" is
# created.
with zipfile.ZipFile(filename) as existing_zip:
    existing_zip.extractall('.')

cmaps = {
    '0_Sequential': [
        'thermal', 'haline', 'solar', 'ice', 'gray', 'deep', 'dense', 'algae',
        'matter', 'turbid', 'speed', 'amp', 'tempo', 'rain',
    ],
    '1_MultiSequential': [
        'topo',
    ],
    '2_Diverging': [
        'oxy', 'balance', 'diff', 'tarn'
    ],
    '3_Diverging2': [
        'curl', 'delta',
    ],
    '4_Cyclic': [
        'phase',
    ],
}

base = 'cmocean-master/cmocean/rgb'
output_scale = 65535

for group in cmaps:
    os.makedirs(group, exist_ok=True)

for group, clrs in cmaps.items():
    for clr in clrs:
        a = np.loadtxt(f'{base}/{clr}-rgb.txt')
        np.savetxt(f'{group}/{clr}.csv',
                   np.clip(a*output_scale,0,output_scale),
                   fmt='%d', delimiter=',')
