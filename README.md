# HIT-CV-3DGS

本仓库把课程实验涉及的 3D Gaussian Splatting 材料整理成一条可执行管线：

```text
环境准备 -> 获取代码和子模块 -> 准备视频/图片 -> FFmpeg 抽帧 -> COLMAP 稀疏重建 -> 3DGS 训练 -> 渲染和指标评估 -> SuperSplat/SIBR 可视化 -> 参数对比 -> 实验报告
```

默认实验环境按 Ubuntu 服务器 + NVIDIA L40S 组织。Windows 配置附件保留在 `docs/source/`，主要作为老师原始材料和排错参考。

## 需要下载或安装的东西

| 类型 | 必需 | 说明 |
| --- | --- | --- |
| NVIDIA Driver | 是 | 服务器需要能正常运行 `nvidia-smi` |
| CUDA Toolkit | 是 | 用于编译 3DGS CUDA 扩展，建议和 PyTorch CUDA 主版本接近 |
| Git | 是 | 拉取本仓库、官方 3DGS、COLMAP、gsplat 等 submodule |
| Miniconda/Anaconda | 是 | 管理 Python、PyTorch、CUDA 依赖 |
| FFmpeg | 是 | 从视频抽帧 |
| COLMAP | 是 | 从多视角图片估计相机和稀疏点云 |
| ImageMagick | 可选 | `convert.py --resize` 时用于生成多尺度图片 |
| 自采视频或图片 | 是 | 实验输入数据 |
| SuperSplat | 可选 | 在线查看 `point_cloud.ply`，打开 <https://superspl.at/editor> 即可 |
| SIBR Viewer | 可选 | 官方实时查看器，Ubuntu 需要额外编译 |

Ubuntu 常用系统依赖：

```bash
sudo apt update
sudo apt install -y git ffmpeg colmap imagemagick build-essential cmake ninja-build
```

如果服务器没有 Conda，可以安装 Miniconda：

```bash
wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
bash Miniconda3-latest-Linux-x86_64.sh
source ~/.bashrc
conda --version
```

如果 `apt` 装不到 COLMAP，可以在 Conda 环境里尝试：

```bash
conda install -c conda-forge colmap
```

## 0. 获取本仓库

```bash
git clone --recurse-submodules https://github.com/Cat-blizzard/HIT-CV-3DGS.git
cd HIT-CV-3DGS
```

如果已经 clone 过但 submodule 没拉全：

```bash
git submodule update --init third_party/gaussian-splatting third_party/colmap third_party/gsplat
```

官方 3DGS 训练还需要它自己的 CUDA 子模块，后面的环境脚本会自动拉取：

```text
third_party/gaussian-splatting/submodules/diff-gaussian-rasterization
third_party/gaussian-splatting/submodules/simple-knn
third_party/gaussian-splatting/submodules/fused-ssim
```

## 1. 配环境

推荐直接跑仓库脚本：

```bash
bash scripts/setup_gaussian_splatting_ubuntu.sh
conda activate gaussian_splatting
```

这个脚本会做三件事：

1. 初始化官方 3DGS 的训练必需子模块。
2. 用 `environment/gaussian_splatting_ubuntu.yml` 创建或更新 `gaussian_splatting` 环境。
3. 编译安装 `diff-gaussian-rasterization`、`simple-knn`、`fused-ssim` 三个 CUDA 扩展。

环境验证命令：

```bash
python - <<'PY'
import torch
print("torch:", torch.__version__)
print("torch cuda:", torch.version.cuda)
print("cuda available:", torch.cuda.is_available())
if torch.cuda.is_available():
    print("gpu:", torch.cuda.get_device_name(0))

import diff_gaussian_rasterization
import simple_knn._C
import fused_ssim
print("3DGS extensions import OK")
PY
```

如果这里失败，先不要训练。优先检查 `nvidia-smi`、`nvcc --version`、PyTorch CUDA 版本和编译器。

## 2. 准备数据

推荐目录：

```text
data/<scene>/
  input/      原始抽帧图片
  images/     convert.py 生成的去畸变图片
  sparse/0/   COLMAP 输出的 cameras.bin、images.bin、points3D.bin
```

