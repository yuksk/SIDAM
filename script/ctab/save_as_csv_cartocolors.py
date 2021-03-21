import re
import os
import shutil

import requests
import numpy as np
import pandas as pd
from scipy import interpolate


class CartoColors:
    url = 'https://raw.githubusercontent.com/CartoDB/CartoColor/master/cartocolor.js'
    _input_scale = 255

    def __init__(self):
        data = requests.get(self.url)
        # clean the beginning
        text = re.sub(r'^.*?= ', '', data.text, flags=re.S)
        # clean the ending
        text = re.sub(r';.*?var colorbrewer_tags.*', '', text, flags=re.S)
        self.df = pd.read_json(text)

    def to_dict(self, output_num=256):
        d = {}
        for name in self.df.columns:
            d[name] = self._get_array(name, output_num)
        return d

    def to_csv(self, output_num=256, output_scale=65535):
        d = self.to_dict(output_num)
        for name, arr in d.items():
            x = np.clip(arr * output_scale / self._input_scale, 0, output_scale)
            np.savetxt(name+'.csv', x, fmt='%d', delimiter=',')

    def _get_array(self, name, num):
        for i in range(2, 12):
            if not isinstance(self.df.at[str(i), name], float):
                continue
            # This is the longest list of the color scale.
            # The list is like ['#e4f1e1', '#b4d9cc', ...]
            list_hex = self.df.at[str(i-1), name]
            break
        else:
            list_hex = self.df.at[str(i), name]

        # Convert hex to rgb
        # ['#e4f1e1', '#b4d9cc', ...] -> [(228, 241, 225), (180, 217, 204), ...]
        list_int = map(
            lambda h: tuple(int(h.lstrip('#')[i:i+2], 16) for i in (0, 2, 4)),
            list_hex
        )

        # arr[:,0], arr[:,1], and arr[:,2] are r, g, and b, respectively
        arr = np.array(list(list_int))

        # If the table is qualitative, return the array without interpolating
        if 'qualitative' in self.df.at['tags', name]:
            return arr

        # If the table is sequantial (quantitative) or diverging, return
        # an interpolated array.
        x = np.linspace(0, arr.shape[0], arr.shape[0], endpoint=False)
        x2 = np.linspace(np.min(x), np.max(x), num)
        arr_interp = [interpolate.PchipInterpolator(x, arr.T[i])(x2)
                      for i in range(arr.shape[1])]
        return np.array(arr_interp).T


if __name__ == '__main__':
    c = CartoColors()
    files = c.to_csv()

    destination = {
        'quantitative': '0_Sequential/',
        'aggregation': '0_Sequential/',
        'diverging': '1_Diverging/',
        'qualitative': '2_Qualitative/',
    }

    for dest in destination.values():
        os.makedirs(dest, exist_ok=True)

    for name in c.df.columns:
        table_type = c.df.at['tags', name][0]
        shutil.move(name+'.csv', destination[table_type])

