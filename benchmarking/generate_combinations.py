import sys
import argparse
import itertools

MINIMUM_SIZE = 2


def generate_combinations(vcfListFile: str, minimumSize) -> list:
    vcfList = vcfListFile.split(",")
    vcfList = [x.strip() for x in vcfList]
    combinationList = []
    for length in range(minimumSize, len(vcfList)+1):
        combinationList.extend(itertools.combinations(vcfList, length))
    return combinationList


args = sys.argv[1]
combinations = generate_combinations(args, MINIMUM_SIZE)
for combination in combinations:
    combinationEnd = [x.split("/")[-1] for x in combination]
    combinationName = "-".join(combinationEnd)
    fl = open(combinationName, "w")
    print(combinationName)
    toWrite = "" 
    for vcf in combination:
        toWrite += vcf + "\n"
    # toWrite = toWrite.strip("\n")
    fl.write(toWrite)
    fl.close()

