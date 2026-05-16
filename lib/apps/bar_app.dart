import 'package:flutter/material.dart';
import 'package:heroui_design_system/heroui_design_system.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:intl/intl.dart';

/// 酒吧系统子应用
class BarApp extends StatefulWidget {
  const BarApp({super.key});

  @override
  State<BarApp> createState() => _BarAppState();
}

class _BarAppState extends State<BarApp> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('酒吧管理系统'),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => Navigator.of(context).pop(),
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(LucideIcons.package), text: '库存管理'),
            Tab(icon: Icon(LucideIcons.receipt), text: '采购记录'),
            Tab(icon: Icon(LucideIcons.truck), text: '供应商'),
            Tab(icon: Icon(LucideIcons.pieChart), text: '统计报表'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _InventoryPage(),
          _PurchaseRecordPage(),
          _SupplierPage(),
          _StatisticsPage(),
        ],
      ),
    );
  }
}

// ==================== 库存管理页面 ====================
class _InventoryPage extends StatefulWidget {
  @override
  State<_InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<_InventoryPage> {
  String? _selectedCategoryId;
  String _searchQuery = '';

  // 模拟分类数据
  final List<Map<String, dynamic>> _categories = [
    {'id': null, 'name': '全部', 'icon': LucideIcons.layers},
    {'id': 1, 'name': '家具设备', 'icon': LucideIcons.armchair},
    {'id': 2, 'name': '装饰布置', 'icon': LucideIcons.palette},
    {'id': 3, 'name': '酒水饮料', 'icon': LucideIcons.wine},
    {'id': 4, 'name': '杯具器皿', 'icon': LucideIcons.glassWater},
    {'id': 5, 'name': '零食小吃', 'icon': LucideIcons.cookie},
    {'id': 6, 'name': '耗材用品', 'icon': LucideIcons.box},
  ];

  // 模拟库存数据
  final List<Map<String, dynamic>> _inventoryItems = [
    {'id': 1, 'name': '吧台高脚椅', 'category_id': 1, 'spec': '黑色/镀铬', 'unit': '把', 'quantity': 12, 'unit_price': 350.00, 'location': '吧台区'},
    {'id': 2, 'name': '吧台桌', 'category_id': 1, 'spec': '2m长', 'unit': '张', 'quantity': 3, 'unit_price': 1200.00, 'location': '吧台区'},
    {'id': 3, 'name': '莫吉托', 'category_id': 3, 'spec': '500ml', 'unit': '杯', 'quantity': 50, 'unit_price': 58.00, 'location': '冰箱'},
    {'id': 4, 'name': '威士忌', 'category_id': 3, 'spec': '700ml', 'unit': '瓶', 'quantity': 20, 'unit_price': 88.00, 'location': '酒柜'},
    {'id': 5, 'name': '啤酒', 'category_id': 3, 'spec': '330ml', 'unit': '瓶', 'quantity': 100, 'unit_price': 28.00, 'location': '冰箱'},
    {'id': 6, 'name': '红酒杯', 'category_id': 4, 'spec': '大号', 'unit': '个', 'quantity': 48, 'unit_price': 25.00, 'location': '杯架'},
    {'id': 7, 'name': '鸡尾酒杯', 'category_id': 4, 'spec': '标准', 'unit': '个', 'quantity': 36, 'unit_price': 18.00, 'location': '杯架'},
    {'id': 8, 'name': '纸巾', 'category_id': 6, 'spec': '大包', 'unit': '包', 'quantity': 20, 'unit_price': 15.00, 'location': '仓库'},
    {'id': 9, 'name': '装饰画', 'category_id': 2, 'spec': '80x120cm', 'unit': '幅', 'quantity': 5, 'unit_price': 280.00, 'location': '墙面'},
  ];

  List<Map<String, dynamic>> get _filteredItems {
    var items = _inventoryItems;
    if (_selectedCategoryId != null) {
      items = items.where((item) => item['category_id'] == _selectedCategoryId).toList();
    }
    if (_searchQuery.isNotEmpty) {
      items = items.where((item) =>
        item['name'].toString().toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 搜索栏
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            decoration: InputDecoration(
              hintText: '搜索物品...',
              prefixIcon: const Icon(LucideIcons.search, size: 20),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onChanged: (value) => setState(() => _searchQuery = value),
          ),
        ),
        // 分类标签
        SizedBox(
          height: 50,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _categories.length,
            itemBuilder: (context, index) {
              final cat = _categories[index];
              final isSelected = _selectedCategoryId == cat['id'];
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(cat['icon'], size: 16),
                      const SizedBox(width: 4),
                      Text(cat['name']),
                    ],
                  ),
                  selected: isSelected,
                  onSelected: (_) => setState(() => _selectedCategoryId = isSelected ? null : cat['id']),
                  selectedColor: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                ),
              );
            },
          ),
        ),
        const Divider(height: 1),
        // 物品列表
        Expanded(
          child: _filteredItems.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(LucideIcons.package, size: 48, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3)),
                      const SizedBox(height: 16),
                      Text('暂无物品', style: HeroUiTypography.bodySm),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _filteredItems.length,
                  itemBuilder: (context, index) => _buildInventoryCard(_filteredItems[index]),
                ),
        ),
      ],
    );
  }

  Widget _buildInventoryCard(Map<String, dynamic> item) {
    final categoryName = _categories.firstWhere((c) => c['id'] == item['category_id'], orElse: () => {'name': '其他'})['name'];

    return HeroUiCard(
      borderRadius: 12,
      showShadow: false,
      borderColor: Theme.of(context).dividerColor,
      onTap: () => _showItemDetail(item),
      body: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(LucideIcons.box, color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(item['name'], style: HeroUiTypography.bodySmMedium),
                    if (item['spec'] != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(item['spec'], style: HeroUiTypography.bodyXs),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '$categoryName · ${item['location'] ?? '-'}',
                  style: HeroUiTypography.bodyXs.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${item['quantity']} ${item['unit']}',
                style: HeroUiTypography.bodySmMedium.copyWith(
                  color: (item['quantity'] as int) < 10 ? Colors.red : Theme.of(context).colorScheme.primary,
                ),
              ),
              Text(
                '¥${item['unit_price'].toStringAsFixed(0)}/${item['unit']}',
                style: HeroUiTypography.bodyXs.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
            ],
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
    );
  }

  void _showItemDetail(Map<String, dynamic> item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(item['name'], style: HeroUiTypography.heading4),
                  IconButton(
                    icon: const Icon(LucideIcons.x),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildDetailRow('规格', item['spec'] ?? '-'),
              _buildDetailRow('单位', item['unit']),
              _buildDetailRow('单价', '¥${item['unit_price'].toStringAsFixed(2)}'),
              _buildDetailRow('库存数量', '${item['quantity']} ${item['unit']}'),
              _buildDetailRow('存放位置', item['location'] ?? '-'),
              const Divider(height: 32),
              const Text('操作', style: HeroUiTypography.bodySmMedium),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: HeroUiButton(
                      label: '采购入库',
                      onPressed: () => Navigator.pop(context),
                      variant: HeroUiButtonVariant.primary,
                      size: HeroUiButtonSize.sm,
                      leading: const Icon(LucideIcons.plus, size: 16),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: HeroUiButton(
                      label: '领用出库',
                      onPressed: () => Navigator.pop(context),
                      variant: HeroUiButtonVariant.secondary,
                      size: HeroUiButtonSize.sm,
                      leading: const Icon(LucideIcons.minus, size: 16),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: HeroUiTypography.bodyXs.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
          )),
          Text(value, style: HeroUiTypography.bodySm),
        ],
      ),
    );
  }
}

