import re
import os
import shutil

import numpy as np
import pandas as pd
from scipy import interpolate


class Colorbrewer:
    url = 'https://colorbrewer2.org/export/colorbrewer.json'
    _input_scale = 255
    _p = re.compile(r'rgb\(([0-9]+),([0-9]+),([0-9]+)\)')

    def __init__(self):
        self.df = pd.read_json(self.url)

    def to_dict(self, output_num=256):
        d = {}
        for name in self.df.columns:
            d[name] = self._get_array(name, output_num)
        return d

    def to_csv(self, output_num=256, output_scale=65535):
        d = self.to_dict(output_num)
        for name, arr in d.items():
            x = np.empty_like(arr, dtype=int)
            np.clip(arr * output_scale / self._input_scale, 0, output_scale,
                    out=x)
            np.savetxt(name+'.csv', x, fmt='%d', delimiter=',')

    def _get_array(self, name: str, num: int) -> np.ndarray:
        """Extract rgb colors of a table specfied by the name as 
        an ndarray from the DataFrame.
        """
        for i in range(3, 13):
            if not isinstance(self.df.at[str(i), name], float):
                continue
            # This is the longest list of the color scale.
            # The list is like ['rgb(158,1,66)', 'rgb(213,62,79)', ...]
            list_rgb = self.df.at[str(i-1), name]
            break
        else:
            list_rgb = self.df.at[str(i), name]

        # Convert strings in the list to tuples of int.
        # 'rgb(158,1,66)' -> (158,1,66)
        list_int = list(
            map(lambda x: tuple(map(int, self._p.findall(x)[0])), list_rgb)
        )

        # arr[:,0], arr[:,1], and arr[:,2] are r, g, and b, respectively
        arr = np.array(list_int)

        # If the table is qualitativee, return the array without interplating
        if c.df.at['type', name] == 'qual':
            return arr

        # If the table is sequential, diverging, or cyclic, return
        # an interpolated array.
        x = np.linspace(0, arr.shape[0], arr.shape[0], endpoint=False)
        x2 = np.linspace(np.min(x), np.max(x), num)
        arr_interp = [interpolate.PchipInterpolator(x, arr.T[i])(x2)
                      for i in range(arr.shape[1])]
        return np.array(arr_interp).T


if __name__ == "__main__":
    c = Colorbrewer()
    files = c.to_csv()

    destination = {
        'seq': '0_Sequential/',
        'div': '1_Diverging/',
        'qual': '2_Qualitative/',
    }

    for dest in destination.values():
        os.makedirs(dest, exist_ok=True)

    for name in c.df.columns:
        table_type = c.df.at['type', name]
        shutil.move(name+'.csv', destination[table_type])
