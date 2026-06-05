import 'package:flutter/material.dart';

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          '报告',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 16),
        const Card(
          child: ListTile(
            leading: Icon(Icons.bar_chart_outlined),
            title: Text('本地报告'),
            subtitle: Text('后续会基于本地记录生成简单趋势，不提供医疗判断。'),
          ),
        ),
        const SizedBox(height: 12),
        const Card(
          child: ListTile(
            leading: Icon(Icons.file_download_outlined),
            title: Text('导出数据'),
            subtitle: Text('后续支持用户导出自己的本地记录。'),
          ),
        ),
      ],
    );
  }
}
