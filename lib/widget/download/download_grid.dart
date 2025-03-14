import 'package:brisk/constants/download_status.dart';
import 'package:brisk/constants/file_type.dart';
import 'package:brisk/dao/download_item_dao.dart';
import 'package:brisk/provider/download_request_provider.dart';
import 'package:brisk/provider/pluto_grid_state_manager_provider.dart';
import 'package:brisk/util/file_util.dart';
import 'package:brisk/widget/download/add_url_dialog.dart';
import 'package:brisk/widget/download/download_info_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:pluto_grid/pluto_grid.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'dart:io';

import 'download_progress_window.dart';

class DownloadGrid extends StatefulWidget {
  @override
  State<DownloadGrid> createState() => _DownloadGridState();
}

class _DownloadGridState extends State<DownloadGrid> {
  late List<PlutoColumn> columns;

  @override
  void didChangeDependencies() {
    initColumns(context);
    super.didChangeDependencies();
  }

  void initColumns(BuildContext context) {
    columns = [
      PlutoColumn(
        readOnly: true,
        hide: true,
        width: 80,
        title: 'Id',
        field: 'id',
        type: PlutoColumnType.number(),
      ),
      PlutoColumn(
        enableRowChecked: true,
        width: 300,
        title: 'File Name',
        field: 'file_name',
        type: PlutoColumnType.text(),
        renderer: (rendererContext) {
          final fileName = rendererContext.row.cells["file_name"]!.value;
          final id = rendererContext.row.cells["id"]!.value;
          final status = rendererContext.row.cells["status"]!.value;
          final fileType = FileUtil.detectFileType(fileName);
          return Row(
            children: [
              PopupMenuButton(
                icon: const Icon(
                  Icons.more_vert_rounded,
                  color: Colors.white,
                ),
                color: const Color.fromRGBO(48, 48, 48, 1),
                tooltip: "Options",
                onSelected: (value) => onPopupMenuItemSelected(value, id),
                itemBuilder: (BuildContext bc) {
                  final provider =
                      Provider.of<DownloadRequestProvider>(bc, listen: false);
                  final downloadProgress = provider.downloads[id];
                  final downloadExists = downloadProgress != null;
                  final downloadComplete =
                      status == DownloadStatus.assembleComplete;
                  final updateUrlEnabled = downloadExists
                      ? (downloadProgress.status == DownloadStatus.paused ||
                          downloadProgress.status == DownloadStatus.canceled)
                      : (status == DownloadStatus.paused ||
                          status == DownloadStatus.canceled);
                  return [
                    PopupMenuItem(
                      value: 1,
                      enabled: updateUrlEnabled,
                      child: !updateUrlEnabled
                          ? Tooltip(
                              message: "Download must be paused",
                              child: getPopupMenuText(
                                "Update URL",
                                updateUrlEnabled,
                              ),
                            )
                          : getPopupMenuText("Update URL", updateUrlEnabled),
                    ),
                    PopupMenuItem(
                        value: 2,
                        enabled: downloadExists,
                        child: getPopupMenuText(
                          "Open progress window",
                          downloadExists,
                        )),
                    PopupMenuItem(
                      value: 3,
                      child: getPopupMenuText("Properties", true),
                    ),
                    PopupMenuItem(
                      value: 4,
                      enabled: downloadComplete,
                      child: getPopupMenuText("Open file", downloadComplete),
                    ),
                    PopupMenuItem(
                      value: 5,
                      enabled: downloadComplete,
                      child: getPopupMenuText(
                        "Open file location",
                        downloadComplete,
                      ),
                    )
                  ];
                },
              ),
              SizedBox(
                width: fileType == DLFileType.program ? 25 : 30,
                height: fileType == DLFileType.program ? 25 : 30,
                child: SvgPicture.asset(
                  FileUtil.resolveFileTypeIconPath(fileType),
                  color: FileUtil.resolveFileTypeIconColor(fileType),
                ),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  rendererContext.row.cells[rendererContext.column.field]!.value
                      .toString(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          );
        },
      ),
      PlutoColumn(
        readOnly: true,
        width: 90,
        title: 'Size',
        field: 'size',
        type: PlutoColumnType.text(),
      ),
      PlutoColumn(
        readOnly: true,
        width: 100,
        title: 'Progress',
        field: 'progress',
        type: PlutoColumnType.text(),
      ),
      PlutoColumn(
          readOnly: true,
          width: 140,
          title: "Status",
          field: "status",
          type: PlutoColumnType.text()),
      PlutoColumn(
        readOnly: true,
        enableSorting: false,
        width: 122,
        title: 'Transfer Rate',
        field: 'transfer_rate',
        type: PlutoColumnType.text(),
      ),
      PlutoColumn(
        readOnly: true,
        width: 100,
        title: 'Time Left',
        field: 'time_left',
        type: PlutoColumnType.text(),
      ),
      PlutoColumn(
        readOnly: true,
        width: 100,
        title: 'Start Date',
        field: 'start_date',
        type: PlutoColumnType.date(),
      ),
      PlutoColumn(
        readOnly: true,
        width: 120,
        title: 'Finish Date',
        field: 'finish_date',
        type: PlutoColumnType.date(),
      ),
      PlutoColumn(
        readOnly: true,
        hide: true,
        width: 120,
        title: 'File Type',
        field: 'file_type',
        type: PlutoColumnType.text(),
      )
    ];
  }

  void onPopupMenuItemSelected(int value, int id) {
    switch (value) {
      case 1:
        showDialog(
          context: context,
          builder: (context) =>
              AddUrlDialog(downloadId: id, updateDialog: true),
        );
        break;
      case 2:
        showDialog(
          context: context,
          builder: (_) => DownloadProgressWindow(id),
        );
        break;
      case 3:
        DownloadItemDao.instance.getById(id).then((dl) {
          showDialog(
              context: context,
              builder: (context) =>
                  DownloadInfoDialog(dl, showActionButtons: false));
        });
        break;
      case 4:
        DownloadItemDao.instance.getById(id).then((dl) {
          launchUrlString("file:${dl.filePath}");
        });
        break;
      case 5:
        DownloadItemDao.instance.getById(id).then((dl) {
          final folder = dl.filePath
              .substring(0, dl.filePath.lastIndexOf(Platform.pathSeparator));
          launchUrlString("file:$folder");
        });
        break;
    }
  }

  Widget getPopupMenuText(String text, bool enabled) => Text(text,
      style: TextStyle(
        color: enabled ? Colors.white : Colors.grey,
      ));

  @override
  Widget build(BuildContext context) {
    final provider =
        Provider.of<DownloadRequestProvider>(context, listen: false);
    final size = MediaQuery.of(context).size;
    return Material(
      type: MaterialType.transparency,
      child: Container(
        height: size.height - 70,
        width: size.width * 0.8,
        decoration: const BoxDecoration(color: Colors.black26),
        child: PlutoGrid(
          key: UniqueKey(),
          mode: PlutoGridMode.selectWithOneTap,
          configuration: const PlutoGridConfiguration(
            style: PlutoGridStyleConfig.dark(
              activatedBorderColor: Colors.transparent,
              borderColor: Colors.black26,
              gridBorderColor: Colors.black54,
              activatedColor: Colors.black26,
              gridBackgroundColor: Color.fromRGBO(40, 46, 58, 1),
              rowColor: Color.fromRGBO(49, 56, 72, 1),
              checkedColor: Colors.blueGrey,
            ),
          ),
          columns: columns,
          rows: [],
          onLoaded: (event) {
            PlutoGridStateManagerProvider.plutoStateManager
                ?.setShowLoading(true);
            PlutoGridStateManagerProvider.setStateManager(event.stateManager);
            PlutoGridStateManagerProvider.plutoStateManager
                ?.setSelectingMode(PlutoGridSelectingMode.row);
            provider.fetchRows();
          },
        ),
      ),
    );
  }
}
