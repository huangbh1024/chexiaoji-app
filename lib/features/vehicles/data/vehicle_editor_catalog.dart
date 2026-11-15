/// 车辆档案编辑器的静态选项。
abstract final class VehicleEditorCatalog {
  const VehicleEditorCatalog._();

  static const commonProvinces = <String>[
    '粤',
    '京',
    '沪',
    '浙',
    '苏',
    '川',
    '鲁',
    '豫',
    '鄂',
    '湘',
    '闽',
    '皖',
  ];

  static const allProvinces = <String>[
    '京',
    '津',
    '冀',
    '晋',
    '蒙',
    '辽',
    '吉',
    '黑',
    '沪',
    '苏',
    '浙',
    '皖',
    '闽',
    '赣',
    '鲁',
    '豫',
    '鄂',
    '湘',
    '粤',
    '桂',
    '琼',
    '渝',
    '川',
    '贵',
    '云',
    '藏',
    '陕',
    '甘',
    '青',
    '宁',
    '新',
  ];

  static const quickModels = <String>[
    '特斯拉 Model Y',
    '比亚迪 汉 EV',
    '理想 L7 Pro',
    '小米 SU7 Max',
  ];

  static const fuelGrades = <int>[92, 95, 98];
}
