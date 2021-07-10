import os.path
import pathlib
import re

# path seen from the directory where the Makefile is.
BASEPATH = '../src/SIDAM'
OUTPUT = './source/commands.rst'

def _docs_from_file(filename: str) -> dict[str, str]:
    # find blocks of comment doc strings in a file
    whole_text_in_file = pathlib.Path(filename).read_text()
    result = re.finditer(r'//@(.*?)//@\nFunction(/\w+)*\s+(\S+)\((.*?)\)',
            whole_text_in_file, flags=re.S|re.M)
    if result is None:
        return None

    # Construct reStructuredText from each block
    doc = {}
    for s in result:
        doc.update(_construct_reST(s.groups()))

    return doc


def _construct_reST(groups: list[str]) -> dict[str, str]:
    """Construct reStructuredText from a block of comment doc strings"""
    body, funcname, funcparams = groups[0], groups[-2], groups[-1]
    doc = []

    # clean up the parameter string
    funcparams = re.sub(r'(\n|\t)', ' ', funcparams)
    funcparams = re.sub(r'\s+', ' ', funcparams)
    funcparams = re.sub(r'(wave(/\w+)*|string|variable|int|STRUCT \w+)\s+', '',
            funcparams, flags=re.I)
    doc.append(f'.. function:: {funcname}({funcparams})')

    # clean up the body
    body = re.sub(r'//\n', '\n', body)
    body = re.sub(r'//\s', '', body)

    # Description
    s = re.search(r'\n(.*?)\n\nParameters\n-*\n', body, flags=re.S)
    str_ = re.sub(r'^', '   ', s.groups()[0], flags=re.M)
    doc.append(str_)

    # Parameters
    s = re.search(r'\nParameters\n-*\n(.*?)($|\n\nReturns\n-*)', body,
            flags=re.S)
    if s is not None:
        str_ = re.sub(r'^(\S*?)\s*:\s*(.*?)\n', r':type \1: \2\n:param \1:\n',
                s.groups()[0], flags=re.M)
        # Handle indent
        str_ = re.sub(r'\t', '   ', str_, flags=re.M)
        str_ = re.sub(r'^:', '   :', str_, flags=re.M)
        # Concatenate lines unless nested block and field lists
        str_ = re.sub(r'\n\s{3}([^:\s])', r' \1', str_)
        doc.append(str_)

    # Returns
    s = re.search(r'^Returns\n-*\n(.*)\n', body, flags=re.S|re.M)
    if s is not None:
        str_ = re.sub(r'^(.*?)\n\t*(.*)', r':rtype: \1\n:return: \2',
                s.groups()[0], flags=re.M|re.S)
        # Handle indent
        str_ = re.sub(r'\t', '   ', str_, flags=re.M)
        str_ = re.sub(r'^:', '   :', str_, flags=re.M)
        # Concatenate lines unless nested block and field lists
        str_ = re.sub(r'\n\s{3}([^:\s])', r' \1', str_)
        doc.append(str_)

    return {funcname: '\n\n'.join(doc)}


if __name__ == '__main__':

    filenames = pathlib.Path(f'{BASEPATH}').glob('**/*.ipf')
    documents = {}

    for filename in filenames:
        docs = _docs_from_file(filename)
        if docs is not None:
            documents.update(docs)

    # Sort by the function names
    documents_sorted = sorted(documents.items())

    if documents:
        p = pathlib.Path(OUTPUT)
        header = '.. _api:\n\nCommand help\n============\n\n'
        contents = '\n\n'.join([d[1] for d in documents_sorted])
        p.write_text(header+contents)

