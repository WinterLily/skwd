pragma Singleton
import QtQuick

QtObject {
    id: svc

    readonly property int thumbWidth: 640
    readonly property int thumbHeight: 360
    readonly property int smallThumbWidth: 240
    readonly property int smallThumbHeight: 135
    readonly property int thumbQuality: 2
    readonly property int smallThumbQuality: 3
    readonly property int monochromeThreshold: 10
    readonly property var imageExtensions: ["jpg", "jpeg", "png", "webp"]
    readonly property var videoExtensions: ["mp4", "webm", "mkv", "avi", "mov", "gif"]

    function findExtPattern(exts) {
        var parts = exts.map(function (e) {
            return '-iname "*.' + e + '"';
        });
        return '\\( ' + parts.join(' -o ') + ' \\)';
    }

    function hueExtractCmd(imagePath) {
        var matugenCmd = "matugen image " + imagePath + " --dry-run --json hex --source-color-index 0 2>/dev/null";
        var pythonCmd = "python3 -c \"import sys,json;d=json.load(sys.stdin);c=d.get('colors',{}).get('source_color',{}).get('dark',{}).get('color','#888888');h=c.lstrip('#');r=int(h[0:2],16)/255;g=int(h[2:4],16)/255;b=int(h[4:6],16)/255;mx=max(r,g,b);mn=min(r,g,b);df=mx-mn;l=(mx+mn)/2;s=0 if df==0 else df/(2-mx-mn) if l>0.5 else df/(mx+mn);h=0 if df==0 else ((g-b)/df+(6 if g<b else 0) if mx==r else ((b-r)/df+2) if mx==g else (r-g)/df+4)*60;print(f'{h:.1f} {s*100:.1f}')\"";
        var fallbackCmd = "magick " + imagePath + " -resize 1x1! -colorspace HSL -format '%[fx:u.r*360] %[fx:u.g*100]' info: 2>/dev/null";
        return "(" + matugenCmd + " | " + pythonCmd + ") 2>/dev/null || " + fallbackCmd + " || echo '0 0'";
    }

    function thumbnailCmd(src, dest, width, height, quality) {
        var w = width || thumbWidth, h = height || thumbHeight, q = quality || thumbQuality;
        return "timeout --kill-after=5 15 ffmpeg -y -i " + src + " -vf 'scale=" + w + ":" + h + ":force_original_aspect_ratio=increase,crop=" + w + ":" + h + "'" + " -q:v " + q + " -frames:v 1 -update 1 " + dest + " 2>/dev/null";
    }

    function videoThumbnailCmd(src, dest, seekSec, width, height, quality) {
        var ss = seekSec !== undefined ? seekSec : 1;
        var w = width || thumbWidth, h = height || thumbHeight, q = quality || thumbQuality;
        return "timeout --kill-after=5 15 ffmpeg -y -ss " + ss + " -i " + src + " -vf 'scale=" + w + ":" + h + ":force_original_aspect_ratio=increase,crop=" + w + ":" + h + "'" + " -q:v " + q + " -frames:v 1 -update 1 " + dest + " 2>/dev/null";
    }

    function animatedWebpThumbnailCmd(srcFrame0, dest, width, height) {
        var w = width || thumbWidth, h = height || thumbHeight;
        return "timeout --kill-after=5 15 magick " + srcFrame0 + " -resize " + w + "x" + h + "^ -gravity center -extent " + w + "x" + h + " -quality 85 " + dest + " 2>/dev/null";
    }

    function encodeBase64Cmd(imagePath) {
        return "magick " + imagePath + " -resize " + "x" + " -quality " + " jpeg:- 2>/dev/null | base64 -w0";
    }

    function hueBucket(hue, sat) {
        if (sat < monochromeThreshold)
            return 99;

        if (hue >= 340 || hue < 25)
            return 0;

        return Math.floor((hue - 25) / 30) + 1;
    }

    function smallThumbPath(thumbPath) {
        return thumbPath.replace("/thumbs/", "/thumbs-sm/").replace("/we-thumbs/", "/thumbs-sm/we-").replace("/video-thumbs/", "/thumbs-sm/vid-");
    }

    function fileUrl(path) {
        if (!path)
            return "";

        return "file://" + path.split("/").map(encodeURIComponent).join("/");
    }

    function thumbKey(thumbPath, fallbackName) {
        if (typeof thumbPath === "string" && thumbPath.length > 0) {
            var fname = thumbPath.split("/").pop();
            if (fname.toLowerCase().endsWith(".jpg"))
                return fname.substring(0, fname.length - 4);

            return fname;
        }
        if (typeof fallbackName === "string" && fallbackName.length > 0)
            return fallbackName;

        return "";
    }
}
