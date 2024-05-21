
import os, sys
import logging, traceback

logging.basicConfig(
    filename=snakemake.log[0],
    level=logging.DEBUG,
    format="%(asctime)s %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)

logging.captureWarnings(True)


def handle_exception(exc_type, exc_value, exc_traceback):
    if issubclass(exc_type, KeyboardInterrupt):
        sys.__excepthook__(exc_type, exc_value, exc_traceback)
        return

    logging.error(
        "".join(
            [
                "Uncaught exception: ",
                *traceback.format_exception(exc_type, exc_value, exc_traceback),
            ]
        )
    )


# Install exception handler
sys.excepthook = handle_exception




import pandas as pd
from pathlib import Path

def process_file(filename):
    """
    Processes a single file and returns a dictionary with results.

    Args:
        filename (str): The path to the file.

    Returns:
        dict: A dictionary containing the number of classified, unclassified, and input sequences, or None if an error occurs.
    """
    
    with open(filename, "r") as f:
        text = f.read()



    numbers = {"sample": Path(filename).stem}

    for key in ["processed","classified", "unclassified"]:

        line_with_keywords = find_line_with_keywords(text, "sequences",key)

        if line_with_keywords is None:  raise Exception(f"keywords {key} and sequences not found in file {filename}:\n{text}")

        # extract number at beginning of line.
        try:
            n_sequences = int(line_with_keywords.rstrip().split(maxsplit=1)[0])
        except (ValueError, IndexError) as e:
            raise Exception(f"Error finding number at the beginning of line:\n {line_with_keywords}")
        


        numbers[key]= n_sequences
        
           


    assert numbers["classified"] + numbers["unclassified"] == numbers["processed"], "Numbers do not match"

    return numbers
    

    


def find_line_with_keywords(text, keyword1, keyword2=None):
    """
    Finds the first line containing the specified keywords.

    Args:
        text (str): The text to search.
        keyword1 (str): The first required keyword.
        keyword2 (str, optional): The second optional keyword. Defaults to None.

    Returns:
        str: The line containing the keywords, or None if not found.
    """
    for line in text.splitlines():
        if keyword1 in line and (not keyword2 or keyword2 in line):
            return line
    return None



results = []
for filename in snakemake.input:
    result = process_file(filename)
    if result:
        results.append(result)


df = pd.DataFrame(results).rename(columns= {
    "processed":"input_reads",
    "classified":"mapped_reads",
    "unclassified":"output_reads"
    }
)


df.to_csv(snakemake.output[0], index=False)

