import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/domain/enums.dart';
import '../../../core/presentation/toast.dart';
import '../../../core/widgets/blurred_header_delegate.dart';
import '../../../core/widgets/section_error.dart';
import '../../home/domain/providers.dart';
import '../../report/domain/report_models.dart';
import '../../report/presentation/report_routes.dart';
import '../domain/providers.dart';
import '../domain/vehicle_models.dart';
import '../domain/vehicle_presenter.dart';
import 'widgets/archive_notice_card.dart';
import 'widgets/archive_security_card.dart';
import 'widgets/archived_empty_state.dart';
import 'widgets/archived_vehicle_card.dart';
import 'widgets/archived_vehicles_header.dart';
import 'widgets/archived_vehicles_skeleton.dart';
import 'widgets/purge_archived_vehicle_sheet.dart';
import 'widgets/restore_archived_vehicle_sheet.dart';

/// 已归档车辆：封存列表、恢复、历史报表与彻底删除。
class ArchivedVehiclesPage extends ConsumerStatefulWidget {
  const ArchivedVehiclesPage({super.key});

  @override
  ConsumerState<ArchivedVehiclesPage> createState() =>
      _ArchivedVehiclesPageState();
}

class _ArchivedVehiclesPageState extends ConsumerState<ArchivedVehiclesPage> {
  final Set<String> _removingIds = <String>{};
  final Set<String> _removedIds = <String>{};
  List<ArchivedVehicleSummary>? _displayed;
  bool _sheetOpen = false;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final tokens = context.tokens;
    final garage = ref.watch(archivedGarageProvider);
    final command = ref.watch(vehicleCommandProvider);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final items = _visibleItems(garage);

