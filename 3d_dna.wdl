version 1.0

workflow run_3d_dna {
  input {
    File draft_assembly_fasta         # GCS path to input contig-level FASTA
    File merged_nodups                # GCS path to Juicer output
    String? output_prefix             # Optional prefix for naming
  }

  call run3DDNA {
    input:
      draft_assembly_fasta = draft_assembly_fasta,
      merged_nodups = merged_nodups,
      output_prefix = output_prefix
  }

  output {
    # Capture all files with the pattern *FINAL.fasta and *FINAL.assembly in the output directory
    Array[File] final_fasta = run3DDNA.final_fasta
    Array[File] final_assembly = run3DDNA.final_assembly
    File run_log = run3DDNA.run_log
  }
}

task run3DDNA {
  input {
    File draft_assembly_fasta
    File merged_nodups
    String? output_prefix
  }

  command <<<
    set -eux

    # Install dependencies if needed
    apt-get update && apt-get install -y git curl samtools

    # Clone the 3D-DNA pipeline
    git clone https://github.com/aidenlab/3d-dna.git
    cd 3d-dna

    # Copy inputs
    cp ~{draft_assembly_fasta} ./assembly.fasta
    cp ~{merged_nodups} ./merged_nodups.txt

    # Run the 3D-DNA pipeline
    bash run-asm-pipeline.sh \
      ./assembly.fasta \
      ./merged_nodups.txt > ../3d-dna.log 2>&1

    # Move outputs to root so WDL can find them
    cp ${output_prefix}.FINAL.fasta ../output/ || true
    cp ${output_prefix}.FINAL.assembly ../output/ || true
  >>>

  output {
    # Collect all FASTA files ending with FINAL.fasta from the output directory.
    Array[File] final_fasta = glob("output/*FINAL.fasta")
    # Collect all assembly files ending with FINAL.assembly.
    Array[File] final_assembly = glob("output/*FINAL.assembly")
    File run_log = "output/3d-dna.log"
  }

  runtime {
    docker: "leglerl/3d-dna:latest"
    cpu: 16
    memory: "104G"
    disks: "local-disk 50 HDD"
  }
}
