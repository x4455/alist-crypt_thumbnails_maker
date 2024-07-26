# 批量生成缩略图（动态图/预览图）
# 本脚本适用于项目 alist-org/alist 中 Crypt 驱动的缩略图功能

# 哪要生成丢哪里，右键执行等完事。
# 不建议对着挂载网盘上的文件使用。

# 乱码的去把Windows系统默认编码改为UTF-8
$OutputEncoding = [console]::InputEncoding = [console]::OutputEncoding = New-Object System.Text.UTF8Encoding

# 检查ffmpeg是否安装
if (Get-Command ffmpeg -ErrorAction SilentlyContinue) {
    Write-Host "ffmpeg 已安装。"
    $ffmpeg_path = Split-Path (Get-Command ffmpeg).Source -Parent
} else {
    # 你要在这里定义 ffmpeg.exe 所在路径 # https://ffmpeg.org/download.html
    $ffmpeg_path = "C:\ffmpeg-7.0.1-full_build\bin"
    # 检查ffmpeg.exe是否存在
    if (Test-Path $ffmpeg_path\ffmpeg.exe) {
        Write-Host "ffmpeg 路径已定义。"
    } else {
        Write-Error "ffmpeg 路径错误或未安装。需要定义 ffmpeg.exe 所在路径"
        # 等待用户按键
        Write-Host "Press any key to exit..."
        Read-Host
        # 退出脚本
        exit
    }
}

##### 自定义部分 #####

# 超过这个时长的都将使用预览图
$durationLimit = 600 # 10min

# 动态选择 帧步长
function Set-FrameInterval {
    param(
        [Parameter(Mandatory=$true)]
        [int]$durationInSeconds,
        [Parameter(Mandatory=$true)]
        [int]$framePerSecond
    )

    # 短视频转动态图（可调参数）
    if ($durationInSeconds -lt $durationLimit) {
        if       ($durationInSeconds -le 60) {  # 1m:
            $frameInterval = 5
        } elseif ($durationInSeconds -le 120) { # 2m:
            $frameInterval = 30
        } elseif ($durationInSeconds -le 180) { # 3m:
            $frameInterval = 35
        } elseif ($durationInSeconds -le 240) { # 4m:
            $frameInterval = 45
        } elseif ($durationInSeconds -le 300) { # 5m:
            $frameInterval = 50
        } elseif ($durationInSeconds -le 360) { # 6m:
            $frameInterval = 60
        } else {
            $frameInterval = 90
        }
        # 根据视频FPS调整frameInterval
        # 基准FPS为30，其他FPS相对于30的倍数进行调整
        $adjustmentFactor = [Math]::Round($framePerSecond / 30)
        $frameInterval = [Math]::Ceiling($frameInterval * $adjustmentFactor)

    } else {
        # 长视频转预览图：时长/画面总数（可调参数）*帧数
        $frameInterval = $durationInSeconds / 12 * $framePerSecond
        # 使用[Math]::Floor进行向下取整，确保结果为整数且不进则退
        $frameInterval = [Math]::Floor($frameInterval)
    }
    return [int]$frameInterval
}

# 动态选择 滤镜参数
function Set-VFchainArg {
    param(
        [Parameter(Mandatory=$true)]
        [int]$frameInterval
    )

    # VF参数（可调参数）
    # thumbnail=n=$frameInterval  缩略图滤镜，出图体积小点但非常耗时
    # selcte=not(mod(n\,$frameInterval))  指定步长取帧，快速出图
    # scale=-1:320  自动宽度，高度为320像素
    # tile=3X4:padding=1:color=black 3x4网格，之间填充1个像素，填充颜色为黑色
    $VFchainArgForSlide = "select=not(mod(n\,$frameInterval)),scale=-1:300" # 动态图
    $VFchainArgForPreview = "select=not(mod(n\,$frameInterval)),scale=-1:320,tile=3X4:padding=1:color=black" # 预览图

    # 根据帧步长选择滤镜参数
    if ($frameInterval -lt 1800) { # 30FPS下这都60秒/帧了，不会真有人等着换图吧。
        $Arg = $VFchainArgForSlide
    } else {
        $Arg = $VFchainArgForPreview
    }
    return $Arg
}

# 动态选择 其他参数
function Set-OtherArg {
    param(
        [Parameter(Mandatory=$true)]
        [int]$durationInSeconds
    )

    # 其他参数（可调参数）
    # 质量 -q:v 25 | 压缩 -compression_level 4 | 循环次数 -loop 0 | 覆盖文件 -y / -n
    $otherArgForSlide = "-q:v 25 -compression_level 4 -loop 0 -n" # 动态图
    $otherArgForPreview = "-lossless 0 -quality 40 -loop 0 -n" # 预览图

    # 根据时长选择其他参数
    if ($durationInSeconds -lt $durationLimit) {
        $Arg = $otherArgForSlide
    } else {
        $Arg = $otherArgForPreview
    }
    return $Arg
}



##### 除非你知道你在做什么 #####

