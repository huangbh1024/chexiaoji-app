import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/tab.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/presentation/toast.dart';
import '../../../core/widgets/blurred_header_delegate.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/section_error.dart';
import '../../expense_entry/domain/expense_entry_models.dart';
import '../../expense_entry/presentation/expense_entry_routes.dart';
import '../../home/domain/providers.dart';
import '../../profile/domain/providers.dart';
import '../../stats/domain/providers.dart';
import '../domain/providers.dart';
import '../domain/vehicle_models.dart';
import '../domain/vehicle_presenter.dart';
import 'widgets/add_vehicle_card.dart';
import 'widgets/archived_entry_card.dart';
import 'widgets/archived_vehicles_sheet.dart';
import 'widgets/fleet_summary_card.dart';
import 'widgets/vehicle_confirm_sheets.dart';
import 'widgets/vehicle_management_header.dart';
import 'widgets/vehicle_management_skeleton.dart';
import 'widgets/vehicle_member_card.dart';
import 'widgets/vehicle_more_sheet.dart';

/// 车辆管理：车库总览、逐车卡片与主驾 / 归档 / 删除操作。
class VehicleManagementPage extends ConsumerWidget {
  const VehicleManagementPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final tokens = context.tokens;
    final garage = ref.watch(garageProvider);
    final command = ref.watch(vehicleCommandProvider);
    final summary = garage.value?.summary;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: palette.background,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 448),
          child: SafeArea(
            bottom: false,
            child: RefreshIndicator(
              color: palette.primary,
              onRefresh: () => _refresh(ref),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: BlurredHeaderDelegate(
                      height: tokens.headerHeight,
                      child: VehicleManagementHeader(
                        summary: summary,
                        canPop: !command.isBusy,
                        onAdd: () => _addPlaceholder(context),
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
                        _contentSlivers(context, ref, garage, command),
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

  List<Widget> _contentSlivers(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<GarageOverview> garage,
    VehicleCommandState command,
  ) {
    final tokens = context.tokens;
    if (!garage.hasValue) {
      if (garage.hasError) {
        return [
          SectionError(
            message: '车库加载失败',
            onRetry: () => ref.invalidate(garageProvider),
          ),
          SizedBox(height: tokens.spaceLg),
          AddVehicleCard(onTap: () => _addPlaceholder(context)),
        ];
      }
      return const [VehicleManagementSkeleton()];
    }

    final overview = garage.value!;
    final vehicles = overview.vehicles;
    final palette = context.palette;

    return [
      FleetSummaryCard(summary: overview.summary),
      SizedBox(height: tokens.spaceLg),
      Row(
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
            '车队成员',
            style: AppTypography.headlineSm.copyWith(color: palette.onSurface),
          ),
          const Spacer(),
          Text(
            '共 ${vehicles.length} 辆',
            style: AppTypography.bodySm.copyWith(color: palette.outline),
          ),
        ],
      ),
      SizedBox(height: tokens.spaceMd),
      if (vehicles.isEmpty)
        EmptyState(
          icon: Icons.directions_car_rounded,
          title: '车库还是空的',
          actionLabel: '添加第一辆爱车',
          onAction: () => _addPlaceholder(context),
        )
      else
        for (var index = 0; index < vehicles.length; index++) ...[
          if (index > 0) const SizedBox(height: 12),
          VehicleMemberCard(
            key: ValueKey<String>(vehicles[index].id),
            vehicle: vehicles[index],
            isBusy: command.isBusy,
            onRecord: () => _record(context, ref, vehicles[index]),
            onStats: () => _openStats(context, ref, vehicles[index]),
            onSetPrimary: () => _setPrimary(context, ref, vehicles[index]),
            onEdit: () => _editPlaceholder(context),
            onMore: () => _openMore(context, ref, vehicles[index], overview),
          ),
        ],
      const SizedBox(height: 12),
      AddVehicleCard(onTap: () => _addPlaceholder(context)),
      if (overview.archivedVehicles.isNotEmpty) ...[
        const SizedBox(height: 12),
        ArchivedEntryCard(
          count: overview.archivedVehicles.length,
          onTap: () => _openArchived(context, ref, overview),
        ),
      ],
    ];
  }

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(garageProvider);
    ref.invalidate(vehiclesProvider);
    ref.invalidate(profileGarageProvider);
    try {
      await ref.read(garageProvider.future);
    } catch (_) {
      // 错误态由页面自行展示。
    }
  }

  void _addPlaceholder(BuildContext context) {
    showAppToast(context, '添加爱车页待接入');
  }

  void _editPlaceholder(BuildContext context) {
    showAppToast(context, '车辆档案编辑待接入');
  }

  Future<void> _record(
    BuildContext context,
    WidgetRef ref,
    ManagedVehicle vehicle,
  ) async {
    final result = await openExpenseEntry(
      context,
      args: ExpenseEntryArgs.create(initialVehicleId: vehicle.id),
    );
    if (result != null && context.mounted) {
      ref.invalidate(garageProvider);
      ref.invalidate(vehiclesProvider);
    }
  }

  void _openStats(BuildContext context, WidgetRef ref, ManagedVehicle vehicle) {
    ref.read(statsFilterProvider.notifier).selectVehicle(vehicle.id);
    ref.read(appTabProvider.notifier).select(AppTab.stats);
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _openMore(
    BuildContext context,
    WidgetRef ref,
    ManagedVehicle vehicle,
    GarageOverview garage,
  ) async {
    final action = await showVehicleMoreSheet(context, vehicle);
    if (!context.mounted || action == null) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 160));
    if (!context.mounted) {
      return;
    }
    switch (action) {
      case VehicleMoreAction.setPrimary:
        await _setPrimary(context, ref, vehicle);
      case VehicleMoreAction.edit:
        _editPlaceholder(context);
      case VehicleMoreAction.archive:
        await _archive(context, ref, vehicle, garage);
      case VehicleMoreAction.delete:
        await _delete(context, ref, vehicle, garage);
    }
  }

  Future<void> _setPrimary(
    BuildContext context,
    WidgetRef ref,
    ManagedVehicle vehicle,
  ) async {
    if (vehicle.isPrimary) {
      return;
    }
    final confirmed = await showSetPrimarySheet(
      context,
      vehicle,
      onConfirm: () => _runCommand(
        ref,
        () => ref.read(vehicleCommandProvider.notifier).setPrimary(vehicle.id),
      ),
    );
    if (confirmed == true && context.mounted) {
      showAppToast(context, '已将 ${vehicle.vehicle.name} 设为默认主驾');
    }
  }

  Future<void> _archive(
    BuildContext context,
    WidgetRef ref,
    ManagedVehicle vehicle,
    GarageOverview garage,
  ) async {
    final sole = garage.vehicles.length == 1;
    final wasPrimary = vehicle.isPrimary;
    final successor = _successorOf(garage, vehicle);

    final buffer = StringBuffer('归档后，该车辆将从常用车库移出，但过往记账流水与统计数据完整保留，可随时恢复。');
    if (sole) {
      buffer.write('归档后车库将为空，默认主驾将被清空；历史流水仍保留在账单与统计中。');
    } else if (wasPrimary && successor != null) {
      buffer.write('归档后，车库中的「${successor.vehicle.name}」将成为默认主驾。');
    }

    final confirmed = await showArchiveVehicleSheet(
      context,
      vehicle,
      body: buffer.toString(),
      confirmLabel: sole ? '确认归档并清空车库' : '确认归档',
      onConfirm: () => _runCommand(
        ref,
        () => ref.read(vehicleCommandProvider.notifier).archive(vehicle.id),
      ),
    );
    if (confirmed == true && context.mounted) {
      showAppToast(context, '已将「${vehicle.vehicle.name}」归档');
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    ManagedVehicle vehicle,
    GarageOverview garage,
  ) async {
    final reason = VehiclePresenter.deleteBlockReason(vehicle, garage);
    final result = await showDeleteVehicleSheet(
      context,
      vehicle,
      blockReason: reason,
      recordCount: vehicle.recordCount,
      onConfirm: () => _runCommand(
        ref,
        () => ref.read(vehicleCommandProvider.notifier).delete(vehicle.id),
      ),
    );
    if (!context.mounted) {
      return;
    }
    if (result == DeleteSheetResult.archive) {
      await _archive(context, ref, vehicle, garage);
      return;
    }
    if (result == DeleteSheetResult.deleted) {
      showAppToast(context, '已删除「${vehicle.vehicle.name}」');
    }
  }

  Future<void> _openArchived(
    BuildContext context,
    WidgetRef ref,
    GarageOverview garage,
  ) async {
    final restored = await showArchivedVehiclesSheet(
      context,
      garage.archivedVehicles,
      onRestore: (vehicleId) => _runCommand(
        ref,
        () => ref.read(vehicleCommandProvider.notifier).restore(vehicleId),
      ),
    );
    if (restored == true && context.mounted) {
      showAppToast(context, '已恢复到车库');
    }
  }

  ManagedVehicle? _successorOf(GarageOverview garage, ManagedVehicle vehicle) {
    for (final item in garage.vehicles) {
      if (item.id != vehicle.id) {
        return item;
      }
    }
    return null;
  }

  Future<String?> _runCommand(
    WidgetRef ref,
    Future<bool> Function() action,
  ) async {
    final ok = await action();
    return ok
        ? null
        : (ref.read(vehicleCommandProvider).errorMessage ?? '操作失败，请重试');
  }
}