// ==================== 采购记录页面 ====================
class _PurchaseRecordPage extends StatefulWidget {
  @override
  State<_PurchaseRecordPage> createState() => _PurchaseRecordPageState();
}

class _PurchaseRecordPageState extends State<_PurchaseRecordPage> {
  DateTime _selectedMonth = DateTime.now();

  final List<Map<String, dynamic>> _purchaseRecords = [
    {
      'id': 1,
      'date': DateTime.now().subtract(const Duration(days: 1)),
      'item': '威士忌',
      'quantity': 5,
      'unit': '瓶',
      'unit_price': 450.00,
      'total_price': 2250.00,
      'channel': '本地酒水批发',
      'supplier': '王老板',
      'status': 'completed',
    },
    {
      'id': 2,
      'date': DateTime.now().subtract(const Duration(days: 3)),
      'item': '吧台高脚椅',
      'quantity': 4,
      'unit': '把',
      'unit_price': 380.00,
      'total_price': 1520.00,
      'channel': '淘宝',
      'supplier': '酒吧用品旗舰店',
      'status': 'completed',
    },
    {
      'id': 3,
      'date': DateTime.now().subtract(const Duration(days: 5)),
      'item': '装饰画',
      'quantity': 2,
      'unit': '幅',
      'unit_price': 280.00,
      'total_price': 560.00,
      'channel': '线下',
      'supplier': '本地建材市场',
      'status': 'completed',
    },
    {
      'id': 4,
      'date': DateTime.now().subtract(const Duration(days: 7)),
      'item': '纸巾',
      'quantity': 10,
      'unit': '包',
      'unit_price': 15.00,
      'total_price': 150.00,
      'channel': '美团',
      'supplier': '超市配送',
      'status': 'completed',
    },
    {
      'id': 5,
      'date': DateTime.now(),
      'item': '红酒杯',
      'quantity': 24,
      'unit': '个',
      'unit_price': 28.00,
      'total_price': 672.00,
      'channel': '淘宝',
      'supplier': '玻璃器皿店',
      'status': 'pending',
    },
  ];

