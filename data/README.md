# data

本目录用于本地放数据集，默认不提交 Git。

推荐结构：

```text
data/<scene>/
  input/      FFmpeg 抽帧结果
  images/     convert.py 生成的去畸变图像
  sparse/0/   COLMAP 相机和稀疏点云
```
