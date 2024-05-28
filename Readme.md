
# Metagenome pipeline used in Centre de la mémoire


# Run the pipeline


There is a `run.sh`script in the code directory, which represents the main script to run the pipeline. The idea is to move to the **working directory*, the directory where the pipeline should be executed and run the script from there. 


### Sample table
First, you need to create a **sample table** (`samples.csv`) in the working directory. This table should contain the information about the fastq files to be processed.

An example of a sample table is given in the `test` directory of the pipeline code. 

```csv
sample_name,Reads_raw_R1,Reads_raw_R2
sample1,sample1_R1.fastq.gz,sample1_R2.fastq.gz
sample2,sample2_R1.fastq.gz,sample2_R2.fastq.gz
```

If you have already quality controlled reads, you can also provide the path to the quality controlled reads in the sample table under the headers `Reads_QC_R1` and `Reads_QC_R2`.

If all the fastq files are within a directory, you don't need to provide the full path to the each fastq files. You can specify the main `fastq_dir` in the config file (see next step). In the sample table provide only the relative path to the `fastq_dir`. 

***Sample names***: The first column should contain concise sample names. These names will be used throughput the pipeline. I request that they start with a letter and don't contain any special characters only numbers ane letters. If you have long sample names, maybe you need to simply use S1,S2... and then create a mapping. 


### Configuration file

Go to the working directory and run the pipline.

```bash

cd ~/scratch/MyWorkingDirectory
~/Path/to/CDM_Pipeline/run.sh

```

The script will create a `project_config.yaml` file in the working directory. This file contains the minimum configuration for the pipeline. You can adjust the configuration to your needs.

For example `fastq_dir` and other parameters are specific to the project.

There is also a `default_config.yaml` file in the code directory, which defines more values which should be common to all runs of this pipepline. 

***Important***:
You should set the `database_dir` to the path of the database folder you created in step 4. of the Setup, either in the `project_config.yaml` or in the `default_config.yaml` file. 

### Run the pipeline

You are now almost ready to run the pipeline.

Let's just, do a *Dry run*, to check what _would be executed_ by the pipeline. 
```bash

cd ~/scratch/MyWorkingDirectory
~/Path/to/CDM_Pipeline/run.sh qc profile functions --dryrun

``` 

If everything looks good, you can run the pipeline.

```bash
~/Path/to/CDM_Pipeline/run.sh qc profile functions

```

You are not required to run all three targets at once. You can run them separately. 
By default the pipeline runs simply the `profile` target. 

```bash

~/Path/to/CDM_Pipeline/run.sh profile
~/Path/to/CDM_Pipeline/run.sh functions
```


# Integrate new code.

I hope you to spare you with complicated merge of code. 
I will try to keep the code in a way that you can simply pull the new code from the repository and run the pipeline.

If I made changes to the code, you can simply pull the new code from the repository. 

```bash

cd ~/path/to/CDM_Pipeline
git pull

```


Accept everything related to git pull. E.g. accept rebasing, when promted.

If there are _merge conflicts_, you can try to resolve them with the VS Code interface. 


Alternatively, you might want to make a copy of the code.

```bash

cd ~/path/to/CDM_Pipeline/
cd ..

mv CDM_Pipeline CDM_Pipeline_old
git clone https://github.com/silask/CDM_Pipeline

```







## Setup

(I explained this to Rahel)

### Setup on personal computer

Install [VS Code](https://code.visualstudio.com/) and install the extension for the [remote development](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.vscode-remote-extensionpack). Using this extension, you can connect to the HPC serversand work on the server as if you were working on your personal computer.

and the snakemake language extension (Search in extensions).


## Setup on HPC servers

### 1. Basic setup

[See my blog](https://silask.github.io/post/hpc/)

This should guide you how to setup a conda/mamba on the HPC.


### 2. Installation of Snakemake on the HPC

Using the mamba install snakemake:

```bash

mamba install -c bioconda -c conda-forge snakemake

```

Install also the snakemake language extension on the VS Code on the server.

### 3. Install slurm extension

Install the [slurm plugin for snakemake](https://snakemake.github.io/snakemake-plugin-catalog/plugins/executor/slurm.html)

```bash
pip install snakemake-executor-plugin-slurm
```


### 4. Database and conda environment folder


create a database folder and a conda environment folder for all your snakemake pipelines. 
Better on a scatch folder. 
A shared scratch folder for the databases is a good idea.



```bash
cd ~/scratch

mkdir Databases
mkdir Databases/conda_envs

# get absolute path 
realpath Databases/conda_envs

```

### 5. Create a snakemake profile

A snakemake profile is used to some common arguments for snakemake commands.
Here we create a profile to access the slurm cluster.

We also specify the path to the conda environment folder.

```bash

mkdir ~/.config/snakemake/slurm
touch ~/.config/snakemake/slurm/config.yaml

```

In this profile-config-file add the following content, either using nano or via the VS Code interface. Take care to adjust the path to the conda environment folder.


```yaml
executor: slurm
restart-times: 0
max-jobs-per-second: 10
max-status-checks-per-second: 10
cores: 30 # how many jobs you want to submit to your cluster queue
local-cores: 2
rerun-incomplete: true  # recomended for cluster submissions
conda-prefix: /srv/beegfs/scratch/users/k/kiesers/conda_envs # <-- here add the path to the conda environment folder
default-resources:
  - "slurm_partition=shared-cpu"
  - "slurm_account=frisoni"
  - "mem_mb=6000"
  - "runtime=300"

```


Now you can run snakemake with the profile:

```bash

snakemake --profile slurm --use-conda

```

And it will submit the jobs to the slurm cluster. 



### 6. Copy the code of the pipeline

Copy the code of the pipeline to the server. (I need to give you access to the repository on Github)

```bash

cd ~
git clone https://github.com/silask/CDM_Pipeline


```


