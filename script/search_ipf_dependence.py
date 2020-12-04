#!/usr/bin/env python
# coding: utf-8

import os
import re
import pathlib
import concurrent.futures as confu

BASE = '../src/SIDAM/func/'

class IgorProcedureFile:

    def __init__(self, filepath):
        self.__filepath = filepath
        self.__module_name = ''
        self.functions = []
        self.include = []       # files in the include statement
        self.used = []          # files where this ipf is already included
        self.required = []      # files where this ipf needs to be included
        self.require = []       # files necessary to be included
        self.unnecessary = []   # files included but no longer necessary

        with open(filepath, 'r') as f:
            content = f.read()

        self.__find_module_name(content)
        self.__find_include_statements(content)
        self.__find_functions(content)


    def __find_module_name(self, content):
        regex = r'#pragma\s+ModuleName\s*=\s*(\S+)'
        pragma = re.search(regex, content, flags=re.I)
        if (pragma):
            self.__module_name = re.sub(regex, r'\1', pragma.group(), flags=re.I)


    def __find_functions(self, content):
        regex = r'(?!//.*Function)^.*Function'
        regex += r'(( |\t)*/\S+)*'    # flags like /S or /WAVE
        regex += r'((( |\t)*\[.*?\])+|( |\t)+)'    # multiple values return or space
        regex += r'(\S+)( |\t)*\('    # name of function
        p = re.compile(regex, flags=re.I|re.M)
        for match in p.finditer(content):
            function_name = p.sub(r'\7', match.group())
            if (re.match('Static', match.group(), flags=re.I)):
                # Static functions in a file without a module name are not necessary
                # to be considered.
                if (len(self.__module_name)):
                    self.functions.append(self.__module_name+'#'+function_name)
            else:
                self.functions.append(function_name)


    def __find_include_statements(self, content):
        regex = r'(?!//.*#include)^.*#include( |\t)+\"(.*?)\"'
        p = re.compile(regex, flags=re.I|re.M)
        for match in p.finditer(content):
            includename = p.sub(r'\2', match.group())
            self.include.append(includename+'.ipf')


    def search_depenence(self):
        # a regular expression to search the include statement in an ipf file
        include = re.compile(r'#include( |\t)+"' + self.__filepath.name[:-4] + '"',
                             flags=re.I)

        # a list of regular expressions to search functions in an ipf file
        functions = []
        for f in self.functions:
            keys = [f+r'( |\t)*\(',
                   r'proc( |\t)*=( |\t)*'+f+r'( |\t)*(,|$)',
                   r',?( |\t)+hook(\(\S+\))?( |\t)*=( |\t)*'+f,
                   r'SetIgorHook( |\t)+\S+( |\t)*=( |\t)*'+f]
            allkeys = '^.*(' + '|'.join(['('+k+')' for k in keys]) + ')'
            exclude_comments = '(?!//.*' + f + ')'
            functions.append(re.compile(exclude_comments+allkeys, flags=re.I|re.M))

        for ipf in pathlib.Path(BASE).glob('**/*.ipf'):
            if (ipf == self.__filepath):
                continue

            with open(ipf, 'r') as f:
                content = f.read()

            for f in functions:
                if (not f.search(content)): # not used in the ipf file
                    continue
                # search the include statement, then go next ipf file
                if (include.search(content)):
                    self.used.append(ipf.name)
                else:
                    self.required.append(ipf.name)
                break


class Progress:

    def __init__(self, full):
        self.__count = 0
        self.__full = full
        print('[' + '.'*full + ']', end='', flush=True)

    def step(self):
        self.__count += 1
        print('\b'*(self.__full+1), end='')
        print('#' * self.__count, end='')
        print('.'*(self.__full-self.__count) + ']', end='', flush=True)


def search(path):
    ipf = IgorProcedureFile(path)
    ipf.search_depenence()
    return (path.name, ipf)


if __name__ == '__main__':

    ipfs = {}

    p = pathlib.Path(BASE)
    paths = list(p.glob('**/*.ipf'))

    print('searching dependence...')
    p = Progress(len(paths))

    with confu.ProcessPoolExecutor(max_workers=os.cpu_count()) as executor:
        futures = [executor.submit(search, f) for f in paths]
        for future in confu.as_completed(futures):
            result = future.result()
            ipfs[result[0]] = result[1]
            p.step()
    print('')

    for name in ipfs:
        for required in ipfs[name].required:
            ipfs[required].require.append(name)
        for include in ipfs[name].include:
            if (include in ipfs) and (not name in ipfs[include].used):
                ipfs[name].unnecessary.append(include)
            if include not in ipfs:
                ipfs[name].unnecessary.append(include)

    ipfs['SIDAM_StartExit.ipf'].require.remove('SIDAM_Hook.ipf')
    ipfs['SIDAM_StartExit.ipf'].unnecessary.remove('SIDAM_Constants.ipf')

    resolved = True
    for name in ipfs:
        if ipfs[name].require or ipfs[name].unnecessary:
            resolved = False
            print('')
        if ipfs[name].require:
            print(f'{name} needs:')
            print(ipfs[name].require)
        if ipfs[name].unnecessary:
            print(f'{name} no longer needs:')
            print(ipfs[name].unnecessary)

    if resolved:
        print('OK')
