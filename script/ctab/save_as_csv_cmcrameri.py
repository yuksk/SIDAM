import os
import urllib.request
import zipfile

import numpy as np

download_url = 'https://zenodo.org/record/4491293/files/ScientificColourMaps7.zip?download=1'
filename = 'SCM7.zip'

data = urllib.request.urlopen(download_url).read()
with open(filename, mode="wb") as f:
    f.write(data)

# Unzip the downloaded file, and a folder named "ScientificColourMaps7" is
# created.
with zipfile.ZipFile(filename) as existing_zip:
    existing_zip.extractall('.')

cmaps = {
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

base = './ScientificColourMaps7'
output_scale = 65535

for group in cmaps:
    os.makedirs(group, exist_ok=True)

for group, clrs in cmaps.items():
    if group == '4_Categorical':
        continue

    for clr in clrs:
        a = np.loadtxt(f'{base}/{clr}/{clr}.txt')
        np.savetxt(f'{group}/{clr}.csv',
                   np.clip(a*output_scale,0,output_scale),
                   fmt='%d', delimiter=',')

        catpal = f'{base}/{clr}/CategoricalPalettes'
        if os.path.isdir(catpal):
            a = np.loadtxt(f'{catpal}/{clr}S.txt')
            np.savetxt(f'4_Categorical/{clr}S.csv',
                       np.clip(a*output_scale,0,output_scale),
                       fmt='%d', delimiter=',')
