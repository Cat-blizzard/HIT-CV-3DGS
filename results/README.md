# results

本目录用于本地保存一键实验结果，默认不提交 Git。

`scripts/run_all_ubuntu.sh` 默认生成：

```text
results/<scene>/
  runs/              baseline 和参数对比模型、渲染结果、metrics JSON
  logs/              每一步终端日志
  report_materials/  报告材料、样例图、点云路径、截图占位、checklist
  RUN_SUMMARY.md     本轮实验摘要
```
