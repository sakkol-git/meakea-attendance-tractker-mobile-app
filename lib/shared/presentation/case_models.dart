import '../../features/identity/domain/models.dart';
import '../domain/cases.dart';

enum FieldKind {
  text,
  email,
  number,
  integer,
  date,
  time,
  note,
  choice,
  lookup,
  toggle,
  weekdays,
}

class CaseField {
  final String key, label;
  final FieldKind kind;
  final bool required;
  final Map<String, String> choices;
  final String? lookup;
  final String valueField;
  final Object? initial;
  final num? minimum, maximum;

  const CaseField(
    this.key,
    this.label, {
    this.kind = FieldKind.text,
    this.required = true,
    this.choices = const {},
    this.lookup,
    this.valueField = 'id',
    this.initial,
    this.minimum,
    this.maximum,
  });
}

class CaseAction {
  final String key, label;
  final List<CaseField> fields;
  final List<String> inherit;
  final String? targetField, prepare;
  final bool destructive;
  final bool Function(CaseRecord?, Profile)? when;

  const CaseAction(
    this.key,
    this.label, {
    this.fields = const [],
    this.inherit = const [],
    this.targetField,
    this.prepare,
    this.destructive = false,
    this.when,
  });
}

class CasePanel {
  final String key, title, description;
  final Map<String, String> details;
  final List<CaseAction> actions;
  final CaseAction? create;
  final bool dates;
  final String access;

  const CasePanel(
    this.key,
    this.title,
    this.description, {
    this.details = const {},
    this.actions = const [],
    this.create,
    this.dates = false,
    this.access = 'hr',
  });
}