从视频抽帧：

```bash
bash scripts/preprocess_video.sh /path/to/my_scene.mp4 my_scene 2
```

上面命令会把视频按 `fps=2` 抽到：

```text
data/my_scene/input/%06d.jpg
```

如果已经有图片，不需要 FFmpeg：

```bash
mkdir -p data/my_scene/input
cp /path/to/images/*.jpg data/my_scene/input/
```

第一次实验建议控制在 80 到 200 张图，先跑通流程，再提高抽帧密度。

## 3. COLMAP 转换成 3DGS 数据集

```bash
conda activate gaussian_splatting
cd third_party/gaussian-splatting
python convert.py -s ../../data/my_scene --colmap_executable colmap
cd ../..
```

如果需要生成 1/2、1/4、1/8 多尺度图片，加 `--resize`：

```bash
cd third_party/gaussian-splatting
python convert.py -s ../../data/my_scene --colmap_executable colmap --resize
cd ../..
```

转换成功后应看到：

```text
data/my_scene/images/
data/my_scene/sparse/0/cameras.bin
data/my_scene/sparse/0/images.bin
data/my_scene/sparse/0/points3D.bin
```

## 4. 训练 baseline

建议训练时加 `--eval`，这样后面能计算测试集指标。

```bash
conda activate gaussian_splatting
cd third_party/gaussian-splatting
python train.py \
  -s ../../data/my_scene \
  -m ../../outputs/my_scene/baseline \
  --eval \
  --iterations 30000
cd ../..
```

训练输出重点看：

```text
outputs/my_scene/baseline/cfg_args
outputs/my_scene/baseline/point_cloud/iteration_30000/point_cloud.ply
```

## 5. 渲染和计算指标

```bash
conda activate gaussian_splatting
cd third_party/gaussian-splatting
python render.py -m ../../outputs/my_scene/baseline
python metrics.py -m ../../outputs/my_scene/baseline
cd ../..
```

报告里至少记录三组测试视角的渲染图、真实图、PSNR、SSIM，并解释视觉效果和指标是否一致。

## 6. 可视化

最省事的方式是 SuperSplat：

1. 打开 <https://superspl.at/editor>
2. 导入训练输出：

```text
outputs/my_scene/baseline/point_cloud/iteration_30000/point_cloud.ply
```

SIBR Viewer 是官方实时查看器。Ubuntu 下需要额外拉取和编译：

```bash
git -C third_party/gaussian-splatting submodule update --init SIBR_viewers
```

具体编译命令以 `third_party/gaussian-splatting/README.md` 的 SIBR 部分为准。课程实验截图优先用 SuperSplat 就够用。

## 7. 参数对比实验

老师要求至少改两组关键参数。推荐保留 `baseline`，再跑下面三组里任选两组。

低迭代数对比：

```bash
cd third_party/gaussian-splatting
python train.py \
  -s ../../data/my_scene \
  -m ../../outputs/my_scene/iter_7000 \
  --eval \
  --iterations 7000
python render.py -m ../../outputs/my_scene/iter_7000
python metrics.py -m ../../outputs/my_scene/iter_7000
cd ../..
```

降低 densify 阈值，观察细节、高斯数量、显存和耗时变化：

```bash
cd third_party/gaussian-splatting
python train.py \
  -s ../../data/my_scene \
  -m ../../outputs/my_scene/densify_low \
  --eval \
  --densify_grad_threshold 0.0001
python render.py -m ../../outputs/my_scene/densify_low
python metrics.py -m ../../outputs/my_scene/densify_low
cd ../..
```

降低初始位置学习率，适合相机轨迹不稳定或场景尺度较大的情况：

```bash
cd third_party/gaussian-splatting
python train.py \
  -s ../../data/my_scene \
  -m ../../outputs/my_scene/pos_lr_low \
  --eval \
  --position_lr_init 0.00008
python render.py -m ../../outputs/my_scene/pos_lr_low
python metrics.py -m ../../outputs/my_scene/pos_lr_low
cd ../..
```

