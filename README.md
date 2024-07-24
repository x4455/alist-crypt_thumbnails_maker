# alist-crypt_thumbnails_maker

This is a PowerShell script to batch create thumbnails for the alist Crypt driver.

这是一个 PowerShell 脚本，用于为 alist Crypt 驱动程序批量创建缩略图。

## Features

- 脚本会为当前目录下的所有视频文件创建缩略图。文件结构兼容alist Crypt驱动的缩略图功能。

- 脚本会自动检测视频文件的信息，并视视频的时长来决定生成哪种类型的缩略图。时长在10min内的将会生成动态图片，其它会生成静态的多图预览。

- 未测试且不建议对挂载到本地的网盘文件使用。

## Requirements

- PowerShell
- [ffmpeg](https://ffmpeg.org/download.html)

## Usage

1. Download script: [BatchThumbnails.ps1](https://github.com/x4455/alist-crypt_thumbnails_maker/raw/main/BatchThumbnails.ps1)
2. Put the script into the video directory.
3. Right-click to run the script, wait for completion.

## 用法

1. 下载脚本： [BatchThumbnails.ps1](https://github.com/x4455/alist-crypt_thumbnails_maker/raw/main/BatchThumbnails.ps1)
2. 把脚本放入到视频目录下。
3. 右键运行脚本，等待完成。
