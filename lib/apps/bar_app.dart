import 'package:flutter/material.dart';
import 'package:heroui_design_system/heroui_design_system.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

/// 酒吧系统子应用
class BarApp extends StatefulWidget {
  const BarApp({super.key});

  @override
  State<BarApp> createState() => _BarAppState();
}

class _BarAppState extends State<BarApp> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // 模拟酒水数据
  final List<DrinkItem> _drinks = [
    DrinkItem(id: '1', name: '莫吉托', category: '鸡尾酒', price: 58.0, stock: 50),
    DrinkItem(id: '2', name: '长岛冰茶', category: '鸡尾酒', price: 68.0, stock: 30),
    DrinkItem(id: '3', name: '威士忌', category: '烈酒', price: 88.0, stock: 20),
    DrinkItem(id: '4', name: '伏特加', category: '烈酒', price: 78.0, stock: 25),
    DrinkItem(id: '5', name: '啤酒', category: '啤酒', price: 28.0, stock: 100),
    DrinkItem(id: '6', name: '红酒', category: '葡萄酒', price: 128.0, stock: 15),
  ];

  // 当前订单
  final List<OrderItem> _currentOrder = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  double get _orderTotal => _currentOrder.fold(0, (sum, item) => sum + item.totalPrice);

  void _addToOrder(DrinkItem drink) {
    setState(() {
      final existingIndex = _currentOrder.indexWhere((item) => item.drink.id == drink.id);
      if (existingIndex >= 0) {
        _currentOrder[existingIndex].quantity++;
      } else {
        _currentOrder.add(OrderItem(drink: drink, quantity: 1));
      }
    });
  }

  void _removeFromOrder(int index) {
    setState(() {
      if (_currentOrder[index].quantity > 1) {
        _currentOrder[index].quantity--;
      } else {
        _currentOrder.removeAt(index);
      }
    });
  }

  void _clearOrder() {
    setState(() {
      _currentOrder.clear();
    });
  }

  void _confirmOrder() {
    if (_currentOrder.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认订单'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ..._currentOrder.map((item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${item.drink.name} x${item.quantity}'),
                  Text('¥${item.totalPrice.toStringAsFixed(2)}'),
                ],
              ),
            )),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('总计:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text('¥${_orderTotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          HeroUiButton(
            label: '确认',
            onPressed: () {
              Navigator.pop(context);
              _clearOrder();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('订单已提交'), backgroundColor: Colors.green),
              );
            },
            variant: HeroUiButtonVariant.primary,
            size: HeroUiButtonSize.sm,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('酒吧系统'),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => Navigator.of(context).pop(),
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(LucideIcons.wine), text: '酒水菜单'),
            Tab(icon: Icon(LucideIcons.shoppingCart), text: '当前订单'),
            Tab(icon: Icon(LucideIcons.barChart3), text: '销售统计'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDrinkMenu(),
          _buildCurrentOrder(),
          _buildStatistics(),
        ],
      ),
      floatingActionButton: _currentOrder.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _confirmOrder,
              label: Text('结算 ¥${_orderTotal.toStringAsFixed(2)}'),
              icon: const Icon(LucideIcons.check),
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
            )
          : null,
    );
  }

  /// 酒水菜单
  Widget _buildDrinkMenu() {
    final categories = ['全部', '鸡尾酒', '烈酒', '啤酒', '葡萄酒'];
    final selectedCategory = '全部';

    return Column(
      children: [
        // 分类筛选
        Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: categories.map((cat) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(cat),
                selected: cat == selectedCategory,
                onSelected: (_) {},
                selectedColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                checkmarkColor: Theme.of(context).colorScheme.primary,
              ),
            )).toList(),
          ),
        ),
        const Divider(height: 1),
        // 酒水列表
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.75,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: _drinks.length,
            itemBuilder: (context, index) => _buildDrinkCard(_drinks[index]),
          ),
        ),
      ],
    );
  }

  /// 酒水卡片
  Widget _buildDrinkCard(DrinkItem drink) {
    return HeroUiCard(
      borderRadius: 16,
      showShadow: true,
      onTap: drink.stock > 0 ? () => _addToOrder(drink) : null,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 图片区域（使用图标占位）
          Expanded(
            flex: 2,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    Theme.of(context).colorScheme.primary.withOpacity(0.3),
                  ],
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Center(
                child: Icon(
                  LucideIcons.wine,
                  size: 48,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ),
          // 信息区域
          Expanded(
            flex: 1,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        drink.name,
                        style: HeroUiTypography.bodySmMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        drink.category,
                        style: HeroUiTypography.bodyXs.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '¥${drink.price.toStringAsFixed(0)}',
                        style: HeroUiTypography.bodySmMedium.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: drink.stock > 10
                              ? Colors.green.withOpacity(0.1)
                              : drink.stock > 0
                                  ? Colors.orange.withOpacity(0.1)
                                  : Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          drink.stock > 0 ? '库存: ${drink.stock}' : '售罄',
                          style: HeroUiTypography.navLabel.copyWith(
                            color: drink.stock > 10
                                ? Colors.green
                                : drink.stock > 0
                                    ? Colors.orange
                                    : Colors.red,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      padding: EdgeInsets.zero,
    );
  }

  /// 当前订单
  Widget _buildCurrentOrder() {
    if (_currentOrder.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              LucideIcons.shoppingCart,
              size: 64,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
            ),
            const SizedBox(height: 16),
            Text(
              '暂无订单',
              style: HeroUiTypography.bodySm.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '点击酒水菜单添加商品',
              style: HeroUiTypography.bodyXs.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: _currentOrder.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final item = _currentOrder[index];
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
                      child: Icon(
                        LucideIcons.wine,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.drink.name, style: HeroUiTypography.bodySmMedium),
                          Text(
                            '¥${item.drink.price.toStringAsFixed(0)} / 杯',
                            style: HeroUiTypography.bodyXs.copyWith(
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(LucideIcons.minus, size: 18),
                          onPressed: () => _removeFromOrder(index),
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          padding: EdgeInsets.zero,
                        ),
                        Container(
                          width: 32,
                          alignment: Alignment.center,
                          child: Text('${item.quantity}', style: HeroUiTypography.bodySmMedium),
                        ),
                        IconButton(
                          icon: const Icon(LucideIcons.plus, size: 18),
                          onPressed: () => _addToOrder(item.drink),
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          padding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '¥${item.totalPrice.toStringAsFixed(0)}',
                      style: HeroUiTypography.bodySmMedium.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(12),
              );
            },
          ),
        ),
        // 底部汇总
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                onPressed: _clearOrder,
                icon: const Icon(LucideIcons.trash2, size: 16),
                label: const Text('清空'),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
              ),
              Row(
                children: [
                  Text('共 ${_currentOrder.fold(0, (sum, item) => sum + item.quantity)} 件', style: HeroUiTypography.bodySm),
                  const SizedBox(width: 16),
                  Text('合计: ', style: HeroUiTypography.bodySm),
                  Text('¥${_orderTotal.toStringAsFixed(2)}', style: HeroUiTypography.heading4.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  )),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 销售统计
  Widget _buildStatistics() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 今日销售概览
          Text('今日销售概览', style: HeroUiTypography.heading4),
          const SizedBox(height: 16),

          // 统计卡片
          Row(
            children: [
              Expanded(child: _buildStatCard('总营业额', '¥2,580', LucideIcons.dollarSign, Colors.green)),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard('订单数', '23', LucideIcons.shoppingBag, Colors.blue)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildStatCard('平均客单价', '¥112', LucideIcons.trendingUp, Colors.orange)),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard('客户数', '18', LucideIcons.users, Colors.purple)),
            ],
          ),

          const SizedBox(height: 24),

          // 热销排行
          Text('热销排行', style: HeroUiTypography.heading4),
          const SizedBox(height: 12),
          ...List.generate(5, (index) => _buildRankItem(index + 1)),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return HeroUiCard(
      borderRadius: 16,
      showShadow: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              const Spacer(),
              Icon(LucideIcons.arrowUpRight, size: 16, color: Colors.green),
              Text('+12%', style: HeroUiTypography.navLabel.copyWith(color: Colors.green)),
            ],
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

  Widget _buildRankItem(int rank) {
    final drinkNames = ['莫吉托', '长岛冰茶', '威士忌', '啤酒', '红酒'];
    final sales = [45, 38, 32, 28, 22];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: rank <= 3
                  ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
            ),
            alignment: Alignment.center,
            child: Text(
              '$rank',
              style: HeroUiTypography.bodyXsMedium.copyWith(
                color: rank <= 3
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(drinkNames[rank - 1], style: HeroUiTypography.bodySm),
          ),
          Text('${sales[rank - 1]} 杯', style: HeroUiTypography.bodyXs.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
          )),
        ],
      ),
    );
  }
}

/// 酒水数据模型
class DrinkItem {
  final String id;
  final String name;
  final String category;
  final double price;
  final int stock;

  const DrinkItem({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.stock,
  });
}

/// 订单项
class OrderItem {
  final DrinkItem drink;
  int quantity;

  OrderItem({required this.drink, required this.quantity});

  double get totalPrice => drink.price * quantity;
}
