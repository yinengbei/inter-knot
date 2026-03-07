import 'package:flutter/material.dart';

Future<void> showCreateDiscussionPostSettingsSheet({
  required BuildContext context,
  required bool compressBeforeUpload,
  required ValueChanged<bool> onCompressionChanged,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: const Color(0xff181818),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (sheetContext) {
      var localCompress = compressBeforeUpload;
      return StatefulBuilder(
        builder: (context, setSheetState) {
          return SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xff383838),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '帖子设置',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xff1F1F1F),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xff2D2D2D)),
                    ),
                    child: ListTile(
                      title: const Text(
                        '图片压缩',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        localCompress ? '节省流量上传更快' : '原图上传',
                        style: const TextStyle(
                          color: Color(0xff9AA0A6),
                          fontSize: 12,
                        ),
                      ),
                      trailing: Switch(
                        value: localCompress,
                        activeThumbColor: const Color(0xffD7FF00),
                        onChanged: (value) {
                          setSheetState(() {
                            localCompress = value;
                          });
                          onCompressionChanged(value);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}