# 定义函数来获取视频信息
function Get-VideoDurationInSeconds {
    param(
        [Parameter(Mandatory=$true)]
        [string]$filePath
    )

    # 使用 ffprobe 获取视频信息，并筛选出时长信息
    $durationInfo = & "$ffmpeg_path\ffprobe.exe" -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$filePath"

    # 将时长（可能是浮点数）转换为秒
    $durationInSeconds = [double]$durationInfo

    return $durationInSeconds
}

function Get-VideoFramesPerSecond {
    param(
        [Parameter(Mandatory=$true)]
        [string]$filePath
    )

    # 获取帧率信息并去重
    $frameRateInfo = (& "$ffmpeg_path\ffprobe.exe" -v error -select_streams v:0 -show_entries stream=r_frame_rate -of default=noprint_wrappers=1:nokey=1 "$filePath") | Select-Object -Unique

    # 初始化帧率变量，默认为null
    $framesPerSecond = $null

    # 检查帧率信息是否为分数形式
    if ($frameRateInfo -match '(\d+)/(\d+)') {
        # 分数形式处理
        $numerator, $denominator = $Matches[1], $Matches[2]
        $framesPerSecond = [double]$numerator / [double]$denominator
    } elseif ($frameRateInfo -match '^\d+$') {
        # 如果是整数（即只有分子），假设它是实际的帧率
        $framesPerSecond = [double]$frameRateInfo
    } else {
        Write-Warning "无法识别的帧率格式: $($frameRateInfo)"
    }

    # 计算并四舍五入帧率到最近的整数
    $framesPerSecond = [Math]::Round($framesPerSecond)

    return $framesPerSecond
}

##### Main #####

# 获取脚本所在目录
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
Write-Host "起始目录: $($scriptDir)"
# 定义一个数组
$mediaFiles = @()
# 使用Get-ChildItem命令递归查找起始目录及子目录下所有的 mkv、mp4、flv
$mediaFiles += Get-ChildItem -Path $scriptDir -Recurse -Include *.mkv,*.mp4,*.flv
# 遍历找到的每个文件
foreach ($file in $mediaFiles) {
    $inputFilePath = $file.FullName

    ##### 动态配置 #####

    Write-Host "视频文件: $inputFilePath" -ForegroundColor Yellow
    # 获取视频基础信息 - 时长 & 帧数
    $videoinfo_Duration = Get-VideoDurationInSeconds -filePath $inputFilePath
    $videoinfo_FPS = Get-VideoFramesPerSecond -filePath $inputFilePath
    Write-Host "视频时长（秒）: $($videoinfo_Duration)  |  视频帧数: $($videoinfo_FPS)" -ForegroundColor Yellow
    # 动态选择参数 - 动态图/预览图
    $FrameInterval = Set-FrameInterval -durationInSeconds $videoinfo_Duration -framePerSecond $videoinfo_FPS
    $VFchainArg = Set-VFchainArg -frameInterval $FrameInterval
    $otherArg = Set-OtherArg -durationInSeconds $videoinfo_Duration
    Write-Host "帧步长：$FrameInterval  |  VF参数: $VFchainArg  |  其他参数: $otherArg" -ForegroundColor Magenta

    ##### 生成路径 #####

    # 分离文件路径的目录部分和文件名（不带扩展名）
    $directory = [System.IO.Path]::GetDirectoryName($inputFilePath)
    # 获取输入路径中的文件名
    $fileName = [System.IO.Path]::GetFileName($inputFilePath)
    # 构建新的输出目录路径，即在原目录后添加.thumbnails
    $outputDirectory = Join-Path -Path $directory -ChildPath ".thumbnails"
    # 构建输出文件的完整路径
    $outputFilePath = Join-Path -Path $outputDirectory -ChildPath ($fileName + ".webp")
    # 确保输出目录存在，如果不存在则创建，且不输出任何信息
    if (-not (Test-Path -Path $outputDirectory -PathType Container)) {
        New-Item -ItemType Directory -Path $outputDirectory -ErrorAction SilentlyContinue | Out-Null
    }

    ##### 转码阶段 #####
    $ffmpegArgs = @{
        FilePath     = "$ffmpeg_path\ffmpeg.exe"
        ArgumentList = "-i `"$inputFilePath`" -vf `"$VFchainArg`" -c:v libwebp $otherArg `"$outputFilePath`""
        NoNewWindow  = $true
        Wait         = $true
        PassThru     = $true
    }
    # 使用 Start-Process 来执行 ffmpeg 命令并获取退出码
    $ffmpegProcess = Start-Process @ffmpegArgs

    # 捕获并检查退出码等信息
    $ffmpegExitCode = $ffmpegProcess.ExitCode
    if ($ffmpegExitCode -eq 0) {
        Write-Host "完成 $outputFilePath" -ForegroundColor Blue
    } else {
        Write-Warning "$outputFilePath 生成错误，代码: $ffmpegExitCode"
        # 将错误文件路径和退出码的内容追加到log文件中
        Add-Content -Path "$scriptDir\ffmpeg_err.log" -Value "$inputFilePath 生成错误，代码: $ffmpegExitCode"
    }
}

Write-Host "所有缩略图生成完毕" -ForegroundColor Green
# 等待用户按键
Write-Host "Press any key to exit..."
Read-Host