version 1.0

import "call.wdl" as CallVcf

workflow Benchmark {
    input {
        File bamIn
        File bamIndexIn
        File refFastaIn
        File benchmarkVcf
        File benchmarkIndex
        # File clair3_model
    }

    call CallVcf.CallVariants {
        input:
            bamIn = bamIn,
            bamIndexIn = bamIndexIn,
            refFastaIn = refFastaIn
            # clair3_model = clair3_model
    }

    call GenerateCombinations {
        input:
            vcfList = CallVariants.vcfList
    }

    scatter(combinationFile in GenerateCombinations.combinations)
    {
        #survivor 
        call Survivor {
            input:
                combinationFile = combinationFile
        }
        call PreProcess {
            input:
                ref = refFastaIn,
                combination = Survivor.combined
        }
        call Truvari {
            input:
                combinationPair = combination,
                benchmarkVcf = benchmarkVcf,
                benchmarkIndex = benchmarkIndex
        }
    }

    call DrawUpset {
        input:
            benchmarks = Truvari.benchmark
    }

    output {
        File output_image = DrawUpset.out
    }
}


task GenerateCombinations {
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
        memory: "20G"
        time_minutes: 240 
    }

    parameter_meta {
        vcfList: "array of vcf-files"
    }
}


task Survivor {
    input {
        File combinationFile
    }

    command {
        SURVIVOR merge \
            ~{combinationFile} \
            1000 \
            2 \
            0 \
            0 \
            0 \
            30 \
            ~{basename(combinationFile)}
        
    }

    output {
        File combined = basename(combinationFile)
    }

    runtime {
        memory: "20G"
        time_minutes: 240 
        cpu: 4
    }

    parameter_meta {
        combinationFile: "file containing file-adresses (seperated by newlines) of vcf-files to merge"
    }
}


task PreProcess {
    input {
        File combination
        File ref
    }

    command {
        set -e -o pipefail
        vt normalize -n -r ~{ref} ~{combination} -o ~{basename(combination)}.n.vcf
        vt decompose ~{basename(combination)}.n.vcf -o ~{basename(combination)}.n.d.vcf
        bgzip ~{basename(combination)}.n.d.vcf
        bcftools index -t ~{basename(combination)}.n.d.vcf.gz
    }

    output {
        Pair[File, File] processed =
            ("~{basename(combination)}.n.d.vcf.gz", "~{basename(combination)}.n.d.vcf.gz.tbi")  
    }

    runtime {
        memory: "20G"
        time_minutes: 240 
        cpu: 4
    }

    parameter_meta {
        combination: "merged vcf-file"
        ref: "fasta file containing reference genome"
    }
}


task Truvari {
    input {
        Pair[File, File] combinationPair
        File benchmarkVcf
        File benchmarkIndex
    }

    command {
        truvari bench \
            -c ~{combinationPair.left} \
            -b ~{benchmarkVcf} \
            -o ~{basename(combinationPair.left)} \
            --passonly
    }

    output {
        Pair[String, File] benchmark = 
            (basename(combinationPair.left), "~{basename(combinationPair.left)}/summary.json")
    }

    runtime {
        memory: "20G"
        time_minutes: 240 
        cpu: 4
    }

    parameter_meta {
        combinationPair: "pair of files (vcf-file, .tbi index of vcf-file)"
        benchmarkVcf: "Vcf-file (truth-set to compare combinationPair to)"
        benchmarkIndex: ".tbi index-file (index of the truth-set)"
    }
}


task DrawUpset {
    input {
        Array[Pair[String, File]] benchmarks
    }

    command {
        python3 /exports/sascstudent/samvank/code/wdl/drawUpset.py ~{write_json(benchmarks)}
    }

    output {
        File out = "upsetplot.png"
    }

    runtime {
        memory: "20G"
        time_minutes: 240 
        cpu: 4
    }

    parameter_meta {
        benchmarks: "array of pairs, each pair containing a name-string and a summary-file"
    }
}