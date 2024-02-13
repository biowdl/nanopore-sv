from cyvcf2 import VCF
import sys
import itertools

# Ordering should match SURVIVOR output
CALLER_LIST = [x for x in sys.argv[2].split(",")]

def get_header(vcf_file_name):
    vcf_header = ""
    with open(vcf_file_name, "r") as vcf_handle:
        for line in vcf_handle:
            if line[0] == "#":
                vcf_header += line
            else:
                return vcf_header


def makeName(pattern):
    name = ""
    for i in range(len(CALLER_LIST)):
        if int(pattern[i]):
            name += CALLER_LIST[i] + "-"
    return name[0:-1]


# for 4 callers: ["0001","0010","0100","1000","0011","0110","0101","1010","1100","1001","0111","1110","1101","1011","1111"]
possibles = ["".join(x) for x in list(itertools.product("01", repeat=len(CALLER_LIST)))]
vecDict = dict()
for p in possibles:
    vecDict[p] = []

args = sys.argv[1]
vcf_header = get_header(args)

for variant in VCF(args):
    vecDict[variant.INFO.get("SUPP_VEC")].append(variant)

for vec in vecDict:
    outf = open(f"{makeName(vec)}.vcf", "w")
    outf.write(vcf_header)
    for var in vecDict[vec]:
        outf.write(str(var))
    outf.close()
    print(f"survivor_output/{makeName(vec)}.vcf")