把结果记录到：

```text
experiments/params.example.csv
docs/03-report-template.md
```

## 8. 一键跑完整流程

最推荐使用这个脚本，它会从环境配置、数据准备、COLMAP、训练、渲染、指标评估一路跑完：

```bash
DATASET_NAME=my_scene \
VIDEO_PATH=/path/to/my_scene.mp4 \
FPS=2 \
bash scripts/run_all_ubuntu.sh
```

如果输入是一组照片：

```bash
DATASET_NAME=my_scene \
IMAGE_DIR=/path/to/images \
bash scripts/run_all_ubuntu.sh
```

如果环境已经配好，不想重新创建/更新 Conda 环境：

```bash
DATASET_NAME=my_scene \
VIDEO_PATH=/path/to/my_scene.mp4 \
RUN_SETUP=0 \
bash scripts/run_all_ubuntu.sh
```

如果要把报告要求的参数对比也一并跑完：

```bash
DATASET_NAME=my_scene \
VIDEO_PATH=/path/to/my_scene.mp4 \
RUN_COMPARISONS=1 \
bash scripts/run_all_ubuntu.sh
```

脚本输出：

```text
outputs/my_scene/baseline/                      baseline 模型
outputs/my_scene/iter_7000/                     低迭代对比，RUN_COMPARISONS=1 时生成
outputs/my_scene/densify_low/                   densify 阈值对比，RUN_COMPARISONS=1 时生成
outputs/my_scene/pos_lr_low/                    位置学习率对比，RUN_COMPARISONS=1 时生成
outputs/my_scene/_logs/                         每一步日志
outputs/my_scene/RUN_SUMMARY.md                 本轮实验摘要
```

完整参数可看：

```bash
bash scripts/run_all_ubuntu.sh --help
```

下面这个旧脚本适合环境已经配好、只想跑 baseline 的简化流程。

如果环境已经配好，并且输入是视频，可以直接跑：

```bash
DATASET_NAME=my_scene \
VIDEO_PATH=/path/to/my_scene.mp4 \
FPS=2 \
MODEL_NAME=baseline \
ITERATIONS=30000 \
bash scripts/run_pipeline_template.sh
```

如果只想复用已有 `data/my_scene/input/`，不重新抽帧：

```bash
DATASET_NAME=my_scene \
MODEL_NAME=baseline \
ITERATIONS=30000 \
bash scripts/run_pipeline_template.sh
```

该脚本依次执行：

```text
可选 FFmpeg 抽帧 -> convert.py -> train.py --eval -> render.py -> metrics.py
```

## 资源对应关系

| 资源 | 本仓库位置 | 用途 |
| --- | --- | --- |
| graphdeco-inria/gaussian-splatting | `third_party/gaussian-splatting` | 主实验代码：`convert.py`、`train.py`、`render.py`、`metrics.py` |
| colmap/colmap | `third_party/colmap` | COLMAP 源码参考。实际实验优先用服务器已安装的 `colmap` 命令 |
| nerfstudio-project/gsplat | `third_party/gsplat` | 现代 CUDA Gaussian rasterization 库，用于拓展理解和对比，不是老师主流程必需项 |
| SuperSplat | <https://superspl.at/editor> | 在线查看训练输出的 `point_cloud.ply` |
| 本地 `D:\simple-knn` | `third_party/simple-knn-local` | 本地源码备份，仅保留源码和许可证，排除了 Windows 编译产物 |
| 老师 Word 文档 | `docs/source/` | 原始指导书和 Windows 环境配置附件 |

## 目录说明

```text
docs/                 实验梳理、流程、报告模板、老师原始附件
environment/          Ubuntu/L40S 环境参考文件
scripts/              初始化、抽帧、训练、评估脚本模板
third_party/          外部仓库 submodule 和本地 simple-knn 源码备份
data/                 本地数据集目录，不提交大文件
outputs/              本地训练输出目录，不提交模型和渲染结果大文件
experiments/          参数对比记录表和实验记录模板
```

更细的实验说明见 `docs/01-experiment-workflow.md`，报告结构见 `docs/03-report-template.md`。
