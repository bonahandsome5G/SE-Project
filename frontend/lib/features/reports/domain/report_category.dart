class ReportCategory {
  const ReportCategory({
    required this.id,
    required this.name,
    required this.icon,
  });

  final int id;
  final String name;
  final String icon;
}

const reportCategories = [
  ReportCategory(id: 1, name: 'Jalan Berlubang', icon: 'road'),
  ReportCategory(id: 2, name: 'Lampu Jalan Mati', icon: 'light'),
  ReportCategory(id: 3, name: 'Rambu Rusak', icon: 'sign'),
  ReportCategory(id: 4, name: 'Trotoar Rusak', icon: 'sidewalk'),
  ReportCategory(id: 5, name: 'Kemacetan/Penghalang Jalan', icon: 'traffic'),
  ReportCategory(id: 6, name: 'Drainase Tersumbat', icon: 'drainage'),
  ReportCategory(id: 7, name: 'Lampu Lalu Lintas Rusak', icon: 'traffic_light'),
  ReportCategory(id: 8, name: 'Marka Jalan Pudar', icon: 'marking'),
  ReportCategory(id: 9, name: 'Jembatan/Pagar Pengaman Rusak', icon: 'bridge'),
  ReportCategory(id: 10, name: 'Lainnya', icon: 'other'),
];
