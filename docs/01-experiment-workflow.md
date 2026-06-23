# 实验流程

## 1. 数据采集

建议从一个中小型静态场景开始，例如桌面物体、实验室角落、走廊局部。拍摄时尽量满足：

- 场景静止，避免人来回走动。
- 相机绕目标缓慢移动，相邻帧有足够重叠。
- 光照和曝光稳定，少用强反光或大面积纯色墙面。
- 视频时长不用太长，第一次实验抽 80 到 200 张图更容易调通。

## 2. 抽帧

```bash
mkdir -p data/my_scene/input
ffmpeg -i raw/my_scene.mp4 -vf fps=2 data/my_scene/input/%06d.jpg
```

如果 COLMAP 匹配太慢，降低 `fps`。如果稀疏点太少，提高 `fps` 或重新拍摄更连续的视角。

## 3. COLMAP 转换

官方 3DGS 期望数据目录最终类似：

```text
data/my_scene/
  input/            原始抽帧
  images/           convert.py 生成的去畸变图像
  sparse/0/
    cameras.bin
    images.bin
    points3D.bin
```

运行：

```bash
cd third_party/gaussian-splatting
python convert.py -s ../../data/my_scene --colmap_executable colmap
```

如果服务器上 `colmap` 已经在 `PATH` 中，`--colmap_executable colmap` 可以省略。需要生成多尺度图片时加 `--resize`。

## 4. 训练

建议第一次保留默认 30000 次迭代，并显式指定输出目录：

```bash
cd third_party/gaussian-splatting
python train.py \
  -s ../../data/my_scene \
  -m ../../results/my_scene/runs/baseline \
  --eval \
  --iterations 30000
```

记录训练终端输出中的 L1、PSNR、训练耗时和保存迭代点。训练完成后的关键文件通常在：

```text
results/my_scene/runs/baseline/
  point_cloud/iteration_30000/point_cloud.ply
  cfg_args
```

## 5. 渲染和指标

```bash
cd third_party/gaussian-splatting
python render.py -m ../../results/my_scene/runs/baseline
python metrics.py -m ../../results/my_scene/runs/baseline
```

报告至少记录三组测试视角的渲染图、真实图、PSNR、SSIM，并解释指标高低和视觉效果是否一致。

## 6. 可视化

最省事的方式是打开 SuperSplat Editor：

<https://superspl.at/editor>

导入：

```text
results/my_scene/runs/baseline/point_cloud/iteration_30000/point_cloud.ply
```

SIBR 查看器适合实时交互展示，但需要额外编译或下载二进制。实验报告可以优先用 SuperSplat 截图完成。

## 7. 参数对比

至少做两组对比，不要只改随机名称。推荐组合：

```bash
# 快速低迭代对比
python train.py -s ../../data/my_scene -m ../../results/my_scene/runs/iter_7000 --eval --iterations 7000

# 降低 densify 阈值，通常会增加高斯数量，可能提升细节但更耗显存
python train.py -s ../../data/my_scene -m ../../results/my_scene/runs/densify_low --eval --densify_grad_threshold 0.0001

# 降低初始位置学习率，适合大尺度或相机轨迹不稳定场景
python train.py -s ../../data/my_scene -m ../../results/my_scene/runs/pos_lr_low --eval --position_lr_init 0.00008
```

每组都要保存：命令、训练耗时、最终 PSNR、SSIM、高斯点数量、三张可视化对比图和现象解释。
