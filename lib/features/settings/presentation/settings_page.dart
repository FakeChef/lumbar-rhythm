import 'package:flutter/material.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          '设置',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 16),
        SwitchListTile(
          value: true,
          onChanged: (_) {},
          secondary: const Icon(Icons.notifications_active_outlined),
          title: const Text('本地提醒'),
          subtitle: const Text('提醒只在本机运行，不上传健康数据。'),
        ),
        const Divider(),
        const ListTile(
          leading: Icon(Icons.storage_outlined),
          title: Text('本地数据'),
          subtitle: Text('记录和设置保存在本地设备。'),
        ),
        const ListTile(
          leading: Icon(Icons.delete_outline),
          title: Text('删除全部本地数据'),
          subtitle: Text('后续实现本地数据清除。'),
        ),
        const ListTile(
          leading: Icon(Icons.info_outline),
          title: Text('医疗边界'),
          subtitle: Text('本 App 不提供疾病诊断或治疗建议。'),
        ),
      ],
    );
  }
}
