part of '../adapty_flow_ui_schema.dart';

extension AdaptyFlowUiSchemaJSONBuilder on AdaptyFlowUiSchema {
  dynamic get jsonValue => {
    _Keys.layouts: layouts.map((e) => e.jsonValue).toList(growable: false),
    _Keys.grids: grids.map((e) => e.jsonValue).toList(growable: false),
  };

  static AdaptyFlowUiSchema fromJsonValue(Map<String, dynamic> json) {
    final layouts = json[_Keys.layouts] as List<dynamic>;
    final grids = json[_Keys.grids] as List<dynamic>;

    return AdaptyFlowUiSchema._(
      layouts
          .map((e) => AdaptyFlowUiSchemaLayoutJSONBuilder.fromJsonValue(e as Map<String, dynamic>))
          .toList(growable: false),
      grids
          .map((e) => AdaptyFlowUiSchemaGridJSONBuilder.fromJsonValue(e as Map<String, dynamic>))
          .toList(growable: false),
    );
  }
}

extension AdaptyFlowUiSchemaLayoutJSONBuilder on AdaptyFlowUiSchemaLayout {
  dynamic get jsonValue => {_Keys.flowLayoutId: flowLayoutId};

  static AdaptyFlowUiSchemaLayout fromJsonValue(Map<String, dynamic> json) {
    return AdaptyFlowUiSchemaLayout._(json.string(_Keys.flowLayoutId));
  }
}

extension AdaptyFlowUiSchemaGridJSONBuilder on AdaptyFlowUiSchemaGrid {
  dynamic get jsonValue => {
    if (platforms == null) _Keys.platforms: _Keys.all else if (platforms!.isNotEmpty) _Keys.platforms: platforms,
    if (devices == null) _Keys.devices: _Keys.all else if (devices!.isNotEmpty) _Keys.devices: devices,
    if (customId != null) _Keys.customId: customId,
    if (hBreakpoints.isNotEmpty) _Keys.hBreakpoints: hBreakpoints,
    if (vBreakpoints.isNotEmpty) _Keys.vBreakpoints: vBreakpoints,
    _Keys.cells: cells,
  };

  static AdaptyFlowUiSchemaGrid fromJsonValue(Map<String, dynamic> json) {
    return AdaptyFlowUiSchemaGrid._(
      _stringListOrAll(json, _Keys.platforms),
      _stringListOrAll(json, _Keys.devices),
      json.stringIfPresent(_Keys.customId),
      _integerListIfPresent(json, _Keys.hBreakpoints) ?? const [],
      _integerListIfPresent(json, _Keys.vBreakpoints) ?? const [],
      _integerList(json, _Keys.cells),
    );
  }

  static List<String>? _stringListOrAll(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value == null) return const [];
    if (value is String && value == _Keys.all) return null;
    return (value as List<dynamic>).map((e) => e as String).toList(growable: false);
  }

  static List<int> _integerList(Map<String, dynamic> json, String key) {
    final value = json[key] as List<dynamic>;
    return value.map((e) => e as int).toList(growable: false);
  }

  static List<int>? _integerListIfPresent(Map<String, dynamic> json, String key) {
    final value = json[key] as List<dynamic>?;
    return value?.map((e) => e as int).toList(growable: false);
  }
}

class _Keys {
  static const layouts = 'layouts';
  static const grids = 'grids';
  static const flowLayoutId = 'flow_layout_id';
  static const platforms = 'platforms';
  static const devices = 'devices';
  static const all = 'all';
  static const customId = 'custom_id';
  static const hBreakpoints = 'h_breakpoints';
  static const vBreakpoints = 'v_breakpoints';
  static const cells = 'cells';
}
