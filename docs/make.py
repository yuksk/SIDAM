import pathlib
import re

BASEDIR = "../src/SIDAM"
OUTPUTDIR = "_commands"
NAVFILE = "_data/navigation.yml"


def extract_text(filename: str) -> list[tuple[str, str]]:
    """Extract a help text from a file."""

    whole_text_in_file = pathlib.Path(filename).read_text()
    # The blocks is a list of tuples. Each tuple has 3 elements.
    # 1st one is a help text and the last one is a function defenition
    blocks = re.findall(
        r"//@(.*?)//@\nFunction(/\w+)*\s+(.*?\))",
        whole_text_in_file,
        flags=re.S | re.M,
    )
    return [(b[0], b[2]) for b in blocks]


def parse_help_text(helptxt: str) -> str:
    """Parse a help text"""

    # Remove // and tubs at the beginning of each line
    parsed = re.sub(r"^//\s*", "", helptxt, flags=re.M)

    # Make variable names bold and make types bold italic
    parsed = re.sub(
        r"^([a-zA-Z].*?:)\s*(.*)$", r"\n**\1** ***\2***  ", parsed, flags=re.M
    )

    # Make the return type bold italic
    parsed = re.sub(r"(## Returns\n)(.*?)\n", r"\1***\2***  \n", parsed, flags=re.M)

    # Insert a line before ## Parameters and ## Returns
    parsed = re.sub(r"## (Parameters|Returns)", r"\n## \1", parsed, flags=re.M)

    return parsed


def parse_function_definition(deftxt: str) -> tuple[str, str]:
    """Parse a function definition"""

    # Connect multiple lines if so
    deftxt = re.sub(r"\n\s*", " ", deftxt, flags=re.M)

    # Split the definition line to the function name and the variables definition
    function_name, variables, _ = re.split(r"[()]", deftxt)

    # Remove type strings (e.g., Wave, String, etc) from the variables definition
    # The last slice is to remove unnecessary ', ' at the beginning
    variables = re.sub(r"(,|^)\s*(\[*)\S+\s+", r", \2", variables)[2:]

    parsed = (
        f'---\ntitle: "{function_name}"\n---\n'
        f'<p class="function_definition">{function_name}'
        f'(<span class="function_variables">{variables}</span>)</p>\n'
    )

    return function_name, parsed


def construct_help_file(filename: str) -> str:
    """Make a help file(s) from an ipf file."""

    function_names = []
    for h in extract_text(filename):
        name, parsed = parse_function_definition(h[1])
        function_names.append(name)
        parsed += parse_help_text(h[0])
        output_path = f"{OUTPUTDIR}/{name}.md"
        with open(output_path, mode="w") as f:
            f.write(parsed)
            print(output_path)

    return function_names


def construct_nav_file(function_names: list[str]):
    """Make the navigation file."""

    with open("_data/_nav.yml", mode="r") as f:
        navstr = f.read()

    function_names.sort()
    navitems = ""
    for name in function_names:
        navitems += f'      - title: "{name}"\n'
        navitems += f"        url: /{OUTPUTDIR[1:]}/{name}/\n"
    navstr = navstr.replace("#%commands%", navitems)

    with open("_data/navigation.yml", mode="w") as f:
        f.write(navstr)


filenames = pathlib.Path(f"{BASEDIR}").glob("**/*.ipf")
function_names = []
for f in filenames:
    function_names += construct_help_file(f)

construct_nav_file(function_names)
