import sys


vcfListFile = sys.argv[1]
vcfList = vcfListFile.split(",")
combination = [x.strip() for x in vcfList]
fl = open("vcf_list_for_survivor", "w")
print("vcf_list_for_survivor")
toWrite = "" 
for vcf in combination:
    toWrite += vcf + "\n"
# toWrite = toWrite.strip("\n")
fl.write(toWrite)
fl.close()

