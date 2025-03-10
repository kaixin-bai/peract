# Perceiver-Actor

[**Perceiver-Actor: A Multi-Task Transformer for Robotic Manipulation**](https://arxiv.org/abs/2209.05451)  
[Mohit Shridhar](https://mohitshridhar.com/), [Lucas Manuelli](http://lucasmanuelli.com/), [Dieter Fox](https://homes.cs.washington.edu/~fox/)  
[CoRL 2022](https://www.robot-learning.org/) 

PerAct is an end-to-end behavior cloning agent that learns to perform a wide variety of language-conditioned manipulation tasks. PerAct uses a Transformer that exploits the 3D structure of _voxel patches_ to learn policies with just a few demonstrations per task.

![](media/sim_tasks.gif)

The best entry-point for understanding PerAct is [this Colab Tutorial](https://colab.research.google.com/drive/1HAqemP4cE81SQ6QO1-N85j5bF4C0qLs0?usp=sharing). If you just want to apply PerAct to your problem, then start with the notebook, otherwise this repo is for mostly reproducing  RLBench results from the paper. 

For the latest updates, see: [peract.github.io](https://peract.github.io)


## Guides

- Getting Started: [Installation](#installation), [Quickstart](#quickstart), [Checkpoints and Pre-Generated Datasets](#download), [Model Card](model-card.md)
- Data Generation: [Data Generation](#data-generation)
- Training & Evaluation: [Multi-Task Training and Evaluation](#training-and-evaluation), [Gotchas](#gotchas)
- Miscellaneous: [Recording Videos](#recording-videos), [Notebooks](#notebooks), [Disclaimers](#disclaimers-and-limitations), [FAQ](#faq), [Docker Guide](#docker-guide), [Licenses](#licenses)
- Acknowledgements: [Acknowledgements](#acknowledgements), [Citations](#citations)

## Hotfix :fire: 
- **Training Speed-Up and Storage Memory Reduction**: [Ishika](https://github.com/ishikasingh) found that switching from fp32 to fp16 for storing pickle files dramatically speeds-up training time and significantly reduces memory usage. Checkout her modifications to YARR [here](https://github.com/ishikasingh/YARR/blob/875f636d43032b883becaa2628429baf688b3c1d/yarr/replay_buffer/task_uniform_replay_buffer.py#L53).

## Installation

### Prerequisites

PerAct is built-off the [ARM repository](https://github.com/stepjam/ARM) by James et al. The prerequisites are the same as ARM. 

#### 1. Environment

```bash
# setup a virtualenv with whichever package manager you prefer
virtualenv -p $(which python3.8) --system-site-packages peract_env  
source peract_env/bin/activate
pip install --upgrade pip
```

#### 2. PyRep and Coppelia Simulator

Follow instructions from the official [PyRep](https://github.com/stepjam/PyRep) repo; reproduced here for convenience:

PyRep requires version **4.1** of CoppeliaSim. Download: 
- [Ubuntu 16.04](https://www.coppeliarobotics.com/files/CoppeliaSim_Edu_V4_1_0_Ubuntu16_04.tar.xz)
- [Ubuntu 18.04](https://www.coppeliarobotics.com/files/CoppeliaSim_Edu_V4_1_0_Ubuntu18_04.tar.xz)
- [Ubuntu 20.04](https://www.coppeliarobotics.com/files/CoppeliaSim_Edu_V4_1_0_Ubuntu20_04.tar.xz)

Once you have downloaded CoppeliaSim, you can pull PyRep from git:

```bash
cd <install_dir>
git clone https://github.com/stepjam/PyRep.git
cd PyRep
```

Add the following to your *~/.bashrc* file: (__NOTE__: the 'EDIT ME' in the first line)

```bash
export COPPELIASIM_ROOT=<EDIT ME>/PATH/TO/COPPELIASIM/INSTALL/DIR
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$COPPELIASIM_ROOT
export QT_QPA_PLATFORM_PLUGIN_PATH=$COPPELIASIM_ROOT
```

Remember to source your bashrc (`source ~/.bashrc`) or 
zshrc (`source ~/.zshrc`) after this.

**Warning**: CoppeliaSim might cause conflicts with ROS workspaces. 

Finally install the python library:

```bash
pip install -r requirements.txt
pip install .
```

You should be good to go!
You could try running one of the examples in the *examples/* folder.

If you encounter errors, please use the [PyRep issue tracker](https://github.com/stepjam/PyRep/issues).

#### 3. RLBench

PerAct uses my [RLBench fork](https://github.com/MohitShridhar/RLBench/tree/peract). 

```bash
cd <install_dir>
git clone -b peract https://github.com/MohitShridhar/RLBench.git # note: 'peract' branch

cd RLBench
pip install -r requirements.txt
# pip install .
python setup.py develop
```

For [running in headless mode](https://github.com/MohitShridhar/RLBench/tree/peract#running-headless), tasks setups, and other issues, please refer to the [official repo](https://github.com/stepjam/RLBench).

#### 4. YARR

PerAct uses my [YARR fork](https://github.com/MohitShridhar/YARR/tree/peract).

```bash
cd <install_dir>
git clone -b peract https://github.com/MohitShridhar/YARR.git # note: 'peract' branch

cd YARR
pip install -r requirements.txt
python setup.py develop
```

### PerAct Repo
Clone:
```bash
cd <install_dir>
git clone https://github.com/peract/peract.git
```

Install:
```bash
cd peract
pip install git+https://github.com/openai/CLIP.git
pip install -r requirements.txt

export PERACT_ROOT=$(pwd)  # mostly used as a reference point for tutorials
python setup.py develop
```

**Note**: You might need versions of `torch==1.7.1` and `torchvision==0.8.2` that are compatible with your CUDA and hardware. Later versions should also be fine (in theory). 


## Quickstart

A quick tutorial on evaluating a pre-trained multi-task agent.

Download a [pre-trained PerAct checkpoint](https://github.com/peract/peract/releases/download/v1.0.0/peract_600k.zip) trained with 100 demos per task (18 tasks in total):
```bash
cd $PERACT_ROOT
sh scripts/quickstart_download.sh
```

Generate a small `val` set of 10 episodes for `open_drawer` inside `$PERACT_ROOT/data`:
```bash
cd <install_dir>/RLBench/tools
python dataset_generator.py --tasks=open_drawer \
                            --save_path=$PERACT_ROOT/data/val \
                            --image_size=128,128 \
                            --renderer=opengl \
                            --episodes_per_task=10 \
                            --processes=1 \
                            --all_variations=True
```
This will take a few minutes to finish.

Evaluate the pre-trained PerAct agent:
```bash
cd $PERACT_ROOT
CUDA_VISIBLE_DEVICES=0 python eval.py \
    rlbench.tasks=[open_drawer] \
    rlbench.task_name='multi' \
    rlbench.demo_path=$PERACT_ROOT/data/val \
    framework.gpu=0 \
    framework.logdir=$PERACT_ROOT/ckpts/ \
    framework.start_seed=0 \
    framework.eval_envs=1 \
    framework.eval_from_eps_number=0 \
    framework.eval_episodes=10 \
    framework.csv_logging=True \
    framework.tensorboard_logging=True \
    framework.eval_type='last' \
    rlbench.headless=False
```
If you are on a headless machine, turn off the visualization with `headless=True`.

You can evaluate the same agent on other tasks. First generate a validation dataset like above (or [download a pre-generated dataset](#download)) and then run `eval.py`.

**Note:** The dowloaded checkpoint might not necessarily be the best one for a given task, it's simply the last checkpoint from training.

## Download

### Pre-Generated Datasets

We provide [pre-generated RLBench demonstrations](https://drive.google.com/drive/folders/0B2LlLwoO3nfZfkFqMEhXWkxBdjJNNndGYl9uUDQwS1pfNkNHSzFDNGwzd1NnTmlpZXR1bVE?resourcekey=0-jRw5RaXEYRLe2W6aNrNFEQ&usp=share_link) for train (100 episodes), validation (25 episodes), and test (25 episodes) splits used in the paper. If you directly use these datasets, you don't need to run `tools/data_generator.py` from RLBench. Using these datasets will also help reproducibility since each scene is randomly sampled in `data_generator.py`.

Is there one big zip file with all splits and tasks instead of individual files? No. My gDrive account will get rate-limited if everyone is directly downloading huge files. I recommend downloading through [rclone](https://rclone.org/drive/) with Google API Console enabled. The full dataset of zip files is ~116GB. 

### Pre-Trained Checkpoints

#### [PerAct - 2048 Latents](https://github.com/peract/peract/releases/download/v1.0.0/peract_600k.zip)
- ID: `seed0`
- Num Tasks: 18
- Training Demos: 100 episodes per task (each task includes all variations)
- Training Iterations: 600k
- Voxel Size: 100x100x100
- Cameras: `front`, `left_shoulder`, `right_shoulder`, `wrist`
- Latents: 2048
- Self-Attention Layers: 6
- Voxel Feature Dim: 64
- Data Augmentation: 45 deg yaw perturbations

#### [PerAct - 512 Latents](https://github.com/peract/peract/releases/download/v1.0.0/peract_600k_512latents.zip)
- ID: `seed5`
- Num Tasks: 18
- Training Demos: 100 episodes per task (each task includes all variations)
- Training Iterations: 600k
- Voxel Size: 100x100x100
- Cameras: `front`, `left_shoulder`, `right_shoulder`, `wrist`
- Latents: 512
- Self-Attention Layers: 6
- Voxel Feature Dim: 64

See [quickstart guide](#quickstart) on how to evaluate these checkpoints. Make sure `framework.start_seed` is set to the correct ID. 

## Data Generation

Data generation is pretty similar to the [ARM setup](https://github.com/stepjam/RLBench), except you use `--all_variations=True` to sample all task variations:

```bash
cd <install_dir>/RLBench/tools
python dataset_generator.py --tasks=open_drawer \
                            --save_path=$PERACT_ROOT/data/train \
                            --image_size=128,128 \
                            --renderer=opengl \
                            --episodes_per_task=100 \
                            --processes=1 \
                            --all_variations=True
```

You can run these in parallel for multiple tasks. Here is a list of 18 tasks used in the paper (in the same order as results Table 1):

```bash 
open_drawer
slide_block_to_color_target
sweep_to_dustpan_of_size
meat_off_grill
turn_tap
put_item_in_drawer
close_jar
reach_and_drag
stack_blocks
light_bulb_in
put_money_in_safe
place_wine_at_rack_location
put_groceries_in_cupboard
place_shape_in_shape_sorter
push_buttons
insert_onto_square_peg
stack_cups
place_cups
```

You can probably train PerAct on more RLBench tasks. These 18 tasks were hand-selected for their diversity in task variations and language instructions. 

**Warning**: Each scene generated with `data_generator.py` will use a different random seed to configure objects and states in the scene. This means you will get very different train, val, and test sets to the pre-generated ones. This should be fine for PerAct, but you will likely see small differences in evaluation performances. It's recommended to use the pre-generated datasets for reproducibility. Using larger test sets will also help. 

## Training and Evaluation

The following is a guide for training everything from scratch. All tasks follow a 4-phase workflow:
 
1. Generate `train`, `val`, `test` datasets with `data_generator.py` or download pre-generated datasets. 
2. Train agent with `train.py` and save 10K iteration checkpoints.
3. Run validation with `eval.py` with `framework.eval_type=missing` to find the best checkpoint on `val` tasks and save results in `eval_data.csv`.
4. Evaluate the best checkpoint in `eval_data.csv` on `test` tasks with `eval.py` and `framework.eval_type=best`. Save final results to `test_data.csv`. 


Make sure you have a `train`, `val`, and `test` set with sufficient demos for the tasks you want to train and evaluate on. 

### Training

Train a `PERACT_BC` agent with `100` demos per task for 600K iterations with 8 GPUs:

```bash
CUDA_VISIBLE_DEVICES=0,1,2,3,4,5,6,7 python train.py \
    method=PERACT_BC \
    rlbench.tasks=[close_jar,insert_onto_square_peg,light_bulb_in,meat_off_grill,open_drawer,place_cups,place_shape_in_shape_sorter,push_buttons,put_groceries_in_cupboard,put_item_in_drawer,put_money_in_safe,reach_and_drag,stack_blocks,stack_cups,turn_tap,place_wine_at_rack_location,slide_block_to_color_target,sweep_to_dustpan_of_size] \
    rlbench.task_name='multi_18T' \
    rlbench.cameras=[front,left_shoulder,right_shoulder,wrist] \
    rlbench.demos=100 \
    rlbench.demo_path=$PERACT_ROOT/data/train \
    replay.batch_size=1 \
    replay.path=/tmp/replay \
    replay.max_parallel_processes=32 \
    method.voxel_sizes=[100] \
    method.voxel_patch_size=5 \
    method.voxel_patch_stride=5 \
    method.num_latents=2048 \
    method.transform_augmentation.apply_se3=True \
    method.transform_augmentation.aug_rpy=[0.0,0.0,45.0] \
    method.pos_encoding_with_lang=True \
    framework.training_iterations=600000 \
    framework.num_weights_to_keep=60 \
    framework.start_seed=0 \
    framework.log_freq=1000 \
    framework.save_freq=10000 \
    framework.logdir=$PERACT_ROOT/logs/ \
    framework.csv_logging=True \
    framework.tensorboard_logging=True \
    ddp.num_devices=8
```

Make sure there is enough disk-space for `replay.path` and `framework.logdir`. Adjust `replay.max_parallel_processes` to fill the replay buffer in parallel based on your resources. You can also train on fewer GPUs, but training will take a long time to converge. 

To get started, you should probably train on a small number of `rlbench.tasks`. 

Use `tensorboard` to monitor training progress with logs inside `framework.logdir`.

### Validation

Evaluate `PERACT_BC` seed0 on 18 `val` tasks sequentially (slow!):

```bash
CUDA_VISIBLE_DEVICES=0 python eval.py \
    rlbench.tasks=[close_jar,insert_onto_square_peg,light_bulb_in,meat_off_grill,open_drawer,place_cups,place_shape_in_shape_sorter,push_buttons,put_groceries_in_cupboard,put_item_in_drawer,put_money_in_safe,reach_and_drag,stack_blocks,stack_cups,turn_tap,place_wine_at_rack_location,slide_block_to_color_target,sweep_to_dustpan_of_size] \
    rlbench.task_name='multi_18T' \
    rlbench.demo_path=$PERACT_ROOT/data/val \
    framework.logdir=$PERACT_ROOT/logs/ \
    framework.csv_logging=True \
    framework.tensorboard_logging=True \
    framework.eval_envs=4 \
    framework.start_seed=0 \
    framework.eval_from_eps_number=0 \
    framework.eval_episodes=25 \
    framework.eval_type='missing' \
    rlbench.headless=True
```

This script will slowly go through each 10K interval checkpoint and save success rates in `eval_data.csv`. To evaluate checkpoints in parallel use `framework.eval_envs` to start multiple processes.

### Testing

```bash
CUDA_VISIBLE_DEVICES=0 python eval.py \
    rlbench.tasks=[close_jar,insert_onto_square_peg,light_bulb_in,meat_off_grill,open_drawer,place_cups,place_shape_in_shape_sorter,push_buttons,put_groceries_in_cupboard,put_item_in_drawer,put_money_in_safe,reach_and_drag,stack_blocks,stack_cups,turn_tap,place_wine_at_rack_location,slide_block_to_color_target,sweep_to_dustpan_of_size] \
    rlbench.task_name='multi_18T' \
    rlbench.demo_path=$PERACT_ROOT/data/test \
    framework.logdir=$PERACT_ROOT/logs/ \
    framework.csv_logging=True \
    framework.tensorboard_logging=True \
    framework.eval_envs=1 \
    framework.start_seed=0 \
    framework.eval_from_eps_number=0 \
    framework.eval_episodes=25 \
    framework.eval_type='best' \
    rlbench.headless=True
```

The final results will be saved in `test_data.csv`.

### Baselines and Ablations

All agents reported in the paper are [here](https://github.com/peract/peract/tree/main/agents) along with their respective [config files](https://github.com/peract/peract/tree/main/conf/method):

|    **Code Name**   | **Paper Name** |
|:------------------:|:--------------:|
|      `PERACT_BC`   |     PerAct     |
|`C2FARM_LINGUNET_BC`|    C2FARM-BC   |
|    `VIT_BC_LANG`   | Image-BC (VIT) |
|      `BC_LANG`     | Image-BC (CNN) |

PerAct ablations are set with:

```bash
method.no_skip_connection: False
method.no_perceiver: False
method.no_language: False
method.keypoint_method: 'heuristic'
```

### Gotchas

#### OpenGL Errors

GL errors are probably being caused by the PyRender voxel visualizer. See this [issue](https://github.com/mmatl/pyrender/issues/86) for reference. You might have to set the following environment variables depending on your setup:

```bash
export DISPLAY=:0
export MESA_GL_VERSION_OVERRIDE=4.1
export PYOPENGL_PLATFORM=egl
```

#### Unpickling Error

If you see `_pickle.UnpicklingError: invalid load key, '\x9e'`, maybe one of the replay pickle files got corrupted when quitting the training script. Try deleting files in `replay.path` and restarting training.


## Recording Videos

To save high-resolution videos of agent executions, set `cinematic_recorder.enabled=True` with `eval.py`:

```bash
cd $PERACT_ROOT
CUDA_VISIBLE_DEVICES=0 python eval.py \
    rlbench.tasks=[open_drawer] \
    rlbench.task_name='multi' \
    rlbench.demo_path=$PERACT_ROOT/data/val \
    framework.gpu=0 \
    framework.logdir=$PERACT_ROOT/ckpts/ \
    framework.start_seed=0 \
    framework.eval_envs=1 \
    framework.eval_from_eps_number=0 \
    framework.eval_episodes=3 \
    framework.csv_logging=True \
    framework.tensorboard_logging=True \
    framework.eval_type='last' \
    rlbench.headless=True \
    cinematic_recorder.enabled=True
```

Videos will be saved at `$PERACT_ROOT/ckpts/multi/PERACT_BC/seed0/videos/open_drawer_w600000_s0_succ.mp4`.

**Note:** Rendering at high-resolutions is super slow and will take a long time to finish.

## Disclaimers and Limitations

- **Code quality level**: Desperate grad student. 
- **Why isn't your code more modular?**: My code, like this project, is end-to-end. 
- **Small test set**: The test set should be larger than just 25 episodes. If you parallelize the evaluation, you can easily evaluate on larger test sets and do multiple runs with different seeds.
- **Parallelization**: A lot of things (data generation, evaluation) are slow because everything is done serially. Parallelizing these processes will save you a lot of time. 
- **Impossible tasks**: Some tasks like `push_buttons` are not solvable by PerAct since it doesn't have any memory.
- **Switch from DP to DDP**: For the paper submission, I was using PyTorch DataParallel for multi-gpu training. For this code release, I switched to DistributedDataParallel. Hopefully, I didn't introduce any new bugs. 
- **Collision avoidance**: All simulated evaluations use V-REP's internal motion-planner with collision avoidance. For real-world experiments, you have to setup MoveIt to use the voxel grid for avoiding occupied voxels. 
- **YARR Modifications**: My changes to the YARR repo are a total mess. Sorry :(
- **LAMB Optimizer**: The LAMB implementation has some [issues](https://github.com/cybertronai/pytorch-lamb/issues/10) but still works 🤷. Maybe use [FusedLAMB](https://nvidia.github.io/apex/_modules/apex/optimizers/fused_lamb.html) instead. 
- **Other limitations**: See Appendix L of the paper for more details.

## FAQ

#### How much training data do I need for real-world tasks?

It depends on the complexity of the task. With 10-20 demonstrations the agent should start to do something useful, but it will often make mistakes by picking the wrong object. For robustness you probably need 50-100 demostrations. A good way to gauge how much data you might need is to setup a simulated version of the problem and evaluate agents trained with 10, 100, 250 demonstrations.

#### How long should I train the agent for? When will I start seeing good evaluation performance?
This depends on the number, complexity, and diversity of tasks, and also how much compute you have. Take a look at this [checkpoint folder](https://github.com/peract/peract/releases/download/v1.0.0/peract_600k.zip) containing `train_data.csv`, `eval_data.csv` and `test_data.csv`. These log files should 
give you a sense of what the training losses look like and what evaluation performances to expect. All multi-task agents in the paper were trained for 600K iterations, and single-task agents were trained for 40K iterations, all with 8-GPU setups.

#### Why doesn't the agent follow my language instruction?

This means either there is some sort of bias in the dataset that the agent is exploiting (e.g. always 'blue blocks'), or you don't have enough training data. Also make sure that the task is doable - if a referred attribute is barely legible in the voxel grid, then it's going to be hard for agent to figure out what you mean. 

#### How to pick the best checkpoint for real-robot tasks?

Ideally, you should create a validation set with heldout instances and then choose the checkpoint with the lowest translation and rotation errors. You can also reuse the training instances but swap the language instructions with unseen goals. But all real-world experiments in the paper simply chose the last checkpoint. 

#### Can you replace the motion-planner with a learnable module?

Yes, see [C2FARM+LPR](https://github.com/stepjam/ARM) by James et al. 

#### Why do I need to generate a `val` and `test` set?

Two reasons: (1) One-to-one comparisons between two agents. We can take an episode from the test dataset, and use its random seed to spawn the exact same objects and object pose configurations every time. (2) Checking if the task is actually solvable, at least by an expert. We don't want to evaluate on unsolvable task instances. See [issue3](https://github.com/peract/peract/issues/3) for reference.

#### Why are duplicate keyframes loaded into the replay buffer?

This is a design choice in [ARM (by James et al)](https://github.com/stepjam/ARM/blob/main/arm/c2farm/launch_utils.py#L161). I am guessing the keyframes get added several times because they indicate important "phase transitions" between trajectory bottlenecks, and having several copies makes them more likely to be sampled. See [issue6](https://github.com/peract/peract/issues/6#issuecomment-1355555980).

#### The training is too slow and the replay pickle files take up too much space. What should I do about this?

[Ishika](https://github.com/ishikasingh) found that switching from fp32 to fp16 for storing pickle files dramatically speeds-up training time and significantly reduces memory usage. Checkout her modifications to YARR [here](https://github.com/ishikasingh/YARR/blob/875f636d43032b883becaa2628429baf688b3c1d/yarr/replay_buffer/task_uniform_replay_buffer.py#L53).

#### Will you release your real-robot code for data-collection and execution?

Checkout [franka_htc_teleop.zip](https://github.com/peract/peract/files/11362196/franka_htc_teleop.zip) for real-robot code. `peract_demo_interface.py` is for collecting data, and `peract_agent_interface.py` is for executing trained models. The real-robot datasets are [here](https://drive.google.com/drive/folders/0B2LlLwoO3nfZfm45a0k5ZHVra0ZJZk1aTXVXWHFTY3J4YnRhR2d5c2t3NE9uLW5tU1VNVWs?resourcekey=0-yk89R3sWdmKkOtJX0GTNhA&usp=share_link). See [issue18](https://github.com/peract/peract/issues/18#issuecomment-1478827887) for more details on the setup, and [issue2](https://github.com/peract/peract/issues/2) for real-world setup details.

## Docker Guide

Coming soon...
 

## Notebooks

- [Colab Tutorial](https://colab.research.google.com/drive/1HAqemP4cE81SQ6QO1-N85j5bF4C0qLs0?usp=sharing): This tutorial is a good starting point for understanding the data-loading and training pipeline.
- Dataset Visualizer: Coming soon ... see [Colab](https://colab.research.google.com/drive/1HAqemP4cE81SQ6QO1-N85j5bF4C0qLs0?usp=sharing) for now.
- Q-Prediction Visualizer:  Coming soon ... see [Colab](https://colab.research.google.com/drive/1HAqemP4cE81SQ6QO1-N85j5bF4C0qLs0?usp=sharing) for now.
- Results Notebook: Coming soon ...


## Hardware Requirements

PerAct agents for the paper were trained with 8 P100 cards with 16GB of memory each. You can use fewer GPUs, but training will take a long time to converge.

Tested with:
- **GPU** - NVIDIA P100
- **CPU** - Intel Xeon (Quad Core)
- **RAM** - 32GB
- **OS** - Ubuntu 16.04, 18.04

For inference, a single GPU is sufficient.

## Acknowledgements

This repository uses code from the following open-source projects:

#### ARM 
Original:  [https://github.com/stepjam/ARM](https://github.com/stepjam/ARM)  
License: [ARM License](https://github.com/stepjam/ARM/LICENSE)    
Changes: Data loading was modified for PerAct. Voxelization code was modified for DDP training.

#### PerceiverIO
Original: [https://github.com/lucidrains/perceiver-pytorch](https://github.com/lucidrains/perceiver-pytorch)   
License: [MIT](https://github.com/lucidrains/perceiver-pytorch/blob/main/LICENSE)   
Changes: PerceiverIO adapted for 6-DoF manipulation.

#### ViT
Original: [https://github.com/lucidrains/vit-pytorch](https://github.com/lucidrains/vit-pytorch)     
License: [MIT](https://github.com/lucidrains/vit-pytorch/blob/main/LICENSE)   
Changes: ViT adapted for baseline.   

#### LAMB Optimizer
Original: [https://github.com/cybertronai/pytorch-lamb](https://github.com/cybertronai/pytorch-lamb)   
License: [MIT](https://github.com/cybertronai/pytorch-lamb/blob/master/LICENSE)   
Changes: None.

#### OpenAI CLIP

Original: [https://github.com/openai/CLIP](https://github.com/openai/CLIP)  
License: [MIT](https://github.com/openai/CLIP/blob/main/LICENSE)  
Changes: Minor modifications to extract token and sentence features.

Thanks for open-sourcing! 

## Licenses
- [PerAct License (Apache 2.0)](LICENSE) - Perceiver-Actor Transformer
- [ARM License](ARM_LICENSE) - Voxelization and Data Preprocessing 
- [YARR Licence (Apache 2.0)](https://github.com/stepjam/YARR/blob/main/LICENSE)
- [RLBench Licence](https://github.com/stepjam/RLBench/blob/master/LICENSE)
- [PyRep License (MIT)](https://github.com/stepjam/PyRep/blob/master/LICENSE)
- [Perceiver PyTorch License (MIT)](https://github.com/lucidrains/perceiver-pytorch/blob/main/LICENSE)
- [LAMB License (MIT)](https://github.com/cybertronai/pytorch-lamb/blob/master/LICENSE)
- [CLIP License (MIT)](https://github.com/openai/CLIP/blob/main/LICENSE)

## Release Notes

**Update 23-Nov-2022**
- I ditched PyTorch Lightning and implemented multi-gpu training directly with Pytorch DDP. I could have introduced some bugs during this transition and from refactoring the repo in general. 

**Update 31-Oct-2022**:
- I have pushed my changes to [RLBench](https://github.com/MohitShridhar/RLBench/tree/peract) and [YARR](https://github.com/MohitShridhar/YARR/tree/peract). The data generation is pretty similar to [ARM](https://github.com/stepjam/ARM#running-experiments), except you run `data_generator.py` with `--all_variations=True`. You should be able to use these generated datasets with the [Colab](https://colab.research.google.com/drive/1HAqemP4cE81SQ6QO1-N85j5bF4C0qLs0?usp=sharing) code.  
- For the paper, I was using PyTorch DataParallel to train on multiple GPUs. This made the code very messy and brittle. I am currently [stuck](https://github.com/Lightning-AI/lightning/issues/10098) cleaning this up with DDP and PyTorch Lightning. So the code release might be a bit delayed. Apologies.


## Citations 

**PerAct**
```
@inproceedings{shridhar2022peract,
  title     = {Perceiver-Actor: A Multi-Task Transformer for Robotic Manipulation},
  author    = {Shridhar, Mohit and Manuelli, Lucas and Fox, Dieter},
  booktitle = {Proceedings of the 6th Conference on Robot Learning (CoRL)},
  year      = {2022},
}
```

**C2FARM**
```
@inproceedings{james2022coarse,
  title={Coarse-to-fine q-attention: Efficient learning for visual robotic manipulation via discretisation},
  author={James, Stephen and Wada, Kentaro and Laidlow, Tristan and Davison, Andrew J},
  booktitle={Proceedings of the IEEE/CVF Conference on Computer Vision and Pattern Recognition},
  pages={13739--13748},
  year={2022}
}
```

**PerceiverIO**
```
@article{jaegle2021perceiver,
  title={Perceiver io: A general architecture for structured inputs \& outputs},
  author={Jaegle, Andrew and Borgeaud, Sebastian and Alayrac, Jean-Baptiste and Doersch, Carl and Ionescu, Catalin and Ding, David and Koppula, Skanda and Zoran, Daniel and Brock, Andrew and Shelhamer, Evan and others},
  journal={arXiv preprint arXiv:2107.14795},
  year={2021}
}
```


**RLBench**
```
@article{james2020rlbench,
  title={Rlbench: The robot learning benchmark \& learning environment},
  author={James, Stephen and Ma, Zicong and Arrojo, David Rovick and Davison, Andrew J},
  journal={IEEE Robotics and Automation Letters},
  volume={5},
  number={2},
  pages={3019--3026},
  year={2020},
  publisher={IEEE}
}
```

## Questions or Issues?

Please file an issue with the issue tracker.  

# 笔记
## 安装
### 1.python环境
```bash
git clone https://github.com/kaixin-bai/peract.git
cd peract/
conda create -n peract python=3.8
conda activate peract
conda install pytorch==1.12.1 torchvision==0.13.1 cudatoolkit=11.3 -c pytorch
```
### 2.所有依赖项安装
确认系统的ubuntu版本：
```bash
$ lsb_release -a
    No LSB modules are available.                                                                                                                                                                                      
    Distributor ID: Ubuntu                                                                                                                                                                                             
    Description:    Ubuntu 18.04.6 LTS                                                                                                                                                                                 
    Release:        18.04                                                                                                                                                                                              
    Codename:       bionic  
```

#### CoppeliaSim
根据确定的ubuntu版本下载和安装[version 4.1 of CoppeliaSim](https://www.coppeliarobotics.com/files/CoppeliaSim_Edu_V4_1_0_Ubuntu18_04.tar.xz)  \
在项目中新建文件夹`thirdparty`，将下载的`CoppeliaSim`解压在此文件夹内.
```bash
cd peract/thirdparty/
wget --no-check-certificate https://www.coppeliarobotics.com/files/CoppeliaSim_Edu_V4_1_0_Ubuntu18_04.tar.xz
tar -xvf CoppeliaSim_Edu_V4_1_0_Ubuntu18_04.tar.xz -C ./
rm CoppeliaSim_Edu_V4_1_0_Ubuntu18_04.tar.xz
```

#### PyRep
下载`PyRep`:
```bash
cd peract/thirdparty/
git clone https://github.com/stepjam/PyRep.git
cd PyRep
```
在`~/.bashrc`中添加以下内容：
```bash
# 更换此处路径为coppeliasim的路径
# 在gpu01上是`/home/kb/MyProjects/peract/thirdparty/CoppeliaSim_Edu_V4_1_0_Ubuntu18_04/`
# 在本机上是`/home/kb/gpu02kb/peract/thirdparty/CoppeliaSim_Edu_V4_1_0_Ubuntu18_04`
export COPPELIASIM_ROOT=<EDIT ME>/PATH/TO/COPPELIASIM/INSTALL/DIR  
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$COPPELIASIM_ROOT
export QT_QPA_PLATFORM_PLUGIN_PATH=$COPPELIASIM_ROOT
export PERACT_ROOT=/home/kb/gpu02kb/peract  # 这个一定要加上，因为后面训练要这个环境变量！

# 以下为与显示相关的环境变量，请只添加在服务器上！本地请不要添加！
export DISPLAY=:0
export MESA_GL_VERSION_OVERRIDE=4.1
export PYOPENGL_PLATFORM=egl
```
```bash
source ~/.bashrc
conda activate peract
```
安装剩下的python依赖项：
```bash
cd PyRep
pip3 install absl-py==0.15.0 einops==0.3.2 ftfy gdown==3.13.1 hydra-core==1.0.5 matplotlib numpy==1.21 packaging==21.3 pandas==1.4.1 pyrender==0.1.45 pytorch3d==0.3.0 regex scipy==1.4.1 tensorboard transformers==4.3.2 trimesh==3.9.34
pip install .
```

#### peract
安装`peract`：
```bash
cd peract
pip3 install .  # setup.py是被修改过的！取消了去安装requirements.txt里面的依赖项
```

#### RLBench
安装RLBench：  \
这个requirements里面没有什么特别的，可以直接安装。
```bash
cd peract/thirdparty/
git clone -b peract https://github.com/MohitShridhar/RLBench.git # note: 'peract' branch
cd RLBench
pip install -r requirements.txt
# pip install .
python setup.py develop
```

#### YARR
安装YARR：  \
这个requirements里面没有什么特别的，可以直接安装。
```bash
cd peract/thirdparty/
git clone -b peract https://github.com/MohitShridhar/YARR.git # note: 'peract' branch
cd YARR
pip install -r requirements.txt
pip install .  # 之前是python setup.py develop,但是会报错
```
PerAct Repo
```bash
cd peract/thirdparty/
pip install git+https://github.com/openai/CLIP.git
# pip install -r requirements.txt  不要安装
pip install ftfy regex tqdm
```
```bash
cd peract/
export PERACT_ROOT=$(pwd)  # mostly used as a reference point for tutorials # /home/kb/MyProjects/peract/
# pip install .
python setup.py develop
```

### 3.下载PerAct checkpoint
```bash
cd $PERACT_ROOT # /home/kb/MyProjects/peract/
sh scripts/quickstart_download.sh  # 这个文件是我们修改过的
```

## 测试
注意：因为我们要同时在本地和服务器上运行，所以我修改了软链接的部分！  \
在本地或者服务器运行时，无论是训练还是测试，请先运行如下命令：
```bash
创建指向服务器路径的软链接：sh setup_soft_link.sh --server
创建指向本地路径的软链接：sh setup_soft_link.sh --local
```
### 1.generate a small evaluation dataset
有18个任务可供选择：
```bash
open_drawer
slide_block_to_color_target
sweep_to_dustpan_of_size
meat_off_grill
turn_tap
put_item_in_drawer
close_jar
reach_and_drag
stack_blocks
light_bulb_in
put_money_in_safe
place_wine_at_rack_location
put_groceries_in_cupboard
place_shape_in_shape_sorter
push_buttons
insert_onto_square_peg
stack_cups
place_cups
```
以下命令会在`peract/data/val/`下新建一个`open_drawer`，并在其中生成不同视角不同位置的任务进行中的图片。
```bash
cd <install_dir>/RLBench/tools
python dataset_generator.py --tasks=sweep_to_dustpan_of_size \
                            --save_path=$PERACT_ROOT/data/val \
                            --image_size=128,128 \
                            --renderer=opengl \
                            --episodes_per_task=10 \
                            --processes=1 \
                            --all_variations=True
```
### 2.evaluating a pre-trained multi-task agent
会启动软件，并在软件中执行机器人操作。如果上面没有生成数据集，这一步是不会有操作执行的。
```bash
cd $PERACT_ROOT  # 即/peract/文件夹
CUDA_VISIBLE_DEVICES=0 python eval.py \
    rlbench.tasks=[open_drawer] \
    rlbench.task_name='multi' \
    rlbench.demo_path=$PERACT_ROOT/data/val \
    framework.gpu=0 \
    framework.logdir=$PERACT_ROOT/ckpts/ \
    framework.start_seed=0 \
    framework.eval_envs=1 \
    framework.eval_from_eps_number=0 \
    framework.eval_episodes=10 \
    framework.csv_logging=True \
    framework.tensorboard_logging=True \
    framework.eval_type='last' \
    rlbench.headless=False
```

## 训练准备
注意：因为我们要同时在本地和服务器上运行，所以我修改了软链接的部分！  \
在本地或者服务器运行时，无论是训练还是测试，请先运行如下命令：
```bash
创建指向服务器路径的软链接：sh setup_soft_link.sh --server
创建指向本地路径的软链接：sh setup_soft_link.sh --local
```
### 训练集的下载
```bash
# 所有内容所在文件夹
https://drive.google.com/drive/folders/0B2LlLwoO3nfZfkFqMEhXWkxBdjJNNndGYl9uUDQwS1pfNkNHSzFDNGwzd1NnTmlpZXR1bVE?resourcekey=0-jRw5RaXEYRLe2W6aNrNFEQ
# train文件夹
https://drive.google.com/drive/folders/0B2LlLwoO3nfZfi1LbGJINXJ1TUQxN1pxa3Q1MzlDZmY0WGk1RmhxazZvNFEydUREbXM4cTA?resourcekey=0-DpkG5eIqkwjKJ84qFcaUfw&usp=drive_link
# test文件夹
https://drive.google.com/drive/folders/0B2LlLwoO3nfZfnJnSmNHTXZycUtFN0k3Y3o2SjlvWUg1WHRkU1Y2OE1wdkN6V1BkRGF6MG8?resourcekey=0-4V4AQmv6RCytSv0_ua2HKg&usp=drive_link
# val文件夹
https://drive.google.com/drive/folders/0B2LlLwoO3nfZfjZVeEkydnAxZWhfTlp4RG9icHQwa3lqVFdlNXoyNExRUnpwOGtqRmY0aEE?resourcekey=0-7XAtiOBiw9bMclxyOqUeXA&usp=drive_link
```
将下载好的内容放置于以下文件夹中：
```bash
- /data/
  - /data/train/
```
选择你要训练的数据集，在文件夹内进行解压，比如：
```bash
cd peract/data/train/
unzip close_jar-003.zip
```
#### 训练集内容解析
以`close_jar`为例，数据集的结构如下：     \
```bash
- close_jar
  - all_variations
    - episodes
      - episode0  -- episode99
```
在`episode`文件夹中：  \
在0文件夹中，是给红色瓶子拧瓶盖，在1文件夹中，是给绿色瓶子拧瓶盖。
```bash
- episode0
  - front_rgb/           : 均是0.png到172.png (128, 128, 3), 0-255的三通道图片
  - front_depth/         : 深度图很奇怪，虽然也是三通到的，但是看起来就像电脑花屏了一样，TODO:这个有什么说法吗？
  - front_mask/          : mask也是三通道，mask都在第一个通道，后面两个通道都是0

  - left_shoulder_rgb/  
  - left_shoulder_depth/
  - left_shoulder_mask/   
  
  - overhead_rgb/  
  - overhead_depth/    
  - overhead_mask/
  
  - right_shoulder_rgb/
  - right_shoulder_depth/
  - right_shoulder_mask/
  
  - wrist_rgb/ 
  - wrist_depth/    
  - wrist_mask/

  - variation_descriptions.pkl
  - low_dim_obs.pkl    
  - variation_number.pkl
```
- 在`variation_descriptions.pkl`中的内容是：
```bash
['close the red jar',
 'screw on the red jar lid',
 'grasping the lid, lift it from the table and use it to seal the red jar',
 'pick up the lid from the table and put it on the red jar']
```
- 在`variation_number.pkl`中的内容是：
```bash
0
```
- 在`low_dim_obs.pkl`中的内容是：
```bash
In [1]: import pickle

In [2]: pkl_file_path = "low_dim_obs.pkl"

In [3]: # Load and print the content
   ...: with open(pkl_file_path, 'rb') as file:
   ...:     data = pickle.load(file)
   ...:     print(data)
   ...: 
<rlbench.demo.Demo object at 0x7f7041064790>

In [4]: print(dir(data))
['__class__', '__delattr__', '__dict__', '__dir__', '__doc__', '__eq__', '__format__', '__ge__', '__getattribute__', '__getitem__', '__gt__', '__hash__', '__init__', '__init_subclass__', '__le__', '__len__', '__lt__', '__module__', '__ne__', '__new__', '__reduce__', '__reduce_ex__', '__repr__', '__setattr__', '__sizeof__', '__str__', '__subclasshook__', '__weakref__', '_observations', 'random_seed', 'restore_state', 'variation_number']
```

### 训练
```bash
CUDA_VISIBLE_DEVICES=0 python train.py \
    method=PERACT_BC \
    rlbench.tasks=[close_jar] \
    rlbench.task_name='multi_18T' \
    rlbench.cameras=[front,left_shoulder,right_shoulder,wrist] \
    rlbench.demos=100 \
    rlbench.demo_path=$PERACT_ROOT/data/train \
    replay.batch_size=1 \
    replay.path=/tmp/replay \
    replay.max_parallel_processes=32 \
    method.voxel_sizes=[100] \
    method.voxel_patch_size=5 \
    method.voxel_patch_stride=5 \
    method.num_latents=2048 \
    method.transform_augmentation.apply_se3=True \
    method.transform_augmentation.aug_rpy=[0.0,0.0,45.0] \
    method.pos_encoding_with_lang=True \
    framework.training_iterations=600000 \
    framework.num_weights_to_keep=60 \
    framework.start_seed=0 \
    framework.log_freq=1000 \
    framework.save_freq=10000 \
    framework.logdir=$PERACT_ROOT/logs/ \
    framework.csv_logging=True \
    framework.tensorboard_logging=True \
    ddp.num_devices=8
```

---
# 所遇到的问题整理
1.在服务器上训练时报错：
```bash
INFO:root:Loading Demo(91) - found 6 keypoints - close_jar
INFO:root:Loading Demo(92) - found 6 keypoints - close_jar
INFO:root:Loading Demo(93) - found 6 keypoints - close_jar
INFO:root:Loading Demo(94) - found 6 keypoints - close_jar
INFO:root:Loading Demo(95) - found 6 keypoints - close_jar
INFO:root:Loading Demo(96) - found 6 keypoints - close_jar
INFO:root:Loading Demo(97) - found 6 keypoints - close_jar
INFO:root:Loading Demo(98) - found 6 keypoints - close_jar
INFO:root:Loading Demo(99) - found 6 keypoints - close_jar
INFO:root:# Q Params: 33240669
/home/kb/MyProjects/peract/agents/peract_bc/qattention_peract_bc_agent.py:52: UserWarning: __floordiv__ is deprecated, and its behavior will change in a future version of pytorch. It currently rounds toward 0 (like the 'trunc' function NOT 'floor'). This results in incorrect rounding for negative values. To keep the current behavior, use torch.div(a, b, rounding_mode='trunc'), or for actual floor division, use torch.div(a, b, rounding_mode='floor').
  indices = torch.cat([((idxs // h) // d), (idxs // h) % w, idxs % w], 1)
INFO:torch.nn.parallel.distributed:Reducer buckets have been rebuilt in this iteration.
Traceback (most recent call last):
  File "train.py", line 79, in main
    mp.spawn(run_seed_fn.run_seed,
  File "/home/kb/anaconda3/envs/peract/lib/python3.8/site-packages/torch/multiprocessing/spawn.py", line 240, in spawn
    return start_processes(fn, args, nprocs, join, daemon, start_method='spawn')
  File "/home/kb/anaconda3/envs/peract/lib/python3.8/site-packages/torch/multiprocessing/spawn.py", line 198, in start_processes
    while not context.join():
  File "/home/kb/anaconda3/envs/peract/lib/python3.8/site-packages/torch/multiprocessing/spawn.py", line 160, in join
    raise ProcessRaisedException(msg, error_index, failed_process.pid)
torch.multiprocessing.spawn.ProcessRaisedException: 

-- Process 0 terminated with the following error:
Traceback (most recent call last):
  File "/home/kb/anaconda3/envs/peract/lib/python3.8/site-packages/torch/multiprocessing/spawn.py", line 69, in _wrap
    fn(i, *args)
  File "/home/kb/MyProjects/peract/run_seed_fn.py", line 158, in run_seed
    train_runner.start()
  File "/home/kb/anaconda3/envs/peract/lib/python3.8/site-packages/yarr/runners/offline_train_runner.py", line 145, in start
    agent_summaries = self._agent.update_summaries()
  File "/home/kb/MyProjects/peract/helpers/preprocess_agent.py", line 80, in update_summaries
    sums.extend(self._pose_agent.update_summaries())
  File "/home/kb/MyProjects/peract/agents/peract_bc/qattention_stack_agent.py", line 98, in update_summaries
    summaries.extend(qa.update_summaries())
  File "/home/kb/MyProjects/peract/agents/peract_bc/qattention_peract_bc_agent.py", line 617, in update_summaries
    transforms.ToTensor()(visualise_voxel(
  File "/home/kb/MyProjects/peract/helpers/utils.py", line 234, in visualise_voxel
    r = offscreen_renderer or pyrender.OffscreenRenderer(
  File "/home/kb/anaconda3/envs/peract/lib/python3.8/site-packages/pyrender/offscreen.py", line 31, in __init__
    self._create()
  File "/home/kb/anaconda3/envs/peract/lib/python3.8/site-packages/pyrender/offscreen.py", line 149, in _create
    self._platform.init_context()
  File "/home/kb/anaconda3/envs/peract/lib/python3.8/site-packages/pyrender/platforms/pyglet_platform.py", line 50, in init_context
    self._window = pyglet.window.Window(config=conf, visible=False,
  File "/home/kb/anaconda3/envs/peract/lib/python3.8/site-packages/pyglet/window/xlib/__init__.py", line 133, in __init__
    super(XlibWindow, self).__init__(*args, **kwargs)
  File "/home/kb/anaconda3/envs/peract/lib/python3.8/site-packages/pyglet/window/__init__.py", line 513, in __init__
    display = pyglet.canvas.get_display()
  File "/home/kb/anaconda3/envs/peract/lib/python3.8/site-packages/pyglet/canvas/__init__.py", line 59, in get_display
    return Display()
  File "/home/kb/anaconda3/envs/peract/lib/python3.8/site-packages/pyglet/canvas/xlib.py", line 88, in __init__
    raise NoSuchDisplayException(f'Cannot connect to "{name}"')
pyglet.canvas.xlib.NoSuchDisplayException: Cannot connect to "None"


Set the environment variable HYDRA_FULL_ERROR=1 for a complete stack trace.
```
分析：在报错中看到如下信息，是由于pyglet尝试连接到一个`X server`，但是失败了，pyglet和pyrender一起用来进行离屏渲染，这是因为我们用的是headless环境进行的训练。
```bash
pyglet.canvas.xlib.NoSuchDisplayException: Cannot connect to "None"
```
解决：在原始repo中提到在这种情况下修改与显示相关的环境变量如下：
```bash
export DISPLAY=:0
export MESA_GL_VERSION_OVERRIDE=4.1
export PYOPENGL_PLATFORM=egl
```