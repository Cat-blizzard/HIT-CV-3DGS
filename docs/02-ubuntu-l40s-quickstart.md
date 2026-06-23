# Ubuntu + L40S 快速环境建议

这份只保留关键判断，不复述 Windows 配置。

## 基本检查

```bash
nvidia-smi
nvcc --version
conda --version
colmap -h
ffmpeg -version
```

L40S 是 Ada 架构 GPU，驱动要足够新。PyTorch 的 CUDA runtime 版本和系统 CUDA Toolkit 不必完全相同，但编译 3DGS CUDA 扩展时，最好让 PyTorch CUDA 版本和本机 CUDA Toolkit 主版本接近。

## 推荐策略

1. 先使用 `scripts/setup_gaussian_splatting_ubuntu.sh` 创建 `gaussian_splatting` 环境。
2. 如果 PyTorch/CUDA 版本冲突，优先参考官方 `third_party/gaussian-splatting/environment.yml`。
3. 如果官方旧环境在 L40S 上构建失败，再切到较新的 PyTorch + CUDA 11.8 或 CUDA 12 组合。
4. COLMAP 优先使用系统包、conda 包或服务器管理员已装版本，不建议为了本实验从源码编译 COLMAP。

## 验证点

训练前至少确认：

```bash
python - <<'PY'
import torch
print(torch.__version__, torch.version.cuda, torch.cuda.is_available())
if torch.cuda.is_available():
    print(torch.cuda.get_device_name(0))
import diff_gaussian_rasterization
import simple_knn._C
import fused_ssim
print("3DGS extensions import OK")
PY
```

如果这里失败，先不要开始训练，优先处理 CUDA 扩展编译问题。

## 小显存或大场景降压参数

L40S 显存通常够用，但如果输入图像太多或分辨率太高，仍可能爆显存。可考虑：

```bash
--data_device cpu
--resolution 2
--test_iterations -1
--densify_grad_threshold 0.0004
--densify_until_iter 10000
```

这些参数会影响质量，报告里要说明改动原因。
