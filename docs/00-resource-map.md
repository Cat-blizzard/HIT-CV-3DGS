# 资源梳理

## 主线判断

老师给的材料里真正需要串起来的是这条链：

```text
输入视频/照片 -> FFmpeg 抽帧 -> COLMAP 稀疏重建 -> 3DGS 数据格式 -> train.py 训练 -> render.py 渲染 -> metrics.py 评估 -> SuperSplat/SIBR 查看 -> 报告分析
```

环境配置、Windows 安装包、VS/CUDA 版本只是为了让代码能跑。你后面有 Ubuntu 服务器和 L40S，优先把精力放在数据质量、训练命令、参数对比和结果解释上。

## 各资源该怎么用

| 资源 | 定位 | 实验中怎么用 |
| --- | --- | --- |
| `graphdeco-inria/gaussian-splatting` | 官方 3DGS 实现 | 主代码。使用 `convert.py` 做 COLMAP 转换，`train.py` 训练，`render.py` 渲染，`metrics.py` 算指标 |
| `colmap/colmap` | 传统 SfM/Sparse Reconstruction 工具 | 给 3DGS 提供相机内外参和稀疏点云。一般直接安装系统包或预编译版本，不需要改 COLMAP 源码 |
| `nerfstudio-project/gsplat` | 更现代的 Gaussian splatting CUDA 库 | 可用于拓展阅读和算法对比。老师实验主线不依赖它 |
| `simple-knn` | 3DGS 的 CUDA 扩展依赖 | 官方 3DGS 子模块里已经有一份。这里额外保存本地 `D:\simple-knn` 的源码备份，避免老师材料丢失 |
| `SuperSplat` | Web 点云/Gaussian 查看器 | 训练完成后上传 `point_cloud.ply` 查看效果，适合作为报告截图来源 |
| Windows 配置文档 | 老师环境附件 | 只作为排错参考。Ubuntu/L40S 环境不需要逐条照搬 Windows 版本 |

## 这次实验最容易踩坑的地方

1. COLMAP 失败比训练失败更常见。图像模糊、重复纹理、曝光跳变、视角跨度太小都会导致稀疏重建差。
2. `train.py --eval` 要在训练时加，不然后续测试集指标不完整。
3. 训练输出很大，`results/`、`outputs/` 和 `data/` 默认不进 Git。
4. 如果只上传 SuperSplat 截图，不足以支撑报告。还要记录训练参数、迭代次数、训练耗时、PSNR/SSIM 和至少三组视角对比。
5. `gsplat` 不等于老师要求的官方 3DGS 项目。它更适合做拓展对比，而不是替代主流程。
