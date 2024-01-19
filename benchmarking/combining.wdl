version 1.0

workflow GenerateCombinations {
    input {
        Boolean inclusive
        Array[File] vcfList
    }

    if (!inclusive) {
        call ExclusivePrepare {
            input:
                vcfList = vcfList
        }

        call ExclusiveMerge {
            input:
                mergingFile = ExclusivePrepare.mergingFile
        }

        call ExclusiveGenerateCombinations {
            input:
                merged = ExclusiveMerge.merged
        }

    }

    if (inclusive)
    {
        call InclusivePrepare {
            input:
                vcfList = vcfList
        }

        scatter(combinationFile in InclusivePrepare.combinations) {
            call InclusiveGenerateCombinations {
                input:
                    combinationFile = combinationFile
            }
        }
    }

    output {
        Array[File] combinations = select_first([ExclusiveGenerateCombinations.combinations, InclusiveGenerateCombinations.out])
    }
}


task ExclusivePrepare {
    input {
        Array[File] vcfList
    }

    command {
        python3 /exports/sascstudent/samvank/code/wdl/generate_one_combination.py \
            ~{sep="," vcfList}
    }

    output {
        File mergingFile = "vcf_list_for_survivor"
    }

    runtime {
        memory: "10G"
        time_minutes: 240 
    }

    parameter_meta {
        vcfList: "array of vcf-files"
    }
}


task ExclusiveMerge {
    # Merges vcf-files, keeping only reads that appear in every vcf supplied in 'combinationFile'
    input {
        File mergingFile
    }

    command {
        
        SURVIVOR merge \
            ~{mergingFile} \
            1000 \
            1 \
            0 \
            0 \
            0 \
            30 \
            all_merged.vcf
    }

    output {
        File merged = "all_merged.vcf"
    }

    runtime {
        docker: "quay.io/biocontainers/survivor:1.0.7--he513fc3_0"
        memory: "20G"
        time_minutes: 240 
        cpu: 4
    }

    parameter_meta {
        mergingFile: "file containing file-adresses (seperated by newlines) of vcf-files to merge"
    }
}

task ExclusiveGenerateCombinations {
    # meta {
    #     volatile: true
    # }

    input {
        File merged
    }

    command {
        mkdir survivor_output
        cd survivor_output
        python3 /exports/sascstudent/samvank/code/wdl/generate_combinations_from_suppvec.py \
            ~{merged}
    }

    output {
        Array[File] combinations = read_lines(stdout())
    }

    runtime {
        memory: "10G"
        time_minutes: 240 
    }

    parameter_meta {
        merged: "merged survivor output"
    }
}


task InclusivePrepare {
    # Generates an array of files that each contain a list of file-paths (separated by newlines) 
    #   to be combined by SURVIVOR
    # Input to scatter-block 
    input {
        Array[File] vcfList
    }

    command {
        python3 /exports/sascstudent/samvank/code/wdl/generate_combinations.py \
            ~{sep="," vcfList}
    }

    output {
        Array[File] combinations = read_lines(stdout())
    }

    runtime {
        memory: "10G"
        time_minutes: 240 
    }

    parameter_meta {
        vcfList: "array of vcf-files"
    }
}


task InclusiveGenerateCombinations {
    # Merges vcf-files, keeping only reads that appear in every vcf supplied in 'combinationFile'
    input {
        File combinationFile
    }

    command {
        if [[ $(cat ~{combinationFile} | wc -l) -eq 1 ]]
        then
            cp $(cat ~{combinationFile}) ./
        elif [[ $(cat ~{combinationFile} | wc -l) -eq 2 ]]
        then
            echo "yes"
            SURVIVOR merge \
                ~{combinationFile} \
                1000 \
                2 \
                0 \
                0 \
                0 \
                30 \
                ~{basename(combinationFile)}
        elif [[ $(cat ~{combinationFile} | wc -l) -eq 3 ]]
        then
            echo "yes"
            SURVIVOR merge \
                ~{combinationFile} \
                1000 \
                3 \
                0 \
                0 \
                0 \
                30 \
                ~{basename(combinationFile)}
        elif [[ $(cat ~{combinationFile} | wc -l) -eq 4 ]]
        then
            echo "yes"
            SURVIVOR merge \
                ~{combinationFile} \
                1000 \
                4 \
                0 \
                0 \
                0 \
                30 \
                ~{basename(combinationFile)}
        else
            echo "no"
            cp $(cat ~{combinationFile}) ./
        fi
    }

    output {
        File out = basename(combinationFile)
    }

    runtime {
        docker: "quay.io/biocontainers/survivor:1.0.7--he513fc3_0"
        memory: "20G"
        time_minutes: 240 
        cpu: 4
    }

    parameter_meta {
        combinationFile: "file containing file-adresses (seperated by newlines) of vcf-files to merge"
    }
}