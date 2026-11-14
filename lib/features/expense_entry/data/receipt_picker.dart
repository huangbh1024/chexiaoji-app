import 'package:flutter/services.dart' show PlatformException;
import 'package:image_picker/image_picker.dart';

enum ReceiptSource { camera, gallery }

class PickedReceipt {
  const PickedReceipt({required this.path, required this.sizeBytes});

  final String path;
  final int sizeBytes;
}

abstract class ReceiptPicker {
  Future<PickedReceipt?> pick(ReceiptSource source);
}

class ReceiptPermissionException implements Exception {
  const ReceiptPermissionException(this.message);

  final String message;
}

class ReceiptTooLargeException implements Exception {
  const ReceiptTooLargeException([this.message = '单张凭证不能超过 5MB']);

  final String message;
}

class ReceiptUnavailableException implements Exception {
  const ReceiptUnavailableException([this.message = '凭证选择暂不可用']);

  final String message;
}

class ImagePickerReceiptPicker implements ReceiptPicker {
  const ImagePickerReceiptPicker();

  static const _maxBytes = 5 * 1024 * 1024;

  @override
  Future<PickedReceipt?> pick(ReceiptSource source) async {
    try {
      final file = await ImagePicker().pickImage(
        source: source == ReceiptSource.camera
            ? ImageSource.camera
            : ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 80,
        requestFullMetadata: false,
      );
      if (file == null) {
        return null;
      }
      final size = await file.length();
      if (size > _maxBytes) {
        throw const ReceiptTooLargeException();
      }
      return PickedReceipt(path: file.path, sizeBytes: size);
    } on PlatformException catch (error) {
      final code = error.code.toLowerCase();
      if (code.contains('denied') || code.contains('permission')) {
        throw ReceiptPermissionException(
          source == ReceiptSource.camera ? '相机权限被拒绝' : '相册权限被拒绝',
        );
      }
      throw ReceiptUnavailableException(error.message ?? '凭证选择失败');
    }
  }
}
