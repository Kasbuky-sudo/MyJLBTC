import { systemShare } from '@kit.ShareKit';
import { common } from '@kit.AbilityKit';
import { image } from '@kit.ImageKit';
import { fileIo, fileUri } from '@kit.CoreFileKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0000;
const TAG = 'ShareUtil';

/**
 * 分享相关工具。
 *
 * 三个要点（都是官方口径，踩过才写下来的）：
 * 1. 分享图片前要先把组件截图存成文件，**URI 必须用 `fileUri.getUriFromPath(沙箱路径)` 生成**——
 *    手拼 `file://${path}` 分享出去对方拿不到内容；
 * 2. `SharedRecord` 是**接口**（对象字面量构造），不是类，没有 addText/setUtD 这些方法；
 * 3. 截图用 `componentSnapshot.get(组件id, { scale, waitUntilRenderFinished })`，
 *    组件必须挂 `.id()`；PixelMap / packer 用完要 release。
 */
export class ShareUtil {
  /** PixelMap → PNG 落到 cacheDir（系统会自动清理），返回可分享的文件 URI */
  static async buildImageFileUri(context: common.UIAbilityContext, pixelMap: image.PixelMap,
    fileName: string): Promise<string> {
    const filePath: string = `${context.cacheDir}/${fileName}`;
    const packer: image.ImagePacker = image.createImagePacker();
    let file: fileIo.File | undefined = undefined;
    try {
      file = fileIo.openSync(filePath,
        fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
      const options: image.PackingOption = { format: 'image/png', quality: 90 };
      await packer.packToFile(pixelMap, file.fd, options);
      return fileUri.getUriFromPath(filePath);
    } finally {
      try {
        if (file !== undefined) {
          fileIo.closeSync(file);
        }
      } catch (err) {
        hilog.warn(DOMAIN, TAG, 'close share file failed');
      }
      packer.release();
      pixelMap.release();
    }
  }

  /** 通用图片分享数据：一张图片 + 一条文本 */
  static buildImageData(title: string, description: string, imageUri: string,
    text: string): systemShare.SharedData {
    const imageRecord: systemShare.SharedRecord = {
      utd: 'general.image',
      uri: imageUri,
      title: title,
      description: description
    };
    const data: systemShare.SharedData = new systemShare.SharedData(imageRecord);
    const textRecord: systemShare.SharedRecord = {
      utd: 'general.text',
      content: text
    };
    data.addRecord(textRecord);
    return data;
  }

  /** 拉起系统分享面板 */
  static async showSystemShare(context: common.UIAbilityContext,
    data: systemShare.SharedData): Promise<void> {
    try {
      const controller: systemShare.ShareController = new systemShare.ShareController(data);
      const options: systemShare.ShareControllerOptions = {
        previewMode: systemShare.SharePreviewMode.DEFAULT
      };
      await controller.show(context, options);
    } catch (err) {
      const error: BusinessError = err as BusinessError;
      hilog.error(DOMAIN, TAG, 'show share panel failed: %{public}d %{public}s', error.code, error.message);
    }
  }
}

