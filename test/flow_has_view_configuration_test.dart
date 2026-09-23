import 'package:adapty_flutter/src/models/adapty_flow.dart';
import 'package:flutter_test/flutter_test.dart';

/// `flow_version_id` and `ui_schema` are two halves of one native structure:
/// iOS carries them in a single optional `LayoutsConfiguration`, and Android
/// drops both unless both are present. A flow that has only one of them has no
/// renderable view configuration, so both must be required here too.
void main() {
  test('a flow has a view configuration only when both halves are present', () {
    expect(_flow(uiSchema: true, flowVersionId: true).hasViewConfiguration, isTrue);
    expect(_flow(uiSchema: true, flowVersionId: false).hasViewConfiguration, isFalse);
    expect(_flow(uiSchema: false, flowVersionId: true).hasViewConfiguration, isFalse);
    expect(_flow(uiSchema: false, flowVersionId: false).hasViewConfiguration, isFalse);
  });
}

AdaptyFlow _flow({required bool uiSchema, required bool flowVersionId}) => AdaptyFlowJSONBuilder.fromJsonValue({
  'placement': {
    'developer_id': 'placement-id',
    'audience_name': 'Audience',
    'revision': 1,
    'ab_test_name': 'Experiment',
    'placement_audience_version_id': 'placement-audience-version-id',
  },
  'flow_id': 'flow-id',
  'flow_name': 'Flow',
  'variation_id': 'variation-id',
  'remote_configs': <dynamic>[],
  'variations': <dynamic>[],
  if (flowVersionId) 'flow_version_id': 'flow-version-id',
  if (uiSchema)
    'ui_schema': {
      'layouts': [
        {'flow_layout_id': 'flow-layout-id'},
      ],
      'grids': [
        {'platforms': 'all', 'devices': 'all', 'custom_id': 'configured-grid-id', 'cells': <dynamic>[]},
      ],
    },
  'response_created_at': 0,
});
