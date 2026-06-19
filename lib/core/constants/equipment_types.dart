// lib/core/constants/equipment_types.dart

enum EquipmentType {
  barbell('Barbell'),
  dumbbell('Dumbbell'),
  cable('Cable'),
  machine('Machine'),
  smithMachine('Smith Machine'),
  ezBar('EZ Bar'),
  kettlebell('Kettlebell'),
  resistanceBand('Resistance Band'),
  plate('Plate'),
  bodyweight('Bodyweight'),
  none('None');

  final String displayName;
  const EquipmentType(this.displayName);

  static EquipmentType fromString(String value) {
    return EquipmentType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => EquipmentType.none,
    );
  }
}
