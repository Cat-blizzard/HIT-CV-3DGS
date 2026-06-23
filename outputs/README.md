# outputs

本目录用于本地放训练输出，默认不提交 Git。

推荐结构：

```text
outputs/<scene>/<run_id>/
  cfg_args
  point_cloud/iteration_30000/point_cloud.ply
  train/
  test/
```

报告截图和指标可以从这里整理，但模型文件、渲染图和视频不要直接提交到仓库。
