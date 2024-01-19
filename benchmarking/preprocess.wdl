version 1.0

workflow DoPreProcessing {
    input {
        File refFastaIn
        File combination   
    }

    call NormalizeAndDecompose { 
        input: 
            combination = combination,
            refFastaIn = refFastaIn
    }

    call Zip { 
        input: 
            normalized = NormalizeAndDecompose.normalized
    }

    call Index { 
        input:
            zipped = Zip.zipped 
    }

    output {
        Pair[File, File] processed = Index.processed
    }
}

task PreCheck {
    input {
        File combination
    }

    command {
        if [[ ~{basename(combination)} =~ .*.vcf.gz$ ]] 
        then 
            pbgzip -d -c ~{combination} > ~{sub(basename(combination), "vcf.gz", "vcf")}
        fi
    }

    output {
        File out = "~{sub(basename(combination), 'vcf.gz', 'vcf')}"
    }

    runtime {
        docker: "quay.io/biocontainers/pbgzip:2016.08.04--h2f06484_1"
        cpu: 4
        memory: "20G"
        time_minutes: 240 
    }
}


task NormalizeAndDecompose {
    input {
        File refFastaIn
        File combination   
    }

    command {
        set -e -o pipefail
        vt normalize -n -r ~{refFastaIn} ~{combination} -o ~{basename(combination)}.n.vcf
        vt decompose ~{basename(combination)}.n.vcf -o ~{basename(combination)}.n.d.vcf
    }

    output {
        File normalized = "~{basename(combination)}.n.d.vcf"
    }

    runtime {
        docker: "quay.io/biocontainers/vt:0.57721--heae7c10_3"
        cpu: 4
        memory: "20G"
        time_minutes: 240 
    }
}

task Zip {
    input {
        File normalized
    }

    command {
        set -e -o pipefail
        pbgzip -c ~{normalized} > ~{basename(normalized)}.gz
    }

    output {
        File zipped = "~{basename(normalized)}.gz"
    }

    runtime {
        docker: "quay.io/biocontainers/pbgzip:2016.08.04--h2f06484_1"
        cpu: 4
        memory: "20G"
        time_minutes: 240 
    }
}

task Index {
    input {
        File zipped 
    }

    command {
        bcftools sort ~{zipped} -Oz -o ~{basename(zipped)}
        bcftools index -t ~{basename(zipped)} -o ~{basename(zipped)}.tbi 
    }

    output {
        Pair[File, File] processed = ("~{basename(zipped)}", "~{basename(zipped)}.tbi")
    }

    runtime {
        docker: "quay.io/biocontainers/bcftools:1.17--h3cc50cf_1"
        cpu: 4
        memory: "20G"
        time_minutes: 240 
    }
}
