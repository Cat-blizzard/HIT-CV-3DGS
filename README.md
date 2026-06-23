# HIT-CV-3DGS

本仓库把课程实验涉及的 3D Gaussian Splatting 材料整理成一条可执行主线：自定义数据采集 -> COLMAP 稀疏重建 -> 3DGS 训练 -> 渲染和指标评估 -> SuperSplat/SIBR 可视化 -> 参数对比和实验报告。

环境配置不是这个仓库的重点。默认按 Ubuntu 服务器 + NVIDIA L40S 使用场景组织，Windows 文档保留在 `docs/source/` 作为老师原始附件。

## 资源对应关系

| 资源 | 本仓库位置 | 用途 |
| --- | --- | --- |
| graphdeco-inria/gaussian-splatting | `third_party/gaussian-splatting` | 主实验代码：`convert.py`、`train.py`、`render.py`、`metrics.py` |
| colmap/colmap | `third_party/colmap` | COLMAP 源码参考。实际实验优先用服务器已安装的 `colmap` 命令 |
| nerfstudio-project/gsplat | `third_party/gsplat` | 现代 CUDA Gaussian rasterization 库，用于拓展理解和对比，不是老师主流程必需项 |
| SuperSplat | <https://superspl.at/editor> | 在线查看训练输出的 `point_cloud.ply` |
| 本地 `D:\simple-knn` | `third_party/simple-knn-local` | 本地源码备份，仅保留源码和许可证，排除了 Windows 编译产物 |
| 老师 Word 文档 | `docs/source/` | 原始指导书和 Windows 环境配置附件 |

## 最短实验路线

1. 准备一段自采视频或一组照片，要求视角连续、曝光尽量稳定、运动不要太快。
2. 用 FFmpeg 抽帧到 `data/<scene>/input/`。
3. 用官方 `convert.py` 调 COLMAP，生成 `images/` 和 `sparse/0/`。
4. 运行 `train.py`，建议带 `--eval`，这样后续能算测试指标。
5. 运行 `render.py` 和 `metrics.py`，记录 PSNR/SSIM。
6. 用 SuperSplat 打开 `outputs/<scene>/<run>/point_cloud/iteration_30000/point_cloud.ply`，截图写报告。
7. 至少做两组参数对比，例如减少迭代次数、改变 `--densify_grad_threshold` 或 `--position_lr_init`。

## Ubuntu 快速开始

```bash
git clone --recurse-submodules https://github.com/Cat-blizzard/HIT-CV-3DGS.git
cd HIT-CV-3DGS

# 拉取官方 3DGS 内部训练必需的 CUDA 子模块，并创建 Conda 环境。
bash scripts/setup_gaussian_splatting_ubuntu.sh

# 按需修改 DATASET_NAME / VIDEO_PATH / ITERATIONS 后运行。
DATASET_NAME=my_scene VIDEO_PATH=/path/to/video.mp4 FPS=2 bash scripts/run_pipeline_template.sh
```

如果服务器上已经配好环境，可以跳过 `setup_gaussian_splatting_ubuntu.sh`，只确保当前 Python 环境中能导入 `torch`、`diff_gaussian_rasterization`、`simple_knn._C` 和 `fused_ssim`。

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

更细的实验流程见 `docs/01-experiment-workflow.md`，报告结构见 `docs/03-report-template.md`。
