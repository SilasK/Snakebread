# Metagenome Pipeline Used in Centre de la Mémoire

## Run the Pipeline

There is a `run.sh` script in the code directory, which represents the main script to run the pipeline. The idea is to move to the **working directory**, the directory where the pipeline should be executed, and run the script from there.

### Sample Table

First, you need to create a **sample table** (`samples.csv`) in the working directory. This table should contain the information about the FASTQ files to be processed.

An example of a sample table is given in the `test` directory of the pipeline code:

```csv
sample_name,Reads_raw_R1,Reads_raw_R2
sample1,sample1_R1.fastq.gz,sample1_R2.fastq.gz
sample2,sample2_R1.fastq.gz,sample2_R2.fastq.gz
```

If you have already quality-controlled reads, you can provide the path to the quality-controlled reads in the sample table under the headers `Reads_QC_R1` and `Reads_QC_R2`.

If all the FASTQ files are within a directory, you don't need to provide the full path to each FASTQ file. You can specify the main `fastq_dir` in the config file (see the next step). In the sample table, provide only the relative path to the `fastq_dir`.

***Sample Names***: The first column should contain concise sample names. These names will be used throughout the pipeline. They should start with a letter and not contain any special characters, only numbers and letters. If you have long sample names, consider using simpler names like S1, S2, etc., and create a mapping.

### Configuration File

Go to the working directory and run the pipeline:

```bash
cd ~/scratch/MyWorkingDirectory
~/Path/to/CDM_Pipeline/run.sh
```

The script will create a `project_config.yaml` file in the working directory. This file contains the minimum configuration for the pipeline. You can adjust the configuration to your needs.

For example, `fastq_dir` and other parameters are specific to the project.

There is also a `default_config.yaml` file in the code directory, which defines more values common to all runs of this pipeline.

***Important***: You should set the `database_dir` to the path of the database folder you created in step 4 of the Setup, either in the `project_config.yaml` or in the `default_config.yaml` file.

### Run the Pipeline

You are now almost ready to run the pipeline.

Let's do a *Dry Run* to check what would be executed by the pipeline:

```bash
cd ~/scratch/MyWorkingDirectory
~/Path/to/CDM_Pipeline/run.sh qc profile functions --dryrun
```

If everything looks good, you can run the pipeline:

```bash
~/Path/to/CDM_Pipeline/run.sh qc profile functions
```

You are not required to run all three targets at once. You can run them separately. By default, the pipeline runs simply the `profile` target:

```bash
~/Path/to/CDM_Pipeline/run.sh profile
~/Path/to/CDM_Pipeline/run.sh functions
```

## Integrate New Code

To avoid complicated code merges, I will try to keep the code in a way that you can simply pull the new code from the repository and run the pipeline.

If I made changes to the code, you can simply pull the new code from the repository:

```bash
cd ~/path/to/CDM_Pipeline
git pull
```

Accept everything related to `git pull`, e.g., accept rebasing when prompted.

If there are _merge conflicts_, you can try to resolve them with the VS Code interface.

Alternatively, you might want to make a copy of the code:

```bash
cd ~/path/to/CDM_Pipeline/
cd ..
mv CDM_Pipeline CDM_Pipeline_old
git clone https://github.com/silask/CDM_Pipeline
```

## Setup


### Setup on Personal Computer

Install [VS Code](https://code.visualstudio.com/) and install the extension for [remote development](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.vscode-remote-extensionpack). Using this extension, you can connect to the HPC servers and work on the server as if you were working on your personal computer.

Install the Snakemake language extension (search in extensions).

### Setup on HPC Servers

#### 0. Copy the Code of the Pipeline

Copy the code of the pipeline to the server. (I need to give you access to the repository on GitHub)

```bash
cd ~
git clone https://github.com/silask/CDM_Pipeline
```

#### 1. Basic Setup

[See my blog](https://silask.github.io/post/hpc/). This should guide you on how to set up a conda/mamba on the HPC.

#### 2. Installation of Snakemake on the HPC

Using mamba, install Snakemake:

```bash
mamba install -c bioconda -c conda-forge snakemake
```

Install also the Snakemake language extension on the VS Code on the server.

#### 3. Install Slurm Extension

Install the [Slurm plugin for Snakemake](https://snakemake.github.io/snakemake-plugin-catalog/plugins/executor/slurm.html):

```bash
mamba install snakemake-executor-plugin-slurm
```

#### 4. Database and Conda Environment Folder

Create a database folder and a conda environment folder for all your Snakemake pipelines, preferably in a scratch folder. A shared scratch folder for the databases is a good idea.

```bash
cd ~/scratch
mkdir Databases
mkdir Databases/conda_envs

# get absolute path 
realpath Databases/conda_envs
```

#### 5. Create a Snakemake Profile

A Snakemake profile is used to define some common arguments for Snakemake commands. Here we create a profile to access the Slurm cluster and specify the path to the conda environment folder.

```bash
mkdir ~/.config/snakemake/slurm
touch ~/.config/snakemake/slurm/config.yaml
```

In this profile-config file, add the following content, either using nano or via the VS Code interface. Take care to adjust the path to the conda environment folder:

```yaml
executor: slurm
restart-times: 0
max-jobs-per-second: 10
max-status-checks-per-second: 10
cores: 30  # how many jobs you want to submit to your cluster queue
local-cores: 2
rerun-incomplete: true  # recommended for cluster submissions
conda-prefix: /srv/beegfs/scratch/users/k/kiesers/conda_envs  # <-- here add the path to the conda environment folder
default-resources:
  - "slurm_partition=shared-cpu"
  - "slurm_account=frisoni"
  - "mem_mb=6000"
  - "runtime=300"
```

Now you can run Snakemake with the profile:

```bash
snakemake --profile slurm --use-conda
```

And it will submit the jobs to the Slurm cluster.
