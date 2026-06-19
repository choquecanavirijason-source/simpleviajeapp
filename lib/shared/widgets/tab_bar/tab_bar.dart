import 'package:flutter/material.dart';

/// Un TabBar reutilizable con estilos negro/gris por defecto.
/// Implementa PreferredSizeWidget para poder usarlo en AppBar.bottom.
class AppTabBar extends StatelessWidget implements PreferredSizeWidget {
  const AppTabBar({
    super.key,
    required this.tabs,
    this.isScrollable = true,
    this.labelColor,
    this.unselectedLabelColor,
    this.indicatorColor,
    this.indicatorThickness = 3,
    this.controller,
    this.onTap,
  });

  final List<Widget> tabs;
  final bool isScrollable;
  final Color? labelColor;
  final Color? unselectedLabelColor;
  final Color? indicatorColor;
  final double indicatorThickness;
  final TabController? controller;
  final ValueChanged<int>? onTap;

  @override
  Size get preferredSize => const Size.fromHeight(kTextTabBarHeight);

  @override
  Widget build(BuildContext context) {
    final Color active = labelColor ?? Colors.black87;
    final Color inactive = unselectedLabelColor ?? Colors.grey;
    final Color underline = indicatorColor ?? active;

    return TabBar(
      controller: controller,
      isScrollable: isScrollable,
      labelColor: active,
      unselectedLabelColor: inactive,
      indicator: UnderlineTabIndicator(
        borderSide: BorderSide(width: indicatorThickness, color: underline),
      ),
      tabs: tabs,
      onTap: onTap,
    );
  }
}

/* Ejemplo de uso:
body: Column(
  children: [
    // ====== TAB BAR ======
    Material(
      color: Colors.transparent,
      child: AppTabBar(
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white70,
        indicatorColor: Colors.white,
        tabs: [
          Tab(text: 'Todos',      icon: Icon(Icons.list_alt)),
          Tab(text: 'Por vencer', icon: Icon(Icons.schedule)),
          Tab(text: 'Vencidos',   icon: Icon(Icons.warning_amber)),
          Tab(text: 'Finalizado',   icon: Icon(Icons.bar_chart)),
        ],
      ),
    ),
    Expanded(
      child: TabBarView(
        physics: BouncingScrollPhysics(),
        children: [
          //_TodosTab(),
          _TodosTab(query: _searchCtrl.text), //🔔
          _VencidosTab(),
          _VencidosTab(),
          _FinalizadoTab(),
        ],
      ),
    ),
  ],
),

class _KeepAlive extends StatefulWidget {
  final Widget child;
  const _KeepAlive({required this.child});

  @override
  State<_KeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<_KeepAlive>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

class _TodosTab extends StatelessWidget {
  const _TodosTab();

  @override
  Widget build(BuildContext context) {
    return const _KeepAlive(child: SizedBox.expand());
  }
}

class _PorVencerTab extends StatelessWidget {
  const _PorVencerTab();

  @override
  Widget build(BuildContext context) {
    return const _KeepAlive(child: SizedBox.expand());
  }
}

class _VencidosTab extends StatelessWidget {
  const _VencidosTab();

  @override
  Widget build(BuildContext context) {
    return const _KeepAlive(child: SizedBox.expand());
  }
}

class _EstadisticasTab extends StatelessWidget {
  const _EstadisticasTab();

  @override
  Widget build(BuildContext context) {
    return const _KeepAlive(child: SizedBox.expand());
  }
}
*/
