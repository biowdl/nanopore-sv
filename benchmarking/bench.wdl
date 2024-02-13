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
        File clairModel
        File scriptFolder
        Array[String] variantCallers
        Boolean? inclusive
    }

    call CallVcf.CallVariants {
        input:
            bamIn = bamIn,
            bamIndexIn = bamIndexIn,
            refFastaIn = refFastaIn,
            refFastaIndexIn = refFastaIndexIn,
            clairModel = clairModel,
    }

    call Combining.GenerateCombinations
    {
        input:
            inclusive = if defined(inclusive) && inclusive then true else false,
            vcfList = CallVariants.vcfList,
            scriptFolder = scriptFolder,
            variantCallers = variantCallers
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


task Truvari {
    # Benchmarking 
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
        python3 scripts/drawUpset.py ~{write_json(benchmarks)} ~{name}
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