    return Scaffold(
      backgroundColor: palette.background,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 448),
          child: SafeArea(
            bottom: false,
            child: RefreshIndicator(
              color: palette.primary,
              onRefresh: _refresh,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: BlurredHeaderDelegate(
                      height: tokens.headerHeight,
                      child: ArchivedVehiclesHeader(
                        count: garage.hasValue ? items.length : null,
                        isLoading: garage.isLoading,
                        hasError: garage.hasError,
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      tokens.pagePadding,
                      4,
                      tokens.pagePadding,
                      tokens.contentBottomPadding + bottomInset,
                    ),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate(
                        _content(context, garage, command, items),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<ArchivedVehicleSummary> _visibleItems(
    AsyncValue<ArchivedGarage> garage,
  ) {
    final data = [
      for (final vehicle
          in garage.value?.vehicles ?? const <ArchivedVehicleSummary>[])
        if (!_removedIds.contains(vehicle.id)) vehicle,
    ];
    if (_removingIds.isEmpty) {
      return data;
    }
    return _displayed ?? data;
  }

  List<Widget> _content(
    BuildContext context,
    AsyncValue<ArchivedGarage> garage,
    VehicleCommandState command,
    List<ArchivedVehicleSummary> items,
  ) {
    final tokens = context.tokens;
    final content = <Widget>[
      const ArchiveNoticeCard(),
      SizedBox(height: tokens.spaceLg),
    ];

    if (garage.hasError && garage.hasValue) {
      content
        ..add(_RefreshErrorBar(onRetry: _refresh))
        ..add(SizedBox(height: tokens.spaceMd));
    }

    if (!garage.hasValue) {
      if (garage.hasError) {
        content.add(
          SectionError(
            message: '封存档案加载失败',
            onRetry: () => ref.invalidate(archivedGarageProvider),
          ),
        );
      } else {
        content.add(const ArchivedVehiclesSkeleton());
      }
    } else if (items.isEmpty) {
      content.add(
        ArchivedEmptyState(onBack: () => Navigator.of(context).maybePop()),
      );
    } else {
      content.add(const _SectionTitle());
      content.add(SizedBox(height: tokens.spaceMd));
      for (var index = 0; index < items.length; index++) {
        if (index > 0) {
          content.add(SizedBox(height: tokens.spaceMd));
        }
        content.add(_buildCard(items[index], command));
      }
    }

    content
      ..add(SizedBox(height: tokens.spaceLg))
      ..add(const ArchiveSecurityCard());
    return content;
  }

  Widget _buildCard(
    ArchivedVehicleSummary vehicle,
    VehicleCommandState command,
  ) {
    final removing = _removingIds.contains(vehicle.id);
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 250);

    return ClipRect(
      child: AnimatedSize(
        duration: duration,
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: removing
            ? const SizedBox(width: double.infinity)
            : ArchivedVehicleCard(
                key: ValueKey<String>(vehicle.id),
                vehicle: vehicle,
                busy: command.isBusy,
                onPurge: () => _purge(vehicle),
                onReport: () => _openReport(vehicle),
                onRestore: () => _restore(vehicle),
              ),
      ),
    );
  }

  Future<String?> _runWithAnimation(
    ArchivedVehicleSummary vehicle,
    Future<bool> Function() action,
  ) async {
    final ok = await action();
    if (!ok) {
      return ref.read(vehicleCommandProvider).errorMessage ?? '操作失败，请重试';
    }
    if (mounted) {
      setState(() {
        _displayed = ref.read(archivedGarageProvider).value?.vehicles;
        _removingIds.add(vehicle.id);
      });
    }
    return null;
  }

  Future<void> _restore(ArchivedVehicleSummary vehicle) async {
    if (_sheetOpen) {
      return;
    }
    _sheetOpen = true;
    try {
      var garageEmpty = false;
      try {
        final overview = await ref.read(garageProvider.future);
        garageEmpty = overview.vehicles.isEmpty;
      } catch (_) {
        // 车库读取失败时按非空处理，弹层仍可完成恢复。
      }
      if (!mounted) {
        return;
      }
      final confirmed = await showRestoreArchivedVehicleSheet(
        context,
        vehicle,
        garageEmpty: garageEmpty,
        onConfirm: () => _runWithAnimation(
          vehicle,
          () => ref.read(vehicleCommandProvider.notifier).restore(vehicle.id),
        ),
      );
      if (confirmed != true || !mounted) {
        return;
      }
      await _finishRemoval(vehicle, restored: true);
    } finally {
      _sheetOpen = false;
    }
  }

  Future<void> _purge(ArchivedVehicleSummary vehicle) async {
    if (_sheetOpen) {
      return;
    }
    _sheetOpen = true;
    try {
      final confirmed = await showPurgeArchivedVehicleSheet(
        context,
        vehicle,
        onConfirm: (plateTail) => _runWithAnimation(
          vehicle,
          () => ref
              .read(vehicleCommandProvider.notifier)
              .purge(vehicle.id, plateTail),
        ),
      );
      if (confirmed != true || !mounted) {
        return;
      }
      await _finishRemoval(vehicle, restored: false);
    } finally {
      _sheetOpen = false;
    }
  }

  Future<void> _finishRemoval(
    ArchivedVehicleSummary vehicle, {
    required bool restored,
  }) async {
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 250);
    await Future<void>.delayed(duration);
    if (!mounted) {
      return;
    }
    setState(() {
      _removingIds.remove(vehicle.id);
      _removedIds.add(vehicle.id);
      _displayed = null;
    });
    ref.invalidate(archivedGarageProvider);
    ref.invalidate(garageProvider);
    ref.invalidate(vehiclesProvider);
    final name = vehicle.vehicle.name;
    showAppToast(
      context,
      restored ? '已成功将「$name」恢复至常用车库' : '已彻底删除「$name」的车辆档案',
    );
  }

  Future<void> _openReport(ArchivedVehicleSummary vehicle) async {
    final latest = vehicle.latestRecordAt;
    if (latest == null || !ArchivedVehiclePresenter.canOpenReports(vehicle)) {
      showAppToast(context, '该车辆暂无历史流水');
      return;
    }
    await openMonthlyReport(
      context,
      ReportScope(
        month: DateTime(latest.year, latest.month),
        vehicleId: vehicle.id,
      ),
      archivedVehicle: _reportBrief(vehicle),
    );
  }

  ReportVehicleBrief _reportBrief(ArchivedVehicleSummary vehicle) {
    return ReportVehicleBrief(
      id: vehicle.id,
      name: vehicle.vehicle.name,
      shortName: vehicle.vehicle.name,
      plate: vehicle.vehicle.plate,
      powertrain: vehicle.powertrain,
      powertrainLabel: vehicle.vehicle.powertrainLabel.isEmpty
          ? vehicle.powertrain.label
          : vehicle.vehicle.powertrainLabel,
      odometerKm: vehicle.vehicle.odometerKm,
      recordCount: vehicle.recordCount,
    );
  }

  Future<void> _refresh() async {
    ref.invalidate(archivedGarageProvider);
    ref.invalidate(garageProvider);
    ref.invalidate(vehiclesProvider);
    try {
      await ref.read(archivedGarageProvider.future);
    } catch (_) {
      // 错误态由页面自行展示。
    }
  }
}

class _RefreshErrorBar extends StatelessWidget {
  const _RefreshErrorBar({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Material(
      color: palette.errorSoft.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onRetry,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(Icons.refresh_rounded, size: 16, color: palette.error),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '刷新失败，点击重试',
                  style: AppTypography.bodySm.copyWith(color: palette.error),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: palette.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '封存座驾列表',
          style: AppTypography.headlineSm.copyWith(color: palette.onSurface),
        ),
        const SizedBox(width: 6),
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: palette.primary,
            shape: BoxShape.circle,
          ),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            '按归档时间倒序',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.labelMd.copyWith(color: palette.outline),
          ),
        ),
      ],
    );
  }
}
