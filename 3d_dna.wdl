version 1.0

workflow run_3d_dna {
  input {
    File draft_assembly_fasta         # GCS path to input contig-level FASTA
    File merged_nodups                # GCS path to Juicer output
    String? output_prefix             # Optional prefix for naming
    Int    Extra_disk_space    = 500
    Int    mem_gb  = 64
    Int    threads = 16
  }

  call run3DDNA {
    input:
      draft_assembly_fasta = draft_assembly_fasta,
      merged_nodups        = merged_nodups,
      output_prefix        = output_prefix,
      Extra_disk_space     = Extra_disk_space,
      mem_gb               = mem_gb,
      threads              = threads
  }

  output {
    File final_fasta       = run3DDNA.final_fasta
    File final_hic         = run3DDNA.final_hic
    File final_assembly    = run3DDNA.final_assembly
    Array[File] contact_maps    = run3DDNA.contact_maps
    Array[File] assembly_steps  = run3DDNA.assembly_steps
    Array[File] misjoin_wigs    = run3DDNA.misjoin_wigs
    Array[File] misjoin_beds    = run3DDNA.misjoin_beds
  }
}

task run3DDNA {
  input {
    File draft_assembly_fasta
    File merged_nodups
    String? output_prefix
    Int    Extra_disk_space
    Int    mem_gb
    Int    threads
  }
  
  # Compute required disk space
  Int GB_of_space = ceil(size(merged_nodups, "GB") * 2) + Extra_disk_space

  # Derive genome ID from input FASTA filename
  String genomeid = basename(draft_assembly_fasta, ".fa")
  
  command <<<
    set -eux

    # Install dependencies if needed
    apt-get update && apt-get install -y git curl samtools parallel

    # Clone the 3D-DNA pipeline
    git clone https://github.com/aidenlab/3d-dna.git
    
    # Run the 3D-DNA pipeline with sealing fixes
    bash ./3d-dna/run-asm-pipeline.sh -i 30000 \
      --editor-coarse-resolution 25000 \
      --editor-coarse-region 150000 \
      --editor-coarse-stringency 50 \
      --editor-saturation-centile 5 \
      --editor-fine-resolution 1000 \
      --polisher-input-size 1000000 \
      --splitter-input-size 1000000 \
      --merger-search-band 3000000 \
      --merger-alignment-score 50000000 \
      --merger-alignment-identity 20 \
      --merger-alignment-length 20000 \
      --assembly "~{draft_assembly_fasta}" \
      --output "${genomeid}_3d_dna_output"
  >>>

  output {
    Array[File] contact_maps   = glob("*.hic")
    Array[File] assembly_steps = glob("*.assembly")
    Array[File] misjoin_wigs   = glob("*.wig")
    Array[File] misjoin_beds   = glob("*.bed")
    File final_fasta     = "${genomeid}_FINAL.fasta"
    File final_hic       = "${genomeid}.final.hic"
    File final_assembly  = "${genomeid}.final.assembly"
  }

  runtime {
    docker: "leglerl/3d-dna:latest"
    memory: mem_gb + " GB"
    cpu: threads
    disks: "local-disk " + GB_of_space + " HDD"
  }
}
