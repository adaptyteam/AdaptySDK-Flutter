import 'package:meta/meta.dart' show immutable;

import 'private/json_builder.dart';

part 'private/adapty_flow_ui_schema_json_builder.dart';

@immutable
class AdaptyFlowUiSchema {
  final List<AdaptyFlowUiSchemaLayout> layouts;
  final List<AdaptyFlowUiSchemaGrid> grids;

  const AdaptyFlowUiSchema._(this.layouts, this.grids);

  @override
  String toString() => '(layouts: $layouts, grids: $grids)';
}

@immutable
class AdaptyFlowUiSchemaLayout {
  final String flowLayoutId;

  const AdaptyFlowUiSchemaLayout._(this.flowLayoutId);

  @override
  String toString() => '(flowLayoutId: $flowLayoutId)';
}

@immutable
class AdaptyFlowUiSchemaGrid {
  /// `null` means all platforms.
  final List<String>? platforms;

  /// `null` means all devices.
  final List<String>? devices;

  final String? customId;
  final List<int> hBreakpoints;
  final List<int> vBreakpoints;
  final List<int> cells;

  const AdaptyFlowUiSchemaGrid._(
    this.platforms,
    this.devices,
    this.customId,
    this.hBreakpoints,
    this.vBreakpoints,
    this.cells,
  );

  @override
  String toString() =>
      '(platforms: $platforms, '
      'devices: $devices, '
      'customId: $customId, '
      'hBreakpoints: $hBreakpoints, '
      'vBreakpoints: $vBreakpoints, '
      'cells: $cells)';
}
