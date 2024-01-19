version 1.0

import "call.wdl" as CallVcf
import "preprocess.wdl" as PreProcess
import "combining.wdl" as Combining

workflow Benchmark {
    input {
        String name
        File bamIn
        File bamIndexIn
        File refFastaIn
        File refFastaIndexIn
        File benchmarkVcf
        File benchmarkIndex
        Boolean? inclusive
        # File clair3_model
    }

    call CallVcf.CallVariants {
        input:
            bamIn = bamIn,
            bamIndexIn = bamIndexIn,
            refFastaIn = refFastaIn,
            refFastaIndexIn = refFastaIndexIn,
            # clair3_model = clair3_model
    }

    call Combining.GenerateCombinations
    {
        input:
            inclusive = if defined(inclusive) && inclusive then true else false,
            vcfList = CallVariants.vcfList
    }

    scatter(combinationFile in GenerateCombinations.combinations)
    {
        call PreProcess.DoPreProcessing{
            input:
                refFastaIn = refFastaIn,
                combination = combinationFile
        }
        call Truvari {
            input:
                combinationPair = DoPreProcessing.processed,
                benchmarkVcf = benchmarkVcf,
                benchmarkIndex = benchmarkIndex
        }
    }

    call DrawUpset {
        input:
            benchmarks = Truvari.benchmark,
            name = name
    }
    

    output {
        File output_image = DrawUpset.out
        Array[File] combinations = GenerateCombinations.combinations
        Array[File] vcfList = CallVariants.vcfList
        Array[Pair[String, File]] benchmarks = Truvari.benchmark
    }
}





task PreProcess {
    #
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
    # Benchmark 
    input {
        Pair[File, File] combinationPair
        File benchmarkVcf
        File benchmarkIndex
    }

    command {
        set -e -o pipefail
        mkdir workfolder
        cp ~{combinationPair.right} workfolder/
        cp ~{combinationPair.left} workfolder/
        less workfolder/~{basename(combinationPair.left)}
        truvari bench \
            -c workfolder/~{basename(combinationPair.left)} \
            -b ~{benchmarkVcf} \
            -o truvari_output 
        mv truvari_output/summary.json truvari_output/~{basename(combinationPair.left)}-summary.json
    }

    output {
        Pair[String, File] benchmark = 
            (basename(combinationPair.left), "truvari_output/~{basename(combinationPair.left)}-summary.json")
    }

    runtime {
        docker: "quay.io/biocontainers/truvari:4.0.0--pyhdfd78af_0"
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
    # Draw upset-plot for precision, recall, f1-score and variant-amount
    input {
        Array[Pair[String, File]] benchmarks
        String name
    }

    command {
        echo "test"
        /exports/sascstudent/samvank/conda2/bin/python3 /exports/sascstudent/samvank/code/wdl/drawUpset.py ~{write_json(benchmarks)} ~{name}
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