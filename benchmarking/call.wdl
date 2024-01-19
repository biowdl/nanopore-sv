version 1.0

workflow CallVariants {
    input {
        File bamIn
        File bamIndexIn   
        File refFastaIn
        File refFastaIndexIn
        File clairModel
    }

    call CallClair3 { 
        input: 
            bamIn = bamIn,
            refFastaIn = refFastaIn,
            bamIndexIn = bamIndexIn,
            refFastaIndexIn = refFastaIndexIn,
            model = clairModel,
    }

    call Unzip {
        input:
            zippedVcf = CallClair3.outVcf,
    }

    call CallCuteSV { 
        input: 
            bamIn = bamIn,
            bamIndexIn = bamIndexIn,
            refFastaIn = refFastaIn,
    }

    call CallSVIM { 
        input: 
            bamIn = bamIn,
            bamIndexIn = bamIndexIn,
            refFastaIn = refFastaIn,
    }

    call CallSniffles { 
        input: 
            bamIn = bamIn,
            bamIndexIn = bamIndexIn,
            refFastaIn = refFastaIn,
    }

    output {
        Array[File] vcfList = [CallCuteSV.outVcf, CallSniffles.outVcf, CallSVIM.outVcf, Unzip.outVcf]
    }
}


task CallClair3 {
    input {
        File bamIn
        File bamIndexIn   
        File refFastaIn
        File refFastaIndexIn 
        File model
        Int threads = 20
    }

    command {
        run_clair3.sh \
            --bam_fn=~{bamIn} \
            --ref_fn=~{refFastaIn} \
            --platform='ont' \
            --enable_long_indel \
            --fast_mode \
            --var_pct_phasing=0.7 \
            --model_path=~{model} \
            --threads=~{threads} \
            --output=output/ 
        mv output/merge_output.vcf.gz ./clair3_out.vcf.gz
    }

    output {
        File outVcf = "clair3_out.vcf.gz"
    }

    runtime {
        cpu: "~{threads}"
        memory: "20G"
        time_minutes: 1400 
    }
}

task Unzip {
    input {
        File zippedVcf
    }

    command {
        pbgzip -d -c ~{zippedVcf} > ~{sub(basename(zippedVcf), "vcf.gz", "vcf")}
    }

    output {
        File outVcf = "~{sub(basename(zippedVcf), 'vcf.gz', 'vcf')}"
    }

    runtime {
        docker: "quay.io/biocontainers/pbgzip:2016.08.04--h2f06484_1"
        cpu: 4
        memory: "20G"
        time_minutes: 240 
    }
}


task CallCuteSV {
    input {
        File bamIn
        File bamIndexIn   
        File refFastaIn
    }

    command {
        cuteSV \
            --max_cluster_bias_INS 100 \
            --diff_ratio_merging_INS 0.3 \
            --max_cluster_bias_DEL 100 \
            --diff_ratio_merging_DEL 0.3 \
            ~{bamIn} \
            ~{refFastaIn} \
            cutesv_out.vcf \
            ./
    }

    output {
        File outVcf = "cutesv_out.vcf"
    }

    runtime {
        docker: "quay.io/biocontainers/cutesv:2.0.2--pyhdfd78af_0"
        cpu: 4
        memory: "20G"
        time_minutes: 240 
    }
}


task CallSniffles {
    input {
        File bamIn
        File bamIndexIn   
        File refFastaIn
    }

    command {
        sniffles \
            -i ~{bamIn} \
            --reference ~{refFastaIn} \
            -v sniffles_out.vcf \
            --allow-overwrite
    }

    output {
        File outVcf = "sniffles_out.vcf"
    }


    runtime {
        docker: "quay.io/biocontainers/sniffles:2.0.7--pyhdfd78af_0"
        cpu: 4
        memory: "20G"
        time_minutes: 240 
    }
}


task CallSVIM {
    input {
        File bamIn
        File bamIndexIn   
        File refFastaIn
    }

    command {
        set -e -o pipefail
        mkdir workfolder
        svim alignment \
            workfolder/ \
            ~{bamIn} \
            ~{refFastaIn} 
        mv workfolder/variants.vcf ./svim_out.vcf
    }

    output {
        File outVcf = "svim_out.vcf"
    }

    runtime {
        docker: "quay.io/biocontainers/svim:2.0.0--pyhdfd78af_0"
        cpu: 4
        memory: "20G"
        time_minutes: 240 
    }
}
