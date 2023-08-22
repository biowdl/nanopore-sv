version 1.0

workflow CallVariants {
    input {
        File bamIn
        File bamIndexIn   
        File refFastaIn
        # File clair3Model
    }

    # call CallClair3 { 
    #     input: 
    #         bamIn = bamIn,
    #         refFastaIn = refFastaIn,
    #         clair3Model = clair3Model,
    # }

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
        Array[File] vcfList = [CallCuteSV.outVcf, CallSniffles.outVcf, CallSVIM.outVcf]
    }
}


task CallClair3 {
    input {
        File bamIn
        File bamIndexIn   
        File refFastaIn
        File clair3Model
    }

    command {
        run_clair3.sh \
            ~{bamIn} \
            ~{refFastaIn} \
            --platform='ont' \
            --enable_long_indel \
            --fast_mode \
            --model_path=~{clair3Model} \
            --threads=20 \
            --output=output/vcf/clair3_out.vcf \
    }

    output {
        File outVcf = "clair3_out.vcf"
    }

    runtime {
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
            workfolder/
    }

    output {
        File outVcf = "cutesv_out.vcf"
    }

    runtime {
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
    }

    output {
        File outVcf = "out.vcf"
    }

    runtime {
        cpu: 4
        memory: "20G"
        time_minutes: 240 
    }
}
