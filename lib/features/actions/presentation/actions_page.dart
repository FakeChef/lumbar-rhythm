import 'package:flutter/material.dart';

class ActionsPage extends StatelessWidget {
  const ActionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          '动作',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 16),
        const Card(
          child: ListTile(
            leading: Icon(Icons.timer_outlined),
            title: Text('短休息'),
            subtitle: Text('用于提醒自己离开固定姿势，做温和活动。'),
          ),
        ),
        const SizedBox(height: 12),
        const Card(
          child: ListTile(
            leading: Icon(Icons.accessibility_new_outlined),
            title: Text('动作库占位'),
            subtitle: Text('后续只提供通用提醒，不写诊断或治疗建议。'),
          ),
        ),
      ],
    );
  }
}