  double get _monthTotal {
    final monthRecords = _purchaseRecords.where((r) {
      final date = r['date'] as DateTime;
      return date.year == _selectedMonth.year && date.month == _selectedMonth.month;
    });
    return monthRecords.fold(0.0, (sum, r) => sum + (r['total_price'] as double));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 月份选择和汇总
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.05),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(LucideIcons.chevronLeft),
                onPressed: () => setState(() => _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1)),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      DateFormat('yyyy年M月').format(_selectedMonth),
                      style: HeroUiTypography.bodySmMedium,
                    ),
                    Text(
                      '本月采购: ¥${_monthTotal.toStringAsFixed(2)}',
                      style: HeroUiTypography.bodyXs.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(LucideIcons.chevronRight),
                onPressed: () => setState(() => _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1)),
              ),
            ],
          ),
        ),
        // 记录列表
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _purchaseRecords.length,
            itemBuilder: (context, index) => _buildPurchaseCard(_purchaseRecords[index]),
          ),
        ),
        // 添加按钮
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: HeroUiButton(
              label: '添加采购记录',
              onPressed: () => _showAddPurchaseDialog(),
              variant: HeroUiButtonVariant.primary,
              size: HeroUiButtonSize.lg,
              leading: const Icon(LucideIcons.plus, size: 18),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPurchaseCard(Map<String, dynamic> record) {
    final date = record['date'] as DateTime;
    final isPending = record['status'] == 'pending';

    return HeroUiCard(
      borderRadius: 12,
      showShadow: false,
      borderColor: Theme.of(context).dividerColor,
      body: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isPending
                  ? Colors.orange.withOpacity(0.1)
                  : Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              LucideIcons.receipt,
              color: isPending ? Colors.orange : Colors.green,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(record['item'], style: HeroUiTypography.bodySmMedium),
                    if (isPending) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('待收货', style: HeroUiTypography.bodyXs.copyWith(color: Colors.orange)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${record['quantity']} ${record['unit']} × ¥${record['unit_price'].toStringAsFixed(0)}',
                  style: HeroUiTypography.bodyXs.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '¥${record['total_price'].toStringAsFixed(0)}',
                style: HeroUiTypography.bodySmMedium.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              Text(
                DateFormat('M/d').format(date),
                style: HeroUiTypography.bodyXs.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
            ],
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
    );
  }

  void _showAddPurchaseDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('添加采购记录', style: HeroUiTypography.heading4),
                IconButton(
                  icon: const Icon(LucideIcons.x),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              decoration: InputDecoration(
                labelText: '物品名称',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    decoration: InputDecoration(
                      labelText: '数量',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      labelText: '单位',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      labelText: '单价',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixText: '¥',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      labelText: '购买渠道',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              decoration: InputDecoration(
                labelText: '供应商',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            // 上传凭证
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).dividerColor),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.imagePlus, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Text('上传购买凭证', style: HeroUiTypography.bodySm.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  )),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: HeroUiButton(
                label: '保存',
                onPressed: () => Navigator.pop(context),
                variant: HeroUiButtonVariant.primary,
                size: HeroUiButtonSize.lg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== 供应商页面 ====================
class _SupplierPage extends StatelessWidget {
  final List<Map<String, dynamic>> _suppliers = [
    {'id': 1, 'name': '本地酒水批发', 'contact': '王老板', 'phone': '13800001111', 'wechat': 'wx_wang', 'type': '酒水'},
    {'id': 2, 'name': '酒吧用品旗舰店', 'contact': '客服', 'phone': '-', 'wechat': '-', 'type': '淘宝'},
    {'id': 3, 'name': '美团零食供应商', 'contact': '李经理', 'phone': '13800002222', 'wechat': 'wx_li', 'type': '零食'},
    {'id': 4, 'name': '本地建材市场', 'contact': '张师傅', 'phone': '13800003333', 'wechat': '-', 'type': '家具'},
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _suppliers.length,
            itemBuilder: (context, index) => _buildSupplierCard(context, _suppliers[index]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: HeroUiButton(
              label: '添加供应商',
              onPressed: () {},
              variant: HeroUiButtonVariant.primary,
              size: HeroUiButtonSize.lg,
              leading: const Icon(LucideIcons.plus, size: 18),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSupplierCard(BuildContext context, Map<String, dynamic> supplier) {
    return HeroUiCard(
      borderRadius: 12,
      showShadow: false,
      borderColor: Theme.of(context).dividerColor,
      body: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(LucideIcons.building2, color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(supplier['name'], style: HeroUiTypography.bodySmMedium),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(supplier['type'], style: HeroUiTypography.bodyXs),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${supplier['contact']} · ${supplier['phone']}',
                  style: HeroUiTypography.bodyXs.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(LucideIcons.phone, size: 18),
            onPressed: () {},
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
    );
  }
}

// ==================== 统计报表页面 ====================
class _StatisticsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('本月概览', style: HeroUiTypography.heading4),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildStatCard(context, '采购总额', '¥5,132', LucideIcons.shoppingCart, Colors.blue)),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard(context, '采购笔数', '12', LucideIcons.fileText, Colors.green)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildStatCard(context, '新增物品', '8', LucideIcons.packagePlus, Colors.orange)),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard(context, '供应商数', '4', LucideIcons.building2, Colors.purple)),
            ],
          ),
          const SizedBox(height: 24),
          Text('分类采购占比', style: HeroUiTypography.heading4),
          const SizedBox(height: 16),
          ..._buildCategoryStats(context),
          const SizedBox(height: 24),
          Text('近期采购趋势', style: HeroUiTypography.heading4),
          const SizedBox(height: 16),
          Container(
            height: 150,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text('图表区域（待实现）', style: HeroUiTypography.bodyXs.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              )),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, String title, String value, IconData icon, Color color) {
    return HeroUiCard(
      borderRadius: 16,
      showShadow: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(height: 12),
          Text(value, style: HeroUiTypography.heading4),
          const SizedBox(height: 4),
          Text(title, style: HeroUiTypography.bodyXs.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
          )),
        ],
      ),
      padding: const EdgeInsets.all(16),
    );
  }

  List<Widget> _buildCategoryStats(BuildContext context) {
    final categories = [
      {'name': '酒水饮料', 'amount': 2250.00, 'percent': 44},
      {'name': '家具设备', 'amount': 1520.00, 'percent': 30},
      {'name': '杯具器皿', 'amount': 672.00, 'percent': 13},
      {'name': '其他', 'amount': 690.00, 'percent': 13},
    ];

    return categories.map((cat) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(cat['name'] as String, style: HeroUiTypography.bodySm),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: (cat['percent'] as int) / 100,
                    backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Text('¥${(cat['amount'] as double).toStringAsFixed(0)}', style: HeroUiTypography.bodySmMedium),
          ],
        ),
      );
    }).toList();
  }
}